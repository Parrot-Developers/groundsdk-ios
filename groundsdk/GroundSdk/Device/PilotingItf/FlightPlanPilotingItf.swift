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

/// Reason why this piloting interface is currently unavailable.
@objc(GSFlightPlanUnavailabilityReason)
public enum FlightPlanUnavailabilityReason: Int, CustomStringConvertible {
    /// Drone GPS accuracy is too weak.
    case droneGpsInfoInacurate
    /// Drone needs to be calibrated.
    case droneNotCalibrated
    /// No flight plan file uploaded.
    case missingFlightPlanFile
    /// Drone cannot take-off.
    /// This error can happen if the flight plan piloting interface is activated while the drone cannot take off.
    /// It can be for example if the drone is in emergency or has not enough battery to take off.
    case cannotTakeOff

    /// Debug description.
    public var description: String {
        switch self {
        case .droneGpsInfoInacurate:    return "droneGpsInfoInacurate"
        case .droneNotCalibrated:       return "droneNotCalibrated"
        case .missingFlightPlanFile:    return "missingFlightPlanFile"
        case .cannotTakeOff:            return "cannotTakeOff"
        }
    }
}

/// Activation error.
@objc(GSFlightPlanActivationError)
public enum FlightPlanActivationError: Int, CustomStringConvertible {
    /// No activation error.
    case none
    /// Incorrect flight plan file.
    case incorrectFlightPlanFile
    /// One or more waypoints are beyond the geofence.
    case waypointBeyondGeofence

    /// Debug description.
    public var description: String {
        switch self {
        case .none:                     return "none"
        case .incorrectFlightPlanFile:  return "incorrectFlightPlanFile"
        case .waypointBeyondGeofence:   return "waypointBeyondGeofence"
        }
    }
}

/// Flight Plan file upload state.
@objc(GSFlightPlanFileUploadState)
public enum FlightPlanFileUploadState: Int, CustomStringConvertible {
    /// No flight plan file has been uploaded yet.
    case none
    /// The flight plan file is currently uploading to the drone.
    case uploading
    /// The flight plan file has been successfully uploaded to the drone.
    case uploaded
    /// The flight plan file upload has failed.
    case failed

    /// Debug description.
    public var description: String {
        switch self {
        case .none:         return "none"
        case .uploading:    return "uploading"
        case .uploaded:     return "uploaded"
        case .failed:       return "failed"
        }
    }
}

/// Flight Plan piloting interface for drones.
///
/// Allows to make the drone execute predefined flight plans.
/// This piloting interface remains `.unavailable` until all `FlightPlanUnavailabilityReason` have been cleared:
///  - A Flight Plan file (i.e. a mavlink file) has been uploaded to the drone (see uploadFlightPlan(filepath:))
///  - The drone GPS location has been acquired
///  - The drone is properly calibrated
///  - The drone is in a state that allows it to take off
///
/// Then, when all those conditions hold, the interface becomes `.idle` and can be activated to begin or resume
/// Flight Plan execution, which can be paused by deactivating this piloting interface.
///
/// This piloting interface can be retrieved by:
/// ```
/// drone.getPilotingItf(flightPlan)
/// ```
public protocol FlightPlanPilotingItf: PilotingItf, ActivablePilotingItf {
    /// Latest flight plan file upload state.
    var latestUploadState: FlightPlanFileUploadState { get }

    /// Index of the latest mission item completed.
    var latestMissionItemExecuted: Int? { get }

    /// Set of reasons why this piloting interface is unavailable.
    ///
    /// Empty when state is `.idle` or `.active`.
    var unavailabilityReasons: Set<FlightPlanUnavailabilityReason> { get }

    /// Error raised during the latest activation.
    ///
    /// It is put back to `.none` as soon as `activate(restart:)` is called.
    var latestActivationError: FlightPlanActivationError { get }

    /// Whether the current flight plan on the drone is the latest one that has been uploaded from the application.
    var flightPlanFileIsKnown: Bool { get }

    /// Whether the flight plan is currently paused.
    ///
    /// If `true`, the restart parameter of `activate(restart:)` can be set to `false` to resume the flight plan instead
    /// of playing it from the beginning. If `isPaused` is `false,` this parameter will be ignored and the flight plan
    /// will be played from its beginning.
    ///
    /// When this piloting interface is deactivated, any currently playing flight plan will be paused.
    var isPaused: Bool { get }

    /// Uploads a Flight Plan file to the drone.
    ///
    /// When the upload ends, if all other necessary conditions hold (GPS location acquired, drone properly calibrated),
    /// then the interface becomes idle and the Flight Plan is ready to be executed.
    ///
    /// - Parameter filepath: local path of the file to upload
    func uploadFlightPlan(filepath: String)

    /// Activates this piloting interface and starts executing the uploaded flight plan.
    ///
    /// The interface should be `.idle` for this method to have effect.
    /// The flight plan is resumed if the `restart` parameter is false and `isPaused` is `true`.
    /// Otherwise, the flight plan is restarted from its beginning.
    ///
    /// If successful, it deactivates the current piloting interface and activate this one.
    ///
    /// - Parameter restart: `true` to force restarting the flight plan.
    ///                       If `isPaused` is `false`, this parameter will be ignored.
    /// - Returns: `true` on success, `false` if the piloting interface can't be activated
    func activate(restart: Bool) -> Bool
}

/// Flight Plan piloting interface for drones.
///
/// Allows to make the drone execute predefined flight plans.
/// This piloting interface remains `.unavailable` until all `FlightPlanUnavailabilityReason` have been cleared:
///  - A Flight Plan file (i.e. a mavlink file) has been uploaded to the drone (see uploadFlightPlan(filepath:))
///  - The drone GPS location has been acquired
///  - The drone is properly calibrated
///  - The drone is in a state that allows it to take off
///
/// Then, when all those conditions hold, the interface becomes `.idle` and can be activated to begin or resume
/// Flight Plan execution, which can be paused by deactivating this piloting interface.
///
/// This piloting interface can be retrieved by:
///
/// ```
// id<GSFlightPlanPilotingItf> fplan = (id<GSFlightPlanPilotingItf>)[drone getPilotingItf:GSPilotingItfs.flightPlan];
/// ```
/// - Note: This protocol is for Objective-C only. Swift must use the protocol `FlightPlanPilotingItf`.
@objc
public protocol GSFlightPlanPilotingItf: PilotingItf, ActivablePilotingItf {
    /// Latest flight plan file upload state.
    var latestUploadState: FlightPlanFileUploadState { get }

    /// Index of the latest mission item completed.
    ///
    /// Negative value when not available.
    @objc(latestMissionItemExecuted)
    var gsLatestMissionItemExecuted: Int { get }

    /// Error raised during the latest activation.
    ///
    /// It is put back to `.none` as soon as `activate(restart:)` is called.
    var latestActivationError: FlightPlanActivationError { get }

    /// Whether the current flight plan on the drone is the latest one that has been uploaded from the application.
    var flightPlanFileIsKnown: Bool { get }

    /// Whether the flight plan is currently paused.
    ///
    /// If `true`, the restart parameter of `activate(restart:)` can be set to `false` to resume the flight plan instead
    /// of playing it from the beginning. If `isPaused` is false, this parameter will be ignored and the flight plan
    /// will be played from its beginning.
    ///
    /// When this piloting interface is deactivated, any currently playing flight plan will be paused.
    var isPaused: Bool { get }

    /// Uploads a Flight Plan file to the drone.
    /// When the upload ends, if all other necessary conditions hold (GPS location acquired, drone properly calibrated),
    /// then the interface becomes idle and the Flight Plan is ready to be executed.
    ///
    /// - Parameter filepath: local path of the file to upload
    func uploadFlightPlan(filepath: String)

    /// Activates this piloting interface and starts executing the uploaded flight plan.
    ///
    /// The interface should be `.idle` for this method to have effect.
    /// The flight plan is resumed if the `restart` parameter is false and `isPaused` is `true`.
    /// Otherwise, the flight plan is restarted from its beginning.
    ///
    /// If successful, it deactivates the current piloting interface and activate this one.
    ///
    /// - Parameter restart: `true` to force restarting the flight plan.
    ///                      If `isPaused` is false, this parameter will be ignored.
    /// - Returns: `true` on success, `false` if the piloting interface can't be activated
    func activate(restart: Bool) -> Bool

    /// Tells whether a given reason is partly responsible of the unavailable state of this piloting interface.
    ///
    /// - Parameter reason: the reason to query
    /// - Returns: `true` if the piloting interface is partly unavailable because of the given reason.
    func hasUnavailabilityReason(_ reason: FlightPlanUnavailabilityReason) -> Bool
}

/// :nodoc:
/// FlightPlan piloting interface description
@objc(GSFlightPlanPilotingItfs)
public class FlightPlanPilotingItfs: NSObject, PilotingItfClassDesc {
    public typealias ApiProtocol = FlightPlanPilotingItf
    public let uid = PilotingItfUid.flightPlan.rawValue
    public let parent: ComponentDescriptor? = nil
}
