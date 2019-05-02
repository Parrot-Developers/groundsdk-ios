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

class SkyControllerCompassTests: ArsdkEngineTestBase {

    var remoteControl: RemoteControlCore!
    var compass: Compass?
    var compassRef: Ref<Compass>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice(
            "456", type: RemoteControl.Model.skyCtrl3.internalId, backendType: .net, name: "Rc1", handle: 1)
        remoteControl = rcStore.getDevice(uid: "456")!

        compassRef = remoteControl.getInstrument(Instruments.compass) { [unowned self] compass in
            self.compass = compass
            self.changeCnt += 1
        }
        changeCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(compass, `is`(nilValue()))

        connect(remoteControl: remoteControl, handle: 1)
        assertThat(compass, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(remoteControl: remoteControl, handle: 1)
        assertThat(compass, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testValue() {
        connect(remoteControl: remoteControl, handle: 1)
        // check default values
        assertThat(compass!.heading, `is`(0))
        assertThat(changeCnt, `is`(1))

        // check heading
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.skyctrlSkycontrollerstateAttitudechangedEncoder(
                q0: 0.707106781186548, q1: 0.0, q2: 0.0, q3: 0.707106781186547))
        assertThat(compass!.heading, closeTo(90, 0.001))
        assertThat(changeCnt, `is`(2))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.skyctrlSkycontrollerstateAttitudechangedEncoder(q0: 0.0, q1: 0.0, q2: 0.0, q3: 0.0))
        assertThat(compass!.heading, `is`(0))
        assertThat(changeCnt, `is`(3))

        // check bounds
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.skyctrlSkycontrollerstateAttitudechangedEncoder(
                q0: 0.707106781186548, q1: 0.0, q2: 0.0, q3: -0.707106781186547))
        assertThat(compass!.heading, closeTo(270, 0.001))
        assertThat(changeCnt, `is`(4))
    }
}
