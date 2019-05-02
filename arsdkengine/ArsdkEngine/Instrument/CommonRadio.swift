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

/// Radio component controller for common messages and wifi feature rssi message
class CommonRadio: DeviceComponentController {

    /// radio component
    private var radio: RadioCore!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        self.radio = RadioCore(store: deviceController.device.instrumentStore)
    }

    /// Drone is connected
    override func didConnect() {
        radio.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        radio.unpublish()
        radio.update(linkSignalQuality: nil)
            .update(isLinkPerturbed: false)
            .update(is4GInterfering: false)
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCommonCommonstateUid {
            ArsdkFeatureCommonCommonstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureWifiUid {
            ArsdkFeatureWifi.decode(command, callback: self)
        }
    }
}

/// Common Common State decode callback implementation
extension CommonRadio: ArsdkFeatureCommonCommonstateCallback {
    func onLinkSignalQuality(value: UInt) {
        let quality = Int(value & 0xF) - 1
        let perturbed = (value & (1 << 7)) != 0
        let smartphone4GInterfering = (value & (1 << 6)) != 0
        // check if the quality is in the interval 0...4
        if (0...4).contains(quality) {
            radio.update(linkSignalQuality: quality)
        } else {
            ULog.w(.tag, "Unknown onLinkSignalQuality value: \(quality)")
        }
        radio.update(isLinkPerturbed: perturbed)
            .update(is4GInterfering: smartphone4GInterfering)
            .notifyUpdated()
    }
}

/// Wifi feature decode callback implementation
extension CommonRadio: ArsdkFeatureWifiCallback {
    func onRssiChanged(rssi: Int) {
        radio.update(rssi: rssi).notifyUpdated()
    }
}
