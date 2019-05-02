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

/// Base controller for precise home peripheral
class PreciseHomeController: DeviceComponentController, PreciseHomeBackend {
    /// component settings key
    private static let settingKey = "PreciseHome"

    /// Precise home component
    private(set) var preciseHome: PreciseHomeCore!

    /// Store device specific values
    private let deviceStore: SettingsStore?

    /// Preset store for this piloting interface
    private var presetStore: SettingsStore?

    /// All settings that can be stored
    enum SettingKey: String, StoreKey {
        case modeKey = "mode"
    }

    /// Stored settings
    enum Setting: Hashable {
        case mode(PreciseHomeMode)
        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .mode: return .modeKey
            }
        }
        /// All values to allow enumerating settings
        static let allCases: [Setting] = [.mode(.disabled)]

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }

        static func == (lhs: Setting, rhs: Setting) -> Bool {
            return lhs.key == rhs.key
        }
    }

    /// Stored capabilities for settings
    enum Capabilities {
        case mode(Set<PreciseHomeMode>)

        /// All values to allow enumerating settings
        static let allCases: [Capabilities] = [.mode([])]

        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .mode: return .modeKey
            }
        }
    }

    /// Setting values as received from the drone
    private var droneSettings = Set<Setting>()

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            deviceStore = nil
            presetStore = nil
        } else {
            deviceStore = deviceController.deviceStore.getSettingsStore(key: PreciseHomeController.settingKey)
            presetStore = deviceController.presetStore.getSettingsStore(key: PreciseHomeController.settingKey)
        }

        super.init(deviceController: deviceController)
        preciseHome = PreciseHomeCore(store: deviceController.device.peripheralStore, backend: self)
        // load settings
        if let deviceStore = deviceStore, let presetStore = presetStore, !deviceStore.new && !presetStore.new {
            loadPresets()
            preciseHome.publish()
        }
    }

    /// Sets precise home mode
    ///
    /// - Parameter mode: the new precise home mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(mode: PreciseHomeMode) -> Bool {
        presetStore?.write(key: SettingKey.modeKey, value: mode).commit()
        if connected {
            return sendModeCommand(mode)
        } else {
            preciseHome.update(mode: mode).notifyUpdated()
            return false
        }
    }

    /// Drone is about to be forgotten
    override func willForget() {
        deviceStore?.clear()
        preciseHome.unpublish()
        super.willForget()
    }

    /// Drone is about to be connect
    override func willConnect() {
        super.willConnect()
        // remove settings stored while connecting. We will get new one on the next connection.
        droneSettings.removeAll()
    }

    /// Drone is connected
    override func didConnect() {
        storeNewPresets()
        applyPresets()
        if preciseHome.setting.supportedModes.isEmpty {
            preciseHome.unpublish()
        } else {
            preciseHome.publish()
        }
        super.didConnect()

    }

    /// Drone is disconnected
    override func didDisconnect() {
        super.didDisconnect()

        // clear all non saved values
        preciseHome.cancelSettingsRollback().update(mode: .disabled)

        // unpublish if offline settings are disabled
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            preciseHome.unpublish()
        } else {
            preciseHome.notifyUpdated()
        }
    }

    /// Preset has been changed
    override func presetDidChange() {
        super.presetDidChange()
        // reload preset store
        presetStore = deviceController.presetStore.getSettingsStore(key: PreciseHomeController.settingKey)
        loadPresets()
        if connected {
            applyPresets()
        }
    }

    /// Load saved settings
    private func loadPresets() {
        if let presetStore = presetStore, let deviceStore = deviceStore {
            for setting in Setting.allCases {
                switch setting {
                case .mode:
                    if let supportedModesValues: StorableArray<PreciseHomeMode> = deviceStore.read(key: setting.key),
                        let mode: PreciseHomeMode = presetStore.read(key: setting.key) {
                        let supportedModes = Set(supportedModesValues.storableValue)
                        if supportedModes.contains(mode) {
                            preciseHome.update(supportedModes: supportedModes).update(mode: mode)
                        }
                    }
                }
                preciseHome.notifyUpdated()
            }
        }
    }

    /// Called when the drone is connected, save all received settings ranges
    private func storeNewPresets() {
        // nothing to do yet
    }

    /// Apply a preset
    ///
    /// Iterate settings received during connection
    private func applyPresets() {
        // iterate settings received during the connection
        for setting in droneSettings {
            switch setting {
            case .mode (let mode):
                if let preset: PreciseHomeMode = presetStore?.read(key: setting.key) {
                    if preset != mode {
                         _ = sendModeCommand(preset)
                    }
                    preciseHome.update(mode: preset).notifyUpdated()
                } else {
                    preciseHome.update(mode: mode).notifyUpdated()
                }
            }
        }
    }

    /// Called when a command that notify a setting change has been received
    ///
    /// - Parameter setting: setting that changed
    func settingDidChange(_ setting: Setting) {
        droneSettings.insert(setting)
        switch setting {
        case .mode(let mode):
            if connected {
                preciseHome.update(mode: mode).notifyUpdated()
            }
        }
        preciseHome.notifyUpdated()
    }

    /// Process stored capabilities changes
    ///
    /// Update precise home and device store. Note caller must call `preciseHome.notifyUpdated()` to notify change.
    ///
    /// - Parameter capabilities: changed capabilities
    func capabilitiesDidChange(_ capabilities: Capabilities) {
        switch capabilities {
        case .mode(let modes):
            deviceStore?.write(key: capabilities.key, value: StorableArray(Array(modes)))
            preciseHome.update(supportedModes: modes)
        }
        deviceStore?.commit()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeaturePreciseHomeUid {
            ArsdkFeaturePreciseHome.decode(command, callback: self)
        }
    }

    /// Send mode command.
    ///
    /// - Parameter mode: requested mode.
    /// - Returns: true if the command has been sent
    func sendModeCommand(_ mode: PreciseHomeMode) -> Bool {
        var commandSent = false
        switch mode {
        case .standard:
            sendCommand(ArsdkFeaturePreciseHome.setModeEncoder(mode: .standard))
            commandSent = true
        case .disabled:
            sendCommand(ArsdkFeaturePreciseHome.setModeEncoder(mode: .disabled))
            commandSent = true
        }
        return commandSent
    }
}

// Extension to make PreciseHomeMode storable
extension PreciseHomeMode: StorableEnum {
    static var storableMapper = Mapper<PreciseHomeMode, String>([
        .standard: "standard",
        .disabled: "disabled"])
}

/// Precise home feature decode callback implementation
extension PreciseHomeController: ArsdkFeaturePreciseHomeCallback {
    func onState(state: ArsdkFeaturePreciseHomeState) {
        switch state {
        case .active:
            // precise home is active
            preciseHome.update(state: .active).notifyUpdated()
        case .available:
            // precise home is available
            preciseHome.update(state: .available).notifyUpdated()
        case .unavailable:
            // precise home is unavailable
            preciseHome.update(state: .unavailable).notifyUpdated()
        case .sdkCoreUnknown:
            // don't change the precise home state
            ULog.w(.tag, "Unknown precise home state, skipping this event.")
        }
    }
    func onMode(mode: ArsdkFeaturePreciseHomeMode) {
        switch mode {
        case .standard:
             settingDidChange(.mode(.standard))
        case .disabled:
             settingDidChange(.mode(.disabled))
        case .sdkCoreUnknown:
            // don't change the precise home modes
            ULog.w(.tag, "Unknown precise home mode, skipping this event.")
        }
    }

    func onCapabilities(modesBitField: UInt) {
        var availableMode: Set<PreciseHomeMode> = []
        if ArsdkFeaturePreciseHomeModeBitField.isSet(.disabled, inBitField: modesBitField) {
            availableMode.insert(.disabled)
        }
        if ArsdkFeaturePreciseHomeModeBitField.isSet(.standard, inBitField: modesBitField) {
            availableMode.insert(.standard)
        }
        capabilitiesDidChange(.mode(availableMode))
        preciseHome.notifyUpdated()
    }
}
