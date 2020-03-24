// Copyright (C) 2020 Parrot Drones SAS
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

/// Battery gauge updater component controller for Anafi message based drones
class BatteryGaugeUpdaterController: DeviceComponentController, BatteryGaugeUpdaterBackend {

    /// Battery gauge updater component
    private var batteryGaugeUpdater: BatteryGaugeUpdaterCore!

    /// if firmware is updatable.
    private var isUpdatable = false

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        batteryGaugeUpdater = BatteryGaugeUpdaterCore(
            store: deviceController.device.peripheralStore, backend: self)
    }

    /// Drone is connected
    override func didConnect() {
        if isUpdatable {
            batteryGaugeUpdater.publish()
        }
    }

    /// Drone is disconnected
    override func didDisconnect() {
        isUpdatable = false
        batteryGaugeUpdater.unpublish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureGaugeFwUpdaterUid {
            ArsdkFeatureGaugeFwUpdater.decode(command, callback: self)
        }
    }

    /// Requests preparing battery gauge update.
    func prepareUpdate() {
        sendCommand(ArsdkFeatureGaugeFwUpdater.prepareEncoder())
    }

    /// Requests battery gauge update.
    func update() {
        sendCommand(ArsdkFeatureGaugeFwUpdater.updateEncoder())
    }
}

extension BatteryGaugeUpdaterController: ArsdkFeatureGaugeFwUpdaterCallback {

    func onStatus(diag: ArsdkFeatureGaugeFwUpdaterDiag,
                  missingRequirementsBitField: UInt, state: ArsdkFeatureGaugeFwUpdaterState) {
        batteryGaugeUpdater.update(unavailabilityReasons: BatteryGaugeUpdaterUnavailabilityReasons
            .createSetFrom(bitField: missingRequirementsBitField))
        if diag == .updatable {
            isUpdatable = true
        } else {
            isUpdatable = false
        }
        switch state {
        case .readyToPrepare:
            batteryGaugeUpdater.update(state: .readyToPrepare).update(progress: 0)
        case .preparationInProgress:
            batteryGaugeUpdater.update(state: .preparingUpdate)
        case .readyToUpdate:
            batteryGaugeUpdater.update(state: .readyToUpdate).update(progress: 0)
        case .updateInProgress:
            batteryGaugeUpdater.update(state: .updating)
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown BatteryGaugeUpdaterState, skipping this event.")
        }
        batteryGaugeUpdater.notifyUpdated()
    }

    func onProgress(result: ArsdkFeatureGaugeFwUpdaterResult, percent: UInt) {
        if batteryGaugeUpdater.state == .preparingUpdate {
            batteryGaugeUpdater.update(progress: percent).notifyUpdated()
        }
        if result == .batteryError {
            batteryGaugeUpdater.update(state: .error).notifyUpdated()
        }
    }
}

/// Extension that add conversion from/to arsdk enum
extension BatteryGaugeUpdaterUnavailabilityReasons: ArsdkMappableEnum {

    /// Create set of unavailability reasons from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all unavailability reasons set in bitField
    static func createSetFrom(bitField: UInt) -> Set<BatteryGaugeUpdaterUnavailabilityReasons> {
        var result = Set<BatteryGaugeUpdaterUnavailabilityReasons>()
        ArsdkFeatureGaugeFwUpdaterRequirementsBitField.forAllSet(in: bitField) { arsdkValue in
            if let reason = BatteryGaugeUpdaterUnavailabilityReasons(fromArsdk: arsdkValue) {
                result.insert(reason)
            }
        }
        return result
    }

    static var arsdkMapper = Mapper<BatteryGaugeUpdaterUnavailabilityReasons,
        ArsdkFeatureGaugeFwUpdaterRequirements>([
        .notUsbPowered: .usb,
        .insufficientCharge: .rsoc,
        .droneNotLanded: .droneState])
}
