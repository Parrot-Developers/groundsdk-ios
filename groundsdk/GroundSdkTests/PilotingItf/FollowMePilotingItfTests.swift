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
class FollowMePilotingItfTest: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: FollowMePilotingItfCore!
    private var backend: Backend!

    let issuesEmptySet = Set<TrackingIssue>()
    let issuesSetOne: Set<TrackingIssue> = [.droneGpsInfoInaccurate, .targetDetectionInfoMissing]
    let issuesSetTwo: Set<TrackingIssue> = [.droneNotCalibrated, .droneTooCloseToGround, .droneTooCloseToTarget ]

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = FollowMePilotingItfCore(store: store, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store.get(PilotingItfs.followMe), present())
        impl.unpublish()
        assertThat(store.get(PilotingItfs.followMe), nilValue())
    }

    func testFollowMeMissingRequirements() {
        impl.publish()
        var cnt = 0
        let followMeItf = store.get(PilotingItfs.followMe)!
        _ = store.register(desc: PilotingItfs.followMe) {
            cnt += 1
        }
        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(followMeItf.availabilityIssues, `is`(issuesEmptySet))

        // update from low level the same value -- no notification expected
        impl.update(availabilityIssues: issuesEmptySet )
        assertThat(cnt, `is`(0))
        assertThat(followMeItf.availabilityIssues, `is`(issuesEmptySet))

        // update from low level
        impl.update(availabilityIssues: issuesSetOne ).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(followMeItf.availabilityIssues, `is`(issuesSetOne))

        // update from low level with the same value
        impl.update(availabilityIssues: issuesSetOne ).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(followMeItf.availabilityIssues, `is`(issuesSetOne))
    }

    func testLookQualityIssues() {
        impl.publish()
        var cnt = 0
        let followMeItf = store.get(PilotingItfs.followMe)!
        _ = store.register(desc: PilotingItfs.followMe) {
            cnt += 1
        }
        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(followMeItf.qualityIssues, `is`(issuesEmptySet))

        // update from low level the same value -- no notification expected
        impl.update(qualityIssues: issuesEmptySet )
        assertThat(cnt, `is`(0))
        assertThat(followMeItf.qualityIssues, `is`(issuesEmptySet))

        // update from low level
        impl.update(qualityIssues: issuesSetOne ).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(followMeItf.qualityIssues, `is`(issuesSetOne))

        // update from low level with the same value
        impl.update(qualityIssues: issuesSetOne ).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(followMeItf.qualityIssues, `is`(issuesSetOne))
    }

    func testFollowMode() {
        // mock geographic and relative are supported, leash is not
        impl.update(supportedFollowModes: [.geographic, .relative])
        impl.publish()
        var cnt = 0
        let followMeItf = store.get(PilotingItfs.followMe)!
        _ = store.register(desc: PilotingItfs.followMe) {
            cnt += 1
        }

        // test default value
        assertThat(followMeItf.followMode, allOf(`is`(.geographic), isUpToDate()))

        // change followMode from API
        followMeItf.followMode.value = .relative
        assertThat(followMeItf.followMode, allOf(`is`(.relative), isUpdating()))
        assertThat(backend.setFollowModeCnt, `is`(1))
        assertThat(cnt, `is`(1))

        // update the value
        impl.update(followMode: .relative).notifyUpdated()
        assertThat(followMeItf.followMode, allOf(`is`(.relative), isUpToDate()))
        assertThat(cnt, `is`(2))

        // change followMode from API with the same value
        followMeItf.followMode.value = .relative
        assertThat(backend.setFollowModeCnt, `is`(1))
        assertThat(followMeItf.followMode, allOf(`is`(.relative), isUpToDate()))
        assertThat(cnt, `is`(2))

        // change followMode from Mock with the same value
        impl.update(followMode: .relative).notifyUpdated()
        assertThat(backend.setFollowModeCnt, `is`(1))
        assertThat(followMeItf.followMode, allOf(`is`(.relative), isUpToDate()))
        assertThat(cnt, `is`(2))

        // timeout should not do anything
        (followMeItf.followMode as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(2))
        assertThat(followMeItf.followMode, allOf(`is`(.relative), isUpToDate()))

        // update followMode from Mock with a new value (setting was not updating before)
        assertThat(followMeItf.followMode, allOf(`is`(.relative), isUpToDate()))
        impl.update(followMode: .geographic).notifyUpdated()
        assertThat(followMeItf.followMode, allOf(`is`(.geographic), isUpToDate()))
        assertThat(cnt, `is`(3))

        // change setting
        followMeItf.followMode.value = .relative
        assertThat(cnt, `is`(4))
        assertThat(followMeItf.followMode, presentAnd(allOf(`is`(.relative), isUpdating())))

        // mock timeout
        (followMeItf.followMode as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(followMeItf.followMode, presentAnd(allOf(`is`(.geographic), isUpToDate())))

        // change setting from the api
        followMeItf.followMode.value = .relative
        assertThat(cnt, `is`(6))
        assertThat(followMeItf.followMode, presentAnd(allOf(`is`(.relative), isUpdating())))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(7))
        assertThat(followMeItf.followMode, presentAnd(allOf(`is`(.relative), isUpToDate())))

        // timeout should not be triggered since it has been canceled
        (followMeItf.followMode as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(7))
        assertThat(followMeItf.followMode, presentAnd(allOf(`is`(.relative), isUpToDate())))

        // check that requesting a mode that is not supported does nothing
        followMeItf.followMode.value = .leash
        assertThat(cnt, `is`(7))
        assertThat(followMeItf.followMode, presentAnd(allOf(`is`(.relative), isUpToDate())))
    }

    func testSupportedFollowModes() {
        impl.publish()
        var cnt = 0
        let followMeItf = store.get(PilotingItfs.followMe)!
        _ = store.register(desc: PilotingItfs.followMe) {
            cnt += 1
        }

        // test default value
        assertThat(followMeItf.followMode.supportedModes, empty())
        assertThat(cnt, `is`(0))

        // mock supported modes changed
        impl.update(supportedFollowModes: [.geographic]).notifyUpdated()
        assertThat(followMeItf.followMode.supportedModes, containsInAnyOrder(.geographic))
        assertThat(cnt, `is`(1))

        // mock supported modes changed
        impl.update(supportedFollowModes: [.geographic, .leash]).notifyUpdated()
        assertThat(followMeItf.followMode.supportedModes, containsInAnyOrder(.geographic, .leash))
        assertThat(cnt, `is`(2))

        // update with the same value should not notify the api
        impl.update(supportedFollowModes: [.geographic, .leash]).notifyUpdated()
        assertThat(followMeItf.followMode.supportedModes, containsInAnyOrder(.geographic, .leash))
        assertThat(cnt, `is`(2))
    }

    func testFollowBehavior() {
        impl.publish()
        var cnt = 0
        let followMeItf = store.get(PilotingItfs.followMe)!
        _ = store.register(desc: PilotingItfs.followMe) {
            cnt += 1
        }

        // test default value
        assertThat(followMeItf.followBehavior, nilValue())
        assertThat(cnt, `is`(0))
        // update from low level the same value -- no notification expected
        impl.update(followBehavior: nil ).notifyUpdated()
        assertThat(cnt, `is`(0))
        assertThat(followMeItf.followBehavior, nilValue())
        // update from low level
        impl.update(followBehavior: .stationary).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(followMeItf.followBehavior, presentAnd(`is`(.stationary)))
        // update from low level with the same value
        impl.update(followBehavior: .stationary).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(followMeItf.followBehavior, presentAnd(`is`(.stationary)))
    }

    func testCallingBackendThroughInterface() {
        impl.publish()
        let interface = store.get(PilotingItfs.followMe)!

        interface.set(roll: 1)
        assertThat(backend.roll, `is`(1))
        interface.set(pitch: 2)
        assertThat(backend.pitch, `is`(2))
        interface.set(verticalSpeed: 3)
        assertThat(backend.verticalSpeed, `is`(3))
    }
}

private class Backend: FollowMePilotingItfBackend {

    var setFollowModeCnt = 0

    func set(followMode: FollowMode) -> Bool {
        setFollowModeCnt += 1
        return true
    }

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
