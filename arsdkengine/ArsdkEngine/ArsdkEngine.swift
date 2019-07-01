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

/// Ground sdk engine implementation for arsdk
@objc(ArsdkEngine)
public class ArsdkEngine: EngineBaseCore {

    /// Store of known devices
    private(set) var persistentStore: PersistentStore!

    /// Arsdk
    private(set) var arsdk: Arsdk!

    /// Map of device controller, by uid. There is one device controller for each device created by the engine
    private(set) var deviceControllers = [String: DeviceController]()

    /// Black box recorder
    /// Nil if the config does not allow to record black boxes
    private(set) var blackBoxRecoder: BlackBoxRecorder?

    /// Constructor
    ///
    /// - Parameter enginesController: engine controller owning the engine
    public required init(enginesController: EnginesControllerCore) {
        ULog.i(.tag, "Create ArsdkEngine")

        // TODO: use global arsdkengine configuration
        arsdkCoreCmdLogLevel = ArsdkCmdLog.acknowledgedOnlyWithoutFrequent

        super.init(enginesController: enginesController)
        arsdk = Arsdk(engine: self)
        persistentStore = createPersistentStore()
        AppDefaults.importTo(persistentStore: persistentStore)
    }

    public override func startEngine() {

        if let blackBoxStorage = utilities.getUtility(Utilities.blackBoxStorage) {
            ULog.d(.myparrot, "BLACKBOX Start Recorder")
            blackBoxRecoder = BlackBoxRecorder(engine: self, blackBoxStorage: blackBoxStorage)
        } else {
            ULog.e(.myparrot, "BLACKBOX no Utilities.blackBoxStorage ?")
        }

        // create all known devices
        for uid in persistentStore.getDevicesUid() {
            let deviceDict = SettingsStore(dictionary: persistentStore.getDevice(uid: uid))

            if let typeNumber: Int = deviceDict.read(key: PersistentStore.deviceType),
                let model = DeviceModel.from(internalId: typeNumber),
                let name: String = deviceDict.read(key: PersistentStore.deviceName) {
                let deviceController = createDeviceController(uid: uid, model: model, name: name)
                deviceControllers[uid] = deviceController
                deviceController.start(stopListener: self)
            }
        }

        arsdk.start()
    }

    public override func stopEngine() {
        for deviceController in deviceControllers.values {
            deviceController.stop()
        }

        deviceControllers.removeAll(keepingCapacity: false)
        arsdk.stop()
    }

    /// Factory function to create arsdk controller
    /// This is to allow mocking engine for unit tests
    ///
    /// - Parameter listener: arsdk ctrl listener
    /// - Returns: an arsdk controller instance
    func createArsdkCore(listener: ArsdkCoreListener) -> ArsdkCore {
        let controllerDescriptor = "APP,iOS,\(AppInfoCore.deviceModel),\(AppInfoCore.systemVersion)"
        let controllerVersion
            = "\(AppInfoCore.appBundle),\(AppInfoCore.appVersion),\(AppInfoCore.sdkBundle),\(AppInfoCore.sdkVersion)"
        return ArsdkCore(backendControllers: createBackendControllers(), listener: listener,
                         controllerDescriptor: controllerDescriptor, controllerVersion: controllerVersion)
    }

    /// Factory function to create the backend controllers
    ///
    /// - Returns: a list of backend controllers to use
    private func createBackendControllers() -> [ArsdkBackendController] {
        var backendController = [ArsdkBackendController]()
        let supportedDevices = GroundSdkConfig.sharedInstance.supportedDevices
        if GroundSdkConfig.sharedInstance.enableWifi {
            let wifiModels = DeviceModel.supportingTechnology(models: supportedDevices, technology: .wifi)
            backendController.append(ArsdkWifiBackendController(
                supportedDeviceTypes: Set<NSNumber>(wifiModels.map { NSNumber(value: $0.internalId) })))
        }
        if GroundSdkConfig.sharedInstance.enableUsb {
            let usbModels = DeviceModel.supportingTechnology(models: supportedDevices, technology: .usb)
            backendController.append(ArsdkMuxEaBackendController(
                supportedDeviceTypes: Set<NSNumber>(usbModels.map { NSNumber(value: $0.internalId) })))
        }
        if GroundSdkConfig.sharedInstance.enableUsbDebug {
            let usbModels = DeviceModel.supportingTechnology(models: supportedDevices, technology: .usb)
            backendController.append(ArsdkMuxIpBackendController(
                supportedDeviceTypes: Set<NSNumber>(usbModels.map { NSNumber(value: $0.internalId) })))
        }
        return backendController
    }

    /// Factory function to create a persistent store
    /// This is to allow mocking persistent store for unit tests
    ///
    /// - Returns: a persistent store instance
    func createPersistentStore() -> PersistentStore {
        return PersistentStore()
    }

    /// Gets a device controller for a device, creating it if it doesn't exist yet
    ///
    /// - Parameters:
    ///   - uid: device uid
    ///   - model: device model
    ///   - name: device name
    /// - Returns: device controller
    func getOrCreateDeviceController(uid: String, model: DeviceModel, name: String) -> DeviceController {
        if let deviceController = deviceControllers[uid] {
            return deviceController
        } else {
            let deviceController = createDeviceController(uid: uid, model: model, name: name)
            deviceControllers[uid] = deviceController
            deviceController.start(stopListener: self)
            return deviceController
        }
    }

    /// Create a device controller for a device
    ///
    /// - Parameters:
    ///   - uid: device uid
    ///   - type: device type
    ///   - name: device name
    /// - Returns: a new device controller instance, or nil if type is invalid
    private func createDeviceController(uid: String, model: DeviceModel, name: String) -> DeviceController {
        switch model {
        case .drone(let droneModel):
            switch droneModel {
            case .anafi4k:
                return AnafiFamilyDroneController(engine: self, deviceUid: uid, name: name, model: .anafi4k)
            case .anafiThermal:
                return AnafiFamilyDroneController(engine: self, deviceUid: uid, name: name, model: .anafiThermal)
            }
        case .rc(let rcModel):
            switch rcModel {
            case .skyCtrl3:
                return SkyControllerFamilyController(engine: self, deviceUid: uid, model: rcModel, name: name)
            }
        }
    }
}

/// Extension of ArsdkEngine that implements DeviceControllerStoppedListener
extension ArsdkEngine: DeviceControllerStoppedListener {
    func onSelfStopped(uid: String) {
        deviceControllers[uid] = nil
    }
}
