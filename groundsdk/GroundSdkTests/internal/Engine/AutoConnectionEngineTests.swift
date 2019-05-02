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

class AutoConnectionEngineCoreTests: XCTestCase {

    var autoConnectionRef: Ref<AutoConnection>!
    var autoConnection: AutoConnection?
    var changeCnt = 0

    private let droneStore = DroneStoreUtilityCore()
    private let rcStore = RemoteControlStoreUtilityCore()

    // need to be retained (normally retained by the EnginesController)
    private let utilityRegistry = UtilityCoreRegistry()
    private let facilityStore = ComponentStoreCore()
    private var enginesController: MockEnginesController!

    private var engine: AutoConnectionEngine!

    override func setUp() {
        super.setUp()

        utilityRegistry.publish(utility: droneStore)
        utilityRegistry.publish(utility: rcStore)

        enginesController = MockEnginesController(utilityRegistry: utilityRegistry, facilityStore: facilityStore)

        engine = AutoConnectionEngine(enginesController: enginesController)

        autoConnectionRef = ComponentRefCore(
            store: facilityStore,
            desc: Facilities.autoConnection) { [unowned self] autoConnection in
                self.autoConnection = autoConnection
                self.changeCnt += 1
        }
    }

    override func tearDown() {
        engine.stop()
    }

    func testPublishUnpublish() {
        // should be unavailable when the engine is not started
        assertThat(autoConnection, nilValue())

        engine.start()
        assertThat(autoConnection, present())
        assertThat(changeCnt, `is`(1))

        engine.stop()
        assertThat(autoConnection, nilValue())
        assertThat(changeCnt, `is`(2))
    }

    /// Checks autoconnect state
    func testAutoConnectState() {
        engine.start()

        // when engine is started, state should be stopped
        assertThat(autoConnection, presentAnd(`is`(.stopped)))
        assertThat(changeCnt, `is`(1))

        // test that calling stopAutoConnect while stopped does not change anything
        assertThat(engine.stopAutoConnection(), `is`(false))
        assertThat(autoConnection, presentAnd(`is`(.stopped)))
        assertThat(changeCnt, `is`(1))

        // test that calling startAutoConnect actually starts the auto connection
        assertThat(engine.startAutoConnection(), `is`(true))
        assertThat(autoConnection, presentAnd(`is`(.started)))
        assertThat(changeCnt, `is`(2))

        // test that calling startAutoConnect while started does not change anything
        assertThat(engine.startAutoConnection(), `is`(false))
        assertThat(autoConnection, presentAnd(`is`(.started)))
        assertThat(changeCnt, `is`(2))

        // test that calling stopAutoConnect when started actually stops the auto connection
        assertThat(engine.stopAutoConnection(), `is`(true))
        assertThat(autoConnection, presentAnd(`is`(.stopped)))
        assertThat(changeCnt, `is`(3))
    }

    func testAutoStartWhenConfig() {
        GroundSdkConfig.sharedInstance.autoConnectionAtStartup = true

        engine.start()

        // test that autoconnection is started automatically (and only notify once)
        assertThat(autoConnection, presentAnd(`is`(.started)))
        assertThat(changeCnt, `is`(1))

        // test that calling stopAutoConnect when started actually stops the auto connection
        assertThat(autoConnection!.stop(), `is`(true))
        assertThat(autoConnection, presentAnd(`is`(.stopped)))
        assertThat(changeCnt, `is`(2))

        GroundSdkConfig.sharedInstance.autoConnectionAtStartup = false
    }

    func testDroneAutoConnectWithTwoWifiDrones() {
        // 0: auto-connected drone, 1: the other drone
        var drones = addDrones(
            MockDrone(uid: "1").addConnectors([LocalDeviceConnectorCore.wifi]),
            MockDrone(uid: "2").addConnectors([LocalDeviceConnectorCore.wifi]))

        // prepare expectations for auto-connection
        drones[0].expectConnect(through: LocalDeviceConnectorCore.wifi, thenDo: { drones[1].revokeLastExpectation() })
        drones[1].expectConnect(through: LocalDeviceConnectorCore.wifi, thenDo: {
            // to make the drone 0 as the connected one, exchange drone 0 and 1.
            drones.swapAt(0, 1)
            drones[1].revokeLastExpectation()
        })

        engine.start()
        // initial state
        assertThat(autoConnection, presentAnd(allOf(has(drone: nil), has(rc: nil))))
        assertThat(changeCnt, `is`(1))

        autoConnection?.start()

        drones[0].assertNoExpectation()
        assertThat(drones[0].stateHolder.state, `is`(.connecting))
        drones[1].assertNoExpectation()
        assertThat(drones[1].stateHolder.state, `is`(.disconnected))
        assertThat(autoConnection, presentAnd(allOf(has(drone: drones[0]), has(rc: nil))))
        assertThat(changeCnt, `is`(2)) // +0 for the started (swallowed), + 1 for the drone change

        // mock auto-connected drone finally connects
        drones[0].mockConnected()

        drones[0].assertNoExpectation()
        assertThat(drones[0].stateHolder.state, `is`(.connected))
        drones[1].assertNoExpectation()
        assertThat(drones[1].stateHolder.state, `is`(.disconnected))
        assertThat(changeCnt, `is`(3))

        // mock auto-connected drone now starts disconnecting
        drones[0].mockDisconnecting()

        drones[0].assertNoExpectation()
        assertThat(drones[0].stateHolder.state, `is`(.disconnecting))
        drones[1].assertNoExpectation()
        assertThat(drones[1].stateHolder.state, `is`(.disconnected))
        assertThat(changeCnt, `is`(4))

        // prepare expectations for auto-connected drone disconnection
        drones[0].expectConnect(through: LocalDeviceConnectorCore.wifi, thenDo: { drones[1].revokeLastExpectation() })
        drones[1].expectConnect(through: LocalDeviceConnectorCore.wifi, thenDo: {
            // to make the drone 0 as the connected one, exchange drone 0 and 1.
            drones.swapAt(0, 1)
            drones[1].revokeLastExpectation()
        })

        // mock auto-connected drone now is disconnected
        drones[0].mockDisconnected()

        drones[0].assertNoExpectation()
        assertThat(drones[0].stateHolder.state, `is`(.connecting))
        drones[1].assertNoExpectation()
        assertThat(drones[1].stateHolder.state, `is`(.disconnected))
        // no changes since disconnected drone is immediately reconnecting.
        assertThat(changeCnt, `is`(6)) // +1 for DISCONNECTED drone[0], +1 for CONNECTING drone[0]
    }

    func testRCAutoConnectWithTwoWifiRCs() {
        // 0: auto-connected rc, 1: the other rc
        var rcs = addRcs(
            MockRemoteControl(uid: "1").addConnectors([LocalDeviceConnectorCore.wifi]),
            MockRemoteControl(uid: "2").addConnectors([LocalDeviceConnectorCore.wifi]))

        // prepare expectations for auto-connection
        rcs[0].expectConnect(through: LocalDeviceConnectorCore.wifi, thenDo: { rcs[1].revokeLastExpectation() })
        rcs[1].expectConnect(through: LocalDeviceConnectorCore.wifi, thenDo: {
            // to make the drone 0 as the connected one, exchange drone 0 and 1.
            rcs.swapAt(0, 1)
            rcs[1].revokeLastExpectation()
        })

        engine.start()
        // initial state
        assertThat(autoConnection, presentAnd(allOf(has(drone: nil), has(rc: nil))))
        assertThat(changeCnt, `is`(1))

        autoConnection?.start()

        rcs[0].assertNoExpectation()
        assertThat(rcs[0].stateHolder.state, `is`(.connecting))
        rcs[1].assertNoExpectation()
        assertThat(rcs[1].stateHolder.state, `is`(.disconnected))
        assertThat(autoConnection, presentAnd(allOf(has(rc: rcs[0]), has(drone: nil))))
        assertThat(changeCnt, `is`(2)) // +0 for the started (swallowed), + 1 for the rc change

        // mock auto-connected rc finally connects
        rcs[0].mockConnected()

        rcs[0].assertNoExpectation()
        assertThat(rcs[0].stateHolder.state, `is`(.connected))
        rcs[1].assertNoExpectation()
        assertThat(rcs[1].stateHolder.state, `is`(.disconnected))
        assertThat(changeCnt, `is`(3))

        // mock auto-connected rc now starts disconnecting
        rcs[0].mockDisconnecting()

        rcs[0].assertNoExpectation()
        assertThat(rcs[0].stateHolder.state, `is`(.disconnecting))
        rcs[1].assertNoExpectation()
        assertThat(rcs[1].stateHolder.state, `is`(.disconnected))
        assertThat(changeCnt, `is`(4))

        // prepare expectations for auto-connected rc disconnection
        rcs[0].expectConnect(through: LocalDeviceConnectorCore.wifi, thenDo: { rcs[1].revokeLastExpectation() })
        rcs[1].expectConnect(through: LocalDeviceConnectorCore.wifi, thenDo: {
            // to make the drone 0 as the connected one, exchange drone 0 and 1.
            rcs.swapAt(0, 1)
            rcs[1].revokeLastExpectation()
        })

        // mock auto-connected rc now is disconnected
        rcs[0].mockDisconnected()

        rcs[0].assertNoExpectation()
        assertThat(rcs[0].stateHolder.state, `is`(.connecting))
        rcs[1].assertNoExpectation()
        assertThat(rcs[1].stateHolder.state, `is`(.disconnected))
        assertThat(changeCnt, `is`(6)) // +1 for DISCONNECTED rcs[0], +1 for CONNECTING rcs[0]
    }

    func testRCAutoConnectWithABetterRC() {
        var rcs = addRcs(
            MockRemoteControl(uid: "1").addConnectors([LocalDeviceConnectorCore.wifi]),
            MockRemoteControl(uid: "2"))

        // prepare expectations for auto-connection
        rcs[0].expectConnect(through: LocalDeviceConnectorCore.wifi)

        // auto-connection should connect rc 0
        engine.start()
        // initial state
        assertThat(autoConnection, presentAnd(allOf(has(drone: nil), has(rc: nil))))
        assertThat(changeCnt, `is`(1))

        autoConnection?.start()

        rcs[0].assertNoExpectation()
        assertThat(rcs[0].stateHolder.state, `is`(.connecting))
        rcs[1].assertNoExpectation()
        assertThat(rcs[1].stateHolder.state, `is`(.disconnected))
        assertThat(autoConnection, presentAnd(allOf(has(rc: rcs[0]), has(drone: nil))))
        assertThat(changeCnt, `is`(2)) // +0 for the started (swallowed), + 1 for the rc change

        // mock rc 0 connected
        rcs[0].mockConnected()

        rcs[0].assertNoExpectation()
        assertThat(rcs[0].stateHolder.state, `is`(.connected))
        rcs[1].assertNoExpectation()
        assertThat(rcs[1].stateHolder.state, `is`(.disconnected))
        assertThat(changeCnt, `is`(3))

        // mock rc 1 is now visible through USB
        // expect a disconnection attempt on rc 0
        rcs[0].expectDisconnect()
        rcs[1].expectConnect(through: LocalDeviceConnectorCore.usb)

        rcs[1].addConnectors([LocalDeviceConnectorCore.usb])

        rcs[0].assertNoExpectation()
        assertThat(rcs[0].stateHolder.state, `is`(.disconnecting))
        rcs[1].assertNoExpectation()
        assertThat(rcs[1].stateHolder.state, `is`(.connecting))
        assertThat(autoConnection, presentAnd(allOf(has(rc: rcs[1]), has(drone: nil))))
        assertThat(changeCnt, `is`(5)) // +1 for DISCONNECTING rc[0], +1 for CONNECTING rc[1]

        // mock final disconnection on rc 0
        rcs[0].mockDisconnected()

        rcs[0].assertNoExpectation()
        assertThat(rcs[0].stateHolder.state, `is`(.disconnected))
        rcs[1].assertNoExpectation()
        assertThat(rcs[1].stateHolder.state, `is`(.connecting))
        assertThat(changeCnt, `is`(5)) // no changes since rc[0] is not the current rc

        // mock final connection on rc 1
        rcs[1].mockConnected()

        rcs[0].assertNoExpectation()
        assertThat(rcs[0].stateHolder.state, `is`(.disconnected))
        rcs[1].assertNoExpectation()
        assertThat(rcs[1].stateHolder.state, `is`(.connected))
        assertThat(changeCnt, `is`(6))
    }

    func testRCAutoconnectWithADrone() {
        var drones = addDrones(MockDrone(uid: "1").addConnectors([LocalDeviceConnectorCore.wifi]))
        let drone = drones.first!
        let rcs = addRcs(MockRemoteControl(uid: "2"))
        let rc = rcs.first!

        // prepare expectations for auto-connection
        drone.expectConnect(through: LocalDeviceConnectorCore.wifi)

        // auto-connection should connect drone
        engine.start()
        // initial state
        assertThat(autoConnection, presentAnd(allOf(has(drone: nil), has(rc: nil))))
        assertThat(changeCnt, `is`(1))

        autoConnection?.start()

        drone.assertNoExpectation()
        assertThat(drone.stateHolder.state, `is`(.connecting))
        rc.assertNoExpectation()
        assertThat(rc.stateHolder.state, `is`(.disconnected))
        assertThat(autoConnection, presentAnd(allOf(has(drone: drone), has(rc: nil))))
        assertThat(changeCnt, `is`(2)) // +0 for the started (swallowed), + 1 for the drone change

        // mock drone connected
        drone.mockConnected()

        drone.assertNoExpectation()
        assertThat(drone.stateHolder.state, `is`(.connected))
        rc.assertNoExpectation()
        assertThat(rc.stateHolder.state, `is`(.disconnected))
        assertThat(changeCnt, `is`(3))

        // mock rc visible through USB
        // expect a disconnection attempt on drone
        drone.expectDisconnect()
        // expect a connection attempt on rc
        rc.expectConnect(through: LocalDeviceConnectorCore.usb)

        rc.addConnectors([LocalDeviceConnectorCore.usb])

        drone.assertNoExpectation()
        assertThat(drone.stateHolder.state, `is`(.disconnecting))
        rc.assertNoExpectation()
        assertThat(rc.stateHolder.state, `is`(.connecting))
        assertThat(autoConnection, presentAnd(allOf(has(drone: drone), has(rc: rc))))
        assertThat(changeCnt, `is`(5)) // +1 for DISCONNECTING drone, +1 for CONNECTING rc

        // mock drone disconnected
        drone.mockDisconnected()

        drone.assertNoExpectation()
        assertThat(drone.stateHolder.state, `is`(.disconnected))
        rc.assertNoExpectation()
        assertThat(rc.stateHolder.state, `is`(.connecting))
        assertThat(changeCnt, `is`(6)) // since drone is still the current drone

        // during connection, mock that rc advertises that it sees drone 1 and a new drone 3
        drones = addDrones(MockDrone(uid: "3").addConnectors([LocalDeviceConnectorCore.wifi]))
        let otherDrone = drones.last!
        drone.addConnectors([RemoteControlDeviceConnectorCore(uid: rc.uid)])

        assertThat(changeCnt, `is`(7)) // +1 for added connector on drone
        // since the rc is not connected yet, no connection on the drone should be attempted
        drone.assertNoExpectation()
        otherDrone.assertNoExpectation()
        rc.assertNoExpectation()

        // mock final connection of the rc.
        // expect a connection on drone 1
        drone.expectConnect(through: RemoteControlDeviceConnectorCore(uid: rc.uid))
        rc.mockConnected()
        drone.assertNoExpectation()
        assertThat(drone.stateHolder.state, `is`(.connecting))
        otherDrone.assertNoExpectation()
        assertThat(otherDrone.stateHolder.state, `is`(.disconnected))
        rc.assertNoExpectation()
        assertThat(rc.stateHolder.state, `is`(.connected))
        assertThat(autoConnection, presentAnd(allOf(has(drone: drone), has(rc: rc))))
        // no changes since drone and rc have not changed
        assertThat(changeCnt, `is`(9)) // +1 for CONNECTED rc, +1 for CONNECTING drone

        // mock disconnection of drone 1
        // we don't expect auto-connection to connect any drone, instead it should let the rc do its own job.
        drone.mockDisconnecting()

        drone.assertNoExpectation()
        assertThat(drone.stateHolder.state, `is`(.disconnecting))
        otherDrone.assertNoExpectation()
        assertThat(otherDrone.stateHolder.state, `is`(.disconnected))
        rc.assertNoExpectation()
        assertThat(rc.stateHolder.state, `is`(.connected))
        assertThat(changeCnt, `is`(10))

        drone.mockDisconnected()

        drone.assertNoExpectation()
        assertThat(drone.stateHolder.state, `is`(.disconnected))
        otherDrone.assertNoExpectation()
        assertThat(otherDrone.stateHolder.state, `is`(.disconnected))
        rc.assertNoExpectation()
        assertThat(rc.stateHolder.state, `is`(.connected))
        assertThat(autoConnection, presentAnd(allOf(has(drone: nil), has(rc: rc))))
        assertThat(changeCnt, `is`(12))
    }

    func testDisconnectOnStart() {
        var rcs = addRcs(
            MockRemoteControl(uid: "1").addConnectors([LocalDeviceConnectorCore.usb]),
            MockRemoteControl(uid: "2").addConnectors([LocalDeviceConnectorCore.wifi]),
            MockRemoteControl(uid: "3").addConnectors([LocalDeviceConnectorCore.ble]))

        rcs[1].mockConnecting(through: LocalDeviceConnectorCore.wifi)
        rcs[1].mockConnected()

        rcs[2].mockConnecting(through: LocalDeviceConnectorCore.ble)

        var drones = addDrones(
            MockDrone(uid: "4").addConnectors(
                [LocalDeviceConnectorCore.wifi, RemoteControlDeviceConnectorCore(uid: "1")]),
            MockDrone(uid: "5").addConnectors([LocalDeviceConnectorCore.ble]),
            MockDrone(uid: "6").addConnectors([LocalDeviceConnectorCore.wifi]))

        drones[0].mockConnecting(through: LocalDeviceConnectorCore.wifi)
        drones[0].mockConnected()

        drones[1].mockConnecting(through: LocalDeviceConnectorCore.ble)

        // start auto-connection. Expect only the best rc to remain connected. All drones should get disconnected
        // (drone '4' should later be reconnected through the rc).
        rcs[0].expectConnect(through: LocalDeviceConnectorCore.usb)
        rcs[1].expectDisconnect()
        rcs[2].expectDisconnect()

        drones[0].expectDisconnect()
        drones[1].expectDisconnect()

        engine.start()
        // initial state
        assertThat(autoConnection, presentAnd(allOf(has(drone: nil), has(rc: nil))))
        assertThat(changeCnt, `is`(1))

        autoConnection?.start()

        rcs[0].assertNoExpectation()
        assertThat(rcs[0].stateHolder.state, `is`(.connecting))
        rcs[1].assertNoExpectation()
        assertThat(rcs[1].stateHolder.state, `is`(.disconnecting))
        rcs[2].assertNoExpectation()
        assertThat(rcs[2].stateHolder.state, `is`(.disconnecting))

        drones[0].assertNoExpectation()
        assertThat(drones[0].stateHolder.state, `is`(.disconnecting))
        drones[1].assertNoExpectation()
        assertThat(drones[1].stateHolder.state, `is`(.disconnecting))
        drones[2].assertNoExpectation()
        assertThat(drones[2].stateHolder.state, `is`(.disconnected))
        assertThat(autoConnection, presentAnd(allOf(has(drone: nil), has(rc: rcs[0]))))
        assertThat(changeCnt, `is`(2)) // +0 for the started (swallowed), + 1 for the rc change

        // mock rc '1' connected, other rcs disconnected, drones other than '4' disconnected
        rcs[0].mockConnected()
        rcs[1].mockDisconnected()
        rcs[2].mockDisconnected()
        drones[1].mockDisconnected()

        rcs[0].assertNoExpectation()
        assertThat(rcs[0].stateHolder.state, `is`(.connected))
        rcs[1].assertNoExpectation()
        assertThat(rcs[1].stateHolder.state, `is`(.disconnected))
        rcs[2].assertNoExpectation()
        assertThat(rcs[2].stateHolder.state, `is`(.disconnected))

        drones[0].assertNoExpectation()
        assertThat(drones[0].stateHolder.state, `is`(.disconnecting))
        drones[1].assertNoExpectation()
        assertThat(drones[1].stateHolder.state, `is`(.disconnected))
        drones[2].assertNoExpectation()
        assertThat(drones[2].stateHolder.state, `is`(.disconnected))
        assertThat(changeCnt, `is`(3)) // +1 for CONNECTED rcs[0]

        // mock drone '4' disconnected
        // expect an auto-connection attempt on drone '4' through rc '1'
        drones[0].expectConnect(through: RemoteControlDeviceConnectorCore(uid: "1"))
        drones[0].mockDisconnected()

        rcs[0].assertNoExpectation()
        assertThat(rcs[0].stateHolder.state, `is`(.connected))
        rcs[1].assertNoExpectation()
        assertThat(rcs[1].stateHolder.state, `is`(.disconnected))
        rcs[2].assertNoExpectation()
        assertThat(rcs[2].stateHolder.state, `is`(.disconnected))

        drones[0].assertNoExpectation()
        assertThat(drones[0].stateHolder.state, `is`(.connecting))
        drones[1].assertNoExpectation()
        assertThat(drones[1].stateHolder.state, `is`(.disconnected))
        drones[2].assertNoExpectation()
        assertThat(drones[2].stateHolder.state, `is`(.disconnected))
        assertThat(autoConnection, presentAnd(allOf(has(drone: drones[0]), has(rc: rcs[0]))))
        assertThat(changeCnt, `is`(4))
    }

    func testStayConnectedWhenStopped() {
        let drones = addDrones(MockDrone(uid: "1").addConnectors([LocalDeviceConnectorCore.wifi]))
        let drone = drones.first!
        let rcs = addRcs(MockRemoteControl(uid: "2").addConnectors([LocalDeviceConnectorCore.wifi]))
        let rc = rcs.first!

        // prepare expectations for auto-connection
        rc.expectConnect(through: LocalDeviceConnectorCore.wifi)

        // auto-connection should connect rc
        engine.start()
        // initial state
        assertThat(autoConnection, presentAnd(allOf(has(drone: nil), has(rc: nil))))
        assertThat(changeCnt, `is`(1))

        autoConnection?.start()

        drone.assertNoExpectation()
        assertThat(drone.stateHolder.state, `is`(.disconnected))
        rc.assertNoExpectation()
        assertThat(rc.stateHolder.state, `is`(.connecting))
        assertThat(autoConnection, presentAnd(allOf(has(drone: nil), has(rc: rc))))
        assertThat(changeCnt, `is`(2)) // +0 for the started (swallowed), + 1 for the rc change

        // mock rc is connected
        rc.mockConnected()

        drone.assertNoExpectation()
        assertThat(drone.stateHolder.state, `is`(.disconnected))
        rc.assertNoExpectation()
        assertThat(rc.stateHolder.state, `is`(.connected))
        assertThat(changeCnt, `is`(3))

        // mock drone is visible and connecting through rc
        drone.addConnectors([RemoteControlDeviceConnectorCore(uid: rc.uid)])
        drone.mockConnecting(through: RemoteControlDeviceConnectorCore(uid: rc.uid))

        // no auto-connection should occur we let the RC do is own business
        drone.assertNoExpectation()
        assertThat(drone.stateHolder.state, `is`(.connecting))
        rc.assertNoExpectation()
        assertThat(rc.stateHolder.state, `is`(.connected))
        assertThat(autoConnection, presentAnd(allOf(has(drone: drone), has(rc: rc))))
        assertThat(changeCnt, `is`(4))

        // stop auto-connection engine
        engine.stop()

        // nothing should change, except that autoconnection facility should be nil
        drone.assertNoExpectation()
        assertThat(drone.stateHolder.state, `is`(.connecting))
        rc.assertNoExpectation()
        assertThat(rc.stateHolder.state, `is`(.connected))
        assertThat(autoConnection, nilValue())
        assertThat(changeCnt, `is`(5))
    }

    func addDrones(_ drones: MockDrone...) -> [MockDrone] {
        drones.forEach { droneStore.add($0) }
        return drones
    }

    func addRcs(_ rcs: MockRemoteControl...) -> [MockRemoteControl] {
        rcs.forEach { rcStore.add($0) }
        return rcs
    }
}
