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

/// Base controller for antiflicker peripheral
class AntiflickerController: DeviceComponentController, AntiflickerBackend {
    /// Component settings key
    private static let settingKey = "Antiflicker"

    /// List of countries with 60Hz electrical network. It's assumed that all other countries have 50hz
    /// electrical network
    private let countries60Hz: Set<String> =
        ["DO", "BM", "HT", "KN", "HN", "BR", "BS", "FM", "BZ", "PR", "NI", "PW", "TW", "TT", "PA", "PF", "PE", "LR",
         "PH", "GU", "GT", "CO", "VE", "AG", "VG", "AI", "VI", "CA", "GY", "AS", "EC", "AW", "CR", "SA", "CU", "MF",
         "SR", "SV", "US", "KR", "KP", "MS", "KY", "MX"]

    /// Antiflicker component
    private(set) var antiflicker: AntiflickerCore!

    /// Store device specific values
    private let deviceStore: SettingsStore?

    /// Preset store for this piloting interface
    private var presetStore: SettingsStore?

    /// Reverse geocoder for location based auto mode
    private let reverseGeocoder: ReverseGeocoderUtilityCore?
    /// Reverse geocoder monitor
    private var reverseGeocoderMonitor: MonitorCore?

    /// True if drone supports auto mode
    private(set) var droneSupportsAutoMode = false

    /// Current frequency given by auto mode. Nil if unknown.
    private var autoModeCurrentFrequency: AntiflickerMode?

    /// All settings that can be stored
    enum SettingKey: String, StoreKey {
        case modeKey = "mode"
    }

    /// Stored settings
    enum Setting: Hashable {
        case mode(AntiflickerMode)
        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .mode: return .modeKey
            }
        }
        /// All values to allow enumerating settings
        static let allCases: [Setting] = [.mode(.off)]

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }

        static func == (lhs: Setting, rhs: Setting) -> Bool {
            return lhs.key == rhs.key
        }
    }

    /// Stored capabilities for settings
    enum Capabilities {
        case mode(Set<AntiflickerMode>)

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
            deviceStore = deviceController.deviceStore.getSettingsStore(key: AntiflickerController.settingKey)
            presetStore = deviceController.presetStore.getSettingsStore(key: AntiflickerController.settingKey)
        }
        reverseGeocoder = deviceController.engine.utilities.getUtility(Utilities.reverseGeocoder)

        super.init(deviceController: deviceController)
        antiflicker = AntiflickerCore(store: deviceController.device.peripheralStore, backend: self)
        setDefaults()
        // load settings
        if let deviceStore = deviceStore, let presetStore = presetStore, !deviceStore.new && !presetStore.new {
            loadPresets()
            antiflicker.publish()
        }
    }

    /// Sets anti-flickering mode
    ///
    /// - Parameter mode: the new anti-flickering mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(mode: AntiflickerMode) -> Bool {
        presetStore?.write(key: SettingKey.modeKey, value: mode).commit()
        if connected {
            if mode == .auto && !droneSupportsAutoMode {
                return startCountryMonitoring()
            } else {
                stopCountryMonitoring()
                return sendModeCommand(mode)
            }
        } else {
            antiflicker.update(mode: mode).notifyUpdated()
            return false
        }
    }

    /// Send mode command. Subclass must override this function to send the command
    ///
    /// - Parameters:
    ///   - mode: requested mode.
    ///   - locationBasedValue: if mode is auto, the corresponding value set from current location.
    /// - Returns: true if the command has been sent
    func sendModeCommand(_ mode: AntiflickerMode, locationBasedValue: AntiflickerValue? = nil) -> Bool {
        return false
    }

    /// Drone is about to be forgotten
    override func willForget() {
        deviceStore?.clear()
        antiflicker.unpublish()
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
        antiflicker.publish()
        super.didConnect()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        super.didDisconnect()

        // clear all non saved values
        antiflicker.cancelSettingsRollback().update(value: .unknown)

        stopCountryMonitoring()

        // unpublish if offline settings are disabled
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            antiflicker.unpublish()
        }
        antiflicker.notifyUpdated()
    }

    /// Preset has been changed
    override func presetDidChange() {
        super.presetDidChange()
        // reload preset store
        presetStore = deviceController.presetStore.getSettingsStore(key: AntiflickerController.settingKey)
        loadPresets()
        if connected {
            applyPresets()
        }
    }

    /// Set default values. Subclass can override this function to customize default values
    func setDefaults() {
    }

    /// Load saved settings
    private func loadPresets() {
        if let presetStore = presetStore, let deviceStore = deviceStore {
            for setting in Setting.allCases {
                switch setting {
                case .mode:
                    if let supportedModesValues: StorableArray<AntiflickerMode> = deviceStore.read(key: setting.key),
                        let mode: AntiflickerMode = presetStore.read(key: setting.key) {
                        let supportedModes = updateSupportedModes(Set(supportedModesValues.storableValue))
                        if supportedModes.contains(mode) {
                            antiflicker.update(supportedModes: supportedModes).update(mode: mode)
                        }
                    }
                }
                antiflicker.notifyUpdated()
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
                if let preset: AntiflickerMode = presetStore?.read(key: setting.key) {
                    if preset == .auto && !droneSupportsAutoMode {
                        _ = startCountryMonitoring()
                    } else {
                        stopCountryMonitoring()
                    }
                    if preset != mode {
                        // only send command if mode is not auto and drone does not support auto mode
                        if preset != .auto || droneSupportsAutoMode {
                            _ = sendModeCommand(preset)
                        }
                    }
                    antiflicker.update(mode: preset)
                } else {
                    antiflicker.update(mode: mode)
                }
            }
        }
        antiflicker.notifyUpdated()
    }

    /// Called when a command that notify a setting change has been received
    ///
    /// - Parameter setting: setting that changed
    func settingDidChange(_ setting: Setting) {
        droneSettings.insert(setting)
        switch setting {
        case .mode(let mode):
             if connected {
                if mode == .auto && !droneSupportsAutoMode {
                    _ = startCountryMonitoring()
                } else {
                    stopCountryMonitoring()
                }
                antiflicker.update(mode: mode)
            }
        }
        antiflicker.notifyUpdated()
    }

    /// Process stored capabilities changes
    ///
    /// Update antiflicker and device store. Note caller must call `antiflicker.notifyUpdated()` to notify change.
    ///
    /// - Parameter capabilities: changed capabilities
    func capabilitiesDidChange(_ capabilities: Capabilities) {
        switch capabilities {
        case .mode(let modes):
            deviceStore?.write(key: capabilities.key, value: StorableArray(Array(modes)))
            antiflicker.update(supportedModes: updateSupportedModes(modes))
        }
        deviceStore?.commit()
    }

    /// Add auto-mode to the set of mode if reverseGeocoder is available
    ///
    /// - Parameter modes: set of supported mode
    /// - Returns: set of supported mode with .auto added if available
    private func updateSupportedModes(_ modes: Set<AntiflickerMode>) -> Set<AntiflickerMode> {
        // if drone supportes auto mode
        if modes.contains(.auto) {
            droneSupportsAutoMode = true
            return modes
        }
        // if not add auto mode based on location
        var computedModes = modes
        if modes.contains(.mode50Hz) && modes.contains(.mode60Hz) && reverseGeocoder != nil {
            computedModes.insert(.auto)
        }
        return computedModes
    }

    /// Starts monitoring current country changes in case it is stopped.
    private func startCountryMonitoring() -> Bool {
        // se to true by default, because if the country is not know for the moment, no command will be sent so setting
        // should be marked as updating.
        // Note that if country is known, monitor will be synchronously called so cmdSent.
        var cmdSent = true
        if reverseGeocoderMonitor == nil {
            reverseGeocoderMonitor = reverseGeocoder?.startReverseGeocoderMonitoring { [unowned self] placemark in
                if let locationBasedValue = self.getAntiflickerValue(forIsoCountryCode: placemark?.isoCountryCode) {
                   cmdSent = self.applyAutoMode(withLocationBasedValue: locationBasedValue)
                }
            }
        } else {
            if let locationBasedValue = self.getAntiflickerValue(
                forIsoCountryCode: reverseGeocoder?.placemark?.isoCountryCode) {

                cmdSent = applyAutoMode(withLocationBasedValue: locationBasedValue)
            }
        }
        return cmdSent
    }

    /// Applies on the drone the auto mode with the given location based antiflicker value
    ///
    /// - Parameter locationBasedValue: location based antiflicker value
    /// - Returns: true if value has been sent to the drone.
    private func applyAutoMode(withLocationBasedValue locationBasedValue: AntiflickerValue) -> Bool {
        if connected {
            // if command is not sent, update the api
            if !sendModeCommand(.auto, locationBasedValue: locationBasedValue) {
                antiflicker.update(mode: .auto).notifyUpdated()
                return false
            }
        }
        return true
    }

    /// Gets the antiflicker value for a given iso country code
    ///
    /// - Parameter isoCountryCode: the iso country code
    /// - Returns: the matching antiflicker value or nil if country code is nil
    private func getAntiflickerValue(forIsoCountryCode isoCountryCode: String?) -> AntiflickerValue? {
        if let isoCountryCode = isoCountryCode {
            if countries60Hz.contains(isoCountryCode.uppercased()) {
                return .value60Hz
            } else {
                return .value50Hz
            }
        }
        return nil
    }

    /// Stops monitoring current country changes in case it is started.
    private func stopCountryMonitoring() {
        reverseGeocoderMonitor?.stop()
        reverseGeocoderMonitor = nil
    }
}

// Extension to make AntiflickerMode storable
extension AntiflickerMode: StorableEnum {
    static var storableMapper = Mapper<AntiflickerMode, String>([
        .off: "off",
        .mode50Hz: "50Hz",
        .mode60Hz: "60Hz",
        .auto: "auto"])
}
