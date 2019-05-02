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
class ArsdkEngineConnectTests: XCTestCase {

    let droneStore = DroneStoreUtilityCore()
    let rcStore = RemoteControlStoreUtilityCore()
    var enginesController: MockEnginesController!
    var arsdkEngine: MockArsdkEngine!
    var mockArsdkCore: MockArsdkCore!
    var mockPersistentStore: MockPersistentStore!

    override func setUp() {
        super.setUp()
        let utilities = UtilityCoreRegistry()
        utilities.publish(utility: droneStore)
        utilities.publish(utility: rcStore)
        GroundSdkConfig.sharedInstance.enableCrashReport = false
        GroundSdkConfig.sharedInstance.enableFlightData = false
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

    override func tearDown() {
        GroundSdkConfig.sharedInstance.enableCrashReport = true
        GroundSdkConfig.sharedInstance.enableFlightData = true
    }

    func expectDateAccordingToDrone(drone: DroneCore, handle: Int16, file: String = #file, line: UInt = #line) {
        mockArsdkCore.expect(CommandExpectation(
            handle: handle, expectedCmds: [ExpectedCmd.commonCommonCurrentdatetime(datetime: "")],
            checkParams: false, inFile: file, atLine: line))
    }

    func testConnectDisconnectDrone() {
        enginesController.start()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        let drone = droneStore.getDevice(uid: droneStore.getDevices()[0].uid)

        expectConnect(handle: 1)
        _ = drone?.connect(connector: LocalDeviceConnectorCore.wifi, password: nil)
        assertThat(drone, present())
        assertThat(drone!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.connecting),
                `is`(DeviceState.ConnectionStateCause.userRequest),
                canBeConnected(false),
                canBeDisconnected(true),
                hasActiveConnector(LocalDeviceConnectorCore.wifi))))

        mockArsdkCore.deviceConnecting(1)
        assertThat(drone!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.connecting),
                `is`(DeviceState.ConnectionStateCause.userRequest),
                canBeConnected(false),
                canBeDisconnected(true),
                has(connector: LocalDeviceConnectorCore.wifi))))

        // after that the sdk is connect, we expect to send a date, time and get all settings
        expectDateAccordingToDrone(drone: drone!, handle: 1)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonSettingsAllsettings())
        mockArsdkCore.deviceConnected(1)

        // after receiving the all settings ended, we expect to send the get all states
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonCommonAllstates())
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.commonSettingsstateAllsettingschangedEncoder())

        // after receiving the all states ended, we expect the state to be connected
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.commonCommonstateAllstateschangedEncoder())
        assertThat(drone!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.connected),
                `is`(DeviceState.ConnectionStateCause.userRequest),
                canBeConnected(false),
                canBeDisconnected(true),
                has(connector: LocalDeviceConnectorCore.wifi))))

        expectDisconnect(handle: 1)
        _ = drone!.disconnect()
        // TODO: check disconnect call and cmd params
        assertThat(drone!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.disconnecting),
                `is`(DeviceState.ConnectionStateCause.userRequest),
                canBeConnected(false),
                canBeDisconnected(false),
                hasActiveConnector(LocalDeviceConnectorCore.wifi))))

        mockArsdkCore.deviceDisconnected(1, removing: false)
        assertThat(drone!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.disconnected),
                `is`(DeviceState.ConnectionStateCause.userRequest),
                canBeConnected(true),
                canBeDisconnected(false),
                dontHaveActiveConnector())))

        enginesController.stop()
    }

    func testConnectDroneCancel() {
        enginesController.start()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        let drone = droneStore.getDevice(uid: droneStore.getDevices()[0].uid)

        assertThat(drone, present())
        expectConnect(handle: 1)
        _ = drone?.connect(connector: LocalDeviceConnectorCore.wifi, password: nil)
        assertThat(drone!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.connecting),
                `is`(DeviceState.ConnectionStateCause.userRequest),
                canBeConnected(false),
                canBeDisconnected(true),
                hasActiveConnector(LocalDeviceConnectorCore.wifi))))
        // TODO: check connect call and cmd params

        mockArsdkCore.deviceConnecting(1)
        assertThat(drone!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.connecting),
                `is`(DeviceState.ConnectionStateCause.userRequest),
                canBeConnected(false),
                canBeDisconnected(true),
                has(connector: LocalDeviceConnectorCore.wifi))))

        // Disconnect before getting connected
        expectDisconnect(handle: 1)
        _ = drone!.disconnect()
        // check that the drone is disconnecting
        assertThat(drone!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.disconnecting),
                `is`(DeviceState.ConnectionStateCause.userRequest),
                canBeConnected(false),
                canBeDisconnected(false),
                hasActiveConnector(LocalDeviceConnectorCore.wifi))))

        mockArsdkCore.deviceDisconnected(1, removing: false)
        assertThat(drone!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.disconnected),
                `is`(DeviceState.ConnectionStateCause.userRequest),
                canBeConnected(true),
                canBeDisconnected(false),
                dontHaveActiveConnector())))
        enginesController.stop()
    }

    func testConnectDroneRejected() {
        enginesController.start()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        let drone = droneStore.getDevice(uid: droneStore.getDevices()[0].uid)

        assertThat(drone, present())
        expectConnect(handle: 1)
        _ = drone?.connect(connector: LocalDeviceConnectorCore.wifi, password: nil)
        assertThat(drone!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.connecting),
                `is`(DeviceState.ConnectionStateCause.userRequest),
                canBeConnected(false),
                canBeDisconnected(true),
                hasActiveConnector(LocalDeviceConnectorCore.wifi))))

        mockArsdkCore.deviceConnectingCancel(1, reason: ArsdkConnCancelReason.reject, removing: false)
        assertThat(drone!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.disconnected),
                `is`(DeviceState.ConnectionStateCause.refused),
                canBeConnected(true),
                canBeDisconnected(false),
                dontHaveActiveConnector())))

        enginesController.stop()
    }

    func testDisconnectRemovingDrone() {
        enginesController.start()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        let drone = droneStore.getDevice(uid: droneStore.getDevices()[0].uid)

        expectConnect(handle: 1)
        _ = drone?.connect(connector: LocalDeviceConnectorCore.wifi, password: nil)
        mockArsdkCore.deviceConnecting(1)
        // after that the sdk is connect, we expect to send a date, time and get all settings
        expectDateAccordingToDrone(drone: drone!, handle: 1)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonSettingsAllsettings())
        mockArsdkCore.deviceConnected(1)

        // after receiving the all settings ended, we expect to send the get all states
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonCommonAllstates())
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.commonSettingsstateAllsettingschangedEncoder())

        // after receiving the all states ended, drone is connected
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.commonCommonstateAllstateschangedEncoder())

        // simulate disconnect with removing set to true
        // this should trigger auto-reconnection
        expectConnect(handle: 1)
        mockArsdkCore.deviceDisconnected(1, removing: true)

        // expect device disconnected and not connectable (i.e. without any connectors)
        assertThat(drone!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.disconnected),
                `is`(DeviceState.ConnectionStateCause.connectionLost),
                canBeConnected(false),
                canBeDisconnected(false),
                dontHaveConnectors())))

        enginesController.stop()
    }

    func testConnectingCancelRemovingDrone() {
        enginesController.start()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        let drone = droneStore.getDevice(uid: droneStore.getDevices()[0].uid)

        expectConnect(handle: 1)
        _ = drone?.connect(connector: LocalDeviceConnectorCore.wifi, password: nil)
        mockArsdkCore.deviceConnecting(1)

        // simulate disconnect with removing set to true
        // this should trigger auto-reconnection
        expectConnect(handle: 1)
        mockArsdkCore.deviceConnectingCancel(1, reason: ArsdkConnCancelReason.local, removing: true)
        // expect device disconnected and not connectable (i.e. without any connectors)
        assertThat(drone!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.disconnected),
                `is`(DeviceState.ConnectionStateCause.connectionLost),
                canBeConnected(false),
                canBeDisconnected(false),
                dontHaveConnectors())))

        enginesController.stop()
    }

    func testConnectDisconnectRemoteControl() {
        enginesController.start()
        mockArsdkCore.addDevice("123", type: RemoteControl.Model.skyCtrl3.internalId, backendType: .mux,
                                name: "SkyCtrl", handle: 1)
        let rc = rcStore.getDevice(uid: rcStore.getDevices()[0].uid)

        expectConnect(handle: 1)
        _ = rc?.connect(connector: nil, password: nil)
        assertThat(rc, present())
        assertThat(rc!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.connecting),
                `is`(DeviceState.ConnectionStateCause.userRequest),
                canBeConnected(false),
                canBeDisconnected(true),
                hasActiveConnector(LocalDeviceConnectorCore.usb))))

        mockArsdkCore.deviceConnecting(1)
        assertThat(rc!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.connecting),
                `is`(DeviceState.ConnectionStateCause.userRequest),
                canBeConnected(false),
                canBeDisconnected(true),
                has(connector: LocalDeviceConnectorCore.usb))))

        // after that the sdk is connect, we expect to send a date, time and get all settings
        expectCommand(
            handle: 1, expectedCmd: ExpectedCmd.skyctrlCommonCurrentdatetime(datetime: ""), checkParams: false)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.skyctrlSettingsAllsettings())
        mockArsdkCore.deviceConnected(1)

        // after receiving the all settings ended, we expect to send the get all states
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.skyctrlCommonAllstates())
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.skyctrlSettingsstateAllsettingschangedEncoder())

        // after receiving the all states ended, we expect the state to be connected
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.skyctrlCommonstateAllstateschangedEncoder())
        assertThat(rc!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.connected),
                `is`(DeviceState.ConnectionStateCause.userRequest),
                canBeConnected(false),
                canBeDisconnected(true),
                has(connector: LocalDeviceConnectorCore.usb))))

        expectDisconnect(handle: 1)
        _ = rc!.disconnect()
        // TODO: check disconnect call and cmd params
        assertThat(rc!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.disconnecting),
                `is`(DeviceState.ConnectionStateCause.userRequest),
                canBeConnected(false),
                canBeDisconnected(false),
                hasActiveConnector(LocalDeviceConnectorCore.usb))))

        mockArsdkCore.deviceDisconnected(1, removing: false)
        assertThat(rc!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.disconnected),
                `is`(DeviceState.ConnectionStateCause.userRequest),
                canBeConnected(true),
                canBeDisconnected(false),
                dontHaveActiveConnector())))

        enginesController.stop()
    }

    func testConnectRemoteControlCancel() {
        enginesController.start()
        mockArsdkCore.addDevice("123", type: RemoteControl.Model.skyCtrl3.internalId, backendType: .mux,
                                name: "SkyCtrl", handle: 1)
        let rc = rcStore.getDevice(uid: rcStore.getDevices()[0].uid)

        assertThat(rc, present())
        expectConnect(handle: 1)
        _ = rc?.connect(connector: nil, password: nil)
        assertThat(rc!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.connecting),
                `is`(DeviceState.ConnectionStateCause.userRequest),
                canBeConnected(false),
                canBeDisconnected(true),
                hasActiveConnector(LocalDeviceConnectorCore.usb))))
        // TODO: check connect call and cmd params

        mockArsdkCore.deviceConnecting(1)
        assertThat(rc!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.connecting),
                `is`(DeviceState.ConnectionStateCause.userRequest),
                canBeConnected(false),
                canBeDisconnected(true),
                has(connector: LocalDeviceConnectorCore.usb))))

        // Disconnect before getting connected
        expectDisconnect(handle: 1)
        _ = rc!.disconnect()
        // check that the drone is disconnecting
        assertThat(rc!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.disconnecting),
                `is`(DeviceState.ConnectionStateCause.userRequest),
                canBeConnected(false),
                canBeDisconnected(false),
                hasActiveConnector(LocalDeviceConnectorCore.usb))))

        mockArsdkCore.deviceDisconnected(1, removing: false)
        assertThat(rc!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.disconnected),
                `is`(DeviceState.ConnectionStateCause.userRequest),
                canBeConnected(true),
                canBeDisconnected(false),
                dontHaveActiveConnector())))
        enginesController.stop()
    }

    func testConnectRemoteControlRejected() {
        enginesController.start()
        mockArsdkCore.addDevice("123", type: RemoteControl.Model.skyCtrl3.internalId, backendType: .net,
                                name: "SkyCtrl", handle: 1)
        let rc = rcStore.getDevice(uid: rcStore.getDevices()[0].uid)

        assertThat(rc, present())
        expectConnect(handle: 1)
        _ = rc?.connect(connector: LocalDeviceConnectorCore.wifi, password: nil)
        assertThat(rc!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.connecting),
                `is`(DeviceState.ConnectionStateCause.userRequest),
                canBeConnected(false),
                canBeDisconnected(true),
                hasActiveConnector(LocalDeviceConnectorCore.wifi))))

        mockArsdkCore.deviceConnectingCancel(1, reason: ArsdkConnCancelReason.reject, removing: false)
        assertThat(rc!.stateHolder.state, presentAnd(
            allOf(
                `is`(DeviceState.ConnectionState.disconnected),
                `is`(DeviceState.ConnectionStateCause.refused),
                canBeConnected(true),
                canBeDisconnected(false),
                dontHaveActiveConnector())))

        enginesController.stop()
    }

    func expectConnect(handle: Int16, file: String = #file, line: UInt = #line) {
        mockArsdkCore.expect(ConnectExpectation(handle: handle, inFile: file, atLine: line))
    }

    func expectDisconnect(handle: Int16, file: String = #file, line: UInt = #line) {
        mockArsdkCore.expect(DisconnectExpectation(handle: handle, inFile: file, atLine: line))
    }

    func expectCommand(handle: Int16, expectedCmd: ExpectedCmd, checkParams: Bool = false,
                       file: String = #file, line: UInt = #line) {
        mockArsdkCore.expect(CommandExpectation(handle: handle, expectedCmds: [expectedCmd], checkParams: checkParams,
                                                inFile: file, atLine: line))
    }
}
