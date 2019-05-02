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

/// Base class of a Device Controller that provides access to an other device (like a RemoteControl)
class ProxyDeviceController: DeviceController {

    /// Proxy instance
    private(set) var arsdkProxy: ArsdkProxy!

    override var dataSyncAllowed: Bool {
        // true if the device may sync data and there is connected drone or the connected drone may sync data
        return super.dataSyncAllowed && (arsdkProxy.activeDevice?.dataSyncAllowed ?? true)
    }

    /// Constructor
    ///
    /// - Parameters:
    ///    - engine: arsdk engine instance
    ///    - deviceUid: device uid
    ///    - deviceModel: device model
    ///    - deviceFactory: closure to create the device managed by this controller
    init(engine: ArsdkEngine, deviceUid: String, deviceModel: DeviceModel,
         deviceFactory: (_ delegate: DeviceCoreDelegate) -> DeviceCore) {
        super.init(engine: engine, deviceUid: deviceUid, deviceModel: deviceModel,
                   deviceFactory: deviceFactory)
        arsdkProxy = ArsdkProxy(proxyDeviceController: self)
    }

    /// Called when the active device did change.
    final func activeDeviceDidChange() {
        dataSyncAllowanceMightHaveChanged()
    }

    /// Called when the data synchronization allowance of the active device might have changed.
    final func activeDeviceDataSyncAllowanceMightHaveChanged() {
        dataSyncAllowanceMightHaveChanged()
    }

    override func protocolDidReceiveCommand(_ command: OpaquePointer) {
        arsdkProxy.activeDevice?.didReceiveCommand(command)
        super.protocolDidReceiveCommand(command)
    }

    /// Ask the proxy to connect to a device. To be implemented by subclasses
    ///
    /// - Parameters:
    ///    - controller: device controller of the device to connect.
    ///    - password: password to use to connect the remote device, an empty string if password is not required
    /// - Returns: true if the connection as started
    func connectRemoteDevice(controller: DeviceController, password: String) -> Bool {
        return false
    }

    /// Disconnect a remote device. To be implemented by subclasses
    ///
    /// - Parameter uid: uid of the device to connect
    func forgetRemoteDevice(uid: String) {
    }
}
