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

/// Test Magnetometer with 3 step calibration peripheral
class MagnetometerWith3StepCalibrationTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: MagnetometerWith3StepCalibrationCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = MagnetometerWith3StepCalibrationCore(store: store!, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.magnetometerWith3StepCalibration), present())
        assertThat(store!.get(Peripherals.magnetometer), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.magnetometerWith3StepCalibration), nilValue())
        assertThat(store!.get(Peripherals.magnetometer), nilValue())
    }

    func testCalibrationProcess() {
        impl.publish()
        var cnt = 0
        let magnetometer = store!.get(Peripherals.magnetometerWith3StepCalibration)!
        _ = store.register(desc: Peripherals.magnetometerWith3StepCalibration) {
            cnt += 1
        }

        // test initial value
        assertThat(magnetometer.calibrationProcessState, nilValue())

        // start a calibration process
        magnetometer.startCalibrationProcess()
        assertThat(backend.startCnt, `is`(1))
        assertThat(cnt, `is`(1))
        assertThat(magnetometer.calibrationProcessState, presentAnd(`is`(.none, [], false)))

        // start a calibration process if already started should not change anything
        magnetometer.startCalibrationProcess()
        assertThat(backend.startCnt, `is`(1))
        assertThat(cnt, `is`(1))
        assertThat(magnetometer.calibrationProcessState, presentAnd(`is`(.none, [], false)))

        // change the calib process state values
        impl.update(currentAxis: .roll).update(calibratedAxes: [.roll, .pitch]).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(magnetometer.calibrationProcessState, presentAnd(`is`(.roll, [.roll, .pitch], false)))

        // check that calling calibration stopped stops the calibration process
        impl.calibrationProcessStopped().notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(magnetometer.calibrationProcessState, nilValue())
    }

    func testCalibrationProcessCancel() {
        impl.publish()
        var cnt = 0
        let magnetometer = store!.get(Peripherals.magnetometerWith3StepCalibration)!
        _ = store.register(desc: Peripherals.magnetometerWith3StepCalibration) {
            cnt += 1
        }

        // cancel a not started calibration process should not do anything
        magnetometer.cancelCalibrationProcess()
        assertThat(backend.cancelCnt, `is`(0))
        assertThat(cnt, `is`(0))
        assertThat(magnetometer.calibrationProcessState, nilValue())

        // start a calibration process
        magnetometer.startCalibrationProcess()
        assertThat(backend.startCnt, `is`(1))
        assertThat(cnt, `is`(1))
        assertThat(magnetometer.calibrationProcessState, presentAnd(`is`(.none, [], false)))

        // cancel the calibration process
        magnetometer.cancelCalibrationProcess()
        assertThat(backend.cancelCnt, `is`(1))
        assertThat(cnt, `is`(2))
        assertThat(magnetometer.calibrationProcessState, nilValue())
    }

    func testCalibrationProcessFailed() {
        impl.publish()
        var cnt = 0
        let magnetometer = store!.get(Peripherals.magnetometerWith3StepCalibration)!
        _ = store.register(desc: Peripherals.magnetometerWith3StepCalibration) {
            cnt += 1
        }

        // start a calibration process
        magnetometer.startCalibrationProcess()
        assertThat(backend.startCnt, `is`(1))
        assertThat(cnt, `is`(1))
        assertThat(magnetometer.calibrationProcessState, presentAnd(`is`(.none, [], false)))

        // first set failed to true
        impl.update(failed: true).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(magnetometer.calibrationProcessState, presentAnd(`is`(.none, [], true)))
        // then stop the
        impl.calibrationProcessStopped().notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(magnetometer.calibrationProcessState, nilValue())

        // start a new calibration process.
        magnetometer.startCalibrationProcess()
        assertThat(backend.startCnt, `is`(2))
        assertThat(cnt, `is`(4))
        assertThat(magnetometer.calibrationProcessState, presentAnd(`is`(.none, [], false)))

        // cancel the calibration process
        magnetometer.cancelCalibrationProcess()
        assertThat(backend.cancelCnt, `is`(1))
        assertThat(cnt, `is`(5))
        assertThat(magnetometer.calibrationProcessState, nilValue())
    }
}

private class Backend: MagnetometerBackend {
    var startCnt = 0
    var cancelCnt = 0

    func startCalibrationProcess() {
        startCnt += 1
    }
    func cancelCalibrationProcess() {
        cancelCnt += 1
    }
}
