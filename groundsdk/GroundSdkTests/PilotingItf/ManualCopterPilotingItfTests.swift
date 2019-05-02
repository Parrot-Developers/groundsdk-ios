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

/// Test ManualCopter piloting interface
class ManualCopterTest: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: ManualCopterPilotingItfCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = ManualCopterPilotingItfCore(store: store, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store.get(PilotingItfs.manualCopter), present())
        impl.unpublish()
        assertThat(store.get(PilotingItfs.manualCopter), nilValue())
    }

    func testCanLandCanTakeoff() {
        impl.publish()
        var cnt = 0
        let manualCopter = store.get(PilotingItfs.manualCopter)!
        _ = store.register(desc: PilotingItfs.manualCopter) {
            cnt += 1
        }

        // test initial value
        assertThat(manualCopter.canTakeOff, `is`(false))
        assertThat(manualCopter.canLand, `is`(false))

        // change canLand
        impl.update(canLand: true).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(manualCopter.canTakeOff, `is`(false))
        assertThat(manualCopter.canLand, `is`(true))

        // change canTakeoff
        impl.update(canTakeOff: true).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(manualCopter.canTakeOff, `is`(true))
        assertThat(manualCopter.canLand, `is`(true))
    }

    func testMaxPitchRoll() {
        impl.publish()
        var cnt = 0
        let manualCopter = store.get(PilotingItfs.manualCopter)!
        _ = store.register(desc: PilotingItfs.manualCopter) {
            cnt += 1
        }

        // notify new backend values
        impl.update(maxPitchRoll: (2, 10, 15)).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(manualCopter.maxPitchRoll, presentAnd(`is`(2, 10, 15)))

        // change setting
        manualCopter.maxPitchRoll.value = 12
        assertThat(cnt, `is`(2))
        assertThat(manualCopter.maxPitchRoll, presentAnd(allOf(`is`(2, 12, 15), isUpdating())))
        assertThat(backend!.maxPitchRoll!, `is`(12))

        impl.update(maxPitchRoll: (nil, 13, nil)).notifyUpdated()
        assertThat(manualCopter.maxPitchRoll, presentAnd(allOf(`is`(2, 13, 15), isUpToDate())))
        assertThat(cnt, `is`(3))

        // change setting from the api
        manualCopter.maxPitchRoll.value = 12
        assertThat(cnt, `is`(4))
        assertThat(manualCopter.maxPitchRoll, presentAnd(allOf(`is`(2, 12, 15), isUpdating())))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(5))
        assertThat(manualCopter.maxPitchRoll, presentAnd(allOf(`is`(2, 12, 15), isUpToDate())))

        // timeout should not be triggered since it has been canceled
        (impl.maxPitchRoll as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(manualCopter.maxPitchRoll, presentAnd(allOf(`is`(2, 12, 15), isUpToDate())))
    }

    func testMaxPitchRollVelocity() {
        impl.publish()
        var cnt = 0
        let manualCopter = store.get(PilotingItfs.manualCopter)!
        _ = store.register(desc: PilotingItfs.manualCopter) {
            cnt += 1
        }

        // test initial value
        assertThat(manualCopter.maxPitchRollVelocity, nilValue())

        // notify new backend values
        impl.update(maxPitchRollVelocity: (0.5, 1, 3)).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(manualCopter.maxPitchRollVelocity, presentAnd(`is`(0.5, 1, 3)))

        // change setting
        manualCopter.maxPitchRollVelocity?.value = 1.5
        assertThat(cnt, `is`(2))
        assertThat(manualCopter.maxPitchRollVelocity, presentAnd(allOf(`is`(0.5, 1.5, 3), isUpdating())))
        assertThat(backend!.maxPitchRollVelocity!, `is`(1.5))

        impl.update(maxPitchRollVelocity: (nil, 1.6, nil)).notifyUpdated()
        assertThat(manualCopter.maxPitchRollVelocity, presentAnd(allOf(`is`(0.5, 1.6, 3), isUpToDate())))
        assertThat(cnt, `is`(3))

        // change setting from the api
        manualCopter.maxPitchRollVelocity?.value = 1.5
        assertThat(cnt, `is`(4))
        assertThat(manualCopter.maxPitchRollVelocity, presentAnd(allOf(`is`(0.5, 1.5, 3), isUpdating())))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(5))
        assertThat(manualCopter.maxPitchRollVelocity, presentAnd(allOf(`is`(0.5, 1.5, 3), isUpToDate())))

        // timeout should not be triggered since it has been canceled
        (impl.maxPitchRollVelocity as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(manualCopter.maxPitchRollVelocity, presentAnd(allOf(`is`(0.5, 1.5, 3), isUpToDate())))
    }

    func testMaxVerticalSpeed() {
        impl.publish()
        var cnt = 0
        let manualCopter = store.get(PilotingItfs.manualCopter)!
        _ = store.register(desc: PilotingItfs.manualCopter) {
            cnt += 1
        }

        // notify new backend values
        impl.update(maxVerticalSpeed: (10, 10, 100)).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(manualCopter.maxVerticalSpeed, presentAnd(`is`(10, 10, 100)))

        // change setting
        manualCopter.maxVerticalSpeed.value = 50
        assertThat(cnt, `is`(2))
        assertThat(manualCopter.maxVerticalSpeed, presentAnd(allOf(`is`(10, 50, 100), isUpdating())))
        assertThat(backend!.maxVerticalSpeed!, `is`(50))

        impl.update(maxVerticalSpeed: (nil, 55, nil)).notifyUpdated()
        assertThat(manualCopter.maxVerticalSpeed, presentAnd(allOf(`is`(10, 55, 100), isUpToDate())))

        // change setting from the api
        manualCopter.maxVerticalSpeed.value = 50
        assertThat(cnt, `is`(4))
        assertThat(manualCopter.maxVerticalSpeed, presentAnd(allOf(`is`(10, 50, 100), isUpdating())))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(5))
        assertThat(manualCopter.maxVerticalSpeed, presentAnd(allOf(`is`(10, 50, 100), isUpToDate())))

        // timeout should not be triggered since it has been canceled
        (impl.maxVerticalSpeed as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(manualCopter.maxVerticalSpeed, presentAnd(allOf(`is`(10, 50, 100), isUpToDate())))
    }

    func testMaxYawSpeed() {
        impl.publish()
        var cnt = 0
        let manualCopter = store.get(PilotingItfs.manualCopter)!
        _ = store.register(desc: PilotingItfs.manualCopter) {
            cnt += 1
        }

        // notify new backend values
        impl.update(maxYawRotationSpeed: (0.1, 0.5, 1)).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(manualCopter.maxYawRotationSpeed, presentAnd(`is`(0.1, 0.5, 1)))

        // change setting
        manualCopter.maxYawRotationSpeed.value = 0.55
        assertThat(cnt, `is`(2))
        assertThat(manualCopter.maxYawRotationSpeed, presentAnd(allOf(`is`(0.1, 0.55, 1), isUpdating())))
        assertThat(backend!.maxYawRotationSpeed!, `is`(0.55))

        impl.update(maxYawRotationSpeed: (nil, 0.55, nil)).notifyUpdated()
        assertThat(manualCopter.maxYawRotationSpeed, presentAnd(allOf(`is`(0.1, 0.55, 1), isUpToDate())))
        assertThat(cnt, `is`(3))

        // change setting from the api
        manualCopter.maxYawRotationSpeed.value = 0.2
        assertThat(cnt, `is`(4))
        assertThat(manualCopter.maxYawRotationSpeed, presentAnd(allOf(`is`(0.1, 0.2, 1), isUpdating())))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(5))
        assertThat(manualCopter.maxYawRotationSpeed, presentAnd(allOf(`is`(0.1, 0.2, 1), isUpToDate())))

        // timeout should not be triggered since it has been canceled
        (impl.maxYawRotationSpeed as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(manualCopter.maxYawRotationSpeed, presentAnd(allOf(`is`(0.1, 0.2, 1), isUpToDate())))
    }

    func testThrownTakeOffSetting() {
        impl.publish()
        var cnt = 0
        let manualCopter = store.get(PilotingItfs.manualCopter)!
        _ = store.register(desc: PilotingItfs.manualCopter) {
            cnt += 1
        }

        // test initial values
        assertThat(manualCopter.thrownTakeOffSettings, `is`(nilValue()))

        // notify new backend values
        impl.update(useThrownTakeOffForSmartTakeOff: false).notifyUpdated()

        assertThat(cnt, `is`(1))
        assertThat(manualCopter.thrownTakeOffSettings, presentAnd(allOf(`is`(false), isUpToDate())))

        // change setting
        manualCopter.thrownTakeOffSettings!.value = true
        assertThat(cnt, `is`(2))
        assertThat(manualCopter.thrownTakeOffSettings, presentAnd(allOf(`is`(true), isUpdating())))

        impl.update(useThrownTakeOffForSmartTakeOff: true).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(manualCopter.thrownTakeOffSettings, presentAnd(allOf(`is`(true), isUpToDate())))

        // change setting from the api
        manualCopter.thrownTakeOffSettings!.value = false
        assertThat(cnt, `is`(4))
        assertThat(manualCopter.thrownTakeOffSettings, presentAnd(allOf(`is`(false), isUpdating())))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(5))
        assertThat(manualCopter.thrownTakeOffSettings, presentAnd(allOf(`is`(false), isUpToDate())))

        // timeout should not be triggered since it has been canceled
        (impl.thrownTakeOffSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(manualCopter.thrownTakeOffSettings, presentAnd(allOf(`is`(false), isUpToDate())))
    }

    func testBankedTurnMode() {
        impl.publish()
        var cnt = 0
        let manualCopter = store.get(PilotingItfs.manualCopter)!
        _ = store.register(desc: PilotingItfs.manualCopter) {
            cnt += 1
        }

        // test initial value
        assertThat(manualCopter.bankedTurnMode, nilValue())

        // notify new backend values
        impl.update(bankedTurnMode: true).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(manualCopter.bankedTurnMode, presentAnd(allOf(`is`(true), isUpToDate())))

        // change setting
        manualCopter.bankedTurnMode?.value = false
        assertThat(cnt, `is`(2))
        assertThat(manualCopter.bankedTurnMode, presentAnd(allOf(`is`(false), isUpdating())))
        assertThat(backend!.bankedTurnMode!, `is`(false))

        // mock reception of the event
        impl.update(bankedTurnMode: false).notifyUpdated()
        assertThat(manualCopter.bankedTurnMode, presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(cnt, `is`(3))

        // timeout should not do anything
        (manualCopter.bankedTurnMode as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(3))
        assertThat(manualCopter.bankedTurnMode, presentAnd(allOf(`is`(false), isUpToDate())))

        // change setting
        manualCopter.bankedTurnMode?.value = true
        assertThat(cnt, `is`(4))
        assertThat(manualCopter.bankedTurnMode, presentAnd(allOf(`is`(true), isUpdating())))

        // mock timeout
        (manualCopter.bankedTurnMode as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(manualCopter.bankedTurnMode, presentAnd(allOf(`is`(false), isUpToDate())))

        // change setting from the api
        manualCopter.bankedTurnMode?.value = true
        assertThat(cnt, `is`(6))
        assertThat(manualCopter.bankedTurnMode, presentAnd(allOf(`is`(true), isUpdating())))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(7))
        assertThat(manualCopter.bankedTurnMode, presentAnd(allOf(`is`(true), isUpToDate())))

        // timeout should not be triggered since it has been canceled
        (impl.thrownTakeOffSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(7))
        assertThat(manualCopter.bankedTurnMode, presentAnd(allOf(`is`(true), isUpToDate())))
    }

    func testNotifyWithoutChanges() {
        impl.publish()
        var cnt = 0
        _ = store.get(PilotingItfs.manualCopter)!
        _ = store.register(desc: PilotingItfs.manualCopter) {
            cnt += 1
        }

        // test notify without changes
        impl.notifyUpdated()
        assertThat(cnt, `is`(0))
    }

    func testSetYawPitchRollGaz () {
        impl.publish()
        let pilotingItf = store.get(PilotingItfs.manualCopter)!

        // check initial value
        assertThat(backend.roll, `is`(0))
        assertThat(backend.pitch, `is`(0))
        assertThat(backend.yawRotationSpeed, `is`(0))
        assertThat(backend.verticalSpeed, `is`(0))
        assertThat(backend.hoverCalled, `is`(false))

        pilotingItf.set(roll: 1)
        pilotingItf.set(pitch: 2)
        pilotingItf.set(yawRotationSpeed: 3)
        pilotingItf.set(verticalSpeed: 4)

        assertThat(backend.roll, `is`(1))
        assertThat(backend.pitch, `is`(2))
        assertThat(backend.yawRotationSpeed, `is`(3))
        assertThat(backend.verticalSpeed, `is`(4))
        assertThat(backend.hoverCalled, `is`(false))

        // check upper bounds
        pilotingItf.set(pitch: 101)
        pilotingItf.set(roll: 127)
        pilotingItf.set(yawRotationSpeed: 127)
        pilotingItf.set(verticalSpeed: 127)
        assertThat(backend.roll, `is`(100))
        assertThat(backend.pitch, `is`(100))
        assertThat(backend.yawRotationSpeed, `is`(100))
        assertThat(backend.verticalSpeed, `is`(100))
        assertThat(backend.hoverCalled, `is`(false))

        // check lower bounds
        pilotingItf.set(pitch: -101)
        pilotingItf.set(roll: -128)
        pilotingItf.set(yawRotationSpeed: -128)
        pilotingItf.set(verticalSpeed: -127)
        assertThat(backend.roll, `is`(-100))
        assertThat(backend.pitch, `is`(-100))
        assertThat(backend.yawRotationSpeed, `is`(-100))
        assertThat(backend.verticalSpeed, `is`(-100))
        assertThat(backend.hoverCalled, `is`(false))

        // check hover
        pilotingItf.hover()
        assertThat(backend.hoverCalled, `is`(true))
    }
}

private class Backend: ManualCopterPilotingItfBackend {
    var roll = 0
    var pitch = 0
    var yawRotationSpeed = 0
    var verticalSpeed = 0
    var hoverCalled = false
    var takOffCalled = false
    var landCalled = false
    var emergencyCalled = false
    var thrownTakeOffCalled = false
    var maxPitchRoll: Double?
    var maxPitchRollVelocity: Double?
    var maxVerticalSpeed: Double?
    var maxYawRotationSpeed: Double?
    var bankedTurnMode: Bool?
    var useThrownTakeOffForSmartTakeOff: Bool?

    func set(roll: Int) { self.roll = roll }
    func set(pitch: Int) { self.pitch = pitch }
    func set(yawRotationSpeed: Int) { self.yawRotationSpeed = yawRotationSpeed }
    func set(verticalSpeed: Int) { self.verticalSpeed = verticalSpeed }
    func hover() { self.hoverCalled = true }
    func activate() -> Bool { return false }
    func deactivate() -> Bool { return false }
    func takeOff() { takOffCalled = true }
    func land() { landCalled = true }
    func thrownTakeOff() { thrownTakeOffCalled = true }
    func emergencyCutOut() { emergencyCalled = true }
    func set(maxPitchRoll value: Double) -> Bool {
        maxPitchRoll = value
        return true
    }
    func set(maxPitchRollVelocity value: Double) -> Bool {
        maxPitchRollVelocity = value
        return true
    }
    func set(maxVerticalSpeed value: Double) -> Bool {
        maxVerticalSpeed = value
        return true
    }
    func set(maxYawRotationSpeed value: Double) -> Bool {
        maxYawRotationSpeed = value
        return true
    }
    func set(bankedTurnMode value: Bool) -> Bool {
        bankedTurnMode = value
        return true
    }
    func set(useThrownTakeOffForSmartTakeOff value: Bool) -> Bool {
        useThrownTakeOffForSmartTakeOff = value
        return true
    }
}
