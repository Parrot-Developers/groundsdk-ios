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

/// Alarms component controller for Anafi drones
class AnafiAlarms: DeviceComponentController {

    /// Alarms component
    private var alarms: AlarmsCore!
    /// Whether the drone uses battery alarms from the battery feature
    private var batteryFeatureSupported = false

    /// Automatic landing delay, in seconds, before below which the alarm is `.critical`
    private let autoLandingCriticalDelay = 3

    /// True or false if the drone is flying
    private var isFlying = false {
        didSet {
            if isFlying != oldValue {
                // Update the noGps tooDark and tooHigh alarms
                updateHoveringDifficulties()
            }
        }
    }

    /// Keeps the drone's Alarm for Hovering status (hoveringDifficultiesNoGpsTooDark and
    /// hoveringDifficultiesNoGpsTooDark)
    private var droneHoveringAlarmLevel = (tooDark: Alarm.Level.off, tooHigh: Alarm.Level.off)

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        self.alarms = AlarmsCore(store: deviceController.device.instrumentStore,
                                 supportedAlarms: [.power, .motorCutOut, .userEmergency,
                                                   .motorError, .batteryTooHot, .batteryTooCold,
                                                   .hoveringDifficultiesNoGpsTooDark, .hoveringDifficultiesNoGpsTooHigh,
                                                   .automaticLandingBatteryIssue, .wind, .verticalCamera,
                                                   .strongVibrations])
    }

    /// Drone is connected
    override func didConnect() {
        alarms.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        alarms.unpublish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3PilotingstateUid {
            ArsdkFeatureArdrone3Pilotingstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3SettingsstateUid {
            ArsdkFeatureArdrone3Settingsstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureBatteryUid {
            ArsdkFeatureBattery.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCommonCommonstateUid {
            ArsdkFeatureCommonCommonstate.decode(command, callback: self)
        }
    }

    /// Update or reset alarms hoveringDifficultiesNoGpsTooDark and hoveringDifficultiesNoGpsTooHigh
    ///
    /// When the drone is not flying: theses alarms are always "off"
    ///
    /// When the drone is flying: the current drone alarm status is updated
    private func updateHoveringDifficulties() {
        if isFlying {
            alarms.update(level: droneHoveringAlarmLevel.tooDark, forAlarm: .hoveringDifficultiesNoGpsTooDark)
                .update(level: droneHoveringAlarmLevel.tooHigh, forAlarm: .hoveringDifficultiesNoGpsTooHigh)
                .notifyUpdated()
        } else {
            alarms.update(level: .off, forAlarm: .hoveringDifficultiesNoGpsTooDark)
                .update(level: .off, forAlarm: .hoveringDifficultiesNoGpsTooHigh)
                .notifyUpdated()
        }
    }
}

/// Anafi Piloting State decode callback implementation
extension AnafiAlarms: ArsdkFeatureArdrone3PilotingstateCallback {
    func onAlertStateChanged(state: ArsdkFeatureArdrone3PilotingstateAlertstatechangedState) {
        switch state {
        case .none:
            // remove all alarms linked to this command
            if !batteryFeatureSupported {
                alarms.update(level: .off, forAlarm: .power)
            }
            alarms.update(level: .off, forAlarm: .motorCutOut)
                .update(level: .off, forAlarm: .userEmergency)
                .notifyUpdated()
        case .cutOut:
            // remove only non-persistent alarms
            alarms.update(level: .critical, forAlarm: .motorCutOut)
                .update(level: .off, forAlarm: .userEmergency)
                .notifyUpdated()
        case .tooMuchAngle:
            // Nothing to do since we don't provide an alarm in the API for this alert
            break
        case .user:
            // remove only non-persistent alarms
            alarms.update(level: .off, forAlarm: .motorCutOut)
                .update(level: .critical, forAlarm: .userEmergency)
                .notifyUpdated()
        case .criticalBattery:
            if !batteryFeatureSupported {
                alarms.update(level: .critical, forAlarm: .power)
                    .update(level: .off, forAlarm: .motorCutOut)
                    .update(level: .off, forAlarm: .userEmergency)
                    .notifyUpdated()
            }
        case .lowBattery:
            if !batteryFeatureSupported {
                alarms.update(level: .warning, forAlarm: .power)
                    .update(level: .off, forAlarm: .motorCutOut)
                    .update(level: .off, forAlarm: .userEmergency)
                    .notifyUpdated()
            }
        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown alert state, skipping this event.")
            return
        }
    }

    func onHoveringWarning(noGpsTooDark: UInt, noGpsTooHigh: UInt) {
        let tooDarkLevel: Alarm.Level = (noGpsTooDark == 0) ? .off : .warning
        let tooHighLevel: Alarm.Level = (noGpsTooHigh == 0) ? .off : .warning
        droneHoveringAlarmLevel = (tooDark: tooDarkLevel, tooHigh: tooHighLevel)
        updateHoveringDifficulties()
    }

    func onForcedLandingAutoTrigger(reason: ArsdkFeatureArdrone3PilotingstateForcedlandingautotriggerReason,
                                    delay: UInt) {

        switch reason {
        case .none:
            alarms.update(level: .off, forAlarm: .automaticLandingBatteryIssue).update(automaticLandingDelay: 0)
        case .batteryCriticalSoon:
            alarms.update(level: delay > autoLandingCriticalDelay ? .warning : .critical,
                          forAlarm: .automaticLandingBatteryIssue)
                .update(automaticLandingDelay: Double(delay))
        case .sdkCoreUnknown:
            return
        }
        alarms.notifyUpdated()
    }

    func onFlyingStateChanged(state: ArsdkFeatureArdrone3PilotingstateFlyingstatechangedState) {
        switch state {
        case .hovering, .flying:
            isFlying = true
        default:
            isFlying = false
        }
    }

    func onWindStateChanged(state: ArsdkFeatureArdrone3PilotingstateWindstatechangedState) {
        let level: Alarm.Level
        switch state {
        case .ok:
            level = .off
        case .warning:
            level = .warning
        case .critical:
            level = .critical
        case .sdkCoreUnknown:
            return
        }
        alarms.update(level: level, forAlarm: .wind).notifyUpdated()
    }

    func onVibrationLevelChanged(state: ArsdkFeatureArdrone3PilotingstateVibrationlevelchangedState) {
        let level: Alarm.Level
        switch state {
        case .ok:
            level = .off
        case .critical:
            level = .critical
        case .warning:
           level = .warning
        case .sdkCoreUnknown:
            return
        }
        alarms.update(level: level, forAlarm: .strongVibrations).notifyUpdated()
    }
}

/// Anafi Setting State decode callback implementation
extension AnafiAlarms: ArsdkFeatureArdrone3SettingsstateCallback {
    func onMotorErrorStateChanged(motorids: UInt,
                                  motorerror: ArsdkFeatureArdrone3SettingsstateMotorerrorstatechangedMotorerror) {
        alarms.update(level: (motorerror == .noerror) ? .off : .critical, forAlarm: .motorError).notifyUpdated()
    }
}

/// Battery feature decode callback implementation
extension AnafiAlarms: ArsdkFeatureBatteryCallback {
    func onAlert(alert: ArsdkFeatureBatteryAlert, level: ArsdkFeatureBatteryAlertLevel, listFlagsBitField: UInt) {

        @discardableResult
        func removeAllBatteryAlarms() -> AlarmsCore {
            return alarms.update(level: .off, forAlarm: .power)
                .update(level: .off, forAlarm: .batteryTooHot)
                .update(level: .off, forAlarm: .batteryTooCold)
        }

        // declare that the drone supports the battery feature
        batteryFeatureSupported = true

        if ArsdkFeatureGenericListFlagsBitField.isSet(.empty, inBitField: listFlagsBitField) {
            // remove all and notify
            removeAllBatteryAlarms().notifyUpdated()
        } else {
            let alarm: Alarm.Kind?
            switch alert {
            case .powerLevel:
                alarm = .power
            case .tooHot:
                alarm = .batteryTooHot
            case .tooCold:
                alarm = .batteryTooCold
            case .sdkCoreUnknown:
                alarm = nil
            }

            if let alarm = alarm {
                if ArsdkFeatureGenericListFlagsBitField.isSet(.remove, inBitField: listFlagsBitField) {
                    // remove
                    alarms.update(level: .off, forAlarm: alarm)
                } else {
                    // first, remove all
                    if ArsdkFeatureGenericListFlagsBitField.isSet(.first, inBitField: listFlagsBitField) {
                        removeAllBatteryAlarms()
                    }

                    let alarmLevel: Alarm.Level?
                    switch level {
                    case .none:
                        alarmLevel = .off
                    case .warning:
                        alarmLevel = .warning
                    case .critical:
                        alarmLevel = .critical
                    case .sdkCoreUnknown:
                        alarmLevel = nil
                    }

                    if let alarmLevel = alarmLevel {
                        // add
                        alarms.update(level: alarmLevel, forAlarm: alarm)
                    }
                }
            }
            if ArsdkFeatureGenericListFlagsBitField.isSet(.last, inBitField: listFlagsBitField) {
                // notify
                alarms.notifyUpdated()
            }
        }
    }
}

/// Sensors state decode callback implementation
extension AnafiAlarms: ArsdkFeatureCommonCommonstateCallback {
    func onSensorsStatesListChanged(sensorname: ArsdkFeatureCommonCommonstateSensorsstateslistchangedSensorname,
                                    sensorstate: UInt) {
        let level: Alarm.Level
        switch sensorname {
        case .verticalCamera:
            level = sensorstate == 1 ? .off : .critical
            alarms.update(level: level, forAlarm: .verticalCamera).notifyUpdated()
        default:
            return
        }
    }
}
