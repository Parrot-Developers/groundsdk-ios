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

/// Coordinates activation and deactivation of the various activable piloting interface of a drone.
class PilotingItfActivationController {

    /// Drone controller
    private(set) unowned var droneController: DroneController

    /// Encoder of the piloting command
    let pilotingCommandEncoder: PilotingCommandEncoder

    /// Default piloting interface
    /// Should not be set outside the constructor
    private(set) var defaultPilotingItf: ActivablePilotingItfController!

    /// Currently active piloting interface. Null if there is no active piloting interface.
    private var currentPilotingItf: ActivablePilotingItfController? {
        didSet {
            if currentPilotingItf != oldValue {
                if let current = currentPilotingItf, current.sendsPilotingCommands {
                    pilotingCommandEncoder.reset()
                    registerInNoAckCommandLoop()
                } else {
                    unregisterInNoAckCommandLoop()
                }
            }
        }
    }

    /// Piloting interface to activate after deactivation of the current one.
    private var nextPilotingItf: ActivablePilotingItfController?

    /// Whether or not the drone is connected
    private var isConnected = false

    /// Keep a reference to the piloting Encoder registered in the "noAck command loop". This ref is used to
    /// unsubscribe later the encoder from the NoAckCommandLoop
    private var pilotingEncoderRegistered: RegisteredNoAckCmdEncoder?

    /// Constructor
    ///
    /// - Parameters:
    ///     - droneController: drone controller that uses this activation controller
    ///     - pilotingCommandEncoder: piloting command encoder
    ///     - defaultPilotingItfFactory: drone controller that uses this activation controller
    init(droneController: DroneController, pilotingCommandEncoder: PilotingCommandEncoder,
         defaultPilotingItfFactory: ((PilotingItfActivationController) -> ActivablePilotingItfController)) {
        self.droneController = droneController
        self.pilotingCommandEncoder = pilotingCommandEncoder
        self.defaultPilotingItf = defaultPilotingItfFactory(self)
    }

    /// Activates the piloting interface of the given controller.
    ///
    /// - Parameter pilotingItf: piloting interface controller whose interface must be activated
    /// - Returns: true if the operation could be initiated, otherwise false
    func activate(pilotingItf: ActivablePilotingItfController) -> Bool {
        if pilotingItf != currentPilotingItf && pilotingItf.canActivate {
            if let currentPilotingItf = currentPilotingItf {
                if currentPilotingItf.canDeactivate {
                    nextPilotingItf = pilotingItf
                    currentPilotingItf.requestDeactivation()
                    return true
                }
            } else {
                pilotingItf.requestActivation()
                return true
            }
        }
        return false
    }

    /// Deactivates the piloting interface of the given controller.
    ///
    /// Only the current, non-default, piloting interface can be deactivated.
    ///
    /// - Parameter pilotingItf: piloting interface controller whose interface must be deactivated
    /// - Returns: true if the operation could be initiated, otherwise false
    func deactivate(pilotingItf: ActivablePilotingItfController) -> Bool {
        if pilotingItf == currentPilotingItf && pilotingItf != defaultPilotingItf && pilotingItf.canDeactivate {
            currentPilotingItf?.requestDeactivation()
            return true
        }
        return false
    }

    /// Called back when the drone has connected.
    func didConnect() {
        isConnected = true
        // if no piloting itf is activated when connection is over, then fallback to the default one
        if currentPilotingItf == nil {
            defaultPilotingItf.requestActivation()
        }
    }

    /// Called back when the drone has disconnected.
    func didDisconnect() {
        isConnected = false
        currentPilotingItf = nil
        nextPilotingItf = nil
    }

    /// Called back when a piloting interface declares itself unavailable.
    ///
    /// - Parameter pilotingItf: piloting interface controller whose interface is now unavailable
    func onUnavailable(pilotingItf: ActivablePilotingItfController) {
        if pilotingItf == currentPilotingItf {
            currentPilotingItf = nil
            activateRelevantPilotingItf()
        } else if isConnected && currentPilotingItf == nil {
            activateRelevantPilotingItf()
        }
    }

    /// Called back when a piloting interface declares itself idle.
    ///
    /// - Parameter pilotingItf: piloting interface controller whose interface is now idle
    func onIdle(pilotingItf: ActivablePilotingItfController) {
        if pilotingItf == currentPilotingItf {
            currentPilotingItf = nil

            activateRelevantPilotingItf()
        } else if isConnected && currentPilotingItf == nil {
            activateRelevantPilotingItf()
        }
    }

    /// Called back when a piloting interface declares itself active.
    ///
    /// - Parameter pilotingItf: piloting interface controller whose interface is now active
    func onActive(pilotingItf: ActivablePilotingItfController) {
        if pilotingItf != currentPilotingItf {
            let pilotingItfToDeactivate = currentPilotingItf
            currentPilotingItf = pilotingItf
            pilotingItfToDeactivate?.requestDeactivation()
         }
    }

    /// Register in NoAck command loop.
    func registerInNoAckCommandLoop() {
        if let backend = droneController.backend, pilotingEncoderRegistered == nil {
            pilotingEncoderRegistered = backend.subscribeNoAckCommandEncoder(encoder: pilotingCommandEncoder)
        }
    }

    /// Unregister in NoAck command loop.
    func unregisterInNoAckCommandLoop() {
        if let pilotingEncoderRegistered = pilotingEncoderRegistered {
            pilotingEncoderRegistered.unregister()
            self.pilotingEncoderRegistered = nil
        }
        pilotingCommandEncoder.reset()
    }

    /// Called back when a piloting interface forwards a piloting command roll change.
    ///
    /// - Parameters:
    ///     - value: the new roll value
    ///     - pilotingItf: piloting interface from which the change originates
    func rollDidChange(_ value: Int, pilotingItf: ActivablePilotingItfController) {
        if pilotingItf == currentPilotingItf && pilotingCommandEncoder.set(roll: value) {
            droneController.pilotingCommandDidChange(pilotingCommandEncoder.pilotingCommand)
        }
    }

    /// Called back when a piloting interface forwards a piloting command pitch change.
    ///
    /// - Parameters:
    ///     - value: the new pitch value
    ///     - pilotingItf: piloting interface from which the change originates
    func pitchDidChange(_ value: Int, pilotingItf: ActivablePilotingItfController) {
        if pilotingItf == currentPilotingItf && pilotingCommandEncoder.set(pitch: value) {
            droneController.pilotingCommandDidChange(pilotingCommandEncoder.pilotingCommand)
        }
    }

    /// Called back when a piloting interface forwards a piloting command yaw change.
    ///
    /// - Parameters:
    ///     - value: the new yaw value
    ///     - pilotingItf: piloting interface from which the change originates
    func yawDidChange(_ value: Int, pilotingItf: ActivablePilotingItfController) {
        if pilotingItf == currentPilotingItf && pilotingCommandEncoder.set(yaw: value) {
            droneController.pilotingCommandDidChange(pilotingCommandEncoder.pilotingCommand)
        }
    }

    /// Called back when a piloting interface forwards a piloting command gaz change.
    ///
    /// - Parameters:
    ///     - value: the new gaz value
    ///     - pilotingItf: piloting interface from which the change originates
    func gazDidChange(_ value: Int, pilotingItf: ActivablePilotingItfController) {
        if pilotingItf == currentPilotingItf && pilotingCommandEncoder.set(gaz: value) {
            droneController.pilotingCommandDidChange(pilotingCommandEncoder.pilotingCommand)
        }
    }

    /// Activates the relevant piloting interface.
    /// The activated piloting interface is the one which was formerly asked to be activated if applicable,
    /// or the default one otherwise.
    private func activateRelevantPilotingItf() {
        if let nextPilotingItf = nextPilotingItf {
            nextPilotingItf.requestActivation()
            self.nextPilotingItf = nil
        } else { // fallback on the default interface
            defaultPilotingItf.requestActivation()
        }
    }
}
