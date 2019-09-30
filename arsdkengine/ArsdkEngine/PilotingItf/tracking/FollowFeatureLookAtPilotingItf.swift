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

/// LookAt piloting interface component controller for the Follow feature based drones
class FollowFeatureLookAtPilotingItf: FollowFeatureTrackingPilotingItf, LookAtPilotingItfBackend {

    /// The piloting interface from which this object is the delegate
    private var lookAtPilotingItf: LookAtPilotingItfCore {
        return pilotingItf as! LookAtPilotingItfCore
    }

    /// Shared last known state of the tracking function at the drone level
    private var trackingSharing: FollowFeatureTrackingSharing

    /// Constructor
    ///
    /// - Parameters:
    ///   - activationController: activation controller that owns this piloting interface controller
    ///   - trackingSharing: Shared last known state of the tracking function at the drone level
    init(activationController: PilotingItfActivationController, trackingSharing: FollowFeatureTrackingSharing ) {
        self.trackingSharing = trackingSharing
        super.init(activationController: activationController)
        pilotingItf = LookAtPilotingItfCore(store: droneController.drone.pilotingItfStore, backend: self)
        trackingModeUsed = [.lookAt]
    }

    // MARK: - Commands

    /// Start a LookAt with all its params set to the default params.
    /// Sending this command will stop other running followMe.
    override func sendStartTrackingCommand() {
        sendCommand(ArsdkFeatureFollowMe.startEncoder(mode: .lookAt))
    }

    /// Stop LookAt
    override func sendStopTrackingCommand() {
        // check if the drone is in LookAt mode (senCommand "stop" only for lookAt mode)
        guard trackingModeUsed!.contains(trackingSharing.latestModeReceived) else {
            return
        }
        sendCommand(ArsdkFeatureFollowMe.stopEncoder())
    }
}

// MARK: - Follow Callbacks
/// TargetTracker - FollowMe Feature decode callback implementation. This extension overrides some functions of the
/// ArsdkFeatureFollowMeCallback extension implemented in the super class.
extension FollowFeatureLookAtPilotingItf {

    override func onState(
        mode: ArsdkFeatureFollowMeMode, behavior: ArsdkFeatureFollowMeBehavior,
        animation: ArsdkFeatureFollowMeAnimation, animationAvailableBitField: UInt) {

        // shares the latest mode received
        trackingSharing.latestModeReceived = mode

        trackingIsRunning = (mode == .lookAt && behavior == .lookAt)
    }
}
