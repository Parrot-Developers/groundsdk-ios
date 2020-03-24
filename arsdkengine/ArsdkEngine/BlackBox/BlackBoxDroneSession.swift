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

/// Drone black box recording session.
class BlackBoxDroneSession: NSObject, BlackBoxSession {
    /// Black box data being recorded
    private(set) var blackBox: BlackBoxData

    /// Block that will be called when the session is about to be closed
    private let didClose: () -> Void

    /// Current flight data
    private var flightData = BlackBoxFlightData()
    /// Flight data write rate
    private let DELAY_5HZ = 0.2
    /// Flight data sampler
    private var flightDataSampler: Timer!

    /// Current environment data
    private var environmentData = BlackBoxEnvironmentData()
    /// Environment data write rate
    private let DELAY_1HZ = 1.0
    /// Environment data sampler
    private var environmentDataSampler: Timer!

    /// Whether or not a radio command is active
    private var radioCommandIsActive = false
    /// Drone's last known location
    private var lastLocation = BlackBoxLocationData()

    /// Constructor
    ///
    /// - Parameters:
    ///   - drone: drone to record a black box from
    ///   - didClose: block that will be called when the session is about to close
    init(drone: DroneCore, didClose: @escaping () -> Void) {
        blackBox = BlackBoxData(drone: drone)
        self.didClose = didClose

        super.init()

        flightDataSampler = Timer.scheduledTimer(
            timeInterval: DELAY_5HZ, target: self, selector: #selector(self.saveFlightDataSample), userInfo: nil,
            repeats: true)

        environmentDataSampler = Timer.scheduledTimer(
            timeInterval: DELAY_1HZ, target: self, selector: #selector(self.saveEnvironmentDataSample), userInfo: nil,
            repeats: true)
    }

    /// Sets the remote control data
    ///
    /// - Parameter remoteControlData: the remote control data to set
    func setRemoteControlData(_ remoteControlData: BlackBoxRemoteControlData) {
        blackBox.set(remoteControlData: remoteControlData)
    }

    /// Adds a remote control button event
    ///
    /// - Parameter action: button action as int
    func addRcButtonEvent(action: Int) {
        blackBox.add(event: BlackBoxEvent.rcButtonAction(action))
    }

    /// Updates current controller piloting command
    ///
    /// - Parameters:
    ///   - roll: controller piloting command roll
    ///   - pitch: controller piloting command pitch
    ///   - yaw: controller piloting command yaw
    ///   - gaz: controller piloting command gaz
    ///   - source: controller piloting command source
    func setRcPilotingCommand(roll: Int, pitch: Int, yaw: Int, gaz: Int, source: Int) {
        environmentData.rcPcmd = BlackBoxRcPilotingCommandData(
            roll: roll, pitch: pitch, yaw: yaw, gaz: gaz, source: source)
    }

    /// Called back when the current piloting command sent to the drone changes.
    ///
    /// - Parameter pilotingCommand: up-to-date piloting command
    func pilotingCommandDidChange(_ pilotingCommand: PilotingCommand) {
        flightData.pcmd = BlackBoxDronePilotingCommandData(
            roll: pilotingCommand.roll, pitch: pilotingCommand.pitch, yaw: pilotingCommand.yaw,
            gaz: pilotingCommand.gaz, flag: Int(pilotingCommand.flag))
    }

    /// Save the current flight data sample if it has changed since the last call
    @objc
    private func saveFlightDataSample() {
        if let flightData = self.flightData.useIfChanged() {
            blackBox.add(flightData: flightData)
        }
    }

    /// Save the current environment data sample if it has changed since the last call
    @objc
    private func saveEnvironmentDataSample() {
        if let environmentData = self.environmentData.useIfChanged() {
            blackBox.add(environmentData: environmentData)
        }
    }

    func onCommandReceived(_ command: OpaquePointer) {
        switch ArsdkCommand.getFeatureId(command) {
        case kArsdkFeatureArdrone3GpssettingsstateUid:
            ArsdkFeatureArdrone3Gpssettingsstate.decode(command, callback: self)
        case kArsdkFeatureWifiUid:
            ArsdkFeatureWifi.decode(command, callback: self)
        case kArsdkFeatureArdrone3PilotingstateUid:
            ArsdkFeatureArdrone3Pilotingstate.decode(command, callback: self)
        case kArsdkFeatureArdrone3SettingsstateUid:
            ArsdkFeatureArdrone3Settingsstate.decode(command, callback: self)
        case kArsdkFeatureBatteryUid:
            ArsdkFeatureBattery.decode(command, callback: self)
        case kArsdkFeatureCommonCommonstateUid:
            ArsdkFeatureCommonCommonstate.decode(command, callback: self)
        case kArsdkFeatureCommonMavlinkstateUid:
            ArsdkFeatureCommonMavlinkstate.decode(command, callback: self)
        case kArsdkFeatureCommonRunstateUid:
            ArsdkFeatureCommonRunstate.decode(command, callback: self)
        case kArsdkFeatureCommonSettingsstateUid:
            ArsdkFeatureCommonSettingsstate.decode(command, callback: self)
        case kArsdkFeatureFollowMeUid:
            ArsdkFeatureFollowMe.decode(command, callback: self)
        default:
            break
        }
    }

    func close() {
        flightDataSampler.invalidate()
        environmentDataSampler.invalidate()
        didClose()
    }
}

extension BlackBoxDroneSession: ArsdkFeatureArdrone3GpssettingsstateCallback {
    func onHomeChanged(latitude: Double, longitude: Double, altitude: Double) {
        blackBox.add(event: BlackBoxEvent.homeLocationChange(
            location: BlackBoxLocationData(latitude: latitude, longitude: longitude, altitude: altitude)))
    }

    func onGPSFixStateChanged(fixed: UInt) {
        blackBox.add(event: BlackBoxEvent.gpsFixChange(fix: Int(fixed)))
    }
}

extension BlackBoxDroneSession: ArsdkFeatureWifiCallback {
    func onApChannelChanged(type: ArsdkFeatureWifiSelectionType, band: ArsdkFeatureWifiBand, channel: UInt) {
        blackBox.add(event: BlackBoxEvent.wifiBandChange(band.rawValue))
        blackBox.add(event: BlackBoxEvent.wifiChannelChange(Int(channel)))
    }

    func onRssiChanged(rssi: Int) {
        environmentData.rssi = rssi
    }

    func onCountryChanged(selectionMode: ArsdkFeatureWifiCountrySelection, code: String!) {
        blackBox.add(event: BlackBoxEvent.countryChange(countryCode: code))
    }
}

extension BlackBoxDroneSession: ArsdkFeatureArdrone3PilotingstateCallback {
    func onAlertStateChanged(state: ArsdkFeatureArdrone3PilotingstateAlertstatechangedState) {
        blackBox.add(event: BlackBoxEvent.alertStateChange(state.rawValue))
    }

    func onHoveringWarning(noGpsTooDark: UInt, noGpsTooHigh: UInt) {
        if noGpsTooDark != 0 {
            blackBox.add(event: BlackBoxEvent.hoveringWarning(tooDark: true))
        }
        if noGpsTooHigh != 0 {
            blackBox.add(event: BlackBoxEvent.hoveringWarning(tooDark: false))
        }
    }

    func onForcedLandingAutoTrigger(reason: ArsdkFeatureArdrone3PilotingstateForcedlandingautotriggerReason,
                                    delay: UInt) {
        blackBox.add(event: BlackBoxEvent.forcedLanding(reason.rawValue))
    }

    func onWindStateChanged(state: ArsdkFeatureArdrone3PilotingstateWindstatechangedState) {
        blackBox.add(event: BlackBoxEvent.windStateChange(state.rawValue))
    }

    func onVibrationLevelChanged(state: ArsdkFeatureArdrone3PilotingstateVibrationlevelchangedState) {
        blackBox.add(event: BlackBoxEvent.vibrationLevelChange(state.rawValue))
    }

    func onFlyingStateChanged(state: ArsdkFeatureArdrone3PilotingstateFlyingstatechangedState) {
        blackBox.add(event: BlackBoxEvent.flyingStateChange(state: state.rawValue))
        if state == .takingoff {
            blackBox.add(event: BlackBoxEvent.takeOffLocation(lastLocation))
        }
    }

    func onNavigateHomeStateChanged(
        state: ArsdkFeatureArdrone3PilotingstateNavigatehomestatechangedState,
        reason: ArsdkFeatureArdrone3PilotingstateNavigatehomestatechangedReason) {
        blackBox.add(event: BlackBoxEvent.returnHomeStateChange(state.rawValue))
    }

    func onPositionChanged(latitude: Double, longitude: Double, altitude: Double) {
        lastLocation = BlackBoxLocationData(latitude: latitude, longitude: longitude, altitude: altitude)
        environmentData.droneLocation = lastLocation
    }

    func onAttitudeChanged(roll: Float, pitch: Float, yaw: Float) {
        flightData.attitude = BlackBoxAttitudeData(roll: roll, pitch: pitch, yaw: yaw)
    }

    func onSpeedChanged(speedx: Float, speedy: Float, speedz: Float) {
        flightData.speed = BlackBoxSpeedData(speedX: speedx, speedY: speedy, speedZ: speedz)
    }

    func onAltitudeChanged(altitude: Double) {
        flightData.altitude = altitude
    }

    func onAltitudeAboveGroundChanged(altitude: Float) {
        flightData.heightAboveGround = altitude
    }
}

extension BlackBoxDroneSession: ArsdkFeatureArdrone3SettingsstateCallback {
    func onProductGPSVersionChanged(software: String!, hardware: String!) {
        blackBox.set(gpsSoftwareVersion: software)
    }

    func onMotorSoftwareVersionChanged(version: String!) {
        blackBox.set(motorSoftwareVersion: version)
    }

    func onMotorErrorStateChanged(motorids: UInt,
                                  motorerror: ArsdkFeatureArdrone3SettingsstateMotorerrorstatechangedMotorerror) {
        blackBox.add(event: BlackBoxEvent.motorError(motorerror.rawValue))
    }
}

extension BlackBoxDroneSession: ArsdkFeatureBatteryCallback {
    func onAlert(alert: ArsdkFeatureBatteryAlert, level: ArsdkFeatureBatteryAlertLevel, listFlagsBitField: UInt) {
        if !ArsdkFeatureGenericListFlagsBitField.isSet(.empty, inBitField: listFlagsBitField) &&
           !ArsdkFeatureGenericListFlagsBitField.isSet(.remove, inBitField: listFlagsBitField) &&
            level != ArsdkFeatureBatteryAlertLevel.none {
            blackBox.add(event: BlackBoxEvent.batteryAlert(critical: level == ArsdkFeatureBatteryAlertLevel.critical,
                                                           type: alert.rawValue))
        }
    }

    func onVoltage(voltage: UInt) {
        environmentData.batteryVoltage = Int(voltage)
    }
}

extension BlackBoxDroneSession: ArsdkFeatureCommonCommonstateCallback {
    func onSensorsStatesListChanged(sensorname: ArsdkFeatureCommonCommonstateSensorsstateslistchangedSensorname,
                                    sensorstate: UInt) {
        if sensorstate == 0 {
            blackBox.add(event: BlackBoxEvent.sensorError(sensorname.rawValue))
        }
    }

    func onBatteryStateChanged(percent: UInt) {
        blackBox.add(event: BlackBoxEvent.batteryLevelChange(Int(percent)))
    }

    func onBootId(bootid: String!) {
        blackBox.set(bootId: bootid)
    }
}

extension BlackBoxDroneSession: ArsdkFeatureCommonMavlinkstateCallback {
    func onMavlinkFilePlayingStateChanged(
        state: ArsdkFeatureCommonMavlinkstateMavlinkfileplayingstatechangedState,
        filepath: String!, type: ArsdkFeatureCommonMavlinkstateMavlinkfileplayingstatechangedType) {
        blackBox.add(event: BlackBoxEvent.flightPlanStateChange(state: state.rawValue))
    }
}
extension BlackBoxDroneSession: ArsdkFeatureCommonRunstateCallback {
    func onRunIdChanged(runid: String!) {
        blackBox.add(event: BlackBoxEvent.runIdChange(runid))
    }
}
extension BlackBoxDroneSession: ArsdkFeatureCommonSettingsstateCallback {
    func onProductVersionChanged(software: String!, hardware: String!) {
        blackBox.setProductVersion(software: software, hardware: hardware)
    }
}
extension BlackBoxDroneSession: ArsdkFeatureFollowMeCallback {
    func onState(
        mode: ArsdkFeatureFollowMeMode, behavior: ArsdkFeatureFollowMeBehavior,
        animation: ArsdkFeatureFollowMeAnimation, animationAvailableBitField: UInt) {
        blackBox.add(event: BlackBoxEvent.followMeModeChange(mode: mode.rawValue))
    }
}
