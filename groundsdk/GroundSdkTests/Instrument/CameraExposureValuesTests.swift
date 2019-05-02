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

/// Test CameraExposureValues instrument
class CameraExposureValuesTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: CameraExposureValuesCore!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        impl = CameraExposureValuesCore(store: store)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store.get(Instruments.cameraExposureValues), present())
        impl.unpublish()
        assertThat(store.get(Instruments.cameraExposureValues), nilValue())
    }

    func testValues() {
        impl.publish()
        var cnt = 0
        let cameraExposureValues = store.get(Instruments.cameraExposureValues)!
        _ = store.register(desc: Instruments.cameraExposureValues) {
            cnt += 1
        }
        // check inital value
        assertThat(cameraExposureValues.shutterSpeed, `is`(.oneOver10000))
        assertThat(cameraExposureValues.isoSensitivity, `is`(.iso50))

        // check set shutter speed value
        impl.update(shutterSpeed: .oneOver100).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(cameraExposureValues.shutterSpeed, `is`(.oneOver100))
        assertThat(cameraExposureValues.isoSensitivity, `is`(.iso50))

        // check setting the same value does not change anything
        impl.update(shutterSpeed: .oneOver100).notifyUpdated()
        assertThat(cnt, `is`(1))

        // check set iso sensitivity value
        impl.update(isoSensitivity: .iso160).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(cameraExposureValues.shutterSpeed, `is`(.oneOver100))
        assertThat(cameraExposureValues.isoSensitivity, `is`(.iso160))

        // check setting the same value does not change anything
        impl.update(isoSensitivity: .iso160).notifyUpdated()
        assertThat(cnt, `is`(2))

        // test notify without changes
        impl.notifyUpdated()
        assertThat(cnt, `is`(2))
    }
}
