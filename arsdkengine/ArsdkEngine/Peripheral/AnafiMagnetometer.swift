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

/// Magnetometer component controller for Anafi message based drones
class AnafiMagnetometer: DeviceComponentController {

    /// Flag indicating whether the calibration process failed or not. The interface will be notified when
    /// the calibration process stops
    private var calibrationFailed = false

    /// Magnetometer component
    private var magnetometer: MagnetometerWith3StepCalibrationCore!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        magnetometer = MagnetometerWith3StepCalibrationCore(
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
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCommonCalibrationstateUid {
            ArsdkFeatureCommonCalibrationstate.decode(command, callback: self)
        }
    }
}

/// Magnetometer backend implementation
extension AnafiMagnetometer: MagnetometerBackend {
    func startCalibrationProcess() {
        sendCommand(ArsdkFeatureCommonCalibration.magnetoCalibrationEncoder(calibrate: 1))
    }

    func cancelCalibrationProcess() {
        sendCommand(ArsdkFeatureCommonCalibration.magnetoCalibrationEncoder(calibrate: 0))
    }
}

/// Common calibration state decode callback implementation
extension AnafiMagnetometer: ArsdkFeatureCommonCalibrationstateCallback {
    func onMagnetoCalibrationStateChanged(xaxiscalibration: UInt, yaxiscalibration: UInt, zaxiscalibration: UInt,
                                          calibrationfailed: UInt) {
        var calibratedAxes: Set<Magnetometer3StepCalibrationProcessState.Axis> = []
        if calibrationfailed == 1 {
            // The value is not immediately updated in the interface. We keep this value (which can change) and it will
            // be updated in the interface when the calibration process is stopped. The failed state can only be
            // considered when the device has indicated the end of the validation process
            self.calibrationFailed = true
        } else {
             self.calibrationFailed = false
            if xaxiscalibration == 1 {
                calibratedAxes.insert(.roll)
            }
            if yaxiscalibration == 1 {
                calibratedAxes.insert(.pitch)
            }
            if zaxiscalibration == 1 {
                calibratedAxes.insert(.yaw)
            }
        }
        magnetometer.update(calibratedAxes: calibratedAxes).notifyUpdated()
    }

    func onMagnetoCalibrationRequiredState(required: UInt) {
        switch required {
        case 0:
            magnetometer.update(calibrated: .calibrated).notifyUpdated()
        case 1:
            magnetometer.update(calibrated: .required).notifyUpdated()
        case 2:
            magnetometer.update(calibrated: .recommended).notifyUpdated()
        default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown state, skipping this calibration required state event.")
        }
    }

    func onMagnetoCalibrationAxisToCalibrateChanged(
        axis: ArsdkFeatureCommonCalibrationstateMagnetocalibrationaxistocalibratechangedAxis) {
        switch axis {
        case .xaxis:
            magnetometer.update(currentAxis: .roll)
        case .yaxis:
            magnetometer.update(currentAxis: .pitch)
        case .zaxis:
            magnetometer.update(currentAxis: .yaw)
        case .none:
            magnetometer.update(currentAxis: .none)
        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown axis, skipping this event.")
            return
        }
        magnetometer.notifyUpdated()
    }

    func onMagnetoCalibrationStartedChanged(started: UInt) {
        if started == 0 {
            // calibration process is stopped
            if calibrationFailed {
                magnetometer.update(failed: true).notifyUpdated()
            }
            magnetometer.calibrationProcessStopped().notifyUpdated()
        }
        // reset the failure indicator when starting or stopping the calibration process
        calibrationFailed = false
    }
}
