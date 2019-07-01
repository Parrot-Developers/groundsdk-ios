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

class CopilotControllerTests: ArsdkEngineTestBase {

    var copilot: Copilot?
    var copilotRef: Ref<Copilot>?
    var remoteControl: RemoteControlCore!
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        setUpRc()
        changeCnt = 0
    }

    func setUpRc() {
        mockArsdkCore.addDevice("123", type: RemoteControl.Model.skyCtrl3.internalId, backendType: .mux, name: "RC1",
                                handle: 1)
        remoteControl = rcStore.getDevice(uid: "123")!

        copilotRef =
            remoteControl.getPeripheral(Peripherals.copilot) { [unowned self] copilot in
                self.copilot = copilot
                self.changeCnt += 1
        }
    }

    override func resetArsdkEngine() {
        super.resetArsdkEngine()
        setUpRc()
    }

    func testPublishUnpublis() {
        // should be unavailable when the drone is not connected
        assertThat(copilot, `is`(nilValue()))

        connect(remoteControl: remoteControl, handle: 1)
        assertThat(copilot, `is`(nilValue()))
        assertThat(changeCnt, `is`(0))

        disconnect(remoteControl: remoteControl, handle: 1)
        assertThat(copilot, `is`(nilValue()))
        assertThat(changeCnt, `is`(0))

        connect(remoteControl: remoteControl, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1,
                        encoder: CmdEncoder.skyctrlCopilotingstatePilotingsourceEncoder(source: .skycontroller))
        }
        assertThat(copilot, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(remoteControl: remoteControl, handle: 1)
        assertThat(copilot, `is`(present()))
        assertThat(changeCnt, `is`(1))
    }

    func testCopilot() {
        connect(remoteControl: remoteControl, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1,
                            encoder: CmdEncoder.skyctrlCopilotingstatePilotingsourceEncoder(source: .skycontroller))
        }
        assertThat(copilot, `is`(present()))
        assertThat(changeCnt, `is`(1))
        assertThat(copilot?.setting.source, `is`(.remoteControl))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.skyctrlCopilotingSetpilotingsource(source: .controller))
        copilot?.setting.source = .application

        assertThat(copilot?.setting.updating, `is`(true))
        assertThat(copilot?.setting.source, `is`(.application))
        assertThat(changeCnt, `is`(2))
        self.mockArsdkCore.onCommandReceived(1,
                                encoder: CmdEncoder.skyctrlCopilotingstatePilotingsourceEncoder(source: .controller))
        assertThat(changeCnt, `is`(3))
        assertThat(copilot?.setting.updating, `is`(false))

        copilot?.setting.source = .application
        assertThat(copilot?.setting.updating, `is`(false))
        assertThat(changeCnt, `is`(3))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.skyctrlCopilotingSetpilotingsource(source: .skycontroller))
        copilot?.setting.source = .remoteControl
        assertThat(copilot?.setting.updating, `is`(true))
        assertThat(copilot?.setting.source, `is`(.remoteControl))
        assertThat(changeCnt, `is`(4))

        self.mockArsdkCore.onCommandReceived(1,
                                encoder: CmdEncoder.skyctrlCopilotingstatePilotingsourceEncoder(source: .skycontroller))
        assertThat(copilot?.setting.updating, `is`(false))
        assertThat(changeCnt, `is`(5))

        copilot?.setting.source = .remoteControl
        assertThat(changeCnt, `is`(5))

        disconnect(remoteControl: remoteControl, handle: 1)
        assertThat(copilot?.setting.source, `is`(.remoteControl))
        assertThat(changeCnt, `is`(5))

        copilot?.setting.source = .application
        assertThat(copilot?.setting.source, `is`(.application))
        assertThat(copilot?.setting.updating, `is`(false))
        assertThat(changeCnt, `is`(6))

        connect(remoteControl: remoteControl, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1,
                            encoder: CmdEncoder.skyctrlCopilotingstatePilotingsourceEncoder(source: .skycontroller))
            self.expectCommand(handle: 1,
                            expectedCmd: ExpectedCmd.skyctrlCopilotingSetpilotingsource(source: .controller))
        }
        self.mockArsdkCore.onCommandReceived(1,
                                encoder: CmdEncoder.skyctrlCopilotingstatePilotingsourceEncoder(source: .controller))
    }
}
