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

/// Test precise home peripheral
class PreciseHomeTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: PreciseHomeCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = PreciseHomeCore(store: store!, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.preciseHome), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.preciseHome), nilValue())
    }

    func testMode() {
        impl.publish()
        var cnt = 0
        let preciseHome = store.get(Peripherals.preciseHome)!
        _ = store.register(desc: Peripherals.preciseHome) {
            cnt += 1
        }

        // test initial value
        assertThat(preciseHome.setting, supports(modes: []))
        assertThat(preciseHome.setting, `is`(mode: .disabled, updating: false))
        assertThat(preciseHome.state, `is`(.unavailable))

        // change capabilities
        impl.update(supportedModes: [.disabled, .standard]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(preciseHome.setting, supports(modes: [.disabled, .standard]))

        // change mode
        impl.update(mode: .standard).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(preciseHome.setting, `is`(mode: .standard, updating: false))

        // same mode should not change count
        impl.update(mode: .standard).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(preciseHome.setting, `is`(mode: .standard, updating: false))

    }

    func testState() {
        impl.publish()
        var cnt = 0
        let preciseHome = store.get(Peripherals.preciseHome)!
        _ = store.register(desc: Peripherals.preciseHome) {
            cnt += 1
        }
        assertThat(preciseHome.state, `is`(.unavailable))

        // change value
        impl.update(state: .active).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(preciseHome.state, `is`(.active))

        // same state should not change count
        impl.update(state: .active).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(preciseHome.state, `is`(.active))

        // change value to unavailable
        impl.update(state: .unavailable).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(preciseHome.state, `is`(.unavailable))

    }
}

private class Backend: PreciseHomeBackend {
    var mode: PreciseHomeMode?

    func set(mode: PreciseHomeMode) -> Bool {
        self.mode = mode
        return true
    }
}
