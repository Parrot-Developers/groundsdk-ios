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
@testable import GroundSdkMock

/// Test drone related of GroundSdk
class GroundSdkDroneTests: XCTestCase {

    var mockGroundSdk: MockGroundSdk?
    var gsdk: GroundSdk?

    override func setUp() {
        super.setUp()
        mockGroundSdk = MockGroundSdk()
        gsdk = GroundSdk()
    }

    override func tearDown() {
        gsdk = nil
        mockGroundSdk = nil
    }

    /// Checks that getting an unknown drone returns nil
    func testUnknown() {
        let d = gsdk!.getDrone(uid: "xxx")
        assertThat(d, nilValue())
    }

    /// Checks that getting an added drone returns the drone which has been added
    func testGetDrone() {
        mockGroundSdk!.addDrone(uid: "1", model: Drone.Model.anafi4k, name: "name")
        let d = gsdk!.getDrone(uid: "1")
        assertThat(d, presentAnd(has(uid: "1")))
    }

    /// Checks that drone removed callback is called when the drone is removed
    func testGetDroneWithCallback() {
        var cnt = 0

        mockGroundSdk!.addDrone(uid: "1", model: Drone.Model.anafi4k, name: "name")
        mockGroundSdk!.addDrone(uid: "2", model: Drone.Model.anafi4k, name: "name")
        var d = gsdk!.getDrone(uid: "1") { _ in
            cnt += 1
        }
        mockGroundSdk!.removeDrone(uid: "2")
        // check callback has not be called
        assertThat(cnt, `is`(0))

        mockGroundSdk!.removeDrone(uid: "1")
        // expect removed callback to be called
        assertThat(cnt, `is`(1))

        // check that the callback is not called when the drone has been deinit
        mockGroundSdk!.addDrone(uid: "2", model: Drone.Model.anafi4k, name: "name")
        d = gsdk!.getDrone(uid: "2") { _ in
            cnt += 1
        }
        _ = d
        d = nil
        mockGroundSdk!.removeDrone(uid: "2")
        // check callback has not be called
        assertThat(cnt, `is`(1))
    }

    /// Checks forgetDrone
    func testForgetDrone() {
        mockGroundSdk!.addDrone(uid: "1", model: Drone.Model.anafi4k, name: "name")
        assertThat(gsdk!.forgetDrone(uid: "1"), `is`(true))
        assertThat(mockGroundSdk!.delegates["1"]!.forgetCnt, `is`(1))
        assertThat(gsdk!.forgetDrone(uid: "2"), `is`(false))
    }

    /// Checks connectDrone
    func testConnectDrone() {
        mockGroundSdk!.addDrone(uid: "1", model: Drone.Model.anafi4k, name: "name")
        mockGroundSdk!.setDroneConnectors(uid: "1", connectors: [LocalDeviceConnectorCore.wifi])
        assertThat(gsdk!.connectDrone(uid: "1"), `is`(true))
        assertThat(mockGroundSdk!.delegates["1"]!.connectCnt, `is`(1))
        assertThat(mockGroundSdk!.delegates["1"]!.connectConnectorUid, presentAnd(
            `is`(LocalDeviceConnectorCore.wifi.uid)))

        assertThat(gsdk!.connectDrone(uid: "1", connector: RemoteControlDeviceConnectorCore(uid: "X")),
                   `is`(true))
        assertThat(mockGroundSdk!.delegates["1"]!.connectCnt, `is`(2))
        assertThat(mockGroundSdk!.delegates["1"]!.connectConnectorUid, presentAnd(`is`("X")))

        assertThat(gsdk!.connectDrone(uid: "2"), `is`(false))
    }

    /// Checks disconnectDrone
    func testDisconnectDrone() {
        mockGroundSdk!.addDrone(uid: "1", model: Drone.Model.anafi4k, name: "name")
        assertThat(gsdk!.disconnectDrone(uid: "1"), `is`(true))
        assertThat(mockGroundSdk!.delegates["1"]!.disconnectCnt, `is`(1))
        assertThat(gsdk!.disconnectDrone(uid: "2"), `is`(false))
    }
}
