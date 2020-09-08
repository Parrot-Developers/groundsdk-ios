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

class CameraFeatureCameraTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var camera: MainCamera?
    var cameraRef: Ref<MainCamera>?
    var changeCnt = 0
    var changeAssertClosure: ((_ camera: Camera?) -> Void)?

    override func setUp() {
        super.setUp()
        setUpDrone()
        changeCnt = 0
    }

    private func setUpDrone() {
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net,
                                name: "Drone1", handle: 1)
        drone = droneStore.getDevice(uid: "123")!
        cameraRef = drone.getPeripheral(Peripherals.mainCamera) { [unowned self] camera in
            self.camera = camera
            self.changeCnt += 1
            self.changeAssertClosure?(self.camera)
        }
    }

    override func resetArsdkEngine() {
        super.resetArsdkEngine()
        setUpDrone()
    }

    private func sendCapabilitiesCommand(
        exposureModes: [ArsdkFeatureCameraExposureMode] = [],
        exposureLockSupported: ArsdkFeatureCameraSupported = .notSupported,
        exposureRoiLockSupported: ArsdkFeatureCameraSupported = .notSupported,
        evCompensations: [ArsdkFeatureCameraEvCompensation] = [],
        whiteBalanceModes: [ArsdkFeatureCameraWhiteBalanceMode] = [],
        customWhiteBalanceTemperatures: [ArsdkFeatureCameraWhiteBalanceTemperature] = [],
        whiteBalanceLockSupported: ArsdkFeatureCameraSupported = .notSupported,
        styles: [ArsdkFeatureCameraStyle] = [],
        cameraModes: [ArsdkFeatureCameraCameraMode] = [],
        hyperlapseValues: [ArsdkFeatureCameraHyperlapseValue] = [],
        bracketingPresets: [ArsdkFeatureCameraBracketingPreset] = [],
        burstValues: [ArsdkFeatureCameraBurstValue] = [], streamingModesBitField: UInt = 0,
        timelapseIntervalMin: Double = 0.0, gpslapseIntervalMin: Double = 0.0,
        exposureMeteringModes: [ArsdkFeatureCameraAutoExposureMeteringMode] =
        [ArsdkFeatureCameraAutoExposureMeteringMode.standard]) {
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraCameraCapabilitiesEncoder(
                camId: 0, model: .main,
                exposureModesBitField: Bitfield.of(exposureModes),
                exposureLockSupported: exposureLockSupported,
                exposureRoiLockSupported: exposureRoiLockSupported,
                evCompensationsBitField: Bitfield.of(evCompensations),
                whiteBalanceModesBitField: Bitfield.of(whiteBalanceModes),
                customWhiteBalanceTemperaturesBitField: Bitfield.of(customWhiteBalanceTemperatures),
                whiteBalanceLockSupported: whiteBalanceLockSupported,
                stylesBitField: Bitfield.of(styles),
                cameraModesBitField: Bitfield.of(cameraModes),
                hyperlapseValuesBitField: Bitfield.of(hyperlapseValues),
                bracketingPresetsBitField: Bitfield.of(bracketingPresets),
                burstValuesBitField: Bitfield.of(burstValues),
                streamingModesBitField: streamingModesBitField,
                timelapseIntervalMin: Float(timelapseIntervalMin),
                gpslapseIntervalMin: Float(gpslapseIntervalMin),
                autoExposureMeteringModesBitField: UInt(ArsdkFeatureCameraAutoExposureMeteringMode.standard.rawValue)))
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(camera, `is`(nilValue()))

        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand()
        }
        assertThat(camera, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // disconnect drone
        assertThat(camera?.whiteBalanceLock, `is`(present()))
        disconnect(drone: drone, handle: 1)
        assertThat(camera, `is`(present()))
        assertThat(camera?.whiteBalanceLock, `is`(nilValue()))

        // The Count is now '2', because the whiteBalanceLock is not visible when the camera is not active
        assertThat(changeCnt, `is`(2))

        // forget the drone
        _ = drone.forget()
        assertThat(camera, `is`(nilValue()))
        assertThat(changeCnt, `is`(3))
    }

    func testMode() {
        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand(cameraModes: [.recording, .photo])
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraCameraModeEncoder(camId: 0, mode: .recording))
        }
        assertThat(changeCnt, `is`(1))

        // Check initial value
        assertThat(camera!.modeSetting, supports(modes: [.photo, .recording]))
        assertThat(camera!.modeSetting, `is`(mode: .recording, updating: false))

        // Check backend change
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraCameraModeEncoder(camId: 0, mode: .photo))
        assertThat(changeCnt, `is`(2))
        assertThat(camera!.modeSetting, `is`(mode: .photo, updating: false))

        // Change mode
        expectCommand(
            handle: 1, expectedCmd: ExpectedCmd.cameraSetCameraMode(camId: 0, value: .recording))
        camera!.modeSetting.mode = .recording
        assertThat(changeCnt, `is`(3))
        assertThat(camera!.modeSetting, `is`(mode: .recording, updating: true))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraCameraModeEncoder(camId: 0, mode: .recording))
        assertThat(changeCnt, `is`(4))
        assertThat(camera!.modeSetting, `is`(mode: .recording, updating: false))
        assertNoExpectation()

        // disconnect
        disconnect(drone: drone, handle: 1)

        // check still in recording mode
        assertThat(camera!.modeSetting, supports(modes: [.photo, .recording]))
        assertThat(camera!.modeSetting, `is`(mode: .recording, updating: false))
        assertThat(changeCnt, `is`(5)) // +1 because cancelRollbackSettings always marks the component as changed

        // Change mode offline
        camera!.modeSetting.mode = .photo
        assertThat(changeCnt, `is`(6))
        assertThat(camera!.modeSetting, `is`(mode: .photo, updating: false))

        // restart engine
        resetArsdkEngine()
        changeCnt = 0

        // reconnect
        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand(cameraModes: [.recording, .photo])
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraCameraModeEncoder(camId: 0, mode: .recording))
            self.expectCommand(
                handle: 1, expectedCmd: ExpectedCmd.cameraSetCameraMode(camId: 0, value: .photo))
        }
        assertThat(camera!.modeSetting, `is`(mode: .photo, updating: false))
    }

    func testExposureSettings() {
        let shutterSpeedBitField: UInt64 = Bitfield<ArsdkFeatureCameraShutterSpeed>.of(
            [.shutter1, .shutter1Over10, .shutter1Over100])
        let manualIsoSensitivityBitField: UInt64 = Bitfield<ArsdkFeatureCameraIsoSensitivity>.of(
            [.iso100, .iso200, .iso320])
        let maxIsoSensitivityBitField: UInt64 = Bitfield<ArsdkFeatureCameraIsoSensitivity>.of(
            [.iso160, .iso320])
        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand(
                exposureModes: [.automatic, .manual, .manualIsoSensitivity, .manualShutterSpeed])
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraExposureSettingsEncoder(
                    camId: 0, mode: .manual,
                    manualShutterSpeed: .shutter1Over10,
                    manualShutterSpeedCapabilitiesBitField: shutterSpeedBitField,
                    manualIsoSensitivity: .iso100,
                    manualIsoSensitivityCapabilitiesBitField: manualIsoSensitivityBitField,
                    maxIsoSensitivity: .iso160,
                    maxIsoSensitivitiesCapabilitiesBitField: maxIsoSensitivityBitField,
                    meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))
        }
        assertThat(changeCnt, `is`(1))

        // Check capabilities
        assertThat(camera!.exposureSettings, supports(
            exposureModes: [.automatic, .manual, .manualIsoSensitivity, .manualShutterSpeed],
            shutterSpeeds: [.one, .oneOver10, .oneOver100],
            isoSensitivities: [.iso100, .iso200, .iso320], maximumIsoSensitivities: [.iso160, .iso320]))
        // Check initial values
        assertThat(camera!.exposureSettings,
                   `is`(mode: .manual, shutterSpeed: .oneOver10,
                        isoSensitivity: .iso100,
                        maximumIsoSensitivity: .iso160,
                        autoExposureMeteringMode: .standard,
                        updating: false))

        // Change mode to automatic
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetExposureSettings(
            camId: 0, mode: .automatic, shutterSpeed: .shutter1Over10, isoSensitivity: .iso100,
            maxIsoSensitivity: .iso160, meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))
        camera!.exposureSettings.mode = .automatic
        assertThat(changeCnt, `is`(2))
        assertThat(camera!.exposureSettings, `is`(mode: .automatic, updating: true))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraExposureSettingsEncoder(
                camId: 0, mode: .automatic, manualShutterSpeed: .shutter1Over10,
                manualShutterSpeedCapabilitiesBitField: shutterSpeedBitField,
                manualIsoSensitivity: .iso100, manualIsoSensitivityCapabilitiesBitField: manualIsoSensitivityBitField,
                maxIsoSensitivity: .iso160, maxIsoSensitivitiesCapabilitiesBitField: maxIsoSensitivityBitField,
                meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))

        assertThat(changeCnt, `is`(3))
        assertThat(camera!.exposureSettings, `is`(mode: .automatic, updating: false))

        // change to center top auto exposure metering mode
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetExposureSettings(
            camId: 0, mode: .manual, shutterSpeed: .shutter1Over10, isoSensitivity: .iso100,
            maxIsoSensitivity: .iso160, meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.centerTop))
        camera!.exposureSettings.set(mode: .manual, manualShutterSpeed: nil,
                                     manualIsoSensitivity: nil, maximumIsoSensitivity: nil,
                                     autoExposureMeteringMode: .centerTop)
        assertThat(changeCnt, `is`(4))
        assertThat(camera!.exposureSettings, `is`(
            mode: .manual, autoExposureMeteringMode: .centerTop, updating: true))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraExposureSettingsEncoder(
                camId: 0, mode: .manual,
                manualShutterSpeed: .shutter1Over100,
                manualShutterSpeedCapabilitiesBitField: shutterSpeedBitField,
                manualIsoSensitivity: .iso100,
                manualIsoSensitivityCapabilitiesBitField: manualIsoSensitivityBitField,
                maxIsoSensitivity: .iso160,
                maxIsoSensitivitiesCapabilitiesBitField: maxIsoSensitivityBitField,
                meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.centerTop))
        assertThat(changeCnt, `is`(5))
        assertThat(camera!.exposureSettings, `is`(
            mode: .manual, autoExposureMeteringMode: .centerTop, updating: false))

        // rollback to standard auto exposure metering mode by using method
        // without autoExposureMeteringMode parameter
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetExposureSettings(
            camId: 0, mode: .automatic, shutterSpeed: .shutter1Over100, isoSensitivity: .iso100,
            maxIsoSensitivity: .iso160, meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))
        camera!.exposureSettings.set(mode: .automatic, manualShutterSpeed: nil,
                                     manualIsoSensitivity: nil, maximumIsoSensitivity: nil)
        assertThat(changeCnt, `is`(6))
        assertThat(camera!.exposureSettings, `is`(
            mode: .automatic, autoExposureMeteringMode: .standard, updating: true))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraExposureSettingsEncoder(
                camId: 0, mode: .automatic,
                manualShutterSpeed: .shutter1Over100,
                manualShutterSpeedCapabilitiesBitField: shutterSpeedBitField,
                manualIsoSensitivity: .iso100,
                manualIsoSensitivityCapabilitiesBitField: manualIsoSensitivityBitField,
                maxIsoSensitivity: .iso160,
                maxIsoSensitivitiesCapabilitiesBitField: maxIsoSensitivityBitField,
                meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))
        assertThat(changeCnt, `is`(7))
        assertThat(camera!.exposureSettings, `is`(
            mode: .automatic, autoExposureMeteringMode: .standard, updating: false))

        // change to manual shutter speed
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetExposureSettings(
            camId: 0, mode: .manualShutterSpeed, shutterSpeed: .shutter1Over100, isoSensitivity: .iso100,
            maxIsoSensitivity: .iso160, meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))
        camera!.exposureSettings.set(mode: .manualShutterSpeed, manualShutterSpeed: .oneOver100,
                                     manualIsoSensitivity: nil, maximumIsoSensitivity: nil,
                                     autoExposureMeteringMode: nil)
        assertThat(changeCnt, `is`(8))
        assertThat(camera!.exposureSettings, `is`(
            mode: .manualShutterSpeed, shutterSpeed: .oneOver100, updating: true))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraExposureSettingsEncoder(
                camId: 0, mode: .manualShutterSpeed,
                manualShutterSpeed: .shutter1Over100,
                manualShutterSpeedCapabilitiesBitField: shutterSpeedBitField,
                manualIsoSensitivity: .iso100,
                manualIsoSensitivityCapabilitiesBitField: manualIsoSensitivityBitField,
                maxIsoSensitivity: .iso160,
                maxIsoSensitivitiesCapabilitiesBitField: maxIsoSensitivityBitField,
                meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))
        assertThat(changeCnt, `is`(9))
        assertThat(camera!.exposureSettings, `is`(
            mode: .manualShutterSpeed, shutterSpeed: .oneOver100, updating: false))

        // change to manual iso
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetExposureSettings(
            camId: 0, mode: .manualIsoSensitivity, shutterSpeed: .shutter1Over100, isoSensitivity: .iso320,
            maxIsoSensitivity: .iso160, meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))
        camera!.exposureSettings.set(mode: .manualIsoSensitivity, manualShutterSpeed: nil,
                                     manualIsoSensitivity: .iso320, maximumIsoSensitivity: nil,
                                     autoExposureMeteringMode: nil)
        assertThat(changeCnt, `is`(10))
        assertThat(camera!.exposureSettings, `is`(
            mode: .manualIsoSensitivity, isoSensitivity: .iso320, updating: true))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraExposureSettingsEncoder(
                camId: 0, mode: .manualIsoSensitivity,
                manualShutterSpeed: .shutter1Over100,
                manualShutterSpeedCapabilitiesBitField: shutterSpeedBitField,
                manualIsoSensitivity: .iso320,
                manualIsoSensitivityCapabilitiesBitField: manualIsoSensitivityBitField,
                maxIsoSensitivity: .iso160,
                maxIsoSensitivitiesCapabilitiesBitField: maxIsoSensitivityBitField,
                meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))
        assertThat(changeCnt, `is`(11))
        assertThat(camera!.exposureSettings, `is`(
            mode: .manualIsoSensitivity, isoSensitivity: .iso320, updating: false))

        // change to automatic, with maximum iso
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetExposureSettings(
            camId: 0, mode: .automatic, shutterSpeed: .shutter1Over100, isoSensitivity: .iso320,
            maxIsoSensitivity: .iso320, meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))
        camera!.exposureSettings.set(mode: .automatic, manualShutterSpeed: nil,
                                     manualIsoSensitivity: nil, maximumIsoSensitivity: .iso320,
                                     autoExposureMeteringMode: nil)
        assertThat(changeCnt, `is`(12))
        assertThat(camera!.exposureSettings, `is`(
            mode: .automatic, maximumIsoSensitivity: .iso320, updating: true))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraExposureSettingsEncoder(
                camId: 0, mode: .automatic,
                manualShutterSpeed: .shutter1Over100,
                manualShutterSpeedCapabilitiesBitField: shutterSpeedBitField,
                manualIsoSensitivity: .iso320,
                manualIsoSensitivityCapabilitiesBitField: manualIsoSensitivityBitField,
                maxIsoSensitivity: .iso320,
                maxIsoSensitivitiesCapabilitiesBitField: maxIsoSensitivityBitField,
                meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))
        assertThat(changeCnt, `is`(13))
        assertThat(camera!.exposureSettings, `is`(
            mode: .automatic, maximumIsoSensitivity: .iso320, updating: false))

        // change shutter speed, iso sensitivity then change mode
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetExposureSettings(
            camId: 0, mode: .automatic, shutterSpeed: .shutter1Over10, isoSensitivity: .iso320,
            maxIsoSensitivity: .iso320, meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))
        camera!.exposureSettings.manualShutterSpeed = .oneOver10
        assertThat(changeCnt, `is`(14))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetExposureSettings(
            camId: 0, mode: .automatic, shutterSpeed: .shutter1Over10, isoSensitivity: .iso200,
            maxIsoSensitivity: .iso320, meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))
        camera!.exposureSettings.manualIsoSensitivity = .iso200

        assertThat(changeCnt, `is`(15))
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetExposureSettings(
            camId: 0, mode: .manual, shutterSpeed: .shutter1Over10, isoSensitivity: .iso200,
            maxIsoSensitivity: .iso320, meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))
        camera!.exposureSettings.mode = .manual
        assertThat(changeCnt, `is`(16))
        assertThat(camera!.exposureSettings, `is`(
            mode: .manual, shutterSpeed: .oneOver10, isoSensitivity: .iso200, updating: true))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraExposureSettingsEncoder(
                camId: 0, mode: .manual,
                manualShutterSpeed: .shutter1Over10,
                manualShutterSpeedCapabilitiesBitField: shutterSpeedBitField,
                manualIsoSensitivity: .iso200,
                manualIsoSensitivityCapabilitiesBitField: manualIsoSensitivityBitField,
                maxIsoSensitivity: .iso160,
                maxIsoSensitivitiesCapabilitiesBitField: maxIsoSensitivityBitField,
                meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))
        assertThat(changeCnt, `is`(17))
        assertThat(camera!.exposureSettings, `is`(
            mode: .manual, shutterSpeed: .oneOver10, isoSensitivity: .iso200, updating: false))

        // disconnect
        disconnect(drone: drone, handle: 1)

        // exposure settings is available offline. WhiteBalance Lock is now nil
        assertThat(changeCnt, `is`(18))
        assertThat(camera!.exposureSettings, `is`(
            mode: .manual, shutterSpeed: .oneOver10, isoSensitivity: .iso200, updating: false))
        assertThat(camera!.exposureSettings, supports(
            exposureModes: [.automatic, .manual, .manualIsoSensitivity, .manualShutterSpeed],
            shutterSpeeds: [.one, .oneOver10, .oneOver100],
            isoSensitivities: [.iso100, .iso200, .iso320], maximumIsoSensitivities: [.iso160, .iso320]))

        camera!.exposureSettings.mode = .manualIsoSensitivity
        assertThat(changeCnt, `is`(19))
        assertThat(camera!.exposureSettings, `is`(
            mode: .manualIsoSensitivity, shutterSpeed: .oneOver10, isoSensitivity: .iso200, updating: false))

        camera!.exposureSettings.manualIsoSensitivity = .iso100
        assertThat(camera!.exposureSettings, `is`(
            mode: .manualIsoSensitivity, shutterSpeed: .oneOver10, isoSensitivity: .iso100, updating: false))
        assertThat(changeCnt, `is`(20))

        camera!.exposureSettings.mode = .manualShutterSpeed
        assertThat(changeCnt, `is`(21))
        assertThat(camera!.exposureSettings, `is`(
            mode: .manualShutterSpeed, shutterSpeed: .oneOver10, isoSensitivity: .iso100, updating: false))

        camera!.exposureSettings.manualShutterSpeed = .oneOver100
        assertThat(camera!.exposureSettings, `is`(
            mode: .manualShutterSpeed, shutterSpeed: .oneOver100, isoSensitivity: .iso100, updating: false))
        assertThat(changeCnt, `is`(22))

        camera!.exposureSettings.mode = .manual
        assertThat(camera!.exposureSettings, `is`(
            mode: .manual, shutterSpeed: .oneOver100, isoSensitivity: .iso100, updating: false))

        assertThat(changeCnt, `is`(23))

        camera!.exposureSettings.mode = .automatic
        assertThat(changeCnt, `is`(24))
        camera!.exposureSettings.maximumIsoSensitivity = .iso320
        assertThat(camera!.exposureSettings, `is`(
            mode: .automatic, shutterSpeed: .oneOver100, isoSensitivity: .iso100, maximumIsoSensitivity: .iso320,
            updating: false))

        assertThat(changeCnt, `is`(25))

        changeCnt = 0
        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand(
                exposureModes: [.automatic, .manual, .manualIsoSensitivity, .manualShutterSpeed])
            // receive the last online value
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraExposureSettingsEncoder(
                    camId: 0, mode: .manual,
                    manualShutterSpeed: .shutter1Over10,
                    manualShutterSpeedCapabilitiesBitField: shutterSpeedBitField,
                    manualIsoSensitivity: .iso200,
                    manualIsoSensitivityCapabilitiesBitField: manualIsoSensitivityBitField,
                    maxIsoSensitivity: .iso160,
                    maxIsoSensitivitiesCapabilitiesBitField: maxIsoSensitivityBitField,
                    meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))

            // send the new value (setted offline)
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetExposureSettings(
                camId: 0, mode: .automatic, shutterSpeed: .shutter1Over100, isoSensitivity: .iso100,
                maxIsoSensitivity: .iso320, meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))
        }

        // 2 for capabilities and Updating
        assertThat(changeCnt, `is`(2))

        assertThat(camera!.exposureSettings, `is`(
            mode: .automatic, shutterSpeed: .oneOver100, isoSensitivity: .iso100, maximumIsoSensitivity: .iso320,
            updating: false))

        // check the new value for the drone
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraExposureSettingsEncoder(
                camId: 0, mode: .automatic,
                manualShutterSpeed: .shutter1Over100,
                manualShutterSpeedCapabilitiesBitField: shutterSpeedBitField,
                manualIsoSensitivity: .iso100,
                manualIsoSensitivityCapabilitiesBitField: manualIsoSensitivityBitField,
                maxIsoSensitivity: .iso320,
                maxIsoSensitivitiesCapabilitiesBitField: maxIsoSensitivityBitField,
                meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))

        assertThat(camera!.exposureSettings, `is`(
            mode: .automatic, shutterSpeed: .oneOver100, isoSensitivity: .iso100, maximumIsoSensitivity: .iso320,
            updating: false))
        assertThat(changeCnt, `is`(2))
        // disconnect
        disconnect(drone: drone, handle: 1)

        // exposure settings is available offline. WhiteBalance Lock is now nil
        assertThat(changeCnt, `is`(3))
    }

    func testExposureLock() {
        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand()
        }

        // check initial value
        assertThat(camera!.exposureLock, nilValue())
        assertThat(changeCnt, `is`(1))

        // mock lock command reception
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraExposureEncoder(
                camId: 0, shutterSpeed: .shutter1Over10, isoSensitivity: .iso1200, lock: .inactive,
                lockRoiX: -1, lockRoiY: -1, lockRoiWidth: -1, lockRoiHeight: -1))
        assertThat(camera!.exposureLock, presentAnd(`is`(mode: CameraExposureLockMode.none, updating: false)))
        assertThat(changeCnt, `is`(2))

        // change mode from api
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraLockExposureOnRoi(
            camId: 0, roiCenterX: 0.5, roiCenterY: 0.5))
        camera?.exposureLock?.lockOnRegion(centerX: 0.5, centerY: 0.5)

        assertThat(camera!.exposureLock, presentAnd(`is`(
            mode: .region(centerX: 0.5, centerY: 0.5, width: 0.0, height: 0.0), updating: true)))
        assertThat(changeCnt, `is`(3))

        // since event is non-ack, we can receive this event before requested value has been applied,
        // check that we are protecting changes for this case
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraExposureEncoder(
                camId: 0, shutterSpeed: .shutter1Over10, isoSensitivity: .iso1200, lock: .inactive,
                lockRoiX: -1, lockRoiY: -1, lockRoiWidth: -1, lockRoiHeight: -1))
        assertThat(camera!.exposureLock, presentAnd(`is`(
            mode: .region(centerX: 0.5, centerY: 0.5, width: 0.0, height: 0.0), updating: true)))
        assertThat(changeCnt, `is`(3))

        // mock requested value applied
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraExposureEncoder(
                camId: 0, shutterSpeed: .shutter1Over10, isoSensitivity: .iso1200, lock: .active,
                lockRoiX: 0.5, lockRoiY: 0.5, lockRoiWidth: 0.4, lockRoiHeight: 0.2))

        assertThat(camera!.exposureLock, presentAnd(`is`(
            mode: .region(centerX: 0.5, centerY: 0.5, width: Double(Float(0.4)), height: Double(Float(0.2))),
            updating: false)))
        assertThat(changeCnt, `is`(4))

        // mock unrequested change
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraExposureEncoder(
                camId: 0, shutterSpeed: .shutter1Over10, isoSensitivity: .iso1200, lock: .inactive,
                lockRoiX: 0.5, lockRoiY: 0.5, lockRoiWidth: 0.4, lockRoiHeight: 0.2))
        assertThat(camera!.exposureLock, presentAnd(`is`(mode: CameraExposureLockMode.none, updating: false)))
        assertThat(changeCnt, `is`(5))

        // mock unrequested change
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraExposureEncoder(
                camId: 0, shutterSpeed: .shutter1Over10, isoSensitivity: .iso1200, lock: .active,
                lockRoiX: -1, lockRoiY: -1, lockRoiWidth: -1, lockRoiHeight: -1))
        assertThat(camera!.exposureLock, presentAnd(`is`(mode: .currentValues, updating: false)))
        assertThat(changeCnt, `is`(6))

        // Exposure lock should be nil after a disconnection
        disconnect(drone: drone, handle: 1)
        assertThat(camera!.exposureLock, nilValue())
        assertThat(changeCnt, `is`(7))
    }

    func testExposureCompensationSettings() {
        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand(evCompensations: [.evMinus3_00, .ev0_00, .ev3_00])
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraEvCompensationEncoder(camId: 0, value: .ev0_00))
        }
        assertThat(changeCnt, `is`(1))
        // Check capabilities
        assertThat(camera!.exposureSettings.mode, `is`(.automatic))
        assertThat(camera!.exposureLock, nilValue())

        assertThat(camera!.exposureCompensationSetting, supports(exposureCompensationValues:
            [.evMinus3_00, .ev0_00, .ev3_00]))
        // Check initial values
        assertThat(camera!.exposureCompensationSetting, `is`(value: .ev0_00, updating: false))

        // change value
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetEvCompensation(
            camId: 0, value: .ev3_00))
        camera!.exposureCompensationSetting.value = .ev3_00
        assertThat(changeCnt, `is`(2))
        assertThat(camera!.exposureCompensationSetting, `is`(value: .ev3_00, updating: true))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraEvCompensationEncoder(camId: 0, value: .ev3_00))
        assertThat(changeCnt, `is`(3))
        assertThat(camera!.exposureCompensationSetting, `is`(value: .ev3_00, updating: false))

        // change exposure mode to manual
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraExposureSettingsEncoder(
                camId: 0, mode: .manual, manualShutterSpeed: .shutter1, manualShutterSpeedCapabilitiesBitField: 0,
                manualIsoSensitivity: .iso200, manualIsoSensitivityCapabilitiesBitField: 0,
                maxIsoSensitivity: .iso160, maxIsoSensitivitiesCapabilitiesBitField: 0,
                meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))

        // check that exposure compensation setting is not available, in manual exposure mode
        assertThat(changeCnt, `is`(4))
        assertThat(camera!.exposureCompensationSetting, supports(exposureCompensationValues: []))

        // change supported exposure compensation values while in manual exposure mode
        self.sendCapabilitiesCommand(evCompensations: [.evMinus1_00, .ev0_00, .ev3_00])
        assertThat(changeCnt, `is`(4))
        assertThat(camera!.exposureCompensationSetting, supports(exposureCompensationValues: []))

        // change exposure mode to automatic
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraExposureSettingsEncoder(
                camId: 0, mode: .automatic, manualShutterSpeed: .shutter1, manualShutterSpeedCapabilitiesBitField: 0,
                manualIsoSensitivity: .iso200, manualIsoSensitivityCapabilitiesBitField: 0,
                maxIsoSensitivity: .iso160, maxIsoSensitivitiesCapabilitiesBitField: 0,
                meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))

        assertThat(changeCnt, `is`(5))
        assertThat(camera!.exposureCompensationSetting,
                   allOf(
                    supports(exposureCompensationValues: [.evMinus1_00, .ev0_00, .ev3_00]),
                    `is`(value: .ev3_00, updating: false)))

        // activate exposure lock
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraExposureEncoder(camId: 0, shutterSpeed: .shutter1Over10,
                isoSensitivity: .iso1200, lock: .active,
                lockRoiX: -1, lockRoiY: -1, lockRoiWidth: -1, lockRoiHeight: -1))

        assertThat(changeCnt, `is`(6))
        assertThat(camera!.exposureCompensationSetting, supports(exposureCompensationValues: []))

        // change supported exposure compensation values while exposure lock is active
        self.sendCapabilitiesCommand(evCompensations: [.evMinus0_33, .ev0_33, .ev2_33])
        assertThat(changeCnt, `is`(6))
        assertThat(camera!.exposureCompensationSetting, supports(exposureCompensationValues: []))

        // deactivate exposure lock
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraExposureEncoder(camId: 0, shutterSpeed: .shutter1Over10,
                isoSensitivity: .iso1200, lock: .inactive,
                lockRoiX: -1, lockRoiY: -1, lockRoiWidth: -1, lockRoiHeight: -1))

        assertThat(changeCnt, `is`(7))
        assertThat(camera!.exposureCompensationSetting,
                   allOf(
                    supports(exposureCompensationValues: [.evMinus0_33, .ev0_33, .ev2_33]),
                    `is`(value: .ev3_00, updating: false)))

        // disconnect
        disconnect(drone: drone, handle: 1)

        // exposure compensation settings not available offline
        assertThat(changeCnt, `is`(8))
        assertThat(camera!.exposureCompensationSetting, supports(
            exposureCompensationValues: [.evMinus0_33, .ev0_33, .ev2_33]))

        camera!.exposureCompensationSetting.value = .ev0_33
        assertThat(camera!.exposureCompensationSetting,
                   allOf(
                    supports(exposureCompensationValues: [.evMinus0_33, .ev0_33, .ev2_33]),
                    `is`(value: .ev0_33, updating: false)))
        assertThat(changeCnt, `is`(9))
        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand(evCompensations: [.evMinus0_33, .ev0_33, .ev2_33])
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraEvCompensationEncoder(camId: 0, value: .ev0_00))
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetEvCompensation(camId: 0, value: .ev0_33))
        }

        assertThat(changeCnt, `is`(11))
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraEvCompensationEncoder(camId: 0, value: .ev0_33))
        assertThat(camera!.exposureCompensationSetting,
                   allOf(
                    supports(exposureCompensationValues: [.evMinus0_33, .ev0_33, .ev2_33]),
                    `is`(value: .ev0_33, updating: false)))

    }

    func testActiveStyle() {
        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand(styles: [.standard, .plog])
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraStyleEncoder(
                camId: 0, style: .standard, saturation: 1, saturationMin: -2, saturationMax: 2,
                contrast: 2, contrastMin: -4, contrastMax: 4, sharpness: 3, sharpnessMin: -6, sharpnessMax: 6))
        }
        assertThat(changeCnt, `is`(1))

        // Check capabilities
        assertThat(camera!.styleSettings, supports(styles: [.standard, .plog]))
        // Check initial values
        assertThat(camera!.styleSettings, `is`(
            activeStyle: .standard, saturation: (-2, 1, 2), contrast: (-4, 2, 4), sharpness: (-6, 3, 6)))

        // change style
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetStyle(camId: 0, style: .plog))
        camera!.styleSettings.activeStyle = .plog
        assertThat(changeCnt, `is`(2))
        assertThat(camera!.styleSettings, `is`(activeStyle: .plog, saturation: (0, 0, 0), contrast: (0, 0, 0),
                                               sharpness: (0, 0, 0), updating: true))
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraStyleEncoder(
            camId: 0, style: .plog, saturation: 0, saturationMin: -1, saturationMax: 1,
            contrast: 0, contrastMin: -2, contrastMax: 2, sharpness: 0, sharpnessMin: -3, sharpnessMax: 3))
        // notificationUpdate() active style + notificationUpdate() for saturation / contrast / sharpness
        assertThat(changeCnt, `is`(6))
        assertThat(camera!.styleSettings, `is`(
            activeStyle: .plog, saturation: (-1, 0, 1), contrast: (-2, 0, 2), sharpness: (-3, 0, 3), updating: false))

        // disconnect
        disconnect(drone: drone, handle: 1)
        // style settings not available offline
        assertThat(changeCnt, `is`(7))
        assertThat(camera!.styleSettings, supports(styles: [.standard, .plog]))

        resetArsdkEngine()
        changeCnt = 0

    }

    func testStyleParameter() {
        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand(styles: [.standard])
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraStyleEncoder(
                camId: 0, style: .standard, saturation: 1, saturationMin: -2, saturationMax: 2,
                contrast: 2, contrastMin: -4, contrastMax: 4, sharpness: 0, sharpnessMin: 0, sharpnessMax: 0))
        }
        assertThat(changeCnt, `is`(1))
        assertThat(camera!.styleSettings, `is`(saturation: (-2, 1, 2), contrast: (-4, 2, 4), sharpness: (0, 0, 0)))
        assertThat(camera!.styleSettings.sharpness.mutable, `is`(false))

        // change contrast
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetStyleParams(
            camId: 0, saturation: 1, contrast: -2, sharpness: 0))
        camera?.styleSettings.contrast.value = -2
        assertThat(changeCnt, `is`(2))

        assertThat(camera!.styleSettings, `is`(saturation: (-2, 1, 2), contrast: (-4, -2, 4), sharpness: (0, 0, 0),
            updating: true))
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraStyleEncoder(
            camId: 0, style: .standard, saturation: 1, saturationMin: -2, saturationMax: 2,
            contrast: -2, contrastMin: -4, contrastMax: 4, sharpness: 0, sharpnessMin: 0, sharpnessMax: 0))
        assertThat(changeCnt, `is`(3))
        assertThat(camera!.styleSettings, `is`(
            saturation: (-2, 1, 2), contrast: (-4, -2, 4), sharpness: (0, 0, 0), updating: false))

        // disconnect
        disconnect(drone: drone, handle: 1)
        // style parameters settings not available offline
        assertThat(changeCnt, `is`(4))
        assertThat(camera!.styleSettings, `is`(
            saturation: (-2, 1, 2), contrast: (-4, -2, 4), sharpness: (0, 0, 0), updating: false))

        camera?.styleSettings.contrast.value = -1
        assertThat(camera!.styleSettings, `is`(
            saturation: (-2, 1, 2), contrast: (-4, -1, 4), sharpness: (0, 0, 0), updating: false))
        assertThat(changeCnt, `is`(5))

        camera?.styleSettings.sharpness.value = 1
        assertThat(camera!.styleSettings, `is`(
            saturation: (-2, 1, 2), contrast: (-4, -1, 4), sharpness: (0, 0, 0), updating: false))
        assertThat(changeCnt, `is`(5))

        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand(styles: [.standard])
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraStyleEncoder(
                camId: 0, style: .standard, saturation: 1, saturationMin: -2, saturationMax: 2,
                contrast: 2, contrastMin: -4, contrastMax: 4, sharpness: 0, sharpnessMin: 0, sharpnessMax: 0))

            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetStyleParams(camId: 0, saturation: 1,
                                                                                        contrast: -1, sharpness: 0))
        }

    }

    func testWhiteBalanceSettings() {
        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand(whiteBalanceModes: [.automatic, .sunny, .snow, .custom],
                customWhiteBalanceTemperatures: [.T3000, .T5000, .T7000])
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraWhiteBalanceEncoder(
                    camId: 0, mode: .automatic, temperature: .T3000, lock: .inactive))
        }
        assertThat(changeCnt, `is`(1))
        // Check capabilities
        assertThat(camera!.whiteBalanceSettings, supports(
            whiteBalanceModes: [.automatic, .sunny, .snow, .custom],
            customTemperatures: [.k3000, .k5000, .k7000]))

        // Check initial values
        assertThat(camera!.whiteBalanceSettings, `is`(mode: .automatic, updating: false))

        // change mode
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetWhiteBalance(
            camId: 0, mode: .sunny, temperature: .T3000))
        camera!.whiteBalanceSettings.mode = .sunny
        assertThat(changeCnt, `is`(2))
        assertThat(camera!.whiteBalanceSettings, `is`(mode: .sunny, updating: true))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraWhiteBalanceEncoder(
            camId: 0, mode: .sunny, temperature: .T3000, lock: .inactive))
        assertThat(changeCnt, `is`(3))
        assertThat(camera!.whiteBalanceSettings, `is`(mode: .sunny, updating: false))

        // custom temperature
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetWhiteBalance(
            camId: 0, mode: .custom, temperature: .T7000))
        camera!.whiteBalanceSettings.set(mode: .custom, customTemperature: .k7000)
        assertThat(changeCnt, `is`(4))
        assertThat(camera!.whiteBalanceSettings, `is`(mode: .custom, customTemperature: .k7000, updating: true))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraWhiteBalanceEncoder(
            camId: 0, mode: .custom, temperature: .T7000, lock: .inactive))
        assertThat(camera!.whiteBalanceSettings, `is`(mode: .custom, customTemperature: .k7000, updating: false))
         assertThat(changeCnt, `is`(5))
        // disconnect
        disconnect(drone: drone, handle: 1)

        // White balance settings not available offline
        assertThat(changeCnt, `is`(6))
        assertThat(camera!.whiteBalanceSettings, supports(
            whiteBalanceModes: [.automatic, .sunny, .snow, .custom],
            customTemperatures: [.k3000, .k5000, .k7000]))

        camera!.whiteBalanceSettings.set(mode: .automatic, customTemperature: .k3000)
        assertThat(camera!.whiteBalanceSettings, `is`(mode: .automatic, customTemperature: .k3000, updating: false))
        assertThat(changeCnt, `is`(7))

        resetArsdkEngine()
        changeCnt = 0
        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand(whiteBalanceModes: [.automatic, .sunny, .snow, .custom],
                                         customWhiteBalanceTemperatures: [.T3000, .T5000, .T7000])
            // receive the last online value
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraWhiteBalanceEncoder(
                camId: 0, mode: .custom, temperature: .T7000, lock: .inactive))

            // send the new value (setted offline)
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetWhiteBalance(
                camId: 0, mode: .automatic, temperature: .T3000))
        }

        assertThat(camera!.whiteBalanceSettings, supports(whiteBalanceModes: [.automatic, .sunny, .snow, .custom],
                                                          customTemperatures: [.k3000, .k5000, .k7000]))

        assertThat(camera!.whiteBalanceSettings, `is`(mode: .automatic, customTemperature: .k3000, updating: false))
        assertThat(changeCnt, `is`(2))
    }

    func testHdrSetting() {
        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand(cameraModes: [.recording, .photo])
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraHdrSettingEncoder(
                camId: 0, value: .inactive))
        }
        assertThat(changeCnt, `is`(1))

        // check initial value
        assertThat(camera!.hdrSetting, presentAnd(`is`(false)))

        // change value
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetHdrSetting(camId: 0, value: .active))
        camera!.hdrSetting?.value = true
        assertThat(changeCnt, `is`(2))
        assertThat(camera!.hdrSetting, presentAnd(allOf(`is`(true), isUpdating())))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraHdrSettingEncoder(camId: 0, value: .active))
        assertThat(changeCnt, `is`(3))
        assertThat(camera!.hdrSetting, presentAnd(allOf(`is`(true), isUpToDate())))

        // disconnect
        disconnect(drone: drone, handle: 1)

        // check hdr setting didn't change
        assertThat(camera!.hdrSetting, presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(changeCnt, `is`(4)) // +1 because cancelRollbackSettings always marks the component as changed

        // Change value offline
        camera!.hdrSetting?.value = false
        assertThat(changeCnt, `is`(5))
        assertThat(camera!.hdrSetting, presentAnd(allOf(`is`(false), isUpToDate())))

        // restart engine
        resetArsdkEngine()
        changeCnt = 0

        // reconnect
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraHdrSettingEncoder(
                camId: 0, value: .active))
            self.expectCommand(
                handle: 1, expectedCmd: ExpectedCmd.cameraSetHdrSetting(camId: 0, value: .inactive))
        }
        assertThat(camera!.hdrSetting, presentAnd(allOf(`is`(false), isUpToDate())))
    }

    func testRecordingSettings() {
        connect(drone: drone, handle: 1) {
            // capabilities
            self.sendCapabilitiesCommand(hyperlapseValues: [.ratio15, .ratio30, .ratio60])
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraRecordingCapabilitiesEncoder(
                id: 0, recordingModesBitField: Bitfield<ArsdkFeatureCameraRecordingMode>.of(.standard, .hyperlapse),
                resolutionsBitField: Bitfield<ArsdkFeatureCameraResolution>.of(.resDci4k, .resUhd4k, .res1080p),
                frameratesBitField: Bitfield<ArsdkFeatureCameraFramerate>.of(.fps24, .fps25, .fps30),
                hdr: .supported, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraRecordingCapabilitiesEncoder(
                id: 1, recordingModesBitField: Bitfield<ArsdkFeatureCameraRecordingMode>.of(.highFramerate),
                resolutionsBitField: Bitfield<ArsdkFeatureCameraResolution>.of(.res1080p, .res720p),
                frameratesBitField: Bitfield<ArsdkFeatureCameraFramerate>.of(.fps48, .fps50, .fps60),
                hdr: .notSupported, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))
            // current mode
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraRecordingModeEncoder(
                    camId: 0, mode: .standard, resolution: .res1080p, framerate: .fps24, hyperlapse: .ratio30,
                    bitrate: 0))
       }

        assertThat(changeCnt, `is`(1))
        // Check capabilities
        assertThat(camera!.recordingSettings, supports(
            recordingModes: [.standard, .hyperlapse, .highFramerate],
            hyperlapseValues: [.ratio15, .ratio30, .ratio60]))
        assertThat(camera!.recordingSettings, supports(
            forMode: .standard, resolutions: [.resDci4k, .resUhd4k, .res1080p]))
        assertThat(camera!.recordingSettings, supports(
            forMode: .hyperlapse, resolutions: [.resDci4k, .resUhd4k, .res1080p]))
        assertThat(camera!.recordingSettings, supports(
            forMode: .highFramerate, resolutions: [.res1080p, .res720p]))
        assertThat(camera!.recordingSettings, supports(
            forMode: .standard, resolution: .resDci4k, framerates: [.fps24, .fps25, .fps30]))
        assertThat(camera!.recordingSettings, supports(
            forMode: .standard, resolution: .resUhd4k, framerates: [.fps24, .fps25, .fps30]))
        assertThat(camera!.recordingSettings, supports(
            forMode: .standard, resolution: .res1080p, framerates: [.fps24, .fps25, .fps30]))
        assertThat(camera!.recordingSettings, supports(
            forMode: .hyperlapse, resolution: .resDci4k, framerates: [.fps24, .fps25, .fps30]))
        assertThat(camera!.recordingSettings, supports(
            forMode: .hyperlapse, resolution: .resUhd4k, framerates: [.fps24, .fps25, .fps30]))
        assertThat(camera!.recordingSettings, supports(
            forMode: .hyperlapse, resolution: .res1080p, framerates: [.fps24, .fps25, .fps30]))
        assertThat(camera!.recordingSettings, supports(
            forMode: .highFramerate, resolution: .res1080p, framerates: [.fps48, .fps50, .fps60]))
        assertThat(camera!.recordingSettings, supports(
            forMode: .highFramerate, resolution: .res720p, framerates: [.fps48, .fps50, .fps60]))
        assertThat(camera!.recordingSettings, `is`(
            hdrAvailable: true, forMode: .standard, resolution: .resUhd4k, framerate: .fps30))
        assertThat(camera!.recordingSettings, `is`(
            hdrAvailable: false, forMode: .highFramerate, resolution: .res720p, framerate: .fps30))

        // Check initial values
        assertThat(camera!.recordingSettings, `is`(
            mode: .standard, resolution: .res1080p, framerate: .fps24, hyperlapse: .ratio15))
        assertThat(camera!.recordingSettings, `is`(hdrAvailable: true))

        // Change mode to hyperlapse, expect resolution, framerate and hyperlapse to default value
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetRecordingMode(
            camId: 0, mode: .hyperlapse, resolution: .resDci4k, framerate: .fps30, hyperlapse: .ratio15))
        camera!.recordingSettings.mode = .hyperlapse
        assertThat(changeCnt, `is`(2))
        assertThat(camera!.recordingSettings, `is`(
            mode: .hyperlapse, resolution: .resDci4k, framerate: .fps30, hyperlapse: .ratio15, updating: true))
        assertNoExpectation()
        assertThat(camera!.recordingSettings, `is`(hdrAvailable: true))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraRecordingModeEncoder(
                camId: 0, mode: .hyperlapse, resolution: .resDci4k, framerate: .fps30, hyperlapse: .ratio30,
                bitrate: 0))
        assertThat(changeCnt, `is`(3))
        assertThat(camera!.recordingSettings, `is`(
            mode: .hyperlapse, resolution: .resDci4k, framerate: .fps30, hyperlapse: .ratio30, updating: false))

        // change resolution in hyperlapse mode
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetRecordingMode(
            camId: 0, mode: .hyperlapse, resolution: .resUhd4k, framerate: .fps30, hyperlapse: .ratio30))
        camera?.recordingSettings.resolution = .resUhd4k
        assertThat(changeCnt, `is`(4))
        assertThat(camera!.recordingSettings, `is`(
            mode: .hyperlapse, resolution: .resUhd4k, framerate: .fps30, hyperlapse: .ratio30, updating: true))
        assertNoExpectation()

        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraRecordingModeEncoder(
                camId: 0, mode: .hyperlapse, resolution: .resUhd4k, framerate: .fps30, hyperlapse: .ratio15,
                bitrate: 0))
        assertThat(changeCnt, `is`(5))
        assertThat(camera!.recordingSettings, `is`(
            mode: .hyperlapse, resolution: .resUhd4k, framerate: .fps30, hyperlapse: .ratio15, updating: false))

        // change framerate in hyperlapse mode
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetRecordingMode(
            camId: 0, mode: .hyperlapse, resolution: .resUhd4k, framerate: .fps24, hyperlapse: .ratio15))
        camera?.recordingSettings.framerate = .fps24
        assertThat(changeCnt, `is`(6))
        assertThat(camera!.recordingSettings, `is`(
            mode: .hyperlapse, resolution: .resUhd4k, framerate: .fps24, hyperlapse: .ratio15, updating: true))
        assertNoExpectation()

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraRecordingModeEncoder(
                camId: 0, mode: .hyperlapse, resolution: .resUhd4k, framerate: .fps24, hyperlapse: .ratio15,
                bitrate: 0))
        assertThat(changeCnt, `is`(7))
        assertThat(camera!.recordingSettings, `is`(
            mode: .hyperlapse, resolution: .resUhd4k, framerate: .fps24, hyperlapse: .ratio15, updating: false))

        // Change hyperlapse value
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetRecordingMode(
            camId: 0, mode: .hyperlapse, resolution: .resUhd4k, framerate: .fps24, hyperlapse: .ratio60))
        camera?.recordingSettings.hyperlapseValue = .ratio60
        assertThat(changeCnt, `is`(8))
        assertThat(camera!.recordingSettings, `is`(
            mode: .hyperlapse, resolution: .resUhd4k, framerate: .fps24, hyperlapse: .ratio60, updating: true))
        assertNoExpectation()

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraRecordingModeEncoder(
                camId: 0, mode: .hyperlapse, resolution: .resUhd4k, framerate: .fps24, hyperlapse: .ratio60,
                bitrate: 0))
        assertThat(changeCnt, `is`(9))
        assertThat(camera!.recordingSettings, `is`(
            mode: .hyperlapse, resolution: .resUhd4k, framerate: .fps24, hyperlapse: .ratio60, updating: false))

        // Change mode to highFramerate, expect resolution and framerate to default value
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetRecordingMode(
            camId: 0, mode: .highFramerate, resolution: .res1080p, framerate: .fps60, hyperlapse: .ratio15))
        camera!.recordingSettings.mode = .highFramerate
        assertThat(changeCnt, `is`(10))
        assertThat(camera!.recordingSettings, `is`(
            mode: .highFramerate, resolution: .res1080p, framerate: .fps60, updating: true))
        assertNoExpectation()

        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraRecordingModeEncoder(
                camId: 0, mode: .highFramerate, resolution: .res1080p, framerate: .fps60, hyperlapse: .ratio60,
                bitrate: 0))
        assertThat(changeCnt, `is`(11))
        assertThat(camera!.recordingSettings, `is`(
            mode: .highFramerate, resolution: .res1080p, framerate: .fps60, updating: false))

        // change back to hyperlapse mode, expect previous resolution, fps and hyperlapse value of this mode
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetRecordingMode(
            camId: 0, mode: .hyperlapse, resolution: .resUhd4k, framerate: .fps24, hyperlapse: .ratio60))
        camera!.recordingSettings.mode = .hyperlapse
        assertThat(changeCnt, `is`(12))
        assertThat(camera!.recordingSettings, `is`(
            mode: .hyperlapse, resolution: .resUhd4k, framerate: .fps24, hyperlapse: .ratio60, updating: true))
        assertNoExpectation()

        // mock reception of a different resolution than what was expect
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraRecordingModeEncoder(
                camId: 0, mode: .hyperlapse, resolution: .resDci4k, framerate: .fps24, hyperlapse: .ratio60,
                bitrate: 0))
        assertThat(changeCnt, `is`(13))
        assertThat(camera!.recordingSettings, `is`(
            mode: .hyperlapse, resolution: .resDci4k, framerate: .fps24, hyperlapse: .ratio60, updating: false))

        // test bitrate
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraRecordingModeEncoder(
                camId: 0, mode: .hyperlapse, resolution: .resDci4k, framerate: .fps24, hyperlapse: .ratio60,
                bitrate: 10000))
        assertThat(changeCnt, `is`(14))
        assertThat(camera!.recordingSettings, `is`( bitrate: 10000, updating: false))

        // disconnect
        disconnect(drone: drone, handle: 1)

        assertThat(camera!.recordingSettings, `is`(
            mode: .hyperlapse, resolution: .resDci4k, framerate: .fps24, hyperlapse: .ratio60, bitrate: 0,
            updating: false))

        // restart engine
        resetArsdkEngine()
        changeCnt = 0

        // check stored capabilities
        assertThat(camera!.recordingSettings, supports(
            recordingModes: [.standard, .hyperlapse, .highFramerate],
            hyperlapseValues: [.ratio15, .ratio30, .ratio60]))
        assertThat(camera!.recordingSettings, `is`(
            mode: .hyperlapse, resolution: .resUhd4k, framerate: .fps24, hyperlapse: .ratio60, updating: false))
        assertThat(camera!.recordingSettings, `is`(
            hdrAvailable: true, forMode: .standard, resolution: .resUhd4k, framerate: .fps30))
        assertThat(camera!.recordingSettings, `is`(
            hdrAvailable: false, forMode: .highFramerate, resolution: .res720p, framerate: .fps30))
        assertNoExpectation()

        // change hyperlapse resolution offline
        camera?.recordingSettings.resolution = .resDci4k
        assertThat(changeCnt, `is`(1))
        assertThat(camera!.recordingSettings, `is`(
            mode: .hyperlapse, resolution: .resDci4k, framerate: .fps24, hyperlapse: .ratio60, updating: false))

        // change hyperlapse framerate offline
        camera?.recordingSettings.framerate = .fps25
        assertThat(changeCnt, `is`(2))
        assertThat(camera!.recordingSettings, `is`(
            mode: .hyperlapse, resolution: .resDci4k, framerate: .fps25, hyperlapse: .ratio60, updating: false))

        // change hyperlapse value offline
        camera?.recordingSettings.hyperlapseValue = .ratio30
        assertThat(changeCnt, `is`(3))
        assertThat(camera!.recordingSettings, `is`(
            mode: .hyperlapse, resolution: .resDci4k, framerate: .fps25, hyperlapse: .ratio30, updating: false))

        // change to highFramerate, expect previous stored resolution and fps
        camera!.recordingSettings.mode = .highFramerate
        assertThat(changeCnt, `is`(4))
        assertThat(camera!.recordingSettings, `is`(
            mode: .highFramerate, resolution: .res1080p, framerate: .fps60, updating: false))

        // reconnect
        connect(drone: drone, handle: 1) {
            // capabilities
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraRecordingModeEncoder(
                    camId: 0, mode: .standard, resolution: .res1080p, framerate: .fps24, hyperlapse: .ratio15,
                    bitrate: 0))

            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetRecordingMode(
                camId: 0, mode: .highFramerate, resolution: .res1080p, framerate: .fps60, hyperlapse: .ratio15))
        }

        // ensure settings are resored
        assertThat(camera!.recordingSettings, `is`(
            mode: .highFramerate, resolution: .res1080p, framerate: .fps60, updating: false))
    }

    func testAutoRecord() {
        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand(cameraModes: [.recording, .photo])
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraCameraModeEncoder(camId: 0, mode: .recording))
        }
        assertThat(changeCnt, `is`(1))

        // Check initial value
        assertThat(camera!.autoRecordSetting, `is`(nilValue()))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraAutorecordEncoder(camId: 0, state: .inactive))
        assertThat(changeCnt, `is`(2))
        assertThat(camera!.autoRecordSetting, presentAnd(allOf(`is`(false), isUpToDate())))

        // Change value
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetAutorecord(camId: 0, state: .active))
        camera!.autoRecordSetting?.value = true
        assertThat(changeCnt, `is`(3))
        assertThat(camera!.autoRecordSetting, presentAnd(allOf(`is`(true), isUpdating())))

        // mock reception of a different value
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraAutorecordEncoder(camId: 0, state: .inactive))
        assertThat(changeCnt, `is`(4))
        assertThat(camera!.autoRecordSetting, presentAnd(allOf(`is`(false), isUpToDate())))

        // disconnect
        disconnect(drone: drone, handle: 1)
        resetArsdkEngine()
        changeCnt = 0

        // check auto record still on
        assertThat(camera!.autoRecordSetting, presentAnd(allOf(`is`(true), isUpToDate())))

        // Change mode offline
        camera!.autoRecordSetting?.value = false
        assertThat(changeCnt, `is`(1))
        assertThat(camera!.autoRecordSetting, presentAnd(allOf(`is`(false), isUpToDate())))

        // reconnect
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraAutorecordEncoder(camId: 0, state: .active))
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetAutorecord(camId: 0, state: .inactive))
        }
        assertThat(camera!.autoRecordSetting, presentAnd(allOf(`is`(false), isUpToDate())))
    }

    func testPhotoMode() {
        connect(drone: drone, handle: 1) {
            // capabilities
            self.sendCapabilitiesCommand(
                bracketingPresets: [.preset1ev, .preset3ev, .preset1ev2ev],
                burstValues: [.burst14Over4s, .burst10Over2s, .burst4Over1s])
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraPhotoCapabilitiesEncoder(
                id: 0, photoModesBitField: Bitfield<ArsdkFeatureCameraPhotoMode>.of([.single, .bracketing, .timeLapse]),
                photoFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFormat>.of([.fullFrame]),
                photoFileFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFileFormat>.of([.dngJpeg, .jpeg]),
                hdr: .notSupported, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraPhotoCapabilitiesEncoder(
                id: 1, photoModesBitField: Bitfield<ArsdkFeatureCameraPhotoMode>.of([.single, .bracketing, .gpsLapse]),
                photoFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFormat>.of([.rectilinear]),
                photoFileFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFileFormat>.of([.jpeg]),
                hdr: .notSupported, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of()))
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraPhotoCapabilitiesEncoder(
                id: 2, photoModesBitField: Bitfield<ArsdkFeatureCameraPhotoMode>.of([.burst]),
                photoFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFormat>.of([.fullFrame, .rectilinear]),
                photoFileFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFileFormat>.of([.jpeg]),
                hdr: .supported, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))
            // current mode
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraCameraModeEncoder(camId: 0, mode: .photo))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraPhotoModeEncoder(
                    camId: 0, mode: .bracketing, format: .fullFrame, fileFormat: .dngJpeg, burst: .burst4Over1s,
                    bracketing: .preset3ev, captureInterval: 0.0))
        }

        assertThat(changeCnt, `is`(1))
        // Check capabilities
        assertThat(camera!.photoSettings, supports(
            photoModes: [.single, .bracketing, .burst, .timeLapse, .gpsLapse],
            burstValues: [.burst14Over4s, .burst10Over2s, .burst4Over1s],
            bracketingValues: [.preset1ev, .preset3ev, .preset1ev2ev]))
        assertThat(camera!.photoSettings, supports(forMode: .single, formats: [.fullFrame, .rectilinear]))
        assertThat(camera!.photoSettings, supports(forMode: .bracketing, formats: [.fullFrame, .rectilinear]))
        assertThat(camera!.photoSettings, supports(forMode: .burst, formats: [.fullFrame, .rectilinear]))

        assertThat(camera!.photoSettings, supports(forMode: .timeLapse, formats: [.fullFrame]))
        assertThat(camera!.photoSettings, supports(forMode: .gpsLapse, formats: [.rectilinear]))

        assertThat(camera!.photoSettings, supports(
            forMode: .single, format: .fullFrame, fileFormats: [.dngAndJpeg, .jpeg]))
        assertThat(camera!.photoSettings, supports(
            forMode: .single, format: .rectilinear, fileFormats: [.jpeg]))
        assertThat(camera!.photoSettings, supports(
            forMode: .bracketing, format: .fullFrame, fileFormats: [.dngAndJpeg, .jpeg]))
        assertThat(camera!.photoSettings, supports(
            forMode: .bracketing, format: .rectilinear, fileFormats: [.jpeg]))
        assertThat(camera!.photoSettings, supports(
            forMode: .burst, format: .fullFrame, fileFormats: [.jpeg]))
        assertThat(camera!.photoSettings, supports(
            forMode: .burst, format: .rectilinear, fileFormats: [.jpeg]))
        assertThat(camera!.photoSettings, supports(
            forMode: .timeLapse, format: .fullFrame, fileFormats: [.dngAndJpeg, .jpeg]))
        assertThat(camera!.photoSettings, supports(
            forMode: .gpsLapse, format: .rectilinear, fileFormats: [.jpeg]))

        assertThat(camera!.photoSettings, `is`(
            hdrAvailable: false, forMode: .single, format: .fullFrame, fileFormat: .jpeg))
        assertThat(camera!.photoSettings, `is`(
            hdrAvailable: true, forMode: .burst, format: .rectilinear, fileFormat: .jpeg))

        assertThat(camera!.photoSettings, `is`(
            hdrAvailable: false, forMode: .timeLapse, format: .fullFrame, fileFormat: .dngAndJpeg))
        assertThat(camera!.photoSettings, `is`(
            hdrAvailable: false, forMode: .gpsLapse, format: .rectilinear, fileFormat: .jpeg))

        // Check initial values
        assertThat(camera!.photoSettings, `is`(mode: .bracketing, format: .fullFrame, fileFormat: .dngAndJpeg,
                                               burst: .burst14Over4s, bracketing: .preset3ev))

        // Change to mode single, expect format and fileFormat default value
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .single, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over4s,
            bracketing: .preset1ev, captureInterval: 0.0))
        camera!.photoSettings.mode = .single
        assertThat(changeCnt, `is`(2))
        assertThat(camera!.photoSettings, `is`(mode: .single, format: .rectilinear, fileFormat: .jpeg,
                                               burst: .burst14Over4s, bracketing: .preset3ev, updating: true))
        assertNoExpectation()

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraPhotoModeEncoder(
                camId: 0, mode: .single, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over4s,
                bracketing: .preset2ev, captureInterval: 0.0))
        assertThat(changeCnt, `is`(3))
        assertThat(camera!.photoSettings, `is`(
            mode: .single, format: .rectilinear, fileFormat: .jpeg, updating: false))

        // change format
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .single, format: .fullFrame, fileFormat: .jpeg, burst: .burst14Over4s,
            bracketing: .preset1ev, captureInterval: 0.0))
        camera!.photoSettings.format = .fullFrame
        assertThat(changeCnt, `is`(4))
        assertThat(camera!.photoSettings, `is`(
            mode: .single, format: .fullFrame, fileFormat: .jpeg, burst: .burst14Over4s, bracketing: .preset3ev,
            updating: true))
        assertNoExpectation()

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraPhotoModeEncoder(
                camId: 0, mode: .single, format: .fullFrame, fileFormat: .jpeg, burst: .burst14Over4s,
                bracketing: .preset1ev, captureInterval: 0.0))
        assertThat(changeCnt, `is`(5))
        assertThat(camera!.photoSettings, `is`(
            mode: .single, format: .fullFrame, fileFormat: .jpeg, burst: .burst14Over4s, bracketing: .preset3ev,
            updating: false))

        // change fileformat
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .single, format: .fullFrame, fileFormat: .dngJpeg, burst: .burst14Over4s,
            bracketing: .preset1ev, captureInterval: 0.0))
        camera!.photoSettings.fileFormat = .dngAndJpeg
        assertThat(changeCnt, `is`(6))
        assertThat(camera!.photoSettings, `is`(
            mode: .single, format: .fullFrame, fileFormat: .dngAndJpeg, burst: .burst14Over4s, bracketing: .preset3ev,
            updating: true))
        assertNoExpectation()

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraPhotoModeEncoder(
                camId: 0, mode: .single, format: .fullFrame, fileFormat: .dngJpeg, burst: .burst4Over1s,
                bracketing: .preset3ev, captureInterval: 0.0))
        assertThat(changeCnt, `is`(7))
        assertThat(camera!.photoSettings, `is`(
            mode: .single, format: .fullFrame, fileFormat: .dngAndJpeg, burst: .burst14Over4s, bracketing: .preset3ev,
            updating: false))

        // change mode to bracketing, expect saved format and file format
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .bracketing, format: .fullFrame, fileFormat: .dngJpeg, burst: .burst14Over4s,
            bracketing: .preset3ev, captureInterval: 0.0))
        camera!.photoSettings.mode = .bracketing
        assertThat(changeCnt, `is`(8))
        assertThat(camera!.photoSettings, `is`(
            mode: .bracketing, format: .fullFrame, fileFormat: .dngAndJpeg, updating: true))
        assertNoExpectation()

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraPhotoModeEncoder(
                camId: 0, mode: .bracketing, format: .fullFrame, fileFormat: .dngJpeg, burst: .burst14Over4s,
                bracketing: .preset3ev, captureInterval: 0.0))
        assertThat(changeCnt, `is`(9))
        assertThat(camera!.photoSettings, `is`(
            mode: .bracketing, format: .fullFrame, fileFormat: .dngAndJpeg, updating: false))

        // change bracketing value
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .bracketing, format: .fullFrame, fileFormat: .dngJpeg, burst: .burst14Over4s,
            bracketing: .preset1ev2ev, captureInterval: 0.0))
        camera!.photoSettings.bracketingValue = .preset1ev2ev
        assertThat(changeCnt, `is`(10))
        assertThat(camera!.photoSettings, `is`(mode: .bracketing, bracketing: .preset1ev2ev, updating: true))
        assertNoExpectation()

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraPhotoModeEncoder(
                camId: 0, mode: .bracketing, format: .fullFrame, fileFormat: .dngJpeg, burst: .burst4Over1s,
                bracketing: .preset1ev2ev, captureInterval: 0.0))
        assertThat(changeCnt, `is`(11))
        assertThat(camera!.photoSettings, `is`(mode: .bracketing, bracketing: .preset1ev2ev, updating: false))

        // change mode to burst, expect default format and fileFormat
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .burst, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over4s,
            bracketing: .preset1ev, captureInterval: 0.0))
        camera!.photoSettings.mode = .burst
        assertThat(changeCnt, `is`(12))
        assertThat(camera!.photoSettings, `is`(
            mode: .burst, format: .rectilinear, fileFormat: .jpeg, updating: true))
        assertNoExpectation()

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraPhotoModeEncoder(
                camId: 0, mode: .burst, format: .rectilinear, fileFormat: .jpeg, burst: .burst4Over1s,
                bracketing: .preset1ev2ev, captureInterval: 0.0))
        assertThat(changeCnt, `is`(13))
        assertThat(camera!.photoSettings, `is`(
            mode: .burst, format: .rectilinear, fileFormat: .jpeg, updating: false))

        // change burst value
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .burst, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over4s,
            bracketing: .preset1ev, captureInterval: 0.0))
        camera!.photoSettings.burstValue = .burst14Over4s
        assertThat(changeCnt, `is`(14))
        assertThat(camera!.photoSettings, `is`(mode: .burst, burst: .burst14Over4s, updating: true))
        assertNoExpectation()

        // mock reception of a different format than what was expect
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraPhotoModeEncoder(
                camId: 0, mode: .burst, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over2s,
                bracketing: .preset1ev2ev, captureInterval: 0.0))
        assertThat(changeCnt, `is`(15))
        // since .burst14Over2s is not supported, fallback to the first supported burst value
        assertThat(camera!.photoSettings, `is`(mode: .burst, burst: .burst14Over4s, updating: false))

        // change mode to timelapse
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .timeLapse, format: .fullFrame, fileFormat: .jpeg, burst: .burst14Over4s,
            bracketing: .preset1ev, captureInterval: 0.0))
        camera!.photoSettings.mode = .timeLapse
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraPhotoModeEncoder(
                camId: 0, mode: .timeLapse, format: .fullFrame, fileFormat: .jpeg, burst: .burst14Over2s,
                bracketing: .preset1ev2ev, captureInterval: 0.0))

        // change mode to gpsLapse
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .gpsLapse, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over4s,
            bracketing: .preset1ev, captureInterval: 0.0))
        camera!.photoSettings.mode = .gpsLapse
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraPhotoModeEncoder(
                camId: 0, mode: .gpsLapse, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over2s,
                bracketing: .preset1ev2ev, captureInterval: 0.0))

        // disconnect
        disconnect(drone: drone, handle: 1)

        assertThat(camera!.photoSettings, `is`(
            mode: .gpsLapse, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over4s, updating: false))

        // restart engine
        resetArsdkEngine()
        changeCnt = 0

        // check stored capabilities
        assertThat(camera!.photoSettings, supports(
            photoModes: [.single, .bracketing, .burst, .timeLapse, .gpsLapse],
            burstValues: [.burst14Over4s, .burst10Over2s, .burst4Over1s],
            bracketingValues: [.preset1ev, .preset3ev, .preset1ev2ev]))
        assertThat(camera!.photoSettings, supports(forMode: .single, formats: [.fullFrame, .rectilinear]))
        assertThat(camera!.photoSettings, supports(forMode: .bracketing, formats: [.fullFrame, .rectilinear]))
        assertThat(camera!.photoSettings, supports(forMode: .burst, formats: [.fullFrame, .rectilinear]))
        assertThat(camera!.photoSettings, `is`(
            hdrAvailable: false, forMode: .single, format: .fullFrame, fileFormat: .jpeg))
        assertThat(camera!.photoSettings, `is`(
            hdrAvailable: true, forMode: .burst, format: .rectilinear, fileFormat: .jpeg))

        // check current photo mode
        assertThat(camera!.photoSettings, `is`(
            mode: .gpsLapse, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over4s, updating: false))

        // change to mode to single offline, expect previous format and file format for this mode
        camera!.photoSettings.mode = .single
        assertThat(changeCnt, `is`(1))
        assertThat(camera!.photoSettings, `is`(
            mode: .single, format: .fullFrame, fileFormat: .dngAndJpeg, updating: false))

        // change format offline, file format must also change
        camera!.photoSettings.format = .rectilinear
        assertThat(changeCnt, `is`(2))
        assertThat(camera!.photoSettings, `is`(
            mode: .single, format: .rectilinear, fileFormat: .jpeg, updating: false))

        // reconnect
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraPhotoModeEncoder(
                    camId: 0, mode: .bracketing, format: .fullFrame, fileFormat: .dngJpeg, burst: .burst4Over1s,
                    bracketing: .preset3ev, captureInterval: 0.0))
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
                camId: 0, mode: .single, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over4s,
                bracketing: .preset1ev, captureInterval: 0.0))
        }

        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraPhotoModeEncoder(
                camId: 0, mode: .single, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over4s,
                bracketing: .preset1ev, captureInterval: 0.0))

        // expect single mode
        assertThat(camera!.photoSettings, `is`(
            mode: .single, format: .rectilinear, fileFormat: .jpeg, updating: false))
    }

    // This test is here to be sure that the photo mode reacts correctly during corner cases, such as when the drone
    // sends incorrect values
    func testPhotoModeCornerCases() {
        connect(drone: drone, handle: 1) {
            // capabilities
            self.sendCapabilitiesCommand(
                bracketingPresets: [.preset2ev, .preset3ev, .preset1ev2ev],
                burstValues: [.burst14Over1s, .burst10Over2s, .burst4Over1s])
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraPhotoCapabilitiesEncoder(
                id: 0, photoModesBitField: Bitfield<ArsdkFeatureCameraPhotoMode>.of([.single, .bracketing]),
                photoFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFormat>.of([.fullFrame]),
                photoFileFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFileFormat>.of([.dngJpeg, .jpeg]),
                hdr: .notSupported, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraPhotoCapabilitiesEncoder(
                id: 1, photoModesBitField: Bitfield<ArsdkFeatureCameraPhotoMode>.of([.single, .bracketing]),
                photoFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFormat>.of([.rectilinear]),
                photoFileFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFileFormat>.of([.jpeg]),
                hdr: .notSupported, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of()))
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraPhotoCapabilitiesEncoder(
                id: 2, photoModesBitField: Bitfield<ArsdkFeatureCameraPhotoMode>.of([.burst]),
                photoFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFormat>.of([.fullFrame, .rectilinear]),
                photoFileFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFileFormat>.of([.jpeg]),
                hdr: .supported, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))
            // current mode
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraCameraModeEncoder(camId: 0, mode: .photo))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraPhotoModeEncoder(
                    camId: 0, mode: .single, format: .fullFrame, fileFormat: .dngJpeg, burst: .burst4Over1s,
                    bracketing: .preset3ev, captureInterval: 0.0))
        }

        assertThat(changeCnt, `is`(1))
        // Check capabilities
        assertThat(camera!.photoSettings, supports(
            photoModes: [.single, .bracketing, .burst],
            burstValues: [.burst14Over1s, .burst10Over2s, .burst4Over1s],
            bracketingValues: [.preset2ev, .preset3ev, .preset1ev2ev]))
        assertThat(camera!.photoSettings, supports(forMode: .single, formats: [.fullFrame, .rectilinear]))
        assertThat(camera!.photoSettings, supports(forMode: .bracketing, formats: [.fullFrame, .rectilinear]))
        assertThat(camera!.photoSettings, supports(forMode: .burst, formats: [.fullFrame, .rectilinear]))

        assertThat(camera!.photoSettings, supports(
            forMode: .single, format: .fullFrame, fileFormats: [.dngAndJpeg, .jpeg]))
        assertThat(camera!.photoSettings, supports(
            forMode: .single, format: .rectilinear, fileFormats: [.jpeg]))
        assertThat(camera!.photoSettings, supports(
            forMode: .bracketing, format: .fullFrame, fileFormats: [.dngAndJpeg, .jpeg]))
        assertThat(camera!.photoSettings, supports(
            forMode: .bracketing, format: .rectilinear, fileFormats: [.jpeg]))
        assertThat(camera!.photoSettings, supports(
            forMode: .burst, format: .fullFrame, fileFormats: [.jpeg]))
        assertThat(camera!.photoSettings, supports(
            forMode: .burst, format: .rectilinear, fileFormats: [.jpeg]))

        assertThat(camera!.photoSettings, `is`(
            hdrAvailable: false, forMode: .single, format: .fullFrame, fileFormat: .jpeg))
        assertThat(camera!.photoSettings, `is`(
            hdrAvailable: true, forMode: .burst, format: .rectilinear, fileFormat: .jpeg))

        // Check initial values (burst and bracketing should be defaulted to the first value supported
        assertThat(camera!.photoSettings, `is`(
            mode: .single, format: .fullFrame, fileFormat: .dngAndJpeg, burst: .burst14Over1s,
            bracketing: .preset2ev))

        // switch to burst mode. Should use the burst value of the api
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .burst, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over1s,
            bracketing: .preset1ev, captureInterval: 0.0))
        camera!.photoSettings.mode = .burst
        assertThat(changeCnt, `is`(2))
        assertThat(camera!.photoSettings, `is`(
            mode: .burst, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over1s,
            bracketing: .preset2ev, updating: true))

        // switch to single mode. Should use the burst value of the api
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .single, format: .fullFrame, fileFormat: .dngJpeg, burst: .burst14Over4s,
            bracketing: .preset1ev, captureInterval: 0.0))
        camera!.photoSettings.mode = .single
        assertThat(changeCnt, `is`(3))
        assertThat(camera!.photoSettings, `is`(
            mode: .single, format: .fullFrame, fileFormat: .dngAndJpeg, burst: .burst14Over1s,
            bracketing: .preset2ev, updating: true))

        // Change burst value while not in burst mode (should not send any command,
        // API should be changed and not updating)
        camera!.photoSettings.burstValue = .burst10Over2s
        assertThat(changeCnt, `is`(4))
        assertThat(camera!.photoSettings, `is`(
            mode: .single, format: .fullFrame, fileFormat: .dngAndJpeg, burst: .burst10Over2s,
            bracketing: .preset2ev, updating: false))
        assertNoExpectation()

        // select an unsupported burst value
        camera!.photoSettings.burstValue = .burst10Over4s
        assertThat(changeCnt, `is`(4))
        assertThat(camera!.photoSettings, `is`(
            mode: .single, format: .fullFrame, fileFormat: .dngAndJpeg, burst: .burst10Over2s,
            bracketing: .preset2ev, updating: false))

        // switch to burst mode. Should use the burst value previously set
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .burst, format: .rectilinear, fileFormat: .jpeg, burst: .burst10Over2s,
            bracketing: .preset1ev, captureInterval: 0.0))
        camera!.photoSettings.mode = .burst
        assertThat(changeCnt, `is`(5))
        assertThat(camera!.photoSettings, `is`(
            mode: .burst, format: .rectilinear, fileFormat: .jpeg, burst: .burst10Over2s,
            bracketing: .preset2ev, updating: true))

        // check that if the drone send back an invalid burst mode, we publish something valid
        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraPhotoModeEncoder(
                camId: 0, mode: .burst, format: .rectilinear, fileFormat: .jpeg, burst: .burst10Over4s,
                bracketing: .preset3ev, captureInterval: 0.0))
        assertThat(changeCnt, `is`(6))
        assertThat(camera!.photoSettings, `is`(
            mode: .burst, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over1s,
            bracketing: .preset2ev, updating: false))

        // Change burst value while in burst mode
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .burst, format: .rectilinear, fileFormat: .jpeg, burst: .burst10Over2s,
            bracketing: .preset1ev, captureInterval: 0.0))
        camera!.photoSettings.burstValue = .burst10Over2s
        assertThat(changeCnt, `is`(7))
        assertThat(camera!.photoSettings, `is`(
            mode: .burst, format: .rectilinear, fileFormat: .jpeg, burst: .burst10Over2s,
            bracketing: .preset2ev, updating: true))

        // Change bracketing value while not in bracketing mode (should not send any command,
        // API should be changed and not updating)
        camera!.photoSettings.bracketingValue = .preset3ev
        assertThat(changeCnt, `is`(8))
        assertThat(camera!.photoSettings, `is`(
            mode: .burst, format: .rectilinear, fileFormat: .jpeg, burst: .burst10Over2s,
            bracketing: .preset3ev, updating: false))
        assertNoExpectation()

        // select an unsupported burst value
        camera!.photoSettings.bracketingValue = .preset1ev2ev3ev
        assertThat(changeCnt, `is`(8))
        assertThat(camera!.photoSettings, `is`(
            mode: .burst, format: .rectilinear, fileFormat: .jpeg, burst: .burst10Over2s,
            bracketing: .preset3ev, updating: false))

        // switch to bracketing mode. Should use the bracketing value previously set
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .bracketing, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over4s,
            bracketing: .preset3ev, captureInterval: 0.0))
        camera!.photoSettings.mode = .bracketing
        assertThat(changeCnt, `is`(9))
        assertThat(camera!.photoSettings, `is`(
            mode: .bracketing, format: .rectilinear, fileFormat: .jpeg, burst: .burst10Over2s,
            bracketing: .preset3ev, updating: true))

        // check that if the drone send back an invalid bracketing mode, we publish something valid
        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraPhotoModeEncoder(
                camId: 0, mode: .bracketing, format: .rectilinear, fileFormat: .jpeg, burst: .burst10Over4s,
                bracketing: .preset1ev2ev3ev, captureInterval: 0.0))
        assertThat(changeCnt, `is`(10))
        assertThat(camera!.photoSettings, `is`(
            mode: .bracketing, format: .rectilinear, fileFormat: .jpeg, burst: .burst10Over2s,
            bracketing: .preset2ev, updating: false))
    }

    func testHdr() {
        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand()
        }
        // Check initial values
        assertThat(changeCnt, `is`(1))
        assertThat(camera!.hdrState, `is`(false))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraHdrEncoder(
            camId: 0, available: .notAvailable, state: .active))

        assertThat(changeCnt, `is`(2))
        assertThat(camera!.hdrState, `is`(true))
    }

    func testZoom() {
        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand()
        }

        // Check initial values
        assertThat(changeCnt, `is`(1))
        assertThat(camera?.zoom, nilValue())

        // check reception of event zoom info does update the api
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraZoomInfoEncoder(
                camId: 0, available: .available, highQualityMaximumLevel: 2.0, maximumLevel: 3.0))

        assertThat(changeCnt, `is`(2))
        assertThat(camera!.zoom, presentAnd(`is`(
            available: true, currentLevel: 1.0, maxLossLessLevel: 2.0,
            maxLossyLevel: 3.0)))
        assertThat(camera!.zoom?.velocityQualityDegradationAllowance, presentAnd(`is`(false)))
        assertThat(camera?.zoom?.maxSpeed, presentAnd(`is`(0.0, 0.0, 0.0)))

        // check reception of event zoom level does update the api
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraZoomLevelEncoder(camId: 0, level: 1.5))

        assertThat(changeCnt, `is`(3))
        assertThat(camera!.zoom, presentAnd(`is`(
            available: true, currentLevel: 1.5, maxLossLessLevel: 2.0,
            maxLossyLevel: 3.0)))

        // set the quality degradation setting
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetZoomVelocityQualityDegradation(camId: 0, allow: 1))
        camera?.zoom?.velocityQualityDegradationAllowance.value = true

        assertThat(changeCnt, `is`(4))
        assertThat(camera!.zoom?.velocityQualityDegradationAllowance, presentAnd(allOf(`is`(true), isUpdating())))

        // mock answer
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraZoomVelocityQualityDegradationEncoder(camId: 0, allowed: 1))

        assertThat(changeCnt, `is`(5))
        assertThat(camera!.zoom?.velocityQualityDegradationAllowance, presentAnd(allOf(`is`(true), isUpToDate())))

        // receive max zoom velocity bounds
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraMaxZoomSpeedEncoder(camId: 0, min: 0.5, max: 20.0, current: 10.0))

        assertThat(changeCnt, `is`(6))
        assertThat(camera!.zoom?.maxSpeed, presentAnd(allOf(`is`(0.5, 10.0, 20.0), isUpToDate())))

        // set the maxZoomSpeed
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetMaxZoomSpeed(camId: 0, max: 20.0))
        camera!.zoom?.maxSpeed.value = 30.0

        assertThat(changeCnt, `is`(7))
        assertThat(camera!.zoom?.maxSpeed, presentAnd(allOf(`is`(0.5, 20.0, 20.0), isUpdating())))

        // mock answer with a different value than the one asked
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraMaxZoomSpeedEncoder(camId: 0, min: 0.5, max: 20.0, current: 15.0))

        assertThat(changeCnt, `is`(8))
        assertThat(camera!.zoom?.maxSpeed, presentAnd(allOf(`is`(0.5, 15.0, 20.0), isUpToDate())))

        // disconnect
        disconnect(drone: drone, handle: 1)

        // check that offline settings are kept and other information are cleared
        assertThat(camera!.zoom, presentAnd(`is`(
            available: false, currentLevel: 1.0, maxLossLessLevel: 1.0,
            maxLossyLevel: 1.0)))
        assertThat(camera!.zoom?.velocityQualityDegradationAllowance, presentAnd(`is`(true)))
        assertThat(camera?.zoom?.maxSpeed, presentAnd(`is`(0.5, 15.0, 20.0)))

        // restart engine
        resetArsdkEngine()
        changeCnt = 0

        assertThat(camera!.zoom, presentAnd(`is`(
            available: false, currentLevel: 1.0, maxLossLessLevel: 1.0,
            maxLossyLevel: 1.0)))
        assertThat(camera!.zoom?.velocityQualityDegradationAllowance, presentAnd(`is`(true)))
        assertThat(camera?.zoom?.maxSpeed, presentAnd(`is`(0.5, 20.0, 20.0)))

        // change max zoom velocity
        camera!.zoom?.maxSpeed.value = 1.0
        assertThat(camera!.zoom?.maxSpeed, presentAnd(allOf(`is`(0.5, 1.0, 20.0), isUpToDate())))
        assertThat(changeCnt, `is`(1))

        // change quality degradation
        camera!.zoom?.velocityQualityDegradationAllowance.value = false
        assertThat(camera!.zoom?.velocityQualityDegradationAllowance, presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(changeCnt, `is`(2))

        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand()
            // also modify bounds to check that new bounds are applied even if old value is kept
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraMaxZoomSpeedEncoder(camId: 0, min: 1.0, max: 25.0, current: 15.0))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraZoomVelocityQualityDegradationEncoder(camId: 0, allowed: 1))

            self.expectCommands(handle: 1, expectedCmds: [
                ExpectedCmd.cameraSetMaxZoomSpeed(camId: 0, max: 1.0),
                ExpectedCmd.cameraSetZoomVelocityQualityDegradation(camId: 0, allow: 0)])
        }
        assertThat(camera!.zoom, presentAnd(`is`(
            available: false, currentLevel: 1.0, maxLossLessLevel: 1.0,
            maxLossyLevel: 1.0)))
        assertThat(camera!.zoom?.velocityQualityDegradationAllowance, presentAnd(`is`(false)))
        assertThat(camera?.zoom?.maxSpeed, presentAnd(`is`(1.0, 1.0, 25.0)))
        assertThat(changeCnt, `is`(5))

        // mock zoom available
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraZoomInfoEncoder(
                camId: 0, available: .available, highQualityMaximumLevel: 2.0, maximumLevel: 3.0))

        assertThat(camera!.zoom, presentAnd(`is`(
            available: true, currentLevel: 1.0, maxLossLessLevel: 2.0,
            maxLossyLevel: 3.0)))
        assertThat(changeCnt, `is`(6))

        // check zoom control
        camera!.zoom?.control(mode: .level, target: 4.0)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetZoomTarget(
            camId: 0, controlMode: .level, target: 3.0))
        mockNonAckLoop(handle: 1, noAckType: .cameraZoom)

        camera!.zoom?.control(mode: .velocity, target: -2.0)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetZoomTarget(
            camId: 0, controlMode: .velocity, target: -1.0))
        mockNonAckLoop(handle: 1, noAckType: .cameraZoom)

        // mock zoom not available: current zoom bounds should be kept at their current values
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraZoomInfoEncoder(
                camId: 0, available: .notAvailable, highQualityMaximumLevel: 9.0, maximumLevel: 10.0))
        assertThat(camera!.zoom, presentAnd(`is`(
            available: false, currentLevel: 1.0, maxLossLessLevel: 2.0, maxLossyLevel: 3.0)))
        assertThat(changeCnt, `is`(7))

        // mock zoom available with bounds < 1.0: event should be skipped
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraZoomInfoEncoder(
                camId: 0, available: .available, highQualityMaximumLevel: 0.0, maximumLevel: 10.0))
        assertThat(camera!.zoom, presentAnd(`is`(
            available: false, currentLevel: 1.0, maxLossLessLevel: 2.0, maxLossyLevel: 3.0)))
        assertThat(changeCnt, `is`(7))
    }

    func testZoomControlSendingTimes() {
        let maxRepeatedSent = 10 // should be the same as GimbalControlCommandEncoder.maxRepeatedSent

        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand()
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraZoomInfoEncoder(
                camId: 0, available: .available, highQualityMaximumLevel: 2.0, maximumLevel: 3.0))
        }

        // control the zoom
        camera!.zoom?.control(mode: .level, target: 1.5)

        for _ in 0..<maxRepeatedSent {
            expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetZoomTarget(
                camId: 0, controlMode: .level, target: 1.5))
            mockNonAckLoop(handle: 1, noAckType: .cameraZoom)
        }

        // check that 0 velocity is sent only 10 times
        camera!.zoom?.control(mode: .velocity, target: 0.0)

        for _ in 0..<maxRepeatedSent {
            expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetZoomTarget(
                camId: 0, controlMode: .velocity, target: 0.0))
            mockNonAckLoop(handle: 1, noAckType: .cameraZoom)
        }

        // check that not 0 velocity is sent infinitely
        camera!.zoom?.control(mode: .velocity, target: 1.0)

        for _ in 0..<maxRepeatedSent + 1 {
            expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetZoomTarget(
                camId: 0, controlMode: .velocity, target: 1.0))
            mockNonAckLoop(handle: 1, noAckType: .cameraZoom)
        }
    }

    func testStartStopRecording() {
        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand()
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraCameraModeEncoder(camId: 0, mode: .recording))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraRecordingStateEncoder(
                    camId: 0, available: .notAvailable, state: .inactive, startTimestamp: 0))
        }
        assertThat(changeCnt, `is`(1))
        // Check initial values
        assertThat(camera!.recordingState, `is`(recordingFunctionState: .unavailable))

        // move to available
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraRecordingStateEncoder(
                camId: 0, available: .available, state: .inactive, startTimestamp: 0))
        assertThat(changeCnt, `is`(2))
        assertThat(camera!.recordingState, `is`(recordingFunctionState: .stopped))

        // start recording
        expectCommand(
            handle: 1, expectedCmd: ExpectedCmd.cameraStartRecording(camId: 0))
        camera?.startRecording()
        assertThat(changeCnt, `is`(3))
        assertThat(camera!.recordingState, `is`(recordingFunctionState: .starting))

        let startTimestamp = UInt64(Date().timeIntervalSince1970*1000)
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraRecordingStateEncoder(
                camId: 0, available: .available, state: .active, startTimestamp: startTimestamp))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraRecordingProgressEncoder(camId: 0, result: .started, mediaId: ""))
        assertThat(changeCnt, `is`(4))
        assertThat(camera!.recordingState, `is`(
            recordingFunctionState: .started, startTime:
            Date(timeIntervalSince1970: TimeInterval(startTimestamp)/1000)))

        // stop recording
        expectCommand(
            handle: 1, expectedCmd: ExpectedCmd.cameraStopRecording(camId: 0))
        camera?.stopRecording()
        assertThat(changeCnt, `is`(5))
        assertThat(camera!.recordingState, `is`(recordingFunctionState: .stopping))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraRecordingProgressEncoder(camId: 0, result: .stopped, mediaId: "M123"))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraRecordingStateEncoder(
                camId: 0, available: .available, state: .inactive, startTimestamp: 0))
        assertThat(changeCnt, `is`(6))
        assertThat(camera!.recordingState, `is`(recordingFunctionState: .stopped, mediaId: "M123"))

        // test memory full error
        expectCommand(
            handle: 1, expectedCmd: ExpectedCmd.cameraStartRecording(camId: 0))
        camera?.startRecording()
        assertThat(changeCnt, `is`(7))
        assertThat(camera!.recordingState, `is`(recordingFunctionState: .starting))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraRecordingStateEncoder(
                camId: 0, available: .available, state: .active, startTimestamp: startTimestamp))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraRecordingProgressEncoder(camId: 0, result: .started, mediaId: ""))
        assertThat(changeCnt, `is`(8))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraRecordingProgressEncoder(
                camId: 0, result: .stoppedNoStorageSpace, mediaId: ""))
        assertThat(changeCnt, `is`(9))
        assertThat(camera!.recordingState, `is`(recordingFunctionState: .errorInsufficientStorageSpace))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraRecordingStateEncoder(
                camId: 0, available: .available, state: .inactive, startTimestamp: startTimestamp))
        assertThat(changeCnt, `is`(10))
        assertThat(camera!.recordingState, `is`(recordingFunctionState: .stopped))

        // test Stopped for reconfiguration
        expectCommand(
            handle: 1, expectedCmd: ExpectedCmd.cameraStartRecording(camId: 0))
        camera?.startRecording()
        assertThat(changeCnt, `is`(11))
        assertThat(camera!.recordingState, `is`(recordingFunctionState: .starting))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraRecordingStateEncoder(
                camId: 0, available: .available, state: .active, startTimestamp: startTimestamp))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraRecordingProgressEncoder(camId: 0, result: .started, mediaId: ""))
        assertThat(changeCnt, `is`(12))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraRecordingProgressEncoder(
                camId: 0, result: .stoppedReconfigured, mediaId: ""))
        assertThat(changeCnt, `is`(13))
        assertThat(camera!.recordingState, `is`(recordingFunctionState: .stoppedForReconfiguration))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraRecordingStateEncoder(
                camId: 0, available: .available, state: .inactive, startTimestamp: startTimestamp))
        assertThat(changeCnt, `is`(14))
        assertThat(camera!.recordingState, `is`(recordingFunctionState: .stopped))

        // disconnect
        disconnect(drone: drone, handle: 1)
        assertThat(changeCnt, `is`(15))
        assertThat(camera!.recordingState, `is`(recordingFunctionState: .unavailable))
    }

    func testTakePhoto() {
        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand()
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraCameraModeEncoder(camId: 0, mode: .photo))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraPhotoStateEncoder(camId: 0, available: .notAvailable, state: .inactive))
        }
        assertThat(changeCnt, `is`(1))

        // Check initial values
        assertThat(camera!.photoState, `is`(photoFunctionState: .unavailable))

        // move to available
        mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraPhotoStateEncoder(camId: 0, available: .available, state: .inactive))
        assertThat(changeCnt, `is`(2))
        assertThat(camera!.photoState, `is`(photoFunctionState: .stopped))

        // take picture
        expectCommand(
            handle: 1, expectedCmd: ExpectedCmd.cameraTakePhoto(camId: 0))
        camera?.startPhotoCapture()
        assertThat(changeCnt, `is`(3))
        // should immediately be in takingPhotos
        assertThat(camera!.photoState, `is`(photoFunctionState: .started))
        assertNoExpectation()

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraPhotoStateEncoder(
            camId: 0, available: .available, state: .active))
        assertThat(camera!.photoState, `is`(photoFunctionState: .started))
        assertThat(changeCnt, `is`(3))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraPhotoProgressEncoder(
            camId: 0, result: .takingPhoto, photoCount: 0, mediaId: ""))
        assertThat(camera!.photoState, `is`(photoFunctionState: .started))
        assertThat(changeCnt, `is`(3))

        // photo taken with photo count
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraPhotoProgressEncoder(
            camId: 0, result: .photoTaken, photoCount: 1, mediaId: ""))
        assertThat(camera!.photoState, `is`(photoFunctionState: .started, photoCount: 1))
        assertThat(changeCnt, `is`(4))

        // photo saved with photo media id, state should be ready
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraPhotoProgressEncoder(
            camId: 0, result: .photoSaved, photoCount: 0, mediaId: "M123"))
        assertThat(camera!.photoState, `is`(photoFunctionState: .stopped, photoCount: 0, mediaId: "M123"))
        assertThat(changeCnt, `is`(5))

        // test memory full error
        expectCommand(
            handle: 1, expectedCmd: ExpectedCmd.cameraTakePhoto(camId: 0))
        camera?.startPhotoCapture()
        assertThat(changeCnt, `is`(6))
        // should immediately be in takingPhotos
        assertThat(camera!.photoState, `is`(photoFunctionState: .started))
        assertNoExpectation()

        changeAssertClosure = { camera in
            assertThat(camera!.photoState, `is`(photoFunctionState: .errorInsufficientStorageSpace))
            self.changeAssertClosure = nil
        }
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraPhotoProgressEncoder(
            camId: 0, result: .errorNoStorageSpace, photoCount: 0, mediaId: ""))
        assertThat(camera!.photoState, `is`(photoFunctionState: .errorInsufficientStorageSpace))
        assertThat(changeCnt, `is`(7))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraPhotoStateEncoder(
            camId: 0, available: .available, state: .inactive))
        assertThat(camera!.photoState, `is`(photoFunctionState: .stopped))
        assertThat(changeCnt, `is`(8))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraPhotoStateEncoder(
            camId: 0, available: .notAvailable, state: .inactive))
        // unavailable
        assertThat(changeCnt, `is`(9))
        assertThat(camera!.photoState, `is`(photoFunctionState: .unavailable, photoCount: 0))
        assertThat(camera!.photoState.mediaId, `is`(nilValue()))

        // disconnect when available
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraPhotoStateEncoder(
            camId: 0, available: .available, state: .inactive))
        assertThat(changeCnt, `is`(10))
        disconnect(drone: drone, handle: 1)
        assertThat(changeCnt, `is`(11))
        assertThat(camera!.photoState, `is`(photoFunctionState: .unavailable, photoCount: 0))
        assertThat(camera!.photoState.mediaId, `is`(nilValue()))
    }

    func testResetOnDisconnect() {
        // tests that all values are reset properly and rollbacks are canceled upon disconnection

        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand(
                exposureModes: [.automatic, .automaticPreferIsoSensitivity, .automaticPreferShutterSpeed, .manual],
                exposureLockSupported: .supported,
                exposureRoiLockSupported: .supported,
                evCompensations: [.ev0_00, .ev0_33],
                whiteBalanceModes: [.candle, .blueSky],
                customWhiteBalanceTemperatures: [.T10000, .T1500],
                whiteBalanceLockSupported: .supported,
                styles: [.standard, .plog],
                cameraModes: [.photo, .recording],
                hyperlapseValues: [.ratio120, .ratio15],
                bracketingPresets: [.preset1ev, .preset3ev],
                burstValues: [.burst10Over1s])
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraCameraModeEncoder(camId: 0, mode: .recording))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraExposureSettingsEncoder(
                    camId: 0, mode: .automatic,
                    manualShutterSpeed: .shutter1, manualShutterSpeedCapabilitiesBitField: UInt64.max,
                    manualIsoSensitivity: .iso50, manualIsoSensitivityCapabilitiesBitField: UInt64.max,
                    maxIsoSensitivity: .iso160, maxIsoSensitivitiesCapabilitiesBitField: UInt64.max,
                    meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraEvCompensationEncoder(camId: 0, value: .ev0_00))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraWhiteBalanceEncoder(
                    camId: 0, mode: .sunny, temperature: .T1500, lock: .inactive))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraHdrSettingEncoder(camId: 0, value: .active))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraStyleEncoder(
                    camId: 0, style: .standard, saturation: 1, saturationMin: 0, saturationMax: 1, contrast: 1,
                    contrastMin: 0, contrastMax: 1, sharpness: 1, sharpnessMin: 0, sharpnessMax: 1))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraPhotoCapabilitiesEncoder(
                    id: 0, photoModesBitField: UInt.max, photoFormatsBitField: UInt.max,
                    photoFileFormatsBitField: UInt.max, hdr: .supported,
                    listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last)))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraPhotoModeEncoder(
                    camId: 0, mode: .single, format: .rectilinear, fileFormat: .jpeg, burst: .burst10Over1s,
                    bracketing: .preset1ev, captureInterval: 0.0))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraRecordingCapabilitiesEncoder(
                    id: 0, recordingModesBitField: UInt.max, resolutionsBitField: UInt.max,
                    frameratesBitField: UInt.max, hdr: .supported,
                    listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first, .last)))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraRecordingModeEncoder(
                    camId: 0, mode: .standard, resolution: .resDci4k, framerate: .fps120, hyperlapse: .ratio15,
                    bitrate: 100000))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraAutorecordEncoder(camId: 0, state: .active))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraMaxZoomSpeedEncoder(camId: 0, min: 0, max: 15, current: 10))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraZoomVelocityQualityDegradationEncoder(camId: 0, allowed: 0))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraZoomInfoEncoder(
                    camId: 0, available: .available, highQualityMaximumLevel: 10.0, maximumLevel: 15.0))
        }

        assertThat(changeCnt, `is`(1))
        assertThat(camera!.modeSetting, supports(modes: [.photo, .recording]))
        assertThat(camera!.modeSetting, `is`(mode: .recording, updating: false))

        assertThat(camera!.exposureSettings, supports(
            exposureModes: [.automatic, .automaticPreferIsoSensitivity, .automaticPreferShutterSpeed, .manual],
            shutterSpeeds: CameraShutterSpeed.allCases,
            isoSensitivities: CameraIso.allCases, maximumIsoSensitivities: CameraIso.allCases))
        assertThat(camera!.exposureSettings,
                   `is`(mode: .automatic, shutterSpeed: .one, isoSensitivity: .iso50,
                        maximumIsoSensitivity: .iso160, updating: false))

        assertThat(camera!.exposureCompensationSetting, supports(exposureCompensationValues: [.ev0_00, .ev0_33]))
        assertThat(camera!.exposureCompensationSetting, `is`(value: .ev0_00, updating: false))

        assertThat(camera!.whiteBalanceSettings, supports(
            whiteBalanceModes: [.candle, .blueSky],
            customTemperatures: [.k10000, .k1500]))
        assertThat(camera!.whiteBalanceSettings, `is`(mode: .sunny, customTemperature: .k1500, updating: false))

        assertThat(camera!.hdrSetting, presentAnd(allOf(`is`(true), isUpToDate())))

        assertThat(camera!.styleSettings, supports(styles: [.standard, .plog]))
        assertThat(camera!.styleSettings, `is`(
            activeStyle: .standard, saturation: (0, 1, 1), contrast: (0, 1, 1), sharpness: (0, 1, 1)))

        assertThat(camera!.photoSettings, supports(
            photoModes: [.single, .bracketing, .burst, .timeLapse, .gpsLapse],
            burstValues: [.burst10Over1s],
            bracketingValues: [.preset1ev, .preset3ev]))
        assertThat(camera!.photoSettings, `is`(mode: .single, format: .rectilinear, fileFormat: .jpeg))

        assertThat(camera!.recordingSettings, supports(
            recordingModes: CameraRecordingMode.allCases, hyperlapseValues: [.ratio120, .ratio15]))
        assertThat(camera!.recordingSettings, `is`(
            mode: .standard, resolution: .resDci4k, framerate: .fps120, hyperlapse: .ratio15))

        assertThat(camera!.autoRecordSetting, presentAnd(allOf(`is`(true), isUpToDate())))

        assertThat(camera!.zoom, presentAnd(`is`(
            available: true, currentLevel: 1.0, maxLossLessLevel: 10.0,
            maxLossyLevel: 15.0)))
        assertThat(camera!.zoom?.velocityQualityDegradationAllowance, presentAnd(`is`(false)))
        assertThat(camera?.zoom?.maxSpeed, presentAnd(`is`(0.0, 10.0, 15.0)))

        // mock user modifies settings
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetCameraMode(camId: 0, value: .photo))
        camera!.modeSetting.mode = .photo
        assertThat(camera!.modeSetting, `is`(mode: .photo, updating: true))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetExposureSettings(
            camId: 0, mode: .manual, shutterSpeed: .shutter1Over10, isoSensitivity: .iso100,
            maxIsoSensitivity: .iso1200, meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))
        camera!.exposureSettings.set(mode: .manual, manualShutterSpeed: .oneOver10,
                                     manualIsoSensitivity: .iso100,
                                     maximumIsoSensitivity: .iso1200, autoExposureMeteringMode: nil)
        assertThat(camera!.exposureSettings,
                   `is`(mode: .manual, shutterSpeed: .oneOver10, isoSensitivity: .iso100,
                        maximumIsoSensitivity: .iso1200, updating: true))

        assertThat(camera!.exposureCompensationSetting, supports(exposureCompensationValues: []))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetWhiteBalance(
            camId: 0, mode: .blueSky, temperature: .T1500))
        camera!.whiteBalanceSettings.mode = .blueSky
        assertThat(camera!.whiteBalanceSettings, `is`(mode: .blueSky, updating: true))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetHdrSetting(camId: 0, value: .inactive))
        camera!.hdrSetting?.value = false
        assertThat(camera!.hdrSetting, presentAnd(allOf(`is`(false), isUpdating())))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetStyle(camId: 0, style: .plog))
        camera!.styleSettings.activeStyle = .plog
        assertThat(camera!.styleSettings, `is`(
            activeStyle: .plog, saturation: (0, 0, 0), contrast: (0, 0, 0), sharpness: (0, 0, 0), updating: true))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .single, format: .fullFrame, fileFormat: .jpeg, burst: .burst14Over4s,
            bracketing: .preset1ev, captureInterval: 0.0))
        camera!.photoSettings.format = .fullFrame
        assertThat(camera!.photoSettings, `is`(
            mode: .single, format: .fullFrame, fileFormat: .jpeg, updating: true))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetRecordingMode(
            camId: 0, mode: .hyperlapse, resolution: .resUhd8k, framerate: .fps240, hyperlapse: .ratio15))
        camera!.recordingSettings.mode = .hyperlapse
        assertThat(camera!.recordingSettings, `is`(
            mode: .hyperlapse, resolution: .resUhd8k, framerate: .fps240, hyperlapse: .ratio15, updating: true))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetAutorecord(camId: 0, state: .inactive))
        camera!.autoRecordSetting?.value = false
        assertThat(camera!.autoRecordSetting, presentAnd(allOf(`is`(false), isUpdating())))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetZoomVelocityQualityDegradation(camId: 0, allow: 1))
        camera?.zoom?.velocityQualityDegradationAllowance.value = true
        assertThat(camera!.zoom?.velocityQualityDegradationAllowance, presentAnd(allOf(`is`(true), isUpdating())))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetMaxZoomSpeed(camId: 0, max: 6.0))
        camera!.zoom?.maxSpeed.value = 6.0
        assertThat(camera!.zoom?.maxSpeed, presentAnd(allOf(`is`(0.0, 6.0, 15.0), isUpdating())))
         // disconnect

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetExposureSettings(
            camId: 0, mode: .automatic, shutterSpeed: .shutter1Over10, isoSensitivity: .iso100,
            maxIsoSensitivity: .iso1200, meteringMode: ArsdkFeatureCameraAutoExposureMeteringMode.standard))
        camera!.exposureSettings.set(mode: .automatic, manualShutterSpeed: .oneOver10,
                                     manualIsoSensitivity: .iso100,
                                     maximumIsoSensitivity: .iso1200, autoExposureMeteringMode: nil)
        assertThat(camera!.exposureSettings,
                   `is`(mode: .automatic, shutterSpeed: .oneOver10, isoSensitivity: .iso100,
                        maximumIsoSensitivity: .iso1200, updating: true))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetEvCompensation(
            camId: 0, value: .ev0_33))
        camera!.exposureCompensationSetting.value = .ev0_33
        assertThat(camera!.exposureCompensationSetting, `is`(value: .ev0_33, updating: true))

        disconnect(drone: drone, handle: 1)

        // setting should be updated to user value
        assertThat(camera!.modeSetting, `is`(mode: .photo, updating: false))
        assertThat(camera!.hdrSetting, presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(camera!.photoSettings, `is`(
            mode: .single, format: .fullFrame, fileFormat: .jpeg, updating: false))
        assertThat(camera!.recordingSettings, `is`(
            mode: .hyperlapse, resolution: .resUhd8k, framerate: .fps240, hyperlapse: .ratio15, updating: false))
        assertThat(camera!.autoRecordSetting, presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(camera!.zoom?.velocityQualityDegradationAllowance, presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(camera!.zoom?.maxSpeed, presentAnd(allOf(`is`(0.0, 6.0, 15.0), isUpToDate())))

        assertThat(camera!.exposureSettings, supports(
            exposureModes: [.automatic, .automaticPreferIsoSensitivity, .automaticPreferShutterSpeed, .manual],
            shutterSpeeds: CameraShutterSpeed.allCases, isoSensitivities: CameraIso.allCases,
            maximumIsoSensitivities: CameraIso.allCases))
        assertThat(camera!.exposureSettings, `is`(updating: false))
        assertThat(camera!.exposureSettings.mode, `is`(.automatic))
        assertThat(camera!.exposureCompensationSetting, supports(exposureCompensationValues: [.ev0_00, .ev0_33]))
        assertThat(camera!.exposureCompensationSetting, `is`(updating: false))

        assertThat(camera!.whiteBalanceSettings, supports(whiteBalanceModes: [.candle, .blueSky],
                                                          customTemperatures: [.k10000, .k1500]))
        assertThat(camera!.whiteBalanceSettings, `is`(updating: false))

        assertThat(camera!.styleSettings, supports(styles: [.standard, .plog]))
        assertThat(camera!.styleSettings, `is`(updating: false))

        // test other values are reset as they should

        assertThat(camera!.zoom, presentAnd(`is`(
            available: false, currentLevel: 1.0, maxLossLessLevel: 1.0, maxLossyLevel: 1.0)))

        assertThat(camera!.recordingSettings.bitrate, `is`(0))

        assertThat(camera!.photoState, `is`(photoFunctionState: .unavailable, photoCount: 0))
        assertThat(camera!.photoState.mediaId, `is`(nilValue()))

        assertThat(camera!.recordingState, `is`(recordingFunctionState: .unavailable))
    }

    // Check that all enum values defined in arsdk commands are mapped
    func testMappers() {
        // CameraMode
        for rawValue in 0..<Int(ArsdkFeatureCameraCameraModeCnt) {
            let mode = ArsdkFeatureCameraCameraMode(rawValue: rawValue)!
            assertThat(CameraMode(fromArsdk: mode), present())
        }

        // CameraExposureMode
        for rawValue in 0..<Int(ArsdkFeatureCameraExposureModeCnt) {
            let mode = ArsdkFeatureCameraExposureMode(rawValue: rawValue)!
            assertThat(CameraExposureMode(fromArsdk: mode), present())
        }

        // CameraShutterSpeed
        for rawValue in 0..<Int(ArsdkFeatureCameraShutterSpeedCnt) {
            let mode = ArsdkFeatureCameraShutterSpeed(rawValue: rawValue)!
            assertThat(CameraShutterSpeed(fromArsdk: mode), present())
        }

        // CameraIso
        for rawValue in 0..<Int(ArsdkFeatureCameraIsoSensitivityCnt) {
            let mode = ArsdkFeatureCameraIsoSensitivity(rawValue: rawValue)!
            assertThat(CameraIso(fromArsdk: mode), present())
        }

        // CameraAutoExposureMeteringMode
        for rawValue in 0..<Int(ArsdkFeatureCameraAutoExposureMeteringModeCnt) {
            let mode = ArsdkFeatureCameraAutoExposureMeteringMode(rawValue: rawValue)!
            assertThat(CameraAutoExposureMeteringMode(fromArsdk: mode), present())
        }

        // CameraEvCompensation
        for rawValue in 0..<Int(ArsdkFeatureCameraEvCompensationCnt) {
            let mode = ArsdkFeatureCameraEvCompensation(rawValue: rawValue)!
            assertThat(CameraEvCompensation(fromArsdk: mode), present())
        }

        // CameraWhiteBalanceMode
        for rawValue in 0..<Int(ArsdkFeatureCameraWhiteBalanceModeCnt) {
            let mode = ArsdkFeatureCameraWhiteBalanceMode(rawValue: rawValue)!
            assertThat(CameraWhiteBalanceMode(fromArsdk: mode), present())
        }

        // CameraWhiteBalanceTemperature
        for rawValue in 0..<Int(ArsdkFeatureCameraWhiteBalanceTemperatureCnt) {
            let mode = ArsdkFeatureCameraWhiteBalanceTemperature(rawValue: rawValue)!
            assertThat(CameraWhiteBalanceTemperature(fromArsdk: mode), present())
        }

        // CameraStyle
        for rawValue in 0..<Int(ArsdkFeatureCameraStyleCnt) {
            let mode = ArsdkFeatureCameraStyle(rawValue: rawValue)!
            assertThat(CameraStyle(fromArsdk: mode), present())
        }

        // CameraRecordingMode
        for rawValue in 0..<Int(ArsdkFeatureCameraRecordingModeCnt) {
            let mode = ArsdkFeatureCameraRecordingMode(rawValue: rawValue)!
            assertThat(CameraRecordingMode(fromArsdk: mode), present())
        }

        // CameraRecordingResolution
        for rawValue in 0..<Int(ArsdkFeatureCameraResolutionCnt) {
            let mode = ArsdkFeatureCameraResolution(rawValue: rawValue)!
            assertThat(CameraRecordingResolution(fromArsdk: mode), present())
        }

        // CameraRecordingFramerate
        for rawValue in 0..<Int(ArsdkFeatureCameraFramerateCnt) {
            let mode = ArsdkFeatureCameraFramerate(rawValue: rawValue)!
            assertThat(CameraRecordingFramerate(fromArsdk: mode), present())
        }

        // CameraHyperlapseValue
        for rawValue in 0..<Int(ArsdkFeatureCameraHyperlapseValueCnt) {
            let mode = ArsdkFeatureCameraHyperlapseValue(rawValue: rawValue)!
            assertThat(CameraHyperlapseValue(fromArsdk: mode), present())
        }

        // CameraPhotoMode
        for rawValue in 0..<Int(ArsdkFeatureCameraPhotoModeCnt) {
            let mode = ArsdkFeatureCameraPhotoMode(rawValue: rawValue)!
            assertThat(CameraPhotoMode(fromArsdk: mode), present())
        }

        // CameraPhotoFormat
        for rawValue in 0..<Int(ArsdkFeatureCameraPhotoFormatCnt) {
            let mode = ArsdkFeatureCameraPhotoFormat(rawValue: rawValue)!
            assertThat(CameraPhotoFormat(fromArsdk: mode), present())
        }

        // CameraPhotoFileFormat
        for rawValue in 0..<Int(ArsdkFeatureCameraPhotoFileFormatCnt) {
            let mode = ArsdkFeatureCameraPhotoFileFormat(rawValue: rawValue)!
            assertThat(CameraPhotoFileFormat(fromArsdk: mode), present())
        }

        // CameraBurstValue
        for rawValue in 0..<Int(ArsdkFeatureCameraBurstValueCnt) {
            let mode = ArsdkFeatureCameraBurstValue(rawValue: rawValue)!
            assertThat(CameraBurstValue(fromArsdk: mode), present())
        }

        // CameraBracketingValue
        for rawValue in 0..<Int(ArsdkFeatureCameraBracketingPresetCnt) {
            let mode = ArsdkFeatureCameraBracketingPreset(rawValue: rawValue)!
            assertThat(CameraBracketingValue(fromArsdk: mode), present())
        }

        // CameraZoomControlMode
        for rawValue in 0..<Int(ArsdkFeatureCameraZoomControlModeCnt) {
            let mode = ArsdkFeatureCameraZoomControlMode(rawValue: rawValue)!
            assertThat(CameraZoomControlMode(fromArsdk: mode), present())
        }
    }

    func testWhiteBalanceLocked() {
        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand(
                exposureModes: [.automatic, .automaticPreferIsoSensitivity, .automaticPreferShutterSpeed, .manual],
                exposureLockSupported: .supported,
                exposureRoiLockSupported: .supported,
                evCompensations: [.ev0_00, .ev0_33],
                whiteBalanceModes: [.automatic, .candle, .blueSky],
                customWhiteBalanceTemperatures: [.T10000, .T1500],
                whiteBalanceLockSupported: .supported,
                styles: [.standard, .plog],
                cameraModes: [.photo, .recording],
                hyperlapseValues: [.ratio120, .ratio15],
                bracketingPresets: [.preset1ev, .preset3ev],
                burstValues: [.burst10Over1s])
        }

        assertThat(changeCnt, `is`(1))

        assertThat(camera!.whiteBalanceLock?.isLockable, `is`(true))
        assertThat(camera!.whiteBalanceLock?.locked, `is`(false))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraWhiteBalanceEncoder(
            camId: 0, mode: .candle, temperature: .T1500, lock: .inactive))

        assertThat(camera!.whiteBalanceLock?.isLockable, `is`(false))
        assertThat(camera!.whiteBalanceLock?.locked, `is`(false))
        assertThat(changeCnt, `is`(2))

        camera!.whiteBalanceLock?.setLock(lock: false)
        assertThat(camera!.whiteBalanceLock?.locked, `is`(false))
        assertThat(camera!.whiteBalanceLock?.updating, `is`(false))
        assertThat(changeCnt, `is`(2))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetWhiteBalance(
            camId: 0, mode: .automatic, temperature: .T1500))
        camera!.whiteBalanceSettings.set(mode: .automatic, customTemperature: CameraWhiteBalanceTemperature.k1500)
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraWhiteBalanceEncoder(
            camId: 0, mode: .automatic, temperature: .T1500, lock: .inactive))
        assertThat(camera!.whiteBalanceSettings.mode, `is`(.automatic))
        assertThat(camera!.whiteBalanceLock?.isLockable, `is`(true))
        assertThat(camera!.whiteBalanceLock?.locked, `is`(false))
        assertThat(camera!.whiteBalanceLock?.updating, `is`(false))
        assertThat(changeCnt, `is`(4))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetWhiteBalance(
            camId: 0, mode: .candle, temperature: .T1500))
        camera!.whiteBalanceSettings.set(mode: .candle, customTemperature: CameraWhiteBalanceTemperature.k1500)
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraWhiteBalanceEncoder(
            camId: 0, mode: .candle, temperature: .T1500, lock: .inactive))
        assertThat(camera!.whiteBalanceSettings.mode, `is`(.candle))
        assertThat(camera!.whiteBalanceLock?.isLockable, `is`(false))
        assertThat(camera!.whiteBalanceLock?.locked, `is`(false))
        assertThat(camera!.whiteBalanceLock?.updating, `is`(false))
        assertThat(changeCnt, `is`(6))

        camera!.whiteBalanceLock?.setLock(lock: true)
        assertThat(camera!.whiteBalanceLock?.locked, `is`(false))
        assertThat(camera!.whiteBalanceLock?.updating, `is`(false))
        assertThat(changeCnt, `is`(6))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetWhiteBalance(
            camId: 0, mode: .automatic, temperature: .T1500))
        camera!.whiteBalanceSettings.set(mode: .automatic, customTemperature: CameraWhiteBalanceTemperature.k1500)
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraWhiteBalanceEncoder(
            camId: 0, mode: .automatic, temperature: .T1500, lock: .inactive))
        assertThat(camera!.whiteBalanceSettings.mode, `is`(.automatic))
        assertThat(camera!.whiteBalanceLock?.isLockable, `is`(true))
        assertThat(camera!.whiteBalanceLock?.locked, `is`(false))
        assertThat(camera!.whiteBalanceLock?.updating, `is`(false))
        assertThat(changeCnt, `is`(8))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetWhiteBalanceLock(camId: 0, state: .active))
        camera!.whiteBalanceLock?.setLock(lock: true)
        assertThat(camera!.whiteBalanceLock?.locked, `is`(true))
        assertThat(camera!.whiteBalanceLock?.updating, `is`(true))
        assertThat(changeCnt, `is`(9))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraWhiteBalanceEncoder(
            camId: 0, mode: .automatic, temperature: .T1500, lock: .active))
        assertThat(changeCnt, `is`(10))
        camera!.whiteBalanceLock?.setLock(lock: true)
        assertThat(camera!.whiteBalanceLock?.locked, `is`(true))
        assertThat(camera!.whiteBalanceLock?.updating, `is`(false))
        assertThat(changeCnt, `is`(10))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetWhiteBalance(
            camId: 0, mode: .candle, temperature: .T1500))
        camera!.whiteBalanceSettings.set(mode: .candle, customTemperature: CameraWhiteBalanceTemperature.k1500)
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraWhiteBalanceEncoder(
            camId: 0, mode: .candle, temperature: .T1500, lock: .inactive))
        assertThat(camera!.whiteBalanceSettings.mode, `is`(.candle))
        assertThat(camera!.whiteBalanceLock?.isLockable, `is`(false))
        assertThat(camera!.whiteBalanceLock?.locked, `is`(false))
        assertThat(camera!.whiteBalanceLock?.updating, `is`(false))
    }

    func testWhiteBalanceLockedNotSupported() {
        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand(
                exposureModes: [.automatic, .automaticPreferIsoSensitivity, .automaticPreferShutterSpeed, .manual],
                exposureLockSupported: .supported,
                exposureRoiLockSupported: .supported,
                evCompensations: [.ev0_00, .ev0_33],
                whiteBalanceModes: [.automatic, .candle, .blueSky],
                customWhiteBalanceTemperatures: [.T10000, .T1500],
                whiteBalanceLockSupported: .notSupported,
                styles: [.standard, .plog],
                cameraModes: [.photo, .recording],
                hyperlapseValues: [.ratio120, .ratio15],
                bracketingPresets: [.preset1ev, .preset3ev],
                burstValues: [.burst10Over1s])
        }

        assertThat(changeCnt, `is`(1))

        assertThat(camera!.whiteBalanceLock?.isLockable, `is`(false))
        assertThat(camera!.whiteBalanceLock?.locked, `is`(false))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraWhiteBalanceEncoder(
            camId: 0, mode: .candle, temperature: .T1500, lock: .inactive))

        assertThat(camera!.whiteBalanceLock?.isLockable, nilValue())
        assertThat(changeCnt, `is`(2))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetWhiteBalance(
            camId: 0, mode: .automatic, temperature: .T1500))
        camera!.whiteBalanceSettings.set(mode: .automatic, customTemperature: CameraWhiteBalanceTemperature.k1500)
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraWhiteBalanceEncoder(
            camId: 0, mode: .automatic, temperature: .T1500, lock: .inactive))
        assertThat(camera!.whiteBalanceSettings.mode, `is`(.automatic))
        assertThat(camera!.whiteBalanceLock, nilValue())
        assertThat(camera!.whiteBalanceLock?.isLockable, nilValue())
        assertThat(changeCnt, `is`(4))

        camera!.whiteBalanceLock?.setLock(lock: true)
        assertThat(camera!.whiteBalanceLock?.isLockable, nilValue())
        assertThat(changeCnt, `is`(4))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetWhiteBalance(
            camId: 0, mode: .candle, temperature: .T1500))
        camera!.whiteBalanceSettings.set(mode: .candle, customTemperature: CameraWhiteBalanceTemperature.k1500)
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraWhiteBalanceEncoder(
            camId: 0, mode: .candle, temperature: .T1500, lock: .inactive))
        assertThat(camera!.whiteBalanceSettings.mode, `is`(.candle))
        assertThat(camera!.whiteBalanceLock?.isLockable, nilValue())
        assertThat(changeCnt, `is`(6))
    }

    func testStopPhoto() {
        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand(
                bracketingPresets: [.preset1ev, .preset3ev, .preset1ev2ev],
                burstValues: [.burst14Over4s, .burst10Over2s, .burst4Over1s])
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraPhotoCapabilitiesEncoder(
                id: 0, photoModesBitField: Bitfield<ArsdkFeatureCameraPhotoMode>.of([.timeLapse]),
                photoFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFormat>.of([.fullFrame]),
                photoFileFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFileFormat>.of([.dngJpeg, .jpeg]),
                hdr: .notSupported, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))

            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraPhotoCapabilitiesEncoder(
                id: 2, photoModesBitField: Bitfield<ArsdkFeatureCameraPhotoMode>.of([.gpsLapse]),
                photoFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFormat>.of([.fullFrame, .rectilinear]),
                photoFileFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFileFormat>.of([.jpeg]),
                hdr: .supported, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraCameraModeEncoder(camId: 0, mode: .photo))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraPhotoStateEncoder(camId: 0, available: .notAvailable, state: .inactive))
        }

        assertThat(changeCnt, `is`(1))

        // Check initial values
        assertThat(camera!.photoState, `is`(photoFunctionState: .unavailable))

        // move to available
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraPhotoStateEncoder(camId: 0, available: .available, state: .inactive))
        assertThat(changeCnt, `is`(2))
        assertThat(camera!.photoState, `is`(photoFunctionState: .stopped))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .timeLapse, format: .fullFrame, fileFormat: .jpeg, burst: .burst14Over4s,
            bracketing: .preset1ev, captureInterval: 0.0))

        camera!.photoSettings.mode = .timeLapse

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraPhotoModeEncoder(
                camId: 0, mode: .timeLapse, format: .fullFrame, fileFormat: .jpeg, burst: .burst14Over4s,
                bracketing: .preset1ev, captureInterval: 3.5))

        assertThat(changeCnt, `is`(4))
        expectCommand(
            handle: 1, expectedCmd: ExpectedCmd.cameraTakePhoto(camId: 0))
        camera!.startPhotoCapture()
        assertThat(changeCnt, `is`(5))

        expectCommand(
            handle: 1, expectedCmd: ExpectedCmd.cameraStopPhoto(camId: 0))
        camera!.stopPhotoCapture()
        assertThat(changeCnt, `is`(6))

        camera!.stopPhotoCapture()
        assertThat(changeCnt, `is`(6))
        assertNoExpectation()

    }

    func testCaptureInterval() {
        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand(
                bracketingPresets: [.preset1ev, .preset3ev, .preset1ev2ev],
                burstValues: [.burst14Over4s, .burst10Over2s, .burst4Over1s],
                timelapseIntervalMin: 3.5, gpslapseIntervalMin: 2.5)
            self.mockArsdkCore.onCommandReceived(
                0, encoder: CmdEncoder.cameraCameraStatesEncoder(activeCameras: Bitfield.of([Model.main])))
            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraPhotoCapabilitiesEncoder(
                id: 0, photoModesBitField: Bitfield<ArsdkFeatureCameraPhotoMode>.of([.timeLapse]),
                photoFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFormat>.of([.fullFrame]),
                photoFileFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFileFormat>.of([.dngJpeg, .jpeg]),
                hdr: .notSupported, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))

            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraPhotoCapabilitiesEncoder(
                id: 2, photoModesBitField: Bitfield<ArsdkFeatureCameraPhotoMode>.of([.gpsLapse]),
                photoFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFormat>.of([.fullFrame, .rectilinear]),
                photoFileFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFileFormat>.of([.jpeg]),
                hdr: .supported, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))
        }

        assertThat(changeCnt, `is`(1))

        assertThat(camera!.photoSettings.supportedTimelapseIntervals.lowerBound, `is`(3.5))
        assertThat(camera!.photoSettings.supportedGpslapseIntervals.lowerBound, `is`(2.5))

        assertThat(camera!.photoSettings.timelapseCaptureInterval, `is`(3.5))
        assertThat(camera!.photoSettings.gpslapseCaptureInterval, `is`(2.5))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .gpsLapse, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over4s,
            bracketing: .preset1ev, captureInterval: 2.5))
        assertThat(changeCnt, `is`(1))
        camera!.photoSettings.mode = .gpsLapse
        assertThat(camera!.photoSettings.gpslapseCaptureInterval, `is`(2.5))
        assertThat(changeCnt, `is`(2))
        assertThat(camera!.photoSettings, `is`(mode: .gpsLapse, format: .rectilinear, fileFormat: .jpeg,
                                               burst: .burst14Over4s, bracketing: .preset1ev, updating: true))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraPhotoModeEncoder(
                camId: 0, mode: .gpsLapse, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over2s,
                bracketing: .preset1ev, captureInterval: 2.5))
        camera!.photoSettings.gpslapseCaptureInterval = 1.0
        assertThat(changeCnt, `is`(3))
        assertNoExpectation()

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .gpsLapse, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over4s,
            bracketing: .preset1ev, captureInterval: 5.0))
        camera!.photoSettings.gpslapseCaptureInterval = 5.0
        assertThat(changeCnt, `is`(4))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraPhotoModeEncoder(
                camId: 0, mode: .gpsLapse, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over2s,
                bracketing: .preset1ev, captureInterval: 5.0))
        assertThat(changeCnt, `is`(5))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .gpsLapse, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over4s,
            bracketing: .preset1ev, captureInterval: 2.5))
        camera!.photoSettings.gpslapseCaptureInterval = 2.5
        assertThat(changeCnt, `is`(6))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraPhotoModeEncoder(
                camId: 0, mode: .gpsLapse, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over2s,
                bracketing: .preset1ev, captureInterval: 2.5))
        assertThat(changeCnt, `is`(7))

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .timeLapse, format: .fullFrame, fileFormat: .jpeg, burst: .burst14Over4s,
            bracketing: .preset1ev, captureInterval: 3.5))

        camera!.photoSettings.mode = .timeLapse
        assertThat(changeCnt, `is`(8))
        assertThat(camera!.photoSettings, `is`(mode: .timeLapse, format: .fullFrame, fileFormat: .jpeg,
                                               burst: .burst14Over4s, bracketing: .preset1ev, updating: true))
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraPhotoModeEncoder(
                camId: 0, mode: .timeLapse, format: .fullFrame, fileFormat: .jpeg, burst: .burst14Over4s,
                bracketing: .preset1ev, captureInterval: 3.5))
        assertThat(changeCnt, `is`(9))

        disconnect(drone: drone, handle: 1)
        assertThat(camera, `is`(present()))

        camera!.photoSettings.timelapseCaptureInterval = 7.0
        connect(drone: drone, handle: 1) {

        self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
                camId: 0, mode: .timeLapse, format: .fullFrame, fileFormat: .jpeg, burst: .burst14Over4s,
                bracketing: .preset1ev, captureInterval: 7.0))
        }

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .timeLapse, format: .fullFrame, fileFormat: .jpeg, burst: .burst14Over4s,
            bracketing: .preset1ev, captureInterval: 3.5))

        camera!.photoSettings.set(mode: .timeLapse, format: .fullFrame, fileFormat: .jpeg, burstValue: .burst14Over4s,
                                  bracketingValue: .preset1ev, gpslapseCaptureIntervalValue: nil,
                                  timelapseCaptureIntervalValue: 2.0)

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .timeLapse, format: .fullFrame, fileFormat: .jpeg, burst: .burst14Over4s,
            bracketing: .preset1ev, captureInterval: 5.0))

        camera!.photoSettings.set(mode: .timeLapse, format: .fullFrame, fileFormat: .jpeg, burstValue: .burst14Over4s,
                                  bracketingValue: .preset1ev, gpslapseCaptureIntervalValue: nil,
                                  timelapseCaptureIntervalValue: 5.0)

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .gpsLapse, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over4s,
            bracketing: .preset1ev, captureInterval: 2.5))

        camera!.photoSettings.set(mode: .gpsLapse, format: .rectilinear, fileFormat: .jpeg, burstValue: .burst14Over4s,
                                  bracketingValue: .preset1ev, gpslapseCaptureIntervalValue: 2.5,
                                  timelapseCaptureIntervalValue: nil)

        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetPhotoMode(
            camId: 0, mode: .gpsLapse, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over4s,
            bracketing: .preset1ev, captureInterval: 7.0))

        camera!.photoSettings.set(mode: .gpsLapse, format: .rectilinear, fileFormat: .jpeg, burstValue: .burst14Over4s,
                                  bracketingValue: .preset1ev, gpslapseCaptureIntervalValue: 7.0,
                                  timelapseCaptureIntervalValue: nil)

    }

    func testOutOfBoundCaptureInterval() {
        connect(drone: drone, handle: 1) {

            self.sendCapabilitiesCommand(
                bracketingPresets: [.preset1ev, .preset3ev, .preset1ev2ev],
                burstValues: [.burst14Over4s, .burst10Over2s, .burst4Over1s],
                timelapseIntervalMin: 3.5, gpslapseIntervalMin: 2.5)

            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraCameraStatesEncoder(activeCameras: Bitfield.of([Model.main])))

            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraPhotoCapabilitiesEncoder(
                id: 0, photoModesBitField: Bitfield<ArsdkFeatureCameraPhotoMode>.of([.timeLapse]),
                photoFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFormat>.of([.fullFrame]),
                photoFileFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFileFormat>.of([.dngJpeg, .jpeg]),
                hdr: .notSupported, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))

            self.mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.cameraPhotoCapabilitiesEncoder(
                id: 2, photoModesBitField: Bitfield<ArsdkFeatureCameraPhotoMode>.of([.gpsLapse]),
                photoFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFormat>.of([.fullFrame, .rectilinear]),
                photoFileFormatsBitField: Bitfield<ArsdkFeatureCameraPhotoFileFormat>.of([.jpeg]),
                hdr: .supported, listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))

            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraPhotoModeEncoder(
                    camId: 0, mode: .gpsLapse, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over2s,
                    bracketing: .preset1ev, captureInterval: 0.5))
        }

        assertThat(changeCnt, `is`(1))

        assertThat(camera!.photoSettings.supportedTimelapseIntervals.lowerBound, `is`(3.5))
        assertThat(camera!.photoSettings.supportedGpslapseIntervals.lowerBound, `is`(2.5))

        assertThat(camera!.photoSettings.timelapseCaptureInterval, `is`(3.5))
        assertThat(camera!.photoSettings.gpslapseCaptureInterval, `is`(0.5))
    }

    func testAlignment() {
        connect(drone: drone, handle: 1) {
            self.sendCapabilitiesCommand()
        }

        // check initial value
        assertThat(camera!.alignment, nilValue())
        assertThat(changeCnt, `is`(1))

        // mock alignment command reception
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraAlignmentOffsetsEncoder(camId: 0,
                                                                 minBoundYaw: 10, maxBoundYaw: 30, currentYaw: 20,
                                                                 minBoundPitch: 40, maxBoundPitch: 60, currentPitch: 50,
                                                                 minBoundRoll: 70, maxBoundRoll: 90, currentRoll: 80))
        assertThat(camera!.alignment, present())
        assertThat(camera!.alignment!, `is`(yawLowerBound: 10, yaw: 20, yawUpperBound: 30,
                                            pitchLowerBound: 40, pitch: 50, pitchUpperBound: 60,
                                            rollLowerBound: 70, roll: 80, rollUpperBound: 90, updating: false))
        assertThat(changeCnt, `is`(2))

        // change yaw offset from api
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetAlignmentOffsets(
            camId: 0, yaw: 25, pitch: 50, roll: 80))
        camera!.alignment!.yaw = 25
        assertThat(camera!.alignment!, `is`(yawLowerBound: 10, yaw: 25, yawUpperBound: 30,
                                            pitchLowerBound: 40, pitch: 50, pitchUpperBound: 60,
                                            rollLowerBound: 70, roll: 80, rollUpperBound: 90, updating: true))
        assertThat(changeCnt, `is`(3))

        // mock alignment command reception
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraAlignmentOffsetsEncoder(camId: 0,
                                                                 minBoundYaw: 10, maxBoundYaw: 30, currentYaw: 25,
                                                                 minBoundPitch: 40, maxBoundPitch: 60, currentPitch: 50,
                                                                 minBoundRoll: 70, maxBoundRoll: 90, currentRoll: 80))
        assertThat(camera!.alignment!, `is`(yawLowerBound: 10, yaw: 25, yawUpperBound: 30,
                                            pitchLowerBound: 40, pitch: 50, pitchUpperBound: 60,
                                            rollLowerBound: 70, roll: 80, rollUpperBound: 90, updating: false))
        assertThat(changeCnt, `is`(4))

        // change pitch offset from api
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetAlignmentOffsets(
            camId: 0, yaw: 25, pitch: 55, roll: 80))
        camera!.alignment!.pitch = 55
        assertThat(camera!.alignment!, `is`(yawLowerBound: 10, yaw: 25, yawUpperBound: 30,
                                            pitchLowerBound: 40, pitch: 55, pitchUpperBound: 60,
                                            rollLowerBound: 70, roll: 80, rollUpperBound: 90, updating: true))
        assertThat(changeCnt, `is`(5))

        // mock alignment command reception
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraAlignmentOffsetsEncoder(camId: 0,
                                                                 minBoundYaw: 10, maxBoundYaw: 30, currentYaw: 25,
                                                                 minBoundPitch: 40, maxBoundPitch: 60, currentPitch: 55,
                                                                 minBoundRoll: 70, maxBoundRoll: 90, currentRoll: 80))
        assertThat(camera!.alignment!, `is`(yawLowerBound: 10, yaw: 25, yawUpperBound: 30,
                                            pitchLowerBound: 40, pitch: 55, pitchUpperBound: 60,
                                            rollLowerBound: 70, roll: 80, rollUpperBound: 90, updating: false))
        assertThat(changeCnt, `is`(6))

        // change roll offset from api
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraSetAlignmentOffsets(
            camId: 0, yaw: 25, pitch: 55, roll: 85))
        camera!.alignment!.roll = 85
        assertThat(camera!.alignment!, `is`(yawLowerBound: 10, yaw: 25, yawUpperBound: 30,
                                            pitchLowerBound: 40, pitch: 55, pitchUpperBound: 60,
                                            rollLowerBound: 70, roll: 85, rollUpperBound: 90, updating: true))
        assertThat(changeCnt, `is`(7))

        // mock alignment command reception
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraAlignmentOffsetsEncoder(camId: 0,
                                                                 minBoundYaw: 10, maxBoundYaw: 30, currentYaw: 25,
                                                                 minBoundPitch: 40, maxBoundPitch: 60, currentPitch: 55,
                                                                 minBoundRoll: 70, maxBoundRoll: 90, currentRoll: 85))
        assertThat(camera!.alignment!, `is`(yawLowerBound: 10, yaw: 25, yawUpperBound: 30,
                                            pitchLowerBound: 40, pitch: 55, pitchUpperBound: 60,
                                            rollLowerBound: 70, roll: 85, rollUpperBound: 90, updating: false))
        assertThat(changeCnt, `is`(8))

        // reset offsets
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.cameraResetAlignmentOffsets(camId: 0))
        _ = camera!.alignment!.reset()

        // mock alignment command reception
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraAlignmentOffsetsEncoder(camId: 0,
                                                                 minBoundYaw: 10, maxBoundYaw: 30, currentYaw: 20,
                                                                 minBoundPitch: 40, maxBoundPitch: 60, currentPitch: 50,
                                                                 minBoundRoll: 70, maxBoundRoll: 90, currentRoll: 80))
        assertThat(camera!.alignment!, `is`(yawLowerBound: 10, yaw: 20, yawUpperBound: 30,
                                            pitchLowerBound: 40, pitch: 50, pitchUpperBound: 60,
                                            rollLowerBound: 70, roll: 80, rollUpperBound: 90, updating: false))
        assertThat(changeCnt, `is`(9))

        // alignment should be nil after a disconnection
        disconnect(drone: drone, handle: 1)
        assertThat(camera!.alignment, nilValue())
        assertThat(changeCnt, `is`(10))
    }
}
