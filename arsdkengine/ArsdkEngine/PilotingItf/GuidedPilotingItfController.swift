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

/// Guided piloting interface component controller base class
class GuidedPilotingItfController: ActivablePilotingItfController, GuidedPilotingItfBackend {

    /// The guidedDirective requested.
    /// Allows a delayed sending to the drone (when the interface will be activated) and
    /// stores the information of the initial query that will be used in the FinishedFlightInfo
    public var pendingGuidedDirectiveRequested: GuidedDirective?

    var currentGuidedDirective: GuidedDirective? {
        didSet {
            // set the value in the interface
            guidedPilotingItf.update(currentGuidedDirective: currentGuidedDirective)
        }
    }

    /// the initial Relative Move Request (used for information in the `latestFinishedFlightInfo`)
    var initialRelativeMove: RelativeMoveDirective?
    /// For successive Relative Move requests, the 'n-1' request is saved.
    /// This information will be used in the `latestFinishedFlightInfo` when a Relative move is interrupted by a new one
    var previousRelativeMove: RelativeMoveDirective?

    /// The piloting interface from which this object is the delegate
    internal var guidedPilotingItf: GuidedPilotingItfCore {
        return pilotingItf as! GuidedPilotingItfCore
    }

    /// Constructor
    ///
    /// - Parameter activationController: activation controller that owns this piloting interface controller
    init(activationController: PilotingItfActivationController) {
        super.init(activationController: activationController, sendsPilotingCommands: false)
        pilotingItf = GuidedPilotingItfCore(store: droneController.drone.pilotingItfStore, backend: self)
    }

    override func didDisconnect() {
        super.didDisconnect()
        resetDirectives()
        // the unavailable state will be set in unpublish
        pilotingItf.unpublish()
    }

    override func didConnect() {
        // the notify will be done in publish
        pilotingItf.publish()
    }

    override func requestDeactivation() {
        // remove any pending directive
        pendingGuidedDirectiveRequested = nil
        // send a stop if a current directive is active
        if let currentGuidedDirective = currentGuidedDirective {
            switch currentGuidedDirective.guidedType {
            case .absoluteLocation:
                // send a stop command
                sendCancelMoveToCommand()
            case .relativeMove:
                // send a stop command (== a zero move)
                sendCancelRelativeMoveCommand()
            }
        }
        resetDirectives()
    }

    override func requestActivation() {
        // check if we have a pending command received before activation sate
        if let pendingGuidedDirectiveRequested = self.pendingGuidedDirectiveRequested {
            switch pendingGuidedDirectiveRequested.guidedType {
            case .absoluteLocation:
                sendMoveToLocationCommand(locationDirective: pendingGuidedDirectiveRequested as! LocationDirective)
            case .relativeMove:
                sendRelativeMoveCommand(
                    relativeMoveDirective: pendingGuidedDirectiveRequested as! RelativeMoveDirective)
            }
            self.pendingGuidedDirectiveRequested = nil
        }
    }

    /// clean all directives (pending, current, initialRelative and previousRelative)
    func resetDirectives() {
        currentGuidedDirective = nil
        pendingGuidedDirectiveRequested = nil
        initialRelativeMove = nil
        previousRelativeMove = nil
    }

    /// Starts a guided flight.
    ///
    /// - Parameter guidedDirective: a move Location or a Relative Move directive
    func moveWithGuidedDirective(guidedDirective: GuidedDirective) {
        // Check if the piloting interface is active
        if pilotingItf!.state == .active {
            pendingGuidedDirectiveRequested = nil
            // send the command now
            switch guidedDirective.guidedType {
            case .absoluteLocation:
                let locationDirective = guidedDirective as! LocationDirective
                sendMoveToLocationCommand(locationDirective: locationDirective)
            case .relativeMove:
                 let relativeMoveDirective = guidedDirective as! RelativeMoveDirective
                sendRelativeMoveCommand(relativeMoveDirective: relativeMoveDirective)
            }
        } else {
            // remember the command and wait for the active state
            pendingGuidedDirectiveRequested = guidedDirective
            _ = droneController.pilotingItfActivationController.activate(pilotingItf: self)
        }
    }

    /// Send the command for a MoveTo location.
    /// Subclass must override this function to send the drone specific command.
    ///
    /// - Parameter locationDirective: the directive that describes the moveTo Location
    func sendMoveToLocationCommand(locationDirective: LocationDirective) {}

    /// Send the command to cancel a MoveTo location.
    /// Subclass must override this function to send the drone specific command.
    func sendCancelMoveToCommand() {}

    /// Send the command to cancel a Relative Move.
    /// Subclass must override this function to send the drone specific command.
    func sendCancelRelativeMoveCommand() {}

    /// Send the command for a Relative move.
    /// Subclass must override this function to send the drone specific command.
    ///
    /// - Parameter relativeMoveDirective: the directive that describes the relative move
    func sendRelativeMoveCommand(relativeMoveDirective: RelativeMoveDirective) {}

}
