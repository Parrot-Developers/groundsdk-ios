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

/// State of the calibration process for a 1-step calibration.
/// The calibration is done on the 3 axes simultaneously: roll, pitch and yaw.
/// The calibration progress is provided for each axis as a percentage, in range [0, 100].
/// The magnetometer is calibrated when the calibration progress of the 3 axes has reached 100%.
@objcMembers
@objc(GSMagnetometer1StepCalibrationProcessState)
public class Magnetometer1StepCalibrationProcessState: NSObject {

    /// Progress of calibration on roll axis, from 0 to 100.
    ///
    /// For a drone, roll axis is the longitudinal axis (axis traversing the drone from tail to head).
    public internal(set) var rollProgress = 0

    /// Progress of calibration on pitch axis, from 0 to 100.
    ///
    /// For a drone, pitch axis is the lateral axis (axis traversing the drone from right to left).
    public internal(set) var pitchProgress = 0

    /// Progress of calibration on roll axis, from 0 to 100.
    ///
    /// For a drone, yaw axis is the vertical axis going through the center of the drone.
    public internal(set) var yawProgress = 0

    /// Constructor.
    ///
    /// As this class is abstract from the API point of view, this function is internal.
    internal override init() { }
}

/// 1-step calibration magnetometer peripheral.
///
/// The calibration is done on the 3 axes simultaneously: roll, pitch and yaw.
/// This peripheral can be retrieved by:
/// ```
/// drone.getPeripheral(Peripherals.magnetometerWith1StepCalibration)
/// ```
@objc(GSMagnetometerWith1StepCalibration)
public protocol MagnetometerWith1StepCalibration: Magnetometer {

    /// State of the calibration process.
    ///
    /// - Note: To start a calibration process, use `startCalibrationProcess()`.
    var calibrationProcessState: Magnetometer1StepCalibrationProcessState? { get }

    /// Starts the calibration process.
    ///
    /// After this call, `calibrationProcessState` should not be nil as the process has started.
    /// The process ends either when all axes are recalibrated
    /// or when you call `cancelCalibrationProcess()`.
    ///
    /// - Note: No changes if the process is already started.
    func startCalibrationProcess()

    /// Cancels the calibration process.
    ///
    /// Cancel a process that has been started with `startCalibrationProcess()`.
    /// After this call, `calibrationProcessState()` should return a null object
    /// as the process has ended.
    ///
    /// - Note: No changes if the process is not started.
    func cancelCalibrationProcess()
}

/// :nodoc:
/// 1-step calibration magnetometer description
@objc(GSMagnetometerWith1StepCalibrationDesc)
public class MagnetometerWith1StepCalibrationDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = MagnetometerWith1StepCalibration
    public let uid = PeripheralUid.magnetometerWith1StepCalibration.rawValue
    public let parent: ComponentDescriptor? = Peripherals.magnetometer
}
