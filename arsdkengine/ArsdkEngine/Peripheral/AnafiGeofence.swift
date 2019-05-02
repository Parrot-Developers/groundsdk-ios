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
import CoreLocation

/// Base controller for geofence peripheral
class AnafiGeofence: DeviceComponentController, GeofenceBackend {

    /// Component settings key
    private static let settingKey = "Geofence"

    /// Geofence component
    private(set) var geofence: GeofenceCore!

    /// Store device specific values
    private let deviceStore: SettingsStore?

    /// Preset store for this piloting interface
    private var presetStore: SettingsStore?

    /// All settings that can be stored
    enum SettingKey: String, StoreKey {
        case maxAltitude = "maxAltitude"
        case maxDistance = "maxDistance"
        case mode = "mode"
    }

    /// Stored settings
    enum Setting: Hashable {
        case maxAltitude(Double, Double, Double)
        case maxDistance(Double, Double, Double)
        case mode(GeofenceMode)

        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .mode: return .mode
            case .maxAltitude: return .maxAltitude
            case .maxDistance: return .maxDistance
            }
        }
        /// All values to allow enumerating settings
        static let allCases: [Setting] = [
            .maxAltitude(0, 0, 0),
            .maxDistance(0, 0, 0),
            .mode(.altitude)
        ]
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
            deviceStore = nil
            presetStore = nil
        } else {
            deviceStore = deviceController.deviceStore.getSettingsStore(key: AnafiGeofence.settingKey)
            presetStore = deviceController.presetStore.getSettingsStore(key: AnafiGeofence.settingKey)
        }

        super.init(deviceController: deviceController)
        geofence = GeofenceCore(store: deviceController.device.peripheralStore, backend: self)
        setDefaults()
        // load settings
        if let deviceStore = deviceStore, let presetStore = presetStore, !deviceStore.new && !presetStore.new {
            loadPresets()
            geofence.publish()
        }
    }

    /// Send max altitude settings
    ///
    /// - Parameter maxAltitude: new maximum altitude
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(maxAltitude value: Double) -> Bool {
        presetStore?.write(key: SettingKey.maxAltitude, value: value).commit()
        if connected {
            sendMaxAltitudeCommand(value)
            return true
        } else {
            geofence.update(maxAltitude: (nil, value, nil)).notifyUpdated()
            return false
        }
    }

    /// Send max distance settings
    ///
    /// - Parameter maxDistance: new maximum distance
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(maxDistance value: Double) -> Bool {
        presetStore?.write(key: SettingKey.maxDistance, value: value).commit()
        if connected {
            sendMaxDistanceCommand(value)
            return true
        } else {
            geofence.update(maxDistance: (nil, value, nil)).notifyUpdated()
            return false
        }
    }

    /// Send mode setting
    ///
    /// - Parameter mode: new geofencing mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(mode value: GeofenceMode) -> Bool {
        presetStore?.write(key: SettingKey.mode, value: value).commit()
        if connected {
            sendModeCommand(value)
            return true
        } else {
            geofence.update(mode: value).notifyUpdated()
            return false
        }
    }

    /// Drone is about to be forgotten
    override func willForget() {
        deviceStore?.clear()
        geofence.unpublish()
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
        geofence.publish()
        super.didConnect()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        super.didDisconnect()

        geofence.cancelSettingsRollback()

        // unpublish if offline settings are disabled
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            geofence.unpublish()
        }
        geofence.notifyUpdated()
    }

    /// Preset has been changed
    override func presetDidChange() {
        super.presetDidChange()
        // reload preset store
        presetStore = deviceController.presetStore.getSettingsStore(key: AnafiGeofence.settingKey)
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
                case .maxAltitude:
                    if let value: Double = presetStore.read(key: setting.key),
                        let range: (min: Double, max: Double) = deviceStore.readRange(key: setting.key) {
                        geofence.update(maxAltitude: (range.min, value, range.max))
                    }
                case .maxDistance:
                    if let value: Double = presetStore.read(key: setting.key),
                        let range: (min: Double, max: Double) = deviceStore.readRange(key: setting.key) {
                        geofence.update(maxDistance: (range.min, value, range.max))
                    }
                case .mode:
                    if let mode: GeofenceMode = presetStore.read(key: setting.key) {
                        geofence.update(mode: mode)
                    }
                }
            }
            geofence.notifyUpdated()
        }
    }

    /// Called when the drone is connected, save all settings received during the connection and not yet in the preset
    /// store, and all received settings ranges
    private func storeNewPresets() {
        if let presetStore = presetStore, let deviceStore = deviceStore {
            for setting in droneSettings {
                switch setting {
                case let .maxAltitude(min, value, max):
                    presetStore.writeIfNew(key: setting.key, value: value)
                    deviceStore.writeRange(key: setting.key, min: min, max: max)
                case let .maxDistance(min, value, max):
                    presetStore.writeIfNew(key: setting.key, value: value)
                    deviceStore.writeRange(key: setting.key, min: min, max: max)
                case .mode (let mode):
                    presetStore.writeIfNew(key: setting.key, value: mode)
                }
            }
            presetStore.commit()
            deviceStore.commit()
        }
    }

    /// Apply a presets
    ///
    /// Iterate settings received during connection
    private func applyPresets() {
        // iterate settings received during the connection
        for setting in droneSettings {
            switch setting {
            case let .maxAltitude(min, value, max):
                if let preset: Double = presetStore?.read(key: setting.key) {
                    if preset != value {
                        // update the drone with the preset value
                        sendMaxAltitudeCommand(preset)
                    }
                    // uses preset value
                    geofence.update(maxAltitude: (min: min, value: preset, max: max))
                } else {
                    // uses device value
                    geofence.update(maxAltitude: (min: min, value: value, max: max))
                }
            case let .maxDistance(min, value, max):
                if let preset: Double = presetStore?.read(key: setting.key) {
                    if preset != value {
                        // update the drone with the preset value
                        sendMaxDistanceCommand(preset)
                    }
                    // uses preset value
                    geofence.update(maxDistance: (min: min, value: preset, max: max))
                } else {
                    // uses device value
                    geofence.update(maxDistance: (min: min, value: value, max: max))
                }
            case let .mode(mode):
                if let preset: GeofenceMode = presetStore?.read(key: setting.key) {
                    if preset != mode {
                        // update the drone with the preset value
                        sendModeCommand(preset)
                    }
                    // uses preset value
                    geofence.update(mode: preset)
                } else {
                    // uses device value
                    geofence.update(mode: mode)
                }
            }
            geofence.notifyUpdated()
        }
    }

    /// Called when a command that notify a setting change has been received
    ///
    /// - Parameter setting: setting that changed
    func settingDidChange(_ setting: Setting) {
        droneSettings.insert(setting)
        // apply setting if connected
        if connected {
            switch setting {
            case let .maxAltitude(min, value, max):
                geofence.update(maxAltitude: (min: min, value: value, max: max))
                // store range for device
                deviceStore?.writeRange(key: setting.key, min: min, max: max)
            case let .maxDistance(min, value, max):
                geofence.update(maxDistance: (min: min, value: value, max: max))
                // store range for device
                deviceStore?.writeRange(key: setting.key, min: min, max: max)
            case let .mode(mode):
                geofence.update(mode: mode)
            }
            deviceStore?.commit()
            geofence.notifyUpdated()
        }
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        let featureId = ArsdkCommand.getFeatureId(command)
        if featureId == kArsdkFeatureArdrone3PilotingsettingsstateUid {
            // Piloting Settings
            ArsdkFeatureArdrone3Pilotingsettingsstate.decode(command, callback: self)
        } else if featureId == kArsdkFeatureArdrone3GpssettingsstateUid {
            // Piloting Settings
            ArsdkFeatureArdrone3Gpssettingsstate.decode(command, callback: self)
        }
    }
}

// MARK: - AnafiGeofence - Commands
extension AnafiGeofence {
    /// Send set max altitude command.
    ///
    /// - Parameter value: new value
    func sendMaxAltitudeCommand(_ value: Double) {
        ULog.d(.ctrlTag, "Geofence: setting max atlitude: \(value)")
        sendCommand(ArsdkFeatureArdrone3Pilotingsettings.maxAltitudeEncoder(current: Float(value)))
    }

    /// Send set max distance command.
    ///
    /// - Parameter value: new value
    func sendMaxDistanceCommand(_ value: Double) {
        ULog.d(.ctrlTag, "Geofence: setting max distance: \(value)")
        sendCommand(ArsdkFeatureArdrone3Pilotingsettings.maxDistanceEncoder(value: Float(value)))
    }

    /// Send set mode command.
    ///
    /// - Parameter mode: new mode
    func sendModeCommand(_ mode: GeofenceMode) {
        ULog.d(.ctrlTag, "Geofence: setting mode: \(mode)")
        sendCommand(ArsdkFeatureArdrone3Pilotingsettings.noFlyOverMaxDistanceEncoder(
            shouldnotflyover: mode == .cylinder ? 1 : 0))
    }
}

/// Piloting Settings callback implementation
extension AnafiGeofence: ArsdkFeatureArdrone3PilotingsettingsstateCallback {
    func onMaxAltitudeChanged(current: Float, min: Float, max: Float) {
        guard min <= max else {
            ULog.w(.tag, "Max altitude bounds are not correct, skipping this event.")
            return
        }
        settingDidChange(.maxAltitude(Double(min), Double(current), Double(max)))
    }

    func onMaxDistanceChanged(current: Float, min: Float, max: Float) {
        guard min <= max else {
            ULog.w(.tag, "Max distance bounds are not correct, skipping this event.")
            return
        }
        settingDidChange(.maxDistance(Double(min), Double(current), Double(max)))
    }

    func onNoFlyOverMaxDistanceChanged(shouldnotflyover: UInt) {
        ULog.d(.ctrlTag, "AnafiGeofence: onNoFlyOverMaxDistanceChanged: \(shouldnotflyover)")
        settingDidChange(.mode(shouldnotflyover == 1 ? .cylinder : .altitude))
    }
}

// GPS Settings callback implementation
extension AnafiGeofence: ArsdkFeatureArdrone3GpssettingsstateCallback {

    /// Special value returned by `latitude` or `longitude` when the coordinate is not known.
    private static let UnknownCoordinate: Double = 500

    func onHomeChanged(latitude: Double, longitude: Double, altitude: Double) {
        ULog.d(.ctrlTag, "ReturnHome: onHomeChanged: latitude=\(latitude) longitude=\(longitude) altitude =\(altitude)")
        if latitude != AnafiGeofence.UnknownCoordinate && longitude != AnafiGeofence.UnknownCoordinate {
            geofence.update(center: CLLocation(latitude: latitude, longitude: longitude)).notifyUpdated()
        } else {
            geofence.update(center: nil).notifyUpdated()
        }
    }
}

// Extension to make GeofenceMode storable
extension GeofenceMode: StorableEnum {
    static var storableMapper = Mapper<GeofenceMode, String>([
        .altitude: "altitude",
        .cylinder: "cylinder"])
}
