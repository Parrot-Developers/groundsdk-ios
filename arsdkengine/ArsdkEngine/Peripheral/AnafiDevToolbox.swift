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

/// Controller for development toolbox peripheral.
class AnafiDevToolbox: DeviceComponentController, DevToolboxBackend {

    /// Development toolbox component.
    private(set) var devToolbox: DevToolboxCore!

    /// Debug settings indexed by id.
    private var settings = [UInt: DebugSettingCore]()

    /// Constructor.
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        devToolbox = DevToolboxCore(store: deviceController.device.peripheralStore, backend: self)
    }

    /// Drone is connected.
    override func didConnect() {
        // when connected, ask all debug settings
        sendCommand(ArsdkFeatureDebug.getAllSettingsEncoder())
        devToolbox.publish()
    }

    /// Drone is disconnected.
    override func didDisconnect() {
        devToolbox.unpublish()
    }

    /// A command has been received.
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureDebugUid {
            ArsdkFeatureDebug.decode(command, callback: self)
        }
    }

    func set(setting: BoolDebugSettingCore) {
        let strValue = setting.value ? "1" : "0"
        sendCommand(ArsdkFeatureDebug.setSettingEncoder(id: setting.uid, value: strValue))
    }

    func set(setting: TextDebugSettingCore) {
        sendCommand(ArsdkFeatureDebug.setSettingEncoder(id: setting.uid, value: setting.value))
    }

    func set(setting: NumericDebugSettingCore) {
        let strValue = String(format: "%f", setting.value)
        sendCommand(ArsdkFeatureDebug.setSettingEncoder(id: setting.uid, value: strValue))
    }

    func sendDebugTag(tag: String) {
        sendCommand(ArsdkFeatureDebug.tagEncoder(value: tag))
    }

    /// Creates a debug setting.
    ///
    /// - Parameters:
    ///   - id: setting unique identifier
    ///   - label: setting name
    ///   - type: setting type
    ///   - mode: whether setting can be modified
    ///   - min: setting value lower bound
    ///   - max: setting value upper bound
    ///   - step: setting value step
    ///   - value: setting value
    /// - Returns: a new debug setting or `nil`
    func createDebugSetting(id: UInt, label: String!, type: ArsdkFeatureDebugSettingType,
                            mode: ArsdkFeatureDebugSettingMode, min: String!, max: String!, step: String!,
                            value: String!) -> DebugSettingCore? {
        var debugSetting: DebugSettingCore?
        let readOnly = mode == .readOnly
        switch type {
        case .bool:
            debugSetting = devToolbox.createDebugSetting(uid: id, name: label, readOnly: readOnly, value: value == "1")
        case .text:
            debugSetting = devToolbox.createDebugSetting(uid: id, name: label, readOnly: readOnly, value: value)
        case .decimal:
            let min = Double(min)
            let max = Double(max)
            let step = Double(step)
            let value = Double(value) ?? 0.0
            var range: ClosedRange<Double>?
            if let min = min, let max = max {
                range = min...max
            }
            debugSetting = devToolbox.createDebugSetting(uid: id, name: label, readOnly: readOnly, range: range,
                                                         step: step, value: value)
        default:
            ULog.w(.tag, "Unknown debug setting type, skipping this event.")
        }
        return debugSetting
    }
}

/// Debug feature decode callback implementation.
extension AnafiDevToolbox: ArsdkFeatureDebugCallback {
    func onSettingsInfo(listFlagsBitField: UInt, id: UInt, label: String!, type: ArsdkFeatureDebugSettingType,
                        mode: ArsdkFeatureDebugSettingMode, rangeMin: String!, rangeMax: String!,
                        rangeStep: String!, value: String!) {
        if ArsdkFeatureGenericListFlagsBitField.isSet(.empty, inBitField: listFlagsBitField) {
            // remove all settings
            settings.removeAll()
            devToolbox.update(debugSettings: Array(settings.values)).notifyUpdated()
        } else {
            if ArsdkFeatureGenericListFlagsBitField.isSet(.first, inBitField: listFlagsBitField) {
                settings.removeAll()
            }

            let debugSetting = createDebugSetting(id: id, label: label, type: type, mode: mode,
                                                  min: rangeMin, max: rangeMax, step: rangeStep, value: value)
            if let debugSetting = debugSetting {
                settings[id] = debugSetting
            }

            if ArsdkFeatureGenericListFlagsBitField.isSet(.last, inBitField: listFlagsBitField) {
                devToolbox.update(debugSettings: Array(settings.values)).notifyUpdated()
                devToolbox.publish()
            }
        }
    }

    func onSettingsList(id: UInt, value: String!) {
        let debugSetting = settings[id]
        switch debugSetting {
        case let debugSetting as BoolDebugSettingCore:
            devToolbox.update(debugSetting: debugSetting, value: value == "1").notifyUpdated()
        case let debugSetting as TextDebugSettingCore:
            devToolbox.update(debugSetting: debugSetting, value: value).notifyUpdated()
        case let debugSetting as NumericDebugSettingCore:
            let doubleValue = Double(value)
            if let doubleValue = doubleValue {
                devToolbox.update(debugSetting: debugSetting, value: doubleValue).notifyUpdated()
            }
        default:
            ULog.w(.tag, "Unknown debug setting id \(id), skipping this event.")
        }
    }

    func onTagNotify(id: String!) {
        ULog.d(.tag, "Debug tag notified by drone \(String(describing: id))")
        devToolbox.update(debugTagId: id).notifyUpdated()
    }
}
