// Copyright (C) 2019 Parrot Drones SAS
//
//    Redistribution and use in source and binary forms, with or without
//    modification, are permitted provided that the following conditions
//    are met:
//    * Redistributions of source code must retain the above copyright
//      notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above copyright
//      notice, this list of conditions and the following disclaimer in
//      the documentation and/or other materials provided with the
//      distribution.
//    * Neither the name of the Parrot Company nor the names
//      of its contributors may be used to endorse or promote products
//      derived from this software without specific prior written
//      permission.
//
//    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//    PARROT COMPANY BE LIABLE FOR ANY DIRECT, INDIRECT,
//    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
//    OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
//    AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
//    OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//    SUCH DAMAGE.

import Foundation
import GroundSdk

/// FlightMeter component controller for Anafi messages based drones
class AnafiFlightMeter: DeviceComponentController {

    /// Main key in the device store
    private static let settingKey = "FlightMeter"

    /// All data that can be stored
    private enum PersistedDataKey: String, StoreKey {
        case totalFlightDuration = "totalFlightDuration"
        case lastFlightDuration = "lastFlightDuration"
        case totalFlights = "totalFlights"
    }

    /// FlightMeter component
    private var flightMeter: FlightMeterCore!

    /// Store device specific values
    private let deviceStore: SettingsStore

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        deviceStore = deviceController.deviceStore.getSettingsStore(key: AnafiFlightMeter.settingKey)
        super.init(deviceController: deviceController)
        self.flightMeter = FlightMeterCore(store: deviceController.device.instrumentStore)

        if !deviceStore.new {
            loadPersistedData()
            flightMeter.publish()
        }
    }

    /// Drone is connected
    override func didConnect() {
        flightMeter.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        if deviceStore.new {
            flightMeter.unpublish()
        }
    }

    /// Drone is about to be forgotten
    override func willForget() {
        deviceStore.clear()
        flightMeter.unpublish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3SettingsstateUid {
            ArsdkFeatureArdrone3Settingsstate.decode(command, callback: self)
        }
    }

    private func loadPersistedData() {
        // load location
        if let totalFlightDuration: Int = deviceStore.read(key: PersistedDataKey.totalFlightDuration) {
            flightMeter.update(totalFlightDuration: totalFlightDuration)
        }
        if let totalFlights: Int = deviceStore.read(key: PersistedDataKey.totalFlights) {
            flightMeter.update(totalFlights: totalFlights)
        }
        if let lastFlightDuration: Int = deviceStore.read(key: PersistedDataKey.lastFlightDuration) {
            flightMeter.update(lastFlightDuration: lastFlightDuration)
        }
    }
}

/// Anafi State decode callback implementation
extension AnafiFlightMeter: ArsdkFeatureArdrone3SettingsstateCallback {
    func onMotorFlightsStatusChanged(nbflights: UInt, lastflightduration: UInt, totalflightduration: UInt) {
        let totalFlightDuration = Int(totalflightduration)
        let lastFlightDuration = Int(lastflightduration)
        let totalFlights = Int(nbflights)

        flightMeter.update(totalFlightDuration: totalFlightDuration)
            .update(totalFlights: totalFlights)
            .update(lastFlightDuration: lastFlightDuration).notifyUpdated()

        deviceStore.write(key: PersistedDataKey.totalFlightDuration, value: totalFlightDuration)
            .write(key: PersistedDataKey.totalFlights, value: nbflights)
            .write(key: PersistedDataKey.lastFlightDuration, value: lastFlightDuration).commit()
    }
}
