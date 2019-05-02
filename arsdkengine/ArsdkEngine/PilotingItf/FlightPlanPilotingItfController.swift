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
import GroundSdk

/// FlightPlan uploader specific part
protocol ArsdkFlightplanUploader: class {
    /// Configure the uploader
    ///
    /// - Parameter flightPlanPilotingItfController: the FPPilotingItfController
    func configure(flightPlanPilotingItfController: FlightPlanPilotingItfController)
    /// Reset the uploader
    ///
    func reset()
    /// Upload a given flight plan file on the drone.
    ///
    /// - Parameters:
    ///   - filepath: local path of the flight plan file
    ///   - completion: the completion callback (called on the main thread)
    ///   - success: true or false if the upload is done with success
    ///   - flightPlanUid: uid of the flightplan returned by the drone
    /// - Returns: a request that can be canceled
    func uploadFlightPlan(
        filepath: String, completion: @escaping (_ success: Bool, _ flightPlanUid: String?) -> Void) -> CancelableCore?
}

/// Return home piloting interface component controller class - with connexion through http
class HttpFlightPlanPilotingItfController: FlightPlanPilotingItfController {
    /// Constructor
    ///
    /// - Parameter activationController: activation controller that owns this piloting interface controller
    init(activationController: PilotingItfActivationController) {
        super.init(activationController: activationController, uploader: HttpFlightPlanUploader())
    }
}

/// Return home piloting interface component controller base class
class FlightPlanPilotingItfController: ActivablePilotingItfController {

    /// Flight plan directory on the drone
    static let remoteFlightPlanDir = "/"

    /// The piloting interface from which this object is the backend
    private var flightPlanPilotingItf: FlightPlanPilotingItfCore {
        return pilotingItf as! FlightPlanPilotingItfCore
    }

    /// Current remote uid of the Flight Plan file uploaded
    /// (can be a filePath if the drone supports ftp upload, or an unique id of the flight plan if the drone supports
    /// upload via http (REST API))
    private var remoteFlightPlanUid: String? {
        didSet {
            if remoteFlightPlanUid != oldValue {
                flightPlanPilotingItf.update(flightPlanFileIsKnown: remoteFlightPlanUid != nil)
            }
        }
    }

    /// Whether or not the flight plan is available on the drone
    private var flightPlanAvailable = false
    /// Whether a flight plan is currently playing.
    private var isPlaying = false
    /// Whether the flight plan should be restarted instead of resumed when the piloting interface can be activated
    private var shouldRestartFlightPlan = false
    /// Unavailability reasons of the drone.
    private var droneUnavailabilityReasons = Set<FlightPlanUnavailabilityReason>()
    /// Whether the flight plan is currently stopped
    private var isStopped = false
    /// Path of the file to upload.
    ///
    /// Used when the upload has to be delayed because we wait for the current flight plan to be paused.
    private var flightPlanPathToUpload: String?

    /// Delegate to upload the FlightPlan
    private var uploader: ArsdkFlightplanUploader

    fileprivate init(activationController: PilotingItfActivationController, uploader: ArsdkFlightplanUploader) {
        self.uploader = uploader
        super.init(activationController: activationController, sendsPilotingCommands: false)
        pilotingItf = FlightPlanPilotingItfCore(
            store: droneController.drone.pilotingItfStore, backend: self)
        // by default, flight plan file is missing
        updateUnavailabilityReasons()
    }

    override func requestActivation() {
        if shouldRestartFlightPlan && flightPlanPilotingItf.isPaused {
            sendStopFlightPlan()
        } else {
            shouldRestartFlightPlan = false
            sendStartFlightPlan()
        }
    }

    override func requestDeactivation() {
        sendPauseFlightPlan()
    }

    /// Drone is connected
    override func didConnect() {
        uploader.configure(flightPlanPilotingItfController: self)
        super.didConnect()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        uploader.reset()
        pilotingItf.unpublish()

        // reset values that does not have a meaning while disconnected
        flightPlanPilotingItf.update(isPaused: false).update(flightPlanFileIsKnown: false)
            .update(latestUploadState: .none).update(latestActivationError: .none).notifyUpdated()

        // super will call notifyUpdated
        super.didDisconnect()
    }

    /// Modifies the internal list of drone unavailability reasons
    ///
    /// - Parameters:
    ///   - reason: the reason
    ///   - isPresent: whether the reason is active or not
    private func modifyDroneUnavailabilityReasons(reason: FlightPlanUnavailabilityReason, isPresent: Bool) {
        if isPresent {
            droneUnavailabilityReasons.insert(reason)
        } else {
            droneUnavailabilityReasons.remove(reason)
        }
    }

    /// Updates the unavailability reasons of the controlled piloting interface
    /// - Note: caller is responsible to call the `notifiyUpdated()` function.
    private func updateUnavailabilityReasons() {
        var reasons: Set<FlightPlanUnavailabilityReason> = []
        if remoteFlightPlanUid == nil && !isPlaying {
            reasons.insert(.missingFlightPlanFile)
        }
        if !flightPlanAvailable {
            reasons.formUnion(droneUnavailabilityReasons)
        }
        flightPlanPilotingItf.update(unavailabilityReasons: reasons)
    }

    /// Updates whether the file is known on the controlled piloting interface.
    ///
    /// - Parameters:
    ///   - playingState: current flight plan playing state
    ///   - playedFile: current played flight plan name
    private func updateFileIsKnown(
        playingState: ArsdkFeatureCommonMavlinkstateMavlinkfileplayingstatechangedState, playedFile: String) {

        switch playingState {
        case .playing, .paused, .stopped:
            switch uploader {
            case is FtpFlightPlanUploader:
                if let remoteFilepath = remoteFlightPlanUid, !playedFile.hasSuffix(remoteFilepath) {
                    remoteFlightPlanUid = nil
                }
            case is HttpFlightPlanUploader :
                if playedFile != remoteFlightPlanUid {
                    remoteFlightPlanUid = nil
                }
                flightPlanPilotingItf.update(flightPlanFileIsKnown: remoteFlightPlanUid != nil)
            default:
                break
            }
        default:
            break
        }
    }

    /// Update the local availability of the flight plan
    func updateAvailability() {
        if !isPlaying {
            if (remoteFlightPlanUid != nil || flightPlanPathToUpload != nil) && flightPlanAvailable {
                notifyIdle()
            } else {
                notifyUnavailable()
            }
        }
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCommonFlightplanstateUid {
            ArsdkFeatureCommonFlightplanstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCommonMavlinkstateUid {
            ArsdkFeatureCommonMavlinkstate.decode(command, callback: self)
        }
    }
}

// MARK: - FlightPlanPilotingItfBackend
/// Extension of FlightPlanPilotingItfController that implements FlightPlanPilotingItfBackend
extension FlightPlanPilotingItfController: FlightPlanPilotingItfBackend {
    func activate(restart: Bool) -> Bool {
        shouldRestartFlightPlan = restart
        flightPlanPilotingItf.update(latestActivationError: .none).notifyUpdated()
        return droneController.pilotingItfActivationController.activate(pilotingItf: self)
    }

    func uploadFlightPlan(filepath: String) {
        // if the piloting interface is active, first deactivate it before uploading the file
        if self.canDeactivate {
            flightPlanPathToUpload = filepath
            self.requestDeactivation()
        } else {
            flightPlanPilotingItf.update(latestUploadState: .uploading).notifyUpdated()
            // uses the ftp or http uploader
            _ = uploader.uploadFlightPlan(filepath: filepath) { [weak self] success, flightPlanUid in
                if let `self` = self {
                    // whether the uploaded file is the same as the one that was previously played
                    var isSameUid = false
                    if success {
                        if self.remoteFlightPlanUid == flightPlanUid {
                            isSameUid = true
                        }
                        self.remoteFlightPlanUid = flightPlanUid
                    } else {
                        self.remoteFlightPlanUid = nil
                    }

                    self.flightPlanPilotingItf.update(latestUploadState: success ? .uploaded : .failed)
                        .update(isPaused: isSameUid)
                    self.updateUnavailabilityReasons()

                    if self.canDeactivate {
                        self.requestDeactivation()
                    } else {
                        self.updateAvailability()
                    }
                    self.flightPlanPilotingItf.notifyUpdated()
                }
            }
        }
    }
}

// MARK: - Send Commands
/// Extension of FlightPlanPilotingItfController for commands
extension FlightPlanPilotingItfController {
    private func sendStartFlightPlan() {
        sendCommand(ArsdkFeatureCommonMavlink.startEncoder(filepath: remoteFlightPlanUid, type: .flightplan))
    }

    private func sendPauseFlightPlan() {
        sendCommand(ArsdkFeatureCommonMavlink.pauseEncoder())
    }

    private func sendStopFlightPlan() {
        sendCommand(ArsdkFeatureCommonMavlink.stopEncoder())
    }
}

// MARK: - Receive Commands

extension FlightPlanPilotingItfController: ArsdkFeatureCommonFlightplanstateCallback {
    func onAvailabilityStateChanged(availabilitystate: UInt) {
        flightPlanAvailable = (availabilitystate == 1)
        updateUnavailabilityReasons()
        updateAvailability()
    }

    func onComponentStateListChanged(component: ArsdkFeatureCommonFlightplanstateComponentstatelistchangedComponent,
                                     state: UInt) {
        switch component {
        case .calibration:
            modifyDroneUnavailabilityReasons(reason: .droneNotCalibrated, isPresent: state == 0)
            updateUnavailabilityReasons()
        case .gps:
            modifyDroneUnavailabilityReasons(reason: .droneGpsInfoInacurate, isPresent: state == 0)
            updateUnavailabilityReasons()
        case .takeoff:
            modifyDroneUnavailabilityReasons(reason: .cannotTakeOff, isPresent: state == 0)
            updateUnavailabilityReasons()
        case .mavlinkFile:
            if state == 0 {
                flightPlanPilotingItf.update(latestActivationError: .incorrectFlightPlanFile)
            } else if flightPlanPilotingItf.latestActivationError == .incorrectFlightPlanFile {
                flightPlanPilotingItf.update(latestActivationError: .none)
            }
        case .waypointsbeyondgeofence:
            if state == 0 {
                flightPlanPilotingItf.update(latestActivationError: .waypointBeyondGeofence)
            } else if flightPlanPilotingItf.latestActivationError == .waypointBeyondGeofence {
                flightPlanPilotingItf.update(latestActivationError: .none)
            }
        case .cameraavailable:
            // TODO: add this unavailability reason in the API
            break
        case .sdkCoreUnknown:
            break
        }
        flightPlanPilotingItf.notifyUpdated()
    }
}

extension FlightPlanPilotingItfController: ArsdkFeatureCommonMavlinkstateCallback {
    func onMavlinkFilePlayingStateChanged(
        state: ArsdkFeatureCommonMavlinkstateMavlinkfileplayingstatechangedState,
        filepath: String!, type: ArsdkFeatureCommonMavlinkstateMavlinkfileplayingstatechangedType) {
        isPlaying = state == .playing
        updateFileIsKnown(playingState: state, playedFile: filepath)
        updateUnavailabilityReasons()
        switch state {
        case .playing:
            // only clear the latest mission item executed if the previous state was stopped.
            if isStopped {
                flightPlanPilotingItf.update(latestMissionItemExecuted: nil)
                isStopped = false
            }
            flightPlanPilotingItf.update(isPaused: false)
            notifyActive()
        case .stopped:
            isStopped = true

            // Only change the isPaused flag if there is no flight plan to upload
            if flightPlanPathToUpload == nil {
                flightPlanPilotingItf.update(isPaused: false)
            }
            updateAvailability()

            if shouldRestartFlightPlan {
                shouldRestartFlightPlan = false
                sendStartFlightPlan()
                flightPlanPilotingItf.notifyUpdated()
            } else {
                updateAvailability()
            }

            // if a flight plan should be uploaded
            if let flightPlanPathToUpload = flightPlanPathToUpload {
                uploadFlightPlan(filepath: flightPlanPathToUpload)
                self.flightPlanPathToUpload = nil
            }
        case .paused:
            isStopped = false

            // Only change the isPaused flag if there is no flight plan to upload
            if flightPlanPathToUpload == nil {
                flightPlanPilotingItf.update(isPaused: true)
            }
            updateAvailability()

            // if a flight plan should be uploaded
            if let flightPlanPathToUpload = flightPlanPathToUpload {
                uploadFlightPlan(filepath: flightPlanPathToUpload)
                self.flightPlanPathToUpload = nil
            }
        case .loaded:
            // This case is not handled because it is not supported by Anafi
            break
        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown mavlink state, skipping this event.")
            return
        }
    }

    func onMissionItemExecuted(idx: UInt) {
        flightPlanPilotingItf.update(latestMissionItemExecuted: Int(idx)).notifyUpdated()
    }
}
