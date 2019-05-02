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

/// Test remote control related API of GroundSdk
class GroundSdkRemoteControlTests: XCTestCase {

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

    /// Checks that getting an unknown remote control returns nil
    func testUnknown() {
        let rc = gsdk!.getRemoteControl(uid: "xxx")
        assertThat(rc, nilValue())
    }

    /// Checks that getting an added remote control returns the remote control which has been added
    func testgetRemoteControl() {
        mockGroundSdk!.addRemoteControl(uid: "1", model: RemoteControl.Model.skyCtrl3, name: "name")
        let rc = gsdk!.getRemoteControl(uid: "1")
        assertThat(rc, presentAnd(has(uid: "1")))
    }

    /// Checks that remote control removed callback is called when the remote control is removed
    func testgetRemoteControlWithCallback() {
        var cnt = 0

        mockGroundSdk!.addRemoteControl(uid: "1", model: RemoteControl.Model.skyCtrl3, name: "name")
        mockGroundSdk!.addRemoteControl(uid: "2", model: RemoteControl.Model.skyCtrl3, name: "name")
        var rc = gsdk!.getRemoteControl(uid: "1") { _ in
            cnt += 1
        }
        mockGroundSdk!.removeRemoteControl(uid: "2")
        // check callback has not be called
        assertThat(cnt, `is`(0))

        mockGroundSdk!.removeRemoteControl(uid: "1")
        // expect removed callback to be called
        assertThat(cnt, `is`(1))

        // check that the callback is not called when the remote control has been deinit
        mockGroundSdk!.addRemoteControl(uid: "2", model: RemoteControl.Model.skyCtrl3, name: "name")
        rc = gsdk!.getRemoteControl(uid: "2") { _ in
            cnt += 1
        }
        _ = rc
        rc = nil
        mockGroundSdk!.removeRemoteControl(uid: "2")
        // check callback has not be called
        assertThat(cnt, `is`(1))
    }

    /// Checks forgetRemoteControl
    func testForgetRemoteControl() {
        mockGroundSdk!.addRemoteControl(uid: "1", model: RemoteControl.Model.skyCtrl3, name: "name")
        assertThat(gsdk!.forgetRemoteControl(uid: "1"), `is`(true))
        assertThat(mockGroundSdk!.delegates["1"]!.forgetCnt, `is`(1))
        assertThat(gsdk!.forgetRemoteControl(uid: "2"), `is`(false))
    }

    /// Checks connectRemoteControl
    func testConnectRemoteControl() {
        mockGroundSdk!.addRemoteControl(uid: "1", model: RemoteControl.Model.skyCtrl3, name: "name")
        mockGroundSdk!.setRemoteControlConnectors(uid: "1", connectors: [LocalDeviceConnectorCore.wifi])
        assertThat(gsdk!.connectRemoteControl(uid: "1"), `is`(true))
        assertThat(mockGroundSdk!.delegates["1"]!.connectCnt, `is`(1))
        assertThat(gsdk!.connectRemoteControl(uid: "2"), `is`(false))
    }

    /// Checks disconnectRemoteControl
    func testDisconnectRemoteControl() {
        mockGroundSdk!.addRemoteControl(uid: "1", model: RemoteControl.Model.skyCtrl3, name: "name")
        assertThat(gsdk!.disconnectRemoteControl(uid: "1"), `is`(true))
        assertThat(mockGroundSdk!.delegates["1"]!.disconnectCnt, `is`(1))
        assertThat(gsdk!.disconnectRemoteControl(uid: "2"), `is`(false))
    }
}
