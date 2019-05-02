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

/// Test speedometer instrument
class SpeedometerTest: XCTestCase {

    var store: ComponentStoreCore!
    var impl: SpeedometerCore!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        impl = SpeedometerCore(store: store)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store.get(Instruments.speedometer), present())
        impl.unpublish()
        assertThat(store.get(Instruments.speedometer), nilValue())
    }

    func testValues() {
        impl.publish()
        var cnt = 0
        let speedometer = store.get(Instruments.speedometer)!
        _ = store.register(desc: Instruments.speedometer) {
            cnt += 1
        }
        // check inital value
        assertThat(speedometer.groundSpeed, `is`(0))

        // check set values
        impl.update(groundSpeed: 1.0).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(speedometer.groundSpeed, `is`(1))

        // check setting the same value does not change anything
        impl.update(groundSpeed: 1.0).notifyUpdated()
        assertThat(cnt, `is`(1))

        // check forwardSpeed value
        impl.update(forwardSpeed: 1.2).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(speedometer.forwardSpeed, `is`(1.2))
        impl.update(forwardSpeed: 1.2).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(speedometer.forwardSpeed, `is`(1.2))

        // check downSpeed value
        impl.update(downSpeed: 1.3).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(speedometer.downSpeed, `is`(1.3))
        impl.update(downSpeed: 1.3).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(speedometer.downSpeed, `is`(1.3))

        // check northSpeed value
        impl.update(northSpeed: 1.4).notifyUpdated()
        assertThat(cnt, `is`(4))
        assertThat(speedometer.northSpeed, `is`(1.4))
        impl.update(northSpeed: 1.4).notifyUpdated()
        assertThat(cnt, `is`(4))
        assertThat(speedometer.northSpeed, `is`(1.4))

        // check eastSpeed value
        impl.update(eastSpeed: 1.5).notifyUpdated()
        assertThat(cnt, `is`(5))
        assertThat(speedometer.eastSpeed, `is`(1.5))
        impl.update(eastSpeed: 1.5).notifyUpdated()
        assertThat(cnt, `is`(5))
        assertThat(speedometer.eastSpeed, `is`(1.5))

        // check rightSpeed value
        impl.update(rightSpeed: 1.6).notifyUpdated()
        assertThat(cnt, `is`(6))
        assertThat(speedometer.rightSpeed, `is`(1.6))
        impl.update(rightSpeed: 1.6).notifyUpdated()
        assertThat(cnt, `is`(6))
        assertThat(speedometer.rightSpeed, `is`(1.6))

        // test notify without changes
        impl.notifyUpdated()
        assertThat(cnt, `is`(6))
    }
}
