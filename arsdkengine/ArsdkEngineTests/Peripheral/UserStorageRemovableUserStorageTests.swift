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

class UserStorageRemovableUserStorageTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var storage: RemovableUserStorage?
    var storageRef: Ref<RemovableUserStorage>?
    var changeCnt = 0
    var transiantStateTester: (() -> Void)?
    var expectedState: RemovableUserStorageState?

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice(
            "123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1", handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        storageRef = drone.getPeripheral(Peripherals.removableUserStorage) { [unowned self] storage in
            self.storage = storage
            self.changeCnt += 1
            if let transiantStateTester = self.transiantStateTester {
                transiantStateTester()
                self.transiantStateTester = nil
            }

            if let expectedState = self.expectedState {
                // check if current state matches the expected state
                assertThat(expectedState, `is`(expectedState))
                self.expectedState = nil
            }
        }
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(storage, nilValue())

        connect(drone: drone, handle: 1)
        assertThat(storage, present())
        assertThat(changeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(storage, nilValue())
        assertThat(changeCnt, `is`(2))
    }

    func testState() {
        connect(drone: drone, handle: 1) {
             self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.userStorageCapabilitiesEncoder(
                supportedFeaturesBitField: Bitfield<ArsdkFeatureUserStorageFeature>.of(.formatResultEvtSupported)))
        }

        // check default values
        assertThat(storage!.state, `is`(.noMedia))
        assertThat(changeCnt, `is`(1))

        // Format denied
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.userStorageFormatResultEncoder(result: .denied))
        assertThat(storage!.state, `is`(.formattingDenied))
        assertThat(changeCnt, `is`(2))

        // Format success
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.userStorageFormatResultEncoder(result: .success))
        assertThat(storage!.state, `is`(.formattingSucceeded))
        assertThat(changeCnt, `is`(3))

        // Format error
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.userStorageFormatResultEncoder(result: .error))
        assertThat(storage!.state, `is`(.formattingFailed))
        assertThat(changeCnt, `is`(4))

        // check that all arsdk state have their corresponding gsdk states
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .tooSmall, fileSystemState: .error, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.mediaTooSmall))
        assertThat(changeCnt, `is`(5))

        // since monitor will be declared as enabled, we should stop monitoring
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.userStorageStopMonitoring())
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .tooSlow, fileSystemState: .formatNeeded, attributeBitField: 0,
                monitorEnabled: 1, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.mediaTooSlow))
        assertThat(changeCnt, `is`(6))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .usbMassStorage, fileSystemState: .unknown, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.usbMassStorage))
        assertThat(changeCnt, `is`(7))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .undetected, fileSystemState: .formatting, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.noMedia))
        assertThat(changeCnt, `is`(8))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .error, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.error))
        assertThat(changeCnt, `is`(9))

        // sdkCoreUnknown should be skipped
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .sdkCoreUnknown, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.error))
        assertThat(changeCnt, `is`(9))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .unknown, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.mounting))
        assertThat(changeCnt, `is`(10))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .formatNeeded, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.needFormat))
        assertThat(changeCnt, `is`(11))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .formatting, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.formatting))
        assertThat(changeCnt, `is`(12))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .ready, attributeBitField: 0,
                monitorEnabled: 1, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.ready))
        assertThat(changeCnt, `is`(13))

        // since monitor will be declared as disabled, we should start monitoring
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.userStorageStartMonitoring(period: 0))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .ready, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.ready))
        assertThat(changeCnt, `is`(13))

        // sdkCoreUnknown should be skipped
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .sdkCoreUnknown, fileSystemState: .unknown, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.ready))
        assertThat(changeCnt, `is`(13))
    }

    func testMediaInfo() {
        connect(drone: drone, handle: 1)

        // check initial values
        assertThat(storage!.mediaInfo, nilValue())
        assertThat(changeCnt, `is`(1))

        // mock storage state is not `.noMedia` in order to mock a `noMedia` change later in this test
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .ready, attributeBitField: 0,
                monitorEnabled: 1, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.ready))
        assertThat(changeCnt, `is`(2))

        // Mock media ready from low level
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageInfoEncoder(name: "name", capacity: 0))
        assertThat(storage!.mediaInfo, presentAnd(`is`(name: "name", capacity: 0)))
        assertThat(changeCnt, `is`(3))

        // mock capacity change
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageInfoEncoder(name: "name", capacity: 100))
        assertThat(storage!.mediaInfo, presentAnd(`is`(name: "name", capacity: 100)))
        assertThat(changeCnt, `is`(4))

        // mock name change
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageInfoEncoder(name: "name2", capacity: 100))
        assertThat(storage!.mediaInfo, presentAnd(`is`(name: "name2", capacity: 100)))
        assertThat(changeCnt, `is`(5))

        // mock same info received, no change should be notified
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageInfoEncoder(name: "name2", capacity: 100))
        assertThat(storage!.mediaInfo, presentAnd(`is`(name: "name2", capacity: 100)))
        assertThat(changeCnt, `is`(5))

        // mock no media detected, media info should be reset to null
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .undetected, fileSystemState: .unknown, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.mediaInfo, nilValue())
        assertThat(changeCnt, `is`(6))
    }

    func testAvailableSpace() {
        connect(drone: drone, handle: 1)

        // check initial values
        assertThat(storage!.availableSpace, lessThan(0))
        assertThat(changeCnt, `is`(1))

        // mock storage state is not `.noMedia` in order to mock a `noMedia` change later in this test
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .ready, attributeBitField: 0,
                monitorEnabled: 1, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.ready))
        assertThat(changeCnt, `is`(2))

        // mock available space received
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.userStorageMonitorEncoder(availableBytes: 100))
        assertThat(storage!.availableSpace, `is`(100))
        assertThat(changeCnt, `is`(3))

        // mock same info received, no change should be notified
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.userStorageMonitorEncoder(availableBytes: 100))
        assertThat(storage!.availableSpace, `is`(100))
        assertThat(changeCnt, `is`(3))

        // mock available space received
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.userStorageMonitorEncoder(availableBytes: 0))
        assertThat(storage!.availableSpace, `is`(0))
        assertThat(changeCnt, `is`(4))

        // mock no media detected, available space should be negative
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .undetected, fileSystemState: .unknown, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.availableSpace, lessThan(0))
        assertThat(changeCnt, `is`(5))
    }

    func testFormatWithFormatResultEvent() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.userStorageCapabilitiesEncoder(
                supportedFeaturesBitField: Bitfield<ArsdkFeatureUserStorageFeature>.of(.formatResultEvtSupported,
                                                                                       .formatWhenReadyAllowed)))

        }

        // check initial values
        assertThat(storage!.state, `is`(.noMedia))
        assertThat(changeCnt, `is`(1))

        // only test when the state is .needFormat. The other tests have been checked in the gsdk tests.
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .formatNeeded, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.needFormat))
        assertThat(changeCnt, `is`(2))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.userStorageFormat(label: "MediaName"))
        var res = storage?.format(formattingType: .quick, newMediaName: "MediaName")
        assertThat(res, presentAnd(`is`(true)))
        assertThat(storage!.state, `is`(.formatting))
        assertThat(changeCnt, `is`(3))

        // FormatResult received before StorageState
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageFormatResultEncoder(result: .success))
        assertThat(storage!.state, `is`(.formattingSucceeded))
        assertThat(changeCnt, `is`(4))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.userStorageStartMonitoring(period: 0))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .ready, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.ready))
        assertThat(changeCnt, `is`(5))

        // check that passing nil sends the command with an empty string
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .formatNeeded, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.needFormat))
        assertThat(changeCnt, `is`(6))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.userStorageFormat(label: ""))
        res = storage?.format(formattingType: .quick)
        assertThat(res, presentAnd(`is`(true)))
        assertThat(storage!.state, `is`(.formatting))
        assertThat(changeCnt, `is`(7))

        // FormatResult received after StorageState
        // State pending and no change
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.userStorageStartMonitoring(period: 0))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .ready, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.formatting))
        assertThat(changeCnt, `is`(7))

        transiantStateTester = {
            assertThat(self.storage!.state, `is`(.formattingSucceeded))
            assertThat(self.changeCnt, `is`(8))
        }
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageFormatResultEncoder(result: .success))
        assertThat(storage!.state, `is`(.ready))
        assertThat(changeCnt, `is`(9))

        // FormatResult is denied
        // Transient state should be issued, then state should be back at the latests state
        transiantStateTester = {
            assertThat(self.storage!.state, `is`(.formattingDenied))
            assertThat(self.changeCnt, `is`(10))
        }
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageFormatResultEncoder(result: .denied))
        assertThat(storage!.state, `is`(.ready))
        assertThat(changeCnt, `is`(11))
    }

    func testFormatWithoutFormatResultEvent() {
        connect(drone: drone, handle: 1)

        // check initial values
        assertThat(storage!.state, `is`(.noMedia))
        assertThat(changeCnt, `is`(1))

        // only test when the state is .needFormat. The other tests have been checked in the gsdk tests.
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .formatNeeded, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.needFormat))
        assertThat(changeCnt, `is`(2))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.userStorageFormat(label: "MediaName"))
        var res = storage?.format(formattingType: .quick, newMediaName: "MediaName")
        assertThat(res, presentAnd(`is`(true)))
        assertThat(storage!.state, `is`(.needFormat))
        assertThat(changeCnt, `is`(2))

        // FormatResult received StorageState formatting
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .formatting, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.formatting))
        assertThat(changeCnt, `is`(3))

        transiantStateTester = {
            assertThat(self.storage!.state, `is`(.formattingSucceeded))
            assertThat(self.changeCnt, `is`(4))
        }

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.userStorageStartMonitoring(period: 0))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .ready, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.ready))
        assertThat(changeCnt, `is`(5))

        // check that passing nil sends the command with an empty string
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .formatNeeded, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.needFormat))
        assertThat(changeCnt, `is`(6))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.userStorageFormat(label: ""))
        res = storage?.format(formattingType: .quick)
        assertThat(res, presentAnd(`is`(true)))
        assertThat(storage!.state, `is`(.needFormat))
        assertThat(changeCnt, `is`(6))

        // FormatResult received StorageState formatting
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .formatting, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.formatting))
        assertThat(changeCnt, `is`(7))

        transiantStateTester = {
            assertThat(self.storage!.state, `is`(.formattingSucceeded))
            assertThat(self.changeCnt, `is`(8))
        }

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.userStorageStartMonitoring(period: 0))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .ready, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.ready))
        assertThat(changeCnt, `is`(9))

        // format without label
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .formatNeeded, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.needFormat))
        assertThat(changeCnt, `is`(10))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.userStorageFormat(label: ""))
        res = storage?.format(formattingType: .quick)
        assertThat(res, presentAnd(`is`(true)))
        assertThat(storage!.state, `is`(.needFormat))
        assertThat(changeCnt, `is`(10))

        // FormatResult received StorageState formatting
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .formatting, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.formatting))
        assertThat(changeCnt, `is`(11))

        // FormatResult is failed by the receipt of state .formatNeeded instead of .ready
        // Transient state should be issued, then state should be back at the state received
        transiantStateTester = {
            assertThat(self.storage!.state, `is`(.formattingFailed))
            assertThat(self.changeCnt, `is`(12))
        }
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .formatNeeded, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.needFormat))
        assertThat(changeCnt, `is`(13))
    }

    func testFormattingType() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder:
                CmdEncoder.userStorageSupportedFormattingTypesEncoder(supportedTypesBitField:
                    Bitfield<ArsdkFeatureUserStorageFormattingType>.of(.quick, .full)))

            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.userStorageCapabilitiesEncoder(
                supportedFeaturesBitField: Bitfield<ArsdkFeatureUserStorageFeature>.of(.formatResultEvtSupported,
                                                                                       .formatWhenReadyAllowed)))
        }
        assertThat(storage!.state, `is`(.noMedia))
        assertThat(changeCnt, `is`(1))
        assertThat(storage!, supports(formattingTypes: [.quick, .full]))

        self.mockArsdkCore.onCommandReceived(1, encoder:
            CmdEncoder.userStorageSupportedFormattingTypesEncoder(supportedTypesBitField:
                Bitfield<ArsdkFeatureUserStorageFormattingType>.of(.full)))

        assertThat(changeCnt, `is`(2))
        assertThat(storage!, supports(formattingTypes: [.full]))

        self.mockArsdkCore.onCommandReceived(1, encoder:
            CmdEncoder.userStorageSupportedFormattingTypesEncoder(supportedTypesBitField:
                Bitfield<ArsdkFeatureUserStorageFormattingType>.of()))

        assertThat(changeCnt, `is`(3))
        assertThat(storage!, supports(formattingTypes: []))

        self.mockArsdkCore.onCommandReceived(1, encoder:
            CmdEncoder.userStorageSupportedFormattingTypesEncoder(supportedTypesBitField:
                Bitfield<ArsdkFeatureUserStorageFormattingType>.of()))
        assertThat(changeCnt, `is`(3))

        self.mockArsdkCore.onCommandReceived(1, encoder:
            CmdEncoder.userStorageSupportedFormattingTypesEncoder(supportedTypesBitField:
                Bitfield<ArsdkFeatureUserStorageFormattingType>.of(.full, .quick)))
        assertThat(changeCnt, `is`(4))
        assertThat(storage!, supports(formattingTypes: [.full, .quick]))

        // only test when the state is .needFormat. The other tests have been checked in the gsdk tests.
        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .formatNeeded, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.needFormat))
        assertThat(changeCnt, `is`(5))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.userStorageFormatWithType(label: "MediaName", type: .quick))
        let res = storage?.format(formattingType: .quick, newMediaName: "MediaName")
        assertThat(res, presentAnd(`is`(true)))
        assertThat(storage!.state, `is`(.formatting))
        assertThat(changeCnt, `is`(6))
    }

    func testFormatProgress() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.userStorageCapabilitiesEncoder(
                supportedFeaturesBitField: Bitfield<ArsdkFeatureUserStorageFeature>.of(.formatResultEvtSupported,
                                                                                       .formatWhenReadyAllowed)))
        }

        assertThat(storage!.state, `is`(.noMedia))
        assertThat(changeCnt, `is`(1))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .ready, attributeBitField: 0,
                monitorEnabled: 1, monitorPeriod: 0))
        assertThat(storage!.state, `is`(.ready))
        assertThat(changeCnt, `is`(2))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.userStorageFormat(label: "MediaName"))
        let res = storage?.format(formattingType: .quick, newMediaName: "MediaName")
        assertThat(res, presentAnd(`is`(true)))
        assertThat(storage!.state, `is`(.formatting))
        assertThat(changeCnt, `is`(3))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .formatting, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))
        // count should not change since we are already in state formatting and can't format.
        assertThat(changeCnt, `is`(3))
        assertThat(storage!.formattingState, nilValue())
        self.mockArsdkCore.onCommandReceived(1, encoder:
            CmdEncoder.userStorageFormatProgressEncoder(step: .partitioning, percentage: 0))
        assertThat(storage!.state, `is`(.formatting))
        assertThat(storage!.formattingState?.step, `is`(.partitioning))
        assertThat(storage!.formattingState?.progress, `is`(0))
        assertThat(changeCnt, `is`(4))

        self.mockArsdkCore.onCommandReceived(1, encoder:
            CmdEncoder.userStorageFormatProgressEncoder(step: .partitioning, percentage: 20))
        assertThat(storage!.state, `is`(.formatting))
        assertThat(storage!.formattingState?.step, `is`(.partitioning))
        assertThat(storage!.formattingState?.progress, `is`(20))
        assertThat(changeCnt, `is`(5))

        self.mockArsdkCore.onCommandReceived(1, encoder:
            CmdEncoder.userStorageFormatProgressEncoder(step: .creatingFs, percentage: 30))
        assertThat(storage!.state, `is`(.formatting))
        assertThat(storage!.formattingState?.step, `is`(.creatingFs))
        assertThat(storage!.formattingState?.progress, `is`(30))
        assertThat(changeCnt, `is`(6))

        self.mockArsdkCore.onCommandReceived(1, encoder:
            CmdEncoder.userStorageFormatProgressEncoder(step: .clearingData, percentage: 50))
        assertThat(storage!.state, `is`(.formatting))
        assertThat(storage!.formattingState?.step, `is`(.clearingData))
        assertThat(storage!.formattingState?.progress, `is`(50))
        assertThat(changeCnt, `is`(7))

        self.mockArsdkCore.onCommandReceived(1, encoder:
            CmdEncoder.userStorageFormatProgressEncoder(step: .clearingData, percentage: 100))
        assertThat(storage!.state, `is`(.formatting))
        assertThat(storage!.formattingState?.step, `is`(.clearingData))
        assertThat(storage!.formattingState?.progress, `is`(100))
        assertThat(changeCnt, `is`(8))

        // same command received, should not change count.
        self.mockArsdkCore.onCommandReceived(1, encoder:
            CmdEncoder.userStorageFormatProgressEncoder(step: .clearingData, percentage: 100))
        assertThat(storage!.state, `is`(.formatting))
        assertThat(storage!.formattingState?.step, `is`(.clearingData))
        assertThat(storage!.formattingState?.progress, `is`(100))
        assertThat(changeCnt, `is`(8))

        transiantStateTester = {
            assertThat(self.storage!.state, `is`(.formattingSucceeded))
            assertThat(self.changeCnt, `is`(9))
        }
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.userStorageFormatResultEncoder(result: .success))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.userStorageStartMonitoring(period: 0))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.userStorageStateEncoder(
                physicalState: .available, fileSystemState: .ready, attributeBitField: 0,
                monitorEnabled: 0, monitorPeriod: 0))

        assertThat(storage!.state, `is`(.ready))
        assertThat(changeCnt, `is`(10))
        assertThat(storage!.formattingState, nilValue())
    }
}
