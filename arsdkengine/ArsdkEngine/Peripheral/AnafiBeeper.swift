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

/// Beeper component controller for Anafi message based drones
class AnafiBeeper: DeviceComponentController {
    /// Beeper component
    private var beeper: BeeperCore!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        beeper = BeeperCore(store: deviceController.device.peripheralStore, backend: self)
    }

    /// Drone is connected
    override func didConnect() {
        beeper.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        beeper.unpublish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3SoundstateUid {
            ArsdkFeatureArdrone3Soundstate.decode(command, callback: self)
        }
    }
}

/// Beeper backend implementation
extension AnafiBeeper: BeeperBackend {
    func startAlertSound() -> Bool {
        sendCommand(ArsdkFeatureArdrone3Sound.startAlertSoundEncoder())
        return true
    }

    func stopAlertSound() -> Bool {
        sendCommand(ArsdkFeatureArdrone3Sound.stopAlertSoundEncoder())
        return true
    }
}

/// Anafi state decode callback implementation
extension AnafiBeeper: ArsdkFeatureArdrone3SoundstateCallback {
    func onAlertSound(state: ArsdkFeatureArdrone3SoundstateAlertsoundState) {
        switch state {
        case .stopped:
            beeper.update(alertSoundPlaying: false).notifyUpdated()
        case .playing:
            beeper.update(alertSoundPlaying: true).notifyUpdated()
        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown BeeperState, skipping this event.")
        }
    }
}
