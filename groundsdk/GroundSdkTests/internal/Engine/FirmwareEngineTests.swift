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
//    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES LOSS
//    OF USE, DATA, OR PROFITS OR BUSINESS INTERRUPTION) HOWEVER CAUSED
//    AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
//    OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//    SUCH DAMAGE.

import XCTest
@testable import GroundSdk
import GroundSdkMock

class FirmwareEngineTests: XCTestCase {

    var updateManagerRef: Ref<FirmwareManager>!
    var updateManager: FirmwareManager?
    var changeCnt = 0

    let httpSession = MockHttpSession()
    let droneStore = DroneStoreUtilityCore()
    let rcStore = RemoteControlStoreUtilityCore()

    // need to be retained (normally retained by the EnginesController)
    private let utilityRegistry = UtilityCoreRegistry()
    private let facilityStore = ComponentStoreCore()
    private var enginesController: MockEnginesController!

    private var engine: FirmwareEngine!

    override func setUp() {
        super.setUp()

        utilityRegistry.publish(utility: CloudServerCore(
            utilityRegistry: utilityRegistry, httpSession: httpSession, bgHttpSession: httpSession))
        utilityRegistry.publish(utility: droneStore)
        utilityRegistry.publish(utility: rcStore)

        enginesController = MockEnginesController(
            utilityRegistry: utilityRegistry,
            facilityStore: facilityStore,
            initEngineClosure: {
                self.engine = FirmwareEngine(enginesController: $0)
                return [self.engine]

        })

        updateManagerRef = ComponentRefCore(
            store: facilityStore,
            desc: Facilities.firmwareManager) { [unowned self] updateManager in
                self.updateManager = updateManager
                self.changeCnt += 1
        }
    }

   func testPublishUnpublish() {
        // should be unavailable when the engine is not started
        assertThat(updateManager, nilValue())

        enginesController.start()

        assertThat(updateManager, present())
        assertThat(changeCnt, `is`(1))

        enginesController.stop()
        assertThat(updateManager, nilValue())
        assertThat(changeCnt, `is`(2))
    }

    // TODO: test the engine
}
