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

/// State of the calibration process for a 3-steps calibration.
@objcMembers
@objc(GSMagnetometer3StepCalibrationProcessState)
public class Magnetometer3StepCalibrationProcessState: NSObject {

    /// Drone axis used during the magnetometer calibration process.
    @objc(GSMagnetometerAxis)
    public enum Axis: Int, CustomStringConvertible {
        /// No axis.
        case none

        /// Roll axis.
        /// Roll axis is the longitudinal axis (axis traversing the drone from tail to head)
        case roll

        /// Pitch axis.
        /// Pitch axis is the lateral axis (axis traversing the drone from right to left)
        case pitch

        /// Yaw axis.
        /// Yaw axis is the vertical axis going through the center of the drone.
        case yaw

        /// Debug description.
        public var description: String {
            switch self {
            case .none:
                return "none"
            case .roll:
                return "roll"
            case .pitch:
                return "pitch"
            case .yaw:
                return "yaw"
            }
        }
    }

    /// `true` if the calibration process failed.
    ///
    /// - Note: This flag may be set at the end of the calibration process, then the process will be ended.
    public internal(set) var failed = false

    /// The current axis to calibrate.
    public internal(set) var currentAxis: Axis = .none

    /// The set of the calibrated axes.
    /// Empty if no axis is calibrated.
    public internal(set) var calibratedAxes: Set<Axis> = []

    /// Tells if an axis is calibrated
    ///
    /// - Note: This method is present because property `calibratedAxes` is not available in Objective-C.
    public func isCalibrated(axis: Axis) -> Bool {
        return calibratedAxes.contains(axis)
    }

    /// Constructor.
    ///
    /// As this class is abstract from the API point of view, this function is internal.
    internal override init() { }
}

/// 3-steps calibration magnetometer peripheral.
///
/// The calibration is done axis by axis, one after the other: roll, pitch and yaw.
/// The order of axis calibration may vary depending on device.
///
/// This peripheral can be retrieved by:
/// ```
/// drone.getPeripheral(Peripherals.magnetometerWith3StepCalibration)
/// ```
@objc(GSMagnetometerWith3StepCalibration)
public protocol MagnetometerWith3StepCalibration: Magnetometer {

    /// Current state of the calibration process. Not `nil` if a calibration process is running, `nil` otherwise.
    ///
    /// - Note: To start a calibration process, use `startCalibrationProcess()`. At the end of the calibration process,
    /// `calibrationProcessState` is `nil`.
    ///
    /// - Note: Even if each axis has been processed successfully during the calibration process, it is possible that
    /// the calibration process may be in error at the end (this may be due to a magnetic environment disturbing
    /// the calibration). See `calibrationProcessState.failed`.
    var calibrationProcessState: Magnetometer3StepCalibrationProcessState? { get }

    /// Starts the calibration process.
    ///
    /// After this call, `calibrationProcessState` should not be nil as the process has started.
    /// The process ends either when all axes are recalibrated or when you call `cancelCalibrationProcess()`.
    ///
    /// - Note: No change if the process is already started.
    func startCalibrationProcess()

    /// Cancels the calibration process.
    ///
    /// Cancel a process that has been started with `startCalibrationProcess()`.
    /// After this call, `calibrationProcessState()` should return a null object as the process has ended.
    ///
    /// - Note: No change if the process is not started.
    func cancelCalibrationProcess()
}

/// :nodoc:
/// 3-steps calibration magnetometer description
@objc(GSMagnetometerWith3StepCalibrationDesc)
public class MagnetometerWith3StepCalibrationDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = MagnetometerWith3StepCalibration
    public let uid = PeripheralUid.magnetometerWith3StepCalibration.rawValue
    public let parent: ComponentDescriptor? = Peripherals.magnetometer
}
