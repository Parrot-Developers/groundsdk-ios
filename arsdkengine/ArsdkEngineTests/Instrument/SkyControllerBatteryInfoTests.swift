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

class SkyControllerBatteryInfoTests: ArsdkEngineTestBase {

    var remoteControl: RemoteControlCore!
    var batteryInfo: BatteryInfo?
    var batteryInfoRef: Ref<BatteryInfo>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("456", type: RemoteControl.Model.skyCtrl3.internalId, backendType: .mux, name: "RC1",
                                handle: 1)
        remoteControl = rcStore.getDevice(uid: "456")!

        batteryInfoRef = remoteControl.getInstrument(Instruments.batteryInfo) { [unowned self] batteryInfo in
            self.batteryInfo = batteryInfo
            self.changeCnt += 1
        }
        changeCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(batteryInfo, `is`(nilValue()))

        connect(remoteControl: remoteControl, handle: 1)
        assertThat(batteryInfo, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(remoteControl: remoteControl, handle: 1)
        assertThat(batteryInfo, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testValue() {
        connect(remoteControl: remoteControl, handle: 1)
        // check default values
        assertThat(batteryInfo!.batteryLevel, `is`(0))
        assertThat(batteryInfo!.isCharging, `is`(false))
        assertThat(changeCnt, `is`(1))

        // check battery level received
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.skyctrlSkycontrollerstateBatterychangedEncoder(percent: 60))
        assertThat(batteryInfo!.batteryLevel, `is`(60))
        assertThat(batteryInfo!.isCharging, `is`(false))
        assertThat(changeCnt, `is`(2))

        // check battery level received with the "charging value"
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.skyctrlSkycontrollerstateBatterychangedEncoder(percent: 255))
        assertThat(batteryInfo!.batteryLevel, `is`(100))
        assertThat(batteryInfo!.isCharging, `is`(true))
        assertThat(changeCnt, `is`(3))

        // check battery level received with the "charging value" again
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.skyctrlSkycontrollerstateBatterychangedEncoder(percent: 255))
        assertThat(batteryInfo!.batteryLevel, `is`(100))
        assertThat(batteryInfo!.isCharging, `is`(true))
        assertThat(changeCnt, `is`(3))

        // check battery level received (no charging)
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.skyctrlSkycontrollerstateBatterychangedEncoder(percent: 99))
        assertThat(batteryInfo!.batteryLevel, `is`(99))
        assertThat(batteryInfo!.isCharging, `is`(false))
        assertThat(changeCnt, `is`(4))
    }
}
