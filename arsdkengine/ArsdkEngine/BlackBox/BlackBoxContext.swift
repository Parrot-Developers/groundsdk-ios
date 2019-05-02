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

/// A black box recording context, which aggregates both a drone and a remote control recording session.
class BlackBoxContext {

    /// Black box ready callback
    private let blackBoxReadyCb: (BlackBoxData) -> Void
    /// Context close callback
    private let closeCb: () -> Void

    /// Drone session, nil if session has not been opened
    private var droneSession: BlackBoxDroneSession?
    /// Remote control session, nil if it has not been opened
    private var rcSession: BlackBoxRcSession?

    /// Constructor
    ///
    /// - Parameters:
    ///   - blackBoxReadyCb: block that will be called when the black box is ready to be archived
    ///   - blackBox: the black box data to archive
    ///   - closeCb: block that will be called when the context is about to be closed
    init(blackBoxReadyCb: @escaping (_ blackBox: BlackBoxData) -> Void, closeCb: @escaping () -> Void) {
        self.blackBoxReadyCb = blackBoxReadyCb
        self.closeCb = closeCb
    }

    /// Creates a drone session
    ///
    /// - Parameter drone: drone to open a session for
    /// - Returns: a new recording session for the drone
    func createDroneSession(drone: DroneCore) -> BlackBoxDroneSession {
        precondition(droneSession == nil, "Drone session is already existing.")

        droneSession = BlackBoxDroneSession(drone: drone) {
            if let rcSession = self.rcSession {
                self.droneSession!.setRemoteControlData(rcSession.rcData)
            }
            self.blackBoxReadyCb(self.droneSession!.blackBox)
            self.droneSession = nil

            if self.rcSession == nil {
                self.close()
            }
        }
        return droneSession!
    }

    /// Creates a remote control session
    ///
    /// - Parameter remoteControl: remote control to open a session for
    /// - Returns: a new recording session for the remote control
    func createRcSession(remoteControl: RemoteControlCore) -> BlackBoxRcSession {
        precondition(rcSession == nil, "Rc session is already existing.")

        rcSession = BlackBoxRcSession(remoteControl: remoteControl, delegate: self) {
            if let droneSession = self.droneSession {
                droneSession.setRemoteControlData(self.rcSession!.rcData)
            } else {
                self.close()
            }
            self.rcSession = nil
        }
        return rcSession!
    }

    /// Close the context
    ///
    /// - Note: the close callback will be called
    private func close() {
        closeCb()
    }
}

/// Extension of the BlackBoxContext that implements the BlackBoxRcSessionDelegate
extension BlackBoxContext: BlackBoxRcSessionDelegate {
    func buttonHasBeenTriggered(action: Int) {
        if let droneSession = droneSession {
            droneSession.addRcButtonEvent(action: action)
        }
    }

    func rcPilotingCommandDidChange(roll: Int, pitch: Int, yaw: Int, gaz: Int, source: Int) {
        if let droneSession = droneSession {
            droneSession.setRcPilotingCommand(roll: roll, pitch: pitch, yaw: yaw, gaz: gaz, source: source)
        }
    }
}
