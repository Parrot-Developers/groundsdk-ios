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

class CommonFlightPlanPilotingItfTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var flightPlanPilotingItf: FlightPlanPilotingItf?
    var flightPlanPilotingItfRef: Ref<FlightPlanPilotingItf>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        flightPlanPilotingItfRef = drone.getPilotingItf(PilotingItfs.flightPlan) { [unowned self] pilotingItf in
                self.flightPlanPilotingItf = pilotingItf
                self.changeCnt += 1
        }
        changeCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected and not known
        assertThat(flightPlanPilotingItf, `is`(nilValue()))

        // connect the drone, piloting interface should be published
        connect(drone: drone, handle: 1)
        assertThat(flightPlanPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // disconnect drone
        disconnect(drone: drone, handle: 1)
        assertThat(flightPlanPilotingItf, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))

        // forget the drone
        _ = drone.forget()
        assertThat(flightPlanPilotingItf, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testState() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                    state: .stopped, filepath: "", type: .flightplan))
        }

        // should be unavailable by default
        assertThat(flightPlanPilotingItf!.state, `is`(.unavailable))
        assertThat(changeCnt, `is`(1))

        // flight plan available should let the state to unavailable
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonFlightplanstateAvailabilitystatechangedEncoder(availabilitystate: 1))
        assertThat(flightPlanPilotingItf!.state, `is`(.unavailable))
        assertThat(changeCnt, `is`(1))

        flightPlanPilotingItf!.uploadFlightPlan(filepath: "flightPlan1")

        assertThat(flightPlanPilotingItf!.state, `is`(.unavailable))
        assertThat(changeCnt, `is`(2)) // + 1 because upload state has changed
        let task = httpSession.popLastTask() as? MockUploadTask
        assertThat(task, presentAnd(isUploading(fileUrl: URL(fileURLWithPath: "flightPlan1"))))
        assertThat(task, presentAnd(has(api: "/api/v1/upload/flightplan")))

        // after completion, state should change
        let flightplanUid = "flightplan_unique_id"
        let dataUid = ("\"" + flightplanUid + "\"").data(using: .utf8)

        task?.mockCompletion(statusCode: 200, data: dataUid)
        assertThat(flightPlanPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(3))

        // mock drone is telling that the flight plan is unavailable
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonFlightplanstateAvailabilitystatechangedEncoder(availabilitystate: 0))
        assertThat(flightPlanPilotingItf!.state, `is`(.unavailable))
        assertThat(changeCnt, `is`(4))

        // mock drone is telling that the flight plan is available again
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonFlightplanstateAvailabilitystatechangedEncoder(availabilitystate: 1))
        assertThat(flightPlanPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(5))

        // asking to activate the piloting interface should not change anything
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonMavlinkStart(
            filepath: flightplanUid, type: .flightplan))
        var res = flightPlanPilotingItf!.activate(restart: false)

        assertThat(res, `is`(true))
        assertThat(changeCnt, `is`(5))

        // mock answer from the drone that the flight plan has started
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .playing, filepath: flightplanUid, type: .flightplan))
        assertThat(flightPlanPilotingItf!.state, `is`(.active))
        assertThat(changeCnt, `is`(6))

        // deactivate the piloting itf should not change anything
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonMavlinkPause())
        res = flightPlanPilotingItf!.deactivate()

        assertThat(res, `is`(true))
        assertThat(changeCnt, `is`(6))

        // mock answer from the drone that the flight plan has been paused
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .paused, filepath: flightplanUid, type: .flightplan))

        assertThat(flightPlanPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(7))

        // check that receiving a state change from the drone is signaled
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .playing, filepath: flightplanUid, type: .flightplan))
        assertThat(flightPlanPilotingItf!.state, `is`(.active))
        assertThat(changeCnt, `is`(8))
    }

    func testUploadState() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                    state: .stopped, filepath: "", type: .flightplan))
        }

        // upload state should be none by default
        assertThat(flightPlanPilotingItf!.latestUploadState, `is`(.none))
        assertThat(changeCnt, `is`(1))

        flightPlanPilotingItf!.uploadFlightPlan(filepath: "flightPlan1")
        var task = httpSession.popLastTask() as? MockUploadTask

        assertThat(flightPlanPilotingItf!.latestUploadState, `is`(.uploading))
        assertThat(changeCnt, `is`(2))

        // progress should not change anything
        task?.mock(progress: 60)
        assertThat(flightPlanPilotingItf!.latestUploadState, `is`(.uploading))
        assertThat(changeCnt, `is`(2))

        // mock completion successful
        let flightplanUid = "flightplan_unique_id"
        let dataUid = ("\"" + flightplanUid + "\"").data(using: .utf8)

        task?.mockCompletion(statusCode: 200, data: dataUid)
        assertThat(flightPlanPilotingItf!.latestUploadState, `is`(.uploaded))
        assertThat(changeCnt, `is`(3))

        // upload again
        flightPlanPilotingItf!.uploadFlightPlan(filepath: "flightPlan1")
        task = httpSession.popLastTask() as? MockUploadTask

        assertThat(flightPlanPilotingItf!.latestUploadState, `is`(.uploading))
        assertThat(changeCnt, `is`(4))

        // mock completion error
        task?.mockCompletion(statusCode: 400)
        assertThat(flightPlanPilotingItf!.latestUploadState, `is`(.failed))
        assertThat(changeCnt, `is`(5))
    }

    func testLatestMissionItemExecuted() {
        connect(drone: drone, handle: 1)
        // latest mission item executed should be nil by default
        assertThat(flightPlanPilotingItf!.latestMissionItemExecuted, nilValue())
        assertThat(changeCnt, `is`(1))

        // mock reception of latest mission item executed
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.commonMavlinkstateMissionitemexecutedEncoder(idx: 2))

        assertThat(flightPlanPilotingItf!.latestMissionItemExecuted, presentAnd(`is`(2)))
        assertThat(changeCnt, `is`(2))

        // mock reception of latest mission item executed
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.commonMavlinkstateMissionitemexecutedEncoder(idx: 10))

        assertThat(flightPlanPilotingItf!.latestMissionItemExecuted, presentAnd(`is`(10)))
        assertThat(changeCnt, `is`(3))
    }

    func testUnavailabilityReasons() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                    state: .stopped, filepath: "", type: .flightplan))
        }

        // latest mission item executed should be only filled with `.missingFlightPlanFile` reason.
        assertThat(flightPlanPilotingItf!.unavailabilityReasons, containsInAnyOrder(
            .missingFlightPlanFile))
        assertThat(changeCnt, `is`(1))

        mockComponentReception(.calibration, isOk: false)
        assertThat(flightPlanPilotingItf!.unavailabilityReasons, containsInAnyOrder(
            .missingFlightPlanFile, .droneNotCalibrated))
        assertThat(changeCnt, `is`(2))

        mockComponentReception(.gps, isOk: false)
        assertThat(flightPlanPilotingItf!.unavailabilityReasons, containsInAnyOrder(
            .missingFlightPlanFile, .droneNotCalibrated, .droneGpsInfoInacurate))
        assertThat(changeCnt, `is`(3))

        mockComponentReception(.takeoff, isOk: false)
        assertThat(flightPlanPilotingItf!.unavailabilityReasons, containsInAnyOrder(
            .missingFlightPlanFile, .droneNotCalibrated, .droneGpsInfoInacurate, .cannotTakeOff))
        assertThat(changeCnt, `is`(4))

        mockComponentReception(.takeoff, isOk: true)
        assertThat(flightPlanPilotingItf!.unavailabilityReasons, containsInAnyOrder(
            .missingFlightPlanFile, .droneNotCalibrated, .droneGpsInfoInacurate))
        assertThat(changeCnt, `is`(5))

        // uploading a file with success should remove the missingFlightPlanFile reason
        flightPlanPilotingItf!.uploadFlightPlan(filepath: "flightPlan1")
        var task = httpSession.popLastTask() as? MockUploadTask

        assertThat(flightPlanPilotingItf!.unavailabilityReasons, containsInAnyOrder(
            .missingFlightPlanFile, .droneNotCalibrated, .droneGpsInfoInacurate))
        assertThat(changeCnt, `is`(6)) // +1 because upload state changed

        // mock completion successful
        let flightplanUid = "flightplan_unique_id"
        let dataUid = ("\"" + flightplanUid + "\"").data(using: .utf8)

        task?.mockCompletion(statusCode: 200, data: dataUid)
        assertThat(flightPlanPilotingItf!.unavailabilityReasons, containsInAnyOrder(
            .droneNotCalibrated, .droneGpsInfoInacurate))
        assertThat(changeCnt, `is`(7))

        // upload again
        flightPlanPilotingItf!.uploadFlightPlan(filepath: "flightPlan1")
        task = httpSession.popLastTask() as? MockUploadTask

        assertThat(flightPlanPilotingItf!.unavailabilityReasons, containsInAnyOrder(
            .droneNotCalibrated, .droneGpsInfoInacurate))
        assertThat(changeCnt, `is`(8)) // +1 because upload state changed

        // mock completion error
        task?.mockCompletion(statusCode: 400)
        assertThat(flightPlanPilotingItf!.unavailabilityReasons, containsInAnyOrder(
            .missingFlightPlanFile, .droneNotCalibrated, .droneGpsInfoInacurate))
        assertThat(changeCnt, `is`(9))

        // check that if the state becomes available, all other reasons are erased
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonFlightplanstateAvailabilitystatechangedEncoder(availabilitystate: 1))
        assertThat(flightPlanPilotingItf!.state, `is`(.unavailable))
        assertThat(flightPlanPilotingItf!.unavailabilityReasons, containsInAnyOrder(.missingFlightPlanFile))
        assertThat(changeCnt, `is`(10))

        // check that if the drone says that it is currently doing a flight plan, all reasons are empty
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .playing, filepath: "unknow_flightplan", type: .flightplan))
        assertThat(flightPlanPilotingItf!.unavailabilityReasons, empty())
        assertThat(changeCnt, `is`(11))

        // back to paused, missingFlightPlanFile should be in the reasons
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .paused, filepath: "unknow_flightplan", type: .flightplan))
        assertThat(flightPlanPilotingItf!.unavailabilityReasons, containsInAnyOrder(.missingFlightPlanFile))
        assertThat(changeCnt, `is`(12))

        // upload a file
        // expect a stop, to stop previous flightplan
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonMavlinkStop())
        flightPlanPilotingItf!.uploadFlightPlan(filepath: "flightPlan1")

        // mock reception of the stop
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .stopped, filepath: "unknow_flightplan", type: .flightplan))

        assertThat(flightPlanPilotingItf!.unavailabilityReasons, containsInAnyOrder(.missingFlightPlanFile))
        assertThat(changeCnt, `is`(14)) // state and upload state changed

        // mock completion successful
        task = httpSession.popLastTask() as? MockUploadTask
        task?.mockCompletion(statusCode: 200, data: dataUid)
        assertThat(flightPlanPilotingItf!.unavailabilityReasons, empty())
        assertThat(changeCnt, `is`(15))
    }

    func testLatestActivationError() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                    state: .stopped, filepath: "", type: .flightplan))
        }

        // should be none by default
        assertThat(flightPlanPilotingItf!.latestActivationError, `is`(.none))
        assertThat(changeCnt, `is`(1))

        // mock flight plan available
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonFlightplanstateAvailabilitystatechangedEncoder(availabilitystate: 1))
        flightPlanPilotingItf!.uploadFlightPlan(filepath: "flightPlan1")
        let task = httpSession.popLastTask() as? MockUploadTask
        assertThat(task, presentAnd(isUploading(fileUrl: URL(fileURLWithPath: "flightPlan1"))))
        assertThat(task, presentAnd(has(api: "/api/v1/upload/flightplan")))
        let flightplanUid = "flightplan_unique_id"
        let dataUid = ("\"" + flightplanUid + "\"").data(using: .utf8)
        task?.mockCompletion(statusCode: 200, data: dataUid)
        assertThat(flightPlanPilotingItf!.state, `is`(.idle))
        assertThat(flightPlanPilotingItf!.latestActivationError, `is`(.none))
        assertThat(changeCnt, `is`(3))

        // activate the piloting interface should not change anything
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonMavlinkStart(
            filepath: flightplanUid, type: .flightplan))
        _ = flightPlanPilotingItf?.activate(restart: false)

        assertThat(flightPlanPilotingItf!.latestActivationError, `is`(.none))
        assertThat(changeCnt, `is`(3))

        // mock reception of an activation error
        mockComponentReception(.mavlinkFile, isOk: false)

        assertThat(flightPlanPilotingItf!.latestActivationError, `is`(.incorrectFlightPlanFile))
        assertThat(changeCnt, `is`(4))

        // mock reception of an other activation error
        mockComponentReception(.waypointsbeyondgeofence, isOk: false)

        assertThat(flightPlanPilotingItf!.latestActivationError, `is`(.waypointBeyondGeofence))
        assertThat(changeCnt, `is`(5))

        // check that calling activate immediately removes the latest activation error
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonMavlinkStart(
            filepath: flightplanUid, type: .flightplan))
        _ = flightPlanPilotingItf?.activate(restart: false)

        assertThat(flightPlanPilotingItf!.latestActivationError, `is`(.none))
        assertThat(changeCnt, `is`(6))

        // mock reception of an activation error
        mockComponentReception(.mavlinkFile, isOk: false)

        assertThat(flightPlanPilotingItf!.latestActivationError, `is`(.incorrectFlightPlanFile))
        assertThat(changeCnt, `is`(7))

        // check that receiving the current activation error as no longer active removes the current activation error
        mockComponentReception(.mavlinkFile, isOk: true)

        assertThat(flightPlanPilotingItf!.latestActivationError, `is`(.none))
        assertThat(changeCnt, `is`(8))
    }

    func testFightPlanFileIsKnown() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                    state: .stopped, filepath: "", type: .flightplan))
        }

        // upload state should be none by default
        assertThat(flightPlanPilotingItf!.flightPlanFileIsKnown, `is`(false))
        assertThat(changeCnt, `is`(1))

        flightPlanPilotingItf!.uploadFlightPlan(filepath: "flightPlan1")
        var task = httpSession.popLastTask() as? MockUploadTask

        assertThat(flightPlanPilotingItf!.flightPlanFileIsKnown, `is`(false))
        assertThat(changeCnt, `is`(2)) // +1 for upload state

        // mock completion successful
        let flightplanUid = "flightplan_unique_id"
        let dataUid = ("\"" + flightplanUid + "\"").data(using: .utf8)

        task?.mockCompletion(statusCode: 200, data: dataUid)
        assertThat(flightPlanPilotingItf!.flightPlanFileIsKnown, `is`(true))
        assertThat(changeCnt, `is`(3))

        // upload again
        flightPlanPilotingItf!.uploadFlightPlan(filepath: "flightPlan1")
        task = httpSession.popLastTask() as? MockUploadTask

        assertThat(flightPlanPilotingItf!.flightPlanFileIsKnown, `is`(true))
        assertThat(changeCnt, `is`(4)) // +1 for upload state

        // mock completion error
        task?.mockCompletion(statusCode: 400)
        assertThat(flightPlanPilotingItf!.flightPlanFileIsKnown, `is`(false))
        assertThat(changeCnt, `is`(5))

        // upload again to have flightPlanIsKnown set to `true`
        flightPlanPilotingItf!.uploadFlightPlan(filepath: "flightPlan1")
        task = httpSession.popLastTask() as? MockUploadTask

        assertThat(flightPlanPilotingItf!.flightPlanFileIsKnown, `is`(false))
        assertThat(changeCnt, `is`(6)) // +1 for upload state

        task?.mockCompletion(statusCode: 200, data: dataUid)
        assertThat(flightPlanPilotingItf!.flightPlanFileIsKnown, `is`(true))
        assertThat(changeCnt, `is`(7))

        // mock that the drone is playing an unknown flight plan
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .playing, filepath: "unknow_flightplan", type: .flightplan))
        assertThat(flightPlanPilotingItf!.flightPlanFileIsKnown, `is`(false))
        assertThat(changeCnt, `is`(8))
    }

    func testPauseResumeRestart() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                    state: .stopped, filepath: "", type: .flightplan))
        }

        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(changeCnt, `is`(1))

        // mock flight plan available
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonFlightplanstateAvailabilitystatechangedEncoder(availabilitystate: 1))
        flightPlanPilotingItf!.uploadFlightPlan(filepath: "flightPlan1")
        let task = httpSession.popLastTask() as? MockUploadTask
        assertThat(task, presentAnd(isUploading(fileUrl: URL(fileURLWithPath: "flightPlan1"))))
        assertThat(task, presentAnd(has(api: "/api/v1/upload/flightplan")))
        let flightplanUid = "flightplan_unique_id"
        let dataUid = ("\"" + flightplanUid + "\"").data(using: .utf8)
        task?.mockCompletion(statusCode: 200, data: dataUid)
        assertThat(flightPlanPilotingItf!.state, `is`(.idle))
        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(changeCnt, `is`(3))

        // check that trying to restart the flight plan when not pause only plays it
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonMavlinkStart(
            filepath: flightplanUid, type: .flightplan))
        _ = flightPlanPilotingItf?.activate(restart: true)

        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(changeCnt, `is`(3))

        // mock flight plan activated
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .playing, filepath: flightplanUid, type: .flightplan))

        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(changeCnt, `is`(4)) // +1 for state change

        // deactivate (should not change state for the moment)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonMavlinkPause())
        _ = flightPlanPilotingItf?.deactivate()

        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(changeCnt, `is`(4))

        // mock reception of paused state
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .paused, filepath: flightplanUid, type: .flightplan))

        assertThat(flightPlanPilotingItf!.isPaused, `is`(true))
        assertThat(changeCnt, `is`(5))

        // resume when paused
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonMavlinkStart(
            filepath: flightplanUid, type: .flightplan))
        _ = flightPlanPilotingItf?.activate(restart: false)

        assertThat(flightPlanPilotingItf!.isPaused, `is`(true))
        assertThat(changeCnt, `is`(5))

        // mock flight plan activated
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .playing, filepath: flightplanUid, type: .flightplan))
        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(changeCnt, `is`(6))

        // mock reception of paused state
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .paused, filepath: flightplanUid, type: .flightplan))

        assertThat(flightPlanPilotingItf!.isPaused, `is`(true))
        assertThat(changeCnt, `is`(7))

        // restart when paused
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonMavlinkStop())
        _ = flightPlanPilotingItf?.activate(restart: true)

        assertThat(flightPlanPilotingItf!.isPaused, `is`(true))
        assertThat(changeCnt, `is`(7))

        // mock reception of stopped state (should trigger a start)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonMavlinkStart(
            filepath: flightplanUid, type: .flightplan))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .stopped, filepath: flightplanUid, type: .flightplan))

        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(changeCnt, `is`(8))

        // mock flight plan activated
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .playing, filepath: flightplanUid, type: .flightplan))
        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(changeCnt, `is`(9))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .paused, filepath: flightplanUid, type: .flightplan))

        assertThat(flightPlanPilotingItf!.isPaused, `is`(true))
        assertThat(changeCnt, `is`(10))

        // mock reception of stopped state
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .stopped, filepath: flightplanUid, type: .flightplan))

        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(flightPlanPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(11))

        // check that trying to restart a flight plan that is stopped with the same file works
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonMavlinkStart(
            filepath: flightplanUid, type: .flightplan))
        var activationResult = flightPlanPilotingItf!.activate(restart: true)
        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(activationResult, `is`(true))
        assertThat(changeCnt, `is`(11))

        // mock reception of stopped state of an unknown file
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .stopped, filepath: "unknown_plan", type: .flightplan))

        // check that trying to restart a flight plan when not available immedialty returns false
        activationResult = flightPlanPilotingItf!.activate(restart: true)
        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(flightPlanPilotingItf!.state, `is`(.unavailable))
        assertThat(activationResult, `is`(false))
    }

    func testIsPausedAfterUpload() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                    state: .stopped, filepath: "", type: .flightplan))
        }

        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(changeCnt, `is`(1))

        // mock flight plan available
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonFlightplanstateAvailabilitystatechangedEncoder(availabilitystate: 1))
        flightPlanPilotingItf!.uploadFlightPlan(filepath: "flightPlan1")
        var task = httpSession.popLastTask() as? MockUploadTask
        assertThat(task, presentAnd(isUploading(fileUrl: URL(fileURLWithPath: "flightPlan1"))))
        assertThat(task, presentAnd(has(api: "/api/v1/upload/flightplan")))
        let flightplanUid1 = "flightplan_unique_id_1"
        var dataUid = ("\"" + flightplanUid1 + "\"").data(using: .utf8)
        task?.mockCompletion(statusCode: 200, data: dataUid)
        assertThat(flightPlanPilotingItf!.state, `is`(.idle))
        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(changeCnt, `is`(3))

        // start the flight plan
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonMavlinkStart(
            filepath: flightplanUid1, type: .flightplan))
        _ = flightPlanPilotingItf?.activate(restart: false)

        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(changeCnt, `is`(3))

        // mock flight plan activated
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .playing, filepath: flightplanUid1, type: .flightplan))

        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(flightPlanPilotingItf!.state, `is`(.active))
        assertThat(changeCnt, `is`(4)) // +1 for state change

        // mock reception of paused state
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .paused, filepath: flightplanUid1, type: .flightplan))

        assertThat(flightPlanPilotingItf!.isPaused, `is`(true))
        assertThat(flightPlanPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(5))

        // upload a new flight plan
        // expect a stop, to stop previous flightplan
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonMavlinkStop())
        flightPlanPilotingItf!.uploadFlightPlan(filepath: "flightPlan2")

        // mock reception of the stop
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .stopped, filepath: flightplanUid1, type: .flightplan))

        assertThat(changeCnt, `is`(6)) // latestUploadState has been changed
        task = httpSession.popLastTask() as? MockUploadTask
        assertThat(task, presentAnd(isUploading(fileUrl: URL(fileURLWithPath: "flightPlan2"))))
        assertThat(task, presentAnd(has(api: "/api/v1/upload/flightplan")))
        let flightplanUid2 = "flightplan_unique_id_2"
        dataUid = ("\"" + flightplanUid2 + "\"").data(using: .utf8)
        task?.mockCompletion(statusCode: 200, data: dataUid)
        assertThat(flightPlanPilotingItf!.state, `is`(.idle))
        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(changeCnt, `is`(7))

        // start the flight plan
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonMavlinkStart(
            filepath: flightplanUid2, type: .flightplan))
        _ = flightPlanPilotingItf?.activate(restart: false)

        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(changeCnt, `is`(7))

        // mock flight plan activated
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .playing, filepath: flightplanUid2, type: .flightplan))

        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(flightPlanPilotingItf!.state, `is`(.active))
        assertThat(changeCnt, `is`(8))

        // upload a new flight plan
        // expect a stop, to stop previous flightplan
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonMavlinkStop())
        flightPlanPilotingItf!.uploadFlightPlan(filepath: "flightPlan3")

        assertThat(flightPlanPilotingItf!.latestUploadState, `is`(.uploading))
        assertThat(changeCnt, `is`(9)) // state idle

        // mock reception of the stop
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .stopped, filepath: flightplanUid2, type: .flightplan))

        assertThat(flightPlanPilotingItf!.state, `is`(.idle))
        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(flightPlanPilotingItf!.latestUploadState, `is`(.uploading))
        assertThat(changeCnt, `is`(10)) // latestUploadState has been changed

        task = httpSession.popLastTask() as? MockUploadTask
        assertThat(task, presentAnd(isUploading(fileUrl: URL(fileURLWithPath: "flightPlan3"))))
        assertThat(task, presentAnd(has(api: "/api/v1/upload/flightplan")))
        let flightplanUid3 = "flightplan_unique_id_3"
        dataUid = ("\"" + flightplanUid3 + "\"").data(using: .utf8)

        task?.mockCompletion(statusCode: 200, data: dataUid)
        assertThat(flightPlanPilotingItf!.state, `is`(.idle))
        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(flightPlanPilotingItf!.latestUploadState, `is`(.uploaded))
        assertThat(changeCnt, `is`(11))

    }

    func testUploadSameFlightplan() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                    state: .stopped, filepath: "", type: .flightplan))
        }

        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(changeCnt, `is`(1))

        // mock flight plan available
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonFlightplanstateAvailabilitystatechangedEncoder(availabilitystate: 1))
        flightPlanPilotingItf!.uploadFlightPlan(filepath: "flightPlan1")
        var task = httpSession.popLastTask() as? MockUploadTask
        assertThat(task, presentAnd(isUploading(fileUrl: URL(fileURLWithPath: "flightPlan1"))))
        assertThat(task, presentAnd(has(api: "/api/v1/upload/flightplan")))
        let flightplanUid = "flightplan_unique_id"
        let dataUid = ("\"" + flightplanUid + "\"").data(using: .utf8)
        task?.mockCompletion(statusCode: 200, data: dataUid)
        assertThat(flightPlanPilotingItf!.state, `is`(.idle))
        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(changeCnt, `is`(3))

        // start the flight plan
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonMavlinkStart(
            filepath: flightplanUid, type: .flightplan))
        _ = flightPlanPilotingItf?.activate(restart: false)

        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(changeCnt, `is`(3))

        // mock flight plan activated
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .playing, filepath: flightplanUid, type: .flightplan))

        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(flightPlanPilotingItf!.state, `is`(.active))
        assertThat(changeCnt, `is`(4)) // +1 for state change

        // mock reception of paused state
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .paused, filepath: flightplanUid, type: .flightplan))

        assertThat(flightPlanPilotingItf!.isPaused, `is`(true))
        assertThat(flightPlanPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(5))

        // upload the same flight plan
        // expect a stop, to stop previous flightplan
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonMavlinkStop())
        flightPlanPilotingItf!.uploadFlightPlan(filepath: "flightPlan1")

        // mock reception of the stop
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .stopped, filepath: flightplanUid, type: .flightplan))

        assertThat(changeCnt, `is`(6)) // latestUploadState has been changed
        task = httpSession.popLastTask() as? MockUploadTask
        assertThat(task, presentAnd(isUploading(fileUrl: URL(fileURLWithPath: "flightPlan1"))))
        assertThat(task, presentAnd(has(api: "/api/v1/upload/flightplan")))
        task?.mockCompletion(statusCode: 200, data: dataUid)
        assertThat(flightPlanPilotingItf!.state, `is`(.idle))
        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(changeCnt, `is`(7)) // latestUploadState has been changed

        // restart the flight plan
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonMavlinkStart(
            filepath: flightplanUid, type: .flightplan))
        _ = flightPlanPilotingItf?.activate(restart: true)

        assertThat(flightPlanPilotingItf!.state, `is`(.idle))
        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(changeCnt, `is`(7))

        // mock reception of playoing state
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                state: .playing, filepath: flightplanUid, type: .flightplan))

        assertThat(flightPlanPilotingItf!.state, `is`(.active))
        assertThat(flightPlanPilotingItf!.isPaused, `is`(false))
        assertThat(changeCnt, `is`(8))
    }

    private func mockComponentReception(
        _ component: ArsdkFeatureCommonFlightplanstateComponentstatelistchangedComponent, isOk: Bool) {

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.commonFlightplanstateComponentstatelistchangedEncoder(
            component: component, state: isOk ? 1 : 0))
    }
}
