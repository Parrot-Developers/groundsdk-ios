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

/// Drone manager feature test
class DroneManagerFeatureTests: ArsdkEngineTestBase {

    var remoteControl: RemoteControlCore!

    override func setUp() {
        super.setUp()

        mockArsdkCore.addDevice("456", type: RemoteControl.Model.skyCtrl3.internalId, backendType: .mux, name: "RC",
                                handle: 1)
        remoteControl = rcStore.getDevice(uid: "456")!
        connect(remoteControl: remoteControl, handle: 1)
    }

    func testKnownDroneList() {
        // add one drone
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerKnownDroneItemEncoder(
                serial: "11", model: UInt(Drone.Model.anafi4k.internalId),
                name: "d1", security: ArsdkFeatureDroneManagerSecurity.none, hasSavedKey: 0,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))

        assertThat(droneStore.getDevices().count, `is`(1))
        let drone1 = droneStore.getDevice(uid: "11")
        assertThat(drone1, present())

        // add (new list)
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerKnownDroneItemEncoder(
                serial: "22", model: UInt(Drone.Model.anafi4k.internalId),
                name: "d2", security: ArsdkFeatureDroneManagerSecurity.none, hasSavedKey: 0,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))

        assertThat(droneStore.getDevices().count, `is`(1))
        assertThat(droneStore.getDevice(uid: "22"), present())

        // add one more device
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerKnownDroneItemEncoder(
                serial: "33", model: UInt(Drone.Model.anafi4k.internalId),
                name: "d3", security: ArsdkFeatureDroneManagerSecurity.none, hasSavedKey: 0,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))
        assertThat(droneStore.getDevices().count, `is`(2))
        assertThat(droneStore.getDevice(uid: "22"), present())
        assertThat(droneStore.getDevice(uid: "33"), present())

        // remove one device
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerKnownDroneItemEncoder(
                serial: "22", model: UInt(Drone.Model.anafi4k.internalId),
                name: "d2", security: ArsdkFeatureDroneManagerSecurity.none, hasSavedKey: 0,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.remove)))

        assertThat(droneStore.getDevices().count, `is`(1))
        assertThat(droneStore.getDevice(uid: "33"), present())

        // remove all
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerKnownDroneItemEncoder(
                serial: "22", model: UInt(Drone.Model.anafi4k.internalId),
                name: "d2", security: ArsdkFeatureDroneManagerSecurity.none, hasSavedKey: 0,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.empty)))
        assertThat(droneStore.getDevices().count, `is`(0))
    }

    func testDroneConnectionState() {
        // add a drone
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerKnownDroneItemEncoder(
                serial: "11", model: UInt(Drone.Model.anafi4k.internalId),
                name: "d1", security: ArsdkFeatureDroneManagerSecurity.none, hasSavedKey: 0,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))

        assertThat(droneStore.getDevices().count, `is`(1))
        let drone1 = droneStore.getDevice(uid: "11")
        assertThat(drone1, present())

        // state connecting
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerConnectionStateEncoder(
                state: .connecting, serial: "11",
                model: UInt(Drone.Model.anafi4k.internalId), name: "d1"))
        // expect drone to be connecting
        assertThat(drone1?.stateHolder.state, presentAnd(`is`(DeviceState.ConnectionState.connecting)))

        // state connected
        assertNoExpectation()
        // expect connection to the remote drone
        expectDateAccordingToDrone(drone: drone1!, handle: 1)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonSettingsAllsettings())
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonCommonAllstates())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerConnectionStateEncoder(
                state: .connected, serial: "11",
                model: UInt(Drone.Model.anafi4k.internalId), name: "d1"))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.commonSettingsstateAllsettingschangedEncoder())
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.commonCommonstateAllstateschangedEncoder())

        assertNoExpectation()

        // expect drone to be connected
        assertThat(drone1?.stateHolder.state, presentAnd(`is`(DeviceState.ConnectionState.connected)))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerConnectionStateEncoder(
                state: .disconnecting, serial: "11",
                model: UInt(Drone.Model.anafi4k.internalId), name: "d1"))

        assertThat(drone1?.stateHolder.state, presentAnd(`is`(DeviceState.ConnectionState.disconnected)))
    }

    /// Test that when a drone is directly connected, if the rc is connecting to it, it won't change its state
    func testDroneConnectingWhenDirectlyConnected() {
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "anafi4k",
                                handle: 2)
        let drone = droneStore.getDevice(uid: "123")!
        connect(drone: drone, handle: 2)

        assertThat(drone.stateHolder.state, presentAnd(allOf(
            `is`(DeviceState.ConnectionState.connected),
            hasActiveConnector(LocalDeviceConnectorCore.wifi))))

        // add a drone
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerKnownDroneItemEncoder(
                serial: "11", model: UInt(Drone.Model.anafi4k.internalId),
                name: "d1", security: ArsdkFeatureDroneManagerSecurity.none, hasSavedKey: 0,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))

        // state connecting
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerConnectionStateEncoder(
                state: .connecting, serial: "11",
                model: UInt(Drone.Model.anafi4k.internalId), name: "d1"))

        // expect drone to be connected and active connector is the local one
        assertThat(drone.stateHolder.state, presentAnd(allOf(
            `is`(DeviceState.ConnectionState.connected),
            hasActiveConnector(LocalDeviceConnectorCore.wifi))))
    }

    func testDroneAuthFail() {
        // add a drone
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerKnownDroneItemEncoder(
                serial: "11", model: UInt(Drone.Model.anafi4k.internalId),
                name: "d1", security: ArsdkFeatureDroneManagerSecurity.none, hasSavedKey: 0,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))

        assertThat(droneStore.getDevices().count, `is`(1))
        let drone1 = droneStore.getDevice(uid: "11")
        assertThat(drone1, present())

        // state connecting
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerConnectionStateEncoder(
                state: .connecting, serial: "11",
                model: UInt(Drone.Model.anafi4k.internalId), name: "d1"))

        // auth failure
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerAuthenticationFailedEncoder(
                serial: "11",
                model: UInt(Drone.Model.anafi4k.internalId), name: "d1"))

        assertThat(drone1?.stateHolder.state, presentAnd(`is`(DeviceState.ConnectionState.disconnected)))
        assertThat(drone1?.stateHolder.state, presentAnd(`is`(DeviceState.ConnectionStateCause.badPassword)))
    }

}
