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
@testable import GroundSdkMock

/// Test drone functions
class DroneTests: XCTestCase {
    /// Check that drone name can be get and is correctly notified when changed
    func testDroneName() {
        var cnt = 0
        var name: String?
        let droneCore = DroneCore(uid: "drone1", model: Drone.Model.anafi4k, name: "name",
                                  delegate: DeviceDelegate())
        let drone = Drone(droneCore: droneCore)
        var nameRef: Ref<String>? = drone.getName { newName in
            name = newName
            cnt += 1
        }
        // remove unused variable warning
        _ = nameRef
        // check that the inital value has been notified
        assertThat(cnt, equalTo(1))
        assertThat(name, presentAnd(`is`("name")))

        droneCore.nameHolder.update(name: "newName")
        assertThat(cnt, equalTo(2))
        assertThat(name, presentAnd(`is`("newName")))
        assertThat(drone.name, `is`("newName"))

        nameRef = nil
        droneCore.nameHolder.update(name: "otherName")
        assertThat(cnt, equalTo(2))
        assertThat(name, presentAnd(`is`("newName")))
        assertThat(drone.name, `is`("otherName"))
    }

    func testDroneEquatableOnUid() {
        let droneCore1 = DroneCore(uid: "sameUID", model: Drone.Model.anafi4k, name: "name",
                                  delegate: DeviceDelegate())
        let drone1 = Drone(droneCore: droneCore1)
        let droneCore2 = DroneCore(uid: "sameUID", model: Drone.Model.anafi4k, name: "name",
                                   delegate: DeviceDelegate())
        let drone2 = Drone(droneCore: droneCore2)
        let droneCore3 = DroneCore(uid: "otherUID", model: Drone.Model.anafi4k, name: "name",
                                   delegate: DeviceDelegate())
        let drone3 = Drone(droneCore: droneCore3)
        assertThat(drone1 == drone2, `is`(true))
        assertThat(drone1 == drone3, `is`(false))
    }

    /// Check that drone name can be get and is correctly notified when changed
    func testDroneState() {
        var cnt = 0
        var state: DeviceState?
        let droneCore = DroneCore(uid: "drone1", model: Drone.Model.anafi4k, name: "name",
                                  delegate: DeviceDelegate())
        let drone = Drone(droneCore: droneCore)
        var stateRef: Ref<DeviceState>? = drone.getState { newState in
            state = newState
            cnt += 1
        }
        // remove unused variable warning
        _ = stateRef

        // check that the callback has not been called when no value is set
        assertThat(cnt, equalTo(1))

        assertThat(state, presentAnd(allOf(
            `is`(DeviceState.ConnectionState.disconnected),
            `is`(DeviceState.ConnectionStateCause.none))))

        droneCore.stateHolder.state?.update(connectionState: .disconnecting, withCause: .failure).notifyUpdated()
        assertThat(cnt, equalTo(2))
        assertThat(state, presentAnd(allOf(
            `is`(DeviceState.ConnectionState.disconnecting),
            `is`(DeviceState.ConnectionStateCause.failure))))

        stateRef = nil
    }

    func testGetInstrument() {
        let droneCore = DroneCore(uid: "drone1", model: Drone.Model.anafi4k, name: "name",
                                  delegate: DeviceDelegate())
        let drone = Drone(droneCore: droneCore)

        var instr: TestInstrument?
        var cnt = 0

        // check getting an unknown Instrument
        let instrRef: Ref<TestInstrument> = drone.getInstrument(testInstruments) { instrument in
            cnt += 1
            instr = instrument
        }
        // remove unused variable warning
        _ = instrRef

        // check instrument is not found
        assertThat(drone.getInstrument(testInstruments), `is`(nilValue()))
        // callback should not be called if the Instrument doesn't exists
        assertThat(cnt, `is`(0))

        // add an Instrument
        droneCore.instrumentStore.add(TestInstrumentCore())

        // check instrument present and notified
        assertThat(drone.getInstrument(TestInstruments()), present())
        assertThat(cnt, `is`(1))
        assertThat(instr, present())

        // get a ref on an existing document
        _ = drone.getInstrument(testInstruments) { instrument in
            cnt += 1
            assertThat(instrument, present())
        }
        // check the callback is called immediately
        assertThat(cnt, `is`(2))

        // remove Instrument
        droneCore.instrumentStore.remove(TestInstrumentCore())

        // check instrument is not found and remove has been notified
        assertThat(drone.getInstrument(testInstruments), `is`(nilValue()))
        assertThat(instr, nilValue())
        assertThat(cnt, `is`(3))
    }

    func testGetPilotingItf() {
        let droneCore = DroneCore(uid: "drone1", model: Drone.Model.anafi4k, name: "name",
                                  delegate: DeviceDelegate())
        let drone = Drone(droneCore: droneCore)

        var pItf: TestPilotingItf?
        var cnt = 0

        // check getting an unknown piloting itf
        let pItfRef: Ref<TestPilotingItf> = drone.getPilotingItf(testPilotingItfs) { pilotingItf in
            cnt += 1
            pItf = pilotingItf
        }
        // remove unused variable warning
        _ = pItfRef

        // check pilotingItf is not found
        assertThat(drone.getPilotingItf(testPilotingItfs), `is`(nilValue()))
        // callback should not be called if the Instrument doesn't exists
        assertThat(cnt, `is`(0))

        // add an Instrument
        droneCore.pilotingItfStore.add(TestPilotingItfCore())

        // check pilotingItf present and notified
        assertThat(drone.getPilotingItf(TestPilotingItfs()), present())
        assertThat(cnt, `is`(1))
        assertThat(pItf, present())

        // get a ref on an existing document
        _ = drone.getPilotingItf(testPilotingItfs) { pilotingItf in
            cnt += 1
            assertThat(pilotingItf, present())
        }
        // check the callback is called immediately
        assertThat(cnt, `is`(2))

        // remove Instrument
        droneCore.pilotingItfStore.remove(TestPilotingItfCore())

        // check pilotingItf is not found and remove has been notified
        assertThat(drone.getPilotingItf(testPilotingItfs), `is`(nilValue()))
        assertThat(pItf, nilValue())
        assertThat(cnt, `is`(3))
    }

    func testGetPeripheral() {
        let droneCore = DroneCore(uid: "drone1", model: Drone.Model.anafi4k, name: "name",
                                  delegate: DeviceDelegate())
        let drone = Drone(droneCore: droneCore)

        var periph: TestPeripheral?
        var cnt = 0

        // check getting an unknown Peripheral
        let periphRef: Ref<TestPeripheral> = drone.getPeripheral(testPeripherals) { peripheral in
            cnt += 1
            periph = peripheral
        }
        // remove unused variable warning
        _ = periphRef

        // check peripheral is not found
        assertThat(drone.getPeripheral(testPeripherals), `is`(nilValue()))
        // callback should not be called if the Peripheral doesn't exists
        assertThat(cnt, `is`(0))

        // add an Peripheral
        droneCore.peripheralStore.add(TestPeripheralCore())

        // check peripheral present and notified
        assertThat(drone.getPeripheral(TestPeripherals()), present())
        assertThat(cnt, `is`(1))
        assertThat(periph, present())

        // get a ref on an existing document
        _ = drone.getPeripheral(testPeripherals) { peripheral in
            cnt += 1
            assertThat(peripheral, present())
        }
        // check the callback is called immediately
        assertThat(cnt, `is`(2))

        // remove Peripheral
        droneCore.peripheralStore.remove(TestPeripheralCore())

        // check peripheral is not found and remove has been notified
        assertThat(drone.getPeripheral(testPeripherals), `is`(nilValue()))
        assertThat(periph, nilValue())
        assertThat(cnt, `is`(3))
    }

    func testForget() {
        let delegate = DeviceDelegate()
        let droneCore = DroneCore(uid: "drone1", model: Drone.Model.anafi4k, name: "name", delegate: delegate)
        let drone = Drone(droneCore: droneCore)
        assertThat(drone.forget(), presentAnd(`is`(true)))
        assertThat(delegate.forgetCnt, `is`(1))
    }

    func testConnect() {
        let delegate = DeviceDelegate()
        let droneCore = DroneCore(uid: "drone1", model: Drone.Model.anafi4k, name: "name", delegate: delegate)
        let drone = Drone(droneCore: droneCore)
        assertThat(drone.connect(connector: LocalDeviceConnectorCore.wifi), `is`(true))
        assertThat(delegate.connectCnt, `is`(1))
    }

    func testConnectNoConnectors() {
        let delegate = DeviceDelegate()
        let droneCore = DroneCore(uid: "drone1", model: Drone.Model.anafi4k, name: "name", delegate: delegate)
        let drone = Drone(droneCore: droneCore)
        assertThat(drone.connect(), `is`(false))
        assertThat(delegate.connectCnt, `is`(0))
    }

    func testConnectSingleLocalConnector() {
        let delegate = DeviceDelegate()
        let droneCore = DroneCore(uid: "drone1", model: Drone.Model.anafi4k, name: "name", delegate: delegate)
        droneCore.stateHolder.state.update(connectors: [LocalDeviceConnectorCore.wifi])
        let drone = Drone(droneCore: droneCore)
        assertThat(drone.connect(), `is`(true))
        assertThat(delegate.connectCnt, `is`(1))
        assertThat(delegate.connectConnectorUid, presentAnd(`is`(LocalDeviceConnectorCore.wifi.uid)))
    }

    func testConnectRemoteAndLocalConnector() {
        let delegate = DeviceDelegate()
        let droneCore = DroneCore(uid: "drone1", model: Drone.Model.anafi4k, name: "name", delegate: delegate)
        droneCore.stateHolder.state.update(connectors: [LocalDeviceConnectorCore.wifi,
                                                     RemoteControlDeviceConnectorCore(uid: "123")])
        let drone = Drone(droneCore: droneCore)
        assertThat(drone.connect(), `is`(true))
        assertThat(delegate.connectCnt, `is`(1))
        assertThat(delegate.connectConnectorUid, presentAnd(`is`("123")))
    }

    func testConnectTwoRemoteConnector() {
        let delegate = DeviceDelegate()
        let droneCore = DroneCore(uid: "drone1", model: Drone.Model.anafi4k, name: "name", delegate: delegate)
        droneCore.stateHolder.state.update(connectors: [LocalDeviceConnectorCore.wifi,
                                                     RemoteControlDeviceConnectorCore(uid: "ABC"),
                                                     RemoteControlDeviceConnectorCore(uid: "123")])
        let drone = Drone(droneCore: droneCore)
        assertThat(drone.connect(), `is`(false))
        assertThat(delegate.connectCnt, `is`(0))
    }

    func testDisconnect() {
        let delegate = DeviceDelegate()
        let droneCore = DroneCore(uid: "drone1", model: Drone.Model.anafi4k, name: "name", delegate: delegate)
        let drone = Drone(droneCore: droneCore)
        assertThat(drone.disconnect(), `is`(true))
        assertThat(delegate.disconnectCnt, `is`(1))
    }
}
