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

/// Implementation of DroneManager feature commands.
class DroneManagerFeature: NSObject {

    /// ArsdkProxy instance
    private let arsdkProxy: ArsdkProxy

    /// Constructor
    ///
    /// - Parameter arsdkProxy: arsdkProxy instance
    init(arsdkProxy: ArsdkProxy) {
        self.arsdkProxy = arsdkProxy
    }

    /// Notify that the device owning the proxy will disconnect
    func protocolWillDisconnect() {
        arsdkProxy.proxyDeviceDidDisconnect()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    func protocolDidReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureDroneManagerUid {
            ArsdkFeatureDroneManager.decode(command, callback: self)
        }
    }

    /// Connect a remote device
    ///
    /// - Parameters:
    ///    - uid: uid of the device to connect.
    ///    - password: password to use to connect the remote device, an empty string if password is not required
    /// - Returns: true if the connection as started
    func connectRemoteDevice(uid: String, password: String) -> Bool {
        ULog.d(.ctrlTag, "DroneManagerFeature: sending connect command, \(uid)")
        arsdkProxy.sendCommand(ArsdkFeatureDroneManager.connectEncoder(serial: uid, key: password))
        return true
    }

    /// Forget a remote device.
    ///
    /// - Parameter uid: uid of the device to forget
    func forgetRemoteDevice(uid: String) {
        ULog.d(.ctrlTag, "DroneManagerFeature: sending forget command, \(uid)")
        arsdkProxy.sendCommand(ArsdkFeatureDroneManager.forgetEncoder(serial: uid))
    }
}

/// DroneManager events dispatcher
extension DroneManagerFeature: ArsdkFeatureDroneManagerCallback {
    func onConnectionState(state: ArsdkFeatureDroneManagerConnectionState, serial: String!, model: UInt,
                           name: String!) {
        switch state {
        case .idle,
             .searching:
            ULog.d(.ctrlTag, "DroneManagerFeature: onConnectionState: Idle or Searching")
            arsdkProxy.remoteDeviceDidDisconnect()
        case .connecting:
            ULog.d(.ctrlTag, "DroneManagerFeature: onConnectionState: Connecting \(serial ?? "nil") \(model)" +
                " \(name ?? "nil")")
            if let model = DeviceModel.from(internalId: Int(model)) {
                arsdkProxy.remoteDeviceWillConnect(uid: serial, model: model, name: name)
            }
        case .connected:
            ULog.d(.ctrlTag, "DroneManagerFeature: onConnectionState: Connected \(serial ?? "nil") \(model)" +
                " \(name ?? "nil")")
            if let model = DeviceModel.from(internalId: Int(model)) {
                arsdkProxy.remoteDeviceDidConnect(uid: serial, model: model, name: name)
            }
        case .disconnecting:
            ULog.d(.ctrlTag, "DroneManagerFeature: onConnectionState: Disconnecting \(serial ?? "nil")" +
                " \(model) \(name ?? "nil")")
            if let model = DeviceModel.from(internalId: Int(model)) {
                arsdkProxy.remoteDeviceWillDisconnect(uid: serial, model: model, name: name)
            }
        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown connection state, skipping this event.")
            return
        }
    }

    func onAuthenticationFailed(serial: String!, model: UInt, name: String!) {
        ULog.d(.ctrlTag, "DroneManagerFeature onAuthenticationFailed: \(serial ?? "nil") \(name ?? "nil")")
        arsdkProxy.remoteDeviceAutheticationFailed(uid: serial)
    }

    func onKnownDroneItem(serial: String!, model: UInt, name: String!, security: ArsdkFeatureDroneManagerSecurity,
                          hasSavedKey: UInt, listFlagsBitField: UInt) {
        ULog.d(.ctrlTag, "DroneManagerFeature: onKnownDroneItem \(serial ?? "nil") \(model) " +
            "\(name ?? "nil") security = \(security.rawValue) listFlags = \(listFlagsBitField)")
        if ArsdkFeatureGenericListFlagsBitField.isSet(.empty, inBitField: listFlagsBitField) {
            // remove all
            arsdkProxy.removeAllRemoteDevices()
        } else {
            if ArsdkFeatureGenericListFlagsBitField.isSet(.remove, inBitField: listFlagsBitField) {
                // remove
                arsdkProxy.removeRemoveDevice(uid: serial)
            } else {
                // first, remove all
                if ArsdkFeatureGenericListFlagsBitField.isSet(.first, inBitField: listFlagsBitField) {
                    arsdkProxy.removeAllRemoteDevices()
                }
                // add
                if let model = DeviceModel.from(internalId: Int(model)) {
                    arsdkProxy.addRemoteDevice(uid: serial, model: model, name: name)
                } else {
                    ULog.w(.ctrlTag, "Ignoring onKnownDroneItem for model \(model)")
                }
            }
        }
    }
}
