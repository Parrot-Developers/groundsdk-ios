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

/// Leds supported capabilities
@objc(GSLedsSupportedCapabilities)
public enum LedsSupportedCapabilities: Int, CustomStringConvertible {

    /// Leds switch is off
    @objc(GSLedsSupportedCapabilitiesOnOff)
    case onOff

    /// Debug description.
    public var description: String {
        switch self {
        case .onOff:         return "onOff"
        }
    }

    /// Comparator
    public static func < (lhs: LedsSupportedCapabilities, rhs: LedsSupportedCapabilities) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    /// Set containing all possible values
    public static let allCases: Set<LedsSupportedCapabilities> = [
        .onOff]

}

/// Base controller for leds peripheral
class LedsController: DeviceComponentController, LedsBackend {

    /// Leds component
    private var leds: LedsCore!

    /// component settings key
    private static let settingKey = "LedsController"

    /// Preset store for this leds interface
    private var presetStore: SettingsStore?

    /// All settings that can be stored
    enum SettingKey: String, StoreKey {
        case stateKey = "state"
    }

    /// Stored settings
    enum Setting: Hashable {
        case state(Bool)
        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .state: return .stateKey
            }
        }
        /// All values to allow enumerating settings
        static let allCases: Set<Setting> = [.state(false)]

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }

        static func == (lhs: Setting, rhs: Setting) -> Bool {
            return lhs.key == rhs.key
        }
    }

    /// Setting values as received from the drone
    private var droneSettings = Set<Setting>()

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            presetStore = nil
        } else {
            presetStore = deviceController.presetStore.getSettingsStore(key: LedsController.settingKey)
        }

        super.init(deviceController: deviceController)
        leds = LedsCore(store: deviceController.device.peripheralStore, backend: self)

        // load settings
        if let presetStore = presetStore, !presetStore.new {
            loadPresets()
            leds.publish()
        }
    }

    func set(state: Bool) -> Bool {
        presetStore?.write(key: SettingKey.stateKey, value: state).commit()
        if connected {
            return sendStateCommand(state)
        } else {
            leds.update(state: state).notifyUpdated()
            return false
        }
    }

    /// Switch Activation or deactivation command
    ///
    /// - Parameter state: requested state.
    /// - Returns: true if the command has been sent
    func sendStateCommand(_ state: Bool) -> Bool {
        var commandSent = false
        if state {
            sendCommand(ArsdkFeatureLeds.activateEncoder())
            commandSent = true
        } else {
            sendCommand(ArsdkFeatureLeds.deactivateEncoder())
            commandSent = true
        }
        return commandSent
    }

    /// Load saved settings
    private func loadPresets() {
        if let presetStore = presetStore {
            Setting.allCases.forEach {
                switch $0 {
                case .state:
                    if let state: Bool = presetStore.read(key: $0.key) {
                        leds.update(state: state)
                    }
                    leds.notifyUpdated()
                }
            }
        }
    }

    /// Drone is connected
    override func didConnect() {
        applyPresets()
        if leds.supportedSwitch {
            leds.publish()
        } else {
             leds.unpublish()
        }
    }

    /// Drone is disconnected
    override func didDisconnect() {
        leds.cancelSettingsRollback()
        // unpublish if offline settings are disabled
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            leds.unpublish()
        }
        leds.notifyUpdated()
    }

    /// Drone is about to be forgotten
    override func willForget() {
        leds.unpublish()
        super.willForget()
    }

    /// Preset has been changed
    override func presetDidChange() {
        super.presetDidChange()
        // reload preset store
        presetStore = deviceController.presetStore.getSettingsStore(key: LedsController.settingKey)
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
            case .state (let state):
                if let preset: Bool = presetStore?.read(key: setting.key) {
                    if preset != state {
                        _ = sendStateCommand(preset)
                    }
                    leds.update(state: preset).notifyUpdated()
                } else {
                    leds.update(state: state).notifyUpdated()
                }
            }
        }
    }

    /// Called when a command that notify a setting change has been received
    /// - Parameter setting: setting that changed
    func settingDidChange(_ setting: Setting) {
        droneSettings.insert(setting)
        switch setting {
        case .state(let state):
            if connected {
                leds.update(state: state).notifyUpdated()
            }
        }
        leds.notifyUpdated()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureLedsUid {
            ArsdkFeatureLeds.decode(command, callback: self)
        }
    }
}

/// Leds decode callback implementation
extension LedsController: ArsdkFeatureLedsCallback {

    func onSwitchState(switchState: ArsdkFeatureLedsSwitchState) {
        switch switchState {
        case .off:
            settingDidChange(.state(false))
        case .on:
            settingDidChange(.state(true))
        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown LedsSwitchState, skipping this event.")
        }
    }

    func onCapabilities(supportedCapabilitiesBitField: UInt) {
        leds.update(supportedSwitch: LedsSupportedCapabilities.createSetFrom(
            bitField: supportedCapabilitiesBitField).contains(.onOff))
    }
}

extension LedsSupportedCapabilities: ArsdkMappableEnum {

    /// Create set of led capabilites from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all led capabilites set in bitField
    static func createSetFrom(bitField: UInt) -> Set<LedsSupportedCapabilities> {
        var result = Set<LedsSupportedCapabilities>()
        ArsdkFeatureLedsSupportedCapabilitiesBitField.forAllSet(in: UInt(bitField)) { arsdkValue in
            if let state = LedsSupportedCapabilities(fromArsdk: arsdkValue) {
                result.insert(state)
            }
        }
        return result
    }
    static var arsdkMapper = Mapper<LedsSupportedCapabilities, ArsdkFeatureLedsSupportedCapabilities>([
        .onOff: .onOff])
}
