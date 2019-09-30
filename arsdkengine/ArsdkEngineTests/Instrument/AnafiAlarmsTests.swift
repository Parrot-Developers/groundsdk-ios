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
import XCTest
@testable import ArsdkEngine
@testable import GroundSdk
import SdkCoreTesting

class AnafiAlarmsTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var alarms: Alarms?
    var alarmsRef: Ref<Alarms>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        alarmsRef = drone.getInstrument(Instruments.alarms) {  [unowned self] alarms in
            self.alarms = alarms
            self.changeCnt += 1
        }
        changeCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(alarms, `is`(nilValue()))

        connect(drone: drone, handle: 1)
        assertThat(alarms, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(alarms, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testValue() {
        connect(drone: drone, handle: 1) {
            // flying (in order to test noGsp tooDark and noGps to high alarms))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        }
        // check default values
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(1))

        // Mock low battery from ARDrone3 reception
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateAlertstatechangedEncoder(state: .lowBattery))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(2))

        // Critical battery
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateAlertstatechangedEncoder(state: .criticalBattery))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(3))

        // UserEmergency
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateAlertstatechangedEncoder(state: .user))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(4))

        // Cut out
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateAlertstatechangedEncoder(state: .cutOut))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(5))

        // Motor error
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(
                motorids: 1, motorerror: .errorbatteryvoltage))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(6))

        // Alert none
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateAlertstatechangedEncoder(state: .none))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(7))

        // Cut out
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateAlertstatechangedEncoder(state: .cutOut))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(8))

        // Warning battery low (as first element of the map, should not trigger any update)
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.batteryAlertEncoder(
                alert: .powerLevel, level: .warning,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))
        assertThat(changeCnt, `is`(8))

        // Critical battery too cold
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.batteryAlertEncoder(
                alert: .tooCold, level: .critical,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(9))

        // Remove battery too cold
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.batteryAlertEncoder(
                alert: .tooCold, level: .critical,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.remove, .last)))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(10))

        // Add as first and last battery too hot
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.batteryAlertEncoder(
                alert: .tooHot, level: .warning,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last)))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(11))

        // Add as last battery level
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.batteryAlertEncoder(
                alert: .powerLevel, level: .critical,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(12))

        // Alert none
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateAlertstatechangedEncoder(state: .none))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(13))

        // Motor error gone
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.ardrone3SettingsstateMotorerrorstatechangedEncoder(motorids: 1, motorerror: .noerror))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(14))

        // Too much angle should not add any alarms
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateAlertstatechangedEncoder(state: .tooMuchAngle))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(14))

        // Remove battery level alarm
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.batteryAlertEncoder(
                alert: .powerLevel, level: .none,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(15))

        // Receiving low battery from ARDrone3 reception after having received a battery alarm (from battery feature)
        // should not trigger any change
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateAlertstatechangedEncoder(state: .lowBattery))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(15))

        // Receiving critical battery from ARDrone3 reception after having received a battery alarm
        // (from battery feature) should not trigger any change
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateAlertstatechangedEncoder(state: .criticalBattery))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(15))

        // receiving hovering warning event
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateHoveringwarningEncoder(noGpsTooDark: 1, noGpsTooHigh: 1))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(16))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateHoveringwarningEncoder(noGpsTooDark: 1, noGpsTooHigh: 0))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(17))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateHoveringwarningEncoder(noGpsTooDark: 0, noGpsTooHigh: 0))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(18))

        // receiving autolanding in 25s because of battery low
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.ardrone3PilotingstateForcedlandingautotriggerEncoder(
            reason: .batteryCriticalSoon, delay: 25))

        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(19))

        // receiving autolanding in less or equal than 3s because of battery low
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.ardrone3PilotingstateForcedlandingautotriggerEncoder(
            reason: .batteryCriticalSoon, delay: 3))

        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(20))

        // receiving autolanding deactivated (i.e. reason is none)
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.ardrone3PilotingstateForcedlandingautotriggerEncoder(
            reason: .none, delay: 3))

        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(21))

        // receiving wind warning event
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.ardrone3PilotingstateWindstatechangedEncoder(
            state: .critical))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(22))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.ardrone3PilotingstateWindstatechangedEncoder(
            state: .warning))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(23))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.ardrone3PilotingstateWindstatechangedEncoder(
            state: .ok))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(24))

        // receiving state from vertical camera sensor
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.commonCommonstateSensorsstateslistchangedEncoder(
            sensorname: .verticalCamera, sensorstate: 0))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.critical))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(25))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.commonCommonstateSensorsstateslistchangedEncoder(
            sensorname: .verticalCamera, sensorstate: 1))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(26))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.ardrone3PilotingstateVibrationlevelchangedEncoder(
            state: .warning))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.warning))
        assertThat(changeCnt, `is`(27))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.ardrone3PilotingstateVibrationlevelchangedEncoder(
            state: .critical))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.critical))
        assertThat(changeCnt, `is`(28))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.ardrone3PilotingstateVibrationlevelchangedEncoder(
            state: .ok))
        assertThat(alarms!.getAlarm(kind: .power).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .userEmergency).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorCutOut).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .motorError).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooCold).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .batteryTooHot).level, `is`(.warning))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .wind).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .verticalCamera).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .strongVibrations).level, `is`(.off))
        assertThat(changeCnt, `is`(29))
    }

    func testNoGpsAlarmsAndFlyingStatus() {
        connect(drone: drone, handle: 1) {
            // not flying and alarm too dark
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingstateHoveringwarningEncoder(noGpsTooDark: 1, noGpsTooHigh: 0))
        }

        // check values
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(changeCnt, `is`(1))

        // flying
        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.warning))
        assertThat(changeCnt, `is`(2))

        // Hovering
        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .hovering))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.warning))
        assertThat(changeCnt, `is`(2))

        // landing
        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landing))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(changeCnt, `is`(3))

        // flying
        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.warning))
        assertThat(changeCnt, `is`(4))

        // landed
        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(changeCnt, `is`(5))

        // Alarm Too High
        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateHoveringwarningEncoder(noGpsTooDark: 0, noGpsTooHigh: 1))
        // but no alram (the drone is landed)
        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.off))
        assertThat(alarms!.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.off))
        assertThat(changeCnt, `is`(5))
    }

    func testAutoLandingDelay() {
        connect(drone: drone, handle: 1)

        // check initial value
        assertThat(alarms!.automaticLandingDelay, `is`(0))
        assertThat(changeCnt, `is`(1))

        // receiving autolanding in 25s because of battery low
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.ardrone3PilotingstateForcedlandingautotriggerEncoder(
            reason: .batteryCriticalSoon, delay: 25))

        assertThat(alarms!.automaticLandingDelay, `is`(25))
        assertThat(changeCnt, `is`(2))

        // receiving autolanding in less or equal than 3s because of battery low
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.ardrone3PilotingstateForcedlandingautotriggerEncoder(
            reason: .batteryCriticalSoon, delay: 3))

        assertThat(alarms!.automaticLandingDelay, `is`(3))
        assertThat(changeCnt, `is`(3))

        // receiving autolanding deactivated (i.e. reason is none)
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.ardrone3PilotingstateForcedlandingautotriggerEncoder(
            reason: .none, delay: 3))

        assertThat(alarms!.automaticLandingDelay, `is`(0))
        assertThat(changeCnt, `is`(4))
    }
}
