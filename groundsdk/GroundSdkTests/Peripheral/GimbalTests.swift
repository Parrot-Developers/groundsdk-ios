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

/// Test Gimbal peripheral
class GimbalTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: GimbalCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = GimbalCore(store: store!, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.gimbal), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.gimbal), nilValue())
    }

    func testSupportedAxes() {
        impl.publish()
        var cnt = 0
        let gimbal = store.get(Peripherals.gimbal)!
        _ = store.register(desc: Peripherals.gimbal) {
            cnt += 1
        }

        // test default value
        assertThat(gimbal.supportedAxes, empty())

        // test backend triggers a notification
        impl.update(supportedAxes: [.yaw, .pitch]).notifyUpdated()
        assertThat(gimbal.supportedAxes, containsInAnyOrder(.yaw, .pitch))
        assertThat(cnt, `is`(1))

        // check that receiving same axes does not trigger a notification
        impl.update(supportedAxes: [.yaw, .pitch]).notifyUpdated()
        assertThat(gimbal.supportedAxes, containsInAnyOrder(.yaw, .pitch))
        assertThat(cnt, `is`(1))

        // check that changing supported axes triggers a notification
        impl.update(supportedAxes: [.yaw]).notifyUpdated()
        assertThat(gimbal.supportedAxes, containsInAnyOrder(.yaw))
        assertThat(cnt, `is`(2))

        // check that changing supported axes triggers a notification
        impl.update(supportedAxes: [.yaw, .pitch, .roll]).notifyUpdated()
        assertThat(gimbal.supportedAxes, containsInAnyOrder(.yaw, .pitch, .roll))
        assertThat(cnt, `is`(3))

        // fill gimbal data
        impl.update(stabilization: true, onAxis: .yaw)
            .update(stabilization: true, onAxis: .pitch)
            .update(stabilization: false, onAxis: .roll)
            .update(lockedAxes: [.yaw, .roll])
            .update(absoluteAttitude: 10.0, onAxis: .yaw)
            .update(absoluteAttitude: 10.0, onAxis: .pitch)
            .update(relativeAttitude: 10.0, onAxis: .roll)
            .update(maxSpeedSetting: (min: 0.0, value: 2.2, max: 3.3), onAxis: .yaw)
            .update(maxSpeedSetting: (min: 0.0, value: 2.2, max: 3.3), onAxis: .pitch)
            .update(maxSpeedSetting: (min: 0.0, value: 2.2, max: 3.3), onAxis: .roll)
            .update(axisBounds: 0..<25, onAxis: .yaw)
            .update(axisBounds: 0..<25, onAxis: .pitch)
            .update(axisBounds: 0..<25, onAxis: .roll)
            .notifyUpdated()

        assertThat(gimbal.supportedAxes, containsInAnyOrder(.yaw, .pitch, .roll))
        assertThat(gimbal.stabilizationSettings[.yaw], presentAnd(`is`(true)))
        assertThat(gimbal.stabilizationSettings[.pitch], presentAnd(`is`(true)))
        assertThat(gimbal.stabilizationSettings[.roll], presentAnd(`is`(false)))
        assertThat(gimbal.lockedAxes, containsInAnyOrder(.yaw, .roll))
        assertThat(gimbal.currentAttitude[.yaw], presentAnd(`is`(10.0)))
        assertThat(gimbal.currentAttitude[.pitch], presentAnd(`is`(10.0)))
        assertThat(gimbal.currentAttitude[.roll], presentAnd(`is`(10.0)))
        assertThat(gimbal.maxSpeedSettings[.yaw], presentAnd(`is`(0.0, 2.2, 3.3)))
        assertThat(gimbal.maxSpeedSettings[.pitch], presentAnd(`is`(0.0, 2.2, 3.3)))
        assertThat(gimbal.maxSpeedSettings[.roll], presentAnd(`is`(0.0, 2.2, 3.3)))
        assertThat(gimbal.attitudeBounds[.yaw], presentAnd(`is`(0..<25)))
        assertThat(gimbal.attitudeBounds[.pitch], presentAnd(`is`(0..<25)))
        assertThat(gimbal.attitudeBounds[.roll], presentAnd(`is`(0..<25)))
        assertThat(cnt, `is`(4))

        // check that changing supported axes automatically removes unsupported axes from all getters
        impl.update(supportedAxes: [.yaw]).notifyUpdated()

        assertThat(gimbal.supportedAxes, containsInAnyOrder(.yaw))
        assertThat(gimbal.stabilizationSettings[.yaw], presentAnd(`is`(true)))
        assertThat(gimbal.stabilizationSettings[.pitch], nilValue())
        assertThat(gimbal.stabilizationSettings[.roll], nilValue())
        assertThat(gimbal.lockedAxes, containsInAnyOrder(.yaw))
        assertThat(gimbal.currentAttitude[.yaw], presentAnd(`is`(10.0)))
        assertThat(gimbal.currentAttitude[.pitch], nilValue())
        assertThat(gimbal.currentAttitude[.roll], nilValue())
        assertThat(gimbal.maxSpeedSettings[.yaw], presentAnd(`is`(0.0, 2.2, 3.3)))
        assertThat(gimbal.maxSpeedSettings[.pitch], nilValue())
        assertThat(gimbal.maxSpeedSettings[.roll], nilValue())
        assertThat(gimbal.attitudeBounds[.yaw], presentAnd(`is`(0..<25)))
        assertThat(gimbal.attitudeBounds[.pitch], nilValue())
        assertThat(gimbal.attitudeBounds[.roll], nilValue())
        assertThat(cnt, `is`(5))
    }

    func testCurrentErrors() {
        impl.publish()
        var cnt = 0
        let gimbal = store.get(Peripherals.gimbal)!
        _ = store.register(desc: Peripherals.gimbal) {
            cnt += 1
        }

        // test default value
        assertThat(gimbal.currentErrors, empty())
        assertThat(cnt, `is`(0))

        // test backend triggers a notification
        impl.update(currentErrors: [.communication, .critical]).notifyUpdated()
        assertThat(gimbal.currentErrors, containsInAnyOrder(.communication, .critical))
        assertThat(cnt, `is`(1))

        // check that receiving same errors does not trigger a notification
        impl.update(currentErrors: [.communication, .critical]).notifyUpdated()
        assertThat(gimbal.currentErrors, containsInAnyOrder(.communication, .critical))
        assertThat(cnt, `is`(1))

        // check that changing errors triggers a notification
        impl.update(currentErrors: [.communication]).notifyUpdated()
        assertThat(gimbal.currentErrors, containsInAnyOrder(.communication))
        assertThat(cnt, `is`(2))

        // check that removing all errors triggers a notification
        impl.update(currentErrors: []).notifyUpdated()
        assertThat(gimbal.currentErrors, empty())
        assertThat(cnt, `is`(3))
    }

    func testStabilizedAxes() {
        impl.update(supportedAxes: [.yaw, .pitch]).notifyUpdated()
        impl.publish()
        var cnt = 0
        let gimbal = store.get(Peripherals.gimbal)!
        _ = store.register(desc: Peripherals.gimbal) {
            cnt += 1
        }

        // test default value
        assertThat(gimbal.stabilizationSettings, empty())
        assertThat(cnt, `is`(0))

        // test backend triggers a notification
        impl.update(stabilization: true, onAxis: .yaw).notifyUpdated()
        assertThat(gimbal.stabilizationSettings[.yaw], presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(gimbal.stabilizationSettings[.pitch], nilValue())
        assertThat(gimbal.stabilizationSettings[.roll], nilValue())
        assertThat(cnt, `is`(1))

        // test backend triggers a notification
        impl.update(stabilization: false, onAxis: .pitch).notifyUpdated()
        assertThat(gimbal.stabilizationSettings[.yaw], presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(gimbal.stabilizationSettings[.pitch], presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(gimbal.stabilizationSettings[.roll], nilValue())
        assertThat(cnt, `is`(2))

        // test update with same value does not trigger a notification
        impl.update(stabilization: false, onAxis: .pitch).notifyUpdated()
        assertThat(gimbal.stabilizationSettings[.yaw], presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(gimbal.stabilizationSettings[.pitch], presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(gimbal.stabilizationSettings[.roll], nilValue())
        assertThat(cnt, `is`(2))

        // test update of a non-supported axis does not trigger a notification
        impl.update(stabilization: false, onAxis: .roll).notifyUpdated()
        assertThat(gimbal.stabilizationSettings[.yaw], presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(gimbal.stabilizationSettings[.pitch], presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(gimbal.stabilizationSettings[.roll], nilValue())
        assertThat(cnt, `is`(2))

        // change stabilized axis from the api
        gimbal.stabilizationSettings[.yaw]?.value = false
        assertThat(gimbal.stabilizationSettings[.yaw], presentAnd(allOf(`is`(false), isUpdating())))
        assertThat(gimbal.stabilizationSettings[.pitch], presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(gimbal.stabilizationSettings[.roll], nilValue())
        assertThat(backend.setStabCnt, `is`(1))
        assertThat(backend.latestStab, presentAnd(`is`(false)))
        assertThat(backend.latestStabAxis, presentAnd(`is`(.yaw)))
        assertThat(cnt, `is`(3))

        // change stabilized axis from the api
        gimbal.stabilizationSettings[.pitch]?.value = true
        assertThat(gimbal.stabilizationSettings[.yaw], presentAnd(allOf(`is`(false), isUpdating())))
        assertThat(gimbal.stabilizationSettings[.pitch], presentAnd(allOf(`is`(true), isUpdating())))
        assertThat(gimbal.stabilizationSettings[.roll], nilValue())
        assertThat(backend.setStabCnt, `is`(2))
        assertThat(backend.latestStab, presentAnd(`is`(true)))
        assertThat(backend.latestStabAxis, presentAnd(`is`(.pitch)))
        assertThat(cnt, `is`(4))

        impl.update(stabilization: true, onAxis: .pitch).notifyUpdated()
        assertThat(gimbal.stabilizationSettings[.yaw], presentAnd(allOf(`is`(false), isUpdating())))
        assertThat(gimbal.stabilizationSettings[.pitch], presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(gimbal.stabilizationSettings[.roll], nilValue())
        assertThat(cnt, `is`(5))

        impl.update(stabilization: true, onAxis: .yaw).notifyUpdated()
        assertThat(gimbal.stabilizationSettings[.yaw], presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(gimbal.stabilizationSettings[.pitch], presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(gimbal.stabilizationSettings[.roll], nilValue())
        assertThat(cnt, `is`(6))

        // change stabilized axis from the api
        gimbal.stabilizationSettings[.pitch]?.value = false
        assertThat(cnt, `is`(7))
        assertThat(gimbal.stabilizationSettings[.pitch], presentAnd(allOf(`is`(false), isUpdating())))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(8))
        assertThat(gimbal.stabilizationSettings[.pitch], presentAnd(allOf(`is`(false), isUpToDate())))

        // timeout should not be triggered since it has been canceled
        (gimbal.stabilizationSettings[.pitch] as! TimeoutableSetting).mockTimeout()
        assertThat(cnt, `is`(8))
        assertThat(gimbal.stabilizationSettings[.pitch], presentAnd(allOf(`is`(false), isUpToDate())))
    }

    func testLockedAxes() {
        impl.update(supportedAxes: [.yaw, .pitch]).notifyUpdated()
        impl.publish()
        var cnt = 0
        let gimbal = store.get(Peripherals.gimbal)!
        _ = store.register(desc: Peripherals.gimbal) {
            cnt += 1
        }

        // test default value
        assertThat(gimbal.lockedAxes, empty())
        assertThat(cnt, `is`(0))

        // test backend triggers a notification
        impl.update(lockedAxes: [.pitch]).notifyUpdated()
        assertThat(gimbal.lockedAxes, containsInAnyOrder(.pitch))
        assertThat(cnt, `is`(1))

        // test update with same value does not trigger a notification
        impl.update(lockedAxes: [.pitch]).notifyUpdated()
        assertThat(gimbal.lockedAxes, containsInAnyOrder(.pitch))
        assertThat(cnt, `is`(1))

        // test update of a non-supported axis does not trigger a notification
        impl.update(lockedAxes: [.pitch, .roll]).notifyUpdated()
        assertThat(gimbal.lockedAxes, containsInAnyOrder(.pitch))
        assertThat(cnt, `is`(1))

        impl.update(lockedAxes: [.pitch, .yaw]).notifyUpdated()
        assertThat(gimbal.lockedAxes, containsInAnyOrder(.pitch, .yaw))
        assertThat(cnt, `is`(2))
    }

    func testAttitude() {
        impl.update(supportedAxes: [.yaw, .pitch]).notifyUpdated()
        impl.publish()
        var cnt = 0
        let gimbal = store.get(Peripherals.gimbal)!
        _ = store.register(desc: Peripherals.gimbal) {
            cnt += 1
        }

        // test default value
        assertThat(gimbal.currentAttitude, empty())
        assertThat(cnt, `is`(0))

        impl.update(stabilization: true, onAxis: .yaw).update(stabilization: true, onAxis: .roll)
            .update(stabilization: false, onAxis: .pitch).notifyUpdated()
        // test backend triggers a notification
        impl.update(absoluteAttitude: 2.0, onAxis: .yaw).notifyUpdated()
        assertThat(gimbal.currentAttitude[.yaw], presentAnd(`is`(2.0)))
        assertThat(gimbal.currentAttitude[.pitch], nilValue())
        assertThat(gimbal.currentAttitude[.roll], nilValue())
        assertThat(cnt, `is`(2))

        // test backend triggers a notification
        impl.update(relativeAttitude: 3.0, onAxis: .pitch).notifyUpdated()
        assertThat(gimbal.currentAttitude[.yaw], presentAnd(`is`(2.0)))
        assertThat(gimbal.currentAttitude[.pitch], presentAnd(`is`(3.0)))
        assertThat(gimbal.currentAttitude[.roll], nilValue())
        assertThat(cnt, `is`(3))

        impl.update(absoluteAttitude: 3.0, onAxis: .pitch).notifyUpdated()
        assertThat(gimbal.currentAttitude[.yaw], presentAnd(`is`(2.0)))
        assertThat(gimbal.currentAttitude[.pitch], presentAnd(`is`(3.0)))
        assertThat(gimbal.currentAttitude[.roll], nilValue())
        assertThat(cnt, `is`(4))

        // test update of a non-supported axis does not trigger a notification
        impl.update(relativeAttitude: 5.0, onAxis: .roll).notifyUpdated()
        assertThat(gimbal.currentAttitude[.yaw], presentAnd(`is`(2.0)))
        assertThat(gimbal.currentAttitude[.pitch], presentAnd(`is`(3.0)))
        assertThat(gimbal.currentAttitude[.roll], nilValue())
        assertThat(cnt, `is`(4))
    }

    func testAbsoluteAttitude() {
        impl.update(supportedAxes: [.yaw, .pitch]).notifyUpdated()
        impl.publish()
        var cnt = 0
        let gimbal = store.get(Peripherals.gimbal)!
        _ = store.register(desc: Peripherals.gimbal) {
            cnt += 1
        }
        impl.update(stabilization: true, onAxis: .yaw).update(stabilization: true, onAxis: .roll)
            .update(stabilization: true, onAxis: .pitch).notifyUpdated()

        // test default value
        assertThat(gimbal.currentAttitude, empty())
        assertThat(cnt, `is`(1))

        // test backend triggers a notification
        impl.update(relativeAttitude: 2.0, onAxis: .yaw).notifyUpdated()
        assertThat(gimbal.currentAttitude[.yaw], nilValue())
        assertThat(gimbal.currentAttitude[.pitch], nilValue())
        assertThat(gimbal.currentAttitude[.roll], nilValue())
        assertThat(cnt, `is`(2))

        impl.update(absoluteAttitude: 2.0, onAxis: .yaw).notifyUpdated()
        assertThat(gimbal.currentAttitude[.yaw], presentAnd(`is`(2.0)))
        assertThat(gimbal.currentAttitude[.pitch], nilValue())
        assertThat(gimbal.currentAttitude[.roll], nilValue())
        assertThat(cnt, `is`(3))

        impl.update(relativeAttitude: 5.0, onAxis: .pitch).notifyUpdated()
        assertThat(gimbal.currentAttitude[.yaw], presentAnd(`is`(2.0)))
        assertThat(gimbal.currentAttitude[.pitch], nilValue())
        assertThat(gimbal.currentAttitude[.roll], nilValue())
        assertThat(cnt, `is`(4))

        impl.update(absoluteAttitude: 6.0, onAxis: .pitch).notifyUpdated()
        assertThat(gimbal.currentAttitude[.yaw], presentAnd(`is`(2.0)))
        assertThat(gimbal.currentAttitude[.pitch], presentAnd(`is`(6.0)))
        assertThat(gimbal.currentAttitude[.roll], nilValue())
        assertThat(cnt, `is`(5))
    }

    func testRelativeAttitude() {
        impl.update(supportedAxes: [.yaw, .pitch]).notifyUpdated()
        impl.publish()
        var cnt = 0
        let gimbal = store.get(Peripherals.gimbal)!
        _ = store.register(desc: Peripherals.gimbal) {
            cnt += 1
        }

        impl.update(stabilization: false, onAxis: .yaw).update(stabilization: false, onAxis: .roll)
            .update(stabilization: false, onAxis: .pitch).notifyUpdated()

        // test default value
        assertThat(gimbal.currentAttitude, empty())
        assertThat(cnt, `is`(1))

        // test backend triggers a notification
        impl.update(absoluteAttitude: 2.0, onAxis: .yaw).notifyUpdated()
        assertThat(gimbal.currentAttitude[.yaw], nilValue())
        assertThat(gimbal.currentAttitude[.pitch], nilValue())
        assertThat(gimbal.currentAttitude[.roll], nilValue())
        assertThat(cnt, `is`(2))

        impl.update(relativeAttitude: 2.0, onAxis: .yaw).notifyUpdated()
        assertThat(gimbal.currentAttitude[.yaw], presentAnd(`is`(2.0)))
        assertThat(gimbal.currentAttitude[.pitch], nilValue())
        assertThat(gimbal.currentAttitude[.roll], nilValue())
        assertThat(cnt, `is`(3))
    }

    func testMaxSpeed() {
        impl.update(supportedAxes: [.yaw, .pitch]).notifyUpdated()
        impl.publish()
        var cnt = 0
        let gimbal = store.get(Peripherals.gimbal)!
        _ = store.register(desc: Peripherals.gimbal) {
            cnt += 1
        }

        // test default value
        assertThat(gimbal.maxSpeedSettings, empty())
        assertThat(cnt, `is`(0))

        // test backend triggers a notification
        impl.update(maxSpeedSetting: (min: 0.0, value: 5.0, max: 10.0), onAxis: .yaw).notifyUpdated()
        assertThat(gimbal.maxSpeedSettings[.yaw], presentAnd(allOf(`is`(0.0, 5.0, 10.0), isUpToDate())))
        assertThat(gimbal.maxSpeedSettings[.pitch], nilValue())
        assertThat(gimbal.maxSpeedSettings[.roll], nilValue())
        assertThat(cnt, `is`(1))

        // test backend triggers a notification
        impl.update(maxSpeedSetting: (min: 5.0, value: 10.0, max: 20.0), onAxis: .pitch).notifyUpdated()
        assertThat(gimbal.maxSpeedSettings[.yaw], presentAnd(allOf(`is`(0.0, 5.0, 10.0), isUpToDate())))
        assertThat(gimbal.maxSpeedSettings[.pitch], presentAnd(allOf(`is`(5.0, 10.0, 20.0), isUpToDate())))
        assertThat(gimbal.maxSpeedSettings[.roll], nilValue())
        assertThat(cnt, `is`(2))

        // test update with same value does not trigger a notification
        impl.update(maxSpeedSetting: (min: 5.0, value: 10.0, max: 20.0), onAxis: .pitch).notifyUpdated()
        assertThat(gimbal.maxSpeedSettings[.yaw], presentAnd(allOf(`is`(0.0, 5.0, 10.0), isUpToDate())))
        assertThat(gimbal.maxSpeedSettings[.pitch], presentAnd(allOf(`is`(5.0, 10.0, 20.0), isUpToDate())))
        assertThat(gimbal.maxSpeedSettings[.roll], nilValue())
        assertThat(cnt, `is`(2))

        // test update of a non-supported axis does not trigger a notification
        impl.update(maxSpeedSetting: (min: 5.0, value: 10.0, max: 20.0), onAxis: .roll).notifyUpdated()
        assertThat(gimbal.maxSpeedSettings[.yaw], presentAnd(allOf(`is`(0.0, 5.0, 10.0), isUpToDate())))
        assertThat(gimbal.maxSpeedSettings[.pitch], presentAnd(allOf(`is`(5.0, 10.0, 20.0), isUpToDate())))
        assertThat(gimbal.maxSpeedSettings[.roll], nilValue())
        assertThat(cnt, `is`(2))

        // change max speed from the api
        gimbal.maxSpeedSettings[.yaw]?.value = 15.0
        assertThat(gimbal.maxSpeedSettings[.yaw], presentAnd(allOf(`is`(0.0, 10.0, 10.0), isUpdating())))
        assertThat(gimbal.maxSpeedSettings[.pitch], presentAnd(allOf(`is`(5.0, 10.0, 20.0), isUpToDate())))
        assertThat(gimbal.maxSpeedSettings[.roll], nilValue())
        assertThat(backend.setMaxSpeedCnt, `is`(1))
        assertThat(backend.latestMaxSpeed, presentAnd(`is`(10.0)))
        assertThat(backend.latestMaxSpeedAxis, presentAnd(`is`(.yaw)))
        assertThat(cnt, `is`(3))

        // change stabilized axis from the api
        gimbal.maxSpeedSettings[.pitch]?.value = 0.0
        assertThat(gimbal.maxSpeedSettings[.yaw], presentAnd(allOf(`is`(0.0, 10.0, 10.0), isUpdating())))
        assertThat(gimbal.maxSpeedSettings[.pitch], presentAnd(allOf(`is`(5.0, 5.0, 20.0), isUpdating())))
        assertThat(gimbal.maxSpeedSettings[.roll], nilValue())
        assertThat(backend.setMaxSpeedCnt, `is`(2))
        assertThat(backend.latestMaxSpeed, presentAnd(`is`(5.0)))
        assertThat(backend.latestMaxSpeedAxis, presentAnd(`is`(.pitch)))
        assertThat(cnt, `is`(4))

        impl.update(maxSpeedSetting: (min: nil, value: 5.0, max: nil), onAxis: .pitch).notifyUpdated()
        assertThat(gimbal.maxSpeedSettings[.yaw], presentAnd(allOf(`is`(0.0, 10.0, 10.0), isUpdating())))
        assertThat(gimbal.maxSpeedSettings[.pitch], presentAnd(allOf(`is`(5.0, 5.0, 20.0), isUpToDate())))
        assertThat(gimbal.maxSpeedSettings[.roll], nilValue())
        assertThat(cnt, `is`(5))

        impl.update(maxSpeedSetting: (min: 2.0, value: 3.0, max: 4.0), onAxis: .yaw).notifyUpdated()
        assertThat(gimbal.maxSpeedSettings[.yaw], presentAnd(allOf(`is`(2.0, 3.0, 4.0), isUpToDate())))
        assertThat(gimbal.maxSpeedSettings[.pitch], presentAnd(allOf(`is`(5.0, 5.0, 20.0), isUpToDate())))
        assertThat(gimbal.maxSpeedSettings[.roll], nilValue())
        assertThat(cnt, `is`(6))

        // change max speed from the api
        gimbal.maxSpeedSettings[.pitch]?.value = 10.0
        assertThat(cnt, `is`(7))
        assertThat(gimbal.maxSpeedSettings[.pitch], presentAnd(allOf(`is`(5.0, 10.0, 20.0), isUpdating())))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(8))
        assertThat(gimbal.maxSpeedSettings[.pitch], presentAnd(allOf(`is`(5.0, 10.0, 20.0), isUpToDate())))

        // timeout should not be triggered since it has been canceled
        (gimbal.maxSpeedSettings[.pitch] as! TimeoutableSetting).mockTimeout()
        assertThat(cnt, `is`(8))
        assertThat(gimbal.maxSpeedSettings[.pitch], presentAnd(allOf(`is`(5.0, 10.0, 20.0), isUpToDate())))
    }

    func testAttitudeBounds() {
        impl.update(supportedAxes: [.yaw, .pitch]).notifyUpdated()
        impl.publish()
        var cnt = 0
        let gimbal = store.get(Peripherals.gimbal)!
        _ = store.register(desc: Peripherals.gimbal) {
            cnt += 1
        }

        // test default value
        assertThat(gimbal.attitudeBounds, empty())
        assertThat(cnt, `is`(0))

        // test backend triggers a notification
        impl.update(axisBounds: 2.0..<3.0, onAxis: .yaw).notifyUpdated()
        assertThat(gimbal.attitudeBounds[.yaw], presentAnd(`is`(2.0..<3.0)))
        assertThat(gimbal.attitudeBounds[.pitch], nilValue())
        assertThat(gimbal.attitudeBounds[.roll], nilValue())
        assertThat(cnt, `is`(1))

        // test backend triggers a notification
        impl.update(axisBounds: 0.0..<10.0, onAxis: .pitch).notifyUpdated()
        assertThat(gimbal.attitudeBounds[.yaw], presentAnd(`is`(2.0..<3.0)))
        assertThat(gimbal.attitudeBounds[.pitch], presentAnd(`is`(0.0..<10.0)))
        assertThat(gimbal.attitudeBounds[.roll], nilValue())
        assertThat(cnt, `is`(2))

        // test update with same value does not trigger a notification
        impl.update(axisBounds: 0.0..<10.0, onAxis: .pitch).notifyUpdated()
        assertThat(gimbal.attitudeBounds[.yaw], presentAnd(`is`(2.0..<3.0)))
        assertThat(gimbal.attitudeBounds[.pitch], presentAnd(`is`(0.0..<10.0)))
        assertThat(gimbal.attitudeBounds[.roll], nilValue())
        assertThat(cnt, `is`(2))

        // test update of a non-supported axis does not trigger a notification
        impl.update(axisBounds: 0.0..<50.0, onAxis: .roll).notifyUpdated()
        assertThat(gimbal.attitudeBounds[.yaw], presentAnd(`is`(2.0..<3.0)))
        assertThat(gimbal.attitudeBounds[.pitch], presentAnd(`is`(0.0..<10.0)))
        assertThat(gimbal.attitudeBounds[.roll], nilValue())
        assertThat(cnt, `is`(2))
    }

    func testOffsetCorrectionProcess() {
        impl.publish()
        var cnt = 0
        let gimbal = store.get(Peripherals.gimbal)!
        _ = store.register(desc: Peripherals.gimbal) {
            cnt += 1
        }

        // test default value
        assertThat(gimbal.offsetsCorrectionProcess, nilValue())
        assertThat(cnt, `is`(0))
        assertThat(backend.startOffsetsCorrectionCnt, `is`(0))
        assertThat(backend.stopOffsetsCorrectionCnt, `is`(0))

        // Setting correctable axes when not started should not change anything
        impl.update(calibratableAxes: [.yaw, .pitch]).notifyUpdated()
        assertThat(gimbal.offsetsCorrectionProcess, nilValue())
        assertThat(cnt, `is`(0))
        assertThat(backend.startOffsetsCorrectionCnt, `is`(0))
        assertThat(backend.stopOffsetsCorrectionCnt, `is`(0))

        // Setting correction offsets when not started should not change anything
        impl.update(calibrationOffset: (min: 5.0, value: 10.0, max: 20.0), onAxis: .pitch).notifyUpdated()
        assertThat(gimbal.offsetsCorrectionProcess, nilValue())
        assertThat(cnt, `is`(0))
        assertThat(backend.startOffsetsCorrectionCnt, `is`(0))
        assertThat(backend.stopOffsetsCorrectionCnt, `is`(0))

        // start correction process, nothing should change for the moment
        gimbal.startOffsetsCorrectionProcess()
        assertThat(gimbal.offsetsCorrectionProcess, nilValue())
        assertThat(cnt, `is`(0))
        assertThat(backend.startOffsetsCorrectionCnt, `is`(1))
        assertThat(backend.stopOffsetsCorrectionCnt, `is`(0))

        // mock correction process started
        impl.update(offsetsCorrectionProcessStarted: true).notifyUpdated()
        assertThat(gimbal.offsetsCorrectionProcess, present())
        assertThat(cnt, `is`(1))
        assertThat(backend.startOffsetsCorrectionCnt, `is`(1))
        assertThat(backend.stopOffsetsCorrectionCnt, `is`(0))

        // Updating with the same value should not trigger any changes
        impl.update(offsetsCorrectionProcessStarted: true).notifyUpdated()
        assertThat(gimbal.offsetsCorrectionProcess, present())
        assertThat(cnt, `is`(1))
        assertThat(backend.startOffsetsCorrectionCnt, `is`(1))
        assertThat(backend.stopOffsetsCorrectionCnt, `is`(0))

        // stop correction process, nothing should change for the moment
        gimbal.stopOffsetsCorrectionProcess()
        assertThat(gimbal.offsetsCorrectionProcess, present())
        assertThat(cnt, `is`(1))
        assertThat(backend.startOffsetsCorrectionCnt, `is`(1))
        assertThat(backend.stopOffsetsCorrectionCnt, `is`(1))

        // mock correction process stopped
        impl.update(offsetsCorrectionProcessStarted: false).notifyUpdated()
        assertThat(gimbal.offsetsCorrectionProcess, nilValue())
        assertThat(cnt, `is`(2))
        assertThat(backend.startOffsetsCorrectionCnt, `is`(1))
        assertThat(backend.stopOffsetsCorrectionCnt, `is`(1))

        // Updating with the same value should not trigger any changes
        impl.update(offsetsCorrectionProcessStarted: false).notifyUpdated()
        assertThat(gimbal.offsetsCorrectionProcess, nilValue())
        assertThat(cnt, `is`(2))
        assertThat(backend.startOffsetsCorrectionCnt, `is`(1))
        assertThat(backend.stopOffsetsCorrectionCnt, `is`(1))
    }

    func testCorrectableAxes() {
        // during this test, offsets correction process is started.
        // Behavior when offset is not started will be tested in another test
        impl.update(offsetsCorrectionProcessStarted: true)
        impl.publish()
        var cnt = 0
        let gimbal = store.get(Peripherals.gimbal)!
        _ = store.register(desc: Peripherals.gimbal) {
            cnt += 1
        }

        // test default value
        assertThat(gimbal.offsetsCorrectionProcess!.correctableAxes, empty())
        assertThat(cnt, `is`(0))

        // test backend triggers a notification
        impl.update(calibratableAxes: [.yaw, .pitch]).notifyUpdated()
        assertThat(gimbal.offsetsCorrectionProcess!.correctableAxes, containsInAnyOrder(.yaw, .pitch))
        assertThat(cnt, `is`(1))

        // check that receiving same axes does not trigger a notification
        impl.update(calibratableAxes: [.yaw, .pitch]).notifyUpdated()
        assertThat(gimbal.offsetsCorrectionProcess!.correctableAxes, containsInAnyOrder(.yaw, .pitch))
        assertThat(cnt, `is`(1))

        // check that changing calibratable axes triggers a notification
        impl.update(calibratableAxes: [.yaw]).notifyUpdated()
        assertThat(gimbal.offsetsCorrectionProcess!.correctableAxes, containsInAnyOrder(.yaw))
        assertThat(cnt, `is`(2))

        // check that changing calibratable axes triggers a notification
        impl.update(calibratableAxes: [.yaw, .pitch, .roll]).notifyUpdated()
        assertThat(gimbal.offsetsCorrectionProcess!.correctableAxes, containsInAnyOrder(.yaw, .pitch, .roll))
        assertThat(cnt, `is`(3))

        // fill offset data
        impl.update(calibrationOffset: (min: 0.0, value: 2.2, max: 3.3), onAxis: .yaw)
            .update(calibrationOffset: (min: 0.0, value: 2.2, max: 3.3), onAxis: .pitch)
            .update(calibrationOffset: (min: 0.0, value: 2.2, max: 3.3), onAxis: .roll)
            .notifyUpdated()

        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.yaw], presentAnd(`is`(0.0, 2.2, 3.3)))
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.pitch], presentAnd(`is`(0.0, 2.2, 3.3)))
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.roll], presentAnd(`is`(0.0, 2.2, 3.3)))
        assertThat(cnt, `is`(4))

        // check that changing calibratable axes automatically removes unsupported axes from the calibration offsets
        impl.update(calibratableAxes: [.yaw]).notifyUpdated()

        assertThat(gimbal.offsetsCorrectionProcess!.correctableAxes, containsInAnyOrder(.yaw))
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.yaw], presentAnd(`is`(0.0, 2.2, 3.3)))
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.pitch], nilValue())
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.roll], nilValue())
        assertThat(cnt, `is`(5))
    }

    func testOffsetsCorrection() {
        // during this test, offsets correction process is started.
        // Behavior when offset is not started will be tested in another test
        impl.update(offsetsCorrectionProcessStarted: true)
        impl.update(calibratableAxes: [.yaw, .pitch]).notifyUpdated()
        impl.publish()
        var cnt = 0
        let gimbal = store.get(Peripherals.gimbal)!
        _ = store.register(desc: Peripherals.gimbal) {
            cnt += 1
        }

        // test default value
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection, empty())
        assertThat(cnt, `is`(0))

        // test backend triggers a notification
        impl.update(calibrationOffset: (min: 0.0, value: 5.0, max: 10.0), onAxis: .yaw).notifyUpdated()
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.yaw],
                   presentAnd(allOf(`is`(0.0, 5.0, 10.0), isUpToDate())))
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.pitch], nilValue())
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.roll], nilValue())
        assertThat(cnt, `is`(1))

        // test backend triggers a notification
        impl.update(calibrationOffset: (min: 5.0, value: 10.0, max: 20.0), onAxis: .pitch).notifyUpdated()
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.yaw],
                   presentAnd(allOf(`is`(0.0, 5.0, 10.0), isUpToDate())))
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.pitch],
                   presentAnd(allOf(`is`(5.0, 10.0, 20.0), isUpToDate())))
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.roll], nilValue())
        assertThat(cnt, `is`(2))

        // test update with same value does not trigger a notification
        impl.update(calibrationOffset: (min: 5.0, value: 10.0, max: 20.0), onAxis: .pitch).notifyUpdated()
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.yaw],
                   presentAnd(allOf(`is`(0.0, 5.0, 10.0), isUpToDate())))
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.pitch],
                   presentAnd(allOf(`is`(5.0, 10.0, 20.0), isUpToDate())))
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.roll], nilValue())
        assertThat(cnt, `is`(2))

        // test update of a non-supported axis does not trigger a notification
        impl.update(calibrationOffset: (min: 5.0, value: 10.0, max: 20.0), onAxis: .roll).notifyUpdated()
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.yaw],
                   presentAnd(allOf(`is`(0.0, 5.0, 10.0), isUpToDate())))
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.pitch],
                   presentAnd(allOf(`is`(5.0, 10.0, 20.0), isUpToDate())))
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.roll], nilValue())
        assertThat(cnt, `is`(2))

        // change max speed from the api
        gimbal.offsetsCorrectionProcess!.offsetsCorrection[.yaw]?.value = 15.0
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.yaw],
                   presentAnd(allOf(`is`(0.0, 10.0, 10.0), isUpdating())))
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.pitch],
                   presentAnd(allOf(`is`(5.0, 10.0, 20.0), isUpToDate())))
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.roll], nilValue())
        assertThat(backend.setOffsetCnt, `is`(1))
        assertThat(backend.latestOffset, presentAnd(`is`(10.0)))
        assertThat(backend.latestOffsetAxis, presentAnd(`is`(.yaw)))
        assertThat(cnt, `is`(3))

        // change stabilized axis from the api
        gimbal.offsetsCorrectionProcess!.offsetsCorrection[.pitch]?.value = 0.0
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.yaw],
                   presentAnd(allOf(`is`(0.0, 10.0, 10.0), isUpdating())))
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.pitch],
                   presentAnd(allOf(`is`(5.0, 5.0, 20.0), isUpdating())))
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.roll], nilValue())
        assertThat(backend.setOffsetCnt, `is`(2))
        assertThat(backend.latestOffset, presentAnd(`is`(5.0)))
        assertThat(backend.latestOffsetAxis, presentAnd(`is`(.pitch)))
        assertThat(cnt, `is`(4))

        impl.update(calibrationOffset: (min: nil, value: 5.0, max: nil), onAxis: .pitch).notifyUpdated()
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.yaw],
                   presentAnd(allOf(`is`(0.0, 10.0, 10.0), isUpdating())))
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.pitch],
                   presentAnd(allOf(`is`(5.0, 5.0, 20.0), isUpToDate())))
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.roll], nilValue())
        assertThat(cnt, `is`(5))

        impl.update(calibrationOffset: (min: 2.0, value: 3.0, max: 4.0), onAxis: .yaw).notifyUpdated()
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.yaw],
                   presentAnd(allOf(`is`(2.0, 3.0, 4.0), isUpToDate())))
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.pitch],
                   presentAnd(allOf(`is`(5.0, 5.0, 20.0), isUpToDate())))
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.roll], nilValue())
        assertThat(cnt, `is`(6))

        // mock correction process started and change an offset
        gimbal.offsetsCorrectionProcess?.offsetsCorrection[.pitch]?.value = 8
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.pitch],
                   presentAnd(allOf(`is`(5.0, 8.0, 20.0), isUpdating())))
        assertThat(cnt, `is`(7))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(8))
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.pitch],
                   presentAnd(allOf(`is`(5.0, 8.0, 20.0), isUpToDate())))

        // timeout should not be triggered since it has been canceled
        (gimbal.offsetsCorrectionProcess!.offsetsCorrection[.pitch] as! TimeoutableSetting).mockTimeout()
        assertThat(cnt, `is`(8))
        assertThat(gimbal.offsetsCorrectionProcess!.offsetsCorrection[.pitch],
                   presentAnd(allOf(`is`(5.0, 8.0, 20.0), isUpToDate())))
    }

    func testControl() {
        impl.update(supportedAxes: [.yaw, .pitch]).notifyUpdated()
        impl.publish()
        var cnt = 0
        let gimbal = store.get(Peripherals.gimbal)!
        _ = store.register(desc: Peripherals.gimbal) {
            cnt += 1
        }

        gimbal.control(mode: .position, yaw: 10, pitch: nil, roll: 20)
        assertThat(backend.controlCnt, `is`(1))
        assertThat(backend.controlMode, presentAnd(`is`(.position)))
        assertThat(backend.yawTarget, presentAnd(`is`(10)))
        assertThat(backend.pitchTarget, nilValue())
        assertThat(backend.rollTarget, nilValue())

        gimbal.control(mode: .velocity, yaw: nil, pitch: -0.5, roll: 20)
        assertThat(backend.controlCnt, `is`(2))
        assertThat(backend.controlMode, presentAnd(`is`(.velocity)))
        assertThat(backend.yawTarget, nilValue())
        assertThat(backend.pitchTarget, presentAnd(`is`(-0.5)))
        assertThat(backend.rollTarget, nilValue())
    }

    func testCalibrated() {
        impl.publish()
        var cnt = 0
        let gimbal = store.get(Peripherals.gimbal)!
        _ = store.register(desc: Peripherals.gimbal) {
            cnt += 1
        }

        // test default value
        assertThat(gimbal.calibrated, `is`(false))
        assertThat(cnt, `is`(0))

        // test backend triggers a notification
        impl.update(calibrated: true).notifyUpdated()
        assertThat(gimbal.calibrated, `is`(true))
        assertThat(cnt, `is`(1))

        // test update with same value does not trigger a notification
        impl.update(calibrated: true).notifyUpdated()
        assertThat(gimbal.calibrated, `is`(true))
        assertThat(cnt, `is`(1))
    }

    func testCalibrationProcessState() {
        impl.publish()
        var cnt = 0
        let gimbal = store.get(Peripherals.gimbal)!
        _ = store.register(desc: Peripherals.gimbal) {
            cnt += 1
        }

        // test default value
        assertThat(gimbal.calibrationProcessState, `is`(.none))
        assertThat(cnt, `is`(0))

        // test backend triggers a notification
        impl.update(calibrationProcessState: .calibrating).notifyUpdated()
        assertThat(gimbal.calibrationProcessState, `is`(.calibrating))
        assertThat(cnt, `is`(1))

        // test update with same value does not trigger a notification
        impl.update(calibrationProcessState: .calibrating).notifyUpdated()
        assertThat(gimbal.calibrationProcessState, `is`(.calibrating))
        assertThat(cnt, `is`(1))
    }

    func testCalibrationStartCancel() {
        impl.publish()
        var cnt = 0
        let gimbal = store.get(Peripherals.gimbal)!
        _ = store.register(desc: Peripherals.gimbal) {
            cnt += 1
        }

        // test intial values
        assertThat(backend.startCalibrationCnt, `is`(0))
        assertThat(backend.cancelCalibrationCnt, `is`(0))
        assertThat(cnt, `is`(0))

        // test start calibration
        gimbal.startCalibration()
        assertThat(backend.startCalibrationCnt, `is`(1))
        assertThat(backend.cancelCalibrationCnt, `is`(0))
        assertThat(cnt, `is`(0))

        // update calibration state
        impl.update(calibrationProcessState: .calibrating).notifyUpdated()
        assertThat(gimbal.calibrationProcessState, `is`(.calibrating))
        assertThat(cnt, `is`(1))

        // trying to start calibration while calibrating should do nothing
        gimbal.startCalibration()
        assertThat(backend.startCalibrationCnt, `is`(1))
        assertThat(backend.cancelCalibrationCnt, `is`(0))
        assertThat(cnt, `is`(1))

        // test cancel calibration
        gimbal.cancelCalibration()
        assertThat(backend.startCalibrationCnt, `is`(1))
        assertThat(backend.cancelCalibrationCnt, `is`(1))
        assertThat(cnt, `is`(1))

        // update calibration state
        impl.update(calibrationProcessState: .none).notifyUpdated()
        assertThat(gimbal.calibrationProcessState, `is`(.none))
        assertThat(cnt, `is`(2))

        // trying to cancel calibration while not calibrating should do nothing
        gimbal.cancelCalibration()
        assertThat(backend.startCalibrationCnt, `is`(1))
        assertThat(backend.cancelCalibrationCnt, `is`(1))
        assertThat(cnt, `is`(2))
    }
}

private class Backend: GimbalBackend {
    var setStabCnt = 0
    var latestStabAxis: GimbalAxis?
    var latestStab: Bool?
    var setMaxSpeedCnt = 0
    var latestMaxSpeedAxis: GimbalAxis?
    var latestMaxSpeed: Double?
    var setOffsetCnt = 0
    var latestOffsetAxis: GimbalAxis?
    var latestOffset: Double?
    var controlCnt = 0
    var controlMode: GimbalControlMode?
    var yawTarget: Double?
    var pitchTarget: Double?
    var rollTarget: Double?
    var startOffsetsCorrectionCnt = 0
    var stopOffsetsCorrectionCnt = 0
    var startCalibrationCnt = 0
    var cancelCalibrationCnt = 0

    func set(stabilization: Bool, onAxis axis: GimbalAxis) -> Bool {
        setStabCnt += 1
        latestStabAxis = axis
        latestStab = stabilization
        return true
    }

    func set(maxSpeed: Double, onAxis axis: GimbalAxis) -> Bool {
        setMaxSpeedCnt += 1
        latestMaxSpeedAxis = axis
        latestMaxSpeed = maxSpeed
        return true
    }

    func set(offsetCorrection: Double, onAxis axis: GimbalAxis) -> Bool {
        setOffsetCnt += 1
        latestOffsetAxis = axis
        latestOffset = offsetCorrection
        return true
    }

    func control(mode: GimbalControlMode, yaw: Double?, pitch: Double?, roll: Double?) {
        controlCnt += 1
        controlMode = mode
        yawTarget = yaw
        pitchTarget = pitch
        rollTarget = roll
    }

    func startOffsetsCorrectionProcess() {
        startOffsetsCorrectionCnt += 1
    }

    func stopOffsetsCorrectionProcess() {
        stopOffsetsCorrectionCnt += 1
    }

    func startCalibration() {
        startCalibrationCnt += 1
    }

    func cancelCalibration() {
        cancelCalibrationCnt += 1
    }
}
