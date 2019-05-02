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

/// Updater event receiver specific for drones.
///
/// - Note: this delegate only uses Ardrone3 message based drones.
class DroneUpdaterEventReceiver: NSObject, UpdaterEventReceiver {
    /// Callback to call when update ability has changed
    private var updateUnavailabilityReasonChanged: ((UpdaterUpdateUnavailabilityReason, Bool) -> Void)!

    func configure(updateUnavailabilityReasonChanged: @escaping (UpdaterUpdateUnavailabilityReason, Bool) -> Void) {
        self.updateUnavailabilityReasonChanged = updateUnavailabilityReasonChanged
    }

    func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCommonCommonstateUid {
            ArsdkFeatureCommonCommonstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3PilotingstateUid {
            ArsdkFeatureArdrone3Pilotingstate.decode(command, callback: self)
        }
    }
}

extension DroneUpdaterEventReceiver: ArsdkFeatureCommonCommonstateCallback {
    func onBatteryStateChanged(percent: UInt) {
        updateUnavailabilityReasonChanged(.notEnoughBattery, percent < 40)
    }
}

extension DroneUpdaterEventReceiver: ArsdkFeatureArdrone3PilotingstateCallback {
    func onFlyingStateChanged(state: ArsdkFeatureArdrone3PilotingstateFlyingstatechangedState) {
        updateUnavailabilityReasonChanged(.notLanded, state != .landed && state != .emergency)
    }
}
