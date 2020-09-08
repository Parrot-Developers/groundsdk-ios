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

/// Test ReturnHome piloting interface
class ReturnHomePilotingItfTest: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: ReturnHomePilotingItfCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = ReturnHomePilotingItfCore(store: store, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store.get(PilotingItfs.returnHome), present())
        impl.unpublish()
        assertThat(store.get(PilotingItfs.returnHome), nilValue())
    }

    func testReason() {
        impl.publish()
        var cnt = 0
        let returnHome = store.get(PilotingItfs.returnHome)!
        _ = store.register(desc: PilotingItfs.returnHome) {
            cnt += 1
        }

        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(returnHome.reason, `is`(.none))

        // change reason
        impl.update(reason: .connectionLost).notifyUpdated()

        assertThat(cnt, `is`(1))
        assertThat(returnHome.reason, `is`(.connectionLost))

        // change with same reason, should not trigger an update
        impl.update(reason: .connectionLost).notifyUpdated()

        assertThat(cnt, `is`(1))
        assertThat(returnHome.reason, `is`(.connectionLost))

        // change with another reason
        impl.update(reason: .powerLow).notifyUpdated()

        assertThat(cnt, `is`(2))
        assertThat(returnHome.reason, `is`(.powerLow))
    }

    func testHomeLocation() {
        impl.publish()
        var cnt = 0
        let returnHome = store.get(PilotingItfs.returnHome)!
        _ = store.register(desc: PilotingItfs.returnHome) {
            cnt += 1
        }

        // test initial value
        assertThat(returnHome.homeLocation, nilValue())

        // change home location
        impl.update(homeLocation: (latitude: 22.2, longitude: 33.3, altitude: 44.4)).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(returnHome.homeLocation, presentAnd(
            `is`(latitude: 22.2, longitude: 33.3, altitude: 44.4, hAcc: -1, vAcc: -1)))

        // clear home location
        impl.update(homeLocation: nil).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(returnHome.homeLocation, nilValue())
    }

    func testCurrentTarget() {
        impl.publish()
        var cnt = 0
        let returnHome = store.get(PilotingItfs.returnHome)!
        _ = store.register(desc: PilotingItfs.returnHome) {
            cnt += 1
        }

        // test initial value
        assertThat(returnHome.currentTarget, `is`(.takeOffPosition))
        assertThat(returnHome.gpsWasFixedOnTakeOff, `is`(false))

        // change current target
        impl.update(currentTarget: .controllerPosition).notifyUpdated()
        assertThat(returnHome.currentTarget, `is`(.controllerPosition))
        assertThat(cnt, `is`(1))

        // change current target
        impl.update(currentTarget: .takeOffPosition).notifyUpdated()
        assertThat(returnHome.currentTarget, `is`(.takeOffPosition))
        assertThat(returnHome.gpsWasFixedOnTakeOff, `is`(false))
        assertThat(cnt, `is`(2))

        impl.update(gpsFixedOnTakeOff: true).notifyUpdated()
        assertThat(returnHome.gpsWasFixedOnTakeOff, `is`(true))
        assertThat(cnt, `is`(3))
    }

    func testautoTriggerMode() {
        impl.publish()
        var cnt = 0
        let returnHome = store.get(PilotingItfs.returnHome)!
        _ = store.register(desc: PilotingItfs.returnHome) {
            cnt += 1
        }

        // test initial value
        assertThat(returnHome.autoTriggerMode, nilValue())

        // enable auto trigger behavior
        impl.update(autoTriggerMode: true).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(returnHome.autoTriggerMode, present())
        assertThat(returnHome.autoTriggerMode!, `is`(true))

        // disable auto trigger behavior
        impl.update(autoTriggerMode: false).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(returnHome.autoTriggerMode, present())
        assertThat(returnHome.autoTriggerMode!, `is`(false))

        // Use same value
        impl.update(autoTriggerMode: false).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(returnHome.autoTriggerMode, present())
        assertThat(returnHome.autoTriggerMode!, `is`(false))
    }

    func testEndingBehaviorAndHoveringAltitude() {
        impl.publish()
        var cnt = 0
        let returnHome = store.get(PilotingItfs.returnHome)!
        _ = store.register(desc: PilotingItfs.returnHome) {
            cnt += 1
        }

        // test initial value
        assertThat(returnHome.endingBehavior.behavior, present())
        assertThat(returnHome.endingBehavior.behavior, `is`(.landing))

        // Force landing behavior
        impl.update(endingBehavior: .landing).notifyUpdated()
        assertThat(cnt, `is`(0))
        assertThat(returnHome.endingBehavior, present())
        assertThat(returnHome.endingBehavior.behavior, `is`(.landing))

        // Force hovering behavior
        impl.update(endingBehavior: .hovering).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(returnHome.endingBehavior, present())
        assertThat(returnHome.endingBehavior.behavior, `is`(.hovering))

        // Set hovering altitude
        impl.update(endingHoveringAltitude: (10.0, 30.0, 50.0)).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(returnHome.endingHoveringAltitude, present())
        assertThat(returnHome.endingHoveringAltitude?.value, `is`(30.0))

        // Use same value
        impl.update(endingHoveringAltitude: (10.0, 30.0, 50.0)).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(returnHome.endingHoveringAltitude, present())
        assertThat(returnHome.endingHoveringAltitude?.value, `is`(30.0))
    }

    func testPreferredTarget() {
        impl.publish()
        var cnt = 0
        let returnHome = store.get(PilotingItfs.returnHome)!
        _ = store.register(desc: PilotingItfs.returnHome) {
            cnt += 1
        }

        // test initial value
        assertThat(returnHome.preferredTarget, `is`(preferredTarget: .takeOffPosition, updating: false))

        // notify new backend values
        impl.update(preferredTarget: .controllerPosition).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(returnHome.preferredTarget, `is`(preferredTarget: .controllerPosition, updating: false))

        // change setting
        returnHome.preferredTarget.target = .takeOffPosition
        assertThat(cnt, `is`(2))
        assertThat(returnHome.preferredTarget, `is`(preferredTarget: .takeOffPosition, updating: true))
        impl.update(preferredTarget: .takeOffPosition).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(returnHome.preferredTarget, `is`(preferredTarget: .takeOffPosition, updating: false))

        // timeout should not do anything
        (returnHome.preferredTarget as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(3))
        assertThat(returnHome.preferredTarget, `is`(preferredTarget: .takeOffPosition, updating: false))

        // change setting
        returnHome.preferredTarget.target = .controllerPosition
        assertThat(cnt, `is`(4))
        assertThat(returnHome.preferredTarget, `is`(preferredTarget: .controllerPosition, updating: true))

        // mock timeout
        (returnHome.preferredTarget as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(returnHome.preferredTarget, `is`(preferredTarget: .takeOffPosition, updating: false))

        // change setting from the api
        returnHome.preferredTarget.target = .controllerPosition
        assertThat(cnt, `is`(6))
        assertThat(returnHome.preferredTarget, `is`(preferredTarget: .controllerPosition, updating: true))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(7))
        assertThat(returnHome.preferredTarget, `is`(preferredTarget: .controllerPosition, updating: false))

        // timeout should not be triggered since it has been canceled
        (returnHome.preferredTarget as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(7))
        assertThat(returnHome.preferredTarget, `is`(preferredTarget: .controllerPosition, updating: false))
    }

    func testWantedEndingBehavior() {
        impl.publish()
        var cnt = 0
        let returnHome = store.get(PilotingItfs.returnHome)!
        _ = store.register(desc: PilotingItfs.returnHome) {
            cnt += 1
        }

        // test initial value
        assertThat(returnHome.endingBehavior, `is`(endingBehavior: .landing, updating: false))

        // notify new backend values
        impl.update(endingBehavior: .hovering).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(returnHome.endingBehavior, `is`(endingBehavior: .hovering,
                                                                updating: false))

        // change setting
        returnHome.endingBehavior.behavior = .landing
        assertThat(cnt, `is`(2))
        assertThat(returnHome.endingBehavior, `is`(endingBehavior: .landing, updating: true))
        impl.update(endingBehavior: .landing).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(returnHome.endingBehavior, `is`(endingBehavior: .landing, updating: false))

        // timeout should not do anything
        (returnHome.endingBehavior as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(3))
        assertThat(returnHome.endingBehavior, `is`(endingBehavior: .landing, updating: false))

        // change setting
        returnHome.endingBehavior.behavior = .hovering
        assertThat(cnt, `is`(4))
        assertThat(returnHome.endingBehavior, `is`(endingBehavior: .hovering, updating: true))

        // mock timeout
        (returnHome.endingBehavior as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(4))
        assertThat(returnHome.endingBehavior, `is`(endingBehavior: .hovering,
                                                                updating: true))
    }

    func testMinimumAltitude() {
        impl.publish()
        var cnt = 0
        let returnHome = store.get(PilotingItfs.returnHome)!
        _ = store.register(desc: PilotingItfs.returnHome) {
            cnt += 1
        }

        // test initial value
        assertThat(returnHome.minAltitude, `is`(nilValue()))

        // notify new backend values
        impl.update(minAltitude: (10, 20, 50)).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(returnHome.minAltitude, presentAnd(allOf(`is`(10, 20, 50), isUpToDate())))

        // change setting
        returnHome.minAltitude?.value = 40
        assertThat(cnt, `is`(2))
        assertThat(returnHome.minAltitude, presentAnd(allOf(`is`(10, 40, 50), isUpdating())))

        impl.update(minAltitude: (10, 42, 50)).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(returnHome.minAltitude, presentAnd(allOf(`is`(10, 42, 50), isUpToDate())))

        // change setting from the api
        returnHome.minAltitude?.value = 30
        assertThat(cnt, `is`(4))
        assertThat(returnHome.minAltitude, presentAnd(allOf(`is`(10, 30, 50), isUpdating())))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(5))
        assertThat(returnHome.minAltitude, presentAnd(allOf(`is`(10, 30, 50), isUpToDate())))

        // timeout should not be triggered since it has been canceled
        (returnHome.minAltitude as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(returnHome.minAltitude, presentAnd(allOf(`is`(10, 30, 50), isUpToDate())))
    }

    func testAutoStartOnDisconnectDelay() {
        impl.publish()
        var cnt = 0
        let returnHome = store.get(PilotingItfs.returnHome)!
        _ = store.register(desc: PilotingItfs.returnHome) {
            cnt += 1
        }

        // test initial value
        assertThat(returnHome.autoStartOnDisconnectDelay, allOf(`is`(0, 0, 0), isUpToDate()))

        // notify new backend values
        impl.update(autoStartOnDisconnectDelay: (10, 60, 120)).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(returnHome.autoStartOnDisconnectDelay, allOf(`is`(10, 60, 120), isUpToDate()))

        // change setting
        returnHome.autoStartOnDisconnectDelay.value = 80
        assertThat(cnt, `is`(2))
        assertThat(returnHome.autoStartOnDisconnectDelay, allOf(`is`(10, 80, 120), isUpdating()))

        impl.update(autoStartOnDisconnectDelay: (10, 82, 120)).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(returnHome.autoStartOnDisconnectDelay, allOf(`is`(10, 82, 120), isUpToDate()))

        // change setting from the api
        returnHome.autoStartOnDisconnectDelay.value = 80
        assertThat(cnt, `is`(4))
        assertThat(returnHome.autoStartOnDisconnectDelay, allOf(`is`(10, 80, 120), isUpdating()))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(5))
        assertThat(returnHome.autoStartOnDisconnectDelay, allOf(`is`(10, 80, 120), isUpToDate()))

        // timeout should not be triggered since it has been canceled
        (returnHome.autoStartOnDisconnectDelay as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(returnHome.autoStartOnDisconnectDelay, allOf(`is`(10, 80, 120), isUpToDate()))
    }

    func testHomeReachability() {
        impl.publish()
        var cnt = 0
        let returnHome = store.get(PilotingItfs.returnHome)!
        _ = store.register(desc: PilotingItfs.returnHome) {
            cnt += 1
        }

        // test initial value
        assertThat(returnHome.homeReachability, `is`(.unknown))

        // change reachability
        impl.update(homeReachability: .critical).notifyUpdated()
        assertThat(returnHome.homeReachability, `is`(.critical))
        assertThat(cnt, `is`(1))

        // set the same value
        impl.update(homeReachability: .critical).notifyUpdated()
        assertThat(returnHome.homeReachability, `is`(.critical))
        assertThat(cnt, `is`(1))
    }

    func testWarningTriggerDate() {
        impl.publish()
        var cnt = 0
        let returnHome = store.get(PilotingItfs.returnHome)!
        _ = store.register(desc: PilotingItfs.returnHome) {
            cnt += 1
        }

        // test initial value
        assertThat(returnHome.autoTriggerDelay, `is`(0))

        // change delay
        impl.update(autoTriggerDelay: 10).notifyUpdated()
        assertThat(returnHome.autoTriggerDelay, `is`(10))
        assertThat(cnt, `is`(1))

        // set an other delay
        impl.update(autoTriggerDelay: 5).notifyUpdated()
        assertThat(returnHome.autoTriggerDelay, `is`(5))
        assertThat(cnt, `is`(2))

        // set the same value
        impl.update(autoTriggerDelay: 5).notifyUpdated()
        assertThat(returnHome.autoTriggerDelay, `is`(5))
        assertThat(cnt, `is`(2))
    }

    func testCancelAutoTrigger() {
        impl.publish()
        var cnt = 0
        let returnHome = store.get(PilotingItfs.returnHome)!
        _ = store.register(desc: PilotingItfs.returnHome) {
            cnt += 1
        }

        // when home reachability is different from .warning, backend should not be called
        returnHome.cancelAutoTrigger()
        assertThat(backend.cancelAutoTriggerCnt, `is`(0))
        assertThat(returnHome.homeReachability, `is`(.unknown))

        // change reachability
        impl.update(homeReachability: .warning).notifyUpdated()
        assertThat(returnHome.homeReachability, `is`(.warning))

        returnHome.cancelAutoTrigger()
        assertThat(backend.cancelAutoTriggerCnt, `is`(1))
    }

    func testSendCustomPosition() {
        impl.publish()
        var cnt = 0
        let returnHome = store.get(PilotingItfs.returnHome)!
        _ = store.register(desc: PilotingItfs.returnHome) {
            cnt += 1
        }

        returnHome.preferredTarget.target = .customPosition
        assertThat(cnt, `is`(1))
        assertThat(returnHome.preferredTarget, `is`(preferredTarget: .customPosition, updating: true))
        impl.update(preferredTarget: .customPosition).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(returnHome.preferredTarget, `is`(preferredTarget: .customPosition, updating: false))

        // Set same value
        impl.update(preferredTarget: .customPosition).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(returnHome.preferredTarget, `is`(preferredTarget: .customPosition, updating: false))

        returnHome.setCustomLocation(latitude: 40, longitude: 40, altitude: 20)
        assertThat(cnt, `is`(2))
        impl.update(homeLocation: (latitude: 40,
                                   longitude: 40,
                                   altitude: 20)).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(returnHome.homeLocation, presentAnd(
        `is`(latitude: 40, longitude: 40, altitude: 20, hAcc: -1, vAcc: -1)))

        // Set same value
        impl.update(homeLocation: (latitude: 40,
                                   longitude: 40,
                                   altitude: 20)).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(returnHome.homeLocation, presentAnd(
        `is`(latitude: 40, longitude: 40, altitude: 20, hAcc: -1, vAcc: -1)))
    }
}

private class Backend: ReturnHomePilotingItfBackend {
    var cancelAutoTriggerCnt = 0

    func activate() -> Bool { return false }
    func deactivate() -> Bool { return false }
    func set(preferredTarget: ReturnHomeTarget) -> Bool { return true }
    func set(autoStartOnDisconnectDelay: Int) -> Bool { return true }
    func set(minAltitude: Double) -> Bool { return true }
    func cancelAutoTrigger() {
        cancelAutoTriggerCnt += 1
    }
    func set(endingBehavior: ReturnHomeEndingBehavior) -> Bool { return true }
    func set(autoTriggerMode: Bool) -> Bool { return true }
    func set(endingHoveringAltitude: Double) -> Bool { return true }
    func setCustomLocation(latitude: Double, longitude: Double, altitude: Double) { }
}
