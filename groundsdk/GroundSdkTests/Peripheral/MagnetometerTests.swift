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

/// Test Magnetometer peripheral
class MagnetometerTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: MagnetometerCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = MagnetometerCore(store: store!, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.magnetometer), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.magnetometer), nilValue())
    }

    func testIsCalibrated() {
        impl.publish()
        var cnt = 0
        let magnetometer = store.get(Peripherals.magnetometer)!
        _ = store.register(desc: Peripherals.magnetometer) {
            cnt += 1
        }

        // test initial value
        assertThat(magnetometer.calibrated, `is`(false))

        // change calibration status
        impl.update(calibrated: true).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(magnetometer.calibrated, `is`(true))

        // change calibration status
        impl.update(calibrated: false).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(magnetometer.calibrated, `is`(false))
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
