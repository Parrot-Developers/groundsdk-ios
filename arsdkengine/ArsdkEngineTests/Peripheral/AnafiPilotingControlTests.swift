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

class AnafiPilotingControlTests: ArsdkEngineTestBase {

    let fullSupportedBehaviours: Set<PilotingBehaviour> = [.standard, .cameraOperated]
    let onlyStandardSupportedBehaviours: Set<PilotingBehaviour> = [.standard]
    var drone: DroneCore!
    var pilotingControl: PilotingControl?
    var pilotingControlRef: Ref<PilotingControl>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        setUpDrone()
    }

    func setUpDrone() {
        mockArsdkCore.addDevice(
            "123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1", handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        pilotingControlRef =
            drone.getPeripheral(Peripherals.pilotingControl) { [unowned self] pilotingControl in
                self.pilotingControl = pilotingControl
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
        assertThat(pilotingControl, `is`(nilValue()))

        connect(drone: drone, handle: 1)
        assertThat(pilotingControl, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // disconnect drone
        disconnect(drone: drone, handle: 1)
        assertThat(pilotingControl, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))

        // forget the drone
        _ = drone.forget()
        assertThat(pilotingControl, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testBehavioursAndSupportedBehaviours() {
        connect(drone: drone, handle: 1) {
            // initial values
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.pilotingStyleCapabilitiesEncoder(
                stylesBitField: Bitfield<ArsdkFeaturePilotingStyleStyle>.of(.standard, .cameraOperated)))
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.pilotingStyleStyleEncoder(style: .standard))

        }
        assertThat(pilotingControl, `is`(present()))
        assertThat(changeCnt, `is`(1))

        assertThat(pilotingControl!.behaviourSetting.supportedBehaviours, `is`(fullSupportedBehaviours))
        assertThat(pilotingControl!.behaviourSetting, `is`(value: .standard, updating: false))

        // change to camera Operated
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.pilotingStyleSetStyle(style: .cameraOperated))
        pilotingControl!.behaviourSetting.value = .cameraOperated
        assertThat(pilotingControl!.behaviourSetting, `is`(value: .cameraOperated, updating: true))
        assertThat(changeCnt, `is`(2))

        // drone changes to camera operated
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.pilotingStyleStyleEncoder(style: .cameraOperated))
        assertThat(pilotingControl!.behaviourSetting, `is`(value: .cameraOperated, updating: false))
        assertThat(changeCnt, `is`(3))

        // drone disables the camera operated
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.pilotingStyleStyleEncoder(style: .standard))
        assertThat(pilotingControl!.behaviourSetting, `is`(value: .standard, updating: false))
        assertThat(changeCnt, `is`(4))

        // drone changes the supported modes
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.pilotingStyleCapabilitiesEncoder(
            stylesBitField: Bitfield<ArsdkFeaturePilotingStyleStyle>.of(.standard)))
        assertThat(pilotingControl!.behaviourSetting.supportedBehaviours, `is`(onlyStandardSupportedBehaviours))
        assertThat(pilotingControl!.behaviourSetting, `is`(value: .standard, updating: false))
        assertThat(changeCnt, `is`(5))

        // trey to change to camera operated
        pilotingControl!.behaviourSetting.value = .cameraOperated
        assertThat(pilotingControl!.behaviourSetting, `is`(value: .standard, updating: false))
        assertThat(changeCnt, `is`(6))

        // disconnect
        disconnect(drone: drone, handle: 1)

        assertThat(pilotingControl, `is`(nilValue()))
        assertThat(changeCnt, `is`(7))
    }

    func testNoPilotingControlFeature() {
        connect(drone: drone, handle: 1)
        assertThat(pilotingControl, `is`(present()))
        assertThat(changeCnt, `is`(1))

        assertThat(pilotingControl!.behaviourSetting.supportedBehaviours, `is`(onlyStandardSupportedBehaviours))
        assertThat(pilotingControl!.behaviourSetting, `is`(value: .standard, updating: false))

        // trey to change to camera operated
        pilotingControl!.behaviourSetting.value = .cameraOperated
        assertThat(pilotingControl!.behaviourSetting, `is`(value: .standard, updating: false))
        assertThat(changeCnt, `is`(2))

        // disconnect
        disconnect(drone: drone, handle: 1)

        assertThat(pilotingControl, `is`(nilValue()))
        assertThat(changeCnt, `is`(3))
    }
}
