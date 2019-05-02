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

/// LookAt piloting interface component controller for the f,00000or the Follow feature based drones
class FollowFeatureFollowMePilotingItf: FollowFeatureTrackingPilotingItf, FollowMePilotingItfBackend {

    /// Mode requested in the pilotingItf
    private var followMode: FollowMode = .geographic

    /// The piloting interface from which this object is the delegate
    private var followMePilotingItf: FollowMePilotingItfCore {
        return pilotingItf as! FollowMePilotingItfCore
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
        pilotingItf = FollowMePilotingItfCore(store: droneController.drone.pilotingItfStore, backend: self)
        trackingModeUsed = [.geographic, .relative, .leash]

        // set default settings
        followMePilotingItf.update(followMode: followMode)
    }

    /// Update the followMode
    func set(followMode newFollowMode: FollowMode) -> Bool {
        followMode = newFollowMode
        if pilotingItf.state == .active {
            // Change the the followModeStting (updating). It will be validated when the drone will change the mode
            sendStartFollowCommand(mode: newFollowMode)
            return true
        } else {
            followMePilotingItf.update(followMode: followMode).notifyUpdated()
            return false
        }
    }

    // MARK: - Commands

    /// Start a Follow Me with a specific mode
    ///
    /// - Parameter mode: desired follow mode
    func sendStartFollowCommand(mode: FollowMode) {
        if let droneMode =  mode.arsdkValue {
            sendCommand(ArsdkFeatureFollowMe.startEncoder(mode: droneMode))
        }
    }

    override func didConnect() {
        // before publishing the component, update the supported modes
        let supportedModes = Set(supportedArsdkModes.map { FollowMode(fromArsdk: $0) }.compactMap { $0 })
        followMePilotingItf.update(supportedFollowModes: supportedModes)
        super.didConnect()
    }

    override func didDisconnect() {
        super.didDisconnect()
        followMePilotingItf.update(followBehavior: nil).notifyUpdated()
        // allways update the followMode (this setting may be "updating" )
        followMePilotingItf.update(followMode: followMode)
    }

    /// Start a follow Me with all its params set to the default params.
    /// Sending this command will stop other running followMe.
    override func sendStartTrackingCommand() {
        sendStartFollowCommand(mode: followMode)
    }

    /// Stop Follow
    override func sendStopTrackingCommand() {
        // check if the drone is in FollowMode (senCommand "stop" only for follow modes)
        guard trackingModeUsed!.contains(trackingSharing.latestModeReceived) else {
            return
        }
        sendCommand(ArsdkFeatureFollowMe.stopEncoder())
    }
}

// MARK: - Follow Callbacks
/// TargetTracker - FollowMe Feature decode callback implementation
extension FollowFeatureFollowMePilotingItf {

    func onState(
        mode: ArsdkFeatureFollowMeMode, behavior: ArsdkFeatureFollowMeBehavior,
        animation: ArsdkFeatureFollowMeAnimation, animationAvailableBitField: UInt) {

        // shares the latest mode received
        trackingSharing.latestModeReceived = mode

        if let newFollowMode = FollowMode(fromArsdk: mode) {
            followMode = newFollowMode
        }
        // allways update the followMode (this setting may be "updating" )
        followMePilotingItf.update(followMode: followMode)

        let newRunnigStatus = (trackingModeUsed!.contains(mode) && (behavior == .follow || behavior == .lookAt))

        if newRunnigStatus {
            // interface should be active (we are in FollowMe)
            // update the behavior
            switch behavior {
            case .follow:
                followMePilotingItf.update(followBehavior: .following)
            case .lookAt:
                followMePilotingItf.update(followBehavior: .stationary)
            default:
                break
            }
        } else {
            // interface should not be active (we are not in FollowMe)
            followMePilotingItf.update(followBehavior: nil)
        }

        trackingIsRunning = newRunnigStatus
        followMePilotingItf.notifyUpdated()
    }
}

// MARK: - Extensions

/// Extension that add conversion from/to arsdk enum
extension FollowMode: ArsdkMappableEnum {

    static let arsdkMapper = Mapper<FollowMode, ArsdkFeatureFollowMeMode>([
        .geographic: .geographic,
        .relative: .relative,
        .leash: .leash])
}
