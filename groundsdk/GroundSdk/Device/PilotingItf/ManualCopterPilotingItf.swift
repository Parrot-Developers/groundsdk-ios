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

/// Action performed when `smartTakeOffLand()` is called.
@objc(GSSmartTakeOffLandAction)
public enum SmartTakeOffLandAction: Int, CustomStringConvertible {
    /// Take Off from ground.
    case takeOff

    /// Request the copter to get prepared for a thrown take off.
    case thrownTakeOff

    /// The drone is flying or taking off, or a thrown take off is in progress
    /// so action will be land.
    case land

    /// No action.
    case none

    /// Debug description.
    public var description: String {
        switch self {
        case .takeOff:              return "takeOff"
        case .thrownTakeOff:        return "thrownTakeOff"
        case .land:                 return "land"
        case .none:                 return "none"
        }
    }
}

/// Manual copter piloting interface.
/// Used to pilot manually a copter.
///
/// This piloting interface is the default one. This means that if you explicitly deactivate another
/// piloting interface, this one will be automatically activated. It also means that you can't explicitly deactivate
/// this piloting interface. To deactivate it, you have to activate another piloting interface.
///
/// This piloting interface can be retrieved by:
/// ```
/// drone.getPilotingItf(PilotingItfs.manualCopter)
/// ```
@objc(GSManualCopterPilotingItf)
public protocol ManualCopterPilotingItf: PilotingItf, ActivablePilotingItf {

    /// Maximum roll and pitch angle in degrees.
    ///
    /// This value defines the range used by set:pitch and set:roll functions, 100 correspond to an angle of
    /// maxPitchRoll value.
    var maxPitchRoll: DoubleSetting { get }

    /// Maximum roll and pitch velocity in degrees/second.
    ///
    /// This value sets the drone dynamic by changing the speed the drone will move to the requested roll/pitch.
    ///
    /// `nil` if not supported by the drone.
    var maxPitchRollVelocity: DoubleSetting? { get }

    /// Maximum vertical speed in meters/second.
    ///
    /// This value defines the range used by set:verticalSpeed, 100 correspond to a vertical speed of
    /// maxVerticalSpeed value.
    var maxVerticalSpeed: DoubleSetting { get }

    /// Maximum yaw angular speed in degrees/second.
    ///
    /// This value define the range used by set:yawRotationSpeed, 100 correspond to a yaw angular speed of
    /// maxYawRotationSpeed value.
    var maxYawRotationSpeed: DoubleSetting { get }

    /// Banked-turn mode.
    ///
    /// When enabled, the drone will use yaw values from the piloting command to infer with roll and pitch when the
    /// horizontal speed is not null.
    ///
    /// `nil` if not supported by the drone.
    var bankedTurnMode: BoolSetting? { get }

    /// Thrown take off settings.
    /// `nil` if not supported by the drone.
    var thrownTakeOffSettings: BoolSetting? { get }

    /// Whether the drone is ready to takeoff.
    var canTakeOff: Bool { get }

    /// Whether the drone is ready to land.
    var canLand: Bool { get }

    /// Activates this piloting interface.
    ///
    /// If successful, it deactivates the current piloting interface and activate this one.
    ///
    /// - Returns: `true` on success, `false` if the piloting interface can't be activated
    func activate() -> Bool

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

    /// Sets the yaw rotation speed value.
    ///
    /// Expressed as a signed percentage of the max yaw rotation speed setting (`maxYawRotationSpeed`), in range
    /// [-100, 100].
    /// * -100 corresponds to a counter-clockwise rotation of max yaw rotation speed
    /// * 100 corresponds to a clockwise rotation of max yaw rotation speed
    ///
    /// - Parameter yawRotationSpeed: the new yaw rotation speed value to set
    @objc(setYawRotationSpeed:)
    func set(yawRotationSpeed: Int)

    /// Sets the current vertical speed value.
    ///
    /// Expressed as a signed percentage of the max vertical speed setting (`maxVerticalSpeed`), in range [-100, 100].
    /// * -100 corresponds to max vertical speed towards ground
    /// * 100 corresponds to max vertical speed towards sky
    ///
    /// - Parameter verticalSpeed: the new vertical speed value to set
    @objc(setVerticalSpeed:)
    func set(verticalSpeed: Int)

    /// Requests the drone to hover.
    ///
    /// Put pitch and roll to 0.
    func hover()

    /// Requests the drone to take off.
    func takeOff()

    /// Requests the copter to get prepared for a thrown take off.
    ///
    /// - Note: Will only request it if `thrownTakeOffSettings` is `available`.
    func thrownTakeOff()

    /// Requests the copter to take off, to get prepared for a thrown take off,
    /// to cancel a thrown take off or to land,
    /// depending on its state and on the thrown take off setting.
    ///
    /// See `smartTakeOffLandAction` and `thrownTakeOffSettings`.
    func smartTakeOffLand()

    /// Action that will be performed if `smartTakeOffLand()` is called.
    var smartTakeOffLandAction: SmartTakeOffLandAction { get }

    /// Requests the drone to land.
    func land()

    /// Emergency motor cut out.
    ///
    /// - Note: Watch out, this will cut the motor immediately. If the drone was flying it will fall off.
    func emergencyCutOut()
}

/// :nodoc:
/// Manual copter piloting interface description
@objc(GSManualCopterPilotingItfs)
public class ManualCopterPilotingItfs: NSObject, PilotingItfClassDesc {
    public typealias ApiProtocol = ManualCopterPilotingItf
    public let uid = PilotingItfUid.manualCopter.rawValue
    public let parent: ComponentDescriptor? = nil
}
