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

/// DeviceComponentController specialization for the piloting interface that implements the Activable protocol
class ActivablePilotingItfController: DeviceComponentController {

    /// Returns the device controller as a drone controller
    var droneController: DroneController {
        return deviceController as! DroneController
    }

    /// The activable piloting interface from which this controller is the backend
    var pilotingItf: ActivablePilotingItfCore!

    /// `true` if the controller requires a piloting command loop when active
    let sendsPilotingCommands: Bool

    /// Whether or not the piloting itf can be activated
    var canActivate: Bool {
        return pilotingItf.state == .idle
    }

    /// Whether or not the piloting itf can be deactivated
    var canDeactivate: Bool {
        return pilotingItf.state == .active
    }

    /// Activation controller
    let activationController: PilotingItfActivationController

    /// Constructor
    ///
    /// - Parameters:
    ///   - activationController: activation controller that owns this piloting interface controller
    ///   - sendsPilotingCommands: true if the controller requires a piloting command loop when active
    init(activationController: PilotingItfActivationController, sendsPilotingCommands: Bool = false) {
        self.activationController = activationController
        self.sendsPilotingCommands = sendsPilotingCommands
        super.init(deviceController: activationController.droneController)
    }

    /// Drone is about to be forgotten
    override func willForget() {
        super.willForget()
        pilotingItf.unpublish()
    }

    /// Drone is connected
    override func didConnect() {
        super.didConnect()
        pilotingItf.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        notifyUnavailable()
        super.didDisconnect()
    }

    /// Notifies that the managed piloting interface is currently unavailable.
    func notifyUnavailable() {
        if pilotingItf.state != .unavailable {
            droneController.pilotingItfActivationController.onUnavailable(pilotingItf: self)
            pilotingItf.update(activeState: .unavailable)
        }
        pilotingItf.notifyUpdated()
    }

    /// Notifies that the managed piloting interface is currently available.
    func notifyIdle() {
        if pilotingItf.state != .idle {
            droneController.pilotingItfActivationController.onIdle(pilotingItf: self)
            pilotingItf.update(activeState: .idle)
        }
        pilotingItf.notifyUpdated()
    }

    /// Notifies that the managed piloting interface is currently active.
    func notifyActive() {
        if pilotingItf.state != .active {
            droneController.pilotingItfActivationController.onActive(pilotingItf: self)
            pilotingItf.update(activeState: .active)
        }
        pilotingItf.notifyUpdated()
    }

    // MARK: Methods that subclass must implement

    /// Requests activation of the managed piloting interface.
    ///
    /// Implementation **MUST NOT** check whether it is currently appropriate to activate the interface, but
    /// **MUST** take immediate action to activate it.
    func requestActivation() { }

    /// Requests deactivation of the managed piloting interface.
    ///
    /// Implementation **MUST NOT** check whether it is currently appropriate to deactivate the interface, but
    /// **MUST** take immediate action to deactivate it.
    @objc func requestDeactivation() { }
}

/// Extension of ActivablePilotingItfController that brings common setter to the piloting command
extension ActivablePilotingItfController {
    /// Sets the pitch value of the piloting command.
    final func setPitch(_ pitch: Int) {
        activationController.pitchDidChange(pitch, pilotingItf: self)
    }

    /// Sets the roll value of the piloting command.
    final func setRoll(_ roll: Int) {
        activationController.rollDidChange(roll, pilotingItf: self)
    }

    /// Sets the yaw value of the piloting command.
    final func setYaw(_ yaw: Int) {
        activationController.yawDidChange(yaw, pilotingItf: self)
    }

    /// Sets the gaz value of the piloting command.
    final func setGaz(_ gaz: Int) {
        activationController.gazDidChange(gaz, pilotingItf: self)
    }
}

extension ActivablePilotingItfController: ActivablePilotingItfBackend {
       func deactivate() -> Bool {
        return droneController.pilotingItfActivationController.deactivate(pilotingItf: self)
    }
}
