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

/// FlightPlanPilotingItf backend protocol
public protocol FlightPlanPilotingItfBackend: ActivablePilotingItfBackend {
    /// Activate this piloting interface and starts executing the uploaded flight plan.
    ///
    /// - Parameter restart: `true` to force restarting the flight plan.
    /// - Returns: `true` on success, false if the piloting interface can't be activated
    func activate(restart: Bool) -> Bool

    /// Upload a given flight plan file on the drone.
    ///
    /// - Parameter filepath: local path of the flight plan file
    func uploadFlightPlan(filepath: String)
}

/// Core implementation of the FlightPlanPilotingItf
public class FlightPlanPilotingItfCore: ActivablePilotingItfCore, FlightPlanPilotingItf {

    private(set) public var latestUploadState = FlightPlanFileUploadState.none
    private(set) public var latestMissionItemExecuted: Int?
    private(set) public var unavailabilityReasons = Set<FlightPlanUnavailabilityReason>()
    private(set) public var latestActivationError = FlightPlanActivationError.none
    private(set) public var flightPlanFileIsKnown = false
    private(set) public var isPaused = false

    /// Super class backend as FlightPlanPilotingItfBackend
    private var flightPlanBackend: FlightPlanPilotingItfBackend {
        return backend as! FlightPlanPilotingItfBackend
    }

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: store where this interface will be stored
    ///    - backend: ReturnHomePilotingItf backend
    public init(store: ComponentStoreCore, backend: FlightPlanPilotingItfBackend) {
        super.init(desc: PilotingItfs.flightPlan, store: store, backend: backend)
    }

    public func activate(restart: Bool) -> Bool {
        if state == .idle {
            return flightPlanBackend.activate(restart: restart)
        }
        return false
    }

    /// Uploads a Flight Plan file to the drone.
    /// When the upload ends, if all other necessary conditions hold (GPS location acquired, drone properly calibrated),
    /// then the interface becomes idle and the Flight Plan is ready to be executed.
    ///
    /// - Parameter filepath: local path of the file to upload
    ///
    /// - Note: See [Parrot FlightPlan Mavlink documentation](https://developer.parrot.com/docs/mavlink-flightplan).
    public func uploadFlightPlan(filepath: String) {
        flightPlanBackend.uploadFlightPlan(filepath: filepath)
    }
}

/// Backend callback methods
extension FlightPlanPilotingItfCore {
    /// Updates the latest upload state.
    ///
    /// - Parameter latestUploadState: new latest upload state
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        latestUploadState newValue: FlightPlanFileUploadState) -> FlightPlanPilotingItfCore {

        if latestUploadState != newValue {
            latestUploadState = newValue
            markChanged()
        }
        return self
    }

    /// Updates the latest mission item executed.
    ///
    /// - Parameter latestUploadState: new latest mission item executed.
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(latestMissionItemExecuted newValue: Int?) -> FlightPlanPilotingItfCore {
        if latestMissionItemExecuted != newValue {
            latestMissionItemExecuted = newValue
            markChanged()
        }
        return self
    }

    /// Updates the unavailability reasons.
    ///
    /// - Parameter unavailabilityReasons: new set of unavailability reasons
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        unavailabilityReasons newValue: Set<FlightPlanUnavailabilityReason>) -> FlightPlanPilotingItfCore {

        if unavailabilityReasons != newValue {
            unavailabilityReasons = newValue
            markChanged()
        }
        return self
    }

    /// Updates the latest activation error.
    ///
    /// - Parameter latestActivationError: new latest activation error
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        latestActivationError newValue: FlightPlanActivationError) -> FlightPlanPilotingItfCore {

        if latestActivationError != newValue {
            latestActivationError = newValue
            markChanged()
        }
        return self
    }

    /// Updates the fact that the flight plan file is known.
    ///
    /// - Parameter flightPlanFileIsKnown: true if the flight plan file is known, false otherwise
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(flightPlanFileIsKnown newValue: Bool) -> FlightPlanPilotingItfCore {
        if flightPlanFileIsKnown != newValue {
            flightPlanFileIsKnown = newValue
            markChanged()
        }
        return self
    }

    /// Updates the fact that the flight plan is paused.
    ///
    /// - Parameter isPaused: true if the flight plan is currently paused, false otherwise
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(isPaused newValue: Bool) -> FlightPlanPilotingItfCore {
        if isPaused != newValue {
            isPaused = newValue
            markChanged()
        }
        return self
    }
}

/// Extension of FlightPlanPilotingItfCore that adds support of the ObjC API
extension FlightPlanPilotingItfCore: GSFlightPlanPilotingItf {
    public var gsLatestMissionItemExecuted: Int {
        return latestMissionItemExecuted ?? -1
    }

    public func hasUnavailabilityReason(_ reason: FlightPlanUnavailabilityReason) -> Bool {
        return unavailabilityReasons.contains(reason)
    }
}
