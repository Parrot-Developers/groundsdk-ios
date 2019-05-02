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

class PreciseHomeControllerTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var preciseHome: PreciseHome?
    var preciseHomeRef: Ref<PreciseHome>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        setUpDrone()
    }

    func setUpDrone() {
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId,
                                backendType: .net, name: "Drone1", handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        preciseHomeRef =
            drone.getPeripheral(Peripherals.preciseHome) { [unowned self] preciseHome in
                self.preciseHome = preciseHome
                self.changeCnt += 1
        }
        changeCnt = 0
    }

    override func resetArsdkEngine() {
        super.resetArsdkEngine()
        setUpDrone()
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(preciseHome, `is`(nilValue()))

        connect(drone: drone, handle: 1)

        // should be unavailable since by default it isn't supported
        assertThat(preciseHome, `is`(nilValue()))
        assertThat(changeCnt, `is`(0))

        disconnect(drone: drone, handle: 1)
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.preciseHomeCapabilitiesEncoder(
                modesBitField: Bitfield<ArsdkFeaturePreciseHomeMode>.of(.standard, .disabled)))
        }

        assertThat(preciseHome, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(preciseHome, `is`(present()))
        assertThat(changeCnt, `is`(1)) // is not changed since mode is .disabled

        _ = drone.forget()
        assertThat(preciseHome, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))

        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.preciseHomeCapabilitiesEncoder(
                modesBitField: Bitfield<ArsdkFeaturePreciseHomeMode>.of(.standard, .disabled)))
        }

        assertThat(preciseHome, `is`(present()))
        assertThat(changeCnt, `is`(3))

        self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.preciseHomeModeEncoder(mode: .standard))
        assertThat(changeCnt, `is`(4))

        disconnect(drone: drone, handle: 1)
        assertThat(preciseHome, `is`(present()))
        assertThat(changeCnt, `is`(5))

        _ = drone.forget()
        assertThat(preciseHome, `is`(nilValue()))
        assertThat(changeCnt, `is`(6)) // change from .standard to .disabled
    }

    func testMode() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.preciseHomeCapabilitiesEncoder(
                modesBitField: Bitfield<ArsdkFeaturePreciseHomeMode>.of(.standard, .disabled)))
        }
        assertThat(preciseHome, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // initial values
        assertThat(preciseHome!.setting, supports(modes: [.standard, .disabled]))
        assertThat(preciseHome!.setting, `is`(mode: .disabled, updating: false))
        assertThat(preciseHome!.state, `is`(.unavailable))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.preciseHomeSetMode(mode: .standard))
        preciseHome!.setting.mode = .standard
        assertThat(changeCnt, `is`(2))
        assertThat(preciseHome!.setting, `is`(mode: .standard, updating: true))

        self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.preciseHomeModeEncoder(mode: .standard))
        assertThat(changeCnt, `is`(3))
        assertThat(preciseHome!.setting, `is`(mode: .standard, updating: false))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.preciseHomeSetMode(mode: .disabled))
        preciseHome!.setting.mode = .disabled
        assertThat(changeCnt, `is`(4))
        assertThat(preciseHome!.setting, `is`(mode: .disabled, updating: true))

        self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.preciseHomeModeEncoder(mode: .disabled))
        assertThat(changeCnt, `is`(5))
        assertThat(preciseHome!.setting, `is`(mode: .disabled, updating: false))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.preciseHomeSetMode(mode: .standard))
        preciseHome!.setting.mode = .standard
        assertThat(changeCnt, `is`(6))
        assertThat(preciseHome!.setting, `is`(mode: .standard, updating: true))

        disconnect(drone: drone, handle: 1)

        // setting should be updated to user value and other values are reset
        assertThat(preciseHome!.setting, `is`(mode: .disabled, updating: false))
        assertThat(preciseHome!.state, `is`(.unavailable))
        assertThat(changeCnt, `is`(7))

        resetArsdkEngine()
        assertThat(preciseHome!.setting, `is`(mode: .standard, updating: false))
        assertThat(preciseHome!.state, `is`(.unavailable))

        // apply mode on connection
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.preciseHomeCapabilitiesEncoder(
                modesBitField: Bitfield<ArsdkFeaturePreciseHomeMode>.of(.standard, .disabled)))
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.preciseHomeModeEncoder(mode: .disabled))
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.preciseHomeSetMode(mode: .standard))
         }

        self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.preciseHomeModeEncoder(mode: .standard))
        assertThat(preciseHome!.setting, `is`(mode: .standard, updating: false))
    }

    func testState() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.preciseHomeCapabilitiesEncoder(
                modesBitField: Bitfield<ArsdkFeaturePreciseHomeMode>.of(.standard, .disabled)))
        }
        assertThat(preciseHome, `is`(present()))
        assertThat(changeCnt, `is`(1))

        self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.preciseHomeStateEncoder(state: .active))
        assertThat(changeCnt, `is`(2))
        assertThat(preciseHome!.state, `is`(.active))

        self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.preciseHomeStateEncoder(state: .active))
        assertThat(changeCnt, `is`(2))
        assertThat(preciseHome!.state, `is`(.active))

        self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.preciseHomeStateEncoder(state: .available))
        assertThat(changeCnt, `is`(3))
        assertThat(preciseHome!.state, `is`(.available))

        disconnect(drone: drone, handle: 1)
    }
}
