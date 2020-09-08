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

class ActivationEngineTests: XCTestCase {

    let internetConnectivity = MockInternetConnectivity()

    let httpSession = MockHttpSession()

    private let droneStore = DroneStoreUtilityCore()
    private let rcStore = RemoteControlStoreUtilityCore()

    // need to be retained (normally retained by the EnginesController)
    private let utilityRegistry = UtilityCoreRegistry()
    private let facilityStore = ComponentStoreCore()
    private var enginesController: MockEnginesController!

    private var engine: MockActivationEngine!

    override func setUp() {
        super.setUp()

        utilityRegistry.publish(utility: droneStore)
        utilityRegistry.publish(utility: rcStore)
        utilityRegistry.publish(utility: internetConnectivity)
        utilityRegistry.publish(utility: CloudServerCore(utilityRegistry: utilityRegistry, httpSession: httpSession))

        enginesController = MockEnginesController(
            utilityRegistry: utilityRegistry,
            facilityStore: facilityStore,
            initEngineClosure: {
                self.engine = MockActivationEngine(enginesController: $0)
                return [self.engine]
        })
    }

    /// Check that device that should be ignored from the registration are ignored
    func testIgnoredDevice() {
        engine.start()

        internetConnectivity.mockInternetAvailable = true

        let simulator = MockDrone(uid: "000000000000000000")
        let defaultDevice = MockRemoteControl(uid: "skyCtrl")
        droneStore.add(simulator)
        assertThat(httpSession.popLastTask(), nilValue())

        simulator.mockPersisted(true)
        defaultDevice.mockPersisted(true)

        assertThat(httpSession.popLastTask(), nilValue())

        rcStore.add(defaultDevice)
        assertThat(httpSession.popLastTask(), nilValue())
    }

    func testRegistrableBoardId() {
        engine.start()

        internetConnectivity.mockInternetAvailable = true

        // devices with board identifier that shall not be registered
        let nilBoardIdDrone = MockDrone(uid: "nilBoardIdDrone", boardId: nil)
        nilBoardIdDrone.mockPersisted(true)
        let hexBoardIdDrone1 = MockDrone(uid: "hexBoardIdDrone1", boardId: "0x1234")
        hexBoardIdDrone1.mockPersisted(true)

        droneStore.add(nilBoardIdDrone)
        droneStore.add(hexBoardIdDrone1)
        assertThat(httpSession.popLastTask(), nilValue())

        // devices with board identifier that shall be registered
        let emptyBoardIdDrone = MockDrone(uid: "emptyBoardIdDrone", boardId: "")
        emptyBoardIdDrone.mockPersisted(true)
        let notHexBoardIdDrone1 = MockDrone(uid: "notHexBoardIdDrone1", boardId: "1234")
        notHexBoardIdDrone1.mockPersisted(true)
        let notHexBoardIdDrone2 = MockDrone(uid: "notHexBoardIdDrone2", boardId: "0xghij")
        notHexBoardIdDrone2.mockPersisted(true)
        let hexBoardIdDrone2 = MockDrone(uid: "hexBoardIdDrone2", boardId: "0x0000")
        hexBoardIdDrone2.mockPersisted(true)

        droneStore.add(emptyBoardIdDrone)
        var expectedBody = """
        [{"serial":"emptyBoardIdDrone","firmware":"0.0.0"}]
        """
        var task = httpSession.popLastTask() as! MockDataTask
        assertThat(String(data: task.request.httpBody!, encoding: .utf8), presentAnd(`is`(expectedBody)))
        task.mockCompletionSuccess(data: nil)

        droneStore.add(notHexBoardIdDrone1)
        expectedBody = """
        [{"serial":"notHexBoardIdDrone1","firmware":"0.0.0"}]
        """
        task = httpSession.popLastTask() as! MockDataTask
        assertThat(String(data: task.request.httpBody!, encoding: .utf8), presentAnd(`is`(expectedBody)))
        task.mockCompletionSuccess(data: nil)

        droneStore.add(notHexBoardIdDrone2)
        expectedBody = """
        [{"serial":"notHexBoardIdDrone2","firmware":"0.0.0"}]
        """
        task = httpSession.popLastTask() as! MockDataTask
        assertThat(String(data: task.request.httpBody!, encoding: .utf8), presentAnd(`is`(expectedBody)))
        task.mockCompletionSuccess(data: nil)

        droneStore.add(hexBoardIdDrone2)
        expectedBody = """
        [{"serial":"hexBoardIdDrone2","firmware":"0.0.0"}]
        """
        task = httpSession.popLastTask() as! MockDataTask
        assertThat(String(data: task.request.httpBody!, encoding: .utf8), presentAnd(`is`(expectedBody)))
        task.mockCompletionSuccess(data: nil)
    }

    func testRegisterSuccess() {
        engine.start()

        let drone1 = MockDrone(uid: "drone1")
        drone1.mockFirmwareVersion(FirmwareVersion.parse(versionStr: "1.1.1")!)
        drone1.mockPersisted(true)
        let drone2 = MockDrone(uid: "drone2")
        drone2.mockPersisted(true)
        let drone3 = MockDrone(uid: "drone3")
        drone3.mockPersisted(true)
        let drone4 = MockDrone(uid: "drone4")
        drone4.mockPersisted(true)
        let rc1 = MockRemoteControl(uid: "rc1")
        rc1.mockPersisted(true)
        let rc2 = MockRemoteControl(uid: "rc2")
        let rc3 = MockRemoteControl(uid: "rc3")
        rc3.mockPersisted(true)

        internetConnectivity.mockInternetAvailable = false

        assertThat(httpSession.popLastTask(), nilValue())

        droneStore.add(drone1)
        rcStore.add(rc1)
        rcStore.add(rc2)

        internetConnectivity.mockInternetAvailable = true

        // only drone1 and rc2 should have been registered since rc2 is not persisted yet
        var expectedBody = """
        [{"serial":"drone1","firmware":"1.1.1"},{"serial":"rc1","firmware":"0.0.0"}]
        """
        var task = httpSession.popLastTask() as! MockDataTask
        assertThat(String(data: task.request.httpBody!, encoding: .utf8), presentAnd(`is`(expectedBody)))

        task.mockCompletionSuccess(data: nil)

        // mock rc2 is now persisted, no request should be issued since we are waiting for a drone to be persisted
        rc2.mockPersisted(true)
        assertThat(httpSession.popLastTask(), nilValue())

        // mock drone2 is added to the store (it is persisted)
        droneStore.add(drone2)

        expectedBody = """
        [{"serial":"drone2","firmware":"0.0.0"},{"serial":"rc2","firmware":"0.0.0"}]
        """
        task = httpSession.popLastTask() as! MockDataTask
        assertThat(String(data: task.request.httpBody!, encoding: .utf8), presentAnd(`is`(expectedBody)))

        // check that adding a new drone when the current request is not finished yet, does not trigger a new request
        // but waits for it to be finished
        droneStore.add(drone3)
        assertThat(httpSession.popLastTask(), nilValue())

        task.mockCompletionSuccess(data: nil)
        expectedBody = """
        [{"serial":"drone3","firmware":"0.0.0"}]
        """
        task = httpSession.popLastTask() as! MockDataTask
        assertThat(String(data: task.request.httpBody!, encoding: .utf8), presentAnd(`is`(expectedBody)))

        task.mockCompletionSuccess(data: nil)

        // check that receiving an rc waits for the drone to be connected to start registration
        rcStore.add(rc3)
        assertThat(httpSession.popLastTask(), nilValue())

        droneStore.add(drone4)

        expectedBody = """
        [{"serial":"drone4","firmware":"0.0.0"},{"serial":"rc3","firmware":"0.0.0"}]
        """
        task = httpSession.popLastTask() as! MockDataTask
        assertThat(String(data: task.request.httpBody!, encoding: .utf8), presentAnd(`is`(expectedBody)))
    }

    func testRegisterFailure() {
        engine.start()

        let drone1 = MockDrone(uid: "drone1")
        drone1.mockPersisted(true)
        let drone2 = MockDrone(uid: "drone2")
        drone2.mockPersisted(true)
        let drone3 = MockDrone(uid: "drone3")
        drone3.mockPersisted(true)
        let drone4 = MockDrone(uid: "drone4")
        drone4.mockPersisted(true)

        internetConnectivity.mockInternetAvailable = false

        droneStore.add(drone1)
        droneStore.add(drone2)

        internetConnectivity.mockInternetAvailable = true

        var task = httpSession.popLastTask() as? MockDataTask
        assertThat(task, present())

        // mock task failed with error 500 (i.e. try again later)
        task?.mockCompletionFail(statusCode: 500)

        assertThat(httpSession.popLastTask(), nilValue())

        // when internet is back again, same request should be issued
        internetConnectivity.mockInternetAvailable = false
        internetConnectivity.mockInternetAvailable = true

        task = httpSession.popLastTask() as? MockDataTask
        assertThat(task, present())

        // mock task failed with error 403 (i.e. bad request), devices should be marked as registered to avoid sending
        // the same request
        task?.mockCompletionFail(statusCode: 403)

        assertThat(httpSession.popLastTask(), nilValue())

        // when internet is back again, no request should be issued
        internetConnectivity.mockInternetAvailable = false
        internetConnectivity.mockInternetAvailable = true
        assertThat(httpSession.popLastTask(), nilValue())
    }
}
