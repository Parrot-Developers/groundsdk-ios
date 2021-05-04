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

    func testSupportedTypes() {
        impl.publish()
        var cnt = 0
        let dri = store.get(Peripherals.dri)!
        _ = store.register(desc: Peripherals.dri) {
            cnt += 1
        }

        // test initial value
        assertThat(dri.type.supportedTypes, empty())
        assertThat(cnt, `is`(0))

        // update from backend
        impl.update(supportedTypes: [.en4709_002]).notifyUpdated()
        assertThat(dri.type, present())
        assertThat(dri.type.supportedTypes, `is`([.en4709_002]))
        assertThat(cnt, `is`(1))

        // update from backend
        impl.update(supportedTypes: Set(DriType.allCases)).notifyUpdated()
        assertThat(dri.type.supportedTypes, `is`(Set(DriType.allCases)))
        assertThat(cnt, `is`(2))

        // same update from backend, should change nothing
        impl.update(supportedTypes: Set(DriType.allCases)).notifyUpdated()
        assertThat(dri.type.supportedTypes, `is`(Set(DriType.allCases)))
        assertThat(cnt, `is`(2))
    }

    func testTypeState() {
        impl.publish()
        var cnt = 0
        let dri = store.get(Peripherals.dri)!
        _ = store.register(desc: Peripherals.dri) {
            cnt += 1
        }

        // test initial value
        assertThat(dri.type.state, nilValue())
        assertThat(cnt, `is`(0))

        // update from backend
        impl.update(typeState: .updating).notifyUpdated()
        assertThat(dri.type.state, `is`(.updating))
        assertThat(cnt, `is`(1))

        // same update from backend, should change nothing
        impl.update(typeState: .updating).notifyUpdated()
        assertThat(dri.type.state, `is`(.updating))
        assertThat(cnt, `is`(1))

        // update from backend
        impl.update(typeState: .configured(type: .french)).notifyUpdated()
        assertThat(dri.type.state, `is`(.configured(type: .french)))
        assertThat(cnt, `is`(2))

        // update from backend
        impl.update(typeState: .configured(type: .en4709_002(operatorId: "operator1"))).notifyUpdated()
        assertThat(dri.type.state, `is`(.configured(type: .en4709_002(operatorId: "operator1"))))
        assertThat(cnt, `is`(3))

        // update from backend
        impl.update(typeState: .configured(type: .en4709_002(operatorId: "operator2"))).notifyUpdated()
        assertThat(dri.type.state, `is`(.configured(type: .en4709_002(operatorId: "operator2"))))
        assertThat(cnt, `is`(4))

        // same update from backend, should change nothing
        impl.update(typeState: .configured(type: .en4709_002(operatorId: "operator2"))).notifyUpdated()
        assertThat(dri.type.state, `is`(.configured(type: .en4709_002(operatorId: "operator2"))))
        assertThat(cnt, `is`(4))

        // same update from backend
        impl.update(typeState: nil).notifyUpdated()
        assertThat(dri.type.state, nilValue())
        assertThat(cnt, `is`(5))
    }

    func testTypeConfig() {
        impl.update(supportedTypes: Set(DriType.allCases))
        impl.publish()
        var cnt = 0
        let dri = store.get(Peripherals.dri)!
        _ = store.register(desc: Peripherals.dri) {
            cnt += 1
        }

        // test initial value
        assertThat(dri.type.type, nilValue())
        assertThat(backend.type, nilValue())
        assertThat(cnt, `is`(0))

        // change from api
        dri.type.type = .french
        assertThat(dri.type.type, nilValue())
        assertThat(backend.type, `is`(.french))
        assertThat(cnt, `is`(0))

        // update from backend
        impl.update(type: .french).notifyUpdated()
        assertThat(dri.type.type, `is`(.french))
        assertThat(cnt, `is`(1))

        // set to same value from api, should change nothing
        backend.type = nil
        dri.type.type = .french
        assertThat(dri.type.type, `is`(.french))
        assertThat(backend.type, nilValue())
        assertThat(cnt, `is`(1))

        // change from api with an invalid operator identifier, should change nothing
        dri.type.type = .en4709_002(operatorId: "invalidOperatorId")
        assertThat(dri.type.type, `is`(.french))
        assertThat(backend.type, nilValue())
        assertThat(cnt, `is`(1))

        // change from api with a valid operator identifier
        dri.type.type = .en4709_002(operatorId: "FIN87astrdge12k8-xyz")
        assertThat(dri.type.type, `is`(.french))
        assertThat(backend.type, `is`(.en4709_002(operatorId: "FIN87astrdge12k8-xyz")))
        assertThat(cnt, `is`(1))

        // update from backend
        impl.update(type: .en4709_002(operatorId: "FIN87astrdge12k8-xyz")).notifyUpdated()
        assertThat(dri.type.type, `is`(.en4709_002(operatorId: "FIN87astrdge12k8-xyz")))
        assertThat(cnt, `is`(2))

        // same update from backend, should change nothing
        impl.update(type: .en4709_002(operatorId: "FIN87astrdge12k8-xyz")).notifyUpdated()
        assertThat(dri.type.type, `is`(.en4709_002(operatorId: "FIN87astrdge12k8-xyz")))
        assertThat(cnt, `is`(2))

        // change from api with a another operator identifier
        dri.type.type = .en4709_002(operatorId: "FRAgroundsdktstp-abc")
        assertThat(dri.type.type, `is`(.en4709_002(operatorId: "FIN87astrdge12k8-xyz")))
        assertThat(backend.type, `is`(.en4709_002(operatorId: "FRAgroundsdktstp-abc")))
        assertThat(cnt, `is`(2))

        // update from backend
        impl.update(type: .en4709_002(operatorId: "FRAgroundsdktstp-abc")).notifyUpdated()
        assertThat(dri.type.type, `is`(.en4709_002(operatorId: "FRAgroundsdktstp-abc")))
        assertThat(cnt, `is`(3))
    }

    func testDriTypeConfigValidation() {
        assertThat(DriTypeConfig.french.isValid, `is`(true))
        assertThat(DriTypeConfig.en4709_002(operatorId: "FIN87astrdge12k8-xyz").isValid, `is`(true))
        assertThat(DriTypeConfig.en4709_002(operatorId: "fin87astrdge12k8-xyz").isValid, `is`(false))
        assertThat(DriTypeConfig.en4709_002(operatorId: "FIN87Astrdge12k8-xyz").isValid, `is`(false))
        assertThat(DriTypeConfig.en4709_002(operatorId: "FIN87bstrdge12k8-xyz").isValid, `is`(false))
        assertThat(DriTypeConfig.en4709_002(operatorId: "FIN87astrdge12k8.xyz").isValid, `is`(false))
        assertThat(DriTypeConfig.en4709_002(operatorId: "FIN87astrdge12k0-xyz").isValid, `is`(false))
        assertThat(DriTypeConfig.en4709_002(operatorId: "FIN87astrdge12k8-xyy").isValid, `is`(false))
        assertThat(DriTypeConfig.en4709_002(operatorId: "FIN87astrdge12k8").isValid, `is`(false))
    }
}

private class Backend: DriBackend {
    var mode: Bool = false
    var type: DriTypeConfig?

    func set(mode: Bool) -> Bool {
        self.mode = mode
        return true
    }

    func set(type: DriTypeConfig?) {
        self.type = type
    }
}
