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

class ThermalControllerTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var thermalControl: ThermalControl?
    var thermalControlRef: Ref<ThermalControl>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        setUpDrone()
    }

    func setUpDrone() {
        mockArsdkCore.addDevice("123", type: Drone.Model.anafiThermal.internalId,
                                backendType: .net, name: "Drone1", handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        thermalControlRef =
            drone.getPeripheral(Peripherals.thermalControl) { [unowned self] thermalControl in
                self.thermalControl = thermalControl
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
        assertThat(thermalControl, `is`(nilValue()))

        connect(drone: drone, handle: 1)

        // should be unavailable since by default it isn't supported
        assertThat(thermalControl, `is`(nilValue()))
        assertThat(changeCnt, `is`(0))

        disconnect(drone: drone, handle: 1)
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalCapabilitiesEncoder(
                modesBitField: Bitfield<ArsdkFeatureThermalMode>.of(.standard, .disabled)))
        }

        assertThat(thermalControl, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(thermalControl, `is`(present()))
        assertThat(changeCnt, `is`(1)) // is not changed since mode is .disabled

        _ = drone.forget()
        assertThat(thermalControl, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))

        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalCapabilitiesEncoder(
                modesBitField: Bitfield<ArsdkFeatureThermalMode>.of(.standard, .disabled)))
        }

        assertThat(thermalControl, `is`(present()))
        assertThat(changeCnt, `is`(3))

        self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalModeEncoder(mode: .standard))
        assertThat(changeCnt, `is`(4))

        disconnect(drone: drone, handle: 1)
        assertThat(thermalControl, `is`(present()))
        assertThat(changeCnt, `is`(5))

        _ = drone.forget()
        assertThat(thermalControl, `is`(nilValue()))
        assertThat(changeCnt, `is`(6)) // change from .standard to .disabled
    }

    func testMode() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalCapabilitiesEncoder(
                modesBitField: Bitfield<ArsdkFeatureThermalMode>.of(.standard, .disabled, .blended)))
        }
        assertThat(thermalControl, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // initial values
        assertThat(thermalControl!.setting, supports(modes: [.standard, .disabled, .blended]))
        assertThat(thermalControl!.setting, `is`(mode: .disabled, updating: false))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.thermalSetMode(mode: .standard))
        thermalControl!.setting.mode = .standard
        assertThat(changeCnt, `is`(2))
        assertThat(thermalControl!.setting, `is`(mode: .standard, updating: true))

        self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalModeEncoder(mode: .standard))
        assertThat(changeCnt, `is`(3))
        assertThat(thermalControl!.setting, `is`(mode: .standard, updating: false))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.thermalSetMode(mode: .disabled))
        thermalControl!.setting.mode = .disabled
        assertThat(changeCnt, `is`(4))
        assertThat(thermalControl!.setting, `is`(mode: .disabled, updating: true))

        self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalModeEncoder(mode: .disabled))
        assertThat(changeCnt, `is`(5))
        assertThat(thermalControl!.setting, `is`(mode: .disabled, updating: false))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.thermalSetMode(mode: .blended))
        thermalControl!.setting.mode = .blended
        assertThat(changeCnt, `is`(6))
        assertThat(thermalControl!.setting, `is`(mode: .blended, updating: true))

        self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalModeEncoder(mode: .blended))
        assertThat(changeCnt, `is`(7))
        assertThat(thermalControl!.setting, `is`(mode: .blended, updating: false))

        disconnect(drone: drone, handle: 1)

        // setting should be updated to user value and other values are reset
        assertThat(thermalControl!.setting, `is`(mode: .disabled, updating: false))
        assertThat(changeCnt, `is`(8))

        resetArsdkEngine()
        assertThat(thermalControl!.setting, `is`(mode: .blended, updating: false))

        // apply mode on connection
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalCapabilitiesEncoder(
                modesBitField: Bitfield<ArsdkFeatureThermalMode>.of(.standard, .disabled)))
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalModeEncoder(mode: .disabled))
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.thermalSetMode(mode: .blended))
        }

        self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalModeEncoder(mode: .standard))
        assertThat(thermalControl!.setting, `is`(mode: .standard, updating: false))
    }

    func testEmissivity() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalCapabilitiesEncoder(
                modesBitField: Bitfield<ArsdkFeatureThermalMode>.of(.standard, .disabled)))
        }
        assertThat(thermalControl, `is`(present()))
        assertThat(changeCnt, `is`(1))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.thermalSetEmissivity(emissivity: 0.5))
        thermalControl!.sendEmissivity(0.5)
        assertThat(changeCnt, `is`(1))

        // check that the same value is not sent twice to drone
        thermalControl!.sendEmissivity(0.5)
        assertThat(changeCnt, `is`(1))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.thermalSetEmissivity(emissivity: 0.6))
        thermalControl!.sendEmissivity(0.6)
        assertThat(changeCnt, `is`(1))

        // receive value from drone and check that this value is not sent to drone
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalEmissivityEncoder(emissivity: 0.7))
        thermalControl!.sendEmissivity(0.7)
        assertThat(changeCnt, `is`(1))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.thermalSetEmissivity(emissivity: 0.6))
        thermalControl!.sendEmissivity(0.6)
        assertThat(changeCnt, `is`(1))
    }

    func testCalibration() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalCapabilitiesEncoder(
                modesBitField: Bitfield<ArsdkFeatureThermalMode>.of(.standard, .disabled)))
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalShutterModeEncoder(
                currentTrigger: .auto))
        }
        assertThat(thermalControl, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // initial values
        assertThat(thermalControl!.calibration, presentAnd(`is`(mode: .automatic, updating: false)))
        assertThat(thermalControl!.calibration, presentAnd(supports(modes: [.automatic, .manual])))

        // change to manual mode
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.thermalSetShutterMode(trigger: .manual))
        thermalControl!.calibration!.mode = .manual
        assertThat(changeCnt, `is`(2))
        assertThat(thermalControl!.calibration, presentAnd(`is`(mode: .manual, updating: true)))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalShutterModeEncoder(currentTrigger: .manual))
        assertThat(changeCnt, `is`(3))
        assertThat(thermalControl!.calibration, presentAnd(`is`(mode: .manual, updating: false)))

        // change to automatic mode
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.thermalSetShutterMode(trigger: .auto))
        thermalControl!.calibration!.mode = .automatic
        assertThat(changeCnt, `is`(4))
        assertThat(thermalControl!.calibration, presentAnd(`is`(mode: .automatic, updating: true)))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalShutterModeEncoder(currentTrigger: .auto))
        assertThat(changeCnt, `is`(5))
        assertThat(thermalControl!.calibration, presentAnd(`is`(mode: .automatic, updating: false)))

        // change to manual mode
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.thermalSetShutterMode(trigger: .manual))
        thermalControl!.calibration!.mode = .manual
        assertThat(changeCnt, `is`(6))
        assertThat(thermalControl!.calibration, presentAnd(`is`(mode: .manual, updating: true)))

        disconnect(drone: drone, handle: 1)

        // should be updated to user value
        assertThat(thermalControl!.calibration, presentAnd(`is`(mode: .manual, updating: false)))
        assertThat(changeCnt, `is`(7))

        resetArsdkEngine()

        assertThat(thermalControl!.calibration, presentAnd(`is`(mode: .manual, updating: false)))

        // apply mode on connection
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalCapabilitiesEncoder(
                modesBitField: Bitfield<ArsdkFeatureThermalMode>.of(.standard, .disabled)))
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalShutterModeEncoder(
                currentTrigger: .auto))
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.thermalSetShutterMode(trigger: .manual))
        }
        assertThat(changeCnt, `is`(1))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalShutterModeEncoder(currentTrigger: .auto))
        assertThat(changeCnt, `is`(2))
        assertThat(thermalControl!.calibration, presentAnd(`is`(mode: .automatic, updating: false)))
    }

    func testBackgroundTemperature () {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalCapabilitiesEncoder(
                modesBitField: Bitfield<ArsdkFeatureThermalMode>.of(.standard, .disabled)))
        }
        assertThat(thermalControl, `is`(present()))
        assertThat(changeCnt, `is`(1))

        expectCommand(handle: 1, expectedCmd:
            ExpectedCmd.thermalSetBackgroundTemperature(backgroundTemperature: 100.0))
        thermalControl!.sendBackgroundTemperature(100.0)
        assertThat(changeCnt, `is`(1))

        // check that the same value is not sent twice to drone
        thermalControl!.sendBackgroundTemperature(100.0)
        assertThat(changeCnt, `is`(1))

        expectCommand(handle: 1, expectedCmd:
            ExpectedCmd.thermalSetBackgroundTemperature(backgroundTemperature: 200.0))
        thermalControl!.sendBackgroundTemperature(200.0)
        assertThat(changeCnt, `is`(1))

        // receive value from drone and check that this value is not sent to drone
        mockArsdkCore.onCommandReceived(1, encoder:
            CmdEncoder.thermalBackgroundTemperatureEncoder(backgroundTemperature: 150.0))
        thermalControl!.sendBackgroundTemperature(150.0)
        assertThat(changeCnt, `is`(1))

        expectCommand(handle: 1, expectedCmd:
            ExpectedCmd.thermalSetBackgroundTemperature(backgroundTemperature: 200.0))
        thermalControl!.sendBackgroundTemperature(200.0)
        assertThat(changeCnt, `is`(1))
    }

    func testRendering() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalCapabilitiesEncoder(
                modesBitField: Bitfield<ArsdkFeatureThermalMode>.of(.standard, .disabled)))
        }
        assertThat(thermalControl, `is`(present()))
        assertThat(changeCnt, `is`(1))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.thermalSetRendering(mode: .blended, blendingRate: 0.5))
        thermalControl!.sendRendering(rendering: ThermalRendering(mode: .blended, blendingRate: 0.5))
        assertThat(changeCnt, `is`(1))
    }

    func testPalette() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalCapabilitiesEncoder(
                modesBitField: Bitfield<ArsdkFeatureThermalMode>.of(.standard, .disabled)))
        }
        assertThat(thermalControl, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // absolute palette
        var colors = [ThermalColor(0, 0, 0, 0), ThermalColor(0.1, 0.2, 0.3, 0.4),
                      ThermalColor(-1, 10, 0.2, 10), ThermalColor(0, 1, 1, 1)]
        var palette: ThermalPalette
        palette = ThermalAbsolutePalette(colors: colors, lowestTemp: 0, highestTemp: 100,
                                         outsideColorization: .limited)

        // expect colors
        expectCommand(handle: 1, expectedCmd:
            ExpectedCmd.thermalSetPalettePart(red: 0, green: 0, blue: 0, index: 0,
                                              listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))
        expectCommand(handle: 1, expectedCmd:
            ExpectedCmd.thermalSetPalettePart(red: 0.1, green: 0.2, blue: 0.3, index: 0.4, listFlagsBitField: 0))
        expectCommand(handle: 1, expectedCmd:
            ExpectedCmd.thermalSetPalettePart(red: 0, green: 1, blue: 0.2, index: 1, listFlagsBitField: 0))
        expectCommand(handle: 1, expectedCmd:
            ExpectedCmd.thermalSetPalettePart(red: 0, green: 1, blue: 1, index: 1,
                                              listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))

        // expect palette settings
        expectCommand(handle: 1, expectedCmd:
            ExpectedCmd.thermalSetPaletteSettings(mode: .absolute, lowestTemp: 0, highestTemp: 100,
                                                  outsideColorization: .limited, relativeRange: .unlocked,
                                                  spotType: .hot, spotThreshold: 0))

        thermalControl!.sendPalette(palette)
        assertThat(changeCnt, `is`(1))

        // check that the same palette is not sent twice to drone
        thermalControl!.sendPalette(palette)
        assertThat(changeCnt, `is`(1))

        // relative palette
        colors = [ThermalColor(1, 0, 0, 0), ThermalColor(0.5, 0.6, 0.7, 0.8), ThermalColor(1.1, 1.2, 1.3, 2)]
        palette = ThermalRelativePalette(colors: colors, locked: true,
                                         lowestTemp: 10, highestTemp: 90)

        // expect colors
        expectCommand(handle: 1, expectedCmd:
            ExpectedCmd.thermalSetPalettePart(red: 1, green: 0, blue: 0, index: 0,
                                              listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))
        expectCommand(handle: 1, expectedCmd:
            ExpectedCmd.thermalSetPalettePart(red: 0.5, green: 0.6, blue: 0.7, index: 0.8, listFlagsBitField: 0))
        expectCommand(handle: 1, expectedCmd:
            ExpectedCmd.thermalSetPalettePart(red: 1, green: 1, blue: 1, index: 1,
                                              listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))

        // expect palette settings
        expectCommand(handle: 1, expectedCmd:
            ExpectedCmd.thermalSetPaletteSettings(mode: .relative, lowestTemp: 10, highestTemp: 90,
                                                  outsideColorization: .extended, relativeRange: .locked,
                                                  spotType: .hot, spotThreshold: 0))

        thermalControl!.sendPalette(palette)
        assertThat(changeCnt, `is`(1))

        // check that the same palette is not sent twice to drone
        thermalControl!.sendPalette(palette)
        assertThat(changeCnt, `is`(1))

        // spot palette
        colors = [ThermalColor(-0.1, 0, 0.1, 0.2), ThermalColor(1.1, -1, 0.12, 2)]
        palette = ThermalSpotPalette(colors: colors, type: .cold, threshold: 123)

        // expect colors
        expectCommand(handle: 1, expectedCmd:
            ExpectedCmd.thermalSetPalettePart(red: 0, green: 0, blue: 0.1, index: 0.2,
                                              listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))
        expectCommand(handle: 1, expectedCmd:
            ExpectedCmd.thermalSetPalettePart(red: 1, green: 0, blue: 0.12, index: 1,
                                              listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))

        // expect palette settings
        expectCommand(handle: 1, expectedCmd:
            ExpectedCmd.thermalSetPaletteSettings(mode: .spot, lowestTemp: 0, highestTemp: 0,
                                                  outsideColorization: .extended, relativeRange: .unlocked,
                                                  spotType: .cold, spotThreshold: 123))

        thermalControl!.sendPalette(palette)
        assertThat(changeCnt, `is`(1))

        // check that the same palette is not sent twice to drone
        thermalControl!.sendPalette(palette)
        assertThat(changeCnt, `is`(1))

        // palette with empty color list
        colors = []
        palette = ThermalSpotPalette(colors: colors, type: .cold, threshold: 123)

        // expect empty color list command
        expectCommand(handle: 1, expectedCmd:
            ExpectedCmd.thermalSetPalettePart(red: 0, green: 0, blue: 0, index: 0,
                                              listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.empty)))
        thermalControl!.sendPalette(palette)
        assertThat(changeCnt, `is`(1))

        // change palette colors without changing settings, check that only colors are sent
        palette.colors = [ThermalColor(0.4, 0.3, 0.2, 0.1)]
        expectCommand(handle: 1, expectedCmd:
            ExpectedCmd.thermalSetPalettePart(red: 0.4, green: 0.3, blue: 0.2, index: 0.1, listFlagsBitField:
                Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last)))
        thermalControl!.sendPalette(palette)
        assertThat(changeCnt, `is`(1))

        // change palette settings without changing colors, check that only settings are sent
        (palette as! ThermalSpotPalette).threshold = 456
        expectCommand(handle: 1, expectedCmd:
            ExpectedCmd.thermalSetPaletteSettings(mode: .spot, lowestTemp: 0, highestTemp: 0,
                                                  outsideColorization: .extended, relativeRange: .unlocked,
                                                  spotType: .cold, spotThreshold: 456))
        thermalControl!.sendPalette(palette)
        assertThat(changeCnt, `is`(1))

        // receive colors from drone and check that these colors are not sent to drone
        mockArsdkCore.onCommandReceived(1, encoder:
            CmdEncoder.thermalPalettePartEncoder(red: 0.1, green: 0.2, blue: 0.3, index: 0.4, listFlagsBitField:
                Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last)))
        palette.colors = [ThermalColor(0.1, 0.2, 0.3, 0.4)]
        thermalControl!.sendPalette(palette)
        assertThat(changeCnt, `is`(1))

        // receive settings from drone and check that these settings are not sent to drone
        mockArsdkCore.onCommandReceived(1, encoder:
            CmdEncoder.thermalPaletteSettingsEncoder(mode: .spot, lowestTemp: 0, highestTemp: 0,
                                                     outsideColorization: .extended, relativeRange: .unlocked,
                                                     spotType: .cold, spotThreshold: 789))
        (palette as! ThermalSpotPalette).threshold = 789
        thermalControl!.sendPalette(palette)
        assertThat(changeCnt, `is`(1))
    }

    func testSensitivityRange() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalCapabilitiesEncoder(
                modesBitField: Bitfield<ArsdkFeatureThermalMode>.of(.standard, .disabled)))
        }

        assertThat(thermalControl, `is`(present()))
        assertThat(changeCnt, `is`(1))

        assertThat(thermalControl!.sensitivitySetting, supports(ranges: [.high, .low]))
        assertThat(thermalControl!.sensitivitySetting.sensitivityRange, `is`(.high))

        expectCommand(handle: 1, expectedCmd:
            ExpectedCmd.thermalSetSensitivity(range: .low))
        thermalControl!.sensitivitySetting.sensitivityRange = .low
        assertThat(thermalControl!.sensitivitySetting, `is`(sensitivityRange: .low, updating: true))
        assertThat(changeCnt, `is`(2))

        self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalSensitivityEncoder(currentRange: .low))
        assertThat(thermalControl!.sensitivitySetting, `is`(sensitivityRange: .low, updating: false))
        assertThat(changeCnt, `is`(3))

        thermalControl!.sensitivitySetting.sensitivityRange = .low
        assertThat(thermalControl!.sensitivitySetting, `is`(sensitivityRange: .low, updating: false))
        assertThat(changeCnt, `is`(3))

        expectCommand(handle: 1, expectedCmd:
            ExpectedCmd.thermalSetSensitivity(range: .high))
        thermalControl!.sensitivitySetting.sensitivityRange = .high
        assertThat(thermalControl!.sensitivitySetting, `is`(sensitivityRange: .high, updating: true))
        assertThat(changeCnt, `is`(4))

        self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalSensitivityEncoder(currentRange: .high))
        assertThat(thermalControl!.sensitivitySetting, `is`(sensitivityRange: .high, updating: false))
        assertThat(changeCnt, `is`(5))

        thermalControl!.sensitivitySetting.sensitivityRange = .high
        assertThat(thermalControl!.sensitivitySetting, `is`(sensitivityRange: .high, updating: false))
        assertThat(changeCnt, `is`(5))

        disconnect(drone: drone, handle: 1)
        assertThat(changeCnt, `is`(5))

        thermalControl!.sensitivitySetting.sensitivityRange = .low
        assertThat(thermalControl!.sensitivitySetting, `is`(sensitivityRange: .low, updating: false))
        assertThat(changeCnt, `is`(6))

        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalSensitivityEncoder(currentRange: .high))
            self.expectCommand(handle: 1, expectedCmd:
                ExpectedCmd.thermalSetSensitivity(range: .low))
        }
        self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.thermalSensitivityEncoder(currentRange: .low))
        assertThat(thermalControl!.sensitivitySetting, `is`(sensitivityRange: .low, updating: false))
        assertThat(changeCnt, `is`(6))
    }
}
