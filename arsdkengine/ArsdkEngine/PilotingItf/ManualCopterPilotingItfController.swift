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

/// Base class for all Manual Copter piloting interface component controller
class ManualCopterPilotingItfController: ManualPilotingItfController, ManualCopterPilotingItfBackend {

    /// Key for manual copter piloting itf storage
    private static let settingKey = "ManualCopter"

    /// The piloting interface from which this object is the delegate
    var manualCopterPilotingItf: ManualCopterPilotingItfCore {
        return pilotingItf as! ManualCopterPilotingItfCore
    }

    /// Store device specific values, like settings ranges and supported flags
    private let deviceStore: SettingsStore?

    /// Preset store for this piloting interface
    private var presetStore: SettingsStore?

    /// All settings that can be stored
    enum SettingKey: String, StoreKey {
        case maxPitchRollKey = "maxPitchRoll"
        case maxPitchRollVelocityKey = "maxPitchRollVelocity"
        case maxVerticalSpeedKey = "maxVerticalSpeed"
        case maxYawRotationSpeedKey = "maxYawRotationSpeed"
        case bankedTurnModeKey = "bankedTurnMode"
        case motionDetectionModeKey = "motionDetection"
    }

    enum Setting: Hashable {
        case maxPitchRoll(Double, Double, Double)
        case maxPitchRollVelocity(Double, Double, Double)
        case maxVerticalSpeed(Double, Double, Double)
        case maxYawRotationSpeed(Double, Double, Double)
        case bankedTurnMode(Bool)
        case motionDetectionMode(Bool)

        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .maxPitchRoll: return .maxPitchRollKey
            case .maxPitchRollVelocity: return .maxPitchRollVelocityKey
            case .maxVerticalSpeed: return .maxVerticalSpeedKey
            case .maxYawRotationSpeed: return .maxYawRotationSpeedKey
            case .bankedTurnMode: return .bankedTurnModeKey
            case .motionDetectionMode: return .motionDetectionModeKey
            }
        }

        /// All values to allow enumerating settings
        static let allCases: [Setting] = [
            .maxPitchRoll(0, 0, 0),
            .maxPitchRollVelocity(0, 0, 0),
            .maxVerticalSpeed(0, 0, 0),
            .maxYawRotationSpeed(0, 0, 0),
            .bankedTurnMode(false),
            .motionDetectionMode(false)
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
    /// - Parameter droneController: drone controller owning this component
    override init(activationController: PilotingItfActivationController) {
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            deviceStore = nil
            presetStore = nil
        } else {
            deviceStore = activationController.droneController.deviceStore.getSettingsStore(
                key: ManualCopterPilotingItfController.settingKey)
            presetStore = activationController.droneController.presetStore.getSettingsStore(
                key: ManualCopterPilotingItfController.settingKey)
        }
        super.init(activationController: activationController)
        pilotingItf = ManualCopterPilotingItfCore(
            store: droneController.drone.pilotingItfStore, backend: self)
        if let deviceStore = deviceStore, let presetStore = presetStore, !deviceStore.new && !presetStore.new {
            self.loadPresets()
            self.pilotingItf.publish()
        }
    }

    func set(pitch: Int) {
        setPitch(pitch)
    }

    func set(roll: Int) {
        setRoll(roll)
    }

    func set(yawRotationSpeed: Int) {
        setYaw(yawRotationSpeed)
    }

    func set(verticalSpeed: Int) {
        setGaz(verticalSpeed)
    }

    func hover() {
        setRoll(0)
        setPitch(0)
    }
    /// Send takeoff request
    final func takeOff() {
        if connected {
            sendTakeOffCommand()
        }
    }

    /// Send land request
    final func land() {
        if connected {
            sendLandCommand()
        }
    }

    /// Send take off request
    final func thrownTakeOff() {
        if connected {
            sendThrownTakeOffCommand()
        }
    }

    /// Send emergency request
    final func emergencyCutOut() {
        if connected {
            sendEmergencyCutOutCommand()
        }
    }

    /// Send max pitch/roll settings
    ///
    /// - Parameter maxPitchRoll: new maximum pitch/roll
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    final func set(maxPitchRoll value: Double) -> Bool {
        presetStore?.write(key: SettingKey.maxPitchRollKey, value: value).commit()
        if connected {
            sendMaxPitchRollCommand(value)
            return true
        } else {
            manualCopterPilotingItf.update(maxPitchRoll: (nil, value, nil)).notifyUpdated()
            return false
       }
    }

    /// Send max pitch/roll velocity settings
    ///
    /// - Parameter maxPitchRollVelocity: new maximum pitch/roll velocity
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    final func set(maxPitchRollVelocity value: Double) -> Bool {
        presetStore?.write(key: SettingKey.maxPitchRollVelocityKey, value: value).commit()
        if connected {
            sendMaxPitchRollVelocityCommand(value)
            return true
        } else {
            manualCopterPilotingItf.update(maxPitchRollVelocity: (nil, value, nil)).notifyUpdated()
            return false
        }
    }

    /// Send max vertical speed settings
    ///
    /// - Parameter maxVerticalSpeed: new maximum vertical speed
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    final func set(maxVerticalSpeed value: Double) -> Bool {
        presetStore?.write(key: SettingKey.maxVerticalSpeedKey, value: value).commit()
        if connected {
            sendMaxVerticalSpeedCommand(value)
            return true
        } else {
            manualCopterPilotingItf.update(maxVerticalSpeed: (nil, value, nil)).notifyUpdated()
            return false
        }
    }

    /// Send max yaw rotation speed settings
    ///
    /// - Parameter maxYawRotationSpeed: new maximum yaw rotation speed
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    final func set(maxYawRotationSpeed value: Double) -> Bool {
        presetStore?.write(key: SettingKey.maxYawRotationSpeedKey, value: value).commit()
        if connected {
            sendMaxYawRotationSpeedCommand(value)
            return true
        } else {
            manualCopterPilotingItf.update(maxYawRotationSpeed: (nil, value, nil)).notifyUpdated()
            return false
        }
    }

    /// Send banked-turn mode settings
    ///
    /// - Parameter bankedTurnMode: new banked turn mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    final func set(bankedTurnMode value: Bool) -> Bool {
        presetStore?.write(key: SettingKey.bankedTurnModeKey, value: value).commit()
        if connected {
            sendBankedTurnModeCommand(value)
            return true
        } else {
            manualCopterPilotingItf.update(bankedTurnMode: value).notifyUpdated()
            return false
        }
    }

    /// Send motion detection mode settings
    ///
    /// - Parameter useThrownTakeOffForSmartTakeOff: will set the corresponding motionDetection mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    final func set(useThrownTakeOffForSmartTakeOff value: Bool) -> Bool {
        presetStore?.write(key: SettingKey.motionDetectionModeKey, value: value).commit()
        if connected {
            sendMotionDetectionModeCommand(value)
            return true
        } else {
            manualCopterPilotingItf.update(useThrownTakeOffForSmartTakeOff: value).notifyUpdated()
            return false
        }
    }

    /// Send takeoff command. Subclass must override this function to send the drone specific command
    func sendTakeOffCommand() { }
    /// Send thrownTakeoff command. Subclass must override this function to send the drone specific command
    func sendThrownTakeOffCommand() { }
    /// Send land command. Subclass must override this function to send the drone specific command
    func sendLandCommand() { }
    /// Send emergency cut-out command. Subclass must override this function to send the drone specific command
    func sendEmergencyCutOutCommand() { }
    /// Send set max pitch/roll command. Subclass must override this function to send the drone specific command
    ///
    /// - Parameter value: new value
    func sendMaxPitchRollCommand(_ value: Double) { }
    /// Send set max pitch/roll velocity command. Subclass must override this function to send the drone specific
    /// command
    ///
    /// - Parameter value: new value
    func sendMaxPitchRollVelocityCommand(_ value: Double) { }
    /// Send set max vertical speed command. Subclass must override this function to send the drone specific command
    ///
    /// - Parameter value: new value
    func sendMaxVerticalSpeedCommand(_ value: Double) { }
    /// Send set max yaw rotation speed command. Subclass must override this function to send the drone specific command
    ///
    /// - Parameter value: new value
    func sendMaxYawRotationSpeedCommand(_ value: Double) { }
    /// Send set banked turn mode command. Subclass must override this function to send the drone specific command
    ///
    /// - Parameter value: new value
    func sendBankedTurnModeCommand(_ value: Bool) { }
    /// Send set motion detection mode command. Subclass must override this function to send the drone specific command
    ///
    /// - Parameter value: new value
    func sendMotionDetectionModeCommand(_ value: Bool) { }

    /// Drone is about to be forgotten
    override func willForget() {
        deviceStore?.clear()
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
        super.didConnect()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        // clear all non saved settings
        manualCopterPilotingItf.cancelSettingsRollback().update(canLand: false).update(canTakeOff: false)
            .update(smartWillThrownTakeoff: false)
        // unpublish if offline settings are disabled
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            pilotingItf.unpublish()
        }

        // super will call notifyUpdated
        super.didDisconnect()
    }

    /// Preset has been changed
    override func presetDidChange() {
        super.presetDidChange()
        // reload preset store
        presetStore = activationController.droneController.presetStore.getSettingsStore(
            key: ManualCopterPilotingItfController.settingKey)
        loadPresets()
        if connected {
            applyPresets()
        }
    }

    /// Load saved settings into pilotingItf
    private func loadPresets() {
        for setting in Setting.allCases {
            switch setting {
            case .maxPitchRoll:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                    let value: Double = presetStore.read(key: setting.key),
                    let range: (min: Double, max: Double) = deviceStore.readRange(key: setting.key) {
                    manualCopterPilotingItf.update(maxPitchRoll: (range.min, value, range.max))
                }
            case .maxPitchRollVelocity:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                    let value: Double = presetStore.read(key: setting.key),
                    let range: (min: Double, max: Double) = deviceStore.readRange(key: setting.key) {
                    manualCopterPilotingItf.update(maxPitchRollVelocity: (range.min, value, range.max))
                }
            case .maxVerticalSpeed:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                    let value: Double = presetStore.read(key: setting.key),
                    let range: (min: Double, max: Double) = deviceStore.readRange(key: setting.key) {
                    manualCopterPilotingItf.update(maxVerticalSpeed: (range.min, value, range.max))
                }
            case .maxYawRotationSpeed:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                    let value: Double = presetStore.read(key: setting.key),
                    let range: (min: Double, max: Double) = deviceStore.readRange(key: setting.key) {
                    manualCopterPilotingItf.update(maxYawRotationSpeed: (range.min, value, range.max))
                }
            case .bankedTurnMode:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                    deviceStore.readSupportedFlag(key: setting.key) {
                    if let value: Bool = presetStore.read(key: setting.key) {
                        manualCopterPilotingItf.update(bankedTurnMode: value)
                    }
                }
            case .motionDetectionMode:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                    deviceStore.readSupportedFlag(key: setting.key) {
                    if let value: Bool = presetStore.read(key: setting.key) {
                        manualCopterPilotingItf.update(useThrownTakeOffForSmartTakeOff: value)
                    }
                }
            }
        }
        pilotingItf.notifyUpdated()
    }

    /// Called when the drone is connected, save all settings received during the connection and  not yet in the preset
    /// store, and all received settings ranges
    private func storeNewPresets() {
        if let deviceStore = deviceStore {
            for setting in droneSettings {
                switch setting {
                case let .maxPitchRoll(min, _, max):
                    deviceStore.writeRange(key: setting.key, min: min, max: max)
                case let .maxPitchRollVelocity(min, _, max):
                    deviceStore.writeRange(key: setting.key, min: min, max: max)
                case let .maxVerticalSpeed(min, _, max):
                    deviceStore.writeRange(key: setting.key, min: min, max: max)
                case let .maxYawRotationSpeed(min, _, max):
                    deviceStore.writeRange(key: setting.key, min: min, max: max)
                case .bankedTurnMode:
                    deviceStore.writeSupportedFlag(key: setting.key)
                case .motionDetectionMode:
                    deviceStore.writeSupportedFlag(key: setting.key)
                }
            }
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
            case let .maxPitchRoll(min, value, max):
                if let preset: Double = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendMaxPitchRollCommand(preset)
                    }
                    manualCopterPilotingItf.update(maxPitchRoll: (min: min, value: preset, max: max))
                } else {
                    manualCopterPilotingItf.update(maxPitchRoll: (min: min, value: value, max: max))
                }
            case let .maxPitchRollVelocity(min, value, max):
                if let preset: Double = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendMaxPitchRollVelocityCommand(preset)
                    }
                    manualCopterPilotingItf.update(maxPitchRollVelocity: (min: min, value: preset, max: max))
                } else {
                    manualCopterPilotingItf.update(maxPitchRollVelocity: (min: min, value: value, max: max))
                }
            case let .maxVerticalSpeed(min, value, max):
                if let preset: Double = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendMaxVerticalSpeedCommand(preset)
                    }
                    manualCopterPilotingItf.update(maxVerticalSpeed: (min: min, value: preset, max: max))
                } else {
                    manualCopterPilotingItf.update(maxVerticalSpeed: (min: min, value: value, max: max))
                }
            case let .maxYawRotationSpeed(min, value, max):
                if let preset: Double = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendMaxYawRotationSpeedCommand(preset)
                    }
                    manualCopterPilotingItf.update(maxYawRotationSpeed: (min: min, value: preset, max: max))
                } else {
                    manualCopterPilotingItf.update(maxYawRotationSpeed: (min: min, value: value, max: max))
                }
            case let .bankedTurnMode(value):
                if let preset: Bool = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendBankedTurnModeCommand(preset)
                    }
                    manualCopterPilotingItf.update(bankedTurnMode: preset)
                } else {
                    manualCopterPilotingItf.update(bankedTurnMode: value)
                }
            case let .motionDetectionMode(value):
                if let preset: Bool = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendMotionDetectionModeCommand(preset)
                    }
                    manualCopterPilotingItf.update(useThrownTakeOffForSmartTakeOff: preset)
                } else {
                    manualCopterPilotingItf.update(useThrownTakeOffForSmartTakeOff: value)
                }
            }
        }
        pilotingItf.notifyUpdated()
    }

    /// Called when a command that notify a setting change has been received
    ///
    /// - Parameter setting: setting that changed
    func settingDidChange(_ setting: Setting) {
        // collect received settings
        droneSettings.insert(setting)
        // apply setting if connected
        if connected {
            switch setting {
            case let .maxPitchRoll(min, value, max):
                manualCopterPilotingItf.update(maxPitchRoll: (min: min, value: value, max: max))
                deviceStore?.writeRange(key: setting.key, min: min, max: max)
            case let .maxPitchRollVelocity(min, value, max):
                manualCopterPilotingItf.update(maxPitchRollVelocity: (min: min, value: value, max: max))
                deviceStore?.writeRange(key: setting.key, min: min, max: max)
            case let .maxVerticalSpeed(min, value, max):
                manualCopterPilotingItf.update(maxVerticalSpeed: (min: min, value: value, max: max))
                deviceStore?.writeRange(key: setting.key, min: min, max: max)
            case let .maxYawRotationSpeed(min, value, max):
                manualCopterPilotingItf.update(maxYawRotationSpeed: (min: min, value: value, max: max))
                deviceStore?.writeRange(key: setting.key, min: min, max: max)
            case let .bankedTurnMode(value):
                manualCopterPilotingItf.update(bankedTurnMode: value)
                deviceStore?.writeSupportedFlag(key: setting.key)
            case let .motionDetectionMode(value):
                manualCopterPilotingItf.update(useThrownTakeOffForSmartTakeOff: value)
                deviceStore?.writeSupportedFlag(key: setting.key)
            }
            pilotingItf.notifyUpdated()
            deviceStore?.commit()
        }
    }
}
