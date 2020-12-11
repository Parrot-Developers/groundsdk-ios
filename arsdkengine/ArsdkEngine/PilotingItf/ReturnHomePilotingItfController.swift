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

/// Return home delay min/max
private let autoStartOnDisconnectDelayMin = 0
private let autoStartOnDisconnectDelayMax = 120

/// Return home piloting interface component controller base class
class ReturnHomePilotingItfController: ActivablePilotingItfController, ReturnHomePilotingItfBackend {

    private static let settingKey = "ReturnHome"

    /// The piloting interface from which this object is the delegate
    internal var returnHomePilotingItf: ReturnHomePilotingItfCore {
        return pilotingItf as! ReturnHomePilotingItfCore
    }

    /// Store device specific values, like settings ranges and supported flags
    private let deviceStore: SettingsStore?

    /// Preset store for this piloting interface
    private var presetStore: SettingsStore?

    /// if preferred target has been received.
    public var preferredTargetReceived = false

    /// All settings that can be stored
    enum SettingKey: String, StoreKey {
        case autoTriggerModeKey = "autoTriggerMode"
        case preferredTargetKey = "preferredTarget"
        case minAltitudeKey = "minAltitude"
        case endingHoveringAltitudeKey = "endingHoveringAltitude"
        case autoStartOnDisconnectDelayKey = "autoStartOnDisconnectDelay"
        case endingBehaviorKey = "wantedEndingBehavior"
    }

    enum Setting: Hashable {
        case autoTriggerMode(Bool)
        case preferredTarget(ReturnHomeTarget)
        case minAltitude(Double, Double, Double)
        case endingHoveringAltitude(Double, Double, Double)
        case autoStartOnDisconnectDelay(Int)
        case endingBehavior(ReturnHomeEndingBehavior)

        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .autoTriggerMode: return .autoTriggerModeKey
            case .preferredTarget: return .preferredTargetKey
            case .minAltitude: return .minAltitudeKey
            case .endingHoveringAltitude: return .endingHoveringAltitudeKey
            case .autoStartOnDisconnectDelay: return .autoStartOnDisconnectDelayKey
            case .endingBehavior: return .endingBehaviorKey
            }
        }
        /// All values to allow enumerating settings
        static let allCases: [Setting] = [
            .autoTriggerMode(false),
            .preferredTarget(ReturnHomeTarget.takeOffPosition),
            .minAltitude(0, 0, 0),
            .endingHoveringAltitude(0, 0, 0),
            .autoStartOnDisconnectDelay(0),
            .endingBehavior(ReturnHomeEndingBehavior.landing)
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

    /// The home reachability as indicated by the drone.
    ///
    /// When there is no planned automatic return, the rthHomeReachability is reported in the interface. But When an
    /// automatic return is planned, the `homeReachability` property in the interface indicates .warning. So we memorize
    /// this value to be able to update the interface when a planned return date (`autoTriggerDate`) is reset to nil
    var homeReachability = HomeReachability.unknown {
        didSet {
            if homeReachability != oldValue {
                updateReachabilityStatus()
            }
        }
    }

    /// If a automatic return is planned, indicates the "auto trigger delay".
    var autoTriggerDelay: TimeInterval? {
        didSet {
            if autoTriggerDelay != oldValue {
                updateReachabilityStatus()
            }
        }
    }

    /// Constructor
    ///
    /// - Parameter activationController: activation controller that owns this piloting interface controller
    init(activationController: PilotingItfActivationController) {
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            deviceStore = nil
            presetStore = nil
        } else {
            deviceStore = activationController.droneController.deviceStore.getSettingsStore(
                key: ReturnHomePilotingItfController.settingKey)
            presetStore = activationController.droneController.presetStore.getSettingsStore(
                key: ReturnHomePilotingItfController.settingKey)
        }
        super.init(activationController: activationController)
        pilotingItf = ReturnHomePilotingItfCore(store: droneController.drone.pilotingItfStore, backend: self)
        if let deviceStore = deviceStore, let presetStore = presetStore, !deviceStore.new && !presetStore.new {
            loadPresets()
            pilotingItf.publish()
        }
    }

    func activate() -> Bool {
        return droneController.pilotingItfActivationController.activate(pilotingItf: self)
    }

    func cancelAutoTrigger() {
        sendCancelAutoTrigger()
    }

    /// Set a custom location to the drone.
    /// This location will be used by the drone for the rth
    ///
    /// If this method is called while the preferredTarget is not set to `customPosition`,
    /// it will do nothing
    ///
    /// - Parameters:
    ///   - latitude: latitude of the location (in degrees) to reach
    ///   - longitude: longitude of the location (in degrees) to reach
    ///   - altitude: altitude above sea level (in meters) to reach
    func setCustomLocation(latitude: Double, longitude: Double, altitude: Double) {
        sendCustomLocationCommand(latitude: latitude, longitude: longitude, altitude: altitude)
    }

    /// Send preferred return home target setting
    ///
    /// - Parameter preferredTarget: new preferred target
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(preferredTarget: ReturnHomeTarget) -> Bool {
        presetStore?.write(key: SettingKey.preferredTargetKey, value: preferredTarget).commit()
        if connected {
            sendPreferredTargetCommand(preferredTarget)
            return true
        } else {
            returnHomePilotingItf.update(preferredTarget: preferredTarget).notifyUpdated()
            return false
        }
    }

    /// Send wanted ending behavior
    ///
    /// - Parameter endingBehavior: new wanted ending behavior
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(endingBehavior: ReturnHomeEndingBehavior) -> Bool {
        presetStore?.write(key: SettingKey.endingBehaviorKey, value: endingBehavior).commit()
        if connected {
            sendWantedEndingBehaviorCommand(endingBehavior)
            return true
        } else {
            returnHomePilotingItf.update(endingBehavior: endingBehavior).notifyUpdated()
            return false
        }
    }

    /// Send return home minimum altitude command
    ///
    /// - Parameter minAltitude: new minimum altitude
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(minAltitude: Double) -> Bool {
        presetStore?.write(key: SettingKey.minAltitudeKey, value: minAltitude).commit()
        if connected {
            sendMinAltitudeCommand(minAltitude)
            return true
        } else {
            returnHomePilotingItf.update(minAltitude: (nil, minAltitude, nil)).notifyUpdated()
            return false
        }
    }

    /// Send return home ending hovering altitude command
    ///
    /// - Parameter endingHoveringAltitude: new ending hovering altitude
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(endingHoveringAltitude: Double) -> Bool {
        presetStore?.write(key: SettingKey.endingHoveringAltitudeKey, value: endingHoveringAltitude).commit()
        if connected {
            sendEndingHoveringAltitudeCommand(endingHoveringAltitude)
            return true
        } else {
            returnHomePilotingItf.update(endingHoveringAltitude: (nil, endingHoveringAltitude, nil)).notifyUpdated()
            return false
        }
    }

    /// Send return home delay after disconnection
    ///
    /// - Parameter autoStartOnDisconnectDelay: new delay in seconds
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(autoStartOnDisconnectDelay: Int) -> Bool {
        presetStore?.write(key: SettingKey.autoStartOnDisconnectDelayKey, value: autoStartOnDisconnectDelay)
            .commit()
        if connected {
            sendHomeDelayCommand(autoStartOnDisconnectDelay)
            return true
        } else {
            returnHomePilotingItf.update(autoStartOnDisconnectDelay:
                (autoStartOnDisconnectDelayMin, autoStartOnDisconnectDelay, autoStartOnDisconnectDelayMax))
                .notifyUpdated()
            return false
        }
    }

    /// Set auto trigger mode.
    ///
    /// - Parameter autoTriggerMode: the new mode indicating if the drone will auto trigger rth
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(autoTriggerMode: Bool) -> Bool {
        presetStore?.write(key: SettingKey.autoTriggerModeKey, value: autoTriggerMode).commit()
        if connected {
            sendAutoTriggerModeCommand(active: autoTriggerMode)
            return true
        } else {
            returnHomePilotingItf.update(autoTriggerMode: autoTriggerMode).notifyUpdated()
            return false
        }
    }

    /// Cancels any current auto trigger.
    func sendCancelAutoTrigger() { }

    /// Send the custom location
    ///
    /// - Parameters:
    ///   - latitude: latitude of the location (in degrees) to reach
    ///   - longitude: longitude of the location (in degrees) to reach
    ///   - altitude: altitude above sea level (in meters) to reach
    func sendCustomLocationCommand(latitude: Double, longitude: Double, altitude: Double) { }

    /// Send preferred target command
    ///
    /// - Parameter preferredTarget: new preferred target
    func sendPreferredTargetCommand(_ preferredTarget: ReturnHomeTarget) { }

    /// Send the command to activate/deactivate auto trigger return home
    ///
    /// - Parameter active: true to activate auto trigger return home, false to deactivate it
    func sendAutoTriggerModeCommand(active: Bool) { }

    /// Send wanted ending behavior command
    ///
    /// - Parameter wantedBehavior: new wanted behavior
    func sendWantedEndingBehaviorCommand(_ wantedBehavior: ReturnHomeEndingBehavior) { }

    /// Send the min altitude command
    ///
    /// - Parameter minAltitude: new min altitude
    func sendMinAltitudeCommand(_ minAltitude: Double) { }

    /// Send the ending hovering altitude command
    ///
    /// - Parameter endingHoveringAltitude: new ending hovering altitude
    func sendEndingHoveringAltitudeCommand(_ endingHoveringAltitude: Double) { }

    /// Send return home delay command
    ///
    /// - Parameter delay: new return home delay
    func sendHomeDelayCommand(_ delay: Int) { }

    /// Send the command to activate/deactivate return home
    ///
    /// - Parameter active: true to activate return home, false to deactivate it
    func sendReturnHomeCommand(active: Bool) { }

    override func requestActivation() {
        sendReturnHomeCommand(active: true)
    }

    override func requestDeactivation() {
        sendReturnHomeCommand(active: false)
    }

    /// Drone is about to be forgotten
    override func willForget() {
        deviceStore?.clear()
        super.willForget()
    }

    /// Drone is about to be connect
    override func willConnect() {
        super.willConnect()
        preferredTargetReceived = false
        // remove settings stored while connecting. We will get new one on the next connection.
        droneSettings.removeAll()
    }

    /// Drone is connected
    override func didConnect() {
        // We do not received Preferred home type when the drone first boot. So we need to apply
        // user setting.
        if !preferredTargetReceived {
            droneSettings.insert(.preferredTarget(.none))
        }
        storeNewPresets()
        applyPresets()
        super.didConnect()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        homeReachability = .unknown
        autoTriggerDelay = nil
        // clear all non saved settings
        returnHomePilotingItf.cancelSettingsRollback()
            .update(homeLocation: nil)
            .update(currentTarget: .takeOffPosition)
            .update(gpsFixedOnTakeOff: false)
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
            key: ReturnHomePilotingItfController.settingKey)
        loadPresets()
        if connected {
            applyPresets()
        }
    }

    /// Called when a command that notify a setting change has been received
    ///
    /// - Parameter setting: setting that changed
    func settingDidChange(_ setting: Setting) {
        droneSettings.insert(setting)
        if connected {
            switch setting {
            case let .autoTriggerMode(value):
                returnHomePilotingItf.update(autoTriggerMode: value)
                deviceStore?.writeSupportedFlag(key: setting.key)
            case let .preferredTarget(value):
                returnHomePilotingItf.update(preferredTarget: value)
                deviceStore?.writeSupportedFlag(key: setting.key)
            case let .minAltitude(min, value, max):
                returnHomePilotingItf.update(minAltitude: (min, value, max))
                deviceStore?.writeRange(key: setting.key, min: min, max: max)
            case let .endingHoveringAltitude(min, value, max):
                returnHomePilotingItf.update(endingHoveringAltitude: (min, value, max))
                deviceStore?.writeRange(key: setting.key, min: min, max: max)
            case let .autoStartOnDisconnectDelay(value):
                returnHomePilotingItf.update(autoStartOnDisconnectDelay:
                    (autoStartOnDisconnectDelayMin, value, autoStartOnDisconnectDelayMax))
                deviceStore?.writeSupportedFlag(key: setting.key)
            case let .endingBehavior(value):
                returnHomePilotingItf.update(endingBehavior: value)
                deviceStore?.writeSupportedFlag(key: setting.key)
            }
            pilotingItf.notifyUpdated()
            deviceStore?.commit()
        }
    }

    /// Load saved settings into pilotingItf
    private func loadPresets() {
        for setting in Setting.allCases {
            switch setting {
            case .autoTriggerMode:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                    deviceStore.readSupportedFlag(key: setting.key) {
                    if let value: Bool = presetStore.read(key: setting.key) {
                        returnHomePilotingItf.update(autoTriggerMode: value)
                    }
                }
            case .preferredTarget:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                    deviceStore.readSupportedFlag(key: setting.key) {
                    if let value: ReturnHomeTarget = presetStore.read(key: setting.key) {
                        returnHomePilotingItf.update(preferredTarget: value)
                    }
                }
            case .minAltitude:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                    let value: Double = presetStore.read(key: setting.key),
                    let range: (min: Double, max: Double) = deviceStore.readRange(key: setting.key) {
                    returnHomePilotingItf.update(minAltitude: (range.min, value, range.max))
                }
            case .endingHoveringAltitude:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                    let value: Double = presetStore.read(key: setting.key),
                    let range: (min: Double, max: Double) = deviceStore.readRange(key: setting.key) {
                    returnHomePilotingItf.update(endingHoveringAltitude: (range.min, value, range.max))
                }
            case .autoStartOnDisconnectDelay:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                    deviceStore.readSupportedFlag(key: setting.key) {
                    if let value: Int = presetStore.read(key: setting.key) {
                        returnHomePilotingItf.update(autoStartOnDisconnectDelay:
                            (autoStartOnDisconnectDelayMin, value, autoStartOnDisconnectDelayMax))
                    }
                }
            case .endingBehavior:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                    deviceStore.readSupportedFlag(key: setting.key) {
                    if let value: ReturnHomeEndingBehavior = presetStore.read(key: setting.key) {
                        returnHomePilotingItf.update(endingBehavior: value)
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
                case .autoTriggerMode:
                    deviceStore.writeSupportedFlag(key: setting.key)
                case .preferredTarget:
                    deviceStore.writeSupportedFlag(key: setting.key)
                case let .minAltitude(min, _, max):
                    deviceStore.writeRange(key: setting.key, min: min, max: max)
                case let .endingHoveringAltitude(min, _, max):
                    deviceStore.writeRange(key: setting.key, min: min, max: max)
                case .autoStartOnDisconnectDelay:
                    deviceStore.writeSupportedFlag(key: setting.key)
                case .endingBehavior:
                    deviceStore.writeSupportedFlag(key: setting.key)
                }
            }
            deviceStore.commit()
        }
    }

    /// Apply a preset
    ///
    /// Iterate settings received during connection
    private func applyPresets() {
        // iterate settings received during the connection
        for setting in droneSettings {
            switch setting {
            case let .autoTriggerMode(value):
                if let preset: Bool = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendAutoTriggerModeCommand(active: preset)
                    }
                    returnHomePilotingItf.update(autoTriggerMode: preset)
                } else {
                    returnHomePilotingItf.update(autoTriggerMode: value)
                }
            case let .preferredTarget(value):
                if let preset: ReturnHomeTarget = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendPreferredTargetCommand(preset)
                    }
                    returnHomePilotingItf.update(preferredTarget: preset)
                } else {
                    returnHomePilotingItf.update(preferredTarget: value)
                }
            case let .minAltitude(min, value, max):
                if let preset: Double = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendMinAltitudeCommand(preset)
                    }
                    returnHomePilotingItf.update(minAltitude: (min: min, value: preset, max: max))
                } else {
                    returnHomePilotingItf.update(minAltitude: (min: min, value: value, max: max))
                }
            case let .endingHoveringAltitude(min, value, max):
                if let preset: Double = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendMinAltitudeCommand(preset)
                    }
                    returnHomePilotingItf.update(endingHoveringAltitude: (min: min, value: preset, max: max))
                } else {
                    returnHomePilotingItf.update(endingHoveringAltitude: (min: min, value: value, max: max))
                }
            case let .autoStartOnDisconnectDelay(value):
                if let preset: Int = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendHomeDelayCommand(preset)
                    }
                    returnHomePilotingItf.update(autoStartOnDisconnectDelay:
                        (autoStartOnDisconnectDelayMin, preset, autoStartOnDisconnectDelayMax))
                } else {
                    returnHomePilotingItf.update(autoStartOnDisconnectDelay:
                        (autoStartOnDisconnectDelayMin, value, autoStartOnDisconnectDelayMax))
                }
            case let .endingBehavior(value):
                if let preset: ReturnHomeEndingBehavior = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendWantedEndingBehaviorCommand(preset)
                    }
                    returnHomePilotingItf.update(endingBehavior: preset)
                } else {
                    returnHomePilotingItf.update(endingBehavior: value)
                }
            }
        }
        presetStore?.commit()
        pilotingItf.notifyUpdated()
    }

    /// Updates the homeReachability and the autoTriggerDelay.
    ///
    /// If a automatic Return is planned, this function set `.warning` as homeReachability value.
    private func updateReachabilityStatus() {
        // force .warning if there is an autoTriggerDelay
        let reachability = autoTriggerDelay != nil ? .warning : homeReachability
        returnHomePilotingItf.update(homeReachability: reachability).update(autoTriggerDelay: autoTriggerDelay)
    }
}

extension ReturnHomeTarget: StorableEnum {
    static let storableMapper = Mapper<ReturnHomeTarget, String>([
        .takeOffPosition: "takeOff",
        .controllerPosition: "controller",
        .trackedTargetPosition: "trackedTargetPosition",
        .customPosition: "customPosition",
        .none: "none"])
}

extension ReturnHomeEndingBehavior: StorableEnum {
    static let storableMapper = Mapper<ReturnHomeEndingBehavior, String>([
        .landing: "landing",
        .hovering: "hovering"])
}
