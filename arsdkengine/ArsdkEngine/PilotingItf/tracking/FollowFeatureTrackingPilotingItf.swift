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

/// Tracking piloting interface component controller for the for the Follow feature based drones. This class is the
/// base class for Tracking and FollowMe controllers
class FollowFeatureTrackingPilotingItf: ActivablePilotingItfController {

    /// Struct to store and add the different (bitfields / Set<TrackingIssue>) received for the tracking type
    private struct IssuesStorage {
        /// Dictionary to store by mode (ArsdkFeatureFollowMeMode as key) the received issues
        private var receivedIssues = [ArsdkFeatureFollowMeMode: Set<TrackingIssue>]()

        /// Convert a tracking issue bitfield in a set of TrackingIssue
        ///
        /// - Parameter fromBitField: bitfield (ArsdkFeatureFollowMeInputBitField)
        /// - Returns: the set
        private func setOfIssues(fromBitField: UInt) -> Set<TrackingIssue> {
            var returnSet = Set<TrackingIssue>()
            let invertedBitField = ~fromBitField
            ArsdkFeatureFollowMeInputBitField.forAllSet(in: invertedBitField) { followMeInput in
                switch followMeInput {
                case .droneCalibrated:
                    returnSet.insert(.droneNotCalibrated)
                case .droneGpsGoodAccuracy:
                    returnSet.insert(.droneGpsInfoInaccurate)
                case .targetGpsGoodAccuracy:
                    returnSet.insert(.targetGpsInfoInaccurate)
                case .targetBarometerOk:
                    returnSet.insert(.targetBarometerInfoInaccurate)
                case .droneFarEnough:
                    returnSet.insert(.droneTooCloseToTarget)
                case .droneHighEnough:
                    returnSet.insert(.droneTooCloseToGround)
                case .imageDetection:
                    returnSet.insert(.targetDetectionInfoMissing)
                case .droneCloseEnough:
                    returnSet.insert(.droneTooFarFromTarget)
                case .targetGoodSpeed:
                    returnSet.insert(.targetHorizontalSpeedKO)
                    returnSet.insert(.targetVerticalSpeedKO)
                case .sdkCoreUnknown:
                    ULog.w(.tag, "Unknown ArsdkFeatureFollowMeInputBitField, skipping this value.")
                }
            }
            return returnSet
        }

        /// All issues received (union)
        var value: Set<TrackingIssue> {
            return Set(receivedIssues.values.flatMap { $0 })
        }

        /// Converts a bitfield in a Set<TrackingIssue> and stores the result for the specified mode
        ///
        /// - Parameters:
        ///   - mode: Follow mode received from the drone
        ///   - bitfield: bitfield (ArsdkFeatureFollowMeInputBitField)
        /// - Returns: returns self for chaining
        @discardableResult mutating func setIssues(mode: ArsdkFeatureFollowMeMode, bitfield: UInt) -> IssuesStorage {
            receivedIssues[mode] = setOfIssues(fromBitField: bitfield)
            return self
        }
    }
    /// Modes used to filter the received information from the drone. Only information received in this set of modes
    /// will be processed. By default, this set is nil, the subclass must set a value in this set in order to track
    /// the events
    var trackingModeUsed: Set<ArsdkFeatureFollowMeMode>?

    /// Set of supported modes for this piloting interface.
    private(set) var supportedArsdkModes: Set<ArsdkFeatureFollowMeMode> = []

    /// The piloting interface from which this object is the delegate
    private var trackingPilotingItf: TrackingPilotingItfCore {
        return pilotingItf as! TrackingPilotingItfCore
    }

    /// The set of reasons that preclude this piloting interface from being available at present.
    private var availabilityIssues = Set<TrackingIssue>() {
         didSet {
            if availabilityIssues != oldValue {
                trackingPilotingItf.update(availabilityIssues: availabilityIssues)
                updateState()
            }
        }
    }

    /// Internal storage for availabilityIssues
    private var requirementsStorage = IssuesStorage()

    /// Alerts about issues that currently hinders optimal behavior of this interface.
    public private(set) var qualityIssues = Set<TrackingIssue>() {
        didSet {
            if qualityIssues != oldValue {
                trackingPilotingItf.update(qualityIssues: qualityIssues)
            }
        }
    }

    /// Internal storage for qualityIssues
    private var improvementsStorage = IssuesStorage()

    /// true or false if the Tracking Is Running (the interface should be .active)
    ///
    /// - Note: subclasses must set this value
    var trackingIsRunning = false {
        didSet {
            if trackingIsRunning != oldValue {
                updateState()
            }
        }
    }

    /// Whether the drone is flying
    private var isFlying = false {
        didSet {
            if isFlying != oldValue {
                // add or remove the "not flying" cause in availabilityIssues
                updateAvailabilityIssues(withDroneIssues: availabilityIssues)
            }
        }
    }

    /// Constructor
    ///
    /// - Parameter activationController: activation controller that owns this piloting interface controller
    init(activationController: PilotingItfActivationController) {
        super.init(activationController: activationController, sendsPilotingCommands: true)
    }

    override func didDisconnect() {
        super.didDisconnect()
        // the unavailable state will be set in unpublish
        pilotingItf.unpublish()
    }

    override func willConnect() {
        super.willConnect()
        updateAvailabilityIssues(withDroneIssues: availabilityIssues)
    }

    override func didConnect() {
        updateState()
        pilotingItf.publish()
    }

    override func requestActivation() {
        sendStartTrackingCommand()
    }

    override func requestDeactivation() {
        sendStopTrackingCommand()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureFollowMeUid {
            ArsdkFeatureFollowMe.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3PilotingstateUid {
            ArsdkFeatureArdrone3Pilotingstate.decode(command, callback: self)
        }
    }

    /// Updates the state of the piloting interface.
    ///
    /// If the drone is not flying the interface state is set to .unavailable
    /// Otherwise, the state of the interface is defined based on Tracking status and availability
    private func updateState() {
        if !isFlying {
            notifyUnavailable()
        } else {
            if !availabilityIssues.isEmpty {
                notifyUnavailable()
            } else if trackingIsRunning {
                notifyActive()
            } else {
                notifyIdle()
            }
        }
    }

    /// Add the member .droneNotFlying in a given Set<TrackingIssue> if the drone is not flying, and set the result in
    /// the availabilityIssues property
    ///
    /// - Parameter fromSet: origin TrackingIssue Set
    private func updateAvailabilityIssues(withDroneIssues droneIssues: Set<TrackingIssue>) {
        var newAvailabilityIssues = droneIssues
        if !isFlying {
            newAvailabilityIssues.insert(.droneNotFlying)
        } else {
            newAvailabilityIssues.remove(.droneNotFlying)
        }
        availabilityIssues = newAvailabilityIssues
    }

    // MARK: - Commands Subclass can override these functions

    /// Start a Tracking (with all its params set to the default params.)
    /// Sending this command will stop other running tracking
    func sendStartTrackingCommand() {}

    /// Stop current Tracking
    func sendStopTrackingCommand() {}
}

// MARK: - TrackingPilotingItfBackend
extension FollowFeatureTrackingPilotingItf: TrackingPilotingItfBackend {

    func set(pitch: Int) {
        setPitch(pitch)
    }

    func set(roll: Int) {
        setRoll(roll)
    }

    func set(verticalSpeed: Int) {
        setGaz(verticalSpeed)
    }

    func activate() -> Bool {
        return droneController.pilotingItfActivationController.activate(pilotingItf: self)
    }
}

// MARK: - Follow Callbacks
/// TargetTracker - FollowMe Feature decode callback implementation
extension FollowFeatureTrackingPilotingItf: ArsdkFeatureFollowMeCallback {

    func onModeInfo(mode: ArsdkFeatureFollowMeMode, missingRequirementsBitField: UInt, improvementsBitField: UInt) {
        // check for which interface this object is used
        guard let trackingModeUsed = trackingModeUsed, trackingModeUsed.contains(mode) else {
            return
        }

        if !connected {
            supportedArsdkModes.insert(mode)
        }

        qualityIssues = improvementsStorage.setIssues(mode: mode, bitfield: improvementsBitField).value

        requirementsStorage.setIssues(mode: mode, bitfield: missingRequirementsBitField)
        // possibly add the non flying issue
        updateAvailabilityIssues(withDroneIssues: requirementsStorage.value)
        pilotingItf.notifyUpdated()
    }

    // onState() event implementation. This function will be overrided in derived classes.
    func onState(
        mode: ArsdkFeatureFollowMeMode, behavior: ArsdkFeatureFollowMeBehavior,
        animation: ArsdkFeatureFollowMeAnimation, animationAvailableBitField: UInt) {
    }
}

// MARK: - ArsdkFeatureArdrone3PilotingstateCallback
extension FollowFeatureTrackingPilotingItf: ArsdkFeatureArdrone3PilotingstateCallback {
    /// Piloting State decode callback implementation
    func onFlyingStateChanged(state: ArsdkFeatureArdrone3PilotingstateFlyingstatechangedState) {
        switch state {
        case .landed, .emergency, .usertakeoff, .motorRamping, .takingoff, .landing, .emergencyLanding:
            isFlying = false

        case .hovering, .flying:
            isFlying = true

        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown flying state, skipping this event.")
            return
        }
    }
}
