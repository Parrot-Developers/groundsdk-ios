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

class AnafiBeeperControllerTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var beeper: Beeper?
    var beeperRef: Ref<Beeper>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        beeperRef =
            drone.getPeripheral(Peripherals.beeper) { [unowned self] beeper in
                self.beeper = beeper
                self.changeCnt += 1
        }
        changeCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(beeper, `is`(nilValue()))

        connect(drone: drone, handle: 1)
        assertThat(beeper, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(beeper, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testStartStopBeeper() {
        connect(drone: drone, handle: 1)
        // check default values
        assertThat(beeper, `is`(present()))
        assertThat(beeper!.alertSoundPlaying, `is`(false))
        assertThat(changeCnt, `is`(1))

        // receive a playing state
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.ardrone3SoundstateAlertsoundEncoder(state: .playing))
        assertThat(changeCnt, `is`(2))
        assertThat(beeper!.alertSoundPlaying, `is`(true))

        // receive a playing state (previous state is playing) -> no change
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.ardrone3SoundstateAlertsoundEncoder(state: .playing))
        assertThat(changeCnt, `is`(2))
        assertThat(beeper!.alertSoundPlaying, `is`(true))

        // receive a stopped state
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.ardrone3SoundstateAlertsoundEncoder(state: .stopped))
        assertThat(changeCnt, `is`(3))
        assertThat(beeper!.alertSoundPlaying, `is`(false))

        // receive a stopped state (previous state is stopped) -> no change
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.ardrone3SoundstateAlertsoundEncoder(state: .stopped))
        assertThat(changeCnt, `is`(3))
        assertThat(beeper!.alertSoundPlaying, `is`(false))

        disconnect(drone: drone, handle: 1)
        assertThat(beeper, `is`(nilValue()))
        assertThat(changeCnt, `is`(4))
    }
}
