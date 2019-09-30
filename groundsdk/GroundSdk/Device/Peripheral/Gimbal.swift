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

/// Gimbal axis.
@objc(GSGimbalAxis)
public enum GimbalAxis: Int, CustomStringConvertible {
    /// Yaw axis of the gimbal.
    case yaw
    /// Pitch axis of the gimbal.
    case pitch
    /// Roll axis of the gimbal.
    case roll

    /// Debug description.
    public var description: String {
        switch self {
        case .yaw: return "yaw"
        case .pitch: return "pitch"
        case .roll: return "roll"
        }
    }

    /// Set containing all axes.
    public static let allCases: Set<GimbalAxis> = [.yaw, .pitch, .roll]
}

/// Gimbal frame of reference.
@objc(GSFrameOfReference)
public enum FrameOfReference: Int, CustomStringConvertible {
    /// Absolute frame of reference.
    case absolute
    /// Relative frame of reference.
    case relative

    /// Debug description.
    public var description: String {
        switch self {
        case .absolute: return "absolute"
        case .relative: return "relative"
        }
    }

    /// Set containing all frame of reference.
    public static let allCases: Set<FrameOfReference> = [.absolute, .relative]
}

/// Gimbal error.
@objc(GSGimbalError)
public enum GimbalError: Int, CustomStringConvertible {
    /// Calibration error.
    ///
    /// May happen during manual or automatic calibration.
    ///
    /// Application should inform the user that the gimbal is currently inoperable and suggest to verify that
    /// nothing currently hinders proper gimbal movement.
    ///
    /// The device will retry calibration regularly; after several failed attempts, it will escalate the current
    /// error to `.critical` level, at which point the gimbal becomes inoperable until both the issue
    /// is fixed and the device is restarted.
    case calibration
    /// Overload error.
    ///
    /// May happen during normal operation of the gimbal.
    ///
    /// Application should inform the user that the gimbal is currently inoperable and suggest to verify that
    /// nothing currently hinders proper gimbal movement.
    ///
    /// The device will retry stabilization regularly; after several failed attempts, it will escalate the current
    /// error to `.critical` level, at which point the gimbal becomes inoperable until both the issue
    /// is fixed and the device is restarted.
    case overload
    /// Communication error.
    ///
    /// Communication with the gimbal is broken due to some unknown software and/or hardware issue.
    ///
    /// Application should inform the user that the gimbal is currently inoperable.
    /// However, there is nothing the application should recommend the user to do at that point: either the issue
    /// will hopefully resolve itself (most likely a software issue), or it will escalate to critical level
    /// (probably hardware issue) and the application should recommend the user to send back the device for repair.
    ///
    /// The device will retry stabilization regularly; after several failed attempts, it will escalate the current
    /// error to `.critical` level, at which point the gimbal becomes inoperable until both the issue
    /// is fixed and the device is restarted.
    case communication
    /// Critical error.
    ///
    /// May occur at any time; in particular, occurs when any of the other errors persists after
    /// multiple retries from the device.
    ///
    /// Application should inform the user that the gimbal has become completely inoperable until the issue is
    /// fixed and the device is restarted, as well as suggest to verify that nothing currently hinders proper gimbal
    /// movement and that the gimbal is not damaged in any way.
    case critical

    /// Debug description.
    public var description: String {
        switch self {
        case .calibration:      return "calibration"
        case .overload:         return "overload"
        case .communication:    return "communication"
        case .critical:         return "critical"
        }
    }

    /// Set containing all axes.
    public static let allCases: Set<GimbalError> = [.calibration, .overload, .communication, critical]
}

/// Way of controlling the gimbal.
@objc(GSGimbalControlMode)
public enum GimbalControlMode: Int, CustomStringConvertible {
    /// Control the gimbal giving position targets.
    case position
    /// Control the gimbal giving velocity targets.
    case velocity

    /// Debug description.
    public var description: String {
        switch self {
        case .position: return "position"
        case .velocity: return "velocity"
        }
    }
}

/// Gimbal calibration process state.
@objc(GSGimbalCalibrationProcessState)
public enum GimbalCalibrationProcessState: Int, CustomStringConvertible {
    /// No ongoing calibration process.
    case none
    /// Calibration process in progress.
    case calibrating
    /// Calibration was successful.
    ///
    /// This result is transient, calibration state will change back to `.none` immediately after success is notified.
    case success
    /// Calibration failed.
    ///
    /// This result is transient, calibration state will change back to `.none` immediately after failure is notified.
    case failure
    /// Calibration was canceled.
    ///
    /// This result is transient, calibration state will change back to `.none` immediately after canceled is notified.
    case canceled

    /// Debug description.
    public var description: String {
        switch self {
        case .none: return "none"
        case .calibrating: return "calibrating"
        case .success: return "success"
        case .failure: return "failure"
        case .canceled: return "canceled"
        }
    }
}

/// Gimbal offsets manual correction process.
@objcMembers
@objc(GSGimbalOffsetsCorrectionProcess)
public class GimbalOffsetsCorrectionProcess: NSObject {
    /// Set of axes that can be manually corrected.
    ///
    /// If a given axis can be corrected, calibrationOffsets of this axis will return a non-nil object when correction
    /// is started.
    internal(set) public var correctableAxes = Set<GimbalAxis>()

    /// Offsets correction applied to the gimbal.
    ///
    /// Only contains correctable axes.
    public var offsetsCorrection: [GimbalAxis: DoubleSetting] {
        return _offsetsCorrection
    }
    var _offsetsCorrection = [GimbalAxis: DoubleSettingCore]()

    /// Internal constructor.
    override init() {}
}

/// The gimbal is the peripheral "holding" and orientating the camera. It can be a real mechanical gimbal, or a software
/// one.
///
/// The gimbal can act on one or multiple axes. It can stabilize a given axis, meaning that the movement on this axis
/// will be following the horizon (for `.roll` and `.pitch`) or the North (for the `.yaw`).
///
/// Two frames of reference are used to control the gimbal with the `.position` mode, and to retrieve the gimbal
/// attitude
/// Relative frame of reference:
/// - yaw: given angle is relative to the heading of the drone.
///        Positive yaw values means a right orientation when seeing the gimbal from above.
/// - pitch: given angle is relative to the body of the drone.
///          Positive pitch values means an orientation of the gimbal towards the top of the drone.
/// - roll: given angle is relative to the body of the drone.
///         Positive roll values means an clockwise rotation of the gimbal.
/// Absolute frame of reference:
/// - yaw: given angle is relative to the magnetic North (clockwise).
/// - pitch: given angle is relative to the horizon.
///         Positive pitch values means an orientation towards sky.
/// - roll: given angle is relative to the horizon line.
///         Positive roll values means an orientation to the right when seeing the gimbal from behind.
///
/// This peripheral can be retrieved by:
/// ```
/// device.getPeripheral(Peripherals.gimbal)
/// ```
public protocol Gimbal: Peripheral {
    /// Set of supported axes, i.e. axis that can be controlled.
    var supportedAxes: Set<GimbalAxis> { get }

    /// Set of current errors.
    ///
    /// When empty, the gimbal can be operated normally, otherwise, it is currently inoperable.
    /// In case the returned set contains the `.critical` error, then gimbal has become completely inoperable
    /// until both all other reported errors are fixed and the device is restarted.
    var currentErrors: Set<GimbalError> { get }

    /// Set of currently locked axes.
    /// While an axis is locked, you cannot set a speed or a position.
    ///
    /// An axis can be locked because the drone is controlling this axis on itself, thus it does not allow the
    /// controller to change its orientation. This might be the case during a FollowMe or when the
    /// `PointOfInterestPilotingItf` is active.
    ///
    /// Only contains supported axes.
    var lockedAxes: Set<GimbalAxis> { get }

    /// Bounds of the attitude by axis.
    /// Only contains supported axes.
    var attitudeBounds: [GimbalAxis: Range<Double>] { get }

    /// Max speed by axis.
    /// Only contains supported axes.
    var maxSpeedSettings: [GimbalAxis: DoubleSetting] { get }

    /// Whether the axis is stabilized.
    /// Only contains supported axes.
    var stabilizationSettings: [GimbalAxis: BoolSetting] { get }

    /// Current gimbal attitude.
    /// Empty when not connected.
    var currentAttitude: [GimbalAxis: Double] { get }

    /// Offset correction process.
    /// Not nil when offset correction is started (see `startOffsetsCorrectionProcess()` and
    /// `stopOffsetsCorrectionProcess()`).
    var offsetsCorrectionProcess: GimbalOffsetsCorrectionProcess? { get }

    /// Whether the gimbal is calibrated.
    var calibrated: Bool { get }

    /// Calibration process state.
    /// See `startCalibration()` and `cancelCalibration()`
    var calibrationProcessState: GimbalCalibrationProcessState { get }

    /// Controls the gimbal.
    ///
    /// Unit of the `yaw`, `pitch`, `roll` values depends on the value of the `mode` parameter:
    ///    - `.position`: axis value is in degrees and represents the desired position of the gimbal on the given axis.
    ///    - `.velocity`: axis value is in max speed (`maxSpeedSettings[thisAxis].value`) ratio (from -1 to 1).
    ///
    /// If mode is `.position`, frame of reference of a given axis depends on the value of the stabilization on
    /// this axis. If this axis is stabilized (i.e. `stabilizationSettings[thisAxis].value == true`), the .absolute
    /// frame of reference is used. Otherwise .relative frame of reference is used.
    /// - Parameters:
    ///   - mode: the mode that should be used to move the gimbal. This parameter will change the unit of the following
    ///           parameters
    ///   - yaw: target on the yaw axis. `nil` if you want to keep the current value.
    ///   - pitch: target on the pitch axis. `nil` if you want to keep the current value.
    ///   - roll: target on the roll axis. `nil` if you want to keep the current value.
    func control(mode: GimbalControlMode, yaw: Double?, pitch: Double?, roll: Double?)

    /// Starts the offsets correction process.
    ///
    /// When offset correction is started, `offsetsCorrectionProcess` is not nil and correctable offsets can be
    /// corrected.
    func startOffsetsCorrectionProcess()

    /// Stops the offsets correction process.
    ///
    /// `offsetsCorrectionProcess` will be set to nil.
    func stopOffsetsCorrectionProcess()

    /// Starts calibration process.
    /// Does nothing when `calibrationProcessState` is `calibrating`.
    func startCalibration()

    /// Cancels the current calibration process.
    /// Does nothing when `calibrationProcessState` is not `calibrating`.
    func cancelCalibration()

    /// Gets the current attitude for a given frame of reference.
    ///
    /// - Parameter frameOfReference: the frame of reference
    /// - Returns: the current attitude as an array of axis.
    func currentAttitude(frameOfReference: FrameOfReference) -> [GimbalAxis: Double]
}

/// Objective-C version of Gimbal.
///
/// The gimbal is the peripheral "holding" and orientating the camera. It can be a real mechanical gimbal, or a software
/// one.
///
/// The gimbal can act on one or multiple axes. It can stabilize a given axis, meaning that the movement on this axis
/// will be following the horizon (for `.roll` and `.pitch`) or the North (for the `.yaw`).
///
/// - Note: This class is for Objective-C only and must not be used in Swift.
@objc
public protocol GSGimbal: Peripheral {
    /// Offset correction process.
    /// Not nil when offset correction is started (see `startOffsetsCorrectionProcess()` and
    /// `stopOffsetsCorrectionProcess()`).
    var offsetsCorrectionProcess: GimbalOffsetsCorrectionProcess? { get }

    /// Whether the gimbal is calibrated.
    var calibrated: Bool { get }

    /// Calibration process state.
    /// See `startCalibration()` and `cancelCalibration()`
    var calibrationProcessState: GimbalCalibrationProcessState { get }

    /// Tells whether a given axis is supported
    ///
    /// - Parameter axis: the axis to query
    /// - Returns: `true` if the axis is supported, `false` otherwise
    func isAxisSupported(_ axis: GimbalAxis) -> Bool

    /// Tells whether the gimbal currently has the given error.
    ///
    /// - Parameter error: the error to query
    /// - Returns: `true` if the error is currently happening
    func hasError(_ error: GimbalError) -> Bool

    /// Tells whether a given axis is currently locked.
    ///
    /// While an axis is locked, you cannot set a speed or a position.
    ///
    /// An axis can be locked because the drone is controlling this axis on itself, thus it does not allow the
    /// controller to change its orientation. This might be the case during a FollowMe or when the
    /// `PointOfInterestPilotingItf` is active.
    ///
    /// - Parameter axis: the axis to query
    /// - Returns: `true` if the axis is supported and locked, `false` otherwise
    func isAxisLocked(_ axis: GimbalAxis) -> Bool

    /// Gets the lower bound of the attitude on a given axis.
    ///
    /// - Parameter axis: the axis
    /// - Returns: a double in an NSNumber. `nil` if axis is not supported.
    func attitudeLowerBound(onAxis axis: GimbalAxis) -> NSNumber?

    /// Gets the upper bound of the attitude on a given axis.
    ///
    /// - Parameter axis: the axis
    /// - Returns: a double in an NSNumber. `nil` if axis is not supported.
    func attitudeUpperBound(onAxis axis: GimbalAxis) -> NSNumber?

    /// Gets the max speed setting on a given axis.
    ///
    /// - Parameter axis: the axis
    /// - Returns: the max speed setting or `nil` if the axis is not supported.
    func maxSpeed(onAxis axis: GimbalAxis) -> DoubleSetting?

    /// Gets the stabilization setting on a given axis
    ///
    /// - Parameter axis: the axis
    /// - Returns: the stabilization setting or `nil` if the axis is not supported
    func stabilization(onAxis axis: GimbalAxis) -> BoolSetting?

    /// Gets the current attitude on a given axis.
    ///
    /// - Parameter axis: the axis
    /// - Returns: the current attitude as a double in an NSNumber. `nil` if axis is not supported.
    func currentAttitude(onAxis axis: GimbalAxis) -> NSNumber?

    /// Gets the current attitude on a given axis and frame of reference
    ///
    /// - Parameters:
    ///   - axis: the axis
    ///   - frameOfReference: the frame of reference
    /// - Returns: the current attitude as a double in an NSNumber. `nil` if axis is not supported.
    func currentAttitude(onAxis axis: GimbalAxis, frameOfReference: FrameOfReference) -> NSNumber?

    /// Controls the gimbal.
    ///
    /// Unit of the `yaw`, `pitch`, `roll` values depends on the value of the `mode` parameter:
    ///    - `.position`: axis value is in degrees and represents the desired position of the gimbal on the given axis.
    ///    - `.velocity`: axis value is in max speed (`maxSpeedSettings[thisAxis].value`) ratio (from -1 to 1).
    ///
    /// If mode is `.position`, frame of reference of a given axis depends on the value of the stabilization on
    /// this axis. If this axis is stabilized (i.e. `stabilizationSettings[thisAxis].value == true`), the .absolute
    /// frame of reference is used. Otherwise .relative frame of reference is used.
    /// - Parameters:
    ///   - mode: the mode that should be used to move the gimbal. This parameter will change the unit of the following
    ///           parameters
    ///   - yaw: target on the yaw axis as a Double in an NSNumber. `nil` if you want to keep the current value.
    ///   - pitch: target on the pitch axis as a Double in an NSNumber. `nil` if you want to keep the current value.
    ///   - roll: target on the roll axis as a Double in an NSNumber. `nil` if you want to keep the current value.
    func control(mode: GimbalControlMode, yaw: NSNumber?, pitch: NSNumber?, roll: NSNumber?)

    /// Starts the offsets correction process.
    ///
    /// When offset correction is started, `offsetsCorrectionProcess` is not nil and correctable offsets can be
    /// corrected.
    func startOffsetsCorrectionProcess()

    /// Stops the offsets correction process.
    ///
    /// `offsetsCorrectionProcess` will be set to nil.
    func stopOffsetsCorrectionProcess()

    /// Starts calibration process.
    func startCalibration()

    /// Cancels the current calibration process.
    func cancelCalibration()
}

/// Extension of the GimbalOffsetsCorrectionProcess that adds Objective-C missing vars and functions support.
extension GimbalOffsetsCorrectionProcess {
    /// Tells whether a given axis can be manually corrected.
    ///
    /// - Parameter axis: the axis to query
    /// - Returns: `true` if the axis can be corrected
    /// - Note: This method is for Objective-C only. Swift must use `correctableAxes`
    public func isAxisCorrectable(_ axis: GimbalAxis) -> Bool {
        return correctableAxes.contains(axis)
    }

    /// Gets the manual offset correction on a given axis.
    ///
    /// - Parameter axis: the axis
    /// - Returns: the manual offset correction setting if the axis is correctable.
    /// - Note: This method is for Objective-C only. Swift must use `offsetsCorrection`
    public func offsetCorrection(onAxis axis: GimbalAxis) -> DoubleSetting? {
        return offsetsCorrection[axis]
    }
}

/// :nodoc:
/// Gimbal description
@objc(GSGimbalDesc)
public class GimbalDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = Gimbal
    public let uid = PeripheralUid.gimbal.rawValue
    public let parent: ComponentDescriptor? = nil
}
