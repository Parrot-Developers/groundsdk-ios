// Copyright (C) 2020 Parrot Drones SAS
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

import Foundation

import XCTest
@testable import GroundSdk

/// Test Leds peripheral
class BatteryGaugeUpdaterTests: XCTestCase {
    private var store: ComponentStoreCore!
    private var impl: BatteryGaugeUpdaterCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = BatteryGaugeUpdaterCore(store: store!, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.batteryGaugeUpdater), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.batteryGaugeUpdater), nilValue())
    }

    func testProgress() {
        impl.publish()
        assertThat(impl.currentProgress, `is`(0))

        impl.update(progress: 50)
        assertThat(impl.currentProgress, `is`(50))

        impl.update(progress: 100)
        assertThat(impl.currentProgress, `is`(100))
    }

    func testState() {
        impl.publish()
        assertThat(impl.state, `is`(.readyToPrepare))

        impl.update(state: .readyToUpdate)
        assertThat(impl.state, `is`(.readyToUpdate))

        impl.update(state: .preparingUpdate)
        assertThat(impl.state, `is`(.preparingUpdate))

        impl.update(state: .readyToPrepare)
        assertThat(impl.state, `is`(.readyToPrepare))

        impl.update(state: .updating)
        assertThat(impl.state, `is`(.updating))
    }

    func testUnavailabilityReasons() {
        impl.publish()
        assertThat(impl.unavailabilityReasons, `is`([]))

        impl.update(unavailabilityReasons: [.droneNotLanded, .insufficientCharge])
        assertThat(impl.unavailabilityReasons, `is`([.droneNotLanded, .insufficientCharge]))

        impl.update(unavailabilityReasons: [.insufficientCharge])
        assertThat(impl.unavailabilityReasons, `is`([.insufficientCharge]))
    }

    func testPrepareUpdate() {
        impl.publish()
        assertThat(impl.unavailabilityReasons, `is`([]))
        assertThat(backend.prepareUpdateInt, `is`(0))

        assertThat(impl.prepareUpdate(), `is`(true))
        assertThat(backend.prepareUpdateInt, `is`(1))

        impl.update(unavailabilityReasons: [.droneNotLanded, .insufficientCharge])
        assertThat(impl.prepareUpdate(), `is`(false))
        assertThat(backend.prepareUpdateInt, `is`(1))
    }

    func testUpdate() {
        impl.publish()
        assertThat(impl.unavailabilityReasons, `is`([]))
        assertThat(backend.updateInt, `is`(0))
        impl.update(state: .readyToUpdate)

        assertThat(impl.update(), `is`(true))
        assertThat(backend.updateInt, `is`(1))

        impl.update(unavailabilityReasons: [.droneNotLanded, .insufficientCharge])
        assertThat(impl.update(), `is`(false))
        assertThat(backend.updateInt, `is`(1))
    }
}

private class Backend: BatteryGaugeUpdaterBackend {
    var prepareUpdateInt = 0
    var updateInt = 0

    func prepareUpdate() {
        prepareUpdateInt += 1
    }

    func update() {
        updateInt += 1
    }
}
