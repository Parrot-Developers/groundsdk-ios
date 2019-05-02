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

class PoiPilotingItfTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var poiPilotingItf: PointOfInterestPilotingItf?
    var poiPilotingItfRef: Ref<PointOfInterestPilotingItf>?
    var manualCopterPilotingItf: ManualCopterPilotingItf?
    var manualCopterPilotingItfRef: Ref<ManualCopterPilotingItf>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        poiPilotingItfRef = drone.getPilotingItf(PilotingItfs.pointOfInterest) { [unowned self] pilotingItf in
            self.poiPilotingItf = pilotingItf
            self.changeCnt += 1
        }

        manualCopterPilotingItfRef = drone.getPilotingItf(PilotingItfs.manualCopter) { [unowned self] pilotingItf in
            self.manualCopterPilotingItf = pilotingItf
        }

        changeCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected and not known
        assertThat(poiPilotingItf, `is`(nilValue()))

        // connect the drone, piloting interface should be published
        connect(drone: drone, handle: 1)
        assertThat(poiPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        assertThat(poiPilotingItf!.state, `is`(.unavailable))

        // disconnect drone
        disconnect(drone: drone, handle: 1)
        assertThat(poiPilotingItf, nilValue())
        assertThat(changeCnt, `is`(2)) // should have been unactivated and deactivated
    }

    func testStartStopPoiCmd() {
        let seqNrGenerator = PilotingCommand.Encoder.AnafiCopter()
        let timeProvider = MockTimeProvider()
        TimeProvider.instance = timeProvider

        connect(drone: drone, handle: 1)
        assertThat(poiPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // flying
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
         assertThat(poiPilotingItf!.state, `is`(.unavailable))
        assertThat(changeCnt, `is`(1))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstatePilotedpoiEncoder(
                latitude: 500, longitude: 500, altitude: 500, status: .available))

        // check initial state
        assertThat(poiPilotingItf!.currentPointOfInterest, nilValue())
        assertThat(poiPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(2))

        // send a Poi command
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingStartpilotedpoi(
            latitude: 1.1, longitude: 2.2, altitude: 3.3))

        poiPilotingItf!.start(latitude: 1.1, longitude: 2.2, altitude: 3.3)

        // Poi is running
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstatePilotedpoiEncoder(
                latitude: 1.1, longitude: 2.2, altitude: 3.3, status: .running))

        assertThat(changeCnt, `is`(3))
        let currentPoi = poiPilotingItf!.currentPointOfInterest

        assertThat(currentPoi, presentAnd(`is`(latitude: 1.1, longitude: 2.2, altitude: 3.3)))

        // The poi Piloting interface should be active
        assertThat(poiPilotingItf!.state, `is`(.active))

        // Send piloting commands
        timeProvider.lockTime()
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingPcmd(
            flag: 0, roll: 0, pitch: 0, yaw: 0, gaz: 0, timestampandseqnum: seqNrGenerator.nextSequenceNumber()))
        mockNonAckLoop(handle: 1, noAckType: .piloting)

        // Update pcmd value
        poiPilotingItf!.set(roll: 2)
        poiPilotingItf!.set(pitch: 4)
        poiPilotingItf!.set(verticalSpeed: 8)
        timeProvider.lockTime()
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingPcmd(
            flag: 1, roll: 2, pitch: -4, yaw: 0, gaz: 8, timestampandseqnum: seqNrGenerator.nextSequenceNumber()))
        mockNonAckLoop(handle: 1, noAckType: .piloting)

        // Poi is finished (the user requests a "stop")
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingStoppilotedpoi())
        _ = poiPilotingItf!.deactivate()
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstatePilotedpoiEncoder(
                latitude: 500, longitude: 500, altitude: 500, status: .available))
        assertThat(poiPilotingItf!.currentPointOfInterest, nilValue())
        assertThat(poiPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(4))

        // Landed and state unavailable
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(poiPilotingItf!.state, `is`(.unavailable))
        assertThat(changeCnt, `is`(5))
    }

    func testAvailableAndThenFlying() {
        connect(drone: drone, handle: 1)
        assertThat(poiPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))
        assertThat(poiPilotingItf!.state, `is`(.unavailable))

        // First state: "available"
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstatePilotedpoiEncoder(
                latitude: 500, longitude: 500, altitude: 500, status: .available))

        assertThat(poiPilotingItf!.state, `is`(.unavailable))
        assertThat(changeCnt, `is`(1))

        // Then: flying
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        // check initial state
        assertThat(poiPilotingItf!.currentPointOfInterest, nilValue())
        assertThat(poiPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(2))
    }

    func testStartAndThenChangeThePoi() {
        connect(drone: drone, handle: 1)
        assertThat(poiPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // Flying
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstatePilotedpoiEncoder(
                latitude: 500, longitude: 500, altitude: 500, status: .available))

        // Check initial state
        assertThat(poiPilotingItf!.currentPointOfInterest, nilValue())
        assertThat(poiPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(2))

        // Send a Poi command
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingStartpilotedpoi(
            latitude: 1.1, longitude: 2.2, altitude: 3.3))

        poiPilotingItf!.start(latitude: 1.1, longitude: 2.2, altitude: 3.3)

        // Poi is running
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstatePilotedpoiEncoder(
                latitude: 1.1, longitude: 2.2, altitude: 3.3, status: .running))

        assertThat(changeCnt, `is`(3))
        let currentPoi = poiPilotingItf!.currentPointOfInterest
        assertThat(currentPoi, presentAnd(`is`(latitude: 1.1, longitude: 2.2, altitude: 3.3)))

        // The poi Piloting interface should be active
        assertThat(poiPilotingItf!.state, `is`(.active))

        // Change the Poi (send a new Poi command)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingStartpilotedpoi(
            latitude: 11.1, longitude: 22.2, altitude: 33.3))

        poiPilotingItf!.start(latitude: 11.1, longitude: 22.2, altitude: 33.3)

        // Poi is running
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstatePilotedpoiEncoder(
                latitude: 11.1, longitude: 22.2, altitude: 33.3, status: .running))

        assertThat(changeCnt, `is`(4))
        let newCurrentPoi = poiPilotingItf!.currentPointOfInterest
        assertThat(newCurrentPoi, presentAnd(`is`(latitude: 11.1, longitude: 22.2, altitude: 33.3)))

        // The poi Piloting interface should be active
        assertThat(poiPilotingItf!.state, `is`(.active))

        // Poi is finished
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingStoppilotedpoi())
        _ = poiPilotingItf!.deactivate()
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstatePilotedpoiEncoder(
                latitude: 500, longitude: 500, altitude: 500, status: .available))
        assertThat(poiPilotingItf!.currentPointOfInterest, nilValue())
        assertThat(poiPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(5))

        // Landed and state unavailable
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(poiPilotingItf!.state, `is`(.unavailable))
        assertThat(changeCnt, `is`(6))
    }

    func testStartPoiAndStopUsingManualItf() {
        connect(drone: drone, handle: 1)
        assertThat(poiPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // Flying and available
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstatePilotedpoiEncoder(
                latitude: 500, longitude: 500, altitude: 500, status: .available))
        assertThat(poiPilotingItf!.state, `is`(.idle))
        assertThat(poiPilotingItf!.currentPointOfInterest, nilValue())
        assertThat(changeCnt, `is`(2))

        // Send a Poi command
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingStartpilotedpoi(
            latitude: 1.1, longitude: 2.2, altitude: 3.3))

        poiPilotingItf!.start(latitude: 1.1, longitude: 2.2, altitude: 3.3)

        // Poi is running
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstatePilotedpoiEncoder(
                latitude: 1.1, longitude: 2.2, altitude: 3.3, status: .running))

        assertThat(changeCnt, `is`(3))
        let currentPoi = poiPilotingItf!.currentPointOfInterest
        assertThat(currentPoi, presentAnd(`is`(latitude: 1.1, longitude: 2.2, altitude: 3.3)))

        // The poi Piloting interface should be active
        assertThat(poiPilotingItf!.state, `is`(.active))

        // Ask to the manualMiplotingItf to be active
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingStoppilotedpoi())
        _ = manualCopterPilotingItf!.activate()
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstatePilotedpoiEncoder(
                latitude: 500, longitude: 500, altitude: 500, status: .available))

        assertThat(poiPilotingItf!.currentPointOfInterest, nilValue())
        assertThat(poiPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(4))

        // Landed and state unavailable
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(poiPilotingItf!.state, `is`(.unavailable))
        assertThat(changeCnt, `is`(5))
    }

    /// test status when we reconnect to a flying  drone
    func testStatusReconnecingAFlyingDrone() {
        connect(drone: drone, handle: 1)
        assertThat(poiPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // Flying
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstatePilotedpoiEncoder(
                latitude: 500, longitude: 500, altitude: 500, status: .available))

        // Check initial state
        assertThat(poiPilotingItf!.currentPointOfInterest, nilValue())
        assertThat(poiPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(2))

        // disconnect the drone
        disconnect(drone: drone, handle: 1)
        assertThat(poiPilotingItf, nilValue())
        assertThat(changeCnt, `is`(4)) // has been set .unavailable (was .idle before) then deactivated (nil)

        // connect the drone
        connect(drone: drone, handle: 1) {
            // Flying
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingstatePilotedpoiEncoder(
                    latitude: 500, longitude: 500, altitude: 500, status: .available))
        }
        assertThat(poiPilotingItf, `is`(present()))

        // Check initial state
        assertThat(poiPilotingItf!.currentPointOfInterest, nilValue())
        assertThat(poiPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(5))

        // Send a Poi command
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingStartpilotedpoi(
            latitude: 11.1, longitude: 22.2, altitude: 33.3))

        poiPilotingItf!.start(latitude: 11.1, longitude: 22.2, altitude: 33.3)

        // Poi is running
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstatePilotedpoiEncoder(
                latitude: 11.1, longitude: 22.2, altitude: 33.3, status: .running))

        assertThat(changeCnt, `is`(6))
        let currentPoi = poiPilotingItf!.currentPointOfInterest
        assertThat(currentPoi, presentAnd(`is`(latitude: 11.1, longitude: 22.2, altitude: 33.3)))

        // The poi Piloting interface should be active
        assertThat(poiPilotingItf!.state, `is`(.active))

        // disconnect the drone
        disconnect(drone: drone, handle: 1)
        assertThat(poiPilotingItf, nilValue())
        assertThat(changeCnt, `is`(8))  // has been set .unavailable (was .active before) then deactivated (nil)

        // connect the drone
        connect(drone: drone, handle: 1) {
            // Flying
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
            // Poi is still running
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingstatePilotedpoiEncoder(
                    latitude: 11.1, longitude: 22.2, altitude: 33.3, status: .running))
        }

        assertThat(changeCnt, `is`(9))
        let currentPoiRunning = poiPilotingItf!.currentPointOfInterest
        assertThat(poiPilotingItf!.state, `is`(.active))
        assertThat(currentPoiRunning, presentAnd(`is`(latitude: 11.1, longitude: 22.2, altitude: 33.3)))
    }
}
