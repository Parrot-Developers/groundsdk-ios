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

/// Test altimeter instrument
class AltimeterTest: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: AltimeterCore!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        impl = AltimeterCore(store: store)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store.get(Instruments.altimeter), present())
        impl.unpublish()
        assertThat(store.get(Instruments.altimeter), nilValue())
    }

    func testValues() {
        impl.publish()
        var cnt = 0
        let altimeter = store.get(Instruments.altimeter)!
        _ = store.register(desc: Instruments.altimeter) {
            cnt += 1
        }
        // check inital value
        assertThat(altimeter.groundRelativeAltitude, nilValue())
        assertThat(altimeter.takeoffRelativeAltitude, nilValue())
        assertThat(altimeter.absoluteAltitude, nilValue())
        assertThat(altimeter.verticalSpeed, nilValue())

        // check set values
        impl.update(groundRelativeAltitude: 1.0)
            .update(takeoffRelativeAltitude: 2.0)
            .update(absoluteAltitude: 3.0)
            .update(verticalSpeed: 4.0)
            .notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(altimeter.groundRelativeAltitude, presentAnd(`is`(1)))
        assertThat(altimeter.takeoffRelativeAltitude, presentAnd(`is`(2)))
        assertThat(altimeter.absoluteAltitude, presentAnd(`is`(3)))
        assertThat(altimeter.verticalSpeed, presentAnd(`is`(4)))

        // check setting the same value does not change anything
        impl.update(groundRelativeAltitude: 1.0)
            .notifyUpdated()
        assertThat(cnt, `is`(1))

        // test notify without changes
        impl.notifyUpdated()
        assertThat(cnt, `is`(1))
    }
}
