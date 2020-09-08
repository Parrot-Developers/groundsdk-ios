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

/// Reasons why a guided piloting may be unavailable.
@objc(GSGuidedIssue)
public enum GuidedIssue: Int, CustomStringConvertible {

    /// Drone is not flying.
    case droneNotFlying

    /// Drone is not calibrated.
    case droneNotCalibrated

    /// Drone gps is not fixed or has a poor accuracy.
    case droneGpsInfoInaccurate

    /// Drone is outside of the geofence.
    case droneOutOfGeofence

    /// Drone is too close to the ground.
    case droneTooCloseToGround

    /// Drone is above max altitude.
    case droneAboveMaxAltitude

    /// Debug description.
    public var description: String {
        switch self {
        case .droneNotFlying:                   return "droneNotFlying"
        case .droneNotCalibrated:               return "droneNotCalibrated"
        case .droneGpsInfoInaccurate:           return "droneGpsInfoInaccurate"
        case .droneOutOfGeofence:               return "droneOutOfGeofence"
        case .droneTooCloseToGround:            return "droneTooCloseToGround"
        case .droneAboveMaxAltitude:            return "droneAboveMaxAltitude"
        }
    }
}

/// Guided move type.
@objc(GSGuidedType)
public enum GuidedType: Int, CustomStringConvertible {
    /// Moves the drone to an absolute position and altitude.
    case absoluteLocation

    /// Moves the drone to a position, relative to its current position and altitude.
    case relativeMove

    /// Debug description.
    public var description: String {
        switch self {
        case .absoluteLocation:     return "absoluteLocation"
        case .relativeMove:         return "relativeMove"
        }
    }
}

/// Orientation that takes the drone during a `LocationDirective`.
public enum OrientationDirective: Equatable, CustomStringConvertible {

    /// Orientation for which the drone won't change its heading.
    case none

    /// Orientation for which the drone will make a rotation to look in direction of the given location before
    /// moving to the location.
    case toTarget

    /// Orientation for which the drone will orientate itself to the given heading before moving to the location.
    case headingStart(Double)

    /// Orientation for which the drone will orientate itself to the given heading while moving to the location.
    case headingDuring(Double)

    /// Equatable.
    static public func == (lhs: OrientationDirective, rhs: OrientationDirective) -> Bool {
        switch (lhs, rhs) {
        case (let .headingStart(headingL), let .headingStart(headingR)):
            return headingL == headingR

        case (let .headingDuring(headingL), let .headingDuring(headingR)):
            return headingL == headingR

        case (.none, .none):
            return true

        case (.toTarget, .toTarget):
            return true

        default:
            return false
        }
    }

    /// Debug description.
    public var description: String {
        switch self {
        case .none: return "none"
        case .toTarget: return "toTarget"
        case .headingDuring(let heading): return "headingDuring \(heading)"
        case .headingStart(let heading): return "headingStart \(heading)"
        }
    }
}

/// Requested speed for the flight.
/// When attached to a flight `Directive`, allows to specify the desired horizontal, vertical and
/// rotation speed values for the flight.
/// - Note:The provided values are considered maximum values: the drone will try its best to respect the
/// specified speeds, but the actual speeds may be lower depending on the situation.
/// Specifying incoherent speed values with regard to the specified location target will result in a failed move.
@objc(GSSpeed)
public class GuidedPilotingSpeed: NSObject {
    /// Horizontal speed, in meters per second.
    public let horizontalSpeed: Double

    /// Vertical speed, in meters per second.
    public let verticalSpeed: Double

    /// Yaw rotation speed, in degrees per second.
    public let yawRotationSpeed: Double

    /// Constructor
    public init(horizontalSpeed: Double, verticalSpeed: Double, yawRotationSpeed: Double) {
        self.horizontalSpeed = horizontalSpeed
        self.verticalSpeed = verticalSpeed
        self.yawRotationSpeed = yawRotationSpeed
        super.init()
    }
}

/// A guided flight directive, of any GuidedType.
/// Optionally, desired speed values for the move may also be specified.
@objcMembers
@objc(GSGuidedDirective)
public class GuidedDirective: NSObject {
    /// Guided flight type.
    public var guidedType: GuidedType

    /// Guided flight speed.
    public var speed: GuidedPilotingSpeed?

    /// Constructor
    public init(guidedType: GuidedType, speed: GuidedPilotingSpeed?) {
        self.guidedType = guidedType
        self.speed = speed
        super.init()
    }
}

/// Directive for a move to an absolute Location ("Move To").
@objcMembers
@objc(GSLocationDirective)
public class LocationDirective: GuidedDirective {

    /// Latitude of the location (in degrees) to reach.
    public internal (set) var latitude: Double

    /// Longitude of the location (in degrees) to reach.
    public internal (set) var longitude: Double

    /// Altitude above sea level (in meters) to reach.
    public internal (set) var altitude: Double

    /// Orientation of the guided flight.
    public internal (set) var orientation: OrientationDirective

    /// Orientation type of the guided flight for Objective-C.
    @objc(orientationDirective)
    public var gsOrientationDirective: GSOrientationDirective {
        switch self.orientation {
        case .none:
            return .none
        case .toTarget:
            return .toTarget
        case .headingStart:
            return .headingStart
        case .headingDuring:
            return .headingDuring
        }
    }

    /// Orientation heading of the guided flight for Objective-C.
    @objc(heading)
    public var gsHeading: Double {
        switch self.orientation {
        case .none, .toTarget:
            return 0
        case .headingStart(let heading):
            return heading
        case .headingDuring(let heading):
            return heading
        }
    }

    /// Constructor.
    ///
    /// - Parameters:
    ///   - latitude: latitude destination
    ///   - longitude: longitude destination
    ///   - altitude: altitude destination
    ///   - orientation: orientation that takes the drone during a `LocationDirective`
    ///   - speed: guided flight speed. `nil` if no speed directive.
    public init(latitude: Double, longitude: Double, altitude: Double, orientation: OrientationDirective,
                speed: GuidedPilotingSpeed?) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.orientation = orientation
        super.init(guidedType: .absoluteLocation, speed: speed)
    }

    /// Equatable concordance
    public override func isEqual(_ object: Any?) -> Bool {
        if let directive = object as? LocationDirective {
            return (self.altitude == directive.altitude &&
            self.longitude == directive.longitude &&
            self.latitude == directive.latitude &&
            self.orientation == directive.orientation)
        }
        return false
    }

    /// Debug description.
    override public var description: String {
        return "lat(\(latitude))-lon(\(longitude))-alt(\(altitude))-ori(\(orientation))"
    }
}

/// Directive for a move to a relative position ("Move By").
@objcMembers
@objc(GSRelativeMoveDirective)
public class RelativeMoveDirective: GuidedDirective {

    /// Desired displacement along the drone front axis, in meters.
    /// A negative value means a backward move.
    public var forwardComponent: Double

    /// Desired displacement along the drone right axis, in meters.
    /// A negative value means a move to the left.
    public var rightComponent: Double

    /// Desired displacement along the down axis, in meters.
    /// A negative value means an upward move.
    public var downwardComponent: Double

    /// Desired relative rotation of heading, in degrees (clockwise).
    /// The rotation is performed before the move.
    public var headingRotation: Double

    /// Constructor.
    ///
    /// - Parameters:
    ///   - forwardComponent: desired displacement along the drone front axis, in meters
    ///   - rightComponent: desired displacement along the drone right axis, in meters
    ///   - downwardComponent: desired displacement along the down axis, in meters
    ///   - headingRotation: desired relative rotation of heading, in degrees (clockwise)`
    ///   - speed: guided flight speed. `nil` if no speed directive.
    public init(forwardComponent: Double, rightComponent: Double, downwardComponent: Double,
                headingRotation: Double, speed: GuidedPilotingSpeed?) {
        self.forwardComponent = forwardComponent
        self.rightComponent = rightComponent
        self.downwardComponent = downwardComponent
        self.headingRotation = headingRotation
        super.init(guidedType: .relativeMove, speed: speed)
    }

    /// Debug description.
    public override var description: String {
        let dx = String(format: "%.2f", forwardComponent)
        let dy = String(format: "%.2f", rightComponent)
        let dz = String(format: "%.2f", downwardComponent)
        let headingString = String(format: "%.2f", headingRotation)
        return "dx: \(dx) dy: \(dy) dz: \(dz) heading: \(headingString)"
    }

    /// Equatable concordance
    public override func isEqual(_ object: Any?) -> Bool {
        if let directive = object as? RelativeMoveDirective {
            return (self.forwardComponent == directive.forwardComponent &&
            self.rightComponent == directive.rightComponent &&
            self.downwardComponent == directive.downwardComponent &&
            self.headingRotation == directive.headingRotation)
        }
        return false
    }

}

/// Information about a finished guided flight.
@objc(GSFinishedFlightInfo)
public protocol FinishedFlightInfo {

    /// Guided flight type.
    var guidedType: GuidedType { get }

    /// Whether the guided flight succeeded.
    /// `true` if the guided flight succeeded, `false` otherwise.
    var wasSuccessful: Bool { get }
}

/// Information about a finished location guided flight.
/// Describes the initial directive and the final state of the flight.
@objc(GSFinishedLocationFlightInfo)
public protocol FinishedLocationFlightInfo: FinishedFlightInfo {

    /// Parameters of the guided flight directive (these parameters are given by the drone).
    var directive: LocationDirective { get }
}

/// Information about a finished relative move guided flight.
/// Describes the initial directive, the move that the drone actually did and the
/// final state of the flight.
@objc(GSFinishedRelativeMoveFlightInfo)
public protocol FinishedRelativeMoveFlightInfo: FinishedFlightInfo {

    /// RInitial guided flight directive.
    var directive: RelativeMoveDirective? { get }

    /// Finished displacement along the drone front axis, in meters.
    /// A negative value means a backward move.
    var actualForwardComponent: Double { get }

    /// Finished displacement along the drone right axis, in meters.
    /// A negative value means a move to the left.
    var actualRightComponent: Double { get }

    /// Finished displacement along the down axis, in meters.
    /// A negative value means an upward move.
    var actualDownwardComponent: Double { get }

    /// Finished relative rotation of heading, in degrees (clockwise).
    var actualHeadingRotation: Double { get }
}

/// Guided piloting interface.
///
/// This interface used is to request a relative (move 'by') or absolute (move 'to') displacement of the drone.
///
/// This piloting interface can be retrieved by:
/// ```
/// drone.getPilotingItf(PilotingItfs.guided)
/// ```
public protocol GuidedPilotingItf: PilotingItf, ActivablePilotingItf {

    /// Starts a guided flight.
    /// Moves the drone according to the specified movement directive
    ///
    /// This interface will change to `active` when the drone starts, and then to
    /// `idle` when the drone reaches its destination or is stopped.
    /// It also becomes `idle` in case of error.
    ///
    /// If this method is called while the previous guided flight is still in progress, it will be stopped
    /// immediately and the new guided flight is started.
    ///
    /// In case of drone disconnection, the guided flight is interrupted.
    /// - Parameter directive: movement directive
    func move(directive: GuidedDirective)

    /// Current guided flight directive if there's a guided flight in progress, `nil` otherwise.
    ///
    /// It can be either a `LocationDirective` or a `RelativeMoveDirective`.
    /// The flight parameters have the values returned by the drone.
    var currentDirective: GuidedDirective? { get }

    /// Latest terminated guided flight information if any, `nil` otherwise.
    ///
    /// It can be either a `FinishedLocationFlightInfo` or a `FinishedRelativeMoveFlightInfo`.
    /// The flight parameters have the values returned by the drone.
    /// It indicates the final state of the flight and, for a relative move, the
    /// move that the drone actually did.
    var latestFinishedFlightInfo: FinishedFlightInfo? { get }

    /// Set of reasons why this piloting interface is unavailable.
    ///
    /// Empty when state is `.idle` or `.active`.
    var unavailabilityReasons: Set<GuidedIssue>? { get }

    /// Starts a location guided flight.
    /// Moves the drone to a specified location, and rotates heading to the specified value.
    ///
    /// This interface will change to `active` when the drone starts, and then to
    /// `idle` when the drone reaches its destination or is stopped.
    /// It also becomes `idle` in case of error.
    ///
    /// If this method is called while the previous guided flight is still in progress, it will be stopped
    /// immediately and the new guided flight is started.
    ///
    /// In case of drone disconnection, the guided flight is interrupted.
    ///
    /// - Parameters:
    ///   - latitude: latitude of the location (in degrees) to reach
    ///   - longitude: longitude of the location (in degrees) to reach
    ///   - altitude: altitude above sea level (in meters) to reach
    ///   - orientation: orientation of the location guided flight
    ///   - heading: heading for the orientation (`headingStart`or `'headingDuring`)
    @available(*, deprecated, message: "Use func move(directive: GuidedDirective) instead")
    func moveToLocation(latitude: Double, longitude: Double, altitude: Double, orientation: OrientationDirective)

    /// Starts a relative move guided flight.
    ///
    /// Rotates heading by a given angle, and then moves the drone to a relative position.<br>
    /// Moves are relative to the current drone orientation (drone's reference).<br>
    /// Also note that the given rotation will not modify the move (i.e. moves are always rectilinear).
    ///
    /// This interface will change to `active` when the drone starts, and then to
    /// `idle` when the drone reaches its destination or is stopped.
    /// It also becomes `idle` in case of error.
    ///
    /// If this method is called while the previous guided flight is still in progress, it will be stopped
    /// immediately and the new guided flight is started.
    ///
    /// In case of drone disconnection, the guided flight is interrupted.
    ///
    /// - Parameters:
    ///   - forwardComponent: desired displacement along the front axis, in meters. Negative value for a backward move
    ///   - rightComponent: desired displacement along the right axis, in meters. Negative value for a left move
    ///   - downwardComponent: desired displacement along the down axis, in meters. Negative value for an upward move
    ///   - headingRotation: desired relative rotation of heading, in degrees (clockwise)
    @available(*, deprecated, message: "Use func move(directive: GuidedDirective) instead")
    func moveToRelativePosition(
        forwardComponent: Double, rightComponent: Double, downwardComponent: Double, headingRotation: Double)
}

// MARK: Objective-C API

/// Objective-C version of `OrientationDirective`.
/// - Note: This enum is for Objective-C only. Swift must use the enum `OrientationDirective`.
@objc(GSOrientationDirective)
public enum GSOrientationDirective: Int {

    /// Orientation for which the drone won't change its heading.
    case none

    /// Orientation for which the drone will make a rotation to look in direction of the given location before
    /// moving to the location.
    case toTarget

    /// Orientation for which the drone will orientate itself to the given heading before moving to the location.
    case headingStart

    /// Orientation for which the drone will orientate itself to the given heading while moving to the location.
    case headingDuring
}

/// Guided piloting interface.
/// - Note: This protocol is for Objective-C only. Swift must use the protocol `GuidedPilotingItf`.
@objc
public protocol GSGuidedPilotingItf: PilotingItf, ActivablePilotingItf {
    /// Starts a guided flight.
    /// Moves the drone according to the specified movement directive
    ///
    /// This interface will change to `active` when the drone starts, and then to
    /// `idle` when the drone reaches its destination or is stopped.
    /// It also becomes `idle` in case of error.
    ///
    /// If this method is called while the previous guided flight is still in progress, it will be stopped
    /// immediately and the new guided flight is started.
    ///
    /// In case of drone disconnection, the guided flight is interrupted.
    /// - Parameter directive: movement directive
    func move(directive: GuidedDirective)

    /// Current guided flight directive if there's a guided flight in progress, `nil` otherwise.
    ///
    /// It can be either a `LocationDirective` or a `RelativeMoveDirective`.
    /// The flight parameters have the values returned by the drone.
    var currentDirective: GuidedDirective? { get }

    /// Latest terminated guided flight information if any, `nil` otherwise.
    ///
    /// It can be either a `FinishedLocationFlightInfo` or a `FinishedRelativeMoveFlightInfo`.
    /// The flight parameters have the values returned by the drone.
    /// It indicates the final state of the flight and, for a relative move, the
    /// move that the drone actually did.
    var latestFinishedFlightInfo: FinishedFlightInfo? { get }

    /// Tells whether a given reason is partly responsible of the unavailable state of this piloting interface.
    ///
    /// - Parameter reason: the reason to query
    /// - Returns: `true` if the piloting interface is partly unavailable because of the given reason.
    func hasUnavailabilityReason(_ reason: GuidedIssue) -> Bool

    /// Starts a location guided flight.
    /// Moves the drone to a specified location, and rotates heading to the specified value.
    ///
    /// This interface will change to `active` when the drone starts, and then to
    /// `idle` when the drone reaches its destination or is stopped.
    /// It also becomes `idle` in case of error.
    ///
    /// If this method is called while the previous guided flight is still in progress, it will be stopped
    /// immediately and the new guided flight is started.
    ///
    /// In case of drone disconnection, the guided flight is interrupted.
    ///
    /// - Parameters:
    ///   - latitude: latitude of the location (in degrees) to reach
    ///   - longitude: longitude of the location (in degrees) to reach
    ///   - altitude: altitude above sea level (in meters) to reach
    ///   - orientation: orientation of the location guided flight
    ///   - heading: heading for the orientation (`headingStart`or `'headingDuring`)
    @available(*, deprecated, message: "Use func move(directive: GuidedDirective) instead")
    func moveToLocation(latitude: Double, longitude: Double, altitude: Double, orientation: GSOrientationDirective,
                        heading: Double)

    /// Start sa relative move guided flight.
    ///
    /// Rotates heading by a given angle, and then moves the drone to a relative position.
    /// Moves are relative to the current drone orientation (drone's reference).
    /// Also note that the given rotation will not modify the move (i.e. moves are always rectilinear).
    ///
    /// This interface will change to `active` when the drone starts, and then to
    /// `idle` when the drone reaches its destination or is stopped.
    /// It also becomes `idle` in case of error.
    ///
    /// If this method is called while the previous guided flight is still in progress, it will be stopped
    /// immediately and the new guided flight is started.
    ///
    /// In case of drone disconnection, the guided flight is interrupted.
    ///
    /// - Parameters:
    ///   - forwardComponent: desired displacement along the front axis, in meters. Negative value for a backward move
    ///   - rightComponent: desired displacement along the right axis, in meters. Negative value for a left move
    ///   - downwardComponent: desired displacement along the down axis, in meters. Negative value for an upward move
    ///   - headingRotation: desired relative rotation of heading, in degrees (clockwise)
    @available(*, deprecated, message: "Use func move(directive: GuidedDirective) instead")
    func moveToRelativePosition(
        forwardComponent: Double, rightComponent: Double, downwardComponent: Double, headingRotation: Double)
}

/// :nodoc:
/// Guided piloting interface description
@objc(GSGuidedPilotingItfs)
public class GuidedPilotingItfs: NSObject, PilotingItfClassDesc {
    public typealias ApiProtocol = GuidedPilotingItf
    public let uid = PilotingItfUid.guided.rawValue
    public let parent: ComponentDescriptor? = nil
}
