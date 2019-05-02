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

/// Test TargetTracker peripheral
class TargetTrackerTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: TargetTrackerCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = TargetTrackerCore(store: store!, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.targetTracker), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.targetTracker), nilValue())
    }

    func testPositionInFrame() {
        impl.publish()
        var cnt = 0
        let targetTracker = store.get(Peripherals.targetTracker)!
        _ = store.register(desc: Peripherals.targetTracker) {
            cnt += 1
        }

        // test default value
        assertThat(targetTracker.framing, allOf(`is`(0.0, 0.0), isUpToDate()))

        // change framing from API
        targetTracker.framing.value = (0.5, 0.6)
        assertThat(targetTracker.framing, allOf(`is`(0.5, 0.6), isUpdating()))
        assertThat(backend.setFramingCnt, `is`(1))
        assertThat(cnt, `is`(1))

        // update the value
        impl.update(framing: (0.5, 0.6)).notifyUpdated()
        assertThat(targetTracker.framing, allOf(`is`(0.5, 0.6), isUpToDate()))
        assertThat(cnt, `is`(2))

        // timeout should not do anything
        (targetTracker.framing as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(2))
        assertThat(targetTracker.framing, allOf(`is`(0.5, 0.6), isUpToDate()))

        // change framing from API with the same value
        targetTracker.framing.value = (0.5, 0.6)
        assertThat(targetTracker.framing, allOf(`is`(0.5, 0.6), isUpToDate()))
        assertThat(backend.setFramingCnt, `is`(1))
        assertThat(cnt, `is`(2))

        // change framing from Mock with the same value
        impl.update(framing: (0.5, 0.6)).notifyUpdated()
        assertThat(targetTracker.framing, allOf(`is`(0.5, 0.6), isUpToDate()))
        assertThat(backend.setFramingCnt, `is`(1))
        assertThat(cnt, `is`(2))

        // update framing from Mock with a new value (setting was not updating before)
        assertThat(targetTracker.framing, allOf(`is`(0.5, 0.6), isUpToDate()))
        impl.update(framing: (2.5, 2.6)).notifyUpdated()
        assertThat(targetTracker.framing, allOf(`is`(2.5, 2.6), isUpToDate()))
        assertThat(cnt, `is`(3))

        // change setting
        targetTracker.framing.value = (0.5, 0.6)
        assertThat(cnt, `is`(4))
        assertThat(targetTracker.framing, allOf(`is`(0.5, 0.6), isUpdating()))

        // mock timeout
        (targetTracker.framing as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(targetTracker.framing, allOf(`is`(2.5, 2.6), isUpToDate()))

        // change framing from the api
        targetTracker.framing.value = (0.5, 0.6)
        assertThat(cnt, `is`(6))
        assertThat(targetTracker.framing, allOf(`is`(0.5, 0.6), isUpdating()))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(7))
        assertThat(targetTracker.framing, allOf(`is`(0.5, 0.6), isUpToDate()))

        // timeout should not be triggered since it has been canceled
        (targetTracker.framing as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(7))
        assertThat(targetTracker.framing, allOf(`is`(0.5, 0.6), isUpToDate()))
    }

    func testUseControllerLocation() {
        impl.publish()
        var cnt = 0
        let targetTracker = store.get(Peripherals.targetTracker)!
        _ = store.register(desc: Peripherals.targetTracker) {
            cnt += 1
        }

        // use controller as target
        assertThat(backend.targetIsController, `is`(false))
        targetTracker.enableControllerTracking()
        assertThat(backend.targetIsController, `is`(true))
        assertThat(cnt, `is`(0))

        // end use controller as target
        targetTracker.disableControllerTracking()
        assertThat(backend.targetIsController, `is`(false))
        assertThat(cnt, `is`(0))
    }

    func testSendTargetDetectionInfo() {
        impl.publish()
        var cnt = 0
        let targetTracker = store.get(Peripherals.targetTracker)!
        _ = store.register(desc: Peripherals.targetTracker) {
            cnt += 1
        }

        // test initial value
        assertThat(backend.targetDectectionInfo, nilValue())

        // send Detection Info from API
        let detectionInfo = TargetDetectionInfo(
            targetAzimuth: 1.1, targetElevation: 2.2, changeOfScale: 3.3, confidence: 0.4, isNewTarget: true,
            timestamp: 200866)
        targetTracker.sendTargetDetectionInfo(detectionInfo)
        assertThat(backend.targetDectectionInfo, presentAnd(`is`(1.1, 2.2, 3.3, 0.4, true, 200866)))
        assertThat(cnt, `is`(0))
    }

    func testTargetTrajectory() {
        impl.publish()
        var cnt = 0
        let targetTracker = store.get(Peripherals.targetTracker)!
        _ = store.register(desc: Peripherals.targetTracker) {
            cnt += 1
        }

        // test default value
        assertThat(targetTracker.targetTrajectory, nilValue())

        // update the value
        let trajectory1 = TargetTrajectoryCore(
            latitude: 1.1, longitude: 2.2, altitude: 3.3, northSpeed: 4.4, eastSpeed: 5.5, downSpeed: 6.6)
        impl.update(targetTrajectory: trajectory1).notifyUpdated()
        assertThat(targetTracker.targetTrajectory, presentAnd(`is`(1.1, 2.2, 3.3, 4.4, 5.5, 6.6)))
        assertThat(cnt, `is`(1))

        // same value
        impl.update(targetTrajectory: trajectory1).notifyUpdated()
        assertThat(targetTracker.targetTrajectory, presentAnd(`is`(1.1, 2.2, 3.3, 4.4, 5.5, 6.6)))
        assertThat(cnt, `is`(1))

        // update followMode from Mock with a new value (setting was not updating before)
        let trajectory2 = TargetTrajectoryCore(
            latitude: 1.1, longitude: 2.2, altitude: 333.333, northSpeed: 4.4, eastSpeed: 5.5, downSpeed: 6.6)
        impl.update(targetTrajectory: trajectory2).notifyUpdated()
        assertThat(targetTracker.targetTrajectory, presentAnd(`is`(1.1, 2.2, 333.333, 4.4, 5.5, 6.6)))
        assertThat(cnt, `is`(2))
    }
}

private class Backend: TargetTrackerBackend {

    var targetDectectionInfo: TargetDetectionInfo?
    var setFramingCnt = 0
    var targetIsController = false

    func set(targetDetectionInfo: TargetDetectionInfo) {
        self.targetDectectionInfo = targetDetectionInfo
    }

    func set(framing: (horizontal: Double, vertical: Double)) -> Bool {
        setFramingCnt += 1
        return true
    }

    func set(targetIsController: Bool) {
        self.targetIsController = targetIsController
    }
}
