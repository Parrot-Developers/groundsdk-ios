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

/// Test FlyingIndicators instrument
class FlyingIndicatorsTest: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: FlyingIndicatorsCore!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        impl = FlyingIndicatorsCore(store: store)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store.get(Instruments.flyingIndicators), present())
        impl.unpublish()
        assertThat(store.get(Instruments.flyingIndicators), nilValue())
    }

    func testStateAndFlyingState() {
        impl.publish()
        var cnt = 0
        let flyingIndicators = store.get(Instruments.flyingIndicators)!
        _ = store.register(desc: Instruments.flyingIndicators) {
            cnt += 1
        }
        // check inital value
        assertThat(flyingIndicators, `is`(.landed, .initializing, .none))

        // check set state
        impl.update(landedState: .initializing).notifyUpdated()
        assertThat(cnt, `is`(0))
        assertThat(flyingIndicators, `is`(.landed, .initializing, .none))

        // check set state
        impl.update(landedState: .idle).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(flyingIndicators, `is`(.landed, .idle, .none))

        // check set state
        impl.update(landedState: .waitingUserAction).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(flyingIndicators, `is`(.landed, .waitingUserAction, .none))

        // check set flying state, should also change state to flying
        impl.update(flyingState: .takingOff).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(flyingIndicators, `is`(.flying, .none, .takingOff))

        // check set state to not flying, should also change flying state to none
        impl.update(state: .emergency).notifyUpdated()
        assertThat(cnt, `is`(4))
        assertThat(flyingIndicators, `is`(.emergency, .none, .none))

        // Back to flying state, should also change state to flying
        impl.update(flyingState: .flying).notifyUpdated()
        assertThat(cnt, `is`(5))
        assertThat(flyingIndicators, `is`(.flying, .none, .flying))

        // Emergency landing
        impl.update(state: .emergencyLanding).notifyUpdated()
        assertThat(cnt, `is`(6))
        assertThat(flyingIndicators, `is`(.emergencyLanding, .none, .none))

        // test notify without changes
        impl.notifyUpdated()
        assertThat(cnt, `is`(6))
    }
}
