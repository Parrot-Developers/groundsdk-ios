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

/// Test Leds peripheral
class LedsTestsTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: LedsCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = LedsCore(store: store!, backend: backend!)
        backend.impl = impl
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.leds), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.leds), nilValue())
    }

    func testSwitchOn() {
        impl.update(state: false)
        impl.publish()
        var cnt = 0
        let leds = store.get(Peripherals.leds)!
        _ = store.register(desc: Peripherals.leds) {
            cnt += 1
        }

        // test initial value
        assertThat(leds.state!.value, `is`(false))
        assertThat(cnt, `is`(0))

        // change state value
        impl.update(state: true).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(leds.state!.value, `is`(true))

        // setting the same state should not change anything
        impl.update(state: true).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(leds.state!, `is`(true))
    }

    func testState() {
        impl.update(state: false)
        impl.publish()
        var cnt = 0
        let leds = store.get(Peripherals.leds)!
        _ = store.register(desc: Peripherals.leds) {
            cnt += 1
        }

        assertThat(store!.get(Peripherals.leds), present())
        // test initial value
        assertThat(leds.state!, `is`(false))
        assertThat(cnt, `is`(0))
        assertThat(backend.state, `is`(false))

        // Activate switch
        leds.state!.value = true
        assertThat(backend.state, `is`(true))
        assertThat(cnt, `is`(1))

        // switch already activated, nothing should happen
        leds.state!.value = true
        assertThat(backend.state, `is`(true))
        assertThat(cnt, `is`(1))

        // Deactivate switch
        leds.state!.value = false
        assertThat(backend.state, `is`(false))
        assertThat(cnt, `is`(2))

        // switch already deactivated, nothing should happen
        leds.state!.value = false
        assertThat(backend.state, `is`(false))
        assertThat(cnt, `is`(2))
    }
}

private class Backend: LedsBackend {
    var state: Bool = false

    func set(state: Bool) -> Bool {
        self.state = state
        return true
    }

    var impl: LedsCore?

}
