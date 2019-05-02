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

/// FollowMe mode, defines how the drone follows the target.
@objc(GSFollowMode)
public enum FollowMode: Int, CustomStringConvertible {

    /// The drone tracks only the position of the target, regardless of its orientation or any change in its direction.
    /// The drone will move so that the north-drone-target angle and the distance to the target both remains constant.
    case geographic

    /// In addition to the position, the drone also tracks changes in the direction of the target, relatively to the
    /// initial direction of the target (i.e: when the interface was activated or after moving the drone with a pitch,
    /// roll or gaz value).The drone will move so that the angle formed by the target direction vector, and the
    /// drone-target vector is constant.
    case relative

    /// Mode instructing the drone to both track the target position and changes in the direction of the target,
    /// as if it was held by the target by a leash.
    case leash

    /// Debug description.
    public var description: String {
        switch self {
        case .geographic:   return "geographic"
        case .relative:     return "relative"
        case .leash:        return "leash"
        }
    }

    /// Set containing all modes.
    public static let allCases: Set<FollowMode> = [.geographic, .relative, .leash]
}

/// Setting providing access to the mode (FollowMode) setup.
public protocol FollowModeSetting: AnyObject {
    /// Set of supported mode.
    var supportedModes: Set<FollowMode> { get }

    /// Tell if the setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Follow mode.
    ///
    /// - Note: Only a supported Follow mode can be set.
    var value: FollowMode { get set }
}

/// Setting providing access to the mode (FollowMode) setup.
///
/// This protocol is Objective-C only. Swift must use `FollowModeSetting`.
@objc
public protocol GSFollowModeSetting {
    /// Tell if the setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Follow mode.
    ///
    /// - Note: Only a supported Follow mode can be set.
    var value: FollowMode { get set }

    /// Tells whether a given mode is supported or not.
    ///
    /// - Parameter mode: the mode to query
    /// - Returns: `true` if the mode is supported
    func modeIsSupported(_ mode: FollowMode) -> Bool
}

/// Current state of follow mode.
///
/// When the FollowMe mode is active, the drone follows its target (moving the drone and the camera). If the Follow
/// mode prerequisites are not met, the drone may remain stationary (while visually following its target).
@objc(GSFollowBehavior)
public enum FollowBehavior: Int, CustomStringConvertible {

    /// The drone follows the target.
    case following

    /// The drone looks at the target without moving.
    case stationary

    /// Debug description.
    public var description: String {
        switch self {
        case .following:   return "following"
        case .stationary:  return "stationary"
        }
    }
}

/// FollowMe piloting interface.
///
/// During an activated FollowMe, the drone will always look at the target but can be piloted
/// normally. However, yaw value is not settable. Camera tilt and pan command is ignored by the drone.
///
/// This piloting interface can be retrieved by:
/// ```
/// drone.getPilotingItf(PilotingItfs.followMe)
/// ```
public protocol FollowMePilotingItf: PilotingItf, ActivablePilotingItf {

    /// The follow mode to use.
    ///
    /// - Note: This setting is not saved at the application level.
    var followMode: FollowModeSetting { get }

    /// The current follow state if this interface is `.active`, `nil` otherwise.
    ///
    /// When the FollowMe mode is active, the drone follows its target (moving the drone and the camera). If the Follow
    /// mode prerequisites are not met, the drone may remain stationary (while visually following its target).
    var followBehavior: FollowBehavior? { get }

    /// Tell why this piloting interface may currently be unavailable.
    ///
    /// Set of reasons that preclude this piloting interface from being available at present.
    var availabilityIssues: Set<TrackingIssue> { get }

    /// Alert about issues that currently hinders optimal behavior of this interface.
    ///
    /// The returned set may contain values only if the interface is `active`.
    var qualityIssues: Set<TrackingIssue> { get }

    /// Sets the current pitch value.
    ///
    /// Expressed as a signed percentage of the max pitch/roll setting (`maxPitchRoll`), in range [-100, 100].
    /// * -100 corresponds to a pitch angle of max pitch/roll towards ground (copter will fly forward)
    /// * 100 corresponds to a pitch angle of max pitch/roll towards sky (copter will fly backward)
    ///
    /// - Note: This value may be clamped if necessary, in order to respect the maximum supported physical tilt of
    /// the copter.
    ///
    /// - Parameter pitch: the new pitch value to set
    func set(pitch: Int)

    /// Sets the current roll value.
    ///
    /// Expressed as a signed percentage of the max pitch/roll setting (`maxPitchRoll`), in range [-100, 100].
    /// * -100 corresponds to a roll angle of max pitch/roll to the left (copter will fly left)
    /// * 100 corresponds to a roll angle of max pitch/roll to the right (copter will fly right)
    ///
    /// - Note: This value may be clamped if necessary, in order to respect the maximum supported physical tilt of
    /// the copter.
    ///
    /// - Parameter roll: the new roll value to set
    func set(roll: Int)

    /// Sets the current vertical speed value.
    ///
    /// Expressed as a signed percentage of the max vertical speed setting (`maxVerticalSpeed`), in range [-100, 100].
    /// * -100 corresponds to max vertical speed towards ground
    /// * 100 corresponds to max vertical speed towards sky
    ///
    /// - Parameter verticalSpeed: the new vertical speed value to set
    func set(verticalSpeed: Int)

    /// Activates this piloting interface.
    ///
    /// If successful, it deactivates the current piloting interface and activate this one.
    ///
    /// - Returns: `true` on success, `false` if the piloting interface can't be activated
    func activate() -> Bool
}

// MARK: - objc compatibility

/// Objective-C version of FollowMePilotingItf.
///
/// During an activated FollowMe, the drone will always look at the target but can be piloted
/// normally. However, yaw value is not settable. Camera tilt and pan command is ignored by the drone.
///
/// - Note: This class is for Objective-C only and must not be used in Swift.
@objc
public protocol GSFollowMePilotingItf: PilotingItf, ActivablePilotingItf {

    /// The follow mode to use.
    ///
    /// - Note: This setting is not saved at the application level.
    @objc(followMode)
    var gsFollowMode: GSFollowModeSetting { get }

    /// The current follow state if this interface is `.active`, otherwise the value is not significant.
    ///
    /// When the FollowMe mode is active, the drone follows its target (moving the drone and the camera). If the Follow
    /// mode prerequisites are not met, the drone may remain stationary (while visually following its target).
    @objc(followBehavior)
    var gsFollowBehavior: FollowBehavior { get }

    /// If the interface is `unavailable`, each TrackingIssue case can be tested.
    ///
    /// - Parameter issue: tracking issue to be tested
    /// - Returns: `true` if the issue is present, `false` otherwise
    func availabilityIssuesContains( _ issue: TrackingIssue) -> Bool

    /// Tells if at least one availabilityIssue is present.
    ///
    /// - Returns: `true` if there is no availability TrackingIssue, `false` otherwise
    func availabilityIssuesIsEmpty() -> Bool

    /// If the interface is `active`, each quality issue case can be tested.
    ///
    /// - Parameter issue: tracking issue to be tested
    /// - Returns: `true` if the issue is present, `false` otherwise
    func qualityIssuesContains( _ issue: TrackingIssue) -> Bool

    /// Tells if at least one qualityIssue is present.
    ///
    /// - Returns: `true` if there is no quality TrackingIssue, `false` otherwise.
    func qualityIssuesIsEmpty() -> Bool

    /// Sets the current pitch value.
    ///
    /// Expressed as a signed percentage of the max pitch/roll setting (`maxPitchRoll`), in range [-100, 100].
    /// * -100 corresponds to a pitch angle of max pitch/roll towards ground (copter will fly forward)
    /// * 100 corresponds to a pitch angle of max pitch/roll towards sky (copter will fly backward)
    ///
    /// - Note: This value may be clamped if necessary, in order to respect the maximum supported physical tilt of
    /// the copter.
    ///
    /// - Parameter pitch: the new pitch value to set
    @objc(setPitch:)
    func set(pitch: Int)

    /// Sets the current roll value.
    ///
    /// Expressed as a signed percentage of the max pitch/roll setting (`maxPitchRoll`), in range [-100, 100].
    /// * -100 corresponds to a roll angle of max pitch/roll to the left (copter will fly left)
    /// * 100 corresponds to a roll angle of max pitch/roll to the right (copter will fly right)
    ///
    /// - Note: This value may be clamped if necessary, in order to respect the maximum supported physical tilt of
    /// the copter.
    ///
    /// - Parameter roll: the new roll value to set
    @objc(setRoll:)
    func set(roll: Int)

    /// Sets the current vertical speed value.
    ///
    /// Expressed as a signed percentage of the max vertical speed setting (`maxVerticalSpeed`), in range [-100, 100].
    /// * -100 corresponds to max vertical speed towards ground
    /// * 100 corresponds to max vertical speed towards sky
    ///
    /// - Parameter verticalSpeed: the new vertical speed value to set
    @objc(setVerticalSpeed:)
    func set(verticalSpeed: Int)

    /// Activates this piloting interface.
    ///
    /// If successful, it deactivates the current piloting interface and activate this one.
    ///
    /// - Returns: `true` on success, `false` if the piloting interface can't be activated
    func activate() -> Bool
}

/// :nodoc:
/// FollowMe piloting interface description
@objc(GSFollowMePilotingItfs)
public class FollowMePilotingItfs: NSObject, PilotingItfClassDesc {
    public typealias ApiProtocol = FollowMePilotingItf
    public let uid = PilotingItfUid.followMe.rawValue
    public let parent: ComponentDescriptor? = nil
}
