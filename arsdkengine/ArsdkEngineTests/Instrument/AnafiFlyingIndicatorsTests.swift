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

class AnafiFlyingIndicatorsTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var flyingIndicators: FlyingIndicators?
    var flyingIndicatorsRef: Ref<FlyingIndicators>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        flyingIndicatorsRef = drone.getInstrument(Instruments.flyingIndicators) { [unowned self] indicator in
            self.flyingIndicators = indicator
            self.changeCnt += 1
        }
        changeCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(flyingIndicators, `is`(nilValue()))

        connect(drone: drone, handle: 1)
        assertThat(flyingIndicators, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(flyingIndicators, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testValue() {
        connect(drone: drone, handle: 1)
        // check default values
        assertThat(flyingIndicators!, `is`(.landed, .initializing, .none))
        assertThat(changeCnt, `is`(1))

        // Landed
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(flyingIndicators!, `is`(.landed, .idle, .none))
        assertThat(changeCnt, `is`(2))

        // Takingoff
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .takingoff))
        assertThat(flyingIndicators!, `is`(.flying, .none, .takingOff))
        assertThat(changeCnt, `is`(3))

        // Hovering
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .hovering))
        assertThat(flyingIndicators!, `is`(.flying, .none, .waiting))
        assertThat(changeCnt, `is`(4))

        // Flying
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        assertThat(flyingIndicators!, `is`(.flying, .none, .flying))
        assertThat(changeCnt, `is`(5))

        // Landing
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landing))
        assertThat(flyingIndicators!, `is`(.flying, .none, .landing))
        assertThat(changeCnt, `is`(6))

        // Emergency
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .emergency))
        assertThat(flyingIndicators!, `is`(.emergency, .none, .none))
        assertThat(changeCnt, `is`(7))

        // Usertakeoff
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .usertakeoff))
        assertThat(flyingIndicators!, `is`(.landed, .waitingUserAction, .none))
        assertThat(changeCnt, `is`(8))

        // Emergency Landing
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .emergencyLanding))
        assertThat(flyingIndicators!, `is`(.emergencyLanding, .none, .none))
        assertThat(changeCnt, `is`(9))

        // back to Landed
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(flyingIndicators!, `is`(.landed, .idle, .none))
        assertThat(changeCnt, `is`(10))

        // motor ramping
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .motorRamping))
        assertThat(flyingIndicators!, `is`(.landed, .motorRamping, .none))
        assertThat(changeCnt, `is`(11))
    }
}
