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

/// Device controller for a RC (Remote Control).
class RCController: ProxyDeviceController {

    /// Drone Manager Feature implementation
    private var droneManager: DroneManagerFeature!

    /// Get the drone managed by this controller
    var remoteControl: RemoteControlCore {
        return device as! RemoteControlCore
    }

    /// Remote control black box subscription
    private var rcBlackBoxSubscription: ArsdkRequest?

    /// Constructor
    ///
    /// - Parameters:
    ///    - engine: arsdk engine instance
    ///    - deviceUid: device uid
    ///    - model: rc model
    ///    - name: rc name
    init(engine: ArsdkEngine, deviceUid: String, model: RemoteControl.Model, name: String) {
        super.init(engine: engine, deviceUid: deviceUid, deviceModel: .rc(model)) { delegate in
            return RemoteControlCore(uid: deviceUid, model: model, name: name, delegate: delegate)
        }
        self.getAllSettingsEncoder = ArsdkFeatureSkyctrlSettings.allSettingsEncoder()
        self.getAllStatesEncoder = ArsdkFeatureSkyctrlCommon.allStatesEncoder()
        self.droneManager = DroneManagerFeature(arsdkProxy: arsdkProxy)
    }

    /// Device controller did start
    override func controllerDidStart() {
        super.controllerDidStart()
        // Can force unwrap remote control store utility because we know it is always available after the engine's start
        engine.utilities.getUtility(Utilities.remoteControlStore)!.add(remoteControl)
    }

    /// Device controller did stop
    override func controllerDidStop() {
        super.controllerDidStop()
        // Can force unwrap remote control store utility because we know it is always available after the engine's start
        engine.utilities.getUtility(Utilities.remoteControlStore)!.remove(remoteControl)
    }

    override func protocolWillConnect() {
        super.protocolWillConnect()

        if let blackBoxRecorder = engine.blackBoxRecoder, userHasAuthorizedBlackbox == true {
            let blackBoxRcSession = blackBoxRecorder.openRemoteControlSession(remoteControl: remoteControl)
            blackBoxSession = blackBoxRcSession

            // can force unwrap backend since we are connecting
            rcBlackBoxSubscription = backend!.subscribeToRcBlackBox(buttonAction: { action in
                blackBoxRcSession.buttonHasBeenTriggered(action: Int(action))
            }, pilotingInfo: { pitch, roll, yaw, gaz, source in
                blackBoxRcSession.rcPilotingCommandDidChange(
                    roll: Int(roll), pitch: Int(pitch), yaw: Int(yaw), gaz: Int(gaz), source: Int(source))
            })
        }
    }

    /// About to disconnect protocol
    override func protocolWillDisconnect() {
        super.protocolWillDisconnect()
        droneManager.protocolWillDisconnect()
    }

    override func protocolDidDisconnect() {
        super.protocolDidDisconnect()
        rcBlackBoxSubscription?.cancel()
        rcBlackBoxSubscription = nil
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func protocolDidReceiveCommand(_ command: OpaquePointer) {
        // settings/state
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureSkyctrlSettingsstateUid {
            ArsdkFeatureSkyctrlSettingsstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureSkyctrlCommonstateUid {
            ArsdkFeatureSkyctrlCommonstate.decode(command, callback: self)
        }

        // Drone manager feature
        droneManager.protocolDidReceiveCommand(command)

        super.protocolDidReceiveCommand(command)
    }

    /// Ask the proxy to connect to a device.
    ///
    /// - Parameters:
    ///    - controller: device controller of the device to connect.
    ///    - password: password to use to connect the remote device, an empty string if password is not required
    /// - Returns: true if the connection as started
    override func connectRemoteDevice(controller: DeviceController, password: String) -> Bool {
        return droneManager.connectRemoteDevice(uid: controller.device.uid, password: password)
    }

    /// Forget a remote device.
    ///
    /// - Parameter uid: uid of the device to forget
    override func forgetRemoteDevice(uid: String) {
        droneManager.forgetRemoteDevice(uid: uid)
    }
}

/// Skyctrl settings events dispatcher, used to receive onAllSettingsChanged
extension RCController: ArsdkFeatureSkyctrlSettingsstateCallback {
    func onAllSettingsChanged() {
        if connectionSession.state == .gettingAllSettings {
            transitToNextConnectionState()
        }
    }

    func onProductVersionChanged(software: String!, hardware: String!) {
        if let firmwareVersion = FirmwareVersion.parse(versionStr: software) {
            device.firmwareVersionHolder.update(version: firmwareVersion)
            deviceStore.write(key: PersistentStore.deviceFirmwareVersion, value: software).commit()
        }
    }
}

/// Skyctrl state events dispatcher, used to receive onAllStatesChanged
extension RCController: ArsdkFeatureSkyctrlCommonstateCallback {
    func onAllStatesChanged() {
        if connectionSession.state == .gettingAllStates {
            transitToNextConnectionState()
        }
    }
}

/// Skyctrl Common event state dispatcher, used to receive onShutdown
extension RCController: ArsdkFeatureSkyctrlCommoneventstateCallback {
    func onShutdown(reason: ArsdkFeatureSkyctrlCommoneventstateShutdownReason) {
        if reason == ArsdkFeatureSkyctrlCommoneventstateShutdownReason.poweroffButton {
            autoReconnect = false
            _ = doDisconnect(cause: .userRequest)
        }
    }
}
