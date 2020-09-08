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

/// Magnetometer component controller for SkyController message based rc and using the 1-step calibration
class SkyControllerMagnetometer: DeviceComponentController {
    /// Magnetometer component
    private var magnetometer: MagnetometerWith1StepCalibrationCore!

    private let arsdkMaxCalibrationQuality: UInt = 255

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        magnetometer = MagnetometerWith1StepCalibrationCore(
            store: deviceController.device.peripheralStore, backend: self)
    }

    /// Drone is connected
    override func didConnect() {
        magnetometer.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        magnetometer.unpublish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureSkyctrlCalibrationstateUid {
            ArsdkFeatureSkyctrlCalibrationstate.decode(command, callback: self)
        }
    }
}

/// Magnetometer backend implementation
extension SkyControllerMagnetometer: MagnetometerBackend {
    func startCalibrationProcess() {
        sendCommand(ArsdkFeatureSkyctrlCalibration.enableMagnetoCalibrationQualityUpdatesEncoder(enable: 1))
    }

    func cancelCalibrationProcess() {
        sendCommand(ArsdkFeatureSkyctrlCalibration.enableMagnetoCalibrationQualityUpdatesEncoder(enable: 0))
    }
}

/// SkyController calibration state decode callback implementation
extension SkyControllerMagnetometer: ArsdkFeatureSkyctrlCalibrationstateCallback {

    func onMagnetoCalibrationState(
        status: ArsdkFeatureSkyctrlCalibrationstateMagnetocalibrationstateStatus,
        xQuality: UInt, yQuality: UInt, zQuality: UInt) {

        if status != .sdkCoreUnknown {
            let rollProgress = Int(percentInterval.clamp((xQuality*100)/arsdkMaxCalibrationQuality))
            let pitchProgress = Int(percentInterval.clamp((yQuality*100)/arsdkMaxCalibrationQuality))
            let yawProgress = Int(percentInterval.clamp((zQuality*100)/arsdkMaxCalibrationQuality))
            var calibratedStatus: MagnetometerCalibrationState = .required
            switch status {
            case .calibrated:
                calibratedStatus = .calibrated
            case .assessing, .unreliable:
                calibratedStatus = .required
            default:
                calibratedStatus = .required
            }
            magnetometer.update(rollProgress: rollProgress, pitchProgress: pitchProgress, yawProgress: yawProgress)
                .update(calibrated: calibratedStatus).notifyUpdated()
        }
    }
}
