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

/// Implementation of a FinishedLocationFlightInfo
public class FinishedLocationFlightInfoCore: FinishedLocationFlightInfo, CustomStringConvertible, Equatable {

    public let guidedType = GuidedType.absoluteLocation

    public let wasSuccessful: Bool

    /// Retrieves the parameters of the guided flight directive (these parameters are given by the drone).
    public var directive: LocationDirective { return _directive }
    /// Internal implementation of location flight directive.
    private let _directive: LocationDirective

    /// Constructor
    ///
    /// - Parameters:
    ///   - directive: the location directive done
    ///   - wasSuccessful: true if the location directive was successful
    public init(directive: LocationDirective, wasSuccessful: Bool) {
        self._directive = directive
        self.wasSuccessful = wasSuccessful
    }

    /// Debug description.
    public var description: String {
        return "Location: success:\(wasSuccessful) {\(directive)}"
    }

    /// Equatable concordance
    public static func == (lhs: FinishedLocationFlightInfoCore, rhs: FinishedLocationFlightInfoCore) -> Bool {
        return lhs.wasSuccessful == rhs.wasSuccessful &&
            lhs._directive == rhs._directive
    }
}

/// Implementation of a FinishedRelativeMoveFlightInfo
public class FinishedRelativeMoveFlightInfoCore: FinishedRelativeMoveFlightInfo, CustomStringConvertible, Equatable {

    public let guidedType = GuidedType.relativeMove

    public let wasSuccessful: Bool

    /// Retrieves the finished displacement along the drone front axis, in meters.
    public let actualForwardComponent: Double

    /// Retrieves the finished displacement along the drone right axis, in meters.
    public let actualRightComponent: Double

    /// Retrieves the finished displacement along the down axis, in meters.
    public let actualDownwardComponent: Double

    /// Retrieves the finished relative rotation of heading, in degrees (clockwise).
    public let actualHeadingRotation: Double

    /// Retrieves the initial guided flight directive.
    public var directive: RelativeMoveDirective? { return _directive }
    /// Internal implementation of relative mode directive.
    public var _directive: RelativeMoveDirective?

    /// Constructor
    ///
    /// - Parameters:
    ///   - wasSuccessful: true if the relative move directive was successful
    ///   - directive: the initial relative move directive requested
    ///   - actualForwardComponent: forward movement done
    ///   - actualRightComponent: right movement done
    ///   - actualDownwardComponent: downward movement done
    ///   - actualHeadingRotation: heading rotation done
    public init(wasSuccessful: Bool, directive: RelativeMoveDirective?, actualForwardComponent: Double,
                actualRightComponent: Double, actualDownwardComponent: Double, actualHeadingRotation: Double) {
        self.wasSuccessful = wasSuccessful
        self._directive = directive
        self.actualForwardComponent = actualForwardComponent
        self.actualRightComponent = actualRightComponent
        self.actualDownwardComponent = actualDownwardComponent
        self.actualHeadingRotation = actualHeadingRotation
    }

    /// Equatable concordance
    public static func == (lhs: FinishedRelativeMoveFlightInfoCore, rhs: FinishedRelativeMoveFlightInfoCore) -> Bool {
        return lhs.wasSuccessful == rhs.wasSuccessful &&
            lhs.actualForwardComponent == rhs.actualForwardComponent &&
            lhs.actualRightComponent == rhs.actualRightComponent &&
            lhs.actualDownwardComponent == rhs.actualDownwardComponent &&
            lhs.actualHeadingRotation == rhs.actualHeadingRotation &&
            lhs._directive == rhs._directive
    }

    /// Debug description.
    public var description: String {
        let dx = String(format: "%.2f", actualForwardComponent)
        let dy = String(format: "%.2f", actualRightComponent)
        let dz = String(format: "%.2f", actualDownwardComponent)
        let headingString = String(format: "%.2f", actualHeadingRotation)
        return "Relative: success:\(wasSuccessful) actual{" +
            "dx:(\(dx)),dy(\(dy)),dz(\(dz))," +  "heading(\(headingString))}" +
            ((directive != nil) ?  "directive{\(directive!))}" : "directive{nil}")
    }
}

/// Guided piloting interface backend.
public protocol GuidedPilotingItfBackend: ActivablePilotingItfBackend {

    /// Starts a guided flight.
    func moveWithGuidedDirective(guidedDirective: GuidedDirective)

}

/// Internal GuidedPilotingItf implementation
public class GuidedPilotingItfCore: ActivablePilotingItfCore, GuidedPilotingItf {

    public private (set) var currentDirective: GuidedDirective?

    public private (set) var latestFinishedFlightInfo: FinishedFlightInfo?

    public var unavailabilityReasons: Set<GuidedIssue>? {
        return _unavailabilityReasons
    }

    /// Unavailability reasons
    private var _unavailabilityReasons: Set<GuidedIssue>?

    /// Constructor
    ///
    /// - Parameters:
    ///   - store: store where this interface will be stored
    ///   - backend: GuidedPilotingItf backend
    public init(store: ComponentStoreCore, backend: GuidedPilotingItfBackend) {
        super.init(desc: PilotingItfs.guided, store: store, backend: backend)
    }

    /// Starts a guided flight.
    public func move(directive: GuidedDirective) {
        if state != .unavailable {
            guidedBackend.moveWithGuidedDirective(guidedDirective: directive)
        }
    }

    /// Super class backend as GuidedPilotingItfBackend
    public var guidedBackend: GuidedPilotingItfBackend {
        return backend as! GuidedPilotingItfBackend
    }

    /// Starts a location guided flight.
    /// Deprecated method. Only for compatibility.
    public func moveToLocation(latitude: Double, longitude: Double, altitude: Double,
                               orientation: OrientationDirective) {
        let locationDirective = LocationDirective(latitude: latitude,
                                                   longitude: longitude,
                                                   altitude: altitude,
                                                   orientation: orientation, speed: nil)
        move(directive: locationDirective)
    }

    /// Starts a relative guided flight.
    /// Deprecated method. Only for compatibility.
    public func moveToRelativePosition(
        forwardComponent: Double, rightComponent: Double, downwardComponent: Double, headingRotation: Double) {
        let relativeDirective = RelativeMoveDirective(forwardComponent: forwardComponent,
                                                      rightComponent: rightComponent,
                                                      downwardComponent: downwardComponent,
                                                      headingRotation: headingRotation, speed: nil)
        move(directive: relativeDirective)
    }
}

/// Backend callback methods
extension GuidedPilotingItfCore {

    /// Change current active guided Directive
    ///
    /// - Parameter updatedGuidedDirective: new activeGuidedDirective
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        currentGuidedDirective updatedGuidedDirective: GuidedDirective?) -> GuidedPilotingItfCore {

        if let updatedGuidedDirective = updatedGuidedDirective {

            switch updatedGuidedDirective.guidedType {
            case .absoluteLocation:
                let currentDirectiveAsLocation = currentDirective as? LocationDirective
                let updatedLocationDirective = updatedGuidedDirective as!LocationDirective

                if currentDirectiveAsLocation != updatedLocationDirective {
                    currentDirective = updatedLocationDirective
                    markChanged()
                }

            case .relativeMove:
                let currentDirectiveAsRelative = currentDirective as? RelativeMoveDirective
                let updatedRelativeDirective = updatedGuidedDirective as! RelativeMoveDirective

                if currentDirectiveAsRelative != updatedRelativeDirective {
                    currentDirective = updatedRelativeDirective
                    markChanged()
                }
            }
        } else {
            if currentDirective != nil {
                // updatedGuidedDirective is nil and a current exists
                currentDirective = nil
                markChanged()
            }
        }

        return self
    }

    /// Change the latest finished FlightInfo
    ///
    /// - Parameter updatedLatestFinishedFlightInfo: the latest finished FlightInfo
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        latestFinishedFlightInfo updatedLatestFinishedFlightInfo: FinishedFlightInfo?) -> GuidedPilotingItfCore {

        // is the FinishedFlightInfo a location move ?
        if let finishedFlightInfo = updatedLatestFinishedFlightInfo as? FinishedLocationFlightInfoCore {

            // if we already have a finished Location Move, we check that the updated value is different
            if let precedFinishedFlightInfo = latestFinishedFlightInfo as? FinishedLocationFlightInfoCore {
                // check if a old value exists and if it is the same (FinishedLocationFlightInfo with the same values)
                guard precedFinishedFlightInfo != finishedFlightInfo else {
                    return self
                }
            }
        }

        // is the FinishedFlightInfo a Relative move ?
        if let finishedFlightInfo = updatedLatestFinishedFlightInfo as? FinishedRelativeMoveFlightInfoCore {

            // if we already have a Relative Move, we check that the updated value is different
            if let precedFinishedFlightInfo = latestFinishedFlightInfo as? FinishedRelativeMoveFlightInfoCore {
                // check if a old value exists with the same values
                guard precedFinishedFlightInfo != finishedFlightInfo else {
                    return self
                }
            }
        }

        // update the latest Flight Info
        if !(updatedLatestFinishedFlightInfo == nil && latestFinishedFlightInfo != nil) {
            markChanged()
            latestFinishedFlightInfo = updatedLatestFinishedFlightInfo
        }
        return self
    }

    /// Updates the unavailability reasons.
    ///
    /// - Parameter unavailabilityReasons: new set of unavailability reasons
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        unavailabilityReasons newValue: Set<GuidedIssue>?) -> GuidedPilotingItfCore {

        if _unavailabilityReasons != newValue {
            _unavailabilityReasons = newValue
            markChanged()
        }
        return self
    }
}

// MARK: Objective-C API
/// - Note: this protocol is for Objective-C only. Swift must use the protocol `GuidedPilotingItf`
extension GuidedPilotingItfCore: GSGuidedPilotingItf {

    /// Starts a location guided flight.
    public func moveToLocation(
        latitude: Double, longitude: Double, altitude: Double, orientation: GSOrientationDirective, heading: Double) {
        var swiftOrientation: OrientationDirective
        switch orientation {
        case .none:
            swiftOrientation = .none
        case .toTarget:
            swiftOrientation = .toTarget
        case .headingStart:
            swiftOrientation = .headingStart(heading)
        case .headingDuring:
            swiftOrientation = .headingDuring(heading)
        }
        // call the swift method in interface
        moveToLocation(latitude: latitude, longitude: longitude, altitude: altitude, orientation: swiftOrientation)
    }

    public func hasUnavailabilityReason(_ reason: GuidedIssue) -> Bool {
        return unavailabilityReasons != nil ? unavailabilityReasons!.contains(reason) : false
    }
}
