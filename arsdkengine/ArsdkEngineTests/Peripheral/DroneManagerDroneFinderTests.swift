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

class DroneManagerDroneFinderTests: ArsdkEngineTestBase {

    var remoteControl: RemoteControlCore!
    var droneFinder: DroneFinder?
    var droneFinderRef: Ref<DroneFinder>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("123", type: RemoteControl.Model.skyCtrl3.internalId, backendType: .mux, name: "RC1",
                                handle: 1)
        remoteControl = rcStore.getDevice(uid: "123")!

        droneFinderRef = remoteControl.getPeripheral(Peripherals.droneFinder) { [unowned self] droneFinder in
            self.droneFinder = droneFinder
            self.changeCnt += 1
        }
        changeCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(droneFinder, `is`(nilValue()))

        connect(remoteControl: remoteControl, handle: 1)
        assertThat(droneFinder, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(remoteControl: remoteControl, handle: 1)
        assertThat(droneFinder, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testRefresh() {
        connect(remoteControl: remoteControl, handle: 1)

        assertThat(droneFinder!.state, `is`(.idle))
        assertThat(changeCnt, `is`(1))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.droneManagerDiscoverDrones())
        droneFinder!.refresh()

        assertNoExpectation()
        assertThat(changeCnt, `is`(2))
        assertThat(droneFinder!.state, `is`(.scanning))

        // scan completed
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerDroneListItemEncoder(
                serial: "1", model: UInt(Drone.Model.anafi4k.internalId), name: "Anafi4k", connectionOrder: 0,
                active: 0,
                visible: 1, security: ArsdkFeatureDroneManagerSecurity.none, hasSavedKey: 0, rssi: -20,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last)))

        assertThat(changeCnt, `is`(3))
        assertThat(droneFinder!.state, `is`(.idle))
    }

    func testDroneList() {
        connect(remoteControl: remoteControl, handle: 1)

        assertThat(droneFinder!.discoveredDrones, `is`(empty()))
        assertThat(changeCnt, `is`(1))
        // add first
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerDroneListItemEncoder(
                serial: "1", model: UInt(Drone.Model.anafi4k.internalId), name: "Anafi4k", connectionOrder: 0,
                active: 0,
                visible: 1, security: ArsdkFeatureDroneManagerSecurity.none, hasSavedKey: 0, rssi: -20,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))

        // should not be notified until "Last"
        assertThat(changeCnt, `is`(1))
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.droneManagerDroneListItemEncoder(
                serial: "2",
                model: UInt(Drone.Model.anafiThermal.internalId), name: "AnafiThermal", connectionOrder: 1,
                active: 0, visible: 1, security: ArsdkFeatureDroneManagerSecurity.wpa2, hasSavedKey: 0, rssi: -50,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of()))

        // should not be notified until "Last"
        assertThat(changeCnt, `is`(1))
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.droneManagerDroneListItemEncoder(
                serial: "3",
                model: UInt(Drone.Model.anafiUa.internalId), name: "AnafiUa", connectionOrder: 0,
                active: 0, visible: 1, security: ArsdkFeatureDroneManagerSecurity.none, hasSavedKey: 0, rssi: -52,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))

        assertThat(changeCnt, `is`(2))
        assertThat(droneFinder!.discoveredDrones, hasCount(3))

        // should not be notified until "Last"
        assertThat(changeCnt, `is`(2))
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.droneManagerDroneListItemEncoder(
                serial: "5",
                model: UInt(Drone.Model.anafiUsa.internalId), name: "AnafiUsa", connectionOrder: 0,
                active: 0, visible: 1, security: ArsdkFeatureDroneManagerSecurity.none, hasSavedKey: 0, rssi: -52,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))

        assertThat(changeCnt, `is`(3))
        assertThat(droneFinder!.discoveredDrones, hasCount(4))

        // expect drones sorted by rssi, then name
        assertThat(droneFinder!.discoveredDrones[0], allOf(
            has(uid: "1"),
            `is`(.anafi4k),
            has(name: "Anafi4k"),
            has(rssi: -20),
            `is`(known: false),
            has(connectionSecurity: .none)))

        assertThat(droneFinder!.discoveredDrones[1], allOf(
            has(uid: "2"),
            `is`(Drone.Model.anafiThermal),
            has(name: "AnafiThermal"),
            has(rssi: -50),
            `is`(known: true),
            has(connectionSecurity: .password)))

        assertThat(droneFinder!.discoveredDrones[2], allOf(
            has(uid: "3"),
            `is`(Drone.Model.anafiUa),
            has(name: "AnafiUa"),
            has(rssi: -52),
            `is`(known: false),
            has(connectionSecurity: .none)))

        assertThat(droneFinder!.discoveredDrones[3], allOf(
            has(uid: "5"),
            `is`(Drone.Model.anafiUsa),
            has(name: "AnafiUsa"),
            has(rssi: -52),
            `is`(known: false),
            has(connectionSecurity: .none)))

        // remove
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerDroneListItemEncoder(
                serial: "1", model: UInt(Drone.Model.anafi4k.internalId), name: "Anafi4k", connectionOrder: 0,
                active: 0,
                visible: 1, security: ArsdkFeatureDroneManagerSecurity.none, hasSavedKey: 0, rssi: -20,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.remove, .last)))
        assertThat(changeCnt, `is`(4))
        assertThat(droneFinder!.discoveredDrones, hasCount(3))
        assertThat(droneFinder!.discoveredDrones[0], has(uid: "2"))

        // empty
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerDroneListItemEncoder(
                serial: "1", model: UInt(Drone.Model.anafi4k.internalId), name: "Anafi4k", connectionOrder: 0,
                active: 0,
                visible: 1, security: ArsdkFeatureDroneManagerSecurity.none, hasSavedKey: 0, rssi: -20,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.empty)))
        assertThat(changeCnt, `is`(5))
        assertThat(droneFinder!.discoveredDrones, `is`(empty()))

        // first
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerDroneListItemEncoder(
                serial: "1", model: UInt(Drone.Model.anafi4k.internalId), name: "Anafi4k", connectionOrder: 0,
                active: 0,
                visible: 1, security: ArsdkFeatureDroneManagerSecurity.none, hasSavedKey: 0, rssi: -20,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerDroneListItemEncoder(
                serial: "2",
                model: UInt(Drone.Model.anafiThermal.internalId), name: "AnafiThermal", connectionOrder: 1, active: 0,
                visible: 1, security: ArsdkFeatureDroneManagerSecurity.wpa2, hasSavedKey: 0, rssi: -50,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last)))
        assertThat(changeCnt, `is`(6))
        assertThat(droneFinder!.discoveredDrones, hasCount(1))
        assertThat(droneFinder!.discoveredDrones[0], has(uid: "2"))

    }

    func testConnect() {
        connect(remoteControl: remoteControl, handle: 1)
        assertThat(changeCnt, `is`(1))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerDroneListItemEncoder(
                serial: "1", model: UInt(Drone.Model.anafi4k.internalId), name: "Anafi4k", connectionOrder: 0,
                active: 0,
                visible: 1, security: ArsdkFeatureDroneManagerSecurity.none, hasSavedKey: 0, rssi: -20,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last)))

        assertThat(changeCnt, `is`(2))
        assertThat(droneFinder!.discoveredDrones, hasCount(1))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.droneManagerConnect(serial: "1", key: "qwertyui"))
        _ = droneFinder!.connect(discoveredDrone: droneFinder!.discoveredDrones[0], password: "qwertyui")

        // mock the drone is connecting so that ArsdkProxy has an active device we can then disconnect
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerConnectionStateEncoder(
                state: .connecting, serial: "1",
                model: UInt(Drone.Model.anafi4k.internalId), name: "Anafi4k"))
        // disconnect the drone so that we can connect again
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.droneManagerConnectionStateEncoder(
                state: .idle, serial: "1",
                model: UInt(Drone.Model.anafi4k.internalId), name: "Anafi4k"))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.droneManagerConnect(serial: "1", key: ""))
        _ = droneFinder!.connect(discoveredDrone: droneFinder!.discoveredDrones[0])
    }
}
