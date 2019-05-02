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

class FollowFeatureLookAtPilotingItfTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var lookAtPilotingItf: LookAtPilotingItf?
    var lookAtPilotingItfRef: Ref<LookAtPilotingItf>?
    var manualCopterPilotingItf: ManualCopterPilotingItf?
    var manualCopterPilotingItfRef: Ref<ManualCopterPilotingItf>?
    var changeCnt = 0

    let missingImageBitfield: UInt = ~(Bitfield<ArsdkFeatureFollowMeInput>.of(.imageDetection))
    let targetTooCloseBitfield: UInt = ~(Bitfield<ArsdkFeatureFollowMeInput>.of(.droneFarEnough))
    let emptyBitfield: UInt = ~0
    let issuesEmptySet = Set<TrackingIssue>()
    let issuesSetImage: Set<TrackingIssue> = [.targetDetectionInfoMissing]
    let issuesSetTooClose: Set<TrackingIssue> = [.droneTooCloseToTarget]
    let issueSetNotFlying: Set<TrackingIssue> = [.droneNotFlying]
    let issueImageAndNotFlying: Set<TrackingIssue> = [.droneNotFlying, .targetDetectionInfoMissing]

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        lookAtPilotingItfRef = drone.getPilotingItf(PilotingItfs.lookAt) { [unowned self] pilotingItf in
            self.lookAtPilotingItf = pilotingItf
            self.changeCnt += 1
        }

        manualCopterPilotingItfRef = drone.getPilotingItf(PilotingItfs.manualCopter) { [unowned self] pilotingItf in
            self.manualCopterPilotingItf = pilotingItf
        }

        changeCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected and not known
        assertThat(lookAtPilotingItf, `is`(nilValue()))

        // connect the drone, piloting interface should be published
        connect(drone: drone, handle: 1)
        assertThat(lookAtPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        assertThat(lookAtPilotingItf!.state, `is`(.unavailable))

        // disconnect drone
        disconnect(drone: drone, handle: 1)
        assertThat(lookAtPilotingItf, nilValue())
        assertThat(changeCnt, `is`(2)) // should have been unactivated and deactivated
    }

    func testLookAtActivation() {

        connect(drone: drone, handle: 1) {
            // Missing image detection
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.followMeModeInfoEncoder(
                    mode: .lookAt, missingRequirementsBitField: self.missingImageBitfield,
                    improvementsBitField: self.emptyBitfield))
        }
        assertThat(lookAtPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        assertThat(lookAtPilotingItf!.state, `is`(.unavailable))
        assertThat(lookAtPilotingItf!.availabilityIssues, `is`(issueImageAndNotFlying))

        // flying
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))

        assertThat(lookAtPilotingItf!.state, `is`(.unavailable))
        assertThat(lookAtPilotingItf!.availabilityIssues, `is`(issuesSetImage))
        assertThat(changeCnt, `is`(2))

        // ready for LookAt
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .lookAt, missingRequirementsBitField: emptyBitfield, improvementsBitField: emptyBitfield))
        assertThat(lookAtPilotingItf!.state, `is`(.idle))
        assertThat(lookAtPilotingItf!.availabilityIssues, `is`(issuesEmptySet))
        assertThat(lookAtPilotingItf!.qualityIssues, `is`(issuesEmptySet))
        assertThat(changeCnt, `is`(3))

        // Target is Too Close (quality issue)
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .lookAt, missingRequirementsBitField: emptyBitfield,
                improvementsBitField: targetTooCloseBitfield))
        assertThat(lookAtPilotingItf!.state, `is`(.idle))
        assertThat(lookAtPilotingItf!.availabilityIssues, `is`(issuesEmptySet))
        assertThat(lookAtPilotingItf!.qualityIssues, `is`(issuesSetTooClose))
        assertThat(changeCnt, `is`(4))

        // activate
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeStart(mode: .lookAt))
        _ = lookAtPilotingItf?.activate()
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeStateEncoder(
                mode: .lookAt, behavior: .lookAt, animation: .none, animationAvailableBitField: 0))

        assertThat(lookAtPilotingItf!.state, `is`(.active))
        assertThat(lookAtPilotingItf!.availabilityIssues, `is`(issuesEmptySet))
        assertThat(lookAtPilotingItf!.qualityIssues, `is`(issuesSetTooClose))
        assertThat(changeCnt, `is`(5))

        // no quality issue
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .lookAt, missingRequirementsBitField: emptyBitfield, improvementsBitField: emptyBitfield))
        assertThat(lookAtPilotingItf!.state, `is`(.active))
        assertThat(lookAtPilotingItf!.availabilityIssues, `is`(issuesEmptySet))
        assertThat(lookAtPilotingItf!.qualityIssues, `is`(issuesEmptySet))
        assertThat(changeCnt, `is`(6))

        // deactivate
         expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeStop())
        _ = lookAtPilotingItf?.deactivate()
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeStateEncoder(
                mode: .none, behavior: .lookAt, animation: .none, animationAvailableBitField: 0))
        assertThat(lookAtPilotingItf!.state, `is`(.idle))
        assertThat(lookAtPilotingItf!.availabilityIssues, `is`(issuesEmptySet))
        assertThat(lookAtPilotingItf!.qualityIssues, `is`(issuesEmptySet))
        assertThat(changeCnt, `is`(7))

        // unavailability (image problem)
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .lookAt, missingRequirementsBitField: missingImageBitfield, improvementsBitField: emptyBitfield))
        assertThat(lookAtPilotingItf!.state, `is`(.unavailable))
        assertThat(lookAtPilotingItf!.availabilityIssues, `is`(issuesSetImage))
        assertThat(lookAtPilotingItf!.qualityIssues, `is`(issuesEmptySet))
        assertThat(changeCnt, `is`(8))

    }

    func testLookAtAndPilot() {

        let seqNrGenerator = PilotingCommand.Encoder.AnafiCopter()
        let timeProvider = MockTimeProvider()
        TimeProvider.instance = timeProvider

        connect(drone: drone, handle: 1)
        assertThat(lookAtPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // flying and ready
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .lookAt, missingRequirementsBitField: emptyBitfield, improvementsBitField: emptyBitfield))
        assertThat(lookAtPilotingItf!.state, `is`(.idle))
        assertThat(lookAtPilotingItf!.availabilityIssues, `is`(issuesEmptySet))
        assertThat(changeCnt, `is`(2))

        // activate
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeStart(mode: .lookAt))
        _ = lookAtPilotingItf?.activate()
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeStateEncoder(
                mode: .lookAt, behavior: .lookAt, animation: .none, animationAvailableBitField: 0))

        assertThat(lookAtPilotingItf!.state, `is`(.active))
        assertThat(lookAtPilotingItf!.availabilityIssues, `is`(issuesEmptySet))
        assertThat(lookAtPilotingItf!.qualityIssues, `is`(issuesEmptySet))
        assertThat(changeCnt, `is`(3))

        // Send piloting commands
        timeProvider.lockTime()
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingPcmd(
            flag: 0, roll: 0, pitch: 0, yaw: 0, gaz: 0, timestampandseqnum: seqNrGenerator.nextSequenceNumber()))
        mockNonAckLoop(handle: 1, noAckType: .piloting)

        // Update pcmd value
        lookAtPilotingItf!.set(roll: 2)
        lookAtPilotingItf!.set(pitch: 4)
        lookAtPilotingItf!.set(verticalSpeed: 8)
        timeProvider.lockTime()
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingPcmd(
            flag: 1, roll: 2, pitch: -4, yaw: 0, gaz: 8, timestampandseqnum: seqNrGenerator.nextSequenceNumber()))
        mockNonAckLoop(handle: 1, noAckType: .piloting)

        // deactivate
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeStop())
        _ = lookAtPilotingItf?.deactivate()
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeStateEncoder(
                mode: .none, behavior: .lookAt, animation: .none, animationAvailableBitField: 0))
        assertThat(lookAtPilotingItf!.state, `is`(.idle))
        assertThat(lookAtPilotingItf!.availabilityIssues, `is`(issuesEmptySet))
        assertThat(lookAtPilotingItf!.qualityIssues, `is`(issuesEmptySet))
        assertThat(changeCnt, `is`(4))

        // Landed and state unavailable
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(lookAtPilotingItf!.state, `is`(.unavailable))
        assertThat(changeCnt, `is`(5))
    }

    func testLookAtOkButNotFlying() {

        connect(drone: drone, handle: 1)
        assertThat(lookAtPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // LookAt ready AND not flying
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .lookAt, missingRequirementsBitField: emptyBitfield, improvementsBitField: emptyBitfield))
        assertThat(lookAtPilotingItf!.state, `is`(.unavailable))
        assertThat(lookAtPilotingItf!.availabilityIssues, `is`(issueSetNotFlying))
        assertThat(changeCnt, `is`(1))

        // flying -> Should be .idle
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        assertThat(lookAtPilotingItf!.state, `is`(.idle))
        assertThat(lookAtPilotingItf!.availabilityIssues, `is`(issuesEmptySet))
        assertThat(lookAtPilotingItf!.qualityIssues, `is`(issuesEmptySet))
        assertThat(changeCnt, `is`(2))

        // Landed and state unavailable
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(lookAtPilotingItf!.state, `is`(.unavailable))
        assertThat(changeCnt, `is`(3))
    }

    func testLookAtAutoSwitchBetweenModes() {

        let seqNrGenerator = PilotingCommand.Encoder.AnafiCopter()
        let timeProvider = MockTimeProvider()
        TimeProvider.instance = timeProvider

        connect(drone: drone, handle: 1) {
            // flying and ready
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.followMeModeInfoEncoder(
                    mode: .geographic, missingRequirementsBitField: self.emptyBitfield,
                    improvementsBitField: self.emptyBitfield))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.followMeStateEncoder(
                     mode: .lookAt, behavior: .lookAt, animation: .none, animationAvailableBitField: 0))
        }
        assertThat(lookAtPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))
        assertThat(lookAtPilotingItf!.state, `is`(.active))

        // Send piloting commands
        timeProvider.lockTime()
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingPcmd(
            flag: 0, roll: 0, pitch: 0, yaw: 0, gaz: 0, timestampandseqnum: seqNrGenerator.nextSequenceNumber()))
        mockNonAckLoop(handle: 1, noAckType: .piloting)
        // Update pcmd value
        lookAtPilotingItf!.set(roll: 2)
        lookAtPilotingItf!.set(pitch: 4)
        lookAtPilotingItf!.set(verticalSpeed: 8)
        timeProvider.lockTime()
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingPcmd(
            flag: 1, roll: 2, pitch: -4, yaw: 0, gaz: 8, timestampandseqnum: seqNrGenerator.nextSequenceNumber()))
        mockNonAckLoop(handle: 1, noAckType: .piloting)

        // the drone is in Follow
        seqNrGenerator.reset()
        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeStateEncoder(
                mode: .relative, behavior: .follow, animation: .none, animationAvailableBitField: 0))
        assertThat(changeCnt, `is`(2))
        assertThat(lookAtPilotingItf!.state, `is`(.idle))

        timeProvider.lockTime()
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingPcmd(
            flag: 0, roll: 0, pitch: 0, yaw: 0, gaz: 0, timestampandseqnum: seqNrGenerator.nextSequenceNumber()))
        mockNonAckLoop(handle: 1, noAckType: .piloting)

        // the drone is back in LookAt
        seqNrGenerator.reset()
        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeStateEncoder(
                mode: .lookAt, behavior: .lookAt, animation: .none, animationAvailableBitField: 0))
        assertThat(changeCnt, `is`(3))
        assertThat(lookAtPilotingItf!.state, `is`(.active))

        // Send piloting commands
        timeProvider.lockTime()
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingPcmd(
            flag: 0, roll: 0, pitch: 0, yaw: 0, gaz: 0, timestampandseqnum: seqNrGenerator.nextSequenceNumber()))
        mockNonAckLoop(handle: 1, noAckType: .piloting)
        // Update pcmd value
        lookAtPilotingItf!.set(roll: 9)
        lookAtPilotingItf!.set(pitch: 10)
        lookAtPilotingItf!.set(verticalSpeed: 11)
        timeProvider.lockTime()
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingPcmd(
            flag: 1, roll: 9, pitch: -10, yaw: 0, gaz: 11, timestampandseqnum: seqNrGenerator.nextSequenceNumber()))
        mockNonAckLoop(handle: 1, noAckType: .piloting)
    }
}
