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

/// Internal magnetometer with 1-step calibration peripheral implementation
public class MagnetometerWith1StepCalibrationCore: MagnetometerCore, MagnetometerWith1StepCalibration {

    /// State of the calibration process.
    private (set) public var calibrationProcessState: Magnetometer1StepCalibrationProcessState?

    /// implementation backend
    private unowned let backend: MagnetometerBackend

    public override init(store: ComponentStoreCore, backend: MagnetometerBackend) {
        self.backend = backend
        super.init(desc: Peripherals.magnetometerWith1StepCalibration, store: store, backend: backend)
    }

    public func startCalibrationProcess() {
        if calibrationProcessState == nil {
            calibrationProcessState = Magnetometer1StepCalibrationProcessState()
            backend.startCalibrationProcess()

            // notify the changes
            markChanged()
            notifyUpdated()
        }
    }

    public func cancelCalibrationProcess() {
        if calibrationProcessState != nil {
            backend.cancelCalibrationProcess()
            calibrationProcessState = nil

            // notify the changes
            markChanged()
            notifyUpdated()
        }
    }
}

/// Backend callback methods
extension MagnetometerWith1StepCalibrationCore {
    /// Changes the current axes calibration progress.
    ///
    /// - Parameters:
    ///   - rollProgress: the calibration progress on the roll axis (from 0 to 100)
    ///   - pitchProgress: the calibration progress on the pitch axis (from 0 to 100)
    ///   - yawProgress: the calibration progress on the yaw axis (from 0 to 100)
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        rollProgress: Int, pitchProgress: Int, yawProgress: Int) -> MagnetometerWith1StepCalibrationCore {

        if let calibrationProcessState = calibrationProcessState,
            (calibrationProcessState.rollProgress != rollProgress ||
                calibrationProcessState.pitchProgress != pitchProgress ||
                calibrationProcessState.yawProgress != yawProgress) {

            calibrationProcessState.rollProgress = rollProgress
            calibrationProcessState.pitchProgress = pitchProgress
            calibrationProcessState.yawProgress = yawProgress
            markChanged()
        }
        return self
    }
}
