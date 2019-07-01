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

class HttpFlightPlanPilotingItfTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var flightPlanPilotingItf: FlightPlanPilotingItf?
    var flightPlanPilotingItfRef: Ref<FlightPlanPilotingItf>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("456", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone2",
                                handle: 1)
        drone = droneStore.getDevice(uid: "456")!

        flightPlanPilotingItfRef = drone.getPilotingItf(PilotingItfs.flightPlan) { [unowned self] pilotingItf in
                self.flightPlanPilotingItf = pilotingItf
                self.changeCnt += 1
        }
        changeCnt = 0
    }

    func testAvailabilityWithHttpUpload() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonMavlinkstateMavlinkfileplayingstatechangedEncoder(
                    state: .stopped, filepath: "", type: .flightplan))
        }

        // should be unavailable
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
        var task = httpSession.popLastTask() as? MockUploadTask
        assertThat(task, presentAnd(isUploading(fileUrl: URL(fileURLWithPath: "flightPlan1"))))
        assertThat(task, presentAnd(has(api: "/api/v1/upload/flightplan")))

        // progress change should not change anything
        task?.mock(progress: 50)
        assertThat(flightPlanPilotingItf!.state, `is`(.unavailable))
        assertThat(changeCnt, `is`(2))

        // after completion, state should change
        let flightplanUid = "flightplan_unique_id"
        let dataUid = ("\"" + flightplanUid + "\"").data(using: .utf8)

        task?.mockCompletion(statusCode: 200, data: dataUid)
        assertThat(flightPlanPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(3))

        // call upload while idle
        flightPlanPilotingItf!.uploadFlightPlan(filepath: "flightPlan2")

        assertThat(flightPlanPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(4)) // + 1 because upload state has changed
        task = httpSession.popLastTask() as? MockUploadTask
        assertThat(task, presentAnd(isUploading(fileUrl: URL(fileURLWithPath: "flightPlan2"))))
        assertThat(task, presentAnd(has(api: "/api/v1/upload/flightplan")))

        // progress change should not change anything
        task?.mock(progress: 50)
        assertThat(flightPlanPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(4))

        // after completion, state should change
        task?.mockCompletion(statusCode: 404)
        assertThat(flightPlanPilotingItf!.state, `is`(.unavailable))
        assertThat(changeCnt, `is`(5))
    }
}
