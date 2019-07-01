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

/// Copilot peripheral controller for SkyController message based remote controls
class SkyControllerCopilot: DeviceComponentController, CopilotBackend {

    /// Component settings key
    private static let settingKey = "Copilot"

    /// Copilot component
    private(set) var copilot: CopilotCore!

    /// Preset store for this piloting interface
    private var presetStore: SettingsStore?

    /// Setting values as received from the drone
    private var droneSettings = Set<Setting>()

    /// Tells whether copilot is supported
    private var isSupported = false

    /// All settings that can be stored
    enum SettingKey: String, StoreKey {
        case valueKey = "value"
    }

    /// Stored settings
    enum Setting: Hashable {
        case value(CopilotSource)
        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .value: return .valueKey
            }
        }
        /// All values to allow enumerating settings
        static let allCases: [Setting] = [.value(.remoteControl)]

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }

        static func == (lhs: Setting, rhs: Setting) -> Bool {
            return lhs.key == rhs.key
        }
    }

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            presetStore = nil
        } else {
            presetStore = deviceController.presetStore.getSettingsStore(key: SkyControllerCopilot.settingKey)
        }

        super.init(deviceController: deviceController)
        copilot = CopilotCore(store: deviceController.device.peripheralStore, backend: self)
        // load settings
        if let presetStore = presetStore, !presetStore.new {
            loadPresets()
            copilot.publish()
        }
    }

    override func willConnect() {
        droneSettings.removeAll()
        super.willConnect()
    }

    override func didConnect() {
        if isSupported {
            applyPresets()
            copilot.publish()
        }
        super.didConnect()
    }

    /// Set piloting source
    func set(source: CopilotSource) -> Bool {
        presetStore?.write(key: SettingKey.valueKey, value: source).commit()
        if connected {
            return sendCopilotCommand(source)
        } else {
            copilot.update(source: source).notifyUpdated()
            return false
        }
    }

    /// Preset has been changed
    override func presetDidChange() {
        super.presetDidChange()
        // reload preset store
        presetStore = deviceController.presetStore.getSettingsStore(key: SkyControllerCopilot.settingKey)
        loadPresets()
        if connected {
            applyPresets()
        }
    }

    /// Load saved settings
    private func loadPresets() {
        if let presetStore = presetStore {
            for setting in Setting.allCases {
                switch setting {
                case .value:
                    if let value: CopilotSource = presetStore.read(key: setting.key) {
                        copilot.update(source: value)
                        }
                    }
                copilot.notifyUpdated()
            }
        }
    }
    /// Apply a preset
    ///
    /// Iterate settings received during connection
    private func applyPresets() {
        // iterate settings received during the connection
        for setting in droneSettings {
            switch setting {
            case .value (let value):
                if let preset: CopilotSource = presetStore?.read(key: setting.key) {
                    if preset != value {
                        _ = sendCopilotCommand(preset)
                    }
                    copilot.update(source: value).notifyUpdated()
                } else {
                    copilot.update(source: value).notifyUpdated()
                }
            }
        }
    }

    /// Send copilot command.
    ///
    /// - Parameter source: requested source.
    /// - Returns: true if the command has been sent
    func sendCopilotCommand(_ source: CopilotSource) -> Bool {
        var commandSent = false
        switch source {
        case .application:
            sendCommand(ArsdkFeatureSkyctrlCopiloting.setPilotingSourceEncoder(source: .controller))
            commandSent = true
        case .remoteControl:
            sendCommand(ArsdkFeatureSkyctrlCopiloting.setPilotingSourceEncoder(source: .skycontroller))
            commandSent = true
        }
        return commandSent
    }

    /// Called when a command that notify a setting change has been received
    ///
    /// - Parameter setting: setting that changed
    func settingDidChange(_ setting: Setting) {
        droneSettings.insert(setting)
        switch setting {
        case .value(let source):
                copilot.update(source: source)
        }
        copilot.notifyUpdated()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureSkyctrlCopilotingstateUid {
            ArsdkFeatureSkyctrlCopilotingstate.decode(command, callback: self)
        }
    }
}

extension SkyControllerCopilot: ArsdkFeatureSkyctrlCopilotingstateCallback {
    func onPilotingSource(source: ArsdkFeatureSkyctrlCopilotingstatePilotingsourceSource) {
        isSupported = true
        switch source {
        case .skycontroller:
            settingDidChange(.value(.remoteControl))
        case .controller:
            settingDidChange(.value(.application))
        case .sdkCoreUnknown:
            // don't change the piloting source
            ULog.w(.tag, "Unknown copilot source, skipping this event.")
        }
    }
}

extension CopilotSource: StorableEnum {
    static var storableMapper = Mapper<CopilotSource, String>([
        .remoteControl: "skyController",
        .application: "controller"])
}
