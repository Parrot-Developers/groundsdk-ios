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

class LedsControllerTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var leds: Leds?
    var ledsRef: Ref<Leds>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        setUpDrone()
        changeCnt = 0
    }

    func setUpDrone() {
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        ledsRef =
            drone.getPeripheral(Peripherals.leds) { [unowned self] leds in
                self.leds = leds
                self.changeCnt += 1
        }
    }

    override func resetArsdkEngine() {
        super.resetArsdkEngine()
        setUpDrone()
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(leds, `is`(nilValue()))

        connect(drone: drone, handle: 1)
        assertThat(leds, `is`(nilValue()))
        disconnect(drone: drone, handle: 1)
        assertThat(changeCnt, `is`(0))

        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1,
                    encoder: CmdEncoder.ledsCapabilitiesEncoder(
                        supportedCapabilitiesBitField: Bitfield<ArsdkFeatureLedsSupportedCapabilities>.of(.onOff)))
        }
        assertThat(leds, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(leds, `is`(present()))
        assertThat(changeCnt, `is`(1))
    }

    func testStartStopSwitch() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1,
                    encoder: CmdEncoder.ledsCapabilitiesEncoder(
                        supportedCapabilitiesBitField: Bitfield<ArsdkFeatureLedsSupportedCapabilities>.of(.onOff)))
        }

        assertThat(leds, `is`(present()))
        assertThat(leds!.state, `is`(nilValue()))
        assertThat(changeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1,
                                                 encoder: CmdEncoder.ledsSwitchStateEncoder(switchState: .off))
        }
        assertThat(leds!.state, `is`(present()))
        assertThat(leds!.state!, `is`(false))
        assertThat(changeCnt, `is`(1))

        // receive a switch state
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.ledsSwitchStateEncoder(switchState: .on))
        assertThat(changeCnt, `is`(2))
        assertThat(leds!.state!, `is`(true))

        // receive a switch state (previous state is on) -> no change
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.ledsSwitchStateEncoder(switchState: .on))
        assertThat(changeCnt, `is`(2))
        assertThat(leds!.state!, `is`(true))

        // receive a switch state off
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.ledsSwitchStateEncoder(switchState: .off))
        assertThat(changeCnt, `is`(3))
        assertThat(leds!.state!, `is`(false))

        // receive a switch state (previous state is off) -> no change
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.ledsSwitchStateEncoder(switchState: .off))
        assertThat(changeCnt, `is`(3))
        assertThat(leds!.state!, `is`(false))

        disconnect(drone: drone, handle: 1)
        assertThat(leds, `is`(present()))
        assertThat(changeCnt, `is`(3))
    }

    func testSupportedCapabilities() {
        connect(drone: drone, handle: 1) {
            let capabilities: [ArsdkFeatureLedsSupportedCapabilities] = [.onOff]
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ledsCapabilitiesEncoder(
                    supportedCapabilitiesBitField: Bitfield.of(capabilities)))
            self.mockArsdkCore.onCommandReceived(1,
                                                 encoder: CmdEncoder.ledsSwitchStateEncoder(switchState: .off))
        }
        // check default values
        assertThat(leds, `is`(present()))
        assertThat(leds!.state!, `is`(false))
        assertThat(changeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(leds, `is`(present()))
        assertThat(changeCnt, `is`(1))
        leds!.state!.value = true
        assertThat(leds!.state!.updating, `is`(false))
        assertThat(changeCnt, `is`(2))

        connect(drone: drone, handle: 1) {
            let capabilities: [ArsdkFeatureLedsSupportedCapabilities] = [.onOff]
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ledsCapabilitiesEncoder(
                    supportedCapabilitiesBitField: Bitfield.of(capabilities)))
            self.mockArsdkCore.onCommandReceived(1,
                                                 encoder: CmdEncoder.ledsSwitchStateEncoder(switchState: .off))
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.ledsActivate())
        }
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.ledsSwitchStateEncoder(switchState: .on))
        assertThat(leds, `is`(present()))
        assertThat(leds!.state!, `is`(true))
        assertThat(changeCnt, `is`(2))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ledsDeactivate())
        leds!.state!.value = false
        assertThat(leds!.state!.updating, `is`(true))
        assertThat(changeCnt, `is`(3))
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.ledsSwitchStateEncoder(switchState: .off))
        assertThat(leds!.state!.updating, `is`(false))
        assertThat(changeCnt, `is`(4))
        leds!.state!.value = false
        assertThat(changeCnt, `is`(4))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ledsActivate())
        leds!.state!.value = true
        disconnect(drone: drone, handle: 1)

        resetArsdkEngine()
        changeCnt = 0
        assertThat(leds, `is`(present()))
        assertThat(leds!.state, `is`(present()))
        assertThat(leds!.state!.value, `is`(true))

        connect(drone: drone, handle: 1) {
            let capabilities: [ArsdkFeatureLedsSupportedCapabilities] = [.onOff]
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ledsCapabilitiesEncoder(
                    supportedCapabilitiesBitField: Bitfield.of(capabilities)))
            self.mockArsdkCore.onCommandReceived(1,
                                                 encoder: CmdEncoder.ledsSwitchStateEncoder(switchState: .on))
        }
        disconnect(drone: drone, handle: 1)
        assertThat(leds, `is`(present()))
        _ = drone.forget()
        assertThat(leds, `is`(nilValue()))
    }
}
