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

/// Test Antiflicker peripheral
class AntiflickerTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: AntiflickerCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = AntiflickerCore(store: store!, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.antiflicker), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.antiflicker), nilValue())
    }

    func testMode() {
        impl.publish()
        var cnt = 0
        let antiflicker = store.get(Peripherals.antiflicker)!
        _ = store.register(desc: Peripherals.antiflicker) {
            cnt += 1
        }

        // test initial value
        assertThat(antiflicker.setting, supports(modes: [.off]))
        assertThat(antiflicker.setting, `is`(mode: .off, updating: false))
        assertThat(antiflicker.value, `is`(.unknown))

        // change capabilities
        impl.update(supportedModes: [.mode50Hz, .mode60Hz, .auto]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(antiflicker.setting, supports(modes: [.mode50Hz, .mode60Hz, .auto]))

        // change mode
        impl.update(mode: .mode50Hz).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(antiflicker.setting, `is`(mode: .mode50Hz, updating: false))

        // change value
        impl.update(value: .value50Hz).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(antiflicker.value, `is`(.value50Hz))
    }

    func testChangeMode() {
        impl.publish()
        var cnt = 0
        let antiflicker = store.get(Peripherals.antiflicker)!
        _ = store.register(desc: Peripherals.antiflicker) {
            cnt += 1
        }
        impl.update(supportedModes: [.mode50Hz, .mode60Hz]).notifyUpdated()
        assertThat(cnt, `is`(1))

        // change mode
        antiflicker.setting.mode = .mode50Hz
        assertThat(cnt, `is`(2))
        assertThat(backend.mode, presentAnd(`is`(.mode50Hz)))
        assertThat(antiflicker.setting, `is`(mode: .mode50Hz, updating: true))

        impl.update(mode: .mode50Hz).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(antiflicker.setting, `is`(mode: .mode50Hz, updating: false))

        // timeout should not do anything
        (antiflicker.setting as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(3))
        assertThat(antiflicker.setting, `is`(mode: .mode50Hz, updating: false))

        // change to an unsupported mode
        antiflicker.setting.mode = .auto
        assertThat(cnt, `is`(3))
        assertThat(backend.mode, presentAnd(`is`(.mode50Hz)))

        // change setting
        antiflicker.setting.mode = .mode60Hz
        assertThat(cnt, `is`(4))
        assertThat(antiflicker.setting, `is`(mode: .mode60Hz, updating: true))

        // mock timeout
        (antiflicker.setting as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(antiflicker.setting, `is`(mode: .mode50Hz, updating: false))

        // change mode
        antiflicker.setting.mode = .mode60Hz
        assertThat(cnt, `is`(6))
        assertThat(antiflicker.setting, `is`(mode: .mode60Hz, updating: true))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(7))
        assertThat(antiflicker.setting, `is`(mode: .mode60Hz, updating: false))

        // timeout should not be triggered since it has been canceled
        (antiflicker.setting as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(7))
        assertThat(antiflicker.setting, `is`(mode: .mode60Hz, updating: false))
    }
}

private class Backend: AntiflickerBackend {
    var mode: AntiflickerMode?

    func set(mode: AntiflickerMode) -> Bool {
        self.mode = mode
        return true
    }
}
