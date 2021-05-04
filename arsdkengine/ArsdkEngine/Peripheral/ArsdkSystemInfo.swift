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

/// Arsdk System Info backend that should be implemented by subclasses
protocol ArsdkSystemInfoBackend {
    /// Reset the settings
    func doResetSettings() -> Bool

    /// Do a factory reset
    func doFactoryReset() -> Bool
}

/// Generic System info component controller
class ArsdkSystemInfo: DeviceComponentController {

    /// All data that can be stored
    enum PersistedDataKey: String, StoreKey {
        case serial = "serial"
        case boardId = "boardId"
        case firmwareVersion = "firmwareVersion"
        case hardwareVersion = "hardwareVersion"
        case updateRequirement = "updateRequirement"
    }

    private static let settingKey = "SystemInfo"

    /// Store device specific values
    public let deviceStore: SettingsStore

    /// SystemInfo component.
    var systemInfo: SystemInfoCore!

    /// Arsdk System Info backend
    var backend: ArsdkSystemInfoBackend!

    /// Current device version
    private var firmwareVersion: FirmwareVersion?

    /// Blacklisted firmware version store
    private let blacklistStore: BlacklistedVersionStoreCore?
    /// Monitors changed on the blacklist store
    private var blacklistStoreMonitor: MonitorCore?

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        deviceStore = deviceController.deviceStore.getSettingsStore(key: ArsdkSystemInfo.settingKey)
        blacklistStore = deviceController.engine.utilities.getUtility(Utilities.blacklistedVersionStore)
        super.init(deviceController: deviceController)
        systemInfo = SystemInfoCore(store: deviceController.device.peripheralStore, backend: self)
        if !deviceStore.new {
            loadPersistedData()
            monitorBlacklistStore()
            systemInfo.publish()
        }
    }

    /// Device is connected
    override func didConnect() {
        super.didConnect()
        monitorBlacklistStore()
        systemInfo.publish()
    }

    /// Device is disconnected
    override func didDisconnect() {
        super.didDisconnect()
        // clear all non saved settings
        systemInfo.resetSettingsEnded().factoryResetEnded().notifyUpdated()
    }

    /// Device is about to be forgotten
    override func willForget() {
        deviceStore.clear()
        systemInfo.unpublish()
        if let blacklistStoreMonitor = blacklistStoreMonitor {
            blacklistStoreMonitor.stop()
            self.blacklistStoreMonitor = nil
        }
        super.willForget()
    }

    /// API capabilities of the managed device are known.
    ///
    /// - Parameter api: the API capabilities received
    override func apiCapabilities(_ api: ArsdkApiCapabilities) {
        let isUpdateRequired = (api == ArsdkApiCapabilities.updateOnly)
        deviceStore.write(key: PersistedDataKey.updateRequirement, value: isUpdateRequired).commit()
        systemInfo.update(isUpdateRequired: isUpdateRequired)
        systemInfo.notifyUpdated()
    }

    /// Called when the current firmware version changed
    ///
    /// - Note: this function will call `notifyUpdated()`.
    ///
    /// - Parameter versionStr: the new firmware versions
    func firmwareVersionDidChange(versionStr: String) {
        systemInfo.update(firmwareVersion: versionStr)

        firmwareVersion = FirmwareVersion.parse(versionStr: versionStr)
        computeIsFirmwareBlacklisted()
        systemInfo.notifyUpdated()
        deviceStore.write(key: PersistedDataKey.firmwareVersion, value: versionStr).commit()
    }

    /// Load saved values in systemInfo
    private func loadPersistedData() {
        if let serial: String = deviceStore.read(key: PersistedDataKey.serial) {
            systemInfo.update(serial: serial)
        }
        if let firmwareVersion: String = deviceStore.read(key: PersistedDataKey.firmwareVersion) {
            self.firmwareVersion = FirmwareVersion.parse(versionStr: firmwareVersion)
            systemInfo.update(firmwareVersion: firmwareVersion)
        }
        if let hardwareVersion: String = deviceStore.read(key: PersistedDataKey.hardwareVersion) {
            systemInfo.update(hardwareVersion: hardwareVersion)
        }
        if let boardId: String = deviceStore.read(key: PersistedDataKey.boardId) {
            systemInfo.update(boardId: boardId)
        }
        if let isUpdateRequired: Bool = deviceStore.read(key: PersistedDataKey.updateRequirement) {
            systemInfo.update(isUpdateRequired: isUpdateRequired)
        }
    }

    /// Starts monitoring the blacklisted firmware version store
    ///
    /// - Note: this function won't call `notifyUpdated()` on the systemInfo component.
    private func monitorBlacklistStore() {
        if let blacklistStoreMonitor = blacklistStoreMonitor {
            blacklistStoreMonitor.stop()
        }
        blacklistStoreMonitor = blacklistStore?.startMonitoring { [weak self] in
            self?.computeIsFirmwareBlacklisted()
            self?.systemInfo.notifyUpdated()
        }
    }

    /// Compute whether the current firmware version is blacklisted.
    ///
    /// - Note: this function won't call `notifyUpdated()` on the systemInfo component.
    private func computeIsFirmwareBlacklisted() {
        if let firmwareVersion = firmwareVersion {
            let firmwareIdentifier = FirmwareIdentifier(
                deviceModel: deviceController.deviceModel, version: firmwareVersion)
            if let blacklisted = blacklistStore?.isBlacklisted(firmwareIdentifier: firmwareIdentifier) {
                systemInfo.update(isBlacklisted: blacklisted)
            }
        }
    }
}

/// SystemInfo backend implementation
extension ArsdkSystemInfo: SystemInfoBackend {
    func resetSettings() -> Bool {
        guard connected else {
            return false
        }
        return backend.doResetSettings()
    }

    func factoryReset() -> Bool {
        guard connected else {
            return false
        }
        return backend.doFactoryReset()
    }
}
