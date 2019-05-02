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

class AnafiSystemInfoTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var systemInfo: SystemInfo?
    var systemInfoRef: Ref<SystemInfo>?
    var changeCnt = 0
    var updateChangeCnt = 0

    override func setUp() {
        super.setUp()
        setUpDrone()
    }

    private func setUpDrone() {
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        systemInfoRef = drone.getPeripheral(Peripherals.systemInfo) { [unowned self] systemInfo in
            self.systemInfo = systemInfo
            self.changeCnt += 1
        }
        changeCnt = 0
    }

    override func resetArsdkEngine() {
        super.resetArsdkEngine()
        setUpDrone()
    }

    func testPublishUnpublish() {
        // should be available when the drone is not connected
        assertThat(systemInfo, `is`(nilValue()))

        connect(drone: drone, handle: 1)
        assertThat(systemInfo, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(systemInfo, `is`(present()))
        assertThat(changeCnt, `is`(1))

        _ = drone.forget()
        assertThat(systemInfo, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testPublishUnpublishWithPersistentValues() {
        // mock new blacklist received
        let anafi4kModel = DeviceModel.drone(.anafi4k)
        var blacklistEntry = BlacklistStoreEntry(deviceModel: anafi4kModel, versions: [], embedded: false)
        blacklistEntry.add(versions: [FirmwareVersion.parse(versionStr: "1.2.3-beta1")!])
        blacklistStore.resetBlacklist([anafi4kModel: blacklistEntry])

        // should be unavailable when the drone is not connected
        assertThat(systemInfo, `is`(nilValue()))

        connect(drone: drone, handle: 1)
        assertThat(systemInfo, `is`(present()))
        assertThat(changeCnt, `is`(1))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(
                software: "1.2.3-beta1", hardware: "HW11"))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonSettingsstateProductseriallowchangedEncoder(low: "low"))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonSettingsstateProductserialhighchangedEncoder(high: "high"))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonSettingsstateBoardidchangedEncoder(id: "board id"))
        assertThat(systemInfo!.firmwareVersion, `is`("1.2.3-beta1"))
        assertThat(systemInfo!.isFirmwareBlacklisted, `is`(true))
        assertThat(systemInfo!.hardwareVersion, `is`("HW11"))
        assertThat(systemInfo!.serial, `is`("highlow"))
        assertThat(systemInfo!.boardId, `is`("board id"))
        assertThat(changeCnt, `is`(4))

        disconnect(drone: drone, handle: 1)
        assertThat(systemInfo, `is`(present()))
        assertThat(systemInfo!.firmwareVersion, `is`("1.2.3-beta1"))
        assertThat(systemInfo!.isFirmwareBlacklisted, `is`(true))
        assertThat(systemInfo!.hardwareVersion, `is`("HW11"))
        assertThat(systemInfo!.serial, `is`("highlow"))
        assertThat(systemInfo!.boardId, `is`("board id"))
        assertThat(changeCnt, `is`(4))

        // restart engine
        resetArsdkEngine()
        assertThat(systemInfo, `is`(present()))
        assertThat(systemInfo!.firmwareVersion, `is`("1.2.3-beta1"))
        assertThat(systemInfo!.isFirmwareBlacklisted, `is`(true))
        assertThat(systemInfo!.hardwareVersion, `is`("HW11"))
        assertThat(systemInfo!.serial, `is`("highlow"))
        assertThat(systemInfo!.boardId, `is`("board id"))
        assertThat(changeCnt, `is`(0))

        // connect and check values
        connect(drone: drone, handle: 1)
        assertThat(systemInfo, `is`(present()))
        assertThat(systemInfo!.firmwareVersion, `is`("1.2.3-beta1"))
        assertThat(systemInfo!.isFirmwareBlacklisted, `is`(true))
        assertThat(systemInfo!.hardwareVersion, `is`("HW11"))
        assertThat(systemInfo!.serial, `is`("highlow"))
        assertThat(systemInfo!.boardId, `is`("board id"))
        assertThat(changeCnt, `is`(0))

        // change values and disconnect
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(
                software: "4.5.6", hardware: "XXXX"))
        disconnect(drone: drone, handle: 1)
        assertThat(systemInfo, `is`(present()))
        assertThat(systemInfo!.firmwareVersion, `is`("4.5.6"))
        assertThat(systemInfo!.isFirmwareBlacklisted, `is`(false))
        assertThat(systemInfo!.hardwareVersion, `is`("XXXX"))
        assertThat(systemInfo!.serial, `is`("highlow"))
        assertThat(systemInfo!.boardId, `is`("board id"))
        assertThat(changeCnt, `is`(1))

        // forget the drone
        _ = drone.forget()
        assertThat(systemInfo, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))

        // restart engine
        resetArsdkEngine()
        assertThat(systemInfo, `is`(nilValue()))
    }

    func testSystemInfoValues() {
        connect(drone: drone, handle: 1)
        // check default values
        assertThat(systemInfo!.firmwareVersion, `is`(""))
        assertThat(systemInfo!.isFirmwareBlacklisted, `is`(false))
        assertThat(systemInfo!.hardwareVersion, `is`(""))
        assertThat(systemInfo!.serial, `is`(""))
        assertThat(systemInfo!.boardId, `is`(""))
        assertThat(changeCnt, `is`(1))

        // mock new blacklist received, should not change anything since we have no current firmware version
        let anafi4kModel = DeviceModel.drone(.anafi4k)
        var blacklistEntry = BlacklistStoreEntry(deviceModel: anafi4kModel, versions: [], embedded: false)
        blacklistEntry.add(versions: [FirmwareVersion.parse(versionStr: "1.2.3-beta1")!])
        blacklistStore.resetBlacklist([anafi4kModel: blacklistEntry])

        assertThat(systemInfo!.isFirmwareBlacklisted, `is`(false))
        assertThat(changeCnt, `is`(1))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(
                software: "1.2.3-beta1", hardware: "HW11"))
        assertThat(changeCnt, `is`(2))
        assertThat(systemInfo!.firmwareVersion, `is`("1.2.3-beta1"))
        assertThat(systemInfo!.isFirmwareBlacklisted, `is`(true))
        assertThat(systemInfo!.hardwareVersion, `is`("HW11"))
        assertThat(systemInfo!.serial, `is`(""))
        assertThat(systemInfo!.boardId, `is`(""))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonSettingsstateProductseriallowchangedEncoder(low: "low"))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonSettingsstateProductserialhighchangedEncoder(high: "high"))
        assertThat(changeCnt, `is`(3))
        assertThat(systemInfo!.firmwareVersion, `is`("1.2.3-beta1"))
        assertThat(systemInfo!.isFirmwareBlacklisted, `is`(true))
        assertThat(systemInfo!.hardwareVersion, `is`("HW11"))
        assertThat(systemInfo!.serial, `is`("highlow"))
        assertThat(systemInfo!.boardId, `is`(""))

        // check that receiving first the high serial and then the low is also working
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonSettingsstateProductserialhighchangedEncoder(high: "high2"))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonSettingsstateProductseriallowchangedEncoder(low: "low2"))
        assertThat(changeCnt, `is`(4))
        assertThat(systemInfo!.firmwareVersion, `is`("1.2.3-beta1"))
        assertThat(systemInfo!.isFirmwareBlacklisted, `is`(true))
        assertThat(systemInfo!.hardwareVersion, `is`("HW11"))
        assertThat(systemInfo!.serial, `is`("high2low2"))
        assertThat(systemInfo!.boardId, `is`(""))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonSettingsstateBoardidchangedEncoder(id: "board id"))
        assertThat(changeCnt, `is`(5))
        assertThat(systemInfo!.firmwareVersion, `is`("1.2.3-beta1"))
        assertThat(systemInfo!.isFirmwareBlacklisted, `is`(true))
        assertThat(systemInfo!.hardwareVersion, `is`("HW11"))
        assertThat(systemInfo!.serial, `is`("high2low2"))
        assertThat(systemInfo!.boardId, `is`("board id"))

        blacklistStore.resetBlacklist([:])

        assertThat(changeCnt, `is`(6))
        assertThat(systemInfo!.firmwareVersion, `is`("1.2.3-beta1"))
        assertThat(systemInfo!.isFirmwareBlacklisted, `is`(false))
        assertThat(systemInfo!.hardwareVersion, `is`("HW11"))
        assertThat(systemInfo!.serial, `is`("high2low2"))
        assertThat(systemInfo!.boardId, `is`("board id"))
    }

    func testSystemInfoFactoryReset() {
        connect(drone: drone, handle: 1)

        // check default values
        assertThat(changeCnt, `is`(1))
        assertThat(systemInfo!.isFactoryResetInProgress, `is`(false))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonFactoryReset())
        let inProgress = systemInfo!.factoryReset()
        assertThat(changeCnt, `is`(2))
        assertThat(inProgress, `is`(true))
        assertThat(systemInfo!.isFactoryResetInProgress, `is`(true))
    }

    func testSystemInfoResetSettings() {
        connect(drone: drone, handle: 1)

        // check default values
        assertThat(systemInfo!.isResetSettingsInProgress, `is`(false))
        assertThat(changeCnt, `is`(1))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonSettingsReset())
        let inProgress = systemInfo!.resetSettings()
        assertThat(changeCnt, `is`(2))
        assertThat(inProgress, `is`(true))
        assertThat(systemInfo!.isResetSettingsInProgress, `is`(true))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonSettingsstateResetchangedEncoder())
        assertThat(changeCnt, `is`(3))
        assertThat(systemInfo!.isResetSettingsInProgress, `is`(false))
    }
}
