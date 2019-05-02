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
import CoreLocation

/// Home reachability.
///
/// Describes whether the return point can be reached by the drone or not.
@objc(GSHomeReachability)
public enum HomeReachability: Int, CustomStringConvertible {
    /// Home reachability is unknown.
    case unknown
    /// Home is reachable.
    case reachable
    /// The drone has planned an automatic safety return. Return Home will start after `autoTriggerDelay`. This delay
    /// of the RTH is calculated so that the return trip can be made before the battery is emptied.
    case warning
    /// Home is still reachable but won't be if return home is not triggered now. If return home is running, cancelling
    /// it will probably make the home not reachable.
    case critical
    /// Home is not reachable.
    case notReachable

    /// Debug description.
    public var description: String {
        switch self {
        case .unknown:      return "unknown"
        case .reachable:    return "reachable"
        case .warning:      return "warning"
        case .critical:     return "critical"
        case .notReachable: return "notReachable"
        }
    }
}

/// Return home destination target.
@objc(GSReturnHomeTarget)
public enum ReturnHomeTarget: Int, CustomStringConvertible {
    /// Return to take-off position.
    case takeOffPosition
    /// Return to current controller position.
    case controllerPosition
    /// Return to latest tracked target position during/after FollowMe piloting interface is/has been activated.
    /// See `TargetTracker` peripheral and `FollowMePilotingItf`
    case trackedTargetPosition

    /// Debug description.
    public var description: String {
        switch self {
        case .takeOffPosition:       return "takeOffPosition"
        case .controllerPosition:    return "controllerPosition"
        case .trackedTargetPosition: return "trackedTargetPosition"
        }
    }
}

/// Reason why return home has been started or stopped.
@objc(GSReturnHomeReason)
public enum ReturnHomeReason: Int, CustomStringConvertible {
    /// Return home is not active.
    case none
    /// Return home requested by user.
    case userRequested
    /// Returning home because the connection was lost.
    case connectionLost
    /// Returning home because the power level is low.
    case powerLow
    /// Return home is finished and is not active anymore.
    case finished

    /// Debug description.
    public var description: String {
        switch self {
        case .none:             return "none"
        case .userRequested:    return "userRequested"
        case .connectionLost:   return "connectionLost"
        case .powerLow:         return "powerLow"
        case .finished:         return "finished"
        }
    }
}

/// Preferred return home target. Drone will select this target if all conditions for it are met.
@objc(GSReturnHomePreferredTarget)
public protocol ReturnHomePreferredTarget {
    /// Tells if the setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }
    /// Preferred return home target. Drone will choose the selected target if all condition to use it are met.
    var target: ReturnHomeTarget { get set }
}

/// Piloting interface used to make the drone return to home.
///
/// This piloting interface can be retrieved by:
/// ```
/// drone.getPilotingItf(PilotingItfs.returnHome)
/// ```
@objc(GSReturnHomePilotingItf)
public protocol ReturnHomePilotingItf: PilotingItf, ActivablePilotingItf {

    /// Reason why the return home is active or not.
    var reason: ReturnHomeReason { get }

    /// Current home location, `nil` if unknown.
    var homeLocation: CLLocation? { get }

    /// Current return home target. May be different from the one selected by preferredTarget if the requirement
    /// of the selected target are not met.
    var currentTarget: ReturnHomeTarget { get }

    /// If current target is `TakeOffPosition`, indicates if the first GPS fix was made before or after takeoff.
    /// If the first fix was made after take off, the drone will return at this first fix position that
    /// may be different from the takeoff position
    var gpsWasFixedOnTakeOff: Bool { get }

    /// Return home target settings, to select if the drone should return to its take-off position or to the
    /// current pilot position.
    var preferredTarget: ReturnHomePreferredTarget { get }

    /// Minimum return home altitude in meters, relative to the take off point. If the drone is below this altitude
    /// when starting its return home, it will first reach the minimum altitude. If it is higher than this minimum
    /// altitude, it will operate its return home at its actual.
    /// `nil` if not supported by the drone.
    var minAltitude: DoubleSetting? { get }

    /// Delay before starting return home when the controller connection is lost, in seconds.
    var autoStartOnDisconnectDelay: IntSetting { get }

    /// Estimation of the possibility for the drone to reach its return point.
    var homeReachability: HomeReachability { get }

    /// Delay in seconds before the drone starts an automatic return home when `homeReachability` is `.warning`,
    /// meaningless otherwise.
    /// This delay is computed by the drone to allow it to reach its home position before the battery is empty.
    var autoTriggerDelay: TimeInterval { get }

    /// Activates this piloting interface.
    ///
    /// If successful, it deactivates the current piloting interface and activate this one.
    ///
    /// - Returns: `true` on success, `false` if the piloting interface can't be activated
    func activate() -> Bool

    /// Cancels any current auto trigger.
    /// If `homeReachability` is `.warning`, this cancels the planned return home.
    func cancelAutoTrigger()
}

/// :nodoc:
/// Return home piloting interface description
@objc(GSReturnHomePilotingItfs)
public class ReturnHomePilotingItfs: NSObject, PilotingItfClassDesc {
    public typealias ApiProtocol = ReturnHomePilotingItf
    public let uid = PilotingItfUid.returnHome.rawValue
    public let parent: ComponentDescriptor? = nil
}
