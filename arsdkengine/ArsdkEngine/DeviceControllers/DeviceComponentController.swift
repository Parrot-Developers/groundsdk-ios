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

/// Base class of a device controller delegate that managed one or more components
public class DeviceComponentController: NSObject {

    /// Whether or not the managed device is connected.
    var connected: Bool {
        return deviceController.connectionSession.state == .connected
    }

    /// Device controller owning this component controller
    internal unowned let deviceController: DeviceController

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    init(deviceController: DeviceController) {
        self.deviceController = deviceController
        super.init()
    }

    /// Device has been discovered by arsdk
    func didAppear() {
    }

    /// Device has been removed by arsdk
    func didDisappear () {
    }

    /// Device is about to be forgotten
    func willForget() {
    }

    /// Device is about to be connect
    func willConnect() {
    }

    /// Device is connected
    func didConnect() {
    }

    /// Device is about to be disconnected
    func willDisconnect() {
    }

    /// Device is disconnected
    func didDisconnect() {
    }

    /// Link to the device has been lost
    func didLoseLink() {
    }

    /// Preset has been changed
    func presetDidChange() {
    }

    /// Data synchronization allowance changed.
    ///
    /// - Note: this function is only called while the device is connected (i.e. after `didConnect`). If the data sync
    ///   was allowed, this callback will be called one last time right after the `didDisconnect`.
    func dataSyncAllowanceChanged(allowed: Bool) {
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    func didReceiveCommand(_ command: OpaquePointer) {
    }

    /// API capabilities of the managed device are known.
    ///
    /// - Parameter api: the API capabilities received
    func apiCapabilities(_ api: ArsdkApiCapabilities) {
    }

    /// Send a command to the device
    ///
    /// - Parameter encoder: encoder of the command to send
    func sendCommand(_ encoder: @escaping ((OpaquePointer) -> Int32)) {
        deviceController.sendCommand(encoder)
    }
}
