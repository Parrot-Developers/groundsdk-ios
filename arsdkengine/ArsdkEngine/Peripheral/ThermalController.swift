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

/// Base controller for thermal control peripheral
class ThermalController: DeviceComponentController, ThermalControlBackend {

    /// Component settings key
    private static let settingKey = "ThermalControl"

    /// Thermal control component
    private(set) var thermalControl: ThermalControlCore!

    /// Store device specific values
    private let deviceStore: SettingsStore?

    /// Preset store for this piloting interface
    private var presetStore: SettingsStore?

    /// Latest emissivity value sent to drone or latest value received from drone
    private var currentEmissivity: Float?

    /// Latest background temperature value sent to drone or latest value received from drone
    private var currentBackgroundTemperature: Float?

    /// Latest palette settings sent to drone or latest settings received from drone
    private var currentPaletteSettings: ArsdkThermalPaletteSettings?

    /// Latest palette colors sent to drone or latest colors received from drone
    private var currentColors: [ThermalColor]?

    /// Palette colors being received from drone
    private var paletteParts: [ThermalColor]?

    /// All settings that can be stored
    enum SettingKey: String, StoreKey {
        case modeKey = "mode"
        case sensitivityRangeKey = "sensitivityRange"
        case calibrationModeKey = "calibrationMode"
    }

    /// Stored settings
    enum Setting: Hashable {
        case mode(ThermalControlMode)
        case sensitivityRange(ThermalSensitivityRange)
        case calibrationMode(ThermalCalibrationMode)
        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .mode: return .modeKey
            case .sensitivityRange: return .sensitivityRangeKey
            case .calibrationMode: return .calibrationModeKey
            }
        }
        /// All values to allow enumerating settings
        static let allCases: [Setting] = [.mode(.disabled), .sensitivityRange(.high), .calibrationMode(.automatic)]

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }

        static func == (lhs: Setting, rhs: Setting) -> Bool {
            return lhs.key == rhs.key
        }
    }

    /// Stored capabilities for settings
    enum Capabilities {
        case mode(Set<ThermalControlMode>)

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
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            deviceStore = nil
            presetStore = nil
        } else {
            deviceStore = deviceController.deviceStore.getSettingsStore(key: ThermalController.settingKey)
            presetStore = deviceController.presetStore.getSettingsStore(key: ThermalController.settingKey)
        }

        super.init(deviceController: deviceController)
        thermalControl = ThermalControlCore(store: deviceController.device.peripheralStore, backend: self)
        // load settings
        if let deviceStore = deviceStore, let presetStore = presetStore, !deviceStore.new && !presetStore.new {
            loadPresets()
            thermalControl.publish()
        }
    }

    /// Sets thermal control mode
    ///
    /// - Parameter mode: the new thermal control mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(mode: ThermalControlMode) -> Bool {
        presetStore?.write(key: SettingKey.modeKey, value: mode).commit()
        if connected {
            return sendModeCommand(mode)
        } else {
            thermalControl.update(mode: mode).notifyUpdated()
            return false
        }
    }

    /// Set emissivity
    ///
    /// - Parameter emissivity: emissivity value
    func set(emissivity: Double) {
        let emissivity = Float(emissivity)
        if connected, emissivity != currentEmissivity {
            currentEmissivity = emissivity
            sendEmissivityCommand(emissivity)
        }
    }

    /// Sets thermal camera calibration mode.
    ///
    /// - Parameter calibrationMode: the new calibration mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(calibrationMode: ThermalCalibrationMode) -> Bool {
        presetStore?.write(key: SettingKey.calibrationModeKey, value: calibrationMode).commit()
        if connected {
            return sendCalibrationModeCommand(calibrationMode)
        } else {
            thermalControl.update(mode: calibrationMode).notifyUpdated()
            return false
        }
    }

    /// Triggers a calibration of the thermal camera.
    ///
    /// - Returns: true if the command has been sent, false otherwise
    func calibrate() -> Bool {
        if connected {
            return sendCalibrateCommand()
        } else {
            return false
        }
    }

    /// Set current palette configuration.
    ///
    /// - Parameter palette: palette configuration
    func set(palette: ThermalPalette) {
        if palette.colors != currentColors {
            currentColors = palette.colors
            sendPaletteColorCommands(colors: palette.colors)
        }
        switch palette {
        case let palette as ThermalAbsolutePalette:
            sendPaletteSettingsCommand(mode: .absolute,
                                       lowestTemp: palette.lowestTemperature, highestTemp: palette.highestTemperature,
                                       outsideColorization: palette.outsideColorization)
        case let palette as ThermalRelativePalette:
            sendPaletteSettingsCommand(mode: .relative,
                                       lowestTemp: palette.lowestTemperature, highestTemp: palette.highestTemperature,
                                       locked: palette.locked)
        case let palette as ThermalSpotPalette:
            sendPaletteSettingsCommand(mode: .spot, spotType: palette.type, spotThreshold: palette.threshold)
        default:
            ULog.w(.tag, "Unknown thermal palette configuration type.")
        }
    }

    /// Set background temperature.
    ///
    /// - Parameter backgroundTemperature: background temperature
    func set(backgroundTemperature: Double) {
        let backgroundTemperature = Float(backgroundTemperature)
        if connected, backgroundTemperature != currentBackgroundTemperature {
            currentBackgroundTemperature = backgroundTemperature
            sendBackgroundTemperatureCommand(backgroundTemperature: backgroundTemperature)
        }
    }

    /// Set rendering
    ///
    /// - Parameter rendering: rendering configuration
    func set(rendering: ThermalRendering) {
        switch rendering.mode {
        case .visible:
            sendRenderingCommand(mode: .visible, blendingRate: rendering.blendingRate)
        case .thermal:
            sendRenderingCommand(mode: .thermal, blendingRate: rendering.blendingRate)
        case .blended:
            sendRenderingCommand(mode: .blended, blendingRate: rendering.blendingRate)
        case .monochrome:
            sendRenderingCommand(mode: .monochrome, blendingRate: rendering.blendingRate)
        }
    }

    /// Set range
    ///
    /// - Parameter range: range
    func set(range: ThermalSensitivityRange) -> Bool {
        presetStore?.write(key: SettingKey.sensitivityRangeKey, value: range).commit()
        if connected {
            switch range {
            case .high:
                return sendSensitivityCommand(range: .high)
            case .low:
                return sendSensitivityCommand(range: .low)
            }
        } else {
            thermalControl.update(range: range).notifyUpdated()
            return false
        }
    }

    /// Drone is about to be forgotten
    override func willForget() {
        deviceStore?.clear()
        thermalControl.unpublish()
        super.willForget()
    }

    /// Drone is about to be connect
    override func willConnect() {
        super.willConnect()
        // remove settings stored while connecting. We will get new one on the next connection.
        droneSettings.removeAll()
        currentEmissivity = nil
        currentBackgroundTemperature = nil
        currentPaletteSettings = nil
        currentColors = nil
        paletteParts = nil
    }

    /// Drone is connected
    override func didConnect() {
        storeNewPresets()
        applyPresets()
        if thermalControl.setting.supportedModes.isEmpty {
            thermalControl.unpublish()
        } else {
            thermalControl.publish()
        }
        super.didConnect()

    }

    /// Drone is disconnected
    override func didDisconnect() {
        super.didDisconnect()

        // clear all non saved values
        thermalControl.cancelSettingsRollback().update(mode: .disabled)

        // unpublish if offline settings are disabled
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            thermalControl.unpublish()
        } else {
            thermalControl.notifyUpdated()
        }
    }

    /// Preset has been changed
    override func presetDidChange() {
        super.presetDidChange()
        // reload preset store
        presetStore = deviceController.presetStore.getSettingsStore(key: ThermalController.settingKey)
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
                    if let supportedModesValues: StorableArray<ThermalControlMode> = deviceStore.read(key: setting.key),
                        let mode: ThermalControlMode = presetStore.read(key: setting.key) {
                        let supportedModes = Set(supportedModesValues.storableValue)
                        if supportedModes.contains(mode) {
                            thermalControl.update(supportedModes: supportedModes).update(mode: mode)
                        }
                    }
                case .sensitivityRange:
                    if let range: ThermalSensitivityRange = presetStore.read(key: setting.key) {
                        thermalControl.update(range: range)
                    }
                case .calibrationMode:
                    if let calibrationMode: ThermalCalibrationMode = presetStore.read(key: setting.key) {
                        thermalControl.update(mode: calibrationMode)
                    }
                }
                thermalControl.notifyUpdated()
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
                if let preset: ThermalControlMode = presetStore?.read(key: setting.key) {
                    if preset != mode {
                        _ = sendModeCommand(preset)
                    }
                    thermalControl.update(mode: preset).notifyUpdated()
                } else {
                    thermalControl.update(mode: mode).notifyUpdated()
                }
            case .sensitivityRange(let sensitivityRange):
                if let preset: ThermalSensitivityRange = presetStore?.read(key: setting.key) {
                    if preset != sensitivityRange {
                        _ = set(range: preset)
                    }
                    thermalControl.update(range: preset).notifyUpdated()
                } else {
                    thermalControl.update(range: sensitivityRange).notifyUpdated()
                }
            case .calibrationMode(let mode):
                if let preset: ThermalCalibrationMode = presetStore?.read(key: setting.key) {
                    if preset != mode {
                        _ = sendCalibrationModeCommand(preset)
                    }
                    thermalControl.update(mode: preset).notifyUpdated()
                } else {
                    thermalControl.update(mode: mode).notifyUpdated()
                }
            }
        }
    }

    /// Called when a command that notify a setting change has been received
    /// - Parameter setting: setting that changed
    func settingDidChange(_ setting: Setting) {
        droneSettings.insert(setting)
        if connected {
            switch setting {
            case .mode(let mode):
                thermalControl.update(mode: mode)
            case .sensitivityRange(let sensitivityRange):
                thermalControl.update(range: sensitivityRange)
            case .calibrationMode(let mode):
                thermalControl.update(mode: mode)
            }
        }
        thermalControl.notifyUpdated()
    }

    /// Process stored capabilities changes
    ///
    /// Update thermal control and device store. Caller must call `ThermalControl.notifyUpdated()` to notify change.
    ///
    /// - Parameter capabilities: changed capabilities
    func capabilitiesDidChange(_ capabilities: Capabilities) {
        switch capabilities {
        case .mode(let modes):
            deviceStore?.write(key: capabilities.key, value: StorableArray(Array(modes)))
            thermalControl.update(supportedModes: modes)
        }
        deviceStore?.commit()
    }

    /// A command has been received
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureThermalUid {
            ArsdkFeatureThermal.decode(command, callback: self)
        }
    }

    /// Send mode command.
    ///
    /// - Parameter mode: requested mode.
    /// - Returns: true if the command has been sent
    func sendModeCommand(_ mode: ThermalControlMode) -> Bool {
        var commandSent = false
        switch mode {
        case .standard:
            sendCommand(ArsdkFeatureThermal.setModeEncoder(mode: .standard))
            commandSent = true
        case .disabled:
            sendCommand(ArsdkFeatureThermal.setModeEncoder(mode: .disabled))
            commandSent = true
        case .blended:
            sendCommand(ArsdkFeatureThermal.setModeEncoder(mode: .blended))
            commandSent = true
        }
        return commandSent
    }

    /// Send emissivity command.
    ///
    /// - Parameter emissivity: requested emissivity.
    func sendEmissivityCommand(_ emissivity: Float) {
        sendCommand(ArsdkFeatureThermal.setEmissivityEncoder(emissivity: emissivity))
    }

    /// Send calibration mode command.
    ///
    /// - Parameter mode: requested mode.
    /// - Returns: true if the command has been sent
    func sendCalibrationModeCommand(_ mode: ThermalCalibrationMode) -> Bool {
        var commandSent = false
        switch mode {
        case .automatic:
            sendCommand(ArsdkFeatureThermal.setShutterModeEncoder(trigger: .auto))
            commandSent = true
        case .manual:
            sendCommand(ArsdkFeatureThermal.setShutterModeEncoder(trigger: .manual))
            commandSent = true
        }
        return commandSent
    }

    /// Send calibrate mode command.
    ///
    /// - Returns: true if the command has been sent
    func sendCalibrateCommand() -> Bool {
        sendCommand(ArsdkFeatureThermal.triggShutterEncoder())
        return true
    }

    /// Send palette colors.
    ///
    /// - Parameter colors: colors to send
    func sendPaletteColorCommands(colors: [ThermalColor]) {
        if colors.count == 0 {
            // empty color list
            let listFlagsBitField: UInt = Bitfield<ArsdkFeatureGenericListFlags>.of(.empty)
            sendCommand(ArsdkFeatureThermal.setPalettePartEncoder(red: 0, green: 0, blue: 0, index: 0,
                                                                  listFlagsBitField: listFlagsBitField))
            return
        }
        var index = 0
        for color in colors {
            var listFlagsBitField: UInt = 0
            if index == 0 {
                // list flag for first element
                listFlagsBitField = Bitfield<ArsdkFeatureGenericListFlags>.of(.first)
            }
            if index == colors.count - 1 {
                // list flag for last element
                listFlagsBitField |= Bitfield<ArsdkFeatureGenericListFlags>.of(.last)
            }
            sendCommand(ArsdkFeatureThermal.setPalettePartEncoder(red: Float(color.red),
                                                                  green: Float(color.green),
                                                                  blue: Float(color.blue),
                                                                  index: Float(color.position),
                                                                  listFlagsBitField: listFlagsBitField))
            index += 1
        }
    }

    /// Send palette settings.
    ///
    /// - Parameters:
    ///    - mode: palette mode
    ///    - lowestTemp: temperature associated to the lower boundary of the palette, in Kelvin,
    ///                  used only when palette mode is 'absolute' or when mode is 'relative' and 'locked'
    ///    - highestTemp: temperature associated to the higher boundary of the palette, in Kelvin,
    ///                  used only when palette mode is 'absolute' or when mode is 'relative' and 'locked'
    ///    - outsideColorization: colorization mode outside palette bounds when palette mode is 'absolute'
    ///    - locked: when palette mode is 'relative', 'true' to lock the palette, 'false' to unlock
    ///    - spotType: temperature type to highlight, when palette mode is 'spot'
    ///    - spotThreshold: threshold palette index for highlighting, from 0 to 1, when palette mode is 'spot'
    func sendPaletteSettingsCommand(mode: ArsdkFeatureThermalPaletteMode,
                                    lowestTemp: Double = 0, highestTemp: Double = 0,
                                    outsideColorization: ThermalColorizationMode = .extended,
                                    locked: Bool = false,
                                    spotType: ThermalSpotType = .hot, spotThreshold: Double = 0) {
        // outside colorization mode for absolute palette
        let arsdkOutsideColorization: ArsdkFeatureThermalColorizationMode
        switch outsideColorization {
        case .limited:
            arsdkOutsideColorization = .limited
        case .extended:
            arsdkOutsideColorization = .extended
        }
        // locked or unlocked mode for relative palette
        let relativeRangeMode: ArsdkFeatureThermalRelativeRangeMode = locked ? .locked : .unlocked
        // temperature type to highlight for spot palette
        let arsdkSpotType: ArsdkFeatureThermalSpotType
        switch spotType {
        case .hot:
            arsdkSpotType = .hot
        case .cold:
            arsdkSpotType = .cold
        }
        let paletteSettings = ArsdkThermalPaletteSettings(mode: mode,
                                                          lowestTemp: Float(lowestTemp),
                                                          highestTemp: Float(highestTemp),
                                                          outsideColorization: arsdkOutsideColorization,
                                                          relativeRangeMode: relativeRangeMode,
                                                          spotType: arsdkSpotType,
                                                          spotThreshold: Float(spotThreshold))
        if paletteSettings != currentPaletteSettings {
            currentPaletteSettings = paletteSettings
            // send command
            sendCommand(ArsdkFeatureThermal.setPaletteSettingsEncoder(mode: mode,
                                                                      lowestTemp: Float(lowestTemp),
                                                                      highestTemp: Float(highestTemp),
                                                                      outsideColorization: arsdkOutsideColorization,
                                                                      relativeRange: relativeRangeMode,
                                                                      spotType: arsdkSpotType,
                                                                      spotThreshold: Float(spotThreshold)))
        }
    }

    /// Send background temperature.
    ///
    /// - Parameter backgroundTemperature: background temperature to send
    func sendBackgroundTemperatureCommand(backgroundTemperature: Float) {
        sendCommand(ArsdkFeatureThermal.setBackgroundTemperatureEncoder(
            backgroundTemperature: backgroundTemperature))
    }

    /// Send rendering
    ///
    /// - Parameters:
    ///    - mode: mode
    ///    - blendingRate: blending rate
    func sendRenderingCommand(mode: ArsdkFeatureThermalRenderingMode, blendingRate: Double) {
        sendCommand(ArsdkFeatureThermal.setRenderingEncoder(mode: mode, blendingRate: Float(blendingRate)))
    }

    /// Send sensitivity
    ///
    /// - Parameter range: sensitivity range
    func sendSensitivityCommand(range: ArsdkFeatureThermalRange) -> Bool {
        sendCommand(ArsdkFeatureThermal.setSensitivityEncoder(range: range))
        return true
    }
}

// Extension to make ThermalControlMode storable
extension ThermalControlMode: StorableEnum {
    static var storableMapper = Mapper<ThermalControlMode, String>([
        .standard: "standard",
        .disabled: "disabled",
        .blended: "blended"])
}

// Extension to make Thermal sensitivity range storable
extension ThermalSensitivityRange: StorableEnum {
    static var storableMapper = Mapper<ThermalSensitivityRange, String>([
        .high: "high",
        .low: "low"])
}

// Extension to make ThermalCalibrationMode storable
extension ThermalCalibrationMode: StorableEnum {
    static var storableMapper = Mapper<ThermalCalibrationMode, String>([
        .automatic: "automatic",
        .manual: "manual"])
}

/// Thermal feature decode callback implementation
extension ThermalController: ArsdkFeatureThermalCallback {

    func onMode(mode: ArsdkFeatureThermalMode) {
        switch mode {
        case .standard:
            settingDidChange(.mode(.standard))
        case .disabled:
            settingDidChange(.mode(.disabled))
        case .blended:
            settingDidChange(.mode(.blended))
        case .sdkCoreUnknown:
            // don't change the thermal control modes
            ULog.w(.tag, "Unknown thermal control mode, skipping this event.")
        }
    }

    func onCapabilities(modesBitField: UInt) {
        var availableMode: Set<ThermalControlMode> = []
        if ArsdkFeatureThermalModeBitField.isSet(.disabled, inBitField: modesBitField) {
            availableMode.insert(.disabled)
        }
        if ArsdkFeatureThermalModeBitField.isSet(.standard, inBitField: modesBitField) {
            availableMode.insert(.standard)
        }
        if ArsdkFeatureThermalModeBitField.isSet(.blended, inBitField: modesBitField) {
            availableMode.insert(.blended)
        }
        capabilitiesDidChange(.mode(availableMode))
        thermalControl.notifyUpdated()
    }

    func onBackgroundTemperature(backgroundTemperature: Float) {
        currentBackgroundTemperature = backgroundTemperature
    }

    func onEmissivity(emissivity: Float) {
        currentEmissivity = emissivity
    }

    func onPalettePart(red: Float, green: Float, blue: Float, index: Float, listFlagsBitField: UInt) {
        if paletteParts == nil {
            paletteParts = []
        }
        if ArsdkFeatureGenericListFlagsBitField.isSet(.empty, inBitField: listFlagsBitField) {
            paletteParts = []
            currentColors = [ThermalColor]()
        } else {
            let color = ThermalColor(Double(red), Double(green), Double(blue), Double(index))
            if ArsdkFeatureGenericListFlagsBitField.isSet(.remove, inBitField: listFlagsBitField) {
                currentColors?.removeAll(where: { $0 == color })
            } else {
                if ArsdkFeatureGenericListFlagsBitField.isSet(.first, inBitField: listFlagsBitField) {
                    paletteParts = []
                }
                paletteParts?.append(color)
                if ArsdkFeatureGenericListFlagsBitField.isSet(.last, inBitField: listFlagsBitField) {
                    currentColors = paletteParts
                    paletteParts = nil
                }
            }
        }
    }

    func onPaletteSettings(mode: ArsdkFeatureThermalPaletteMode, lowestTemp: Float, highestTemp: Float,
                           outsideColorization: ArsdkFeatureThermalColorizationMode,
                           relativeRange: ArsdkFeatureThermalRelativeRangeMode,
                           spotType: ArsdkFeatureThermalSpotType, spotThreshold: Float) {
        currentPaletteSettings = ArsdkThermalPaletteSettings(mode: mode,
                                                          lowestTemp: lowestTemp,
                                                          highestTemp: highestTemp,
                                                          outsideColorization: outsideColorization,
                                                          relativeRangeMode: relativeRange,
                                                          spotType: spotType,
                                                          spotThreshold: spotThreshold)
    }

    func onSensitivity(currentRange: ArsdkFeatureThermalRange) {
        switch currentRange {
        case .high:
            settingDidChange(.sensitivityRange(.high))
        case .low:
            settingDidChange(.sensitivityRange(.low))
        case .sdkCoreUnknown:
            // don't change the range of sensitivity
            ULog.w(.tag, "Unknown thermal range, skipping this event.")
        }
    }

    func onShutterMode(currentTrigger: ArsdkFeatureThermalShutterTrigger) {
        switch currentTrigger {
        case .auto:
            settingDidChange(.calibrationMode(.automatic))
        case .manual:
            settingDidChange(.calibrationMode(.manual))
        case .sdkCoreUnknown:
            // don't change the thermal calibration modes
            ULog.w(.tag, "Unknown thermal shutter mode, skipping this event.")
        }
    }
}

/// Structure allowing to store palette settings sent to drone or received from drone.
private struct ArsdkThermalPaletteSettings: Equatable {

    /// Palette mode.
    let mode: ArsdkFeatureThermalPaletteMode

    /// Lowest temperature, in Kelvin.
    let lowestTemp: Float

    /// Highest temperature, in Kelvin.
    let highestTemp: Float

    /// Outside colorization mode for absolute palette.
    let outsideColorization: ArsdkFeatureThermalColorizationMode

    /// Locked or unlocked mode for relative palette.
    let relativeRangeMode: ArsdkFeatureThermalRelativeRangeMode

    /// Temperature type to highlight for spot palette.
    let spotType: ArsdkFeatureThermalSpotType

    /// Threshold for spot palette, from 0 to 1.
    let spotThreshold: Float
}
