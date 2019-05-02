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

/// Test Drone Finder peripheral
class DroneFinderTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: DroneFinderCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = DroneFinderCore(store: store!, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.droneFinder), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.droneFinder), nilValue())
    }

    func testState() {
        impl.publish()
        var cnt = 0
        let droneFinder = store.get(Peripherals.droneFinder)!
        _ = store.register(desc: Peripherals.droneFinder) {
            cnt += 1
        }

        // test initial value
        assertThat(droneFinder.state, `is`(.idle))

        impl.update(state: .scanning).notifyUpdated()
        assertThat(droneFinder.state, `is`(.scanning))
    }

    func testDiscoveredDronesList() {
        impl.publish()
        var cnt = 0
        let droneFinder = store.get(Peripherals.droneFinder)!
        _ = store.register(desc: Peripherals.droneFinder) {
            cnt += 1
        }

        // test initial value
        assertThat(droneFinder.discoveredDrones, `is`(empty()))

        impl.update(discoveredDrones: [DiscoveredDrone(
            uid: "1", model: .anafi4k, name: "Anafi4k", known: false, rssi: -30, connectionSecurity: .none)])
            .notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(droneFinder.discoveredDrones, hasCount(1))
        assertThat(droneFinder.discoveredDrones[0], has(uid: "1"))

        droneFinder.clear()
        assertThat(cnt, `is`(2))
        assertThat(droneFinder.discoveredDrones, `is`(empty()))
    }

    func testRefresh() {
        impl.publish()
        let droneFinder = store.get(Peripherals.droneFinder)!

        droneFinder.refresh()
        assertThat(backend.discoverCnt, `is`(1))
    }

    func testConnect() {
        impl.publish()
        var cnt = 0
        let droneFinder = store.get(Peripherals.droneFinder)!
        _ = store.register(desc: Peripherals.droneFinder) {
            cnt += 1
        }

        // test initial value
        assertThat(droneFinder.discoveredDrones, `is`(empty()))
        impl.update(discoveredDrones: [DiscoveredDrone(
            uid: "1", model: .anafi4k, name: "Anafi4k", known: false, rssi: -30, connectionSecurity: .none)])
            .notifyUpdated()
        assertThat(cnt, `is`(1))

        _ = droneFinder.connect(discoveredDrone: droneFinder.discoveredDrones[0])
        assertThat(backend.connectUid, presentAnd(equalTo("1")))
        assertThat(backend.connectPassword, presentAnd(equalTo("")))
    }

    func testConnectWithPassword() {
        impl.publish()
        var cnt = 0
        let droneFinder = store.get(Peripherals.droneFinder)!
        _ = store.register(desc: Peripherals.droneFinder) {
            cnt += 1
        }

        // test initial value
        assertThat(droneFinder.discoveredDrones, `is`(empty()))
        impl.update(discoveredDrones: [DiscoveredDrone(
            uid: "2", model: .anafi4k, name: "Anafi4k", known: false, rssi: -30, connectionSecurity: .none)])
            .notifyUpdated()
        assertThat(cnt, `is`(1))

        _ =  droneFinder.connect(discoveredDrone: droneFinder.discoveredDrones[0], password: "qwerty")
        assertThat(backend.connectUid, presentAnd(equalTo("2")))
        assertThat(backend.connectPassword, presentAnd(equalTo("qwerty")))
    }
}

private class Backend: DroneFinderBackend {
    var discoverCnt = 0
    var connectUid: String?
    var connectPassword: String?

    func discoverDrones() {
        discoverCnt+=1
    }

    func connectDrone(uid: String, password: String) -> Bool {
        connectUid = uid
        connectPassword = password
        return true
    }
}
