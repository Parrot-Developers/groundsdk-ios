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

/// Test BatteryInfo instrument
class BatteryInfoTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: BatteryInfoCore!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        impl = BatteryInfoCore(store: store)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store.get(Instruments.batteryInfo), present())
        impl.unpublish()
        assertThat(store.get(Instruments.batteryInfo), nilValue())
    }

    func testValues() {
        impl.publish()
        var cnt = 0
        let batteryInfo = store.get(Instruments.batteryInfo)!
        _ = store.register(desc: Instruments.batteryInfo) {
            cnt += 1
        }
        // check inital value
        assertThat(batteryInfo.batteryLevel, `is`(0))
        assertThat(batteryInfo.isCharging, `is`(false))
        assertThat(batteryInfo.batteryHealth, nilValue())

        // check set value level
        impl.update(batteryLevel: 50).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(batteryInfo.batteryLevel, `is`(50))

        // check setting the same value does not change anything
        impl.update(batteryLevel: 50).notifyUpdated()
        assertThat(cnt, `is`(1))

        // check set value isCharging
        impl.update(isCharging: true).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(batteryInfo.isCharging, `is`(true))

        // check setting the same value does not change anything
        impl.update(isCharging: true).notifyUpdated()
        assertThat(cnt, `is`(2))

        // check set value health
        impl.update(batteryHealth: 50).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(batteryInfo.batteryHealth, `is`(50))

        // check setting the same value does not change anything
        impl.update(batteryHealth: 50).notifyUpdated()
        assertThat(cnt, `is`(3))

        // test notify without changes
        impl.notifyUpdated()
        assertThat(cnt, `is`(3))
    }
}
