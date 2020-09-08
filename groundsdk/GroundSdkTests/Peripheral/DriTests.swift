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

import XCTest
@testable import GroundSdk

/// Test Dri peripheral
class DriTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: DriCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = DriCore(store: store!, backend: backend!)
        backend.impl = impl
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.dri), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.dri), nilValue())
    }

    func testModeUpdate() {
        impl.update(mode: false)
        impl.publish()
        var cnt = 0
        let dri = store.get(Peripherals.dri)!
        _ = store.register(desc: Peripherals.dri) {
            cnt += 1
        }

        // test initial value
        assertThat(dri.mode!.value, `is`(false))
        assertThat(cnt, `is`(0))

        // change mode value
        impl.update(mode: true).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(dri.mode!.value, `is`(true))

        // setting the same mode should not change anything
        impl.update(mode: true).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(dri.mode!.value, `is`(true))
    }

    func testMode() {
        impl.update(mode: false)
        impl.publish()
        var cnt = 0
        let dri = store.get(Peripherals.dri)!
        _ = store.register(desc: Peripherals.dri) {
            cnt += 1
        }

        assertThat(store!.get(Peripherals.dri), present())
         // test initial value
         assertThat(dri.mode!, `is`(false))
         assertThat(cnt, `is`(0))
         assertThat(backend.mode, `is`(false))

         // Activate switch mode
         dri.mode!.value = true
         assertThat(backend.mode, `is`(true))
         assertThat(cnt, `is`(1))

         // switch mode already enabled, nothing should happen
         dri.mode!.value = true
         assertThat(backend.mode, `is`(true))
         assertThat(cnt, `is`(1))

         // Disable switch mode
         dri.mode!.value = false
         assertThat(backend.mode, `is`(false))
         assertThat(cnt, `is`(2))

         // switch mode already disabled, nothing should happen
         dri.mode!.value = false
         assertThat(backend.mode, `is`(false))
         assertThat(cnt, `is`(2))
    }

    func testTypeAndid() {
        impl.update(mode: false)
        impl.publish()
        var cnt = 0
        let dri = store.get(Peripherals.dri)!
        _ = store.register(desc: Peripherals.dri) {
            cnt += 1
        }

        assertThat(store!.get(Peripherals.dri), present())
        // test initial value
        assertThat(dri.mode!, `is`(false))
        assertThat(cnt, `is`(0))
        assertThat(backend.mode, `is`(false))

        // Activate switch mode
        dri.mode!.value = true
        assertThat(backend.mode, `is`(true))
        assertThat(cnt, `is`(1))

        impl.update(droneId: DriCore.DroneIdentifier(type: .FR_30_Octets,
                              id: "123456789012345678901234567890")).notifyUpdated()
        assertThat(dri.droneId?.type, `is`(.FR_30_Octets))
        assertThat(dri.droneId?.id, `is`("123456789012345678901234567890"))
        assertThat(cnt, `is`(2))

        impl.update(droneId: DriCore.DroneIdentifier(type: .ANSI_CTA_2063,
                             id: "1234567890123456789012345678901234567890")).notifyUpdated()
        assertThat(dri.droneId?.type, `is`(.ANSI_CTA_2063))
        assertThat(dri.droneId?.id, `is`("1234567890123456789012345678901234567890"))
        assertThat(cnt, `is`(3))
    }
}

private class Backend: DriBackend {
    var mode: Bool = false

    func set(mode: Bool) -> Bool {
        self.mode = mode
        return true
    }

    var impl: DriCore?
}
