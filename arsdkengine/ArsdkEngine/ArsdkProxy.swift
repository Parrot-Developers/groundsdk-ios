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

class ArsdkProxy: DeviceProvider {

    /// Device controller acting as proxy
    unowned let proxyDeviceController: ProxyDeviceController

    /// arsdk engine
    private var engine: ArsdkEngine {
        return proxyDeviceController.engine
    }

    private var knownDevices = [String: DeviceController]()

    /// current active device on the proxy
    private(set) var activeDevice: DeviceController?

    override var parent: DeviceProvider? {
        return proxyDeviceController.activeProvider
    }

    /// Constructor
    ///
    /// - Parameter proxyDeviceController: device controller acting as proxy
    required init(proxyDeviceController: ProxyDeviceController) {
        self.proxyDeviceController = proxyDeviceController
        super.init(connector: RemoteControlDeviceConnectorCore(uid: proxyDeviceController.device.uid))
    }

    func proxyDeviceDidDisconnect() {
        remoteDeviceDidDisconnect()
        changeActiveDevice(nil)
        removeAllRemoteDevices()
    }

    /// Connect an exiting device
    ///
    /// - Parameters:
    ///    - deviceController: device controller of the device to connect
    ///    - password: password to connect the remote device, an empty string if password is not required
    /// - Returns: true if the connect request has been processed
    override func connect(deviceController: DeviceController, password: String) -> Bool {
        if deviceController.connectionSession.state == .disconnected {
            changeActiveDevice(deviceController)
            activeDevice!.linkWillConnect(provider: self)
            return proxyDeviceController.connectRemoteDevice(controller: deviceController, password: password)
        }
        return false
    }

    /// Connect an exiting or new device
    ///
    /// - Parameters:
    ///    - uid: device uid
    ///    - model: device model
    ///    - name: device name
    ///    - password: password to connect the remote device, an empty string if password is not required
    /// - Returns: true if the connect request has been processed
    func connect(uid: String, model: DeviceModel, name: String, password: String) -> Bool {
        let deviceController = engine.getOrCreateDeviceController(uid: uid, model: model, name: name)
        deviceController.addProvider(self)
        return connect(deviceController: deviceController, password: password)
    }

    override func forget(deviceController: DeviceController) {
        if activeDevice == deviceController {
            changeActiveDevice(nil)
        }
        proxyDeviceController.forgetRemoteDevice(uid: deviceController.device.uid)
    }

    override func dataSyncAllowanceMightHaveChanged(deviceController: DeviceController) {
        if activeDevice == deviceController {
            proxyDeviceController.activeDeviceDataSyncAllowanceMightHaveChanged()
        }
    }

    /// Send a command
    ///
    /// - Parameter encoder: encoder of the command to send
    func sendCommand(_ encoder: ((OpaquePointer) -> Int32)!) {
        proxyDeviceController.sendCommand(encoder)
    }

    private func changeActiveDevice(_ newActiveDevice: DeviceController?) {
        // disconenct current active device if different
        if let activeDevice = activeDevice, activeDevice != newActiveDevice {
            activeDevice.linkDidDisconnect(removing: false)
            if knownDevices[activeDevice.device.uid] == nil {
                // not a known device. it can be a device just added
                activeDevice.removeProvider(self)
            }
            self.activeDevice = nil
        }
        if let newActiveDevice = newActiveDevice, activeDevice == nil {
            activeDevice = newActiveDevice
            activeDevice!.addProvider(self)
        }
        proxyDeviceController.activeDeviceDidChange()
    }

    override var description: String {
        return "ArsdkProxy \(proxyDeviceController.device.uid)"
    }

}

// known device management
extension ArsdkProxy {

    @discardableResult func addRemoteDevice(uid: String, model: DeviceModel, name: String) -> DeviceController? {
        let deviceController = engine.getOrCreateDeviceController(uid: uid, model: model, name: name)
        knownDevices[uid] = deviceController
        deviceController.addProvider(self)
        return deviceController
    }

    func removeRemoveDevice(uid: String) {
        if let deviceController = knownDevices.removeValue(forKey: uid) {
            deviceController.removeProvider(self)
        }
    }

    func removeAllRemoteDevices() {
        for deviceController in knownDevices.values {
            deviceController.removeProvider(self)
        }
        knownDevices.removeAll()
    }
}

// active device management
extension ArsdkProxy {

    func remoteDeviceWillConnect(uid: String, model: DeviceModel, name: String) {
        let deviceController = engine.getOrCreateDeviceController(uid: uid, model: model, name: name)
        changeActiveDevice(deviceController)
        activeDevice!.linkWillConnect(provider: self)
    }

    func remoteDeviceDidConnect(uid: String, model: DeviceModel, name: String) {
        let deviceController = engine.getOrCreateDeviceController(uid: uid, model: model, name: name)
        changeActiveDevice(deviceController)
        activeDevice!.linkDidConnect(provider: self, backend: proxyDeviceController.backend!)
    }

    func remoteDeviceWillDisconnect(uid: String, model: DeviceModel, name: String) {
        if let activeDevice = activeDevice, activeDevice.device.uid == uid {
            activeDevice.linkDidDisconnect(removing: false)
        }
    }

    func remoteDeviceAutheticationFailed(uid: String) {
        if let activeDevice = activeDevice, activeDevice.device.uid == uid {
            activeDevice.linkDidCancelConnect(cause: .badPassword, removing: false)
        }
    }

    func remoteDeviceDidDisconnect() {
        if let activeDevice = activeDevice {
            activeDevice.linkDidDisconnect(removing: false)
            // keep disconnected device with bad password as active device, to keep it in the device list
            if activeDevice.device.stateHolder.state.connectionStateCause != .badPassword {
                changeActiveDevice(nil)
            }
        }
    }
}
