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
@testable import GroundSdk

/// Test Camera peripheral
class CameraTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: MainCameraCore!
    private var implThermal: ThermalCameraCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = MainCameraCore(store: store!, backend: backend!)
        implThermal = ThermalCameraCore(store: store!, backend: backend!)
        // check default value
        assertThat(impl.isActive, `is`(false))
        impl.updateActiveFlag(active: true)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.mainCamera), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.mainCamera), nilValue())

        implThermal.publish()
        assertThat(store!.get(Peripherals.thermalCamera), present())
        implThermal.unpublish()
        assertThat(store!.get(Peripherals.thermalCamera), nilValue())
    }

    func testMode() {
        impl.update(supportedModes: Set<CameraMode>([.recording, .photo]))
        impl.publish()
        var cnt = 0
        let camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }

        // test capabilities values
        assertThat(camera.modeSetting, supports(modes: [.recording, .photo]))

        // test backend change notification
        impl.update(mode: .photo).notifyUpdated()
        assertThat(camera.modeSetting, `is`(mode: .photo, updating: false))
        assertThat(cnt, `is`(1))

        // test change value
        camera.modeSetting.mode = .recording
        assertThat(cnt, `is`(2))
        assertThat(camera.modeSetting, `is`(mode: .recording, updating: true))
        assertThat(backend.mode, presentAnd(`is`(.recording)))
        impl.update(mode: .recording).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(camera.modeSetting, `is`(mode: .recording, updating: false))

        // timeout should not do anything
        (camera.modeSetting as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(3))
        assertThat(camera.modeSetting, `is`(mode: .recording, updating: false))

        // test change to unsupported value
        impl.update(supportedModes: Set<CameraMode>([.recording]))
        camera.modeSetting.mode = .photo
        assertThat(cnt, `is`(3))
        assertThat(backend.mode, presentAnd(`is`(.recording)))
        assertThat(camera.modeSetting, `is`(mode: .recording, updating: false))

        // change setting
        impl.update(supportedModes: Set<CameraMode>([.recording, .photo]))
        camera.modeSetting.mode = .photo
        assertThat(cnt, `is`(4))
        assertThat(camera.modeSetting, `is`(mode: .photo, updating: true))

        // mock timeout
        (camera.modeSetting as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(camera.modeSetting, `is`(mode: .recording, updating: false))

        // change setting from the api
        camera.modeSetting.mode = .photo
        assertThat(cnt, `is`(6))
        assertThat(camera.modeSetting, `is`(mode: .photo, updating: true))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(7))
        assertThat(camera.modeSetting, `is`(mode: .photo, updating: false))

        // timeout should not be triggered since it has been canceled
        (camera.modeSetting as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(7))
        assertThat(camera.modeSetting, `is`(mode: .photo, updating: false))
    }

    func testExposure() {
        impl.update(supportedExposureModes: Set<CameraExposureMode>(
            [.automatic, .automaticPreferIsoSensitivity, .manualShutterSpeed, .manual]))
        impl.update(supportedManualShutterSpeeds: Set<CameraShutterSpeed>([.oneOver10000, .oneOver1000, .one]))
        impl.update(supportedManualIsoSensitivity: Set<CameraIso>([.iso50, .iso200, .iso1200]))
        impl.update(supportedMaximumIsoSensitivity: Set<CameraIso>([.iso50, .iso200, .iso1200]))

        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }

        // test capabilities values
        assertThat(camera.exposureSettings, supports(
            exposureModes: [.automatic, .manualShutterSpeed, .automaticPreferIsoSensitivity, .manual],
            shutterSpeeds: [.oneOver10000, .oneOver1000, .one],
            isoSensitivities: [.iso50, .iso200, .iso1200],
            maximumIsoSensitivities: [.iso50, .iso200, .iso1200]))

        // test backend change notification
        impl.update(exposureMode: .manual).update(manualShutterSpeed: .oneOver1000)
            .update(manualIsoSensitivity: .iso200).update(maximumIsoSensitivity: .iso1200).notifyUpdated()

        assertThat(cnt, `is`(1))
        assertThat(camera.exposureSettings, `is`(
            mode: .manual, shutterSpeed: .oneOver1000, isoSensitivity: .iso200, maximumIsoSensitivity: .iso1200,
            updating: false))

        // test individial setters

        // mode
        camera.exposureSettings.mode = .manualShutterSpeed
        assertThat(cnt, `is`(2))
        assertThat(camera.exposureSettings, `is`(mode: .manualShutterSpeed, updating: true))
        assertThat(backend.exposureMode, presentAnd(`is`(.manualShutterSpeed)))
        impl.update(exposureMode: .manualShutterSpeed).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(camera.exposureSettings, `is`(mode: .manualShutterSpeed, updating: false))
        // unsupported value
        camera.exposureSettings.mode = .manualIsoSensitivity
        assertThat(cnt, `is`(3))
        assertThat(camera.exposureSettings, `is`(mode: .manualShutterSpeed, updating: false))

        // move to manual to test shutter speed and iso sensitivty
        camera.exposureSettings.mode = .manual
        assertThat(cnt, `is`(4))

        // shutter speed
        camera.exposureSettings.manualShutterSpeed = .one
        assertThat(cnt, `is`(5))
        assertThat(camera.exposureSettings, `is`(shutterSpeed: .one, updating: true))
        assertThat(backend.manualShutterSpeed, presentAnd(`is`(.one)))
        impl.update(manualShutterSpeed: .one).notifyUpdated()
        assertThat(cnt, `is`(6))
        assertThat(camera.exposureSettings, `is`(shutterSpeed: .one, updating: false))
        // unsupported value
        camera.exposureSettings.manualShutterSpeed = .oneOver8
        assertThat(cnt, `is`(6))
        assertThat(camera.exposureSettings, `is`(shutterSpeed: .one, updating: false))

        // iso sensitivty
        camera.exposureSettings.manualIsoSensitivity = .iso1200
        assertThat(cnt, `is`(7))
        assertThat(camera.exposureSettings, `is`(isoSensitivity: .iso1200, updating: true))
        assertThat(backend.manualIsoSensitivity, presentAnd(`is`(.iso1200)))
        impl.update(manualIsoSensitivity: .iso1200).notifyUpdated()
        assertThat(camera.exposureSettings.manualIsoSensitivity, `is`(.iso1200))
        assertThat(cnt, `is`(8))
        assertThat(camera.exposureSettings, `is`(isoSensitivity: .iso1200, updating: false))
        // unsupported value
        camera.exposureSettings.manualIsoSensitivity = .iso400
        assertThat(cnt, `is`(8))
        assertThat(camera.exposureSettings, `is`(isoSensitivity: .iso1200, updating: false))

        // move to automatic to test maximum iso sensitivty
        camera.exposureSettings.mode = .automatic
        assertThat(cnt, `is`(9))

        // maximum iso sensitivity
        camera.exposureSettings.maximumIsoSensitivity = .iso50
        assertThat(cnt, `is`(10))
        assertThat(camera.exposureSettings, `is`(maximumIsoSensitivity: .iso50, updating: true))
        assertThat(backend.maxIsoSensitivity, presentAnd(`is`(.iso50)))
        impl.update(maximumIsoSensitivity: .iso50).notifyUpdated()
        assertThat(camera.exposureSettings.maximumIsoSensitivity, `is`(.iso50))
        assertThat(cnt, `is`(11))
        assertThat(camera.exposureSettings, `is`(maximumIsoSensitivity: .iso50, updating: false))
        // unsupported value
        camera.exposureSettings.maximumIsoSensitivity = .iso400
        assertThat(cnt, `is`(11))
        assertThat(camera.exposureSettings, `is`(maximumIsoSensitivity: .iso50, updating: false))

        // global setter
        camera.exposureSettings.set(mode: .automaticPreferIsoSensitivity, manualShutterSpeed: .oneOver1000,
                                    manualIsoSensitivity: .iso200,
                                    maximumIsoSensitivity: .iso1200, autoExposureMeteringMode: .standard)
        assertThat(cnt, `is`(12))
        assertThat(camera.exposureSettings, `is`(
            mode: .automaticPreferIsoSensitivity, shutterSpeed: .oneOver1000,
            isoSensitivity: .iso200, maximumIsoSensitivity: .iso1200, updating: true))
        assertThat(backend.exposureMode, presentAnd(`is`(.automaticPreferIsoSensitivity)))
        assertThat(backend.manualShutterSpeed, presentAnd(`is`(.oneOver1000)))
        assertThat(backend.manualIsoSensitivity, presentAnd(`is`(.iso200)))
        assertThat(backend.maxIsoSensitivity, presentAnd(`is`(.iso1200)))
        impl.update(exposureMode: .automaticPreferIsoSensitivity).update(manualShutterSpeed: .oneOver1000)
            .update(manualIsoSensitivity: .iso200).update(maximumIsoSensitivity: .iso1200).notifyUpdated()
        assertThat(cnt, `is`(13))
        assertThat(camera.exposureSettings, `is`(
            mode: .automaticPreferIsoSensitivity, shutterSpeed: .oneOver1000 ,
            isoSensitivity: .iso200, maximumIsoSensitivity: .iso1200, updating: false))

        // timeout should not do anything
        (camera.exposureSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(13))
        assertThat(camera.exposureSettings, `is`(
            mode: .automaticPreferIsoSensitivity, shutterSpeed: .oneOver1000 ,
            isoSensitivity: .iso200, maximumIsoSensitivity: .iso1200, updating: false))

        // change setting
        camera.exposureSettings.mode = .manualShutterSpeed
        assertThat(cnt, `is`(14))
        assertThat(camera.exposureSettings, `is`(
            mode: .manualShutterSpeed, shutterSpeed: .oneOver1000 ,
            isoSensitivity: .iso200, maximumIsoSensitivity: .iso1200, updating: true))

        // mock timeout
        (camera.exposureSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(15))
        assertThat(camera.exposureSettings, `is`(
            mode: .automaticPreferIsoSensitivity, shutterSpeed: .oneOver1000,
            isoSensitivity: .iso200, maximumIsoSensitivity: .iso1200, updating: false))

        impl.update(exposureMode: .manualShutterSpeed).notifyUpdated()
        assertThat(cnt, `is`(16))
        assertThat(camera.exposureSettings, `is`(mode: .manualShutterSpeed, updating: false))

        // change setting
        camera.exposureSettings.manualShutterSpeed = .one
        assertThat(cnt, `is`(17))
        assertThat(camera.exposureSettings, `is`(
            mode: .manualShutterSpeed, shutterSpeed: .one ,
            isoSensitivity: .iso200, maximumIsoSensitivity: .iso1200, updating: true))

        // mock timeout
        (camera.exposureSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(18))
        assertThat(camera.exposureSettings, `is`(
            mode: .manualShutterSpeed, shutterSpeed: .oneOver1000,
            isoSensitivity: .iso200, maximumIsoSensitivity: .iso1200, updating: false))

        // change setting from the api
        camera.exposureSettings.manualShutterSpeed = .one
        assertThat(cnt, `is`(19))
        assertThat(camera.exposureSettings, `is`(
            mode: .manualShutterSpeed, shutterSpeed: .one ,
            isoSensitivity: .iso200, maximumIsoSensitivity: .iso1200, updating: true))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(20))
        assertThat(camera.exposureSettings, `is`(
            mode: .manualShutterSpeed, shutterSpeed: .one ,
            isoSensitivity: .iso200, maximumIsoSensitivity: .iso1200, updating: false))

        // timeout should not be triggered since it has been canceled
        (camera.exposureSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(20))
        assertThat(camera.exposureSettings, `is`(
            mode: .manualShutterSpeed, shutterSpeed: .one ,
            isoSensitivity: .iso200, maximumIsoSensitivity: .iso1200, updating: false))

        // auto exposure metering mode
        // Set to default
        camera.exposureSettings.autoExposureMeteringMode = .standard
        assertThat(cnt, `is`(20))
        assertThat(camera.exposureSettings, `is`(autoExposureMeteringMode: .standard, updating: false))

        // Change to center top
        camera.exposureSettings.autoExposureMeteringMode = .centerTop
        assertThat(cnt, `is`(21))
        assertThat(camera.exposureSettings, `is`(autoExposureMeteringMode: .centerTop, updating: true))

        assertThat(backend.autoExposureMeteringMode, presentAnd(`is`(.centerTop)))
        impl.update(autoExposureMeteringMode: .centerTop).notifyUpdated()
        assertThat(cnt, `is`(22))
        assertThat(camera.exposureSettings, `is`(autoExposureMeteringMode: .centerTop, updating: false))
    }

    func testIsActive() {
        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }

        // the default value should be false, but setup() set this value to true for testing
        assertThat(camera.isActive, `is`(true))
        assertThat(cnt, `is`(0))

        // set active to false
        impl.updateActiveFlag(active: false).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(camera.isActive, `is`(false))

        // set the same value
        impl.updateActiveFlag(active: false).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(camera.isActive, `is`(false))
    }

    func testExposureLock() {
        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }

        // check default value
        assertThat(camera.exposureLock, nilValue())
        assertThat(cnt, `is`(0))

        // make lock available
        impl.update(exposureLockMode: .none).notifyUpdated()
        assertThat(camera.exposureLock, presentAnd(`is`(mode: CameraExposureLockMode.none, updating: false)))
        assertThat(cnt, `is`(1))

        // change mode from api
        camera.exposureLock?.lockOnCurrentValues()
        assertThat(camera.exposureLock, presentAnd(`is`(mode: .currentValues, updating: true)))
        assertThat(backend.exposureLockMode, presentAnd(`is`(.currentValues)))
        assertThat(cnt, `is`(2))

        // update mode
        impl.update(exposureLockMode: .currentValues).notifyUpdated()
        assertThat(camera.exposureLock, presentAnd(`is`(mode: .currentValues, updating: false)))
        assertThat(cnt, `is`(3))

        // change from api
        camera.exposureLock?.lockOnRegion(centerX: 0.4, centerY: 0.8)
        assertThat(camera.exposureLock, presentAnd(`is`(
            mode: .region(centerX: 0.4, centerY: 0.8, width: 0.0, height: 0.0))))
        assertThat(backend.exposureLockMode, presentAnd(`is`(
            .region(centerX: 0.4, centerY: 0.8, width: 0.0, height: 0.0))))
        assertThat(cnt, `is`(4))

        // update mode
        impl.update(exposureLockMode: .region(centerX: 0.4, centerY: 0.8, width: 0.2, height: 0.5)).notifyUpdated()
        assertThat(camera.exposureLock, presentAnd(
            `is`(mode: .region(centerX: 0.4, centerY: 0.8, width: 0.2, height: 0.5), updating: false)))
        assertThat(cnt, `is`(5))

        // timeout should not do anything
        (camera.exposureLock as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(camera.exposureLock, presentAnd(
            `is`(mode: .region(centerX: 0.4, centerY: 0.8, width: 0.2, height: 0.5), updating: false)))

        // update with same (complex) value
        impl.update(exposureLockMode: .region(centerX: 0.4, centerY: 0.8, width: 0.2, height: 0.5)).notifyUpdated()
        assertThat(camera.exposureLock, presentAnd(
            `is`(mode: .region(centerX: 0.4, centerY: 0.8, width: 0.2, height: 0.5), updating: false)))
        assertThat(cnt, `is`(5))

        // change mode from api
        camera.exposureLock?.unlock()
        assertThat(camera.exposureLock, presentAnd(`is`(mode: CameraExposureLockMode.none, updating: true)))
        assertThat(backend.exposureLockMode, presentAnd(`is`(CameraExposureLockMode.none)))
        assertThat(cnt, `is`(6))

        // update mode
        impl.update(exposureLockMode: .none).notifyUpdated()
        assertThat(camera.exposureLock, presentAnd(`is`(mode: CameraExposureLockMode.none, updating: false)))
        assertThat(cnt, `is`(7))

        // change from api
        camera.exposureLock?.lockOnRegion(centerX: 0.4, centerY: 0.8)
        assertThat(camera.exposureLock, presentAnd(`is`(
            mode: .region(centerX: 0.4, centerY: 0.8, width: 0.0, height: 0.0), updating: true)))
        assertThat(backend.exposureLockMode, presentAnd(`is`(
            .region(centerX: 0.4, centerY: 0.8, width: 0.0, height: 0.0))))
        assertThat(cnt, `is`(8))

        // mock timeout
        (camera.exposureLock as? TimeoutableSetting)?.mockTimeout()
        assertThat(camera.exposureLock, presentAnd(`is`(mode: CameraExposureLockMode.none, updating: false)))
        assertThat(cnt, `is`(9))

        // update mode
        impl.update(exposureLockMode: .region(centerX: 0.4, centerY: 0.8, width: 0.2, height: 0.5)).notifyUpdated()
        assertThat(camera.exposureLock, presentAnd(
            `is`(mode: .region(centerX: 0.4, centerY: 0.8, width: 0.2, height: 0.5), updating: false)))
        assertThat(cnt, `is`(10))

        // change mode from api
        camera.exposureLock?.unlock()
        assertThat(camera.exposureLock, presentAnd(`is`(mode: CameraExposureLockMode.none, updating: true)))
        assertThat(backend.exposureLockMode, presentAnd(`is`(CameraExposureLockMode.none)))
        assertThat(cnt, `is`(11))

        // mock timeout
        (camera.exposureLock as? TimeoutableSetting)?.mockTimeout()
        assertThat(camera.exposureLock, presentAnd(
            `is`(mode: .region(centerX: 0.4, centerY: 0.8, width: 0.2, height: 0.5), updating: false)))
        assertThat(cnt, `is`(12))
    }

    func testWhiteBalanceLock() {
        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }

        // check default value
        assertThat(camera.whiteBalanceLock, nilValue())
        assertThat(cnt, `is`(0))

        // make lock available
        impl.update(whiteBalanceLockSupported: true).notifyUpdated()
        assertThat(camera.whiteBalanceLock?.isLockable, presentAnd(`is`(true)))
        assertThat(camera.whiteBalanceLock, presentAnd(`is`(locked: false, updating: false)))
        assertThat(cnt, `is`(1))

        impl.update(whiteBalanceLockSupported: nil).notifyUpdated()
        assertThat(camera.whiteBalanceLock, nilValue())
        assertThat(cnt, `is`(2))

        impl.update(whiteBalanceLockSupported: nil).notifyUpdated()
        assertThat(camera.whiteBalanceLock, nilValue())
        assertThat(cnt, `is`(2))

        impl.update(whiteBalanceLockSupported: false).notifyUpdated()
        assertThat(camera.whiteBalanceLock?.isLockable, presentAnd(`is`(false)))
        assertThat(camera.whiteBalanceLock, presentAnd(`is`(locked: false, updating: false)))
        assertThat(cnt, `is`(3))

        impl.update(whiteBalanceLockSupported: true).notifyUpdated()
        assertThat(camera.whiteBalanceLock?.isLockable, presentAnd(`is`(true)))
        assertThat(camera.whiteBalanceLock, presentAnd(`is`(locked: false, updating: false)))
        assertThat(cnt, `is`(4))

        camera.whiteBalanceLock?.setLock(lock: true)
        assertThat(camera.whiteBalanceLock, presentAnd(`is`(locked: true, updating: true)))
        assertThat(cnt, `is`(5))
        impl.update(whiteBalanceLock: true).notifyUpdated()
        assertThat(camera.whiteBalanceLock, presentAnd(`is`(locked: true, updating: false)))
        assertThat(cnt, `is`(6))

        camera.whiteBalanceLock?.setLock(lock: true)
        assertThat(camera.whiteBalanceLock, presentAnd(`is`(locked: true, updating: false)))
        assertThat(cnt, `is`(6))
    }

    func testExposureCompensation() {
        impl.update(supportedExposureCompensationValues: [.evMinus3_00, .ev0_00, .ev3_00])

        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }

        // test capabilities values
        assertThat(camera.exposureCompensationSetting, supports(
            exposureCompensationValues: [.evMinus3_00, .ev0_00, .ev3_00]))

        // test backend change notification
        impl.update(exposureCompensationValue: .ev3_00).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(camera.exposureCompensationSetting, `is`(value: .ev3_00, updating: false))

        // test setter
        camera.exposureCompensationSetting.value = .evMinus3_00
        assertThat(cnt, `is`(2))
        assertThat(camera.exposureCompensationSetting, `is`(value: .evMinus3_00, updating: true))
        assertThat(backend.exposureCompensation, presentAnd(`is`(.evMinus3_00)))
        impl.update(exposureCompensationValue: .evMinus3_00).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(camera.exposureCompensationSetting, `is`(value: .evMinus3_00, updating: false))

        // timeout should not do anything
        (camera.exposureCompensationSetting as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(3))
        assertThat(camera.exposureCompensationSetting, `is`(value: .evMinus3_00, updating: false))

        // unsupported value
        camera.exposureCompensationSetting.value = .ev0_67
        assertThat(cnt, `is`(3))
        assertThat(camera.exposureCompensationSetting, `is`(value: .evMinus3_00, updating: false))

        // change setting
        camera.exposureCompensationSetting.value = .ev0_00
        assertThat(cnt, `is`(4))
        assertThat(camera.exposureCompensationSetting, `is`(value: .ev0_00, updating: true))

        // mock timeout
        (camera.exposureCompensationSetting as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(camera.exposureCompensationSetting, `is`(value: .evMinus3_00, updating: false))

        // change setting from the api
        camera.exposureCompensationSetting.value = .ev0_00
        assertThat(cnt, `is`(6))
        assertThat(camera.exposureCompensationSetting, `is`(value: .ev0_00, updating: true))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(7))
        assertThat(camera.exposureCompensationSetting, `is`(value: .ev0_00, updating: false))

        // timeout should not be triggered since it has been canceled
        (camera.exposureCompensationSetting as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(7))
        assertThat(camera.exposureCompensationSetting, `is`(value: .ev0_00, updating: false))
    }

    func testWhiteBalance() {
        impl.update(supportedWhiteBalanceModes: Set<CameraWhiteBalanceMode>([.automatic, .sunny, .snow, .custom]))
        impl.update(supportedCustomWhiteBalanceTemperatures: Set<CameraWhiteBalanceTemperature>(
            [.k10000, .k3000, .k8000]))

        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }

        // test capabilities values
        assertThat(camera.whiteBalanceSettings, supports(
            whiteBalanceModes: [.automatic, .sunny, .snow, .custom],
            customTemperatures: [.k10000, .k3000, .k8000]))

        // test backend change notification
        impl.update(whiteBalanceMode: .custom).update(customWhiteBalanceTemperature: .k3000).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(camera.whiteBalanceSettings, `is`(mode: .custom, customTemperature: .k3000, updating: false))

        // test individial setters

        // mode
        camera.whiteBalanceSettings.mode = .snow
        assertThat(cnt, `is`(2))
        assertThat(camera.whiteBalanceSettings, `is`(mode: .snow, updating: true))
        assertThat(backend.whiteBalanceMode, presentAnd(`is`(.snow)))
        impl.update(whiteBalanceMode: .snow).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(camera.whiteBalanceSettings, `is`(mode: .snow, updating: false))
        // unsupported value
        camera.whiteBalanceSettings.mode = .sunset
        assertThat(cnt, `is`(3))
        assertThat(camera.whiteBalanceSettings, `is`(mode: .snow, updating: false))

        // change to custom
        camera.whiteBalanceSettings.mode = .custom
        assertThat(cnt, `is`(4))

        // custom temperature
        camera.whiteBalanceSettings.customTemperature = .k8000
        assertThat(cnt, `is`(5))
        assertThat(camera.whiteBalanceSettings, `is`(customTemperature: .k8000, updating: true))
        assertThat(backend.whiteBalanceCustomTemperature, presentAnd(`is`(.k8000)))
        impl.update(customWhiteBalanceTemperature: .k8000).notifyUpdated()
        assertThat(cnt, `is`(6))
        assertThat(camera.whiteBalanceSettings, `is`(customTemperature: .k8000, updating: false))

        // timeout should not do anything
        (camera.whiteBalanceSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(6))
        assertThat(camera.whiteBalanceSettings, `is`(customTemperature: .k8000, updating: false))

        // unsupported value
        camera.whiteBalanceSettings.customTemperature = .k3500
        assertThat(cnt, `is`(6))
        assertThat(camera.whiteBalanceSettings, `is`(customTemperature: .k8000, updating: false))

        // global setter
        camera.whiteBalanceSettings.set(mode: .custom, customTemperature: .k10000)
        assertThat(cnt, `is`(7))
        assertThat(camera.whiteBalanceSettings, `is`(mode: .custom, customTemperature: .k10000, updating: true))
        assertThat(backend.whiteBalanceMode, presentAnd(`is`(.custom)))
        assertThat(backend.whiteBalanceCustomTemperature, presentAnd(`is`(.k10000)))
        impl.update(whiteBalanceMode: .custom).update(customWhiteBalanceTemperature: .k10000).notifyUpdated()
        assertThat(cnt, `is`(8))
        assertThat(camera.whiteBalanceSettings, `is`(mode: .custom, customTemperature: .k10000, updating: false))

        // change setting
        camera.whiteBalanceSettings.set(mode: .snow, customTemperature: .k8000)
        assertThat(cnt, `is`(9))
        assertThat(camera.whiteBalanceSettings, `is`(mode: .snow, customTemperature: .k8000, updating: true))

        // mock timeout
        (camera.whiteBalanceSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(10))
        assertThat(camera.whiteBalanceSettings, `is`(mode: .custom, customTemperature: .k10000, updating: false))

        // change setting from the api
        camera.whiteBalanceSettings.set(mode: .snow, customTemperature: .k8000)
        assertThat(cnt, `is`(11))
        assertThat(camera.whiteBalanceSettings, `is`(mode: .snow, customTemperature: .k8000, updating: true))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(12))
        assertThat(camera.whiteBalanceSettings, `is`(mode: .snow, customTemperature: .k8000, updating: false))

        // timeout should not be triggered since it has been canceled
        (camera.whiteBalanceSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(12))
        assertThat(camera.whiteBalanceSettings, `is`(mode: .snow, customTemperature: .k8000, updating: false))
    }

    func testHdrSetting() {
        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }

        // test initial value
        assertThat(camera.hdrSetting, `is`(nilValue()))

        // update hdr setting, this must create the setting
        impl.update(hdrSetting: false).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(camera.hdrSetting, presentAnd(`is`(false)))

        // change setting
        camera.hdrSetting?.value = true
        assertThat(cnt, `is`(2))
        assertThat(camera.hdrSetting, presentAnd(allOf(`is`(true), isUpdating())))

        impl.update(hdrSetting: true).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(camera.hdrSetting, presentAnd(allOf(`is`(true), isUpToDate())))

        // timeout should not do anything
        (camera.hdrSetting as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(3))
        assertThat(camera.hdrSetting, presentAnd(allOf(`is`(true), isUpToDate())))

        // change setting
        camera.hdrSetting?.value = false
        assertThat(cnt, `is`(4))
        assertThat(camera.hdrSetting, presentAnd(allOf(`is`(false), isUpdating())))

        // mock timeout
        (camera.hdrSetting as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(camera.hdrSetting, presentAnd(allOf(`is`(true), isUpToDate())))

        // change setting from the api
        camera.hdrSetting?.value = false
        assertThat(cnt, `is`(6))
        assertThat(camera.hdrSetting, presentAnd(allOf(`is`(false), isUpdating())))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(7))
        assertThat(camera.hdrSetting, presentAnd(allOf(`is`(false), isUpToDate())))

        // timeout should not be triggered since it has been canceled
        (camera.hdrSetting as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(7))
        assertThat(camera.hdrSetting, presentAnd(allOf(`is`(false), isUpToDate())))
    }

    func testHdrState() {
        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }

        // test initial value
        assertThat(camera.hdrState, `is`(false))
        // backend change
        impl.update(hdrState: true).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(camera.hdrState, `is`(true))
    }

    func testActiveStyle() {
        impl.update(supportedStyles: [.standard, .plog])
        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }

        // test capabilities
        assertThat(camera.styleSettings, supports(styles: [.standard, .plog]))

        // test backend style change notification
        impl.update(activeStyle: .plog).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(camera.styleSettings, `is`(activeStyle: .plog, updating: false))

        // change style
        camera.styleSettings.activeStyle = .standard
        assertThat(cnt, `is`(2))
        assertThat(camera.styleSettings, `is`(activeStyle: .standard, updating: true))
        impl.update(activeStyle: .standard).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(camera.styleSettings, `is`(activeStyle: .standard, updating: false))

        // timeout should not do anything
        (camera.styleSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(3))
        assertThat(camera.styleSettings, `is`(activeStyle: .standard, updating: false))

        // test change to unsupported mode
        impl.update(supportedStyles: [.standard]).notifyUpdated()
        assertThat(cnt, `is`(4))
        camera.styleSettings.activeStyle = .plog
        assertThat(cnt, `is`(4))
        assertThat(camera.styleSettings, `is`(activeStyle: .standard, updating: false))

        // change setting
        impl.update(supportedStyles: [.standard, .plog])
        camera.styleSettings.activeStyle = .plog
        assertThat(cnt, `is`(5))
        assertThat(camera.styleSettings, `is`(activeStyle: .plog, updating: true))

        // mock timeout
        (camera.styleSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(6))
        assertThat(camera.styleSettings, `is`(activeStyle: .standard, updating: false))

        // change setting from the api
        camera.styleSettings.activeStyle = .plog
        assertThat(cnt, `is`(7))
        assertThat(camera.styleSettings, `is`(activeStyle: .plog, updating: true))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(8))
        assertThat(camera.styleSettings, `is`(activeStyle: .plog, updating: false))

        // timeout should not be triggered since it has been canceled
        (camera.styleSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(8))
        assertThat(camera.styleSettings, `is`(activeStyle: .plog, updating: false))
    }

    func testStyleParameter() {
        impl.update(supportedStyles: [.standard])
        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }

        // test backend notification
        impl.update(saturation: (-2, 1, 2))
        impl.update(contrast: (-4, 2, 4))
        impl.update(sharpness: (-6, 3, 6))
            .notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(camera.styleSettings, `is`(
            activeStyle: .standard, saturation: (-2, 1, 2), contrast: (-4, 2, 4), sharpness: (-6, 3, 6),
            updating: false))

        // change saturation
        camera.styleSettings.saturation.value = -1
        assertThat(cnt, `is`(2))
        assertThat(camera.styleSettings, `is`(
            activeStyle: .standard, saturation: (-2, -1, 2), contrast: (-4, 2, 4), sharpness: (-6, 3, 6),
            updating: true))
        impl.update(saturation: (-2, -1, 2))
        impl.update(contrast: (-4, 2, 4))
        impl.update(sharpness: (-6, 3, 6))
            .notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(camera.styleSettings, `is`(
            activeStyle: .standard, saturation: (-2, -1, 2), contrast: (-4, 2, 4), sharpness: (-6, 3, 6),
            updating: false))

        // change contrast
        camera.styleSettings.contrast.value = -2
        assertThat(cnt, `is`(4))
        assertThat(camera.styleSettings, `is`(
            activeStyle: .standard, saturation: (-2, -1, 2), contrast: (-4, -2, 4), sharpness: (-6, 3, 6),
            updating: true))
        impl.update(saturation: (-2, -1, 2))
        impl.update(contrast: (-4, -2, 4))
        impl.update(sharpness: (-6, 3, 6))
            .notifyUpdated()

        assertThat(cnt, `is`(5))
        assertThat(camera.styleSettings, `is`(
            activeStyle: .standard, saturation: (-2, -1, 2), contrast: (-4, -2, 4), sharpness: (-6, 3, 6),
            updating: false))

        // timeout should not do anything
        (camera.styleSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(camera.styleSettings, `is`(
            activeStyle: .standard, saturation: (-2, -1, 2), contrast: (-4, -2, 4), sharpness: (-6, 3, 6),
            updating: false))

        // change sharpness
        camera.styleSettings.sharpness.value = -3
        assertThat(cnt, `is`(6))
        assertThat(camera.styleSettings, `is`(
            activeStyle: .standard, saturation: (-2, -1, 2), contrast: (-4, -2, 4), sharpness: (-6, -3, 6),
            updating: true))
        impl.update(saturation: (-2, -1, 2))
        impl.update(contrast: (-4, -2, 4))
        impl.update(sharpness: (-6, -3, 6))
            .notifyUpdated()
        assertThat(cnt, `is`(7))
        assertThat(camera.styleSettings, `is`(
            activeStyle: .standard, saturation: (-2, -1, 2), contrast: (-4, -2, 4), sharpness: (-6, -3, 6),
            updating: false))

        // change setting
        camera.styleSettings.sharpness.value = -2
        assertThat(cnt, `is`(8))
        assertThat(camera.styleSettings, `is`(
            activeStyle: .standard, saturation: (-2, -1, 2), contrast: (-4, -2, 4), sharpness: (-6, -2, 6),
            updating: true))

        // mock timeout
        (camera.styleSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(9))
        assertThat(camera.styleSettings, `is`(
            activeStyle: .standard, saturation: (-2, -1, 2), contrast: (-4, -2, 4), sharpness: (-6, -3, 6),
            updating: false))

        // change setting from the api
        camera.styleSettings.sharpness.value = -2
        assertThat(cnt, `is`(10))
        assertThat(camera.styleSettings, `is`(
            activeStyle: .standard, saturation: (-2, -1, 2), contrast: (-4, -2, 4), sharpness: (-6, -2, 6),
            updating: true))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(11))
        assertThat(camera.styleSettings, `is`(
            activeStyle: .standard, saturation: (-2, -1, 2), contrast: (-4, -2, 4), sharpness: (-6, -2, 6),
            updating: false))

        // timeout should not be triggered since it has been canceled
        (camera.styleSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(11))
        assertThat(camera.styleSettings, `is`(
            activeStyle: .standard, saturation: (-2, -1, 2), contrast: (-4, -2, 4), sharpness: (-6, -2, 6),
            updating: false))
    }

    func testStyleParameterOutOfRange() {
        impl.update(supportedStyles: [.standard])
        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }
        impl.update(saturation: (-2, 1, 2))
        impl.update(contrast: (-4, 2, 4))
        impl.update(sharpness: (-6, 3, 6))
            .notifyUpdated()
        assertThat(cnt, `is`(1))

        // change sharpness to a out of range value
        camera.styleSettings.saturation.value = -5
        assertThat(cnt, `is`(2))
        assertThat(camera.styleSettings, `is`(
            activeStyle: .standard, saturation: (-2, -2, 2), updating: true))
   }

    func testNonMutableStyleParam() {
        impl.update(supportedStyles: [.standard])
        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }
        impl.update(saturation: (0, 0, 0))
        impl.update(contrast: (-4, 2, 4))
        impl.update(sharpness: (-6, 3, 6))
            .notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(camera.styleSettings.saturation.mutable, `is`(false))
        assertThat(camera.styleSettings.contrast.mutable, `is`(true))
        assertThat(camera.styleSettings.sharpness.mutable, `is`(true))
    }

    func testRecordingMode() {
        impl.update(recordingCapabilities: [
            CameraCore.RecordingCapabilitiesEntry(
                modes: [.standard, .hyperlapse], resolutions: [.resUhd4k],
                framerates: [.fps24, .fps25, .fps30], hdrAvailable: false),
            CameraCore.RecordingCapabilitiesEntry(
                modes: [.standard, .hyperlapse], resolutions: [.res1080p],
                framerates: [.fps24, .fps25], hdrAvailable: true),
            CameraCore.RecordingCapabilitiesEntry(
                modes: [.standard, .hyperlapse], resolutions: [.res1080p],
                framerates: [.fps30], hdrAvailable: false),
            CameraCore.RecordingCapabilitiesEntry(
                modes: [.hyperlapse], resolutions: [.res720p], framerates: [.fps60], hdrAvailable: false),
            CameraCore.RecordingCapabilitiesEntry(
                modes: [.highFramerate], resolutions: [.res720p], framerates: [.fps120], hdrAvailable: false)
            ])
        impl.update(supportedRecordingHyperlapseValues: [.ratio15, .ratio30, .ratio240])
        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }

        // test capabilities values
        assertThat(camera.recordingSettings, supports(
            recordingModes: [.standard, .hyperlapse, .highFramerate],
            hyperlapseValues: [.ratio15, .ratio30, .ratio240]))
        assertThat(camera.recordingSettings, supports(
            forMode: .standard, resolutions: [.resUhd4k, .res1080p]))
        assertThat(camera.recordingSettings, supports(
            forMode: .hyperlapse, resolutions: [.resUhd4k, .res1080p, .res720p]))
        assertThat(camera.recordingSettings, supports(
            forMode: .highFramerate, resolutions: [.res720p]))
        assertThat(camera.recordingSettings, supports(
            forMode: .slowMotion, resolutions: []))
        assertThat(camera.recordingSettings, supports(
            forMode: .standard, resolution: .resUhd4k, framerates: [.fps24, .fps25, .fps30]))
        assertThat(camera.recordingSettings, supports(
            forMode: .standard, resolution: .res1080p, framerates: [.fps24, .fps25, .fps30]))
        assertThat(camera.recordingSettings, supports(
            forMode: .hyperlapse, resolution: .resUhd4k, framerates: [.fps24, .fps25, .fps30]))
        assertThat(camera.recordingSettings, supports(
            forMode: .hyperlapse, resolution: .res1080p, framerates: [.fps24, .fps25, .fps30]))
        assertThat(camera.recordingSettings, supports(
            forMode: .hyperlapse, resolution: .res720p, framerates: [.fps60]))
        assertThat(camera.recordingSettings, supports(
            forMode: .highFramerate, resolution: .res720p, framerates: [.fps120]))

        assertThat(camera.recordingSettings, `is`(
            hdrAvailable: false, forMode: .standard, resolution: .resUhd4k, framerate: .fps24))
        assertThat(camera.recordingSettings, `is`(
            hdrAvailable: false, forMode: .standard, resolution: .resUhd4k, framerate: .fps25))
        assertThat(camera.recordingSettings, `is`(
            hdrAvailable: false, forMode: .standard, resolution: .resUhd4k, framerate: .fps30))
        assertThat(camera.recordingSettings, `is`(
            hdrAvailable: false, forMode: .hyperlapse, resolution: .resUhd4k, framerate: .fps24))
        assertThat(camera.recordingSettings, `is`(
            hdrAvailable: false, forMode: .hyperlapse, resolution: .resUhd4k, framerate: .fps25))
        assertThat(camera.recordingSettings, `is`(
            hdrAvailable: false, forMode: .hyperlapse, resolution: .resUhd4k, framerate: .fps30))
        assertThat(camera.recordingSettings, `is`(
            hdrAvailable: true, forMode: .standard, resolution: .res1080p, framerate: .fps24))
        assertThat(camera.recordingSettings, `is`(
            hdrAvailable: true, forMode: .standard, resolution: .res1080p, framerate: .fps25))
        assertThat(camera.recordingSettings, `is`(
            hdrAvailable: false, forMode: .standard, resolution: .res1080p, framerate: .fps30))
        assertThat(camera.recordingSettings, `is`(
            hdrAvailable: true, forMode: .hyperlapse, resolution: .res1080p, framerate: .fps24))
        assertThat(camera.recordingSettings, `is`(
            hdrAvailable: true, forMode: .hyperlapse, resolution: .res1080p, framerate: .fps25))
        assertThat(camera.recordingSettings, `is`(
            hdrAvailable: false, forMode: .hyperlapse, resolution: .res1080p, framerate: .fps30))

        // test backend change notification
        impl.update(recordingMode: .standard).update(recordingResolution: .resUhd4k)
            .update(recordingFramerate: .fps25).update(recordingHyperlapseValue: .ratio30).notifyUpdated()

        assertThat(cnt, `is`(1))
        assertThat(camera.recordingSettings, `is`(
            mode: .standard, resolution: .resUhd4k, framerate: .fps25, hyperlapse: .ratio30, updating: false))
        assertThat(camera.recordingSettings, `is`(hdrAvailable: false))

        // test individial setters

        // mode
        camera.recordingSettings.mode = .hyperlapse
        assertThat(cnt, `is`(2))
        assertThat(camera.recordingSettings, `is`(mode: .hyperlapse, updating: true))
        assertThat(backend.recordingMode, presentAnd(`is`(.hyperlapse)))
        // check that capabilities have change
        assertThat(camera.recordingSettings, supports(
            resolutions: [.resUhd4k, .res1080p, .res720p], framerates: [.fps24, .fps25, .fps30]))
        assertThat(camera.recordingSettings, `is`(hdrAvailable: false))
        // backend response
        impl.update(recordingMode: .hyperlapse).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(camera.recordingSettings, `is`(mode: .hyperlapse, updating: false))

        // timeout should not do anything
        (camera.recordingSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(3))
        assertThat(camera.recordingSettings, `is`(mode: .hyperlapse, updating: false))

        // unsupported value
        camera.recordingSettings.mode = .slowMotion
        assertThat(cnt, `is`(3))
        assertThat(camera.recordingSettings, `is`(mode: .hyperlapse, updating: false))

        // resolution
        camera.recordingSettings.resolution = .res1080p
        assertThat(cnt, `is`(4))
        assertThat(camera.recordingSettings, `is`(hdrAvailable: true))
        assertThat(camera.recordingSettings, `is`(resolution: .res1080p, updating: true))
        assertThat(backend.recordingResolution, presentAnd(`is`(.res1080p)))
        impl.update(recordingResolution: .res1080p).notifyUpdated()
        assertThat(cnt, `is`(5))
        assertThat(camera.recordingSettings, `is`(resolution: .res1080p, updating: false))

        // timeout should not do anything
        (camera.recordingSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(camera.recordingSettings, `is`(resolution: .res1080p, updating: false))

        // unsupported value
        camera.recordingSettings.resolution = .res2_7k
        assertThat(cnt, `is`(5))
        assertThat(camera.recordingSettings, `is`(resolution: .res1080p, updating: false))

        // framerate
        camera.recordingSettings.framerate = .fps30
        assertThat(cnt, `is`(6))
        assertThat(camera.recordingSettings, `is`(hdrAvailable: false))
        assertThat(camera.recordingSettings, `is`(framerate: .fps30, updating: true))
        assertThat(backend.recordingFramerate, presentAnd(`is`(.fps30)))
        impl.update(recordingFramerate: .fps30).notifyUpdated()
        assertThat(cnt, `is`(7))
        assertThat(camera.recordingSettings, `is`(framerate: .fps30, updating: false))

        // timeout should not do anything
        (camera.recordingSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(7))
        assertThat(camera.recordingSettings, `is`(framerate: .fps30, updating: false))

        // unsupported value
        camera.recordingSettings.framerate = .fps120
        assertThat(cnt, `is`(7))
        assertThat(camera.recordingSettings, `is`(framerate: .fps30, updating: false))

        // hyperlapse
        camera.recordingSettings.hyperlapseValue = .ratio15
        assertThat(cnt, `is`(8))
        assertThat(camera.recordingSettings, `is`(hyperlapse: .ratio15, updating: true))
        assertThat(backend.recordingHyperlapse, presentAnd(`is`(.ratio15)))
        impl.update(recordingHyperlapseValue: .ratio15).notifyUpdated()
        assertThat(cnt, `is`(9))
        assertThat(camera.recordingSettings, `is`(hyperlapse: .ratio15, updating: false))

        // timeout should not do anything
        (camera.recordingSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(9))
        assertThat(camera.recordingSettings, `is`(hyperlapse: .ratio15, updating: false))

        // unsupported value
        camera.recordingSettings.hyperlapseValue = .ratio120
        assertThat(cnt, `is`(9))
        assertThat(camera.recordingSettings, `is`(hyperlapse: .ratio15, updating: false))

        // global setter
        camera.recordingSettings.set(
            mode: .highFramerate, resolution: .res720p, framerate: .fps120, hyperlapseValue: .ratio240)
        assertThat(cnt, `is`(10))
        assertThat(camera.recordingSettings, `is`(
            mode: .highFramerate, resolution: .res720p, framerate: .fps120, hyperlapse: .ratio240, updating: true))
        assertThat(backend.recordingMode, presentAnd(`is`(.highFramerate)))
        assertThat(backend.recordingResolution, presentAnd(`is`(.res720p)))
        assertThat(backend.recordingFramerate, presentAnd(`is`(.fps120)))
        assertThat(backend.recordingHyperlapse, presentAnd(`is`(.ratio240)))
        impl.update(recordingMode: .slowMotion).update(recordingResolution: .res1080p)
            .update(recordingFramerate: .fps60)
            .update(recordingHyperlapseValue: .ratio240).notifyUpdated()
        assertThat(cnt, `is`(11))
        assertThat(camera.recordingSettings, `is`(
            mode: .slowMotion, resolution: .res1080p, framerate: .fps60, hyperlapse: .ratio240, updating: false))

        // change setting
        camera.recordingSettings.mode = .standard
        assertThat(cnt, `is`(12))
        assertThat(camera.recordingSettings, `is`(
            mode: .standard, resolution: .res1080p, framerate: .fps60, hyperlapse: .ratio240, updating: true))

        // mock timeout
        (camera.recordingSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(13))
        assertThat(camera.recordingSettings, `is`(
            mode: .slowMotion, resolution: .res1080p, framerate: .fps60, hyperlapse: .ratio240, updating: false))

        // change setting
        camera.recordingSettings.set(
            mode: .highFramerate, resolution: .res720p, framerate: .fps120, hyperlapseValue: .ratio240)
        assertThat(cnt, `is`(14))
        assertThat(camera.recordingSettings, `is`(
            mode: .highFramerate, resolution: .res720p, framerate: .fps120, hyperlapse: .ratio240, updating: true))

        // mock timeout
        (camera.recordingSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(15))
        assertThat(camera.recordingSettings, `is`(
            mode: .slowMotion, resolution: .res1080p, framerate: .fps60, hyperlapse: .ratio240, updating: false))

        // change setting from the api
        camera.recordingSettings.set(
            mode: .highFramerate, resolution: .res720p, framerate: .fps120, hyperlapseValue: .ratio240)
        assertThat(cnt, `is`(16))
        assertThat(camera.recordingSettings, `is`(
            mode: .highFramerate, resolution: .res720p, framerate: .fps120, hyperlapse: .ratio240, updating: true))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(17))
        assertThat(camera.recordingSettings, `is`(
            mode: .highFramerate, resolution: .res720p, framerate: .fps120, hyperlapse: .ratio240, updating: false))

        // timeout should not be triggered since it has been canceled
        (camera.recordingSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(17))
        assertThat(camera.recordingSettings, `is`(
            mode: .highFramerate, resolution: .res720p, framerate: .fps120, hyperlapse: .ratio240, updating: false))
    }

    func testAutoRecord() {
        impl.publish()

        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }

        // test initial value
        assertThat(camera.autoRecordSetting, `is`(nilValue()))

        // test backend change notification
        impl.update(autoRecord: true).notifyUpdated()
        assertThat(camera.autoRecordSetting, presentAnd(`is`(true)))
        assertThat(cnt, `is`(1))

        // change setting
        camera.autoRecordSetting?.value = false
        assertThat(cnt, `is`(2))
        assertThat(camera.autoRecordSetting, presentAnd(allOf(`is`(false), isUpdating())))

        impl.update(autoRecord: false).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(camera.autoRecordSetting, presentAnd(allOf(`is`(false), isUpToDate())))

        // timeout should not do anything
        (camera.autoRecordSetting as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(3))
        assertThat(camera.autoRecordSetting, presentAnd(allOf(`is`(false), isUpToDate())))

        // change setting
        camera.autoRecordSetting?.value = true
        assertThat(cnt, `is`(4))
        assertThat(camera.autoRecordSetting, presentAnd(allOf(`is`(true), isUpdating())))

        // mock timeout
        (camera.autoRecordSetting as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(camera.autoRecordSetting, presentAnd(allOf(`is`(false), isUpToDate())))

        // change setting from the api
        camera.autoRecordSetting?.value = true
        assertThat(cnt, `is`(6))
        assertThat(camera.autoRecordSetting, presentAnd(allOf(`is`(true), isUpdating())))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(7))
        assertThat(camera.autoRecordSetting, presentAnd(allOf(`is`(true), isUpToDate())))

        // timeout should not be triggered since it has been canceled
        (camera.autoRecordSetting as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(7))
        assertThat(camera.autoRecordSetting, presentAnd(allOf(`is`(true), isUpToDate())))
    }

    func testPhotoMode() {
        impl.update(photoCapabilities: [
            CameraCore.PhotoCapabilitiesEntry(
                modes: [.single, .gpsLapse, .timeLapse], formats: [.rectilinear], fileFormats: [.jpeg],
                hdrAvailable: true),
            CameraCore.PhotoCapabilitiesEntry(
                modes: [.burst], formats: [.rectilinear, .large], fileFormats: [.jpeg], hdrAvailable: true),
            CameraCore.PhotoCapabilitiesEntry(
                modes: [.single], formats: [.fullFrame], fileFormats: [.dngAndJpeg, .jpeg], hdrAvailable: true),
            CameraCore.PhotoCapabilitiesEntry(
                modes: [.gpsLapse], formats: [.fullFrame], fileFormats: [.jpeg], hdrAvailable: true),
            CameraCore.PhotoCapabilitiesEntry(
            modes: [.timeLapse], formats: [.fullFrame], fileFormats: [.dngAndJpeg], hdrAvailable: true)
            ])
        impl.update(supportedPhotoBurstValues: [.burst10Over2s, .burst14Over1s, .burst4Over1s])
        impl.update(supportedPhotoBracketingValues: [.preset1ev, .preset1ev2ev, .preset1ev2ev3ev])
        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }

        // test capabilities values
        assertThat (camera.photoSettings, supports(
            photoModes: [.single, .burst, .gpsLapse, .timeLapse],
            burstValues: [.burst10Over2s, .burst14Over1s, .burst4Over1s],
            bracketingValues: [.preset1ev, .preset1ev2ev, .preset1ev2ev3ev]))
        assertThat(camera.photoSettings, supports(forMode: .single, formats: [.fullFrame, .rectilinear]))
        assertThat(camera.photoSettings, supports(forMode: .burst, formats: [.rectilinear, .large]))
        assertThat(camera.photoSettings, supports(
            forMode: .single, format: .fullFrame, fileFormats: [.dngAndJpeg, .jpeg]))
        assertThat(camera.photoSettings, supports(forMode: .single, format: .rectilinear, fileFormats: [.jpeg]))
        assertThat(camera.photoSettings, supports(forMode: .burst, format: .rectilinear, fileFormats: [.jpeg]))

        assertThat(camera.photoSettings, supports(forMode: .gpsLapse, formats: [.fullFrame, .rectilinear]))
        assertThat(camera.photoSettings, supports(forMode: .timeLapse, formats: [.fullFrame, .rectilinear]))
        assertThat(camera.photoSettings, supports(forMode: .gpsLapse, format: .rectilinear, fileFormats: [.jpeg]))
        assertThat(camera.photoSettings, supports(forMode: .gpsLapse, format: .fullFrame, fileFormats: [.jpeg]))
        assertThat(camera.photoSettings, supports(forMode: .timeLapse, format: .fullFrame, fileFormats: [.dngAndJpeg]))
        assertThat(camera.photoSettings, supports(forMode: .timeLapse, format: .rectilinear, fileFormats: [.jpeg]))

        assertThat(camera.photoSettings, `is`(
            hdrAvailable: true, forMode: .single, format: .rectilinear, fileFormat: .jpeg))
        assertThat(camera.photoSettings, `is`(
            hdrAvailable: true, forMode: .single, format: .fullFrame, fileFormat: .dngAndJpeg))
        assertThat(camera.photoSettings, `is`(
            hdrAvailable: true, forMode: .single, format: .fullFrame, fileFormat: .jpeg))
        assertThat(camera.photoSettings, `is`(
            hdrAvailable: true, forMode: .burst, format: .rectilinear, fileFormat: .jpeg))
        assertThat(camera.photoSettings, `is`(
            hdrAvailable: true, forMode: .burst, format: .large, fileFormat: .jpeg))

        // test backend change notification
        impl.update(photoMode: .single).update(photoFormat: .fullFrame).update(photoFileFormat: .dng)
            .update(photoBurstValue: .burst10Over2s).update(photoBracketingValue: .preset1ev).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(camera.photoSettings, `is`(
            mode: .single, format: .fullFrame, fileFormat: .dng, burst: .burst10Over2s,
            bracketing: .preset1ev, updating: false))
        assertThat(camera.photoSettings, `is`(hdrAvailable: false))

        // test individial setters

        // mode
        camera.photoSettings.mode = .burst
        assertThat(cnt, `is`(2))
        assertThat(camera.photoSettings, `is`(mode: .burst, updating: true))
        assertThat(backend.photoMode, presentAnd(`is`(.burst)))
        // check that capabilities have change
        assertThat(camera.photoSettings, supports(formats: [.rectilinear, .large]))
        assertThat(camera.photoSettings, `is`(hdrAvailable: false))
        // backend response
        impl.update(photoMode: .burst).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(camera.photoSettings, `is`(mode: .burst, updating: false))

        // unsupported value
        camera.photoSettings.mode = .gpsLapse
        assertThat(cnt, `is`(4))
        assertThat(camera.photoSettings, `is`(mode: .gpsLapse, updating: true))
        impl.update(photoMode: .gpsLapse).notifyUpdated()
        assertThat(cnt, `is`(5))

        // unsupported value
        camera.photoSettings.mode = .timeLapse
        assertThat(cnt, `is`(6))
        assertThat(camera.photoSettings, `is`(mode: .timeLapse, updating: true))
        impl.update(photoMode: .timeLapse).notifyUpdated()

        // timeout should not do anything
        (camera.photoSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(7))
        assertThat(camera.photoSettings, `is`(mode: .timeLapse, updating: false))

        camera.photoSettings.mode = .burst
        assertThat(cnt, `is`(8))
        assertThat(camera.photoSettings, `is`(mode: .burst, updating: true))
        impl.update(photoMode: .burst).notifyUpdated()
        assertThat(cnt, `is`(9))
        assertThat(camera.photoSettings, `is`(mode: .burst, updating: false))

        // unsupported value
        camera.photoSettings.mode = .bracketing
        assertThat(cnt, `is`(9))
        assertThat(camera.photoSettings, `is`(mode: .burst, updating: false))

        // format
        camera.photoSettings.format = .rectilinear
        assertThat(cnt, `is`(10))
        assertThat(camera.photoSettings, `is`(format: .rectilinear, updating: true))
        assertThat(backend.photoFormat, presentAnd(`is`(.rectilinear)))
        // check that capabilities have change
        assertThat(camera.photoSettings, supports(fileFormats: [.jpeg]))
        assertThat(camera.photoSettings, `is`(hdrAvailable: false))
        // backend response
        impl.update(photoFormat: .rectilinear).notifyUpdated()
        assertThat(cnt, `is`(11))
        assertThat(camera.photoSettings, `is`(format: .rectilinear, updating: false))
        // timeout should not do anything
        (camera.photoSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(11))
        assertThat(camera.photoSettings, `is`(format: .rectilinear, updating: false))
        // unsupported value
        camera.photoSettings.format = .fullFrame
        assertThat(cnt, `is`(11))
        assertThat(camera.photoSettings, `is`(format: .rectilinear, updating: false))

        // fileformat
        camera.photoSettings.fileFormat = .jpeg
        assertThat(cnt, `is`(12))
        assertThat(camera.photoSettings, `is`(fileFormat: .jpeg, updating: true))
        assertThat(backend.photoFileFormat, presentAnd(`is`(.jpeg)))
        assertThat(camera.photoSettings, `is`(hdrAvailable: true))
        impl.update(photoFileFormat: .jpeg).notifyUpdated()
        assertThat(cnt, `is`(13))
        assertThat(camera.photoSettings, `is`(fileFormat: .jpeg, updating: false))
        // timeout should not do anything
        (camera.photoSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(13))
        assertThat(camera.photoSettings, `is`(fileFormat: .jpeg, updating: false))
        // unsupported value
        camera.photoSettings.fileFormat = .dng
        assertThat(cnt, `is`(13))
        assertThat(camera.photoSettings, `is`(fileFormat: .jpeg, updating: false))

        // burst
        camera.photoSettings.burstValue = .burst14Over1s
        assertThat(cnt, `is`(14))
        assertThat(camera.photoSettings, `is`(burst: .burst14Over1s, updating: true))
        assertThat(backend.photoBurst, presentAnd(`is`(.burst14Over1s)))
        impl.update(photoBurstValue: .burst14Over1s).notifyUpdated()
        assertThat(cnt, `is`(15))
        assertThat(camera.photoSettings, `is`(burst: .burst14Over1s, updating: false))
        // timeout should not do anything
        (camera.photoSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(15))
        assertThat(camera.photoSettings, `is`(burst: .burst14Over1s, updating: false))
        // unsupported value
        camera.photoSettings.burstValue = .burst14Over4s
        assertThat(cnt, `is`(15))
        assertThat(camera.photoSettings, `is`(burst: .burst14Over1s, updating: false))

        // bracketing
        camera.photoSettings.bracketingValue = .preset1ev2ev
        assertThat(cnt, `is`(16))
        assertThat(camera.photoSettings, `is`(bracketing: .preset1ev2ev, updating: true))
        assertThat(backend.photoBracketing, presentAnd(`is`(.preset1ev2ev)))
        impl.update(photoBracketingValue: .preset1ev2ev).notifyUpdated()
        assertThat(cnt, `is`(17))
        assertThat(camera.photoSettings, `is`(bracketing: .preset1ev2ev, updating: false))
        // timeout should not do anything
        (camera.photoSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(17))
        assertThat(camera.photoSettings, `is`(bracketing: .preset1ev2ev, updating: false))
        // unsupported value
        camera.photoSettings.bracketingValue = .preset2ev
        assertThat(cnt, `is`(17))
        assertThat(camera.photoSettings, `is`(bracketing: .preset1ev2ev, updating: false))

        // global setter
        camera.photoSettings.set(mode: .single, format: .fullFrame, fileFormat: .dngAndJpeg,
                                 burstValue: .burst10Over2s, bracketingValue: .preset1ev2ev3ev,
                                 gpslapseCaptureIntervalValue: 0.0, timelapseCaptureIntervalValue: 0.0)
        assertThat(cnt, `is`(18))
        assertThat(camera.photoSettings, `is`(
            mode: .single, format: .fullFrame, fileFormat: .dngAndJpeg, burst: .burst10Over2s,
            bracketing: .preset1ev2ev3ev, updating: true))
        assertThat(backend.photoMode, presentAnd(`is`(.single)))
        assertThat(backend.photoFormat, presentAnd(`is`(.fullFrame)))
        assertThat(backend.photoFileFormat, presentAnd(`is`(.dngAndJpeg)))
        assertThat(backend.photoBurst, presentAnd(`is`(.burst10Over2s)))
        assertThat(backend.photoBracketing, presentAnd(`is`(.preset1ev2ev3ev)))
        impl.update(photoMode: .single).update(photoFormat: .fullFrame).update(photoFileFormat: .dngAndJpeg)
            .update(photoBurstValue: .burst10Over2s).update(photoBracketingValue: .preset1ev2ev3ev).notifyUpdated()
        assertThat(cnt, `is`(19))
        assertThat(camera.photoSettings, `is`(
            mode: .single, format: .fullFrame, fileFormat: .dngAndJpeg, burst: .burst10Over2s,
            bracketing: .preset1ev2ev3ev, updating: false))

        // timeout should not do anything
        (camera.photoSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(19))
        assertThat(camera.photoSettings, `is`(
            mode: .single, format: .fullFrame, fileFormat: .dngAndJpeg, burst: .burst10Over2s,
            bracketing: .preset1ev2ev3ev, updating: false))

        // change setting
        camera.photoSettings.mode = .burst
        assertThat(cnt, `is`(20))
        assertThat(camera.photoSettings, `is`(
            mode: .burst, format: .fullFrame, fileFormat: .dngAndJpeg, burst: .burst10Over2s,
            bracketing: .preset1ev2ev3ev, updating: true))

        // mock timeout
        (camera.photoSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(21))
        assertThat(camera.photoSettings, `is`(
            mode: .single, format: .fullFrame, fileFormat: .dngAndJpeg, burst: .burst10Over2s,
            bracketing: .preset1ev2ev3ev, updating: false))

        // change setting
        camera.photoSettings.set(mode: .burst, format: .rectilinear, fileFormat: .jpeg,
                                 burstValue: .burst14Over1s, bracketingValue: .preset1ev,
                                 gpslapseCaptureIntervalValue: 0.0, timelapseCaptureIntervalValue: 0.0)
        assertThat(cnt, `is`(22))
        assertThat(camera.photoSettings, `is`(
            mode: .burst, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over1s,
            bracketing: .preset1ev, updating: true))

        // mock timeout
        (camera.photoSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(23))
        assertThat(camera.photoSettings, `is`(
            mode: .single, format: .fullFrame, fileFormat: .dngAndJpeg, burst: .burst10Over2s,
            bracketing: .preset1ev2ev3ev, updating: false))

        // change setting from the api
        camera.photoSettings.set(mode: .burst, format: .rectilinear, fileFormat: .jpeg,
                                 burstValue: .burst14Over1s, bracketingValue: .preset1ev,
                                 gpslapseCaptureIntervalValue: 0.0, timelapseCaptureIntervalValue: 0.0)
        assertThat(cnt, `is`(24))
        assertThat(camera.photoSettings, `is`(
            mode: .burst, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over1s,
            bracketing: .preset1ev, updating: true))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(25))
        assertThat(camera.photoSettings, `is`(
            mode: .burst, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over1s,
            bracketing: .preset1ev, updating: false))

        // timeout should not be triggered since it has been canceled
        (camera.photoSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(25))
        assertThat(camera.photoSettings, `is`(
            mode: .burst, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over1s,
            bracketing: .preset1ev, updating: false))
    }

    func testMaxZoomSpeed() {
        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }

        // test initial value
        assertThat(camera.zoom?.maxSpeed, nilValue())
        assertThat(backend.maxZoomSpeed, nilValue())

        // backend set the setting
        impl.update(maxZoomSpeedLowerBound: 2.0, maxZoomSpeed: 5.0, maxZoomSpeedUpperBound: 10.0)
            .notifyUpdated()
        assertThat(camera.zoom?.maxSpeed, presentAnd(allOf(`is`(2.0, 5.0, 10.0), isUpToDate())))
        assertThat(cnt, `is`(1))

        // update the value from the api
        camera.zoom?.maxSpeed.value = 7.0
        assertThat(camera.zoom?.maxSpeed, presentAnd(allOf(`is`(2.0, 7.0, 10.0), isUpdating())))
        assertThat(backend.maxZoomSpeed, presentAnd(`is`(7.0)))
        assertThat(cnt, `is`(2))

        // mock update from backend
        impl.update(maxZoomSpeedLowerBound: 2.0, maxZoomSpeed: 7.0, maxZoomSpeedUpperBound: 10.0)
            .notifyUpdated()
        assertThat(camera.zoom?.maxSpeed, presentAnd(allOf(`is`(2.0, 7.0, 10.0), isUpToDate())))
        assertThat(cnt, `is`(3))

        // timeout should not do anything
        (camera.zoom?.maxSpeed as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(3))
        assertThat(camera.zoom?.maxSpeed, presentAnd(allOf(`is`(2.0, 7.0, 10.0), isUpToDate())))

        // mock update with same values
        impl.update(maxZoomSpeedLowerBound: 2.0, maxZoomSpeed: 7.0, maxZoomSpeedUpperBound: 10.0)
            .notifyUpdated()
        assertThat(camera.zoom?.maxSpeed, presentAnd(allOf(`is`(2.0, 7.0, 10.0), isUpToDate())))
        assertThat(cnt, `is`(3))

        // change setting
        camera.zoom?.maxSpeed.value = 8.0
        assertThat(cnt, `is`(4))
        assertThat(camera.zoom?.maxSpeed, presentAnd(allOf(`is`(2.0, 8.0, 10.0), isUpdating())))

        // mock timeout
        (camera.zoom?.maxSpeed as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(camera.zoom?.maxSpeed, presentAnd(allOf(`is`(2.0, 7.0, 10.0), isUpToDate())))

        // change setting from the api
        camera.zoom?.maxSpeed.value = 8.0
        assertThat(cnt, `is`(6))
        assertThat(camera.zoom?.maxSpeed, presentAnd(allOf(`is`(2.0, 8.0, 10.0), isUpdating())))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(7))
        assertThat(camera.zoom?.maxSpeed, presentAnd(allOf(`is`(2.0, 8.0, 10.0), isUpToDate())))

        // timeout should not be triggered since it has been canceled
        (camera.photoSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(7))
        assertThat(camera.zoom?.maxSpeed, presentAnd(allOf(`is`(2.0, 8.0, 10.0), isUpToDate())))

        // check that reset zoom values does not reset the settings
        impl.resetZoomValues().notifyUpdated()
        assertThat(camera.zoom?.maxSpeed, presentAnd(allOf(`is`(2.0, 8.0, 10.0), isUpToDate())))
        assertThat(cnt, `is`(8)) // +1 because values of zoom have changed
    }

    func testZoomVelocityQualityDegradationAllowance() {
        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }

        // test initial value
        assertThat(camera.zoom?.velocityQualityDegradationAllowance, nilValue())
        assertThat(backend.qualityDegradation, nilValue())

        // mock receiving data in order to make zoom non nil
        impl.update(qualityDegradationAllowed: false).notifyUpdated()
        assertThat(camera.zoom?.velocityQualityDegradationAllowance, presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(backend.qualityDegradation, nilValue())
        assertThat(cnt, `is`(1))

        // update the value from the api
        camera.zoom?.velocityQualityDegradationAllowance.value = true
        assertThat(camera.zoom?.velocityQualityDegradationAllowance, presentAnd(allOf(`is`(true), isUpdating())))
        assertThat(backend.qualityDegradation, presentAnd(`is`(true)))
        assertThat(cnt, `is`(2))

        // mock rejection from backend
        impl.update(qualityDegradationAllowed: false).notifyUpdated()
        assertThat(camera.zoom?.velocityQualityDegradationAllowance, presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(cnt, `is`(3))

        // timeout should not do anything
        (camera.zoom?.velocityQualityDegradationAllowance as? TimeoutableSetting)?.mockTimeout()
        assertThat(camera.zoom?.velocityQualityDegradationAllowance, presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(cnt, `is`(3))

        // mock update from backend
        impl.update(qualityDegradationAllowed: true).notifyUpdated()
        assertThat(camera.zoom?.velocityQualityDegradationAllowance, presentAnd(allOf(`is`(true), isUpToDate())))
        assertThat(cnt, `is`(4))

        // change setting
        camera.zoom?.velocityQualityDegradationAllowance.value = false
        assertThat(cnt, `is`(5))
        assertThat(camera.zoom?.velocityQualityDegradationAllowance, presentAnd(allOf(`is`(false), isUpdating())))

        // mock timeout
        (camera.zoom?.velocityQualityDegradationAllowance as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(6))
        assertThat(camera.zoom?.velocityQualityDegradationAllowance, presentAnd(allOf(`is`(true), isUpToDate())))

        // change setting from the api
        camera.zoom?.velocityQualityDegradationAllowance.value = false
        assertThat(cnt, `is`(7))
        assertThat(camera.zoom?.velocityQualityDegradationAllowance, presentAnd(allOf(`is`(false), isUpdating())))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(8))
        assertThat(camera.zoom?.velocityQualityDegradationAllowance, presentAnd(allOf(`is`(false), isUpToDate())))

        // timeout should not be triggered since it has been canceled
        (camera.photoSettings as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(8))
        assertThat(camera.zoom?.velocityQualityDegradationAllowance, presentAnd(allOf(`is`(false), isUpToDate())))

        // check that reset zoom values does not reset the settings
        impl.resetZoomValues().notifyUpdated()
        assertThat(camera.zoom?.velocityQualityDegradationAllowance, presentAnd(allOf(`is`(false), isUpToDate())))
        assertThat(cnt, `is`(9)) // +1 because values of zoom have changed
    }

    func testZoomControl() {
        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }

        // test initial value
        assertThat(backend.zoomControlMode, nilValue())
        assertThat(backend.zoomTarget, nilValue())
        assertThat(camera.zoom, nilValue())

        // mock max value updated by the backend
        impl.update(maxLossyZoomLevel: 5.0).notifyUpdated()
        assertThat(camera.zoom, presentAnd(`is`(maxLossyLevel: 5.0)))
        assertThat(cnt, `is`(1))

        // change zoom level
        camera.zoom?.control(mode: .level, target: 2.0)
        assertThat(backend.zoomControlMode, presentAnd(`is`(.level)))
        assertThat(backend.zoomTarget, presentAnd(`is`(2.0)))

        // change zoom level
        camera.zoom?.control(mode: .level, target: 1.0)
        assertThat(backend.zoomControlMode, presentAnd(`is`(.level)))
        assertThat(backend.zoomTarget, presentAnd(`is`(1.0)))

        // check bounds
        camera.zoom?.control(mode: .level, target: 6.0)
        assertThat(backend.zoomControlMode, presentAnd(`is`(.level)))
        assertThat(backend.zoomTarget, presentAnd(`is`(5.0)))

        // check bounds
        camera.zoom?.control(mode: .level, target: 0.0)
        assertThat(backend.zoomControlMode, presentAnd(`is`(.level)))
        assertThat(backend.zoomTarget, presentAnd(`is`(1.0)))

        // change zoom velocity
        camera.zoom?.control(mode: .velocity, target: 0.5)
        assertThat(backend.zoomControlMode, presentAnd(`is`(.velocity)))
        assertThat(backend.zoomTarget, presentAnd(`is`(0.5)))

        // change zoom level
        camera.zoom?.control(mode: .velocity, target: -1.0)
        assertThat(backend.zoomControlMode, presentAnd(`is`(.velocity)))
        assertThat(backend.zoomTarget, presentAnd(`is`(-1.0)))

        // check bounds
        camera.zoom?.control(mode: .velocity, target: 1.2)
        assertThat(backend.zoomControlMode, presentAnd(`is`(.velocity)))
        assertThat(backend.zoomTarget, presentAnd(`is`(1.0)))

        // check bounds
        camera.zoom?.control(mode: .velocity, target: -1.5)
        assertThat(backend.zoomControlMode, presentAnd(`is`(.velocity)))
        assertThat(backend.zoomTarget, presentAnd(`is`(-1.0)))
    }

    func testZoomAvailability() {
        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }

        // test initial values
        assertThat(camera.zoom, nilValue())

        // mock update of the zoom availability
        impl.update(zoomIsAvailable: true).notifyUpdated()
        assertThat(camera.zoom, presentAnd(`is`(available: true)))
        assertThat(cnt, `is`(1))

        // mock update of the zoom availability with same value
        impl.update(zoomIsAvailable: true).notifyUpdated()
        assertThat(camera.zoom, presentAnd(`is`(available: true)))
        assertThat(cnt, `is`(1))

        // mock update of the zoom availability
        impl.update(zoomIsAvailable: false).notifyUpdated()
        assertThat(camera.zoom, presentAnd(`is`(available: false)))
        assertThat(cnt, `is`(2))

        // check that reset zoom values does reset the availability
        impl.resetZoomValues().notifyUpdated()
        assertThat(camera.zoom, presentAnd(`is`(available: false)))
        assertThat(cnt, `is`(3))
    }

    func testMaxLossyZoomLevel() {
        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }

        // test initial values
        assertThat(camera.zoom, nilValue())

        // mock update of the max lossy zoom level
        impl.update(maxLossyZoomLevel: 5.0).notifyUpdated()
        assertThat(camera.zoom, presentAnd(`is`(maxLossyLevel: 5.0)))
        assertThat(cnt, `is`(1))

        // mock update of the max lossy zoom level with same value
        impl.update(maxLossyZoomLevel: 5.0).notifyUpdated()
        assertThat(camera.zoom, presentAnd(`is`(maxLossyLevel: 5.0)))
        assertThat(cnt, `is`(1))

        // mock update of the max lossy zoom level
        impl.update(maxLossyZoomLevel: 2.0).notifyUpdated()
        assertThat(camera.zoom, presentAnd(`is`(maxLossyLevel: 2.0)))
        assertThat(cnt, `is`(2))

        // check that reset zoom values does reset max lossy level
        impl.resetZoomValues().notifyUpdated()
        assertThat(camera.zoom, presentAnd(`is`(maxLossyLevel: 1.0)))
        assertThat(cnt, `is`(3))
    }

    func testMaxLossLessZoomLevel() {
        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }

        // test initial values
        assertThat(camera.zoom, nilValue())

        // mock update of the max loss less zoom level
        impl.update(maxLossLessZoomLevel: 5.0).notifyUpdated()
        assertThat(camera.zoom, presentAnd(`is`(maxLossLessLevel: 5.0)))
        assertThat(cnt, `is`(1))

        // mock update of the max loss less zoom level with same value
        impl.update(maxLossLessZoomLevel: 5.0).notifyUpdated()
        assertThat(camera.zoom, presentAnd(`is`(maxLossLessLevel: 5.0)))
        assertThat(cnt, `is`(1))

        // mock update of the max loss less zoom level
        impl.update(maxLossLessZoomLevel: 1.0).notifyUpdated()
        assertThat(camera.zoom, presentAnd(`is`(maxLossLessLevel: 1.0)))
        assertThat(cnt, `is`(2))

        // check that reset zoom values does reset max lossless level
        impl.resetZoomValues().notifyUpdated()
        assertThat(camera.zoom, presentAnd(`is`(maxLossLessLevel: 1.0)))
        assertThat(cnt, `is`(3))
    }

    func testZoomLevel() {
        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }

        // test initial values
        assertThat(camera.zoom, nilValue())

        // mock update of the zoom level
        impl.update(currentZoomLevel: 5.0).notifyUpdated()
        assertThat(camera.zoom, presentAnd(`is`(currentLevel: 5.0)))
        assertThat(cnt, `is`(1))

        // mock update of the zoom level with same value
        impl.update(currentZoomLevel: 5.0).notifyUpdated()
        assertThat(camera.zoom, presentAnd(`is`(currentLevel: 5.0)))
        assertThat(cnt, `is`(1))

        // mock update of the zoom level
        impl.update(currentZoomLevel: 1.0).notifyUpdated()
        assertThat(camera.zoom, presentAnd(`is`(currentLevel: 1.0)))
        assertThat(cnt, `is`(2))

        // check that reset zoom values does reset the current level
        impl.resetZoomValues().notifyUpdated()
        assertThat(camera.zoom, presentAnd(`is`(maxLossLessLevel: 1.0)))
        assertThat(cnt, `is`(3))
    }

    func testRecording() {
        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }
        // test initial value
        assertThat(camera.recordingState, `is`(recordingFunctionState: .unavailable))

        // backend move to stopped
        impl.update(recordingState: .stopped).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(camera.recordingState, `is`(recordingFunctionState: .stopped))

        // start recording
        camera.startRecording()
        assertThat(backend.startRecordingCnt, `is`(1))
        assertThat(cnt, `is`(2))
        assertThat(camera.recordingState, `is`(recordingFunctionState: .starting))

        let startTime = Date()
        impl.update(recordingState: .started, startTime: startTime).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(camera.recordingState, `is`(recordingFunctionState: .started, startTime: startTime))

        // stop recording
        camera.stopRecording()
        assertThat(backend.stopRecordingCnt, `is`(1))
        assertThat(cnt, `is`(4))
        assertThat(camera.recordingState, `is`(recordingFunctionState: .stopping))

        impl.update(recordingState: .stopped, mediaId: "M123").notifyUpdated()
        assertThat(cnt, `is`(5))
        assertThat(camera.recordingState, `is`(recordingFunctionState: .stopped, mediaId: "M123"))
        assertThat(camera.recordingState.startTime, `is`(nilValue()))

        // unavailable
        impl.update(recordingState: .unavailable)
        assertThat(camera.recordingState, `is`(recordingFunctionState: .unavailable))
        assertThat(cnt, `is`(5))

        // start recording should not go to backend when unavailable
        camera.startRecording()
        assertThat(backend.startRecordingCnt, `is`(1))
        assertThat(cnt, `is`(5))
        assertThat(camera.recordingState, `is`(recordingFunctionState: .unavailable))
   }

    func testTakePicture() {
        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }
        // test initial value
        assertThat(camera.photoState, `is`(photoFunctionState: .unavailable))

        // backend move to ready
        impl.update(photoState: .stopped).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(camera.photoState, `is`(photoFunctionState: .stopped))

        // take photo
        camera.startPhotoCapture()
        assertThat(backend.takePhotoCnt, `is`(1))
        // should move to in-progress
        assertThat(cnt, `is`(2))
        assertThat(camera.photoState, `is`(photoFunctionState: .started))
        // update photoCount
        impl.update(photoState: .started, photoCount: 1).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(camera.photoState, `is`(photoFunctionState: .started, photoCount: 1))
        // done, update mediaId
        impl.update(photoState: .stopped, mediaId: "M123").notifyUpdated()
        assertThat(cnt, `is`(4))
        assertThat(camera.photoState, `is`(photoFunctionState: .stopped, mediaId: "M123"))

        // unavailable
        impl.update(photoState: .unavailable)
        // take photo should not go to backend when unavailable
        camera.startPhotoCapture()
        assertThat(backend.takePhotoCnt, `is`(1))
        assertThat(cnt, `is`(4))
        assertThat(camera.photoState, `is`(photoFunctionState: .unavailable))
    }

    func testStopPhoto() {
        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }
        // test initial value
        assertThat(camera.photoState, `is`(photoFunctionState: .unavailable))

        // backend move to ready
        impl.update(photoState: .stopped).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(camera.photoState, `is`(photoFunctionState: .stopped))

        // take photo
        camera.startPhotoCapture()
        assertThat(backend.takePhotoCnt, `is`(1))
        // should move to in-progress
        assertThat(cnt, `is`(2))
        assertThat(camera.photoState, `is`(photoFunctionState: .started))
        // update photoCount

        camera.stopPhotoCapture()
        assertThat(cnt, `is`(3))
        assertThat(camera.photoState, `is`(photoFunctionState: .stopping))

        impl.update(photoState: .stopped, mediaId: "M123").notifyUpdated()
        assertThat(cnt, `is`(4))
        assertThat(camera.photoState, `is`(photoFunctionState: .stopped, mediaId: "M123"))
    }

    func testTimelapseCaptureInterval() {
        impl.update(photoCapabilities: [
            CameraCore.PhotoCapabilitiesEntry(
                modes: [.timeLapse], formats: [.rectilinear], fileFormats: [.jpeg], hdrAvailable: true),
            CameraCore.PhotoCapabilitiesEntry(
                modes: [.gpsLapse], formats: [.rectilinear, .large], fileFormats: [.jpeg], hdrAvailable: true)
            ])
        impl.update(timelapseIntervalMin: 1.5)
        impl.update(timelapseCaptureInterval: 0.5)

        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }

        // we do not replace value if drone is sending bad information
        assertThat(camera.photoSettings.timelapseCaptureInterval, `is`(0.5))
        assertThat(cnt, `is`(0))

        // value should change after connection if value is under minimum
        camera.photoSettings.timelapseCaptureInterval = 0.5

        assertThat(camera.photoSettings.timelapseCaptureInterval, `is`(1.5))
        assertThat(cnt, `is`(1))

        camera.photoSettings.timelapseCaptureInterval = 2.5
        assertThat(camera.photoSettings.timelapseCaptureInterval, `is`(2.5))
        assertThat(cnt, `is`(2))

        camera.photoSettings.timelapseCaptureInterval = 2.5
        assertThat(camera.photoSettings.timelapseCaptureInterval, `is`(2.5))
        assertThat(cnt, `is`(2))
    }

    func testGpslapseCaptureInterval() {
        impl.update(photoCapabilities: [
            CameraCore.PhotoCapabilitiesEntry(
                modes: [.timeLapse], formats: [.rectilinear], fileFormats: [.jpeg], hdrAvailable: true),
            CameraCore.PhotoCapabilitiesEntry(
                modes: [.gpsLapse], formats: [.rectilinear, .large], fileFormats: [.jpeg], hdrAvailable: true)
            ])
        impl.update(gpslapseIntervalMin: 2.5)
        impl.update(gpslapseCaptureInterval: 3.5)
        impl.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.mainCamera)!
        _ = store.register(desc: Peripherals.mainCamera) {
            cnt += 1
        }
        assertThat(camera.photoSettings.gpslapseCaptureInterval, `is`(3.5))
        assertThat(cnt, `is`(0))
        camera.photoSettings.gpslapseCaptureInterval = 0.5

        assertThat(camera.photoSettings.gpslapseCaptureInterval, `is`(2.5))
        assertThat(cnt, `is`(1))

        camera.photoSettings.gpslapseCaptureInterval = 2.5
        assertThat(camera.photoSettings.gpslapseCaptureInterval, `is`(2.5))
        assertThat(cnt, `is`(1))

        camera.photoSettings.gpslapseCaptureInterval = 7
        assertThat(camera.photoSettings.gpslapseCaptureInterval, `is`(7))
        assertThat(cnt, `is`(2))
    }

    func testEnumAllCase() {
        var i = 0
        while let value = CameraShutterSpeed(rawValue: i) {
            assertThat(CameraShutterSpeed.allCases, hasItem(value))
            i += 1
        }

        i = 0
        while let value = CameraIso(rawValue: i) {
            assertThat(CameraIso.allCases, hasItem(value))
            i += 1
        }

        i = 0
        while let value = CameraEvCompensation(rawValue: i) {
            assertThat(CameraEvCompensation.allCases, hasItem(value))
            i += 1
        }

        i = 0
        while let value = CameraWhiteBalanceMode(rawValue: i) {
            assertThat(CameraWhiteBalanceMode.allCases, hasItem(value))
            i += 1
        }

        i = 1500
        while let value = CameraWhiteBalanceTemperature(rawValue: i) {
            assertThat(CameraWhiteBalanceTemperature.allCases, hasItem(value))
            i += 250
        }

        i = 0
        while let value = CameraRecordingMode(rawValue: i) {
            assertThat(CameraRecordingMode.allCases, hasItem(value))
            i += 1
        }

        i = 0
        while let value = CameraRecordingResolution(rawValue: i) {
            assertThat(CameraRecordingResolution.allCases, hasItem(value))
            i += 1
        }

        i = 0
        while let value = CameraRecordingFramerate(rawValue: i) {
            assertThat(CameraRecordingFramerate.allCases, hasItem(value))
            i += 1
        }

        i = 0
        while let value = CameraHyperlapseValue(rawValue: i) {
            assertThat(CameraHyperlapseValue.allCases, hasItem(value))
            i += 1
        }
    }

    func testAlignment() {
        implThermal.publish()
        var cnt = 0
        let camera: Camera = store.get(Peripherals.thermalCamera)!
        _ = store.register(desc: Peripherals.thermalCamera) {
            cnt += 1
        }

        // check default value
        assertThat(camera.alignment, nilValue())
        assertThat(backend.yawOffset, `is`(0))
        assertThat(backend.pitchOffset, `is`(0))
        assertThat(backend.rollOffset, `is`(0))
        assertThat(backend.resetAlignmentCnt, `is`(0))
        assertThat(cnt, `is`(0))

        implThermal.update(yawLowerBound: 1, yaw: 2, yawUpperBound: 3,
                           pitchLowerBound: 4, pitch: 5, pitchUpperBound: 6,
                           rollLowerBound: 7, roll: 8, rollUpperBound: 9).notifyUpdated()
        assertThat(camera.alignment, nilValue())
        assertThat(cnt, `is`(0))

        implThermal.updateActiveFlag(active: true).notifyUpdated()

        assertThat(camera.alignment, present())
        assertThat(camera.alignment!, `is`(yawLowerBound: 1, yaw: 2, yawUpperBound: 3,
                                           pitchLowerBound: 4, pitch: 5, pitchUpperBound: 6,
                                           rollLowerBound: 7, roll: 8, rollUpperBound: 9, updating: false))
        assertThat(cnt, `is`(1))

        // update offsets settings
        implThermal.update(yawLowerBound: 10, yaw: 20, yawUpperBound: 30,
                           pitchLowerBound: 40, pitch: 50, pitchUpperBound: 60,
                           rollLowerBound: 70, roll: 80, rollUpperBound: 90).notifyUpdated()
        assertThat(camera.alignment!, `is`(yawLowerBound: 10, yaw: 20, yawUpperBound: 30,
                                           pitchLowerBound: 40, pitch: 50, pitchUpperBound: 60,
                                           rollLowerBound: 70, roll: 80, rollUpperBound: 90, updating: false))
        assertThat(cnt, `is`(2))

        // change yaw offset
        camera.alignment?.yaw = 25
        assertThat(camera.alignment!, `is`(yawLowerBound: 10, yaw: 25, yawUpperBound: 30,
                                           pitchLowerBound: 40, pitch: 50, pitchUpperBound: 60,
                                           rollLowerBound: 70, roll: 80, rollUpperBound: 90, updating: true))
        assertThat(backend.yawOffset, `is`(25))
        assertThat(backend.pitchOffset, `is`(50))
        assertThat(backend.rollOffset, `is`(80))
        assertThat(cnt, `is`(3))

        implThermal.update(yawLowerBound: 10, yaw: 25, yawUpperBound: 30,
                           pitchLowerBound: 40, pitch: 50, pitchUpperBound: 60,
                           rollLowerBound: 70, roll: 80, rollUpperBound: 90).notifyUpdated()
        assertThat(camera.alignment!, `is`(yawLowerBound: 10, yaw: 25, yawUpperBound: 30,
                                           pitchLowerBound: 40, pitch: 50, pitchUpperBound: 60,
                                           rollLowerBound: 70, roll: 80, rollUpperBound: 90, updating: false))
        assertThat(cnt, `is`(4))

        // change pitch offset
        camera.alignment?.pitch = 55
        assertThat(camera.alignment!, `is`(yawLowerBound: 10, yaw: 25, yawUpperBound: 30,
                                           pitchLowerBound: 40, pitch: 55, pitchUpperBound: 60,
                                           rollLowerBound: 70, roll: 80, rollUpperBound: 90, updating: true))
        assertThat(backend.yawOffset, `is`(25))
        assertThat(backend.pitchOffset, `is`(55))
        assertThat(backend.rollOffset, `is`(80))
        assertThat(cnt, `is`(5))

        implThermal.update(yawLowerBound: 10, yaw: 25, yawUpperBound: 30,
                           pitchLowerBound: 40, pitch: 55, pitchUpperBound: 60,
                           rollLowerBound: 70, roll: 80, rollUpperBound: 90).notifyUpdated()
        assertThat(camera.alignment!, `is`(yawLowerBound: 10, yaw: 25, yawUpperBound: 30,
                                           pitchLowerBound: 40, pitch: 55, pitchUpperBound: 60,
                                           rollLowerBound: 70, roll: 80, rollUpperBound: 90, updating: false))
        assertThat(cnt, `is`(6))

        // change roll offset
        camera.alignment?.roll = 85
        assertThat(camera.alignment!, `is`(yawLowerBound: 10, yaw: 25, yawUpperBound: 30,
                                           pitchLowerBound: 40, pitch: 55, pitchUpperBound: 60,
                                           rollLowerBound: 70, roll: 85, rollUpperBound: 90, updating: true))
        assertThat(backend.yawOffset, `is`(25))
        assertThat(backend.pitchOffset, `is`(55))
        assertThat(backend.rollOffset, `is`(85))
        assertThat(cnt, `is`(7))

        implThermal.update(yawLowerBound: 10, yaw: 25, yawUpperBound: 30,
                           pitchLowerBound: 40, pitch: 55, pitchUpperBound: 60,
                           rollLowerBound: 70, roll: 85, rollUpperBound: 90).notifyUpdated()
        assertThat(camera.alignment!, `is`(yawLowerBound: 10, yaw: 25, yawUpperBound: 30,
                                           pitchLowerBound: 40, pitch: 55, pitchUpperBound: 60,
                                           rollLowerBound: 70, roll: 85, rollUpperBound: 90, updating: false))
        assertThat(cnt, `is`(8))

        // set to same values
        camera.alignment?.yaw = 25
        camera.alignment?.pitch = 55
        camera.alignment?.roll = 85
        assertThat(camera.alignment!, `is`(yawLowerBound: 10, yaw: 25, yawUpperBound: 30,
                                           pitchLowerBound: 40, pitch: 55, pitchUpperBound: 60,
                                           rollLowerBound: 70, roll: 85, rollUpperBound: 90, updating: false))
        assertThat(cnt, `is`(8))

        // update to same values
        implThermal.update(yawLowerBound: 10, yaw: 25, yawUpperBound: 30,
                           pitchLowerBound: 40, pitch: 55, pitchUpperBound: 60,
                           rollLowerBound: 70, roll: 85, rollUpperBound: 90).notifyUpdated()
        assertThat(camera.alignment!, `is`(yawLowerBound: 10, yaw: 25, yawUpperBound: 30,
                                           pitchLowerBound: 40, pitch: 55, pitchUpperBound: 60,
                                           rollLowerBound: 70, roll: 85, rollUpperBound: 90, updating: false))
        assertThat(cnt, `is`(8))

        // reset offsets
        assertThat(camera.alignment?.reset(), `is`(true))
        assertThat(backend.resetAlignmentCnt, `is`(1))
        assertThat(cnt, `is`(8))

        implThermal.update(yawLowerBound: 0, yaw: 0, yawUpperBound: 0,
                           pitchLowerBound: 0, pitch: 0, pitchUpperBound: 0,
                           rollLowerBound: 0, roll: 0, rollUpperBound: 0).notifyUpdated()
        assertThat(camera.alignment!, `is`(yawLowerBound: 0, yaw: 0, yawUpperBound: 0,
                                           pitchLowerBound: 0, pitch: 0, pitchUpperBound: 0,
                                           rollLowerBound: 0, roll: 0, rollUpperBound: 0, updating: false))
        assertThat(cnt, `is`(9))

        // deactivate camera
        implThermal.updateActiveFlag(active: false).notifyUpdated()
        assertThat(camera.alignment, nilValue())
        assertThat(cnt, `is`(10))
    }
}

private class Backend: CameraBackend {

    var mode: CameraMode?
    var exposureMode: CameraExposureMode?
    var exposureLockMode: CameraExposureLockMode?
    var manualShutterSpeed: CameraShutterSpeed?
    var manualIsoSensitivity: CameraIso?
    var maxIsoSensitivity: CameraIso?
    var autoExposureMeteringMode: CameraAutoExposureMeteringMode?
    var exposureCompensation: CameraEvCompensation?
    var whiteBalanceMode: CameraWhiteBalanceMode?
    var whiteBalanceLock: Bool?
    var whiteBalanceCustomTemperature: CameraWhiteBalanceTemperature?
    var recordingMode: CameraRecordingMode?
    var recordingResolution: CameraRecordingResolution?
    var recordingFramerate: CameraRecordingFramerate?
    var recordingHyperlapse: CameraHyperlapseValue?
    var autoRecord: Bool?
    var photoMode: CameraPhotoMode?
    var photoFormat: CameraPhotoFormat?
    var photoFileFormat: CameraPhotoFileFormat?
    var photoBurst: CameraBurstValue?
    var photoBracketing: CameraBracketingValue?
    var hdr: Bool?
    var maxZoomSpeed: Double?
    var qualityDegradation: Bool?
    var zoomControlMode: CameraZoomControlMode?
    var zoomTarget: Double?
    var takePhotoCnt = 0
    var startRecordingCnt = 0
    var stopRecordingCnt = 0
    var gpslapseCaptureInterval: Double?
    var timelapseCaptureInterval: Double?
    var yawOffset = 0.0
    var pitchOffset = 0.0
    var rollOffset = 0.0
    var resetAlignmentCnt = 0

    func set(mode: CameraMode) -> Bool {
        self.mode = mode
        return true
    }

    func set(exposureMode: CameraExposureMode, manualShutterSpeed: CameraShutterSpeed,
             manualIsoSensitivity: CameraIso, maximumIsoSensitivity: CameraIso,
             autoExposureMeteringMode: CameraAutoExposureMeteringMode) -> Bool {
        self.exposureMode = exposureMode
        self.manualShutterSpeed = manualShutterSpeed
        self.manualIsoSensitivity = manualIsoSensitivity
        self.maxIsoSensitivity = maximumIsoSensitivity
        self.autoExposureMeteringMode = autoExposureMeteringMode
        return true
    }

    func set(exposureLockMode: CameraExposureLockMode) -> Bool {
        self.exposureLockMode = exposureLockMode
        return true
    }

    func set(exposureCompensation: CameraEvCompensation) -> Bool {
        self.exposureCompensation = exposureCompensation
        return true
    }

    func set(whiteBalanceMode: CameraWhiteBalanceMode, customTemperature: CameraWhiteBalanceTemperature) -> Bool {
        self.whiteBalanceMode = whiteBalanceMode
        self.whiteBalanceCustomTemperature = customTemperature
        return true
    }

    func set(whiteBalanceLock: Bool) -> Bool {
        self.whiteBalanceLock = whiteBalanceLock
        return true
    }

    func set(activeStyle: CameraStyle) -> Bool {
        return true
    }

    func set(styleParameters: (saturation: Int, contrast: Int, sharpness: Int)) -> Bool {
        return true
    }

    func set(recordingMode: CameraRecordingMode, resolution: CameraRecordingResolution?,
             framerate: CameraRecordingFramerate?, hyperlapse: CameraHyperlapseValue?) -> Bool {
        self.recordingMode = recordingMode
        self.recordingResolution = resolution
        self.recordingFramerate = framerate
        self.recordingHyperlapse = hyperlapse
        return true
    }

    func set(autoRecord: Bool) -> Bool {
        self.autoRecord = autoRecord
        return true
    }

    func set(photoMode: CameraPhotoMode, format: CameraPhotoFormat?, fileFormat: CameraPhotoFileFormat?,
             burst: CameraBurstValue?, bracketing: CameraBracketingValue?, gpslapseCaptureInterval: Double?,
             timelapseCaptureInterval: Double?) -> Bool {
        self.photoMode = photoMode
        self.photoFormat = format
        self.photoFileFormat = fileFormat
        self.photoBurst = burst
        self.photoBracketing = bracketing
        self.gpslapseCaptureInterval = gpslapseCaptureInterval
        self.timelapseCaptureInterval = timelapseCaptureInterval
        return true
    }

    func set(hdr: Bool) -> Bool {
        self.hdr = hdr
        return true
    }

    func set(maxZoomSpeed: Double) -> Bool {
        self.maxZoomSpeed = maxZoomSpeed
        return true
    }

    func set(qualityDegradationAllowance: Bool) -> Bool {
        self.qualityDegradation = qualityDegradationAllowance
        return true
    }

    func control(mode: CameraZoomControlMode, target: Double) {
        self.zoomControlMode = mode
        self.zoomTarget = target
    }

    func startRecording() -> Bool {
        startRecordingCnt += 1
        return true
    }

    func stopRecording() -> Bool {
        stopRecordingCnt += 1
        return true
    }

    func startPhotoCapture() -> Bool {
        takePhotoCnt += 1
        return true
    }

    func stopPhotoCapture() -> Bool {
        takePhotoCnt += 1
        return true
    }

    func set(yawOffset: Double, pitchOffset: Double, rollOffset: Double) -> Bool {
        self.yawOffset = yawOffset
        self.pitchOffset = pitchOffset
        self.rollOffset = rollOffset
        return true
    }

    func resetAlignment() -> Bool {
        resetAlignmentCnt += 1
        return true
    }
}
