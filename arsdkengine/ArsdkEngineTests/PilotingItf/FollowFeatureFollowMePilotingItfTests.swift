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

class FollowFeatureFollowMePilotingItfTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var followMePilotingItf: FollowMePilotingItf?
    var followMePilotingItfRef: Ref<FollowMePilotingItf>?
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
        mockArsdkCore.addDevice(
            "123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1", handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        followMePilotingItfRef = drone.getPilotingItf(PilotingItfs.followMe) { [unowned self] pilotingItf in
            self.followMePilotingItf = pilotingItf
            self.changeCnt += 1
        }

        manualCopterPilotingItfRef = drone.getPilotingItf(PilotingItfs.manualCopter) { [unowned self] pilotingItf in
            self.manualCopterPilotingItf = pilotingItf
        }

        changeCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected and not known
        assertThat(followMePilotingItf, `is`(nilValue()))

        // connect the drone, piloting interface should be published
        connect(drone: drone, handle: 1)
        assertThat(followMePilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        assertThat(followMePilotingItf!.state, `is`(.unavailable))

        // disconnect drone
        disconnect(drone: drone, handle: 1)
        assertThat(followMePilotingItf, nilValue())
        assertThat(changeCnt, `is`(2)) // should have been unactivated and deactivated
    }

    func testFollowMeActivation() {

        connect(drone: drone, handle: 1) {
            // Missing image detection
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.followMeModeInfoEncoder(
                    mode: .geographic, missingRequirementsBitField: self.missingImageBitfield,
                    improvementsBitField: self.emptyBitfield))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.followMeModeInfoEncoder(
                    mode: .relative, missingRequirementsBitField: self.missingImageBitfield,
                    improvementsBitField: self.emptyBitfield))
        }
        assertThat(followMePilotingItf, `is`(present()))
        // always in geograhic (the defaut mode)
        assertThat(followMePilotingItf?.followMode, presentAnd(allOf(`is`(.geographic), isUpToDate())))
        assertThat(changeCnt, `is`(1))
        assertThat(followMePilotingItf!.state, `is`(.unavailable))
        assertThat(followMePilotingItf!.availabilityIssues, `is`(issueImageAndNotFlying))

        // flying
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))

        assertThat(followMePilotingItf!.state, `is`(.unavailable))
        assertThat(followMePilotingItf!.availabilityIssues, `is`(issuesSetImage))
        assertThat(changeCnt, `is`(2))

        // ready for FollowMe
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .geographic, missingRequirementsBitField: emptyBitfield, improvementsBitField: emptyBitfield))
        // allways unavailable (because there is still missig requirement in .relative mode
        assertThat(followMePilotingItf!.state, `is`(.unavailable))
        assertThat(changeCnt, `is`(2))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .relative, missingRequirementsBitField: emptyBitfield, improvementsBitField: emptyBitfield))
        // now it is "OK"
        assertThat(followMePilotingItf!.state, `is`(.idle))
        assertThat(followMePilotingItf!.availabilityIssues, `is`(issuesEmptySet))
        assertThat(followMePilotingItf!.qualityIssues, `is`(issuesEmptySet))
        assertThat(changeCnt, `is`(3))

        // Target is Too Close (quality issue)
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .geographic, missingRequirementsBitField: emptyBitfield,
                improvementsBitField: targetTooCloseBitfield))
        assertThat(followMePilotingItf!.state, `is`(.idle))
        assertThat(followMePilotingItf!.availabilityIssues, `is`(issuesEmptySet))
        assertThat(followMePilotingItf!.qualityIssues, `is`(issuesSetTooClose))
        assertThat(changeCnt, `is`(4))

        // activate
        assertThat(followMePilotingItf?.followMode, presentAnd(allOf(`is`(.geographic), isUpToDate())))
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeStart(mode: .geographic))
        _ = followMePilotingItf?.activate()
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeStateEncoder(
                mode: .geographic, behavior: .lookAt, animation: .none, animationAvailableBitField: 0))

        assertThat(followMePilotingItf!.state, `is`(.active))
        assertThat(followMePilotingItf?.followMode, presentAnd(allOf(`is`(.geographic), isUpToDate())))
        assertThat(followMePilotingItf!.availabilityIssues, `is`(issuesEmptySet))
        assertThat(followMePilotingItf!.qualityIssues, `is`(issuesSetTooClose))
        assertThat(changeCnt, `is`(5))

        // no quality issue
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .geographic, missingRequirementsBitField: emptyBitfield, improvementsBitField: emptyBitfield))
        assertThat(followMePilotingItf!.state, `is`(.active))
        assertThat(followMePilotingItf!.availabilityIssues, `is`(issuesEmptySet))
        assertThat(followMePilotingItf!.qualityIssues, `is`(issuesEmptySet))
        assertThat(changeCnt, `is`(6))

        // deactivate
         expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeStop())
        _ = followMePilotingItf?.deactivate()
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeStateEncoder(
                mode: .none, behavior: .lookAt, animation: .none, animationAvailableBitField: 0))
        assertThat(followMePilotingItf!.state, `is`(.idle))
        assertThat(followMePilotingItf!.availabilityIssues, `is`(issuesEmptySet))
        assertThat(followMePilotingItf!.qualityIssues, `is`(issuesEmptySet))
        assertThat(followMePilotingItf?.followMode, presentAnd(allOf(`is`(.geographic), isUpToDate())))
        assertThat(changeCnt, `is`(7))

        // unavailability (image problem)
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .geographic, missingRequirementsBitField: missingImageBitfield,
                improvementsBitField: emptyBitfield))
        assertThat(followMePilotingItf!.state, `is`(.unavailable))
        assertThat(followMePilotingItf!.availabilityIssues, `is`(issuesSetImage))
        assertThat(followMePilotingItf!.qualityIssues, `is`(issuesEmptySet))
        assertThat(changeCnt, `is`(8))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
            mode: .geographic,
            missingRequirementsBitField: ~(Bitfield<ArsdkFeatureFollowMeInput>.of(.droneCloseEnough)),
            improvementsBitField: emptyBitfield))

        assertThat(followMePilotingItf!.state, `is`(.unavailable))
        assertThat(followMePilotingItf!.availabilityIssues, `is`([.droneTooFarFromTarget]))

        assertThat(changeCnt, `is`(9))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
            mode: .geographic,
            missingRequirementsBitField: ~(Bitfield<ArsdkFeatureFollowMeInput>.of(.targetGoodSpeed)),
            improvementsBitField: emptyBitfield))

        assertThat(followMePilotingItf!.availabilityIssues, `is`([.targetHorizontalSpeedKO, .targetVerticalSpeedKO]))

        assertThat(changeCnt, `is`(10))
    }

    func testFollowMeAndPilot() {

        let seqNrGenerator = PilotingCommand.Encoder.AnafiCopter()
        let timeProvider = MockTimeProvider()
        TimeProvider.instance = timeProvider

        connect(drone: drone, handle: 1)
        assertThat(followMePilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // flying and ready
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .geographic, missingRequirementsBitField: emptyBitfield, improvementsBitField: emptyBitfield))
        assertThat(followMePilotingItf!.state, `is`(.idle))
        assertThat(followMePilotingItf!.availabilityIssues, `is`(issuesEmptySet))
        assertThat(changeCnt, `is`(2))

        // activate
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeStart(mode: .geographic))
        _ = followMePilotingItf?.activate()
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeStateEncoder(
                mode: .geographic, behavior: .lookAt, animation: .none, animationAvailableBitField: 0))

        assertThat(followMePilotingItf!.state, `is`(.active))
        assertThat(followMePilotingItf!.availabilityIssues, `is`(issuesEmptySet))
        assertThat(followMePilotingItf!.qualityIssues, `is`(issuesEmptySet))
        assertThat(changeCnt, `is`(3))

        // Send piloting commands
        timeProvider.lockTime()
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingPcmd(
            flag: 0, roll: 0, pitch: 0, yaw: 0, gaz: 0, timestampandseqnum: seqNrGenerator.nextSequenceNumber()))
        mockNonAckLoop(handle: 1, noAckType: .piloting)

        // Update pcmd value
        followMePilotingItf!.set(roll: 2)
        followMePilotingItf!.set(pitch: 4)
        followMePilotingItf!.set(verticalSpeed: 8)
        timeProvider.lockTime()
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingPcmd(
            flag: 1, roll: 2, pitch: -4, yaw: 0, gaz: 8, timestampandseqnum: seqNrGenerator.nextSequenceNumber()))
        mockNonAckLoop(handle: 1, noAckType: .piloting)

        // deactivate
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeStop())
        _ = followMePilotingItf?.deactivate()
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeStateEncoder(
                mode: .none, behavior: .lookAt, animation: .none, animationAvailableBitField: 0))
        assertThat(followMePilotingItf!.state, `is`(.idle))
        assertThat(followMePilotingItf!.availabilityIssues, `is`(issuesEmptySet))
        assertThat(followMePilotingItf!.qualityIssues, `is`(issuesEmptySet))
        assertThat(changeCnt, `is`(4))

        // Landed and state unavailable
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(followMePilotingItf!.state, `is`(.unavailable))
        assertThat(changeCnt, `is`(5))
    }

    func testFollowMeOkButNotFlying() {

        connect(drone: drone, handle: 1)
        assertThat(followMePilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // FollowMe ready AND not flying
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .geographic, missingRequirementsBitField: emptyBitfield, improvementsBitField: emptyBitfield))
        assertThat(followMePilotingItf!.state, `is`(.unavailable))
        assertThat(followMePilotingItf!.availabilityIssues, `is`(issueSetNotFlying))
        assertThat(changeCnt, `is`(1))

        // flying -> Should be .idle
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        assertThat(followMePilotingItf!.state, `is`(.idle))
        assertThat(followMePilotingItf!.availabilityIssues, `is`(issuesEmptySet))
        assertThat(followMePilotingItf!.qualityIssues, `is`(issuesEmptySet))
        assertThat(changeCnt, `is`(2))

        // Landed and state unavailable
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(followMePilotingItf!.state, `is`(.unavailable))
        assertThat(changeCnt, `is`(3))
    }

    func testUnionBitfields() {
        let setABitfield: UInt = ~(Bitfield<ArsdkFeatureFollowMeInput>.of(.imageDetection, .droneFarEnough))
        let setBBitfield: UInt = ~(Bitfield<ArsdkFeatureFollowMeInput>.of(.droneGpsGoodAccuracy, .droneFarEnough,
                                                                          .droneCalibrated))
        let issuesSetA: Set<TrackingIssue> = [.targetDetectionInfoMissing, .droneTooCloseToTarget]
        let issuesSetB: Set<TrackingIssue> = [.droneGpsInfoInaccurate, .droneTooCloseToTarget, .droneNotCalibrated]
        let issuesSetAandB: Set<TrackingIssue> = issuesSetA.union(issuesSetB)

        connect(drone: drone, handle: 1) {
            // flying
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        }
        assertThat(followMePilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))
        assertThat(followMePilotingItf!.availabilityIssues, `is`(issuesEmptySet))

        // A + A
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .relative, missingRequirementsBitField: setABitfield, improvementsBitField: emptyBitfield))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .geographic, missingRequirementsBitField: setABitfield, improvementsBitField: emptyBitfield))
        assertThat(changeCnt, `is`(2))
        assertThat(followMePilotingItf!.availabilityIssues, `is`(issuesSetA))

        // A + B
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .geographic, missingRequirementsBitField: setBBitfield, improvementsBitField: emptyBitfield))
        assertThat(changeCnt, `is`(3))
        assertThat(followMePilotingItf!.availabilityIssues, `is`(issuesSetAandB))

        // remove A
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .relative, missingRequirementsBitField: emptyBitfield, improvementsBitField: emptyBitfield))
        assertThat(changeCnt, `is`(4))
        assertThat(followMePilotingItf!.availabilityIssues, `is`(issuesSetB))

        // remove B
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .geographic, missingRequirementsBitField: emptyBitfield, improvementsBitField: emptyBitfield))
        assertThat(changeCnt, `is`(5))
        assertThat(followMePilotingItf!.availabilityIssues, `is`(issuesEmptySet))

        // A + B in Quality
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .relative, missingRequirementsBitField: emptyBitfield, improvementsBitField: setABitfield))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .geographic, missingRequirementsBitField: emptyBitfield, improvementsBitField: setBBitfield))
        assertThat(changeCnt, `is`(7))
        assertThat(followMePilotingItf!.qualityIssues, `is`(issuesSetAandB))
        assertThat(followMePilotingItf!.availabilityIssues, `is`(issuesEmptySet))

        // B in requirements
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .relative, missingRequirementsBitField: setBBitfield, improvementsBitField: setABitfield))
        assertThat(changeCnt, `is`(8))
        assertThat(followMePilotingItf!.qualityIssues, `is`(issuesSetAandB))
        assertThat(followMePilotingItf!.availabilityIssues, `is`(issuesSetB))

        // missing in an other mode (lookAt) -> no change
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .lookAt, missingRequirementsBitField: setABitfield, improvementsBitField: setBBitfield))
        assertThat(changeCnt, `is`(8))
        assertThat(followMePilotingItf!.qualityIssues, `is`(issuesSetAandB))
        assertThat(followMePilotingItf!.availabilityIssues, `is`(issuesSetB))
    }

    func testChangeMode() {

        connect(drone: drone, handle: 1) {
            // flying
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
            // receive mode infos to have all modes supported
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .geographic, missingRequirementsBitField: self.emptyBitfield,
                improvementsBitField: self.emptyBitfield))
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .relative, missingRequirementsBitField: self.emptyBitfield,
                improvementsBitField: self.emptyBitfield))
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .leash, missingRequirementsBitField: self.emptyBitfield,
                improvementsBitField: self.emptyBitfield))
        }

        assertThat(followMePilotingItf, `is`(present()))
        // always in geograhic (the defaut mode)
        assertThat(followMePilotingItf?.followMode, presentAnd(allOf(`is`(.geographic), isUpToDate())))
        assertThat(changeCnt, `is`(1))
        assertThat(followMePilotingItf!.state, `is`(.idle))

        followMePilotingItf!.followMode.value = .relative
        assertThat(followMePilotingItf?.followMode, presentAnd(allOf(`is`(.relative), isUpToDate())))
        assertThat(changeCnt, `is`(2))

        // activate
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeStart(mode: .relative))
        _ = followMePilotingItf?.activate()
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeStateEncoder(
                mode: .relative, behavior: .follow, animation: .none, animationAvailableBitField: 0))
        assertThat(followMePilotingItf!.state, `is`(.active))
        assertThat(followMePilotingItf?.followMode, presentAnd(allOf(`is`(.relative), isUpToDate())))
        assertThat(changeCnt, `is`(3))

        // change to the same value
        followMePilotingItf!.followMode.value = .relative
        assertThat(followMePilotingItf!.state, `is`(.active))
        assertThat(followMePilotingItf?.followMode, presentAnd(allOf(`is`(.relative), isUpToDate())))
        assertThat(changeCnt, `is`(3))

        // switch to geographic
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeStart(mode: .geographic))
        followMePilotingItf!.followMode.value = .geographic

        assertThat(followMePilotingItf!.state, `is`(.active))
        assertThat(followMePilotingItf?.followMode, presentAnd(allOf(`is`(.geographic), isUpdating())))
        assertThat(changeCnt, `is`(4))

        // drone is in geographic mode
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeStateEncoder(
                mode: .geographic, behavior: .follow, animation: .none, animationAvailableBitField: 0))
        assertThat(followMePilotingItf!.state, `is`(.active))
        assertThat(followMePilotingItf?.followMode, presentAnd(allOf(`is`(.geographic), isUpToDate())))
        assertThat(changeCnt, `is`(5))

        // switch to leash
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeStart(mode: .leash))
        followMePilotingItf!.followMode.value = .leash

        assertThat(followMePilotingItf!.state, `is`(.active))
        assertThat(followMePilotingItf?.followMode, presentAnd(allOf(`is`(.leash), isUpdating())))
        assertThat(changeCnt, `is`(6))

        // drone is in geographic mode
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeStateEncoder(
                mode: .leash, behavior: .follow, animation: .none, animationAvailableBitField: 0))
        assertThat(followMePilotingItf!.state, `is`(.active))
        assertThat(followMePilotingItf?.followMode, presentAnd(allOf(`is`(.leash), isUpToDate())))
        assertThat(changeCnt, `is`(7))
    }

    func testSupportedModes() {
        connect(drone: drone, handle: 1) {
            // flying
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
            // receive mode infos to have all modes supported
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .geographic, missingRequirementsBitField: self.targetTooCloseBitfield,
                improvementsBitField: self.emptyBitfield))
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.followMeModeInfoEncoder(
                mode: .relative, missingRequirementsBitField: self.emptyBitfield,
                improvementsBitField: self.emptyBitfield))
        }

        // supported modes should only be geographic and relative
        assertThat(followMePilotingItf!.followMode.supportedModes, containsInAnyOrder(.geographic, .relative))
        assertThat(changeCnt, `is`(1))

        // receiving a new mode after connection will be ignored
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.followMeModeInfoEncoder(
            mode: .leash, missingRequirementsBitField: emptyBitfield,
            improvementsBitField: emptyBitfield))
        assertThat(followMePilotingItf!.followMode.supportedModes, containsInAnyOrder(.geographic, .relative))
        assertThat(changeCnt, `is`(1))
    }

    func testBehavior () {
        connect(drone: drone, handle: 1) {
            // flying and follow (relative)
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.followMeStateEncoder(
                    mode: .relative, behavior: .follow, animation: .none, animationAvailableBitField: 0))
        }

        assertThat(followMePilotingItf!.state, `is`(.active))
        assertThat(followMePilotingItf?.followBehavior, presentAnd(`is`(.following)))
        assertThat(changeCnt, `is`(1))

        // LookAt behavior
        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeStateEncoder(
                mode: .relative, behavior: .lookAt, animation: .none, animationAvailableBitField: 0))
        assertThat(followMePilotingItf!.state, `is`(.active))
        assertThat(followMePilotingItf?.followBehavior, presentAnd(`is`(.stationary)))
        assertThat(changeCnt, `is`(2))

        // LookAt behavior (again -> nochange)
        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeStateEncoder(
                mode: .relative, behavior: .lookAt, animation: .none, animationAvailableBitField: 0))
        assertThat(followMePilotingItf!.state, `is`(.active))
        assertThat(followMePilotingItf?.followBehavior, presentAnd(`is`(.stationary)))
        assertThat(changeCnt, `is`(2))

        // Back to following
        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeStateEncoder(
                mode: .relative, behavior: .follow, animation: .none, animationAvailableBitField: 0))
        assertThat(followMePilotingItf!.state, `is`(.active))
        assertThat(followMePilotingItf?.followBehavior, presentAnd(`is`(.following)))
        assertThat(changeCnt, `is`(3))

        // deactivate
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.followMeStop())
        _ = followMePilotingItf?.deactivate()
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeStateEncoder(
                mode: .none, behavior: .lookAt, animation: .none, animationAvailableBitField: 0))
        assertThat(followMePilotingItf!.state, `is`(.idle))
        assertThat(followMePilotingItf?.followBehavior, nilValue())
        assertThat(changeCnt, `is`(4))
    }

    func testFollowMeAutoSwitchBetweenModes() {

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
                    mode: .relative, behavior: .follow, animation: .none, animationAvailableBitField: 0))
        }
        assertThat(followMePilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))
        assertThat(followMePilotingItf!.state, `is`(.active))

        // Send piloting commands
        timeProvider.lockTime()
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingPcmd(
            flag: 0, roll: 0, pitch: 0, yaw: 0, gaz: 0, timestampandseqnum: seqNrGenerator.nextSequenceNumber()))
        mockNonAckLoop(handle: 1, noAckType: .piloting)
        // Update pcmd value
        followMePilotingItf!.set(roll: 2)
        followMePilotingItf!.set(pitch: 4)
        followMePilotingItf!.set(verticalSpeed: 8)
        timeProvider.lockTime()
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingPcmd(
            flag: 1, roll: 2, pitch: -4, yaw: 0, gaz: 8, timestampandseqnum: seqNrGenerator.nextSequenceNumber()))
        mockNonAckLoop(handle: 1, noAckType: .piloting)

        // the drone is in LookAt
        seqNrGenerator.reset()
        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeStateEncoder(
                mode: .lookAt, behavior: .lookAt, animation: .none, animationAvailableBitField: 0))
        assertThat(changeCnt, `is`(2))
        assertThat(followMePilotingItf!.state, `is`(.idle))

        timeProvider.lockTime()
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingPcmd(
            flag: 0, roll: 0, pitch: 0, yaw: 0, gaz: 0, timestampandseqnum: seqNrGenerator.nextSequenceNumber()))
        mockNonAckLoop(handle: 1, noAckType: .piloting)

        // the drone is back in Follow
        seqNrGenerator.reset()
        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.followMeStateEncoder(
                mode: .relative, behavior: .follow, animation: .none, animationAvailableBitField: 0))
        assertThat(changeCnt, `is`(3))
        assertThat(followMePilotingItf!.state, `is`(.active))

        // Send piloting commands
        timeProvider.lockTime()
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingPcmd(
            flag: 0, roll: 0, pitch: 0, yaw: 0, gaz: 0, timestampandseqnum: seqNrGenerator.nextSequenceNumber()))
        mockNonAckLoop(handle: 1, noAckType: .piloting)
        // Update pcmd value
        followMePilotingItf!.set(roll: 9)
        followMePilotingItf!.set(pitch: 10)
        followMePilotingItf!.set(verticalSpeed: 11)
        timeProvider.lockTime()
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingPcmd(
            flag: 1, roll: 9, pitch: -10, yaw: 0, gaz: 11, timestampandseqnum: seqNrGenerator.nextSequenceNumber()))
        mockNonAckLoop(handle: 1, noAckType: .piloting)
    }
}
