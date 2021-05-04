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

class AnafiDevToolboxTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var devToolbox: DevToolbox?
    var devToolboxRef: Ref<DevToolbox>?
    var changeCnt = 0

    override func setGroundSdkConfig() {
        super.setGroundSdkConfig()
        GroundSdkConfig.sharedInstance.enableDevToolbox = true
    }

    override func setUp() {
        super.setUp()
        setUpDrone()
    }

    override func tearDown() {
        super.tearDown()
        GroundSdkConfig.sharedInstance.enableDevToolbox = false
    }

    func setUpDrone() {
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId,
                                backendType: .net, name: "Drone1", handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        devToolboxRef = drone.getPeripheral(Peripherals.devToolbox) { [unowned self] devToolbox in
            self.devToolbox = devToolbox
            self.changeCnt += 1
        }
        changeCnt = 0
    }

    override func resetArsdkEngine() {
        super.resetArsdkEngine()
        setUpDrone()
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(devToolbox, `is`(nilValue()))

        connect(drone: drone, handle: 1) {
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.debugGetAllSettings())
        }
        assertThat(changeCnt, `is`(1))
        assertThat(devToolbox, `is`(present()))

        disconnect(drone: drone, handle: 1)
        assertThat(changeCnt, `is`(2))
        assertThat(devToolbox, `is`(nilValue()))
    }

    func testDebugSettings() {
        connect(drone: drone, handle: 1) {
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.debugGetAllSettings())
        }
        assertThat(changeCnt, `is`(1))
        assertThat(devToolbox, `is`(present()))
        assertThat(devToolbox!.debugSettings, empty())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.debugSettingsInfoEncoder(
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first),
                id: 1, label: "label1", type: .bool, mode: .readWrite,
                rangeMin: "", rangeMax: "", rangeStep: "", value: "1"))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.debugSettingsInfoEncoder(
                listFlagsBitField: 0, id: 2, label: "label2", type: .bool, mode: .readOnly,
                rangeMin: "", rangeMax: "", rangeStep: "", value: "0"))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.debugSettingsInfoEncoder(
                listFlagsBitField: 0, id: 3, label: "label3", type: .text, mode: .readWrite,
                rangeMin: "", rangeMax: "", rangeStep: "", value: "value3"))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.debugSettingsInfoEncoder(
                listFlagsBitField: 0, id: 4, label: "label4", type: .text, mode: .readOnly,
                rangeMin: "", rangeMax: "", rangeStep: "", value: "value4"))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.debugSettingsInfoEncoder(
                listFlagsBitField: 0, id: 5, label: "label5", type: .decimal, mode: .readWrite,
                rangeMin: "", rangeMax: "", rangeStep: "", value: "0.5"))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.debugSettingsInfoEncoder(
                listFlagsBitField: 0, id: 6, label: "label6", type: .decimal, mode: .readOnly,
                rangeMin: "5", rangeMax: "", rangeStep: "6", value: "-0.5"))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.debugSettingsInfoEncoder(
                listFlagsBitField: 0, id: 7, label: "label7", type: .decimal, mode: .readOnly,
                rangeMin: "5", rangeMax: "6", rangeStep: "", value: "100"))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.debugSettingsInfoEncoder(
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last),
                        id: 8, label: "label8", type: .decimal, mode: .readOnly,
                        rangeMin: "5", rangeMax: "6.5", rangeStep: "0.5", value: "-100"))

        assertThat(changeCnt, `is`(2))
        assertThat(devToolbox!.debugSettings, containsInAnyOrder(
            allOf(has(name: "label1"), `is`(readOnly: false), `is`(updating: false), has(value: true)),
            allOf(has(name: "label2"), `is`(readOnly: true), `is`(updating: false), has(value: false)),
            allOf(has(name: "label3"), `is`(readOnly: false), `is`(updating: false), has(value: "value3")),
            allOf(has(name: "label4"), `is`(readOnly: true), `is`(updating: false), has(value: "value4")),
            allOf(has(name: "label5"), `is`(readOnly: false), `is`(updating: false), has(value: 0.5),
                  has(range: nil), has(step: nil)),
            allOf(has(name: "label6"), `is`(readOnly: true), `is`(updating: false), has(value: -0.5),
                  has(range: nil), has(step: 6)),
            allOf(has(name: "label7"), `is`(readOnly: true), `is`(updating: false), has(value: 100),
                  has(range: 5...6), has(step: nil)),
            allOf(has(name: "label8"), `is`(readOnly: true), `is`(updating: false), has(value: -100),
                  has(range: 5...6.5), has(step: 0.5))
        ))

        // empty debug settings list
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.debugSettingsInfoEncoder(
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.empty),
                id: 0, label: "", type: .bool, mode: .readWrite,
                rangeMin: "", rangeMax: "", rangeStep: "", value: "1"))

        assertThat(changeCnt, `is`(3))
        assertThat(devToolbox!.debugSettings, empty())
    }

    func testWritableBooleanDebugSetting() {
        connect(drone: drone, handle: 1) {
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.debugGetAllSettings())
        }
        assertThat(changeCnt, `is`(1))
        assertThat(devToolbox, `is`(present()))
        assertThat(devToolbox!.debugSettings, empty())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.debugSettingsInfoEncoder(
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last),
                id: 1, label: "label1", type: .bool, mode: .readWrite,
                rangeMin: "", rangeMax: "", rangeStep: "", value: "1"))

        assertThat(changeCnt, `is`(2))
        assertThat(devToolbox!.debugSettings, containsInAnyOrder(
            allOf(has(name: "label1"), `is`(readOnly: false), `is`(updating: false), has(value: true))))

        // get debug setting
        let debugSetting = devToolbox?.debugSettings[0] as? BoolDebugSettingCore
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "label1"), `is`(readOnly: false), `is`(updating: false), has(value: true))))

        // change its value
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.debugSetSetting(id: 1, value: "0"))
        debugSetting?.value = false
        assertThat(changeCnt, `is`(3))
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "label1"), `is`(readOnly: false), `is`(updating: true), has(value: false))))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.debugSettingsListEncoder(id: 1, value: "0"))
        assertThat(changeCnt, `is`(4))
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "label1"), `is`(readOnly: false), `is`(updating: false), has(value: false))))

        // change its value
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.debugSetSetting(id: 1, value: "1"))
        debugSetting?.value = true
        assertThat(changeCnt, `is`(5))
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "label1"), `is`(readOnly: false), `is`(updating: true), has(value: true))))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.debugSettingsListEncoder(id: 1, value: "1"))
        assertThat(changeCnt, `is`(6))
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "label1"), `is`(readOnly: false), `is`(updating: false), has(value: true))))
    }

    func testReadOnlyBooleanDebugSetting() {
        connect(drone: drone, handle: 1) {
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.debugGetAllSettings())
        }
        assertThat(changeCnt, `is`(1))
        assertThat(devToolbox, `is`(present()))
        assertThat(devToolbox!.debugSettings, empty())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.debugSettingsInfoEncoder(
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last),
                id: 1, label: "label1", type: .bool, mode: .readOnly,
                rangeMin: "", rangeMax: "", rangeStep: "", value: "1"))

        assertThat(changeCnt, `is`(2))
        assertThat(devToolbox!.debugSettings, containsInAnyOrder(
            allOf(has(name: "label1"), `is`(readOnly: true), `is`(updating: false), has(value: true))))

        // get debug setting
        let debugSetting = devToolbox?.debugSettings[0] as? BoolDebugSettingCore
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "label1"), `is`(readOnly: true), `is`(updating: false), has(value: true))))

        // try to change its value
        debugSetting?.value = false
        assertThat(changeCnt, `is`(2))
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "label1"), `is`(readOnly: true), `is`(updating: false), has(value: true))))
    }

    func testWritableTextDebugSetting() {
        connect(drone: drone, handle: 1) {
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.debugGetAllSettings())
        }
        assertThat(changeCnt, `is`(1))
        assertThat(devToolbox, `is`(present()))
        assertThat(devToolbox!.debugSettings, empty())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.debugSettingsInfoEncoder(
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last),
                id: 1, label: "label1", type: .text, mode: .readWrite,
                rangeMin: "", rangeMax: "", rangeStep: "", value: "value1"))

        assertThat(changeCnt, `is`(2))
        assertThat(devToolbox!.debugSettings, containsInAnyOrder(
            allOf(has(name: "label1"), `is`(readOnly: false), `is`(updating: false), has(value: "value1"))))

        // get debug setting
        let debugSetting = devToolbox?.debugSettings[0] as? TextDebugSettingCore
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "label1"), `is`(readOnly: false), `is`(updating: false), has(value: "value1"))))

        // change its value
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.debugSetSetting(id: 1, value: "newValue1"))
        debugSetting?.value = "newValue1"
        assertThat(changeCnt, `is`(3))
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "label1"), `is`(readOnly: false), `is`(updating: true), has(value: "newValue1"))))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.debugSettingsListEncoder(id: 1, value: "newValue1"))
        assertThat(changeCnt, `is`(4))
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "label1"), `is`(readOnly: false), `is`(updating: false), has(value: "newValue1"))))
    }

    func testReadOnlyTextDebugSetting() {
        connect(drone: drone, handle: 1) {
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.debugGetAllSettings())
        }
        assertThat(changeCnt, `is`(1))
        assertThat(devToolbox, `is`(present()))
        assertThat(devToolbox!.debugSettings, empty())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.debugSettingsInfoEncoder(
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last),
                id: 1, label: "label1", type: .text, mode: .readOnly,
                rangeMin: "", rangeMax: "", rangeStep: "", value: "value1"))

        assertThat(changeCnt, `is`(2))
        assertThat(devToolbox, `is`(present()))
        assertThat(devToolbox!.debugSettings, containsInAnyOrder(
            allOf(has(name: "label1"), `is`(readOnly: true), `is`(updating: false), has(value: "value1"))))

        // get debug setting
        let debugSetting = devToolbox?.debugSettings[0] as? TextDebugSettingCore
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "label1"), `is`(readOnly: true), `is`(updating: false), has(value: "value1"))))

        // try to change its value
        debugSetting?.value = "newValue1"
        assertThat(changeCnt, `is`(2))
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "label1"), `is`(readOnly: true), `is`(updating: false), has(value: "value1"))))
    }

    func testWritableNumericDebugSetting() {
        connect(drone: drone, handle: 1) {
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.debugGetAllSettings())
        }
        assertThat(changeCnt, `is`(1))
        assertThat(devToolbox, `is`(present()))
        assertThat(devToolbox!.debugSettings, empty())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.debugSettingsInfoEncoder(
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last),
                id: 1, label: "label1", type: .decimal, mode: .readWrite,
                rangeMin: "", rangeMax: "", rangeStep: "", value: "1.1"))

        assertThat(changeCnt, `is`(2))
        assertThat(devToolbox!.debugSettings, containsInAnyOrder(
            allOf(has(name: "label1"), `is`(readOnly: false), `is`(updating: false), has(value: 1.1))))

        // get debug setting
        let debugSetting = devToolbox?.debugSettings[0] as? NumericDebugSettingCore
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "label1"), `is`(readOnly: false), `is`(updating: false), has(value: 1.1))))

        // change its value
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.debugSetSetting(id: 1, value: String(format: "%f", 2.2)))
        debugSetting?.value = 2.2
        assertThat(changeCnt, `is`(3))
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "label1"), `is`(readOnly: false), `is`(updating: true), has(value: 2.2))))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.debugSettingsListEncoder(id: 1, value: "2.2"))
        assertThat(changeCnt, `is`(4))
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "label1"), `is`(readOnly: false), `is`(updating: false), has(value: 2.2))))
    }

    func testReadOnlyNumericDebugSetting() {
        connect(drone: drone, handle: 1) {
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.debugGetAllSettings())
        }
        assertThat(changeCnt, `is`(1))
        assertThat(devToolbox, `is`(present()))
        assertThat(devToolbox!.debugSettings, empty())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.debugSettingsInfoEncoder(
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last),
                id: 1, label: "label1", type: .decimal, mode: .readOnly,
                rangeMin: "", rangeMax: "", rangeStep: "", value: "1.1"))

        assertThat(changeCnt, `is`(2))
        assertThat(devToolbox!.debugSettings, containsInAnyOrder(
            allOf(has(name: "label1"), `is`(readOnly: true), `is`(updating: false), has(value: 1.1))))

        // get debug setting
        let debugSetting = devToolbox?.debugSettings[0] as? NumericDebugSettingCore
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "label1"), `is`(readOnly: true), `is`(updating: false), has(value: 1.1))))

        // try to change its value
        debugSetting?.value = 2.2
        assertThat(changeCnt, `is`(2))
        assertThat(debugSetting, presentAnd(
            allOf(has(name: "label1"), `is`(readOnly: true), `is`(updating: false), has(value: 1.1))))
    }

    func testDebugTag() {
        connect(drone: drone, handle: 1) {
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.debugGetAllSettings())
        }
        assertThat(changeCnt, `is`(1))
        assertThat(devToolbox, `is`(present()))
        assertThat(devToolbox!.latestDebugTagId, nilValue())

        // send a debug tag
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.debugTag(value: "debug tag 1"))
        devToolbox!.sendDebugTag(tag: "debug tag 1")

        assertThat(changeCnt, `is`(1))
        assertThat(devToolbox!.latestDebugTagId, nilValue())

        // receive debug tag id
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.debugTagNotifyEncoder(id: "debugTagId1"))

        assertThat(changeCnt, `is`(2))
        assertThat(devToolbox!.latestDebugTagId, `is`("debugTagId1"))

        // receive same debug tag id
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.debugTagNotifyEncoder(id: "debugTagId1"))

        assertThat(changeCnt, `is`(2))
        assertThat(devToolbox!.latestDebugTagId, `is`("debugTagId1"))
    }
}
