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

class SkyControllerSystemInfoTests: ArsdkEngineTestBase {

    var remoteControl: RemoteControlCore!
    var systemInfo: SystemInfo?
    var systemInfoRef: Ref<SystemInfo>?
    var changeCnt = 0
    var updateChangeCnt = 0

    override func setUp() {
        super.setUp()
        setUpRc()
    }

    private func setUpRc() {
        mockArsdkCore.addDevice("123", type: RemoteControl.Model.skyCtrl3.internalId, backendType: .mux, name: "RC1",
                                handle: 1)
        remoteControl = rcStore.getDevice(uid: "123")!

        systemInfoRef = remoteControl.getPeripheral(Peripherals.systemInfo) { [unowned self] systemInfo in
            self.systemInfo = systemInfo
            self.changeCnt += 1
        }
        changeCnt = 0
    }

    override func resetArsdkEngine() {
        super.resetArsdkEngine()
        setUpRc()
    }

    func testPublishUnpublish() {
        // should be available when the drone is not connected
        assertThat(systemInfo, `is`(nilValue()))

        connect(remoteControl: remoteControl, handle: 1)
        assertThat(systemInfo, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(remoteControl: remoteControl, handle: 1)
        assertThat(systemInfo, `is`(present()))
        assertThat(changeCnt, `is`(1))
    }

     func testPublishUnpublishWithPersistentValues() {
        connect(remoteControl: remoteControl, handle: 1)
        assertThat(systemInfo, `is`(present()))
        assertThat(changeCnt, `is`(1))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.skyctrlSettingsstateProductversionchangedEncoder(
                software: "1.2.3-beta1", hardware: "HW11"))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.skyctrlSettingsstateProductserialchangedEncoder(serialnumber: "serial1"))

        assertThat(changeCnt, `is`(3))
        assertThat(systemInfo!.firmwareVersion, `is`("1.2.3-beta1"))
        assertThat(systemInfo!.hardwareVersion, `is`("HW11"))
        assertThat(systemInfo!.serial, `is`("serial1"))

        // disconnect and check values
        disconnect(remoteControl: remoteControl, handle: 1)
        assertThat(changeCnt, `is`(3))
        assertThat(systemInfo, `is`(present()))
        assertThat(systemInfo!.firmwareVersion, `is`("1.2.3-beta1"))
        assertThat(systemInfo!.hardwareVersion, `is`("HW11"))
        assertThat(systemInfo!.serial, `is`("serial1"))

        // restart engine
        resetArsdkEngine()
        assertThat(changeCnt, `is`(0))
        assertThat(systemInfo, `is`(present()))
        assertThat(systemInfo!.firmwareVersion, `is`("1.2.3-beta1"))
        assertThat(systemInfo!.hardwareVersion, `is`("HW11"))
        assertThat(systemInfo!.serial, `is`("serial1"))

        // connect and check values
        connect(remoteControl: remoteControl, handle: 1)
        assertThat(changeCnt, `is`(0))
        assertThat(systemInfo, `is`(present()))
        assertThat(systemInfo!.firmwareVersion, `is`("1.2.3-beta1"))
        assertThat(systemInfo!.hardwareVersion, `is`("HW11"))
        assertThat(systemInfo!.serial, `is`("serial1"))

        // change values and disconnect
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.skyctrlSettingsstateProductversionchangedEncoder(
                software: "4.5.6", hardware: "HW11"))
        disconnect(remoteControl: remoteControl, handle: 1)
        assertThat(changeCnt, `is`(1))
        assertThat(systemInfo, `is`(present()))
        assertThat(systemInfo!.firmwareVersion, `is`("4.5.6"))
        assertThat(systemInfo!.hardwareVersion, `is`("HW11"))
        assertThat(systemInfo!.serial, `is`("serial1"))
    }

    func testSystemInfoValues() {
        connect(remoteControl: remoteControl, handle: 1)
        // check default values
        assertThat(systemInfo!.firmwareVersion, `is`(""))
        assertThat(systemInfo!.hardwareVersion, `is`(""))
        assertThat(systemInfo!.serial, `is`(""))
        assertThat(changeCnt, `is`(1))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.skyctrlSettingsstateProductversionchangedEncoder(
                software: "1.2.3-beta1", hardware: "HW11"))
        assertThat(changeCnt, `is`(2))
        assertThat(systemInfo!.firmwareVersion, `is`("1.2.3-beta1"))
        assertThat(systemInfo!.hardwareVersion, `is`("HW11"))
        assertThat(systemInfo!.serial, `is`(""))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.skyctrlSettingsstateProductserialchangedEncoder(serialnumber: "serial1"))
        assertThat(changeCnt, `is`(3))
        assertThat(systemInfo!.firmwareVersion, `is`("1.2.3-beta1"))
        assertThat(systemInfo!.hardwareVersion, `is`("HW11"))
        assertThat(systemInfo!.serial, `is`("serial1"))
    }

    func testSystemInfoFactoryReset() {
        connect(remoteControl: remoteControl, handle: 1)

        // check default values
        assertThat(changeCnt, `is`(1))
        assertThat(systemInfo!.isFactoryResetInProgress, `is`(false))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.skyctrlFactoryReset())
        let inProgress = systemInfo!.factoryReset()
        assertThat(changeCnt, `is`(2))
        assertThat(inProgress, `is`(true))
        assertThat(systemInfo!.isFactoryResetInProgress, `is`(true))
    }
}
