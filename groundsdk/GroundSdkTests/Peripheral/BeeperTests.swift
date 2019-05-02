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

/// Test Beeper peripheral
class BeeperTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: BeeperCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = BeeperCore(store: store!, backend: backend!)
        backend.impl = impl
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.beeper), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.beeper), nilValue())
    }

    func testAlertSoundPlaying() {
        impl.publish()
        var cnt = 0
        let beeper = store.get(Peripherals.beeper)!
        _ = store.register(desc: Peripherals.beeper) {
            cnt += 1
        }

        // test initial value
        assertThat(beeper.alertSoundPlaying, `is`(false))
        assertThat(cnt, `is`(0))

        // change alertSoundPlaying value
        impl.update(alertSoundPlaying: true).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(beeper.alertSoundPlaying, `is`(true))

        // setting the same firmware version should not change anything
        impl.update(alertSoundPlaying: true).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(beeper.alertSoundPlaying, `is`(true))
    }

    func testStartAndStop() {
        impl.publish()
        var cnt = 0
        let beeper = store.get(Peripherals.beeper)!
        _ = store.register(desc: Peripherals.beeper) {
            cnt += 1
        }

        assertThat(store!.get(Peripherals.beeper), present())
        // test initial value
        assertThat(beeper.alertSoundPlaying, `is`(false))
        assertThat(cnt, `is`(0))
        assertThat(backend.playing, `is`(false))

        // send a start
        var result = beeper.startAlertSound()
        assertThat(backend.playing, `is`(true))
        assertThat(result, `is`(true))
        assertThat(cnt, `is`(1))

        // send a start again (no change)
        result = beeper.startAlertSound()
        assertThat(backend.playing, `is`(true))
        assertThat(result, `is`(false))
        assertThat(cnt, `is`(1))

        // send a stop
        result = beeper.stopAlertSound()
        assertThat(backend.playing, `is`(false))
        assertThat(result, `is`(true))
        assertThat(cnt, `is`(2))

        // send a stop again (no change)
        result = beeper.stopAlertSound()
        assertThat(backend.playing, `is`(false))
        assertThat(result, `is`(false))
        assertThat(cnt, `is`(2))
    }
}

private class Backend: BeeperBackend {

    var impl: BeeperCore?

    var playing = false {
        didSet {
            if oldValue != playing {
                impl?.update(alertSoundPlaying: playing).notifyUpdated()
            }
        }
    }

    func stopAlertSound() -> Bool {
        playing = false
        return true
    }

    func startAlertSound() -> Bool {
        playing = true
        return true
    }
}
