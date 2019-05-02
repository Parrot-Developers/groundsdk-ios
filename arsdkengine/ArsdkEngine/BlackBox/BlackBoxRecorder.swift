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

/// Black box recorder, allowing device controllers to create sessions to record black box data.
class BlackBoxRecorder {

    /// Black box storage utility
    private let blackBoxStorage: BlackBoxStorageCore

    /// Live black box contexts, by master uid
    private var sessions: [String: BlackBoxContext] = [:]

    /// Constructor
    ///
    /// - Parameters:
    ///   - engine: arsdk engine
    ///   - blackBoxStorage: black box storage utility
    init(engine: ArsdkEngine, blackBoxStorage: BlackBoxStorageCore) {
        self.blackBoxStorage = blackBoxStorage
    }

    /// Opens a session to record drone black box data
    ///
    /// - Parameters:
    ///   - drone: drone to record black box data from
    ///   - providerUid: uid of the active device provider for that drone, if any. Nil otherwise
    /// - Returns: an opened drone black box recording session
    func openDroneSession(drone: DroneCore, providerUid: String?) -> BlackBoxDroneSession {
        let masterUid: String
        if let providerUid = providerUid {
            masterUid = providerUid
        } else {
            masterUid = drone.uid
        }
        return obtainContext(masterUid: masterUid).createDroneSession(drone: drone)
    }

    /// Opens a session to record remote control black box data
    ///
    /// - Parameters:
    ///   - drone: drone to record black box data from
    ///   - providerUid: uid of the active device provider for that drone, if any. Nil otherwise
    /// - Returns: an opened drone black box recording session
    func openRemoteControlSession(remoteControl: RemoteControlCore) -> BlackBoxRcSession {
        return obtainContext(masterUid: remoteControl.uid).createRcSession(remoteControl: remoteControl)
    }

    /// Obtains an appropriate recording context for the given device.
    ///
    /// - Parameter masterUid: unique identifier for the context (either directly the device uid or the provider's uid
    ///                        if the drone is connected through a remote control
    /// - Returns: an existing or new context for the given device to record black box data within
    private func obtainContext(masterUid: String) -> BlackBoxContext {
        var session = sessions[masterUid]
        if session == nil {
            session = BlackBoxContext(blackBoxReadyCb: { blackBox in
                self.blackBoxStorage.notifyBlackBoxDataReady(blackBoxData: blackBox)
            }, closeCb: {
                self.sessions[masterUid] = session
            })
        }
        return session!
    }
}
