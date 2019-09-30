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

/// Test PilotingControl peripheral
class PilotingControlTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: PilotingControlCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = PilotingControlCore(store: store!, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.pilotingControl), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.pilotingControl), nilValue())
    }

    func testDefaultAndSupportedValues() {
        impl.publish()
        assertThat(store!.get(Peripherals.pilotingControl), present())
        var cnt = 0
        let pilotingControl = store.get(Peripherals.pilotingControl)!
        _ = store.register(desc: Peripherals.pilotingControl) {
            cnt += 1
        }

        // test initial value
        let emptySupportedBehaviours: Set<PilotingBehaviour> = []
        let fullSupportedBehaviours: Set<PilotingBehaviour> = [.standard, .cameraOperated]
        let onlyStandardSupportedBehaviours: Set<PilotingBehaviour> = [.standard]
        assertThat(pilotingControl.behaviourSetting.value, `is`(.standard))
        assertThat(pilotingControl.behaviourSetting.supportedBehaviours, `is`(emptySupportedBehaviours))
        assertThat(cnt, `is`(0))

        impl.update(supportedBehaviours: fullSupportedBehaviours).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(pilotingControl.behaviourSetting.value, `is`(.standard))
        assertThat(pilotingControl.behaviourSetting.supportedBehaviours, `is`(fullSupportedBehaviours))

        impl.update(supportedBehaviours: onlyStandardSupportedBehaviours).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(pilotingControl.behaviourSetting.value, `is`(.standard))
        assertThat(pilotingControl.behaviourSetting.supportedBehaviours, `is`(onlyStandardSupportedBehaviours))

        // update the same value, changes nothing
        impl.update(supportedBehaviours: onlyStandardSupportedBehaviours).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(pilotingControl.behaviourSetting.value, `is`(.standard))
        assertThat(pilotingControl.behaviourSetting.supportedBehaviours, `is`(onlyStandardSupportedBehaviours))
    }

    func testUpdateSetting() {
        impl.publish()
        assertThat(store!.get(Peripherals.pilotingControl), present())
        var cnt = 0
        let pilotingControl = store.get(Peripherals.pilotingControl)!
        _ = store.register(desc: Peripherals.pilotingControl) {
            cnt += 1
        }

        // test initial value
        let emptySupportedBehaviours: Set<PilotingBehaviour> = []
        let fullSupportedBehaviours: Set<PilotingBehaviour> = [.standard, .cameraOperated]
        assertThat(pilotingControl.behaviourSetting.value, `is`(.standard))
        assertThat(pilotingControl.behaviourSetting.supportedBehaviours, `is`(emptySupportedBehaviours))
        assertThat(cnt, `is`(0))

        impl.update(supportedBehaviours: fullSupportedBehaviours).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(pilotingControl.behaviourSetting.value, `is`(.standard))
        assertThat(pilotingControl.behaviourSetting.supportedBehaviours, `is`(fullSupportedBehaviours))

        // change to camera operated
        impl.behaviourSetting.value = .cameraOperated
        assertThat(impl.behaviourSetting, `is`(value: .cameraOperated, updating: true))
        assertThat(cnt, `is`(2))
    }

    func testGuardUnsupportedSeeting() {
        impl.publish()
        assertThat(store!.get(Peripherals.pilotingControl), present())
        var cnt = 0
        let pilotingControl = store.get(Peripherals.pilotingControl)!
        _ = store.register(desc: Peripherals.pilotingControl) {
            cnt += 1
        }

        // test initial value
        let emptySupportedBehaviours: Set<PilotingBehaviour> = []
        let onlyStandardSupportedBehaviours: Set<PilotingBehaviour> = [.standard]
        assertThat(pilotingControl.behaviourSetting.value, `is`(.standard))
        assertThat(pilotingControl.behaviourSetting.supportedBehaviours, `is`(emptySupportedBehaviours))
        assertThat(cnt, `is`(0))

        impl.update(supportedBehaviours: onlyStandardSupportedBehaviours).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(pilotingControl.behaviourSetting.value, `is`(.standard))
        assertThat(pilotingControl.behaviourSetting.supportedBehaviours, `is`(onlyStandardSupportedBehaviours))

        // change to camera operated
        impl.behaviourSetting.value = .cameraOperated
        assertThat(impl.behaviourSetting, `is`(value: .standard, updating: false))
        assertThat(cnt, `is`(2))
    }
}

private class Backend: PilotingControlBackend {
    func set(behaviour: PilotingBehaviour) -> Bool {
        return true
    }
}
