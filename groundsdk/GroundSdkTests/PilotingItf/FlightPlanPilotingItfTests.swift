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

import XCTest
@testable import GroundSdk

/// Test FlightPlan piloting interface
class FlightPlanPilotingItfTest: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: FlightPlanPilotingItfCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = FlightPlanPilotingItfCore(store: store, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store.get(PilotingItfs.flightPlan), present())
        impl.unpublish()
        assertThat(store.get(PilotingItfs.flightPlan), nilValue())
    }

    func testActivation() {
        impl.publish()
        var cnt = 0
        let flightPlan = store.get(PilotingItfs.flightPlan)!
        _ = store.register(desc: PilotingItfs.flightPlan) {
            cnt += 1
        }

        assertThat(flightPlan.state, `is`(.unavailable))
        // when state is unavailable, backend should not be called
        var res = flightPlan.activate(restart: true)
        assertThat(res, `is`(false))
        assertThat(backend.activateCalled, `is`(false))
        assertThat(backend.activateRestart, `is`(false))

        res = flightPlan.activate(restart: false)
        assertThat(res, `is`(false))
        assertThat(backend.activateCalled, `is`(false))
        assertThat(backend.activateRestart, `is`(false))

        // mock state is idle
        impl.update(activeState: .idle)

        res = flightPlan.activate(restart: true)
        assertThat(res, `is`(true))
        assertThat(backend.activateCalled, `is`(true))
        assertThat(backend.activateRestart, `is`(true))

        res = flightPlan.activate(restart: false)
        assertThat(res, `is`(true))
        assertThat(backend.activateCalled, `is`(true))
        assertThat(backend.activateRestart, `is`(false))
    }

    func testUploadFile() {
        impl.publish()
        var cnt = 0
        let flightPlan = store.get(PilotingItfs.flightPlan)!
        _ = store.register(desc: PilotingItfs.flightPlan) {
            cnt += 1
        }

        // test initial value
        assertThat(backend.uploadCalled, `is`(false))

        // upload a file
        flightPlan.uploadFlightPlan(filepath: "flightPlan1.mavlink")

        assertThat(cnt, `is`(0)) // should not call the onChange
        assertThat(backend.uploadCalled, `is`(true))
        assertThat(backend.uploadedFilePath, presentAnd(`is`("flightPlan1.mavlink")))
    }

    func testLatestUploadState() {
        impl.publish()
        var cnt = 0
        let flightPlan = store.get(PilotingItfs.flightPlan)!
        _ = store.register(desc: PilotingItfs.flightPlan) {
            cnt += 1
        }

        // test initial value
        assertThat(flightPlan.latestUploadState, `is`(.none))

        // update value
        impl.update(latestUploadState: .uploading).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(flightPlan.latestUploadState, `is`(.uploading))

        // update with same value
        impl.update(latestUploadState: .uploading).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(flightPlan.latestUploadState, `is`(.uploading))

        // update with another value
        impl.update(latestUploadState: .uploaded).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(flightPlan.latestUploadState, `is`(.uploaded))
    }

    func testLatestMissionItemExecuted() {
        impl.publish()
        var cnt = 0
        let flightPlan = store.get(PilotingItfs.flightPlan)!
        _ = store.register(desc: PilotingItfs.flightPlan) {
            cnt += 1
        }

        // test initial value
        assertThat(flightPlan.latestMissionItemExecuted, nilValue())

        // update value
        impl.update(latestMissionItemExecuted: 1).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(flightPlan.latestMissionItemExecuted, presentAnd(`is`(1)))

        // update with same value
        impl.update(latestMissionItemExecuted: 1).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(flightPlan.latestMissionItemExecuted, presentAnd(`is`(1)))

        // update with another value
        impl.update(latestMissionItemExecuted: 5).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(flightPlan.latestMissionItemExecuted, presentAnd(`is`(5)))

        // update with another value
        impl.update(latestMissionItemExecuted: nil).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(flightPlan.latestMissionItemExecuted, nilValue())
    }

    func testUnavailabilityReasons() {
        impl.publish()
        var cnt = 0
        let flightPlan = store.get(PilotingItfs.flightPlan)!
        _ = store.register(desc: PilotingItfs.flightPlan) {
            cnt += 1
        }

        // test initial value
        assertThat(flightPlan.unavailabilityReasons, empty())

        // update value
        impl.update(unavailabilityReasons: [.cannotTakeOff, .droneGpsInfoInacurate]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(flightPlan.unavailabilityReasons, containsInAnyOrder(.cannotTakeOff, .droneGpsInfoInacurate))

        // update with same value
        impl.update(unavailabilityReasons: [.cannotTakeOff, .droneGpsInfoInacurate]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(flightPlan.unavailabilityReasons, containsInAnyOrder(.cannotTakeOff, .droneGpsInfoInacurate))

        // update with another value
        impl.update(unavailabilityReasons: [.droneGpsInfoInacurate]).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(flightPlan.unavailabilityReasons, containsInAnyOrder(.droneGpsInfoInacurate))

        // update with another value
        impl.update(unavailabilityReasons: [
            .droneGpsInfoInacurate, .cannotTakeOff, .droneNotCalibrated, .missingFlightPlanFile]).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(flightPlan.unavailabilityReasons, containsInAnyOrder(
            .droneGpsInfoInacurate, .cannotTakeOff, .droneNotCalibrated, .missingFlightPlanFile))
    }

    func testLatestActivationError() {
        impl.publish()
        var cnt = 0
        let flightPlan = store.get(PilotingItfs.flightPlan)!
        _ = store.register(desc: PilotingItfs.flightPlan) {
            cnt += 1
        }

        // test initial value
        assertThat(flightPlan.latestActivationError, `is`(.none))

        // update value
        impl.update(latestActivationError: .waypointBeyondGeofence).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(flightPlan.latestActivationError, `is`(.waypointBeyondGeofence))

        // update with same value
        impl.update(latestActivationError: .waypointBeyondGeofence).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(flightPlan.latestActivationError, `is`(.waypointBeyondGeofence))

        // update with another value
        impl.update(latestActivationError: .incorrectFlightPlanFile).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(flightPlan.latestActivationError, `is`(.incorrectFlightPlanFile))
    }

    func testFileIsKnown() {
        impl.publish()
        var cnt = 0
        let flightPlan = store.get(PilotingItfs.flightPlan)!
        _ = store.register(desc: PilotingItfs.flightPlan) {
            cnt += 1
        }

        // test initial value
        assertThat(flightPlan.flightPlanFileIsKnown, `is`(false))

        // update value
        impl.update(flightPlanFileIsKnown: true).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(flightPlan.flightPlanFileIsKnown, `is`(true))

        // update with same value
        impl.update(flightPlanFileIsKnown: true).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(flightPlan.flightPlanFileIsKnown, `is`(true))

        // update with another value
        impl.update(flightPlanFileIsKnown: false).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(flightPlan.flightPlanFileIsKnown, `is`(false))
    }

    func testIsPaused() {
        impl.publish()
        var cnt = 0
        let flightPlan = store.get(PilotingItfs.flightPlan)!
        _ = store.register(desc: PilotingItfs.flightPlan) {
            cnt += 1
        }

        // test initial value
        assertThat(flightPlan.isPaused, `is`(false))

        // update value
        impl.update(isPaused: true).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(flightPlan.isPaused, `is`(true))

        // update with same value
        impl.update(isPaused: true).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(flightPlan.isPaused, `is`(true))

        // update with another value
        impl.update(isPaused: false).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(flightPlan.isPaused, `is`(false))
    }
}

private class Backend: FlightPlanPilotingItfBackend {
    var activateCalled = false
    var activateRestart = false
    var uploadCalled = false
    var uploadedFilePath: String?

    func activate(restart: Bool) -> Bool {
        activateCalled = true
        activateRestart = restart
        return true
    }
    func deactivate() -> Bool { return false }
    func uploadFlightPlan(filepath: String) {
        uploadCalled = true
        uploadedFilePath = filepath
    }
}
