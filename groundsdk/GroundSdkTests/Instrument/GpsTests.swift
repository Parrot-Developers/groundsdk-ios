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

/// Test Gps instrument
class GpsTest: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: GpsCore!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        impl = GpsCore(store: store)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store.get(Instruments.gps), present())
        impl.unpublish()
        assertThat(store.get(Instruments.gps), nilValue())
    }

    func testValues() {
        impl.publish()
        var cnt = 0
        let gps = store.get(Instruments.gps)!
        _ = store.register(desc: Instruments.gps) {
            cnt += 1
        }
        // check inital value
        assertThat(gps.fixed, `is`(false))
        assertThat(gps.lastKnownLocation, nilValue())
        assertThat(gps.satelliteCount, `is`(0))

        // check set values
        let date = Date()
        impl.update(fixed: true)
            .update(latitude: 1.0, longitude: 2.0, altitude: 1.0, date: date)
            .update(horizontalAccuracy: 100.0)
            .update(verticalAccuracy: 40.0)
            .update(satelliteCount: 20)
            .notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(gps.fixed, `is`(true))
        assertThat(gps.lastKnownLocation, presentAnd(`is`(latitude: 1.0, longitude: 2.0, altitude: 1.0,
                                                          hAcc: 100.0, vAcc: 40.0, date: date)))
        assertThat(gps.satelliteCount, `is`(20))

        // check setting the same value does not change anything
        impl.update(fixed: true)
            .update(latitude: 1.0, longitude: 2.0, altitude: 1.0, date: date)
            .update(horizontalAccuracy: 100.0)
            .update(verticalAccuracy: 40.0)
            .update(satelliteCount: 20)
            .notifyUpdated()
        assertThat(cnt, `is`(1))

        // test notify without changes
        impl.notifyUpdated()
        assertThat(cnt, `is`(1))
    }
}
