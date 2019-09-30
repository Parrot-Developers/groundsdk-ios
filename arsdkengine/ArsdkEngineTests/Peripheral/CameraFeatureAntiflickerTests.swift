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

class CameraFeatureAntiflickerTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var antiflicker: Antiflicker?
    var antiflickerRef: Ref<Antiflicker>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        setUpDrone()
    }

    func setUpDrone() {
        mockArsdkCore.addDevice(
            "123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1", handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        antiflickerRef =
            drone.getPeripheral(Peripherals.antiflicker) { [unowned self] antiflicker in
                self.antiflicker = antiflicker
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
        assertThat(antiflicker, `is`(nilValue()))

        connect(drone: drone, handle: 1)
        assertThat(antiflicker, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // disconnect drone
        disconnect(drone: drone, handle: 1)
        assertThat(antiflicker, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // forget the drone
        _ = drone.forget()
        assertThat(antiflicker, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testModeAndValue() {
        connect(drone: drone, handle: 1)
        assertThat(antiflicker, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // initial values
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraAntiflickerCapabilitiesEncoder(
            supportedModesBitField: Bitfield<ArsdkFeatureCameraAntiflickerMode>.of(.off, .mode50hz, .mode60hz)))
        assertThat(antiflicker!.setting, supports(modes: [.off, .mode50Hz, .mode60Hz, .auto]))
        assertThat(antiflicker!.setting, `is`(mode: .off, updating: false))
        assertThat(antiflicker!.value, `is`(.unknown))

        // set mode to 50Hz
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetAntiflickerMode(mode: .mode50hz))
        antiflicker!.setting.mode = .mode50Hz
        assertThat(changeCnt, `is`(2))
        assertThat(antiflicker!.setting, `is`(mode: .mode50Hz, updating: true))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraAntiflickerModeEncoder(
            mode: .mode50hz, value: .mode50hz))
        assertThat(changeCnt, `is`(3))
        assertThat(antiflicker!.setting, `is`(mode: .mode50Hz, updating: false))
        assertThat(antiflicker!.value, `is`(.value50Hz))

        // set mode to 60Hz
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetAntiflickerMode(mode: .mode60hz))
        antiflicker!.setting.mode = .mode60Hz
        assertThat(changeCnt, `is`(4))
        assertThat(antiflicker!.setting, `is`(mode: .mode60Hz, updating: true))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraAntiflickerModeEncoder(
            mode: .mode60hz, value: .mode60hz))
        assertThat(changeCnt, `is`(5))
        assertThat(antiflicker!.setting, `is`(mode: .mode60Hz, updating: false))
        assertThat(antiflicker!.value, `is`(.value60Hz))

        // set mode to off
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetAntiflickerMode(mode: .off))
        antiflicker!.setting.mode = .off
        assertThat(changeCnt, `is`(6))
        assertThat(antiflicker!.setting, `is`(mode: .off, updating: true))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraAntiflickerModeEncoder(
            mode: .off, value: .off))
        assertThat(changeCnt, `is`(7))
        assertThat(antiflicker!.setting, `is`(mode: .off, updating: false))
        assertThat(antiflicker!.value, `is`(.off))

        // user modifies settings
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetAntiflickerMode(mode: .mode50hz))
        antiflicker!.setting.mode = .mode50Hz
        assertThat(antiflicker!.setting, `is`(mode: .mode50Hz, updating: true))
        assertThat(antiflicker!.value, `is`(.off))
        assertThat(changeCnt, `is`(8))

        // disconnect
        disconnect(drone: drone, handle: 1)

        // setting should be updated to user value and other values are reset
        assertThat(antiflicker!.setting, `is`(mode: .mode50Hz, updating: false))
        assertThat(antiflicker!.value, `is`(.unknown))
        assertThat(changeCnt, `is`(9))
    }

    func testAutoLocationMode() {
        connect(drone: drone, handle: 1)
        // initial values
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraAntiflickerCapabilitiesEncoder(
            supportedModesBitField: Bitfield<ArsdkFeatureCameraAntiflickerMode>.of(.off, .mode50hz, .mode60hz)))
        assertThat(antiflicker!.setting, supports(modes: [.off, .mode50Hz, .mode60Hz, .auto]))
        assertThat(antiflicker!.setting, `is`(mode: .off, updating: false))
        assertThat(antiflicker!.value, `is`(.unknown))
        assertThat(changeCnt, `is`(1))

        // set mode to auto
        antiflicker!.setting.mode = .auto
        assertThat(changeCnt, `is`(2))
        assertThat(antiflicker!.setting, `is`(mode: .auto, updating: true))
        assertThat(antiflicker!.value, `is`(.unknown))

        // change to France (50hz)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetAntiflickerMode(mode: .mode50hz))
        reverseGeocoder.placemark = MockReverseGeocoder.fr
        assertNoExpectation()
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraAntiflickerModeEncoder(
            mode: .mode50hz, value: .mode50hz))
        assertThat(changeCnt, `is`(3))
        assertThat(antiflicker!.setting, `is`(mode: .auto, updating: false))
        assertThat(antiflicker!.value, `is`(.value50Hz))

        // change to US (60hz)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetAntiflickerMode(mode: .mode60hz))
        reverseGeocoder.placemark = MockReverseGeocoder.us
        assertNoExpectation()
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraAntiflickerModeEncoder(
            mode: .mode60hz, value: .mode60hz))
        assertThat(changeCnt, `is`(4))
        assertThat(antiflicker!.setting, `is`(mode: .auto, updating: false))
        assertThat(antiflicker!.value, `is`(.value60Hz))

        // Disconnect
        disconnect(drone: drone, handle: 1)

        // value should be reset to unknown
        assertThat(antiflicker!.setting, `is`(mode: .auto, updating: false))
        assertThat(antiflicker!.value, `is`(.unknown))
        assertThat(changeCnt, `is`(5))

        // change mode
        antiflicker?.setting.mode = .mode60Hz
        assertThat(antiflicker!.setting, `is`(mode: .mode60Hz, updating: false))
        assertThat(antiflicker!.value, `is`(.unknown))
        assertThat(changeCnt, `is`(6))

        // change mode to auto
        antiflicker?.setting.mode = .auto
        assertThat(antiflicker!.setting, `is`(mode: .auto, updating: false))
        assertThat(antiflicker!.value, `is`(.unknown))
        assertThat(changeCnt, `is`(7))

        // change mode
        antiflicker?.setting.mode = .mode50Hz
        assertThat(antiflicker!.setting, `is`(mode: .mode50Hz, updating: false))
        assertThat(antiflicker!.value, `is`(.unknown))
        assertThat(changeCnt, `is`(8))

        // change mode to auto
        antiflicker?.setting.mode = .auto
        assertThat(antiflicker!.setting, `is`(mode: .auto, updating: false))
        assertThat(antiflicker!.value, `is`(.unknown))
        assertThat(changeCnt, `is`(9))

        resetArsdkEngine()

        reverseGeocoder.placemark = MockReverseGeocoder.us

        // check auto mode has been saved
        assertThat(antiflicker!.setting, `is`(mode: .auto, updating: false))

        // connect
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraAntiflickerCapabilitiesEncoder(
                supportedModesBitField: Bitfield<ArsdkFeatureCameraAntiflickerMode>.of(.off, .mode50hz, .mode60hz)))
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraAntiflickerModeEncoder(
                mode: .mode50hz, value: .mode50hz))
            // since mode is auto and country is us, a command should be sent to set antiflicker to 60hz
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetAntiflickerMode(mode: .mode60hz))
        }
        assertThat(antiflicker!.setting, supports(modes: [.off, .mode50Hz, .mode60Hz, .auto]))
        assertThat(antiflicker!.setting, `is`(mode: .auto, updating: false))
        assertThat(antiflicker!.value, `is`(.value50Hz))
        assertThat(changeCnt, `is`(1))

        // mock commmand reception
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraAntiflickerModeEncoder(
            mode: .mode60hz, value: .mode60hz))
        assertThat(antiflicker!.setting, supports(modes: [.off, .mode50Hz, .mode60Hz, .auto]))
        assertThat(antiflicker!.setting, `is`(mode: .auto, updating: false))
        assertThat(antiflicker!.value, `is`(.value60Hz))
        assertThat(changeCnt, `is`(2))

        // country change should update the frequency
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetAntiflickerMode(mode: .mode50hz))
        reverseGeocoder.placemark = MockReverseGeocoder.fr

        // mock commmand reception
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraAntiflickerModeEncoder(
            mode: .mode50hz, value: .mode50hz))
        assertThat(antiflicker!.setting, supports(modes: [.off, .mode50Hz, .mode60Hz, .auto]))
        assertThat(antiflicker!.setting, `is`(mode: .auto, updating: false))
        assertThat(antiflicker!.value, `is`(.value50Hz))
        assertThat(changeCnt, `is`(3))

        disconnect(drone: drone, handle: 1)

        assertThat(antiflicker!.setting, supports(modes: [.off, .mode50Hz, .mode60Hz, .auto]))
        assertThat(antiflicker!.setting, `is`(mode: .auto, updating: false))
        assertThat(antiflicker!.value, `is`(.unknown))
        assertThat(changeCnt, `is`(4))

        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraAntiflickerCapabilitiesEncoder(
                supportedModesBitField: Bitfield<ArsdkFeatureCameraAntiflickerMode>.of(.off, .mode50hz, .mode60hz)))
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraAntiflickerModeEncoder(
                mode: .mode50hz, value: .mode50hz))
        }

        assertNoExpectation()
        assertThat(antiflicker!.setting, supports(modes: [.off, .mode50Hz, .mode60Hz, .auto]))
        assertThat(antiflicker!.setting, `is`(mode: .auto, updating: false))
        assertThat(antiflicker!.value, `is`(.value50Hz))
        assertThat(changeCnt, `is`(5))

        // change to fr (50Hz), should not trigger anything since we were already in 50hz
        reverseGeocoder.placemark = MockReverseGeocoder.fr
        assertNoExpectation()

        // remove auto mode to set mode 50hz
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetAntiflickerMode(mode: .mode50hz))
        antiflicker!.setting.mode = .mode50Hz
        assertThat(changeCnt, `is`(6))
        assertThat(antiflicker!.setting, `is`(mode: .mode50Hz, updating: true))
        assertThat(antiflicker!.value, `is`(.value50Hz))

        // mock change applied
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraAntiflickerModeEncoder(
            mode: .mode50hz, value: .mode50hz))
        assertThat(antiflicker!.setting, supports(modes: [.off, .mode50Hz, .mode60Hz, .auto]))
        assertThat(antiflicker!.setting, `is`(mode: .mode50Hz, updating: false))
        assertThat(antiflicker!.value, `is`(.value50Hz))
        assertThat(changeCnt, `is`(7))

        // setting to auto when country is known should directly send the command
        antiflicker!.setting.mode = .auto
        assertThat(changeCnt, `is`(8))
        assertThat(antiflicker!.setting, `is`(mode: .auto, updating: false))
        assertThat(antiflicker!.value, `is`(.value50Hz))
    }

    func testOfflineAccess() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraAntiflickerCapabilitiesEncoder(
                supportedModesBitField: Bitfield<ArsdkFeatureCameraAntiflickerMode>.of(.off, .mode50hz, .mode60hz)))
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraAntiflickerModeEncoder(
                mode: .mode50hz, value: .mode50hz))
        }

        assertThat(antiflicker, `is`(present()))
        assertThat(antiflicker!.setting, `is`(mode: .mode50Hz, updating: false))
        assertThat(antiflicker!.value, `is`(.value50Hz))

        // Disconnect
        disconnect(drone: drone, handle: 1)
        assertThat(antiflicker!.setting, `is`(mode: .mode50Hz, updating: false))
        assertThat(antiflicker!.value, `is`(.unknown))

        // user set a value (this will store the value in the preset)
        antiflicker?.setting.mode = .off
        assertThat(antiflicker!.setting, `is`(mode: .off, updating: false))
        assertThat(antiflicker!.value, `is`(.unknown))

        resetArsdkEngine()
        assertThat(antiflicker, `is`(present()))
        assertThat(changeCnt, `is`(0))

        // Check setting are loaded correctly
        assertThat(antiflicker!.setting, `is`(mode: .off, updating: false))
        assertThat(antiflicker!.value, `is`(.unknown))

        // change to 60Hz while disconneted
        antiflicker!.setting.mode = .mode60Hz
        assertThat(changeCnt, `is`(1))
        assertThat(antiflicker!.setting, `is`(mode: .mode60Hz, updating: false))

        // connect
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraAntiflickerModeEncoder(
                mode: .mode50hz, value: .mode50hz))
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetAntiflickerMode(mode: .mode60hz))
        }
        assertThat(antiflicker!.setting, `is`(mode: .mode60Hz, updating: false))
    }
}
