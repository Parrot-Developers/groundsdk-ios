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
@testable import ArsdkEngine
@testable import GroundSdk
import SdkCoreTesting

/// Core arsdk engine tests
class ArsdkEngineAddRemoteDevicesTests: XCTestCase {

    let droneStore = DroneStoreUtilityCore()
    let rcStore = RemoteControlStoreUtilityCore()
    var enginesController: MockEnginesController!
    var arsdkEngine: MockArsdkEngine!
    var mockArsdkCore: MockArsdkCore!
    var mockPersistentStore: MockPersistentStore!
    var droneAddedCalls = 0
    var droneRemovedCalls = 0
    var rcAddedCalls = 0
    var rcRemovedCalls = 0

    override func setUp() {
        super.setUp()
        _ = droneStore.startMonitoring(
            didAddDevice: { [unowned self] _ in
                self.droneAddedCalls += 1
            },
            didRemoveDevice: { [unowned self] _ in
                self.droneRemovedCalls += 1
        })

        _ = rcStore.startMonitoring(
            didAddDevice: { [unowned self] _ in
                self.rcAddedCalls += 1
            },
            didRemoveDevice: { [unowned self] _ in
                self.rcRemovedCalls += 1
        })

        let utilities = UtilityCoreRegistry()
        utilities.publish(utility: droneStore)
        utilities.publish(utility: rcStore)

        enginesController = MockEnginesController(
            utilityRegistry: utilities,
            facilityStore: ComponentStoreCore(),
            initEngineClosure: { engine in
                self.arsdkEngine = MockArsdkEngine(enginesController: engine)
                return [self.arsdkEngine]
        })
        mockArsdkCore = arsdkEngine.mockArsdkCore
        mockArsdkCore.testCase = self
        mockPersistentStore = arsdkEngine.mockPersistentStore
    }

    /// Check known drone and rc
    func testArsdKnownDevice() {
        mockPersistentStore.createDeviceDict(uid: "123", model: .drone(.anafi4k), name: "Drone1").commit()
        mockPersistentStore.createDeviceDict(uid: "456", model: .rc(.skyCtrl3), name: "Rc1").commit()
        enginesController.start()

        // Check drone has been created from the store
        assertThat(droneAddedCalls, equalTo(1))
        let drone = droneStore.getDevice(uid: droneStore.getDevices()[0].uid)
        assertThat(drone, presentAnd(allOf(
            has(uid: "123"),
            `is`(Drone.Model.anafi4k))))
        assertThat(drone?.stateHolder.state, presentAnd(allOf(
            `is`(DeviceState.ConnectionState.disconnected),
            `is`(DeviceState.ConnectionStateCause.none),
            canBeConnected(false),
            canBeDisconnected(false),
            canBeForgotten(true),
            dontHaveConnectors())))

        // Check rc has been created from the store
        assertThat(rcAddedCalls, equalTo(1))
        let rc = rcStore.getDevice(uid: rcStore.getDevices()[0].uid)
        assertThat(rc, presentAnd(allOf(
            has(uid: "456"),
            `is`(RemoteControl.Model.skyCtrl3))))
        assertThat(rc?.stateHolder.state, presentAnd(allOf(
            `is`(DeviceState.ConnectionState.disconnected),
            `is`(DeviceState.ConnectionStateCause.none),
            canBeConnected(false),
            canBeDisconnected(false),
            canBeForgotten(true),
            dontHaveConnectors())))

        enginesController.stop()
    }

    /// Check add/remove drone
    func testAddRemoveDrone() {
        enginesController.start()

        // Add
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        assertThat(droneAddedCalls, equalTo(1))
        let drone = droneStore.getDevice(uid: droneStore.getDevices()[0].uid)
        assertThat(drone, presentAnd(allOf(
            has(uid: "123"),
            `is`(Drone.Model.anafi4k))))
        assertThat(drone?.stateHolder.state, presentAnd(allOf(
            `is`(DeviceState.ConnectionState.disconnected),
            `is`(DeviceState.ConnectionStateCause.none),
            canBeConnected(true),
            canBeDisconnected(false),
            canBeForgotten(false),
            has(connector: LocalDeviceConnectorCore.wifi))))

        // Remove
        mockArsdkCore.removeDevice(1)
        assertThat(droneRemovedCalls, equalTo(1))
        assertThat(droneStore.getDevices(), hasCount(0))

        enginesController.stop()
    }

    /// Check add/remove remote control
    func testAddRemoveRemoteControl() {
        enginesController.start()

        // Add
        mockArsdkCore.addDevice("123", type: RemoteControl.Model.skyCtrl3.internalId, backendType: .mux, name: "mpp",
                                handle: 1)
        assertThat(rcAddedCalls, equalTo(1))
        let rc = rcStore.getDevice(uid: rcStore.getDevices()[0].uid)
        assertThat(rc, presentAnd(allOf(
            has(uid: "123"),
            `is`(RemoteControl.Model.skyCtrl3))))

        assertThat(rc?.stateHolder.state, presentAnd(allOf(
            `is`(DeviceState.ConnectionState.disconnected),
            `is`(DeviceState.ConnectionStateCause.none),
            canBeConnected(true),
            canBeDisconnected(false),
            canBeForgotten(false),
            has(connector: LocalDeviceConnectorCore.usb))))

        // Remove
        mockArsdkCore.removeDevice(1)
        assertThat(rcAddedCalls, equalTo(1))
        assertThat(rcRemovedCalls, equalTo(1))
        assertThat(rcStore.getDevices(), hasCount(0))

        enginesController.stop()
    }

    /// Check add/remove a known drone
    func testAddRemoveKnownDrone() {
        mockPersistentStore.createDeviceDict(uid: "123", model: .drone(.anafi4k), name: "Drone1").commit()
        enginesController.start()

        // Add
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        assertThat(droneAddedCalls, equalTo(1))
        let drone = droneStore.getDevice(uid: droneStore.getDevices()[0].uid)
        assertThat(drone, presentAnd(allOf(
            has(uid: "123"),
            `is`(Drone.Model.anafi4k))))
        assertThat(drone?.stateHolder.state, presentAnd(allOf(
            `is`(DeviceState.ConnectionState.disconnected),
            `is`(DeviceState.ConnectionStateCause.none),
            canBeConnected(true),
            canBeDisconnected(false),
            canBeForgotten(true),
            has(connector: LocalDeviceConnectorCore.wifi))))

        // Remove
        mockArsdkCore.removeDevice(1)
        assertThat(droneAddedCalls, equalTo(1))
        assertThat(droneRemovedCalls, equalTo(0)) // should not be notified
        let removedDrone = droneStore.getDevice(uid: droneStore.getDevices()[0].uid)
        assertThat(removedDrone?.stateHolder.state, presentAnd(allOf(
            `is`(DeviceState.ConnectionState.disconnected),
            `is`(DeviceState.ConnectionStateCause.none),
            canBeConnected(false),
            canBeDisconnected(false),
            canBeForgotten(true),
            dontHaveConnectors())))

        enginesController.stop()
    }

    /// Check add/remove a known rc
    func testAddRemoveKnownRc() {
        mockPersistentStore.createDeviceDict(uid: "456", model: .rc(.skyCtrl3), name: "Rc1").commit()
        enginesController.start()

        // Add
        mockArsdkCore.addDevice("456", type: RemoteControl.Model.skyCtrl3.internalId, backendType: .mux, name: "Rc1",
                                handle: 1)
        assertThat(rcAddedCalls, equalTo(1))
        let rc = rcStore.getDevice(uid: rcStore.getDevices()[0].uid)
        assertThat(rc, presentAnd(allOf(
            has(uid: "456"),
            `is`(RemoteControl.Model.skyCtrl3))))
        assertThat(rc?.stateHolder.state, presentAnd(allOf(
            `is`(DeviceState.ConnectionState.disconnected),
            `is`(DeviceState.ConnectionStateCause.none),
            canBeConnected(true),
            canBeDisconnected(false),
            canBeForgotten(true),
            has(connector: LocalDeviceConnectorCore.usb))))

        // Remove
        mockArsdkCore.removeDevice(1)
        assertThat(rcAddedCalls, equalTo(1))
        assertThat(rcRemovedCalls, equalTo(0)) // should not be notified
        let removedRc = rcStore.getDevice(uid: rcStore.getDevices()[0].uid)
        assertThat(removedRc?.stateHolder.state, presentAnd(allOf(
            `is`(DeviceState.ConnectionState.disconnected),
            `is`(DeviceState.ConnectionStateCause.none),
            canBeConnected(false),
            canBeDisconnected(false),
            canBeForgotten(true),
            dontHaveConnectors())))

        enginesController.stop()
    }

    func testForgetDrone() {
        mockPersistentStore.createDeviceDict(uid: "123", model: .drone(.anafi4k), name: "Drone1").commit()
        enginesController.start()

        // Check device has been created from the store
        assertThat(droneAddedCalls, equalTo(1))
        let drone = droneStore.getDevice(uid: droneStore.getDevices()[0].uid)

        _ = drone!.forget()
        assertThat(droneAddedCalls, equalTo(1))
        assertThat(droneRemovedCalls, equalTo(1))
        assertThat(droneStore.getDevices(), `is`(empty()))

        // check the the data has been removed from the persistent store
        assertThat(mockPersistentStore.getDevicesUid(), `is`(empty()))

        enginesController.stop()
    }

    func testForgetRc() {
        mockPersistentStore.createDeviceDict(uid: "456", model: .rc(.skyCtrl3), name: "Rc1").commit()
        enginesController.start()

        // Check device has been created from the store
        assertThat(rcAddedCalls, equalTo(1))
        let rc = rcStore.getDevice(uid: rcStore.getDevices()[0].uid)

        _ = rc!.forget()
        assertThat(rcAddedCalls, equalTo(1))
        assertThat(rcRemovedCalls, equalTo(1))
        assertThat(rcStore.getDevices(), `is`(empty()))

        // check the the data has been removed from the persistent store
        assertThat(mockPersistentStore.getDevicesUid(), `is`(empty()))

        enginesController.stop()
    }

    func testAddRemoveRcDrone() {
        mockPersistentStore.createDeviceDict(uid: "456", model: .rc(.skyCtrl3), name: "Rc1").commit()
        enginesController.start()

        let arksdProxy = (arsdkEngine.deviceControllers["456"] as? ProxyDeviceController)?.arsdkProxy

        _ = arksdProxy?.addRemoteDevice(uid: "123", model: .drone(.anafi4k), name: "Drone1")

        assertThat(droneAddedCalls, equalTo(1))
        let drone = droneStore.getDevice(uid: droneStore.getDevices()[0].uid)
        assertThat(drone, presentAnd(allOf(
            has(uid: "123"),
            `is`(Drone.Model.anafi4k))))
        assertThat(drone?.stateHolder.state, presentAnd(allOf(
            `is`(DeviceState.ConnectionState.disconnected),
            `is`(DeviceState.ConnectionStateCause.none),
            canBeConnected(true),
            canBeDisconnected(false),
            canBeForgotten(true),
            has(connector: RemoteControlDeviceConnectorCore(uid: "456")))))

        arksdProxy?.removeRemoveDevice(uid: "123")
        assertThat(droneRemovedCalls, equalTo(1))
        assertThat(droneStore.getDevices(), hasCount(0))

        enginesController.stop()
    }

    func testAddRemoveLocalAndRcDrone() {
        mockPersistentStore.createDeviceDict(uid: "456", model: .rc(.skyCtrl3), name: "Rc1").commit()

        enginesController.start()
        let arksdProxy = (arsdkEngine.deviceControllers["456"] as? ProxyDeviceController)?.arsdkProxy

        // add local drone
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        let drone = droneStore.getDevice(uid: droneStore.getDevices()[0].uid)
        assertThat(droneAddedCalls, equalTo(1))
        assertThat(drone, presentAnd(allOf(
            has(uid: "123"),
            `is`(Drone.Model.anafi4k))))
        assertThat(drone?.stateHolder.state, presentAnd(allOf(
            `is`(DeviceState.ConnectionState.disconnected),
            `is`(DeviceState.ConnectionStateCause.none),
            canBeConnected(true),
            canBeDisconnected(false),
            canBeForgotten(false),
            has(connector: LocalDeviceConnectorCore.wifi))))

        // add remote drone
        _ = arksdProxy?.addRemoteDevice(uid: "123", model: .drone(.anafi4k), name: "Drone1")
        assertThat(droneAddedCalls, equalTo(1))
        assertThat(drone, presentAnd(allOf(
            has(uid: "123"),
            `is`(Drone.Model.anafi4k))))
        assertThat(drone?.stateHolder.state, presentAnd(allOf(
            `is`(DeviceState.ConnectionState.disconnected),
            `is`(DeviceState.ConnectionStateCause.none),
            canBeConnected(true),
            canBeDisconnected(false),
            canBeForgotten(true),
            has(connector: LocalDeviceConnectorCore.wifi),
            has(connector: RemoteControlDeviceConnectorCore(uid: "456")))))

        // remove remote drone
        arksdProxy?.removeRemoveDevice(uid: "123")
        assertThat(droneRemovedCalls, equalTo(0))
        assertThat(drone, presentAnd(allOf(
            has(uid: "123"),
            `is`(Drone.Model.anafi4k))))
        assertThat(drone?.stateHolder.state, presentAnd(allOf(
            `is`(DeviceState.ConnectionState.disconnected),
            `is`(DeviceState.ConnectionStateCause.none),
            canBeConnected(true),
            canBeDisconnected(false),
            canBeForgotten(false),
            has(connector: LocalDeviceConnectorCore.wifi))))

        // remove local drone
        mockArsdkCore.removeDevice(1)
        assertThat(droneRemovedCalls, equalTo(1))
        assertThat(droneStore.getDevices(), hasCount(0))

        enginesController.stop()
    }

}
