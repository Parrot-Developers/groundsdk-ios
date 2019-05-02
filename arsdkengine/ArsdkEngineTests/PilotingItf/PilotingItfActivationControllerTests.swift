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

import Foundation
import XCTest
@testable import ArsdkEngine
@testable import GroundSdk
import SdkCoreTesting

class PilotingItfActivationControllerTests: ArsdkEngineTestBase {

    var droneController: DroneController!
    private var defaultPilotingItfController: MockActivablePilotingItfController!
    private var pilotingItf2Controller: MockActivablePilotingItfController!
    private var pilotingItf3Controller: MockActivablePilotingItfController!

    private var defaultPilotingItf: MockActivablePilotingItfCore {
        return defaultPilotingItfController.pilotingItf as! MockActivablePilotingItfCore
    }
    private var pilotingItf2: MockActivablePilotingItfCore {
        return pilotingItf2Controller.pilotingItf as! MockActivablePilotingItfCore
    }
    private var pilotingItf3: MockActivablePilotingItfCore {
        return pilotingItf3Controller.pilotingItf as! MockActivablePilotingItfCore
    }

    override func setUp() {
        super.setUp()

        droneController = DroneController(
            engine: arsdkEngine, deviceUid: "123", model: .anafi4k, name: "anafi4k",
            pcmdEncoder: PilotingCommand.Encoder.AnafiCopter(),
            defaultPilotingItfFactory: { activationController in
                return MockActivablePilotingItfController(activationController: activationController)
        })
        defaultPilotingItfController =
            droneController.pilotingItfActivationController.defaultPilotingItf as? MockActivablePilotingItfController
        pilotingItf2Controller = MockActivablePilotingItfController(
            activationController: droneController.pilotingItfActivationController)
        pilotingItf3Controller = MockActivablePilotingItfController(
            activationController: droneController.pilotingItfActivationController)

        MockActivablePilotingItfController.reset()
    }

    func testInitialState() {
        // check initial state
        assertThat(defaultPilotingItf.state, `is`(.unavailable))
        assertThat(pilotingItf2.state, `is`(.unavailable))
        assertThat(pilotingItf3.state, `is`(.unavailable))
    }

    func testActivateDefault() {
        // the default piloting itf is idle
        defaultPilotingItfController.set(state: .idle)
        assertThat(defaultPilotingItf.state, `is`(.idle))
        assertThat(pilotingItf2.state, `is`(.unavailable))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(0))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))

        // set the default piloting itf as active
        defaultPilotingItfController.set(state: .active)
        assertThat(defaultPilotingItf.state, `is`(.active))
        assertThat(pilotingItf2.state, `is`(.unavailable))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(0))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))
    }

    func testActivateActiveItf() {
        // the default piloting itf is active
        defaultPilotingItfController.set(state: .active)
        assertThat(defaultPilotingItf.state, `is`(.active))
        assertThat(pilotingItf2.state, `is`(.unavailable))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(0))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))

        // can not activate an active piloting itf
        let result = defaultPilotingItf.activate()
        assertThat(result, `is`(false))
        assertThat(defaultPilotingItf.state, `is`(.active))
        assertThat(pilotingItf2.state, `is`(.unavailable))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(0))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))
    }

    func testActivateUnavailableItf() {
        // initial state: all unavailable
        assertThat(defaultPilotingItf.state, `is`(.unavailable))
        assertThat(pilotingItf2.state, `is`(.unavailable))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(0))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))

        // can not activate an unavailable piloting itf
        let result = defaultPilotingItf.activate()
        assertThat(result, `is`(false))
        assertThat(defaultPilotingItf.state, `is`(.unavailable))
        assertThat(pilotingItf2.state, `is`(.unavailable))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(0))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))
    }

    func testDeactivateDefaultItf() {
        // initial state: default is active
        defaultPilotingItfController.set(state: .active)
        assertThat(defaultPilotingItf.state, `is`(.active))
        assertThat(pilotingItf2.state, `is`(.unavailable))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(0))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))

        // can not deactivate a default piloting itf
        let result = defaultPilotingItf.deactivate()
        assertThat(result, `is`(false))
        assertThat(defaultPilotingItf.state, `is`(.active))
        assertThat(pilotingItf2.state, `is`(.unavailable))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(0))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))
    }

    func testActivation() {
        // initial state: default is active
        defaultPilotingItfController.set(state: .active)
        assertThat(defaultPilotingItf.state, `is`(.active))
        assertThat(pilotingItf2.state, `is`(.unavailable))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(0))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))

        // set the piloting itf 2 to idle in order to be able to activate it
        pilotingItf2Controller.set(state: .idle)
        assertThat(defaultPilotingItf.state, `is`(.active))
        assertThat(pilotingItf2.state, `is`(.idle))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(0))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))

        // activate pilotingItf2
        let result = pilotingItf2.activate()
        assertThat(result, `is`(true))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.deactivatedPilotingItf,
                   presentAnd(`is`(defaultPilotingItfController)))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))
        // no state should change for the moment
        assertThat(defaultPilotingItf.state, `is`(.active))
        assertThat(pilotingItf2.state, `is`(.idle))
        assertThat(pilotingItf3.state, `is`(.unavailable))

        // mock deactivation answer from low-level
        defaultPilotingItfController.set(state: .idle)
        assertThat(defaultPilotingItf.state, `is`(.idle))
        assertThat(pilotingItf2.state, `is`(.idle))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.activatedPilotingItf, presentAnd(`is`(pilotingItf2Controller)))

        // mock answer from low level
        pilotingItf2Controller.set(state: .active)
        assertThat(defaultPilotingItf.state, `is`(.idle))
        assertThat(pilotingItf2.state, `is`(.active))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(1))
    }

    func testDeactivateNonDefaultItf() {
        // initial state: default is idle, pilotingItf2 is active
        defaultPilotingItfController.set(state: .idle)
        pilotingItf2Controller.set(state: .active)
        assertThat(defaultPilotingItf.state, `is`(.idle))
        assertThat(pilotingItf2.state, `is`(.active))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(0))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))

        // deactivate a non-default piloting itf should activate the default one
        let result = pilotingItf2.deactivate()
        assertThat(result, `is`(true))
        assertThat(defaultPilotingItf.state, `is`(.idle))
        assertThat(pilotingItf2.state, `is`(.active))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.deactivatedPilotingItf, presentAnd(`is`(pilotingItf2Controller)))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))

        // mock deactivation answer from low-level
        pilotingItf2Controller.set(state: .idle)
        assertThat(defaultPilotingItf.state, `is`(.idle))
        assertThat(pilotingItf2.state, `is`(.idle))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.activatedPilotingItf,
                   presentAnd(`is`(defaultPilotingItfController)))

        // mock activation answer from low-level
        defaultPilotingItfController.set(state: .active)
        assertThat(defaultPilotingItf.state, `is`(.active))
        assertThat(pilotingItf2.state, `is`(.idle))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(1))
    }

    func testActivateNext() {
        // initial state: default is idle, pilotingItf2 is active
        defaultPilotingItfController.set(state: .active)
        pilotingItf2Controller.set(state: .idle)
        pilotingItf3Controller.set(state: .idle)
        assertThat(defaultPilotingItf.state, `is`(.active))
        assertThat(pilotingItf2.state, `is`(.idle))
        assertThat(pilotingItf3.state, `is`(.idle))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(0))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))

        // activate pilotingItf2
        var result = pilotingItf2.activate()
        assertThat(result, `is`(true))
        assertThat(defaultPilotingItf.state, `is`(.active))
        assertThat(pilotingItf2.state, `is`(.idle))
        assertThat(pilotingItf3.state, `is`(.idle))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.deactivatedPilotingItf,
                   presentAnd(`is`(defaultPilotingItfController)))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))

        // mock deactivation answer from low-level
        defaultPilotingItfController.set(state: .idle)
        assertThat(defaultPilotingItf.state, `is`(.idle))
        assertThat(pilotingItf2.state, `is`(.idle))
        assertThat(pilotingItf3.state, `is`(.idle))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.activatedPilotingItf, presentAnd(`is`(pilotingItf2Controller)))

        // mock activation answer from low-level
        pilotingItf2Controller.set(state: .active)
        assertThat(defaultPilotingItf.state, `is`(.idle))
        assertThat(pilotingItf2.state, `is`(.active))
        assertThat(pilotingItf3.state, `is`(.idle))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(1))

        // activate pilotingItf3
        result = pilotingItf3.activate()
        assertThat(result, `is`(true))
        assertThat(defaultPilotingItf.state, `is`(.idle))
        assertThat(pilotingItf2.state, `is`(.active))
        assertThat(pilotingItf3.state, `is`(.idle))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(2))
        assertThat(MockActivablePilotingItfController.deactivatedPilotingItf, presentAnd(`is`(pilotingItf2Controller)))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(1))

        // mock deactivation answer from low-level
        pilotingItf2Controller.set(state: .idle)
        assertThat(defaultPilotingItf.state, `is`(.idle))
        assertThat(pilotingItf2.state, `is`(.idle))
        assertThat(pilotingItf3.state, `is`(.idle))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(2))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(2))
        assertThat(MockActivablePilotingItfController.activatedPilotingItf, presentAnd(`is`(pilotingItf3Controller)))

        // mock activation answer from low-level
        pilotingItf3Controller.set(state: .active)
        assertThat(defaultPilotingItf.state, `is`(.idle))
        assertThat(pilotingItf2.state, `is`(.idle))
        assertThat(pilotingItf3.state, `is`(.active))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(2))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(2))
    }

    func testActivePilotingItfGoesUnavailable() {
        // initial state: default is idle, pilotingItf1 is active
        defaultPilotingItfController.set(state: .idle)
        pilotingItf2Controller.set(state: .active)
        assertThat(defaultPilotingItf.state, `is`(.idle))
        assertThat(pilotingItf2.state, `is`(.active))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(0))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))

        // mock pilotingItf2 goes unavailable
        pilotingItf2Controller.set(state: .unavailable)
        assertThat(defaultPilotingItf.state, `is`(.idle))
        assertThat(pilotingItf2.state, `is`(.unavailable))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(0))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.activatedPilotingItf,
                   presentAnd(`is`(defaultPilotingItfController)))

        // mock activation answer
        defaultPilotingItfController.set(state: .active)
        assertThat(defaultPilotingItf.state, `is`(.active))
        assertThat(pilotingItf2.state, `is`(.unavailable))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(0))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(1))
    }

    func testDesiredActivePilotingItfGoesUnavailableWhenDisconnected() {
        // initial state: default is active, pilotingItf1 is idle
        defaultPilotingItfController.set(state: .active)
        pilotingItf2Controller.set(state: .idle)
        assertThat(defaultPilotingItf.state, `is`(.active))
        assertThat(pilotingItf2.state, `is`(.idle))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(0))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))

        // activate pilotingItf2
        let result = pilotingItf2.activate()
        assertThat(result, `is`(true))
        assertThat(defaultPilotingItf.state, `is`(.active))
        assertThat(pilotingItf2.state, `is`(.idle))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.deactivatedPilotingItf,
                   presentAnd(`is`(defaultPilotingItfController)))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))

        // mock deactivation answer from low-level
        defaultPilotingItfController.set(state: .idle)
        assertThat(defaultPilotingItf.state, `is`(.idle))
        assertThat(pilotingItf2.state, `is`(.idle))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.activatedPilotingItf, presentAnd(`is`(pilotingItf2Controller)))

        // mock pilotingItf2 goes unavailable
        pilotingItf2Controller.set(state: .unavailable)
        assertThat(defaultPilotingItf.state, `is`(.idle))
        assertThat(pilotingItf2.state, `is`(.unavailable))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(1))

        defaultPilotingItfController.set(state: .active)
        assertThat(defaultPilotingItf.state, `is`(.active))
        assertThat(pilotingItf2.state, `is`(.unavailable))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(1))
    }

    func testDesiredActivePilotingItfGoesUnavailableWhenConnected() {
        // initial state: default is active, pilotingItf1 is idle
        defaultPilotingItfController.set(state: .active)
        pilotingItf2Controller.set(state: .idle)
        assertThat(defaultPilotingItf.state, `is`(.active))
        assertThat(pilotingItf2.state, `is`(.idle))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(0))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))

        // drone is connected
        droneController.pilotingItfActivationController.didConnect()

        // activate pilotingItf2
        let result = pilotingItf2.activate()
        assertThat(result, `is`(true))
        assertThat(defaultPilotingItf.state, `is`(.active))
        assertThat(pilotingItf2.state, `is`(.idle))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.deactivatedPilotingItf,
                   presentAnd(`is`(defaultPilotingItfController)))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))

        // mock deactivation answer from low-level
        defaultPilotingItfController.set(state: .idle)
        assertThat(defaultPilotingItf.state, `is`(.idle))
        assertThat(pilotingItf2.state, `is`(.idle))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.activatedPilotingItf, presentAnd(`is`(pilotingItf2Controller)))

        // mock pilotingItf2 goes unavailable
        pilotingItf2Controller.set(state: .unavailable)
        assertThat(defaultPilotingItf.state, `is`(.idle))
        assertThat(pilotingItf2.state, `is`(.unavailable))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(1))
        // when connected, default piloting itf activation should be requested
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(2))
        assertThat(MockActivablePilotingItfController.activatedPilotingItf,
                   presentAnd(`is`(defaultPilotingItfController)))

        defaultPilotingItfController.set(state: .active)
        assertThat(defaultPilotingItf.state, `is`(.active))
        assertThat(pilotingItf2.state, `is`(.unavailable))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(2))
    }

    func testConnected() {
        // drone is connected
        droneController.pilotingItfActivationController.didConnect()

        // when connected and no piloting itf is active, the default piloting itf activation should be requested
        assertThat(defaultPilotingItf.state, `is`(.unavailable))
        assertThat(pilotingItf2.state, `is`(.unavailable))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(0))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.activatedPilotingItf,
                   presentAnd(`is`(defaultPilotingItfController)))
    }

    func testActivationNotRequested() {
        // initial state: default is active
        defaultPilotingItfController.set(state: .active)
        assertThat(defaultPilotingItf.state, `is`(.active))
        assertThat(pilotingItf2.state, `is`(.unavailable))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(0))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))

        // set the piloting itf 2 to idle in order to be able to activate it
        pilotingItf2Controller.set(state: .idle)
        assertThat(defaultPilotingItf.state, `is`(.active))
        assertThat(pilotingItf2.state, `is`(.idle))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(0))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))

        // mock unrequested activation of pilotingItf2
        pilotingItf2Controller.set(state: .active)
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.deactivatedPilotingItf,
                   presentAnd(`is`(defaultPilotingItfController)))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))
        // no state should change for the moment
        assertThat(defaultPilotingItf.state, `is`(.active))
        // if activation was made by low level, we accept to have two active pitf because in reality the drone should
        // immediately say that the first pitf is idle. (or, better, it has said it before switching to the pitf2).
        assertThat(pilotingItf2.state, `is`(.active))
        assertThat(pilotingItf3.state, `is`(.unavailable))

        // mock deactivation answer from low-level
        defaultPilotingItfController.set(state: .idle)
        assertThat(defaultPilotingItf.state, `is`(.idle))
        assertThat(pilotingItf2.state, `is`(.active))
        assertThat(pilotingItf3.state, `is`(.unavailable))
        assertThat(MockActivablePilotingItfController.deactivationCnt, `is`(1))
        assertThat(MockActivablePilotingItfController.activationCnt, `is`(0))
        //assertThat(MockActivablePilotingItfController.activatedPilotingItf, presentAnd(`is`(pilotingItf2)))
    }
}

private class MockActivablePilotingItfCore: ActivablePilotingItfCore {
    private var mockBackend: MockActivablePilotingItfBackend {
        return backend as! MockActivablePilotingItfBackend
    }
    public init(store: ComponentStoreCore, backend: MockActivablePilotingItfBackend) {
        super.init(desc: PilotingItfs.flightPlan, store: store, backend: backend)
    }

    public func activate() -> Bool {
        return mockBackend.activate()
    }
}

private protocol MockActivablePilotingItfBackend: ActivablePilotingItfBackend {
    func activate() -> Bool
}

private class MockActivablePilotingItfController: ActivablePilotingItfController {

    static var activatedPilotingItf: MockActivablePilotingItfController?
    static var deactivatedPilotingItf: MockActivablePilotingItfController?
    static var activationCnt = 0
    static var deactivationCnt = 0

    init(activationController: PilotingItfActivationController) {
        super.init(activationController: activationController)
        pilotingItf = MockActivablePilotingItfCore(
            store: droneController.drone.pilotingItfStore, backend: self)
    }

    override func requestActivation() {
        MockActivablePilotingItfController.activationCnt += 1
        MockActivablePilotingItfController.activatedPilotingItf = self
    }

    override func requestDeactivation() {
        MockActivablePilotingItfController.deactivationCnt += 1
        MockActivablePilotingItfController.deactivatedPilotingItf = self
    }

    func set(state: ActivablePilotingItfState) {
        switch state {
        case .idle:
            notifyIdle()
        case .active:
            notifyActive()
        case .unavailable:
            notifyUnavailable()
        }
    }

    static func reset() {
        activatedPilotingItf = nil
        deactivatedPilotingItf = nil
        activationCnt = 0
        deactivationCnt = 0
    }
}

extension MockActivablePilotingItfController: MockActivablePilotingItfBackend {
    func activate() -> Bool {
        return droneController.pilotingItfActivationController.activate(pilotingItf: self)
    }
}
