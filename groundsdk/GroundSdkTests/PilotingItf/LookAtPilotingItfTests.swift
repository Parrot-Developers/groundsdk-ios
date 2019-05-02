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

/// Test Poi piloting interface
class LookAtPilotingItfTest: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: LookAtPilotingItfCore!
    private var backend: Backend!

    let issuesEmptySet = Set<TrackingIssue>()
    let issuesSetOne: Set<TrackingIssue> = [.droneGpsInfoInaccurate, .targetDetectionInfoMissing]
    let issuesSetTwo: Set<TrackingIssue> = [.droneNotCalibrated, .droneTooCloseToGround, .droneTooCloseToTarget ]

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = LookAtPilotingItfCore(store: store, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store.get(PilotingItfs.lookAt), present())
        impl.unpublish()
        assertThat(store.get(PilotingItfs.lookAt), nilValue())
    }

    func testLookAtMissingRequirements() {
        impl.publish()
        var cnt = 0
        let lookAtItf = store.get(PilotingItfs.lookAt)!
        _ = store.register(desc: PilotingItfs.lookAt) {
            cnt += 1
        }
        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(lookAtItf.availabilityIssues, `is`(issuesEmptySet))

        // update from low level the same value -- no notification expected
        impl.update(availabilityIssues: issuesEmptySet )
        assertThat(cnt, `is`(0))
        assertThat(lookAtItf.availabilityIssues, `is`(issuesEmptySet))

        // update from low level
        impl.update(availabilityIssues: issuesSetOne ).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(lookAtItf.availabilityIssues, `is`(issuesSetOne))

        // update from low level with the same value
        impl.update(availabilityIssues: issuesSetOne ).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(lookAtItf.availabilityIssues, `is`(issuesSetOne))
    }

    func testLookQualityIssues() {
        impl.publish()
        var cnt = 0
        let lookAtItf = store.get(PilotingItfs.lookAt)!
        _ = store.register(desc: PilotingItfs.lookAt) {
            cnt += 1
        }
        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(lookAtItf.qualityIssues, `is`(issuesEmptySet))

        // update from low level the same value -- no notification expected
        impl.update(qualityIssues: issuesEmptySet )
        assertThat(cnt, `is`(0))
        assertThat(lookAtItf.qualityIssues, `is`(issuesEmptySet))

        // update from low level
        impl.update(qualityIssues: issuesSetOne ).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(lookAtItf.qualityIssues, `is`(issuesSetOne))

        // update from low level with the same value
        impl.update(qualityIssues: issuesSetOne ).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(lookAtItf.qualityIssues, `is`(issuesSetOne))
    }

    func testCallingBackendThroughInterface() {
        impl.publish()
        let lookAtInterface = store.get(PilotingItfs.lookAt)!

        lookAtInterface.set(roll: 1)
        assertThat(backend.roll, `is`(1))
        lookAtInterface.set(pitch: 2)
        assertThat(backend.pitch, `is`(2))
        lookAtInterface.set(verticalSpeed: 3)
        assertThat(backend.verticalSpeed, `is`(3))
    }
}

private class Backend: LookAtPilotingItfBackend {

    var roll = 0
    var pitch = 0
    var verticalSpeed = 0

    func activate() -> Bool {
        return true
    }

    func deactivate() -> Bool {
        return true
    }

    func set(roll: Int) {
        self.roll = roll
    }

    func set(pitch: Int) {
        self.pitch = pitch
    }

    func set(verticalSpeed: Int) {
        self.verticalSpeed = verticalSpeed
    }
}
