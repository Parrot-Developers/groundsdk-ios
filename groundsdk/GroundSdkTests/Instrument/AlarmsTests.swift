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

import XCTest
@testable import GroundSdk

/// Test Alarms instrument
class AlarmsTests: XCTestCase {

    private var store: ComponentStoreCore!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
    }

    func testPublishUnpublish() {
        let impl = AlarmsCore(store: store, supportedAlarms: Set())
        impl.publish()
        assertThat(store.get(Instruments.alarms), present())
        impl.unpublish()
        assertThat(store.get(Instruments.alarms), nilValue())
    }

    func testAlarmKindAllValues() {
        var allKind: Set<Alarm.Kind> = Set()
        for i in 0 ... Int.max - 1 {
            let kind = Alarm.Kind(rawValue: i)
            if let kind = kind {
                allKind.insert(kind)
            } else {
                break
            }
        }

        assertThat(Alarm.Kind.allCases, `is`(allKind))
    }

    func testAlarmsKind() {
        let impl = AlarmsCore(store: store, supportedAlarms: [.power])
        // check that all alarms are the same kind with the one they are stored in
        for kind in Alarm.Kind.allCases {
            assertThat(impl.getAlarm(kind: kind).kind, `is`(kind))
        }
    }

    func testLevelChanges() {
        let impl = AlarmsCore(store: store, supportedAlarms: [.power])
        impl.publish()
        var cnt = 0
        let alarms = store.get(Instruments.alarms)!
        _ = store.register(desc: Instruments.alarms) {
            cnt += 1
        }

        // check availability set at construction
        assertThat(alarms.getAlarm(kind: .power).level, `is`(.off))
        assertThat(alarms.getAlarm(kind: .userEmergency).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .motorCutOut).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .motorError).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .batteryTooCold).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .batteryTooHot).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .wind).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .verticalCamera).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .strongVibrations).level, `is`(.notAvailable))

        // check changing a single level
        impl.update(level: .critical, forAlarm: .power).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(alarms.getAlarm(kind: .power).level, `is`(.critical))
        assertThat(alarms.getAlarm(kind: .userEmergency).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .motorCutOut).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .motorError).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .batteryTooCold).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .batteryTooHot).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .wind).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .verticalCamera).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .strongVibrations).level, `is`(.notAvailable))

        // check changing multiple levels
        impl.update(level: .warning, forAlarm: .power).update(level: .critical, forAlarm: .userEmergency)
            .update(level: .critical, forAlarm: .batteryTooHot)
            .update(level: .critical, forAlarm: .hoveringDifficultiesNoGpsTooDark)
            .update(level: .warning, forAlarm: .strongVibrations)
            .notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(alarms.getAlarm(kind: .power).level, `is`(.warning))
        assertThat(alarms.getAlarm(kind: .userEmergency).level, `is`(.critical))
        assertThat(alarms.getAlarm(kind: .motorCutOut).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .motorError).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .batteryTooCold).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .batteryTooHot).level, `is`(.critical))
        assertThat(alarms.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.critical))
        assertThat(alarms.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .wind).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .verticalCamera).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .strongVibrations).level, `is`(.warning))

        // check setting again the same level does nothing
        impl.update(level: .warning, forAlarm: .power).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(alarms.getAlarm(kind: .power).level, `is`(.warning))
        assertThat(alarms.getAlarm(kind: .userEmergency).level, `is`(.critical))
        assertThat(alarms.getAlarm(kind: .motorCutOut).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .motorError).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .batteryTooCold).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .batteryTooHot).level, `is`(.critical))
        assertThat(alarms.getAlarm(kind: .hoveringDifficultiesNoGpsTooHigh).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .hoveringDifficultiesNoGpsTooDark).level, `is`(.critical))
        assertThat(alarms.getAlarm(kind: .automaticLandingBatteryIssue).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .wind).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .verticalCamera).level, `is`(.notAvailable))
        assertThat(alarms.getAlarm(kind: .strongVibrations).level, `is`(.warning))

        // test notify without changes
        impl.notifyUpdated()
        assertThat(cnt, `is`(2))
    }

    func testAutoLandingDelay() {
        let impl = AlarmsCore(store: store, supportedAlarms: [])
        impl.publish()
        var cnt = 0
        let alarms = store.get(Instruments.alarms)!
        _ = store.register(desc: Instruments.alarms) {
            cnt += 1
        }

        // check initial state
        assertThat(alarms.automaticLandingDelay, `is`(0))
        assertThat(cnt, `is`(0))

        // mock delay changed
        impl.update(automaticLandingDelay: 25).notifyUpdated()

        assertThat(alarms.automaticLandingDelay, `is`(25))
        assertThat(cnt, `is`(1))

        // mock delay update with same value
        impl.update(automaticLandingDelay: 25).notifyUpdated()

        assertThat(alarms.automaticLandingDelay, `is`(25))
        assertThat(cnt, `is`(1))
    }
}
