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

/// Test Compass instrument
class CompassTest: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: CompassCore!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        impl = CompassCore(store: store)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store.get(Instruments.compass), present())
        impl.unpublish()
        assertThat(store.get(Instruments.compass), nilValue())
    }

    func testValues() {
        impl.publish()
        var cnt = 0
        let compass = store.get(Instruments.compass)!
        _ = store.register(desc: Instruments.compass) {
            cnt += 1
        }
        // check inital value
        assertThat(compass.heading, `is`(0))

        // check set values
        impl.update(heading: 1.0)
            .notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(compass.heading, `is`(1.0))

        // check setting the same value does not change anything
        impl.update(heading: 1.0)
            .notifyUpdated()
        assertThat(cnt, `is`(1))

        // test notify without changes
        impl.notifyUpdated()
        assertThat(cnt, `is`(1))
    }
}
