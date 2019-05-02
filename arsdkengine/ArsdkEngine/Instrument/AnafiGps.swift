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

/// Gps component controller for Anafi messages based drones
class AnafiGps: DeviceComponentController {

    /// Main key in the device store
    private static let settingKey = "Gps"

    /// All data that can be stored
    private enum PersistedDataKey: String, StoreKey {
        case latitude = "latitude"
        case longitude = "longitude"
        case altitude = "altitude"
        case horizontalAccuracy = "horizontalAccuracy"
        case verticalAccuracy = "verticalAccuracy"
        case locationDate = "locationTime"
    }

    /// Special value returned by `latitude` or `longitude` when the coordinate is not known.
    private static let UnknownCoordinate: Double = 500

    /// Whether the onGpsLocationChanged callback was triggered once.
    private var useOnGpsLocationChanged = false

    /// Gps component
    private var gps: GpsCore!

    /// Store device specific values, like last position
    private let deviceStore: SettingsStore

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        deviceStore = deviceController.deviceStore.getSettingsStore(key: AnafiGps.settingKey)
        super.init(deviceController: deviceController)
        self.gps = GpsCore(store: deviceController.device.instrumentStore)

        if !deviceStore.new {
            loadPersistedData()
            gps.publish()
        }
    }

    /// Drone is connected
    override func didConnect() {
        gps.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        // clear all non saved settings
        gps.update(fixed: false).update(satelliteCount: 0).notifyUpdated()
        // unpublish if offline settings are disabled
        if deviceStore.new {
            gps.unpublish()
        }
    }

    /// Drone is about to be forgotten
    override func willForget() {
        deviceStore.clear()
        gps.unpublish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3PilotingstateUid {
            ArsdkFeatureArdrone3Pilotingstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3GpssettingsstateUid {
            ArsdkFeatureArdrone3Gpssettingsstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3GpsstateUid {
            ArsdkFeatureArdrone3Gpsstate.decode(command, callback: self)
        }
    }

    private func loadPersistedData() {
        // load location
        if let latitude: Double = deviceStore.read(key: PersistedDataKey.latitude),
            let longitude: Double = deviceStore.read(key: PersistedDataKey.longitude),
            let altitude: Double = deviceStore.read(key: PersistedDataKey.altitude),
            let date: Date = deviceStore.read(key: PersistedDataKey.locationDate) {

            gps.update(latitude: latitude, longitude: longitude, altitude: altitude, date: date)
        }

        // load location accuracy
        if let horizontalAccuracy: Double = deviceStore.read(key: PersistedDataKey.horizontalAccuracy) {
            gps.update(horizontalAccuracy: horizontalAccuracy)
        }
        if let verticalAccuracy: Double = deviceStore.read(key: PersistedDataKey.verticalAccuracy) {
            gps.update(verticalAccuracy: verticalAccuracy)
        }
    }

    private func save(latitude: Double, longitude: Double, altitude: Double, date: Date) {
        deviceStore.write(key: PersistedDataKey.latitude, value: latitude)
            .write(key: PersistedDataKey.longitude, value: longitude)
            .write(key: PersistedDataKey.altitude, value: altitude)
            .write(key: PersistedDataKey.locationDate, value: date)
            .commit()
    }

    private func save(horizontalAccuracy: Double, verticalAccuracy: Double) {
        deviceStore.write(key: PersistedDataKey.horizontalAccuracy, value: horizontalAccuracy)
            .write(key: PersistedDataKey.verticalAccuracy, value: verticalAccuracy)
    }
}

/// Anafi Piloting State decode callback implementation
extension AnafiGps: ArsdkFeatureArdrone3PilotingstateCallback {
    func onPositionChanged(latitude: Double, longitude: Double, altitude: Double) {
        if useOnGpsLocationChanged {
            return
        }

        if (latitude != AnafiGps.UnknownCoordinate) && (longitude != AnafiGps.UnknownCoordinate) {
            let date = Date()
            gps.update(latitude: latitude, longitude: longitude, altitude: altitude, date: date).notifyUpdated()
            save(latitude: latitude, longitude: longitude, altitude: altitude, date: date)
        }
    }

    func onGpsLocationChanged(latitude: Double, longitude: Double, altitude: Double,
                              latitudeAccuracy: Int, longitudeAccuracy: Int, altitudeAccuracy: Int) {
        useOnGpsLocationChanged = true
        if (latitude != AnafiGps.UnknownCoordinate) && (longitude != AnafiGps.UnknownCoordinate) {
            let date = Date()
            let horizontalAccuracy = Double(max(latitudeAccuracy, longitudeAccuracy))
            let verticalAccuracy = Double(altitudeAccuracy)
            gps.update(latitude: latitude, longitude: longitude, altitude: altitude, date: date)
                .update(horizontalAccuracy: horizontalAccuracy)
                .update(verticalAccuracy: verticalAccuracy)
                .notifyUpdated()
            save(latitude: latitude, longitude: longitude, altitude: altitude, date: date)
            save(horizontalAccuracy: horizontalAccuracy, verticalAccuracy: verticalAccuracy)
        }
    }
}

/// Anafi Gps Settings State decode callback implementation
extension AnafiGps: ArsdkFeatureArdrone3GpssettingsstateCallback {
    func onGPSFixStateChanged(fixed: UInt) {
        // as the number of satellite is not sent back when gps is not fixed,
        // put the satellite number to 0 if the gps is not fixed
        if fixed == 0 {
            gps.update(satelliteCount: 0)
        }
        gps.update(fixed: (fixed != 0)).notifyUpdated()
    }
}

/// Anafi Gps State decode callback implementation
extension AnafiGps: ArsdkFeatureArdrone3GpsstateCallback {
    func onNumberOfSatelliteChanged(numberofsatellite: UInt) {
        gps.update(satelliteCount: Int(numberofsatellite)).notifyUpdated()
    }
}
