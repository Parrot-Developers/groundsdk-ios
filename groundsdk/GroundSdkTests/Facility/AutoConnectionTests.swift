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

/// Test AutoConnection facility
class AutoConnectionTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: AutoConnectionCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = AutoConnectionCore(store: store, backend: backend)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Facilities.autoConnection), present())
        impl.unpublish()
        assertThat(store!.get(Facilities.autoConnection), nilValue())
    }

    func testStartStop() {
        impl.publish()
        var cnt = 0
        let autoConnection = store.get(Facilities.autoConnection)!
        _ = store.register(desc: Facilities.autoConnection) {
            cnt += 1
        }

        // test initial value
        assertThat(autoConnection.state, `is`(.stopped))

        // Check that setting same state from low-level does not trigger the notification
        impl.update(state: .stopped).notifyUpdated()
        assertThat(autoConnection.state, `is`(.stopped))
        assertThat(cnt, `is`(0))

        // mock state change from low-level
        impl.update(state: .started).notifyUpdated()
        assertThat(autoConnection.state, `is`(.started))
        assertThat(cnt, `is`(1))

        // calling start when started should call the backend
        var res = autoConnection.start()
        assertThat(res, `is`(true))
        assertThat(autoConnection.state, `is`(.started))
        assertThat(cnt, `is`(1))
        assertThat(backend.startCnt, `is`(1))

        // check that calling stop when started correctly calls the backend
        res = autoConnection.stop()
        assertThat(res, `is`(true))
        assertThat(autoConnection.state, `is`(.started))
        assertThat(cnt, `is`(1))
        assertThat(backend.stopCnt, `is`(1))

        // mock state change from low-level
        impl.update(state: .stopped).notifyUpdated()
        assertThat(autoConnection.state, `is`(.stopped))
        assertThat(cnt, `is`(2))

        // calling start when stopped should call the backend
        res = autoConnection.start()
        assertThat(res, `is`(true))
        assertThat(autoConnection.state, `is`(.stopped))
        assertThat(cnt, `is`(2))
        assertThat(backend.startCnt, `is`(2))
    }

    func testDrone() {
        impl.publish()
        var cnt = 0
        let autoConnection = store.get(Facilities.autoConnection)!
        _ = store.register(desc: Facilities.autoConnection) {
            cnt += 1
        }

        // test initial value
        assertThat(autoConnection.drone, nilValue())

        // mock update from low level
        impl.update(drone: MockDrone(uid: "1")).notifyUpdated()
        assertThat(autoConnection.drone, presentAnd(has(uid: "1")))
        assertThat(cnt, `is`(1))

        // mock update with same drone
        impl.update(drone: MockDrone(uid: "1")).notifyUpdated()
        assertThat(autoConnection.drone, presentAnd(has(uid: "1")))
        assertThat(cnt, `is`(1))

        // mock update with a different drone
        impl.update(drone: MockDrone(uid: "2")).notifyUpdated()
        assertThat(autoConnection.drone, presentAnd(has(uid: "2")))
        assertThat(cnt, `is`(2))

        // mock state change
        impl.notifyDroneStateChanged()
        assertThat(autoConnection.drone, presentAnd(has(uid: "2")))
        assertThat(cnt, `is`(3))

        // mock update with no drone
        impl.update(drone: nil).notifyUpdated()
        assertThat(autoConnection.drone, nilValue())
        assertThat(cnt, `is`(4))

        // mock update with no drone again
        impl.update(drone: nil).notifyUpdated()
        assertThat(autoConnection.drone, nilValue())
        assertThat(cnt, `is`(4))

        // mock state change when no drone (should not change anything)
        impl.notifyDroneStateChanged()
        assertThat(autoConnection.drone, nilValue())
        assertThat(cnt, `is`(4))
    }

    func testRemoteControl() {
        impl.publish()
        var cnt = 0
        let autoConnection = store.get(Facilities.autoConnection)!
        _ = store.register(desc: Facilities.autoConnection) {
            cnt += 1
        }

        // test initial value
        assertThat(autoConnection.remoteControl, nilValue())

        // mock update from low level
        impl.update(remoteControl: MockRemoteControl(uid: "1")).notifyUpdated()
        assertThat(autoConnection.remoteControl, presentAnd(has(uid: "1")))
        assertThat(cnt, `is`(1))

        // mock update with same remoteControl
        impl.update(remoteControl: MockRemoteControl(uid: "1")).notifyUpdated()
        assertThat(autoConnection.remoteControl, presentAnd(has(uid: "1")))
        assertThat(cnt, `is`(1))

        // mock update with a different remoteControl
        impl.update(remoteControl: MockRemoteControl(uid: "2")).notifyUpdated()
        assertThat(autoConnection.remoteControl, presentAnd(has(uid: "2")))
        assertThat(cnt, `is`(2))

        // mock state change
        impl.notifyRemoteControlStateChanged()
        assertThat(autoConnection.remoteControl, presentAnd(has(uid: "2")))
        assertThat(cnt, `is`(3))

        // mock update with no remoteControl
        impl.update(remoteControl: nil).notifyUpdated()
        assertThat(autoConnection.remoteControl, nilValue())
        assertThat(cnt, `is`(4))

        // mock update with no remoteControl again
        impl.update(remoteControl: nil).notifyUpdated()
        assertThat(autoConnection.remoteControl, nilValue())
        assertThat(cnt, `is`(4))

        // mock state change
        impl.notifyRemoteControlStateChanged()
        assertThat(autoConnection.remoteControl, nilValue())
        assertThat(cnt, `is`(4))
    }
}

private class Backend: AutoConnectionBackend {
    var startCnt = 0
    var stopCnt = 0

    func startAutoConnection() -> Bool {
        startCnt += 1
        return true
    }

    func stopAutoConnection() -> Bool {
        stopCnt += 1
        return true
    }
}
