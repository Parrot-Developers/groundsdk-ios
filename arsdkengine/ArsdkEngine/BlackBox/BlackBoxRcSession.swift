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

/// Remote control session delegate
protocol BlackBoxRcSessionDelegate: class {
    /// Called when a button has been triggered
    ///
    /// - Parameter action: the button action
    func buttonHasBeenTriggered(action: Int)

    /// Called when the pcmd sent by the remote control has changed
    ///
    /// - Parameters:
    ///   - roll: roll value
    ///   - pitch: pitch value
    ///   - yaw: yaw value
    ///   - gaz: gaz value
    ///   - source: source of this piloting command (drone or remote control)
    func rcPilotingCommandDidChange(roll: Int, pitch: Int, yaw: Int, gaz: Int, source: Int)
}

/// Remote control black box recording session.
class BlackBoxRcSession: NSObject, BlackBoxSession {
    /// Delegate of this session
    private unowned let delegate: BlackBoxRcSessionDelegate
    /// Block that will be called when the session is about to close
    private let didClose: () -> Void

    /// Remote control data
    private(set) var rcData: BlackBoxRemoteControlData

    /// Constructor
    ///
    /// - Parameters:
    ///   - remoteControl: remote control to record a black box from
    ///   - delegate: delegate of this session
    ///   - didClose: block that will be called when the session is about to close
    init(remoteControl: RemoteControlCore, delegate: BlackBoxRcSessionDelegate, didClose: @escaping () -> Void) {
        rcData = BlackBoxRemoteControlData(remoteControl: remoteControl)
        self.delegate = delegate
        self.didClose = didClose
    }

    func onCommandReceived(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureSkyctrlSettingsstateUid {
            ArsdkFeatureSkyctrlSettingsstate.decode(command, callback: self)
        }
    }

    func close() {
        didClose()
    }

    /// Called when a button has been triggered
    ///
    /// - Parameter action: the button action
    func buttonHasBeenTriggered(action: Int) {
        delegate.buttonHasBeenTriggered(action: action)
    }

    /// Called when the pcmd sent by the remote control has changed
    ///
    /// - Parameters:
    ///   - roll: roll value
    ///   - pitch: pitch value
    ///   - yaw: yaw value
    ///   - gaz: gaz value
    ///   - source: source of this piloting command (drone or remote control)
    func rcPilotingCommandDidChange(roll: Int, pitch: Int, yaw: Int, gaz: Int, source: Int) {
        delegate.rcPilotingCommandDidChange(roll: roll, pitch: pitch, yaw: yaw, gaz: gaz, source: source)
    }
}

extension BlackBoxRcSession: ArsdkFeatureSkyctrlSettingsstateCallback {
    func onProductVersionChanged(software: String!, hardware: String!) {
        rcData.hardwareVersion = hardware
        rcData.softwareVersion = software
    }
}
