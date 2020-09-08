// Copyright (C) 2020 Parrot Drones SAS
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

/// Dri supported capabilities
public enum DriSupportedCapabilities: Int, CustomStringConvertible {

    /// Dri switch mode `enabled`/`disabled` is supported
    case onOff

    /// Debug description.
    public var description: String {
        switch self {
        case .onOff:         return "onOff"
        }
    }

    /// Comparator
    public static func < (lhs: DriSupportedCapabilities, rhs: DriSupportedCapabilities) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    /// Set containing all possible values
    public static let allCases: Set<DriSupportedCapabilities> = [
        .onOff]
}

/// Base controller for dri peripheral
class DriController: DeviceComponentController, DriBackend {
    /// Dri component
    private var dri: DriCore!

    /// Component settings key
    private static let settingKey = "DriController"

    /// Store device specific values
    private let deviceStore: SettingsStore?

    /// Preset store for this component
    private var presetStore: SettingsStore?

    /// All settings that can be stored
    enum SettingKey: String, StoreKey {
        case modeKey = "mode"
        case identifier = "id"
    }

    /// Stored settings
    enum Setting: Hashable {
        case mode(Bool)
        case identifier(DriCore.DroneIdentifier)

        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .mode: return .modeKey
            case .identifier: return .identifier
            }
        }
        /// All values to allow enumerating settings
        static let allCases: Set<Setting> = [.mode(false),
                                             .identifier(DriCore.DroneIdentifier(type: .ANSI_CTA_2063, id: ""))]

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }

        static func == (lhs: Setting, rhs: Setting) -> Bool {
            return lhs.key == rhs.key
        }
    }

    /// Stored capabilities for settings
    enum Capabilities {
        case modeSwitchSupport(Bool)

        /// All values to allow enumerating settings
        static let allCases: [Capabilities] = [.modeSwitchSupport(false)]

        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .modeSwitchSupport: return .modeKey
            }
        }
    }

    /// Setting values as received from the drone
    private var droneSettings = Set<Setting>()

    /// Whether mode switch is supported.
    private (set) public var modeSwitchSupported = false

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            deviceStore = nil
            presetStore = nil
        } else {
            deviceStore = deviceController.deviceStore.getSettingsStore(key: DriController.settingKey)
            presetStore = deviceController.presetStore.getSettingsStore(key: DriController.settingKey)
        }

        super.init(deviceController: deviceController)
        dri = DriCore(store: deviceController.device.peripheralStore, backend: self)

        // load settings
        if let deviceStore = deviceStore, !deviceStore.new {
            loadPresets()
            dri.publish()
        }
    }

    /// Sets dri mode
    ///
    /// - Parameter mode: the new dri mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(mode: Bool) -> Bool {
        presetStore?.write(key: SettingKey.modeKey, value: mode).commit()
        if connected {
            return sendModeCommand(mode)
        } else {
            dri.update(mode: mode).notifyUpdated()
            return false
        }
    }

    /// Send mode command. Subclass must override this function to send the command
    ///
    /// - Parameter mode: requested mode. `true` if enabled
    /// - Returns: true if the command has been sent
    func sendModeCommand(_ mode: Bool) -> Bool {
        sendCommand(ArsdkFeatureDri.driModeEncoder(mode: mode ? .enabled : .disabled))
        return true
    }

    /// Load saved settings
    private func loadPresets() {
        if let presetStore = presetStore, let deviceStore = deviceStore {
            Setting.allCases.forEach {
                switch $0 {
                case .mode:
                    if let modeSwitchSupported: Bool = deviceStore.read(key: $0.key) {
                        self.modeSwitchSupported = modeSwitchSupported
                    }
                    if let mode: Bool = presetStore.read(key: $0.key) {
                        dri.update(mode: mode)
                    }
                case .identifier:
                    if let id: DriCore.DroneIdentifier = deviceStore.read(key: $0.key) {
                        dri.update(droneId: id)
                    }
                }
            }
            dri.notifyUpdated()
        }
    }

    /// Drone is connected
    override func didConnect() {
        applyPresets()
        if modeSwitchSupported {
            dri.publish()
        } else {
            dri.unpublish()
        }
    }

    /// Drone is disconnected
    override func didDisconnect() {
        dri.cancelSettingsRollback()
        // unpublish if offline settings are disabled
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            dri.unpublish()
        }
        dri.notifyUpdated()
    }

    /// Drone is about to be forgotten
    override func willForget() {
        dri.unpublish()
        super.willForget()
    }

    /// Preset has been changed
    override func presetDidChange() {
        super.presetDidChange()
        // reload preset store
        presetStore = deviceController.presetStore.getSettingsStore(key: DriController.settingKey)
        loadPresets()
        if connected {
            applyPresets()
        }
    }

    /// Apply a preset
    ///
    /// Iterate settings received during connection
    private func applyPresets() {
        // iterate settings received during the connection
        for setting in droneSettings {
            switch setting {
            case .mode (let mode):
                if let preset: Bool = presetStore?.read(key: setting.key) {
                    if preset != mode {
                        _ = sendModeCommand(preset)
                    }
                    dri.update(mode: preset).notifyUpdated()
                } else {
                    dri.update(mode: mode).notifyUpdated()
                }
            case .identifier:
                break
            }
        }
    }

    /// Called when a command that notifies a setting change has been received.
    ///
    /// - Parameter setting: setting that changed
    func settingDidChange(_ setting: Setting) {
        droneSettings.insert(setting)
        switch setting {
        case .mode(let mode):
            if connected {
                dri.update(mode: mode)
            }
        case .identifier(let id):
            dri.update(droneId: id)
            deviceStore?.write(key: setting.key, value: id).commit()
        }
        dri.notifyUpdated()
    }

    /// Called when a command that notifies a capabilities change has been received.
    ///
    /// - Parameter capabilities: capabilities that changed
    func capabilitiesDidChange(_ capabilities: Capabilities) {
        switch capabilities {
        case .modeSwitchSupport(let supported):
            deviceStore?.write(key: capabilities.key, value: AnyStorable(supported))
            modeSwitchSupported = supported
        }
        deviceStore?.commit()
        dri.notifyUpdated()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureDriUid {
            ArsdkFeatureDri.decode(command, callback: self)
        }
    }
}

/// Dri decode callback implementation
extension DriController: ArsdkFeatureDriCallback {

    func onDroneId(type: ArsdkFeatureDriIdType, value: String!) {
        var newType: DriIdType
        switch type {
        case .fr30Octets:
            newType = .FR_30_Octets
        case .ansiCta2063:
            newType = .ANSI_CTA_2063
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown DriIdType, skipping this event.")
            return
        }
        settingDidChange(.identifier(DriCore.DroneIdentifier(type: newType, id: value)))
    }

    func onDriState(mode: ArsdkFeatureDriMode) {
        switch mode {
        case .disabled:
            settingDidChange(.mode(false))
        case .enabled:
            settingDidChange(.mode(true))
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown DriSwitchMode, skipping this event.")
        }
    }

    func onCapabilities(supportedCapabilitiesBitField: UInt) {
        let modeSwitchSupported = DriSupportedCapabilities.createSetFrom(
            bitField: supportedCapabilitiesBitField).contains(.onOff)
        capabilitiesDidChange(.modeSwitchSupport(modeSwitchSupported))
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension DriSupportedCapabilities: ArsdkMappableEnum {

    /// Create set of dri capabilites from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all dri capabilites set in bitField
    static func createSetFrom(bitField: UInt) -> Set<DriSupportedCapabilities> {
        var result = Set<DriSupportedCapabilities>()
        ArsdkFeatureDriSupportedCapabilitiesBitField.forAllSet(in: UInt(bitField)) { arsdkValue in
            if let state = DriSupportedCapabilities(fromArsdk: arsdkValue) {
                result.insert(state)
            }
        }
        return result
    }

    static var arsdkMapper = Mapper<DriSupportedCapabilities, ArsdkFeatureDriSupportedCapabilities>([
        .onOff: .onOff])
}

/// Extension to make DriIdType storable.
extension DriIdType: StorableEnum {
    static var storableMapper = Mapper<DriIdType, String>([
        .ANSI_CTA_2063: "ansiCta2063",
        .FR_30_Octets: "fr30Octets"])
}

/// Extension to make DriCore.DroneIdentifier storable.
extension DriCore.DroneIdentifier: StorableType {

    /// Store key.
    private enum Key: String {
        case type, id
    }

    /// Constructor from store data.
    ///
    /// - Parameter content: store data
    init?(from content: AnyObject?) {
        if let content = StorableDict<String, AnyStorable>(from: content),
            let type = DriIdType(AnyStorable(content[Key.type.rawValue])),
            let id = String(AnyStorable(content[Key.id.rawValue])) {
            self.init(type: type, id: id)
        } else {
            return nil
        }
    }

    /// Convert to storable.
    ///
    /// - Returns: storable containing drone identifier
    func asStorable() -> StorableProtocol {
        return StorableDict([
            Key.type.rawValue: AnyStorable(type),
            Key.id.rawValue: AnyStorable(id)])
    }
}
