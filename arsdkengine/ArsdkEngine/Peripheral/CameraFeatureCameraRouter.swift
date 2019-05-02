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
import GroundSdk

/// Camera router for camera controller
class CameraFeatureCameraRouter: DeviceComponentController {

    /// Main camera identifier
    private let CAMERA_ID_MAIN: UInt = 0

    /// Known camera controllers, by camera identifier
    private var cameraControllers: [UInt: CameraController] = [:]

    /// Camera controllers to activate at the connection.
    private var controllersToActivate: [CameraController]?

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)

        /// load persisted camera controllers
        if GroundSdkConfig.sharedInstance.offlineSettings == .model {
            let array = deviceController.deviceStore.getEntriesForPrefix(key: CameraControllerBase.settingKey)
            if let array = array {
                for key in array {
                    let suffix: String = String(key.suffix(key.count - CameraControllerBase.settingKey.count))
                    if !suffix.isEmpty, let value = UInt(suffix) {
                        cameraControllers[value] = CameraController(camId: value, router: self,
                                                                    key: "\(CameraControllerBase.settingKey)\(value)")
                    } else {
                        cameraControllers[CAMERA_ID_MAIN] = CameraController(camId: CAMERA_ID_MAIN, router: self,
                                                                    key: CameraControllerBase.settingKey)
                    }
                }
            }
        }
    }

    /// Camera controller
    private class CameraController: CameraControllerBase {

        /// List of received recording capabilities collected when receiving list items
        public var recordingCapabilitiesList: ([UInt: CameraCore.RecordingCapabilitiesEntry])?

        /// List of received photo capabilities collected when receiving list items
        public var photoCapabilitiesList: ([UInt: CameraCore.PhotoCapabilitiesEntry])?

        /// Encoder of the zoom control command
        private var zoomControlEncoder: ZoomControlCommandEncoder!
        public var zoomControlEncoderRegistration: RegisteredNoAckCmdEncoder?

        /// Lock mode that has been requested by GroundSdk.
        /// This is kept because drone exposure lock mode event is non acknowledged so it might be received right
        /// after a changed has been requested but before this change has been applied. Hence, thanks to this variable,
        /// we can skip such an event an avoid updating the component with an outdated lock mode.
        public var requestedExposureLockMode: CameraExposureLockMode?

        /// White balance lock supported
        public var supportedWhiteBalanceLock: Bool = false

        /// Camera unique identifier
        public let cameraId: UInt

        /// Camera Feature Camera Router
        var router: CameraFeatureCameraRouter

        var bitrate: UInt?

        /// Constructor
        ///
        /// - Parameters:
        ///   - camId : camera Id
        ///   - model : model of camera
        ///   - router : camera router
        ///   - key: sub setting store key
        init(camId: UInt, model: Model? = nil, router: CameraFeatureCameraRouter, key: String) {
            cameraId = camId
            self.router = router
            zoomControlEncoder = ZoomControlCommandEncoder(cameraId: camId)

            super.init(peripheralStore: router.deviceController.device.peripheralStore,
                       deviceStore: router.deviceController.deviceStore
                        .getSettingsStore(key: key),
                       presetStore: router.deviceController.presetStore
                        .getSettingsStore(key: key), model: model)
        }

        /// Camera zoom control command encoder.
        private class ZoomControlCommandEncoder: NoAckCmdEncoder {
            let type = ArsdkNoAckCmdType.cameraZoom

            /// Max number of time the command should be sent with the same value
            let maxRepeatedSent = 10

            /// Queue used to dispatch messages on it in order to ensure synchronization between main queue and pomp
            /// loop. All synchronized variables of this object must be accessed (read and write) in this queue
            private let queue = DispatchQueue(label: "com.parrot.zoom.encoder")

            // synchronized vars
            /// Desired control mode
            private var desiredControlMode = ArsdkFeatureCameraZoomControlMode.level
            /// Desired target.
            private var desiredTarget: Double = 1.0

            // pomp loop only vars
            private var latestControlMode = ArsdkFeatureCameraZoomControlMode.level
            private var latestTarget: Double = 1.0

            /// Number of time the same command has been sent
            private var sentCnt = -1

            var encoder: () -> (ArsdkCommandEncoder?) {
                return encoderBlock
            }

            /// Encoder of the current piloting command that should be sent to the device.
            private var encoderBlock: (() -> (ArsdkCommandEncoder?))!

            /// Constructor
            ///
            /// - Parameter cameraId: camera id
            init(cameraId: UInt) {
                encoderBlock = { [unowned self] in
                    // Note: this code will be called in the pomp loop

                    var encoderControlMode = ArsdkFeatureCameraZoomControlMode.level
                    var encoderTarget: Double = 0.0
                    // set the local var in a synchronized queue
                    self.queue.sync {
                        encoderControlMode = self.desiredControlMode
                        encoderTarget = self.desiredTarget
                    }

                    // if control has changed or target has changed
                    if self.latestControlMode != encoderControlMode ||
                        self.latestTarget != encoderTarget {

                        self.latestControlMode = encoderControlMode
                        self.latestTarget = encoderTarget
                        self.sentCnt = self.maxRepeatedSent
                    }

                    // only decrement the counter if the control is in level,
                    // or, if the control is in velocity and target is zero
                    if encoderControlMode == .level || encoderTarget == 0.0 {
                        self.sentCnt -= 1
                    }

                    if self.sentCnt >= 0 {
                        return ArsdkFeatureCamera.setZoomTargetEncoder(
                            camId: cameraId, controlMode: encoderControlMode, target: Float(encoderTarget))
                    }
                    return nil
                }
            }

            /// Control the zoom
            ///
            /// - Parameters:
            ///   - mode: control mode to send
            ///   - target: target to send
            func control(mode: CameraZoomControlMode, target: Double) {
                queue.sync {
                    self.desiredControlMode = mode.arsdkValue!
                    self.desiredTarget = target
                }
            }
        }

        override func activate() {
            if let backend = self.router.deviceController.backend {
                zoomControlEncoderRegistration = backend.subscribeNoAckCommandEncoder(encoder: zoomControlEncoder)
            }
            if let bitrate = bitrate {
                self.camera.update(recordingBitrate: bitrate)
            }
            super.activate()

        }

        override func deactivate() {
            super.deactivate()
            zoomControlEncoderRegistration?.unregister()
            zoomControlEncoderRegistration = nil
        }

        /// Preset has been changed
        func presetDidChange() {
            presetDidChange(presetStore: router.deviceController.presetStore
                                            .getSettingsStore(key: "\(CameraControllerBase.settingKey)\(cameraId)"))
        }

        override func sendCameraModeCommand(_ mode: CameraMode) -> Bool {
            router.sendCommand(ArsdkFeatureCamera.setCameraModeEncoder(camId: cameraId, value: mode.arsdkValue!))
            return true
        }

        override func sendExposureCommand(
            exposureMode: CameraExposureMode, manualShutterSpeed: CameraShutterSpeed, manualIsoSensitivity: CameraIso,
            maximumIsoSensitivity: CameraIso) -> Bool {
            router.sendCommand(ArsdkFeatureCamera.setExposureSettingsEncoder(
                camId: cameraId, mode: exposureMode.arsdkValue!,
                shutterSpeed: manualShutterSpeed.arsdkValue!, isoSensitivity: manualIsoSensitivity.arsdkValue!,
                maxIsoSensitivity: maximumIsoSensitivity.arsdkValue!))
            return true
        }

        override func sendExposureLockCommand(mode: CameraExposureLockMode) -> Bool {
            switch mode {
            case .none:
                requestedExposureLockMode = mode
                router.sendCommand(ArsdkFeatureCamera.unlockExposureEncoder(camId: 0))
            case .currentValues:
                requestedExposureLockMode = mode
                router.sendCommand(ArsdkFeatureCamera.lockExposureEncoder(camId: 0))
            case .region(let centerX, let centerY, _, _):
                // save the requested mode in float, in order to avoid precision errors when we test the drone response
                let centerXFromFloat = Double(Float(centerX))
                let centerYFromFloat = Double(Float(centerY))
                requestedExposureLockMode = CameraExposureLockMode.region(
                    centerX: centerXFromFloat, centerY: centerYFromFloat, width: 0.0, height: 0.0)
                router.sendCommand(ArsdkFeatureCamera.lockExposureOnRoiEncoder(
                    camId: 0, roiCenterX: Float(centerX), roiCenterY: Float(centerY)))
            }
            return true
        }

        override func sendExposureCompensationCommand(value: CameraEvCompensation) -> Bool {
            router.sendCommand(ArsdkFeatureCamera.setEvCompensationEncoder(
                camId: cameraId, value: value.arsdkValue!))
            return true
        }

        override func sendWhiteBalanceCommand(
            mode: CameraWhiteBalanceMode, customTemperature: CameraWhiteBalanceTemperature) -> Bool {
            router.sendCommand(ArsdkFeatureCamera.setWhiteBalanceEncoder(
                camId: cameraId, mode: mode.arsdkValue!, temperature: customTemperature.arsdkValue!))
            return true
        }

        override func sendWhiteBalanceLockedCommand(lock: Bool) -> Bool {
            if let isLockable = camera.whiteBalanceLock?.isLockable, isLockable {
                router.sendCommand(ArsdkFeatureCamera.setWhiteBalanceLockEncoder(camId: cameraId,
                                                                          state: lock ? .active : .inactive))
                return true
            }
            return false
        }

        override func sendActiveStyleCommand(style: CameraStyle) -> Bool {
            router.sendCommand(ArsdkFeatureCamera.setStyleEncoder(camId: cameraId, style: style.arsdkValue!))
            return true
        }

        override func sendStyleParameterCommand(saturation: Int, contrast: Int, sharpness: Int) -> Bool {
            router.sendCommand(ArsdkFeatureCamera.setStyleParamsEncoder(
                camId: cameraId, saturation: saturation, contrast: contrast, sharpness: sharpness))
            return true
        }

        override func sendHdrSettingCommand(_ hdr: Bool) -> Bool {
            router.sendCommand(ArsdkFeatureCamera.setHdrSettingEncoder(
                camId: cameraId, value: hdr ? .active : .inactive))
            return true
        }

        override func sendRecordingCommand(
            recordingMode: CameraRecordingMode, resolution: CameraRecordingResolution,
            framerate: CameraRecordingFramerate, hyperlapse: CameraHyperlapseValue) -> Bool {
            router.sendCommand(ArsdkFeatureCamera.setRecordingModeEncoder(
                camId: cameraId, mode: recordingMode.arsdkValue!, resolution: resolution.arsdkValue!,
                framerate: framerate.arsdkValue!,
                hyperlapse: recordingMode == .hyperlapse ? hyperlapse.arsdkValue! : .ratio15))
            return true
        }

        override func sendAutoRecordCommand(_ value: Bool) -> Bool {
            router.sendCommand(ArsdkFeatureCamera.setAutorecordEncoder(
                camId: cameraId, state: value ? .active : .inactive))
            return true
        }

        override func sendPhotoCommand(
            photoMode: CameraPhotoMode, photoFormat: CameraPhotoFormat, photoFileFormat: CameraPhotoFileFormat,
            bustValue: CameraBurstValue, bracketingValue: CameraBracketingValue, captureInterval: Double) -> Bool {
            router.sendCommand(ArsdkFeatureCamera.setPhotoModeEncoder(
                camId: cameraId, mode: photoMode.arsdkValue!, format: photoFormat.arsdkValue!,
                fileFormat: photoFileFormat.arsdkValue!,
                burst: photoMode == .burst ? bustValue.arsdkValue! : .burst14Over4s,
                bracketing: photoMode == .bracketing ? bracketingValue.arsdkValue! : .preset1ev,
                captureInterval: Float(captureInterval)))
            return true
        }

        override func sendStartPhotoCommand() -> Bool {
            router.sendCommand(ArsdkFeatureCamera.takePhotoEncoder(camId: cameraId))
            return true
        }

        override func sendStopPhotoCommand() -> Bool {
            router.sendCommand(ArsdkFeatureCamera.stopPhotoEncoder(camId: cameraId))
            return true
        }

        override func sendStartRecordingCommand() -> Bool {
            router.sendCommand(ArsdkFeatureCamera.startRecordingEncoder(camId: cameraId))
            return true
        }

        override func sendStopRecordingCommand() -> Bool {
            router.sendCommand(ArsdkFeatureCamera.stopRecordingEncoder(camId: cameraId))
            return true
        }

        override func sendMaxZoomSpeedCommand(value: Double) -> Bool {
            router.sendCommand(ArsdkFeatureCamera.setMaxZoomSpeedEncoder(camId: cameraId, max: Float(value)))
            return true
        }

        override func sendZoomVelocityQualityDegradationAllowanceCommand(value: Bool) -> Bool {
            router.sendCommand(ArsdkFeatureCamera.setZoomVelocityQualityDegradationEncoder(
                camId: cameraId, allow: value ? 1 : 0))
            return true
        }

        override func control(mode: CameraZoomControlMode, target: Double) {
            zoomControlEncoder.control(mode: mode, target: target)
        }
    }

    /// Drone is about to be forgotten
    override func willForget() {
        super.willForget()
        cameraControllers.forEach {
            $1.willForget()
        }
    }

    /// Drone is about to be connect
    override func willConnect() {
        controllersToActivate = nil
        super.willConnect()
    }

    /// Drone is connected
    override func didConnect() {
        // If cameras state not received, assuming main camera is active
        if controllersToActivate == nil {
            controllersToActivate = []
            if let cameraController = cameraControllers[CAMERA_ID_MAIN] {
                controllersToActivate!.append(cameraController)
                ULog.w(.cameraTag, "Cameras state not received, assuming main camera is active")
            }
        }

        // store all cameras presets
        cameraControllers.forEach {
            $1.connected = true
            $1.storeNewPresets()
        }
        // activate each camera that must be activated
        controllersToActivate!.forEach {
            $0.activate()
        }

        // publish all cameras
        cameraControllers.forEach {
            $1.publish()
        }
        super.didConnect()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        cameraControllers.forEach {
            $1.connected = false
            $1.deactivate()
        }

        super.didDisconnect()
    }

    /// Preset did change
    override func presetDidChange() {
        cameraControllers.forEach {
            $1.presetDidChange()
        }
        super.presetDidChange()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCameraUid {
            ArsdkFeatureCamera.decode(command, callback: self)
        }
    }
}

// MARK: - ArsdkFeatureCameraCallback
extension CameraFeatureCameraRouter: ArsdkFeatureCameraCallback {

    func onCameraCapabilities(
        camId: UInt, model: ArsdkFeatureCameraModel, exposureModesBitField: UInt,
        exposureLockSupported: ArsdkFeatureCameraSupported, exposureRoiLockSupported: ArsdkFeatureCameraSupported,
        evCompensationsBitField: UInt64, whiteBalanceModesBitField: UInt,
        customWhiteBalanceTemperaturesBitField: UInt64, whiteBalanceLockSupported: ArsdkFeatureCameraSupported,
        stylesBitField: UInt, cameraModesBitField: UInt, hyperlapseValuesBitField: UInt,
        bracketingPresetsBitField: UInt, burstValuesBitField: UInt, streamingModesBitField: UInt,
        timelapseIntervalMin: Float, gpslapseIntervalMin: Float) {
        var cameraController = self.cameraControllers[camId]
        if cameraController == nil {
            if let model: Model = Model.from(model: model) {
                cameraController = CameraController(camId: camId, model: model, router: self,
                                                    key: "\(CameraControllerBase.settingKey)\(camId)")
            } else {
                return
            }
        }
        if let _model = Model.from(model: model) {
            cameraController!.settingDidChange(.model(model: _model))
        } else {
            return
        }
        // exposure compensation, only updated if camera mode is not manual
        cameraController!.updateAvailableValues(supportedValue: CameraEvCompensation
            .createSetFrom(bitField: evCompensationsBitField))
        // white balance
        cameraController!.capabilitiesDidChange(.whiteBalanceMode(
            CameraWhiteBalanceMode.createSetFrom(bitField: whiteBalanceModesBitField)))
        cameraController!.capabilitiesDidChange(.whiteBalanceTemperature(
            CameraWhiteBalanceTemperature.createSetFrom(bitField: customWhiteBalanceTemperaturesBitField)))
        // exposure
        cameraController!.capabilitiesDidChange(.exposureMode(CameraExposureMode
            .createSetFrom(bitField: exposureModesBitField)))
        // mode
        cameraController!.capabilitiesDidChange(.mode(CameraMode.createSetFrom(bitField: cameraModesBitField)))
        // styles
        cameraController!.capabilitiesDidChange(.style(CameraStyle.createSetFrom(bitField: stylesBitField)))
        // hyperlapse
        cameraController!.capabilitiesDidChange(.hyperlapseValue(
            CameraHyperlapseValue.createSetFrom(bitField: hyperlapseValuesBitField)))
        // bracketing
        cameraController!.capabilitiesDidChange(.bracketingValue(
            CameraBracketingValue.createSetFrom(bitField: bracketingPresetsBitField)))
        // burst burstValuesBitField
        cameraController!.capabilitiesDidChange(.burstValue(
            CameraBurstValue.createSetFrom(bitField: burstValuesBitField)))
        cameraController!.supportedWhiteBalanceLock = whiteBalanceLockSupported == .supported
        cameraController!.camera.update(whiteBalanceLockSupported: cameraController!.supportedWhiteBalanceLock)
        cameraController!.capabilitiesDidChange(.timelapseIntervalMin(min: Double(timelapseIntervalMin)))
        cameraController!.capabilitiesDidChange(.gpslapseIntervalMin(min: Double(gpslapseIntervalMin)))
        // TODO:streaming streamingModesBitField
        cameraController!.camera.notifyUpdated()
        self.cameraControllers[camId] = cameraController
    }

    func onRecordingCapabilities(
        id: UInt, recordingModesBitField: UInt, resolutionsBitField: UInt, frameratesBitField: UInt,
        hdr: ArsdkFeatureCameraSupported, listFlagsBitField: UInt) {

        if let cameraController = self.cameraControllers[id>>8] {
            if ArsdkFeatureGenericListFlagsBitField.isSet(.first, inBitField: listFlagsBitField) {
                cameraController.recordingCapabilitiesList = [:]
            }
            if !ArsdkFeatureGenericListFlagsBitField.isSet(.empty, inBitField: listFlagsBitField) {
                cameraController.recordingCapabilitiesList![id & 0x00FF] = CameraCore.RecordingCapabilitiesEntry(
                    modes: CameraRecordingMode.createSetFrom(bitField: recordingModesBitField),
                    resolutions: CameraRecordingResolution.createSetFrom(bitField: resolutionsBitField),
                    framerates: CameraRecordingFramerate.createSetFrom(bitField: frameratesBitField),
                    hdrAvailable: hdr == .supported)
            }
            if ArsdkFeatureGenericListFlagsBitField.isSet(.last, inBitField: listFlagsBitField) {
                cameraController.capabilitiesDidChange(
                    .recording(Array(cameraController.recordingCapabilitiesList!.values)))
                cameraController.recordingCapabilitiesList = nil
            }
            self.cameraControllers[id>>8] = cameraController
        } else {
            ULog.w(.cameraTag, "Recording capabilities received for an unknown camera id=\(id>>8)")
        }
    }

    func onPhotoCapabilities(
        id: UInt, photoModesBitField: UInt, photoFormatsBitField: UInt, photoFileFormatsBitField: UInt,
        hdr: ArsdkFeatureCameraSupported, listFlagsBitField: UInt) {
        if let cameraController = self.cameraControllers[id>>8] {

            if ArsdkFeatureGenericListFlagsBitField.isSet(.first, inBitField: listFlagsBitField) {
                cameraController.photoCapabilitiesList = [:]
            }
            if !ArsdkFeatureGenericListFlagsBitField.isSet(.empty, inBitField: listFlagsBitField) {
                cameraController.photoCapabilitiesList![id & 0x00FF] = CameraCore.PhotoCapabilitiesEntry(
                    modes: CameraPhotoMode.createSetFrom(bitField: photoModesBitField),
                    formats: CameraPhotoFormat.createSetFrom(bitField: photoFormatsBitField),
                    fileFormats: CameraPhotoFileFormat.createSetFrom(bitField: photoFileFormatsBitField),
                    hdrAvailable: hdr == .supported)
            }
            if ArsdkFeatureGenericListFlagsBitField.isSet(.last, inBitField: listFlagsBitField) {
                cameraController.capabilitiesDidChange(.photo(Array(cameraController.photoCapabilitiesList!.values)))
                cameraController.photoCapabilitiesList = nil
            }
            self.cameraControllers[id>>8] = cameraController
        } else {
            ULog.w(.cameraTag, "Photo capabilities received for an unknown camera id=\(id>>8)")
        }
    }

    func onCameraMode(camId: UInt, mode: ArsdkFeatureCameraCameraMode) {
        if let cameraController = self.cameraControllers[camId] {
            guard let _mode = CameraMode(fromArsdk: mode) else {
                ULog.w(.cameraTag, "Unsupported camera mode: \(mode)")
                return
            }
            cameraController.settingDidChange(.mode(_mode))
            self.cameraControllers[camId] = cameraController
        } else {
            ULog.w(.cameraTag, "Camera mode received for an unknown camera id=\(camId)")
        }
    }

    func onExposureSettings(
        camId: UInt, mode: ArsdkFeatureCameraExposureMode, manualShutterSpeed: ArsdkFeatureCameraShutterSpeed,
        manualShutterSpeedCapabilitiesBitField: UInt64, manualIsoSensitivity: ArsdkFeatureCameraIsoSensitivity,
        manualIsoSensitivityCapabilitiesBitField: UInt64, maxIsoSensitivity: ArsdkFeatureCameraIsoSensitivity,
        maxIsoSensitivitiesCapabilitiesBitField: UInt64) {
        if let cameraController = self.cameraControllers[camId] {
            guard let _mode = CameraExposureMode(fromArsdk: mode) else {
                ULog.w(.cameraTag, "Invalid exposure mode: \(mode.rawValue)")
                return
            }
            let _manualShutterSpeed = CameraShutterSpeed(fromArsdk: manualShutterSpeed)
            guard _manualShutterSpeed != nil || _mode == .automatic || _mode == .manualIsoSensitivity else {
                ULog.w(.cameraTag, "Invalid shutter speed: \(manualShutterSpeed.rawValue)")
                return
            }
            let _manualIsoSensitivity = CameraIso(fromArsdk: manualIsoSensitivity)
            guard _manualIsoSensitivity != nil || _mode == .automatic || _mode == .manualShutterSpeed else {
                ULog.w(.cameraTag, "Invalid iso sensitivity: \(manualIsoSensitivity.rawValue)")
                return
            }
            let _maxIsoSensitivity = CameraIso(fromArsdk: maxIsoSensitivity)
            guard _maxIsoSensitivity != nil else {
                ULog.w(.cameraTag, "Invalid maximum sensitivity: \(maxIsoSensitivity.rawValue)")
                return
            }
            cameraController.camera.update(exposureMode: _mode)
            cameraController.computeEVCompensationAvailableValues()
            if let _manualShutterSpeed = _manualShutterSpeed {
                cameraController.camera.update(manualShutterSpeed: _manualShutterSpeed)
            }

            cameraController.capabilitiesDidChange(.exposureShutterSpeed(CameraShutterSpeed
                .createSetFrom(bitField: manualShutterSpeedCapabilitiesBitField)))

            if let _manualIsoSensitivity = _manualIsoSensitivity {
                cameraController.camera.update(manualIsoSensitivity: _manualIsoSensitivity)
            }

            cameraController.capabilitiesDidChange(.exposureManualIsoSensitivity(
                CameraIso.createSetFrom(bitField: manualIsoSensitivityCapabilitiesBitField)))

             if let _maxIsoSensitivity = _maxIsoSensitivity {
                cameraController.camera.update(maximumIsoSensitivity: _maxIsoSensitivity)
            }
            cameraController.capabilitiesDidChange(.exposureMaximumIsoSensitivity(
                CameraIso.createSetFrom(bitField: maxIsoSensitivitiesCapabilitiesBitField)))

            cameraController.settingDidChange(.exposure(mode: _mode,
                                       manualShutterSpeed: _manualShutterSpeed!,
                                       manualIsoSensitivity: _manualIsoSensitivity!,
                                       maximumIsoSensitivity: _maxIsoSensitivity!))
            self.cameraControllers[camId] = cameraController

        } else {
            ULog.w(.cameraTag, "Exposure settings received for an unknown camera id=\(camId)")
        }
    }

    func onExposure(
        camId: UInt, shutterSpeed: ArsdkFeatureCameraShutterSpeed, isoSensitivity: ArsdkFeatureCameraIsoSensitivity,
        lock: ArsdkFeatureCameraState, lockRoiX: Float, lockRoiY: Float, lockRoiWidth: Float, lockRoiHeight: Float) {

        guard let cameraController = self.cameraControllers[camId] else {
            ULog.w(.cameraTag, "Exposure received for an unknown camera id=\(camId)")
            return
        }

        let mode: CameraExposureLockMode
        if lock == .active {
            // if all lockRoi values are greater than zero, the lock mode is region
            if lockRoiX >= 0 && lockRoiY >= 0 && lockRoiWidth >= 0 && lockRoiHeight >= 0 {
                mode = .region(centerX: Double(lockRoiX), centerY: Double(lockRoiY),
                               width: Double(lockRoiWidth), height: Double(lockRoiHeight))
            } else {
                mode = .currentValues
            }
        } else {
            mode = .none
        }
        // if there is no pending request and mode has changed or if the requested lock mode matches the received mode
        if (cameraController.requestedExposureLockMode == nil &&
            !mode.isSameRequest(as: cameraController.camera.exposureLock?.mode)) ||
            mode.isSameRequest(as: cameraController.requestedExposureLockMode) {

            cameraController.requestedExposureLockMode = nil
            cameraController.camera.update(exposureLockMode: mode)
            cameraController.computeEVCompensationAvailableValues()
            cameraController.camera.notifyUpdated()
            self.cameraControllers[camId] = cameraController
        }
    }

    func onEvCompensation(camId: UInt, value: ArsdkFeatureCameraEvCompensation) {
        if let cameraController = self.cameraControllers[camId] {
            guard let _value = CameraEvCompensation(fromArsdk: value) else {
                ULog.w(.cameraTag, "Invalid ev compensation value: \(value.rawValue)")
                return
            }
            cameraController.settingDidChange(.exposureCompensation(_value))
            self.cameraControllers[camId] = cameraController
        } else {
            ULog.w(.cameraTag, "Ev compensation received for an unknown camera id=\(camId)")
        }
    }

    func onWhiteBalance(camId: UInt, mode: ArsdkFeatureCameraWhiteBalanceMode,
                        temperature: ArsdkFeatureCameraWhiteBalanceTemperature, lock: ArsdkFeatureCameraState) {
        if let cameraController = self.cameraControllers[camId] {
            guard let _mode = CameraWhiteBalanceMode(fromArsdk: mode) else {
                ULog.w(.cameraTag, "Invalid white balance mode: \(mode.rawValue)")
                return
            }
            guard let _temperature = CameraWhiteBalanceTemperature(fromArsdk: temperature) else {
                ULog.w(.cameraTag, "Invalid white balance temperature: \(temperature.rawValue)")
                return
            }
            cameraController.camera.update(
                whiteBalanceLockSupported: cameraController.supportedWhiteBalanceLock ? _mode == .automatic : nil)
            cameraController.camera.update(whiteBalanceLock: lock == .active)
            // settingDidChange already nofityUpdate
            cameraController.settingDidChange(.whiteBalance(mode: _mode, customTemperature: _temperature))
            self.cameraControllers[camId] = cameraController
        } else {
            ULog.w(.cameraTag, "White balance received for an unknown camera id=\(camId)")
        }
    }

    func onHdrSetting(camId: UInt, value arsdkValue: ArsdkFeatureCameraState) {
        if let cameraController = self.cameraControllers[camId] {
            cameraController.settingDidChange(.hdr(arsdkValue == .active))
            self.cameraControllers[camId] = cameraController
        } else {
            ULog.w(.cameraTag, "Hdr Setting received for an unknown camera id=\(camId)")
        }
    }

    func onHdr(camId: UInt, available: ArsdkFeatureCameraAvailability, state: ArsdkFeatureCameraState) {
        if let cameraController = self.cameraControllers[camId] {
            cameraController.camera.update(hdrState: state == .active).notifyUpdated()
            self.cameraControllers[camId] = cameraController
        } else {
            ULog.w(.cameraTag, "Hdr received for an unknown camera id=\(camId)")
        }
    }

    func onStyle(camId: UInt, style arsdkStyle: ArsdkFeatureCameraStyle,
                 saturation: Int, saturationMin: Int, saturationMax: Int,
                 contrast: Int, contrastMin: Int, contrastMax: Int,
                 sharpness: Int, sharpnessMin: Int, sharpnessMax: Int) {

        guard saturationMin <= saturationMax, contrastMin <= contrastMax, sharpnessMin <= sharpnessMax else {
            ULog.w(.cameraTag, "Style bounds are not correct, skipping this event.")
            return
        }

        if let cameraController = self.cameraControllers[camId] {
            guard let style = CameraStyle(fromArsdk: arsdkStyle) else {
                ULog.w(.cameraTag, "Invalid camera style: \(arsdkStyle.rawValue)")
                return
            }
            cameraController.settingDidChange(.style(activeStyle: style, saturation: saturation, contrast: contrast,
                                    sharpness: sharpness))
            cameraController.settingDidChange(.saturation(min: saturationMin, current: saturation, max: saturationMax))
            cameraController.settingDidChange(.contrast(min: contrastMin, current: contrast, max: contrastMax))
            cameraController.settingDidChange(.sharpness(min: sharpnessMin, current: sharpness, max: sharpnessMax))
            self.cameraControllers[camId] = cameraController
        } else {
            ULog.w(.cameraTag, "Camera Style received for an unknown camera id=\(camId)")
        }
    }

    func onCameraStates(activeCameras: UInt) {
        controllersToActivate = []
        cameraControllers.forEach {
            if (activeCameras & (1 << $0.value.cameraId)) != 0 {

                // activate directly camera if connected
                if connected {
                    $0.value.activate()
                } else {
                    // save camera to be activated at the connection
                    controllersToActivate!.append($0.value)
                }
            } else if connected {
                $0.value.deactivate()
            }
        }
    }

    func onRecordingMode(camId: UInt, mode: ArsdkFeatureCameraRecordingMode,
                         resolution: ArsdkFeatureCameraResolution, framerate: ArsdkFeatureCameraFramerate,
                         hyperlapse: ArsdkFeatureCameraHyperlapseValue, bitrate: UInt) {
        if let cameraController = self.cameraControllers[camId] {
            guard let _mode = CameraRecordingMode(fromArsdk: mode) else {
                ULog.w(.cameraTag, "Invalid recording mode: \(mode.rawValue)")
                return
            }
            guard let _resolution = CameraRecordingResolution(fromArsdk: resolution) else {
                ULog.w(.cameraTag, "Invalid recording resolution: \(resolution.rawValue)")
                return
            }
            guard let _framerate = CameraRecordingFramerate(fromArsdk: framerate) else {
                ULog.w(.cameraTag, "Invalid recording framerate: \(framerate.rawValue)")
                return
            }
            let _hyperlapse: CameraHyperlapseValue
            if _mode == .hyperlapse {
                guard let hyperlapseValue = CameraHyperlapseValue(fromArsdk: hyperlapse) else {
                    ULog.w(.cameraTag, "Invalid recording hyperlapse: \(hyperlapse.rawValue)")
                    return
                }
                _hyperlapse = hyperlapseValue
            } else {
                _hyperlapse = .ratio15
            }
            cameraController.settingDidChange(.recording(mode: _mode, resolution: _resolution, framerate: _framerate,
                                        hyperlapse: _hyperlapse))
            cameraController.camera.update(recordingBitrate: bitrate).notifyUpdated()
            cameraController.bitrate = bitrate
            self.cameraControllers[camId] = cameraController
        } else {
            ULog.w(.cameraTag, "Recording Mode received for an unknown camera id=\(camId)")
        }
    }

    func onAutorecord(camId: UInt, state: ArsdkFeatureCameraState) {
        if let cameraController = self.cameraControllers[camId] {
            cameraController.settingDidChange(.autoRecord(state == .active))
            self.cameraControllers[camId] = cameraController
        } else {
            ULog.w(.cameraTag, "Auto-record received for an unknown camera id=\(camId)")
        }
    }

    func onPhotoMode(camId: UInt, mode: ArsdkFeatureCameraPhotoMode, format: ArsdkFeatureCameraPhotoFormat,
                     fileFormat: ArsdkFeatureCameraPhotoFileFormat, burst: ArsdkFeatureCameraBurstValue,
                     bracketing: ArsdkFeatureCameraBracketingPreset, captureInterval: Float) {
        if let cameraController = self.cameraControllers[camId] {
            guard let _mode = CameraPhotoMode(fromArsdk: mode) else {
                ULog.w(.cameraTag, "Invalid photo mode: \(mode.rawValue)")
                return
            }
            guard let _format = CameraPhotoFormat(fromArsdk: format) else {
                ULog.w(.cameraTag, "Invalid photo format: \(format.rawValue)")
                return
            }
            guard let _fileFormat = CameraPhotoFileFormat(fromArsdk: fileFormat) else {
                ULog.w(.cameraTag, "Invalid photo file format: \(fileFormat.rawValue)")
                return
            }
            let _burst: CameraBurstValue
            if _mode == .burst {
                guard let burstValue = CameraBurstValue(fromArsdk: burst) else {
                    ULog.w(.cameraTag, "Invalid photo burst value: \(burst.rawValue)")
                    return
                }
                _burst = burstValue
            } else {
                _burst = .burst14Over4s
            }
            let _bracketing: CameraBracketingValue
            if _mode == .bracketing {
                guard let bracketingValue = CameraBracketingValue(fromArsdk: bracketing) else {
                    ULog.w(.cameraTag, "Invalid photo bracketing value: \(bracketing.rawValue)")
                    return
                }
                _bracketing = bracketingValue
            } else {
                _bracketing = .preset1ev
            }
            cameraController.settingDidChange(.photo(mode: _mode, format: _format, fileFormat: _fileFormat,
                burst: _burst, bracketing: _bracketing, captureInterval: Double(captureInterval)))
            self.cameraControllers[camId] = cameraController
        } else {
            ULog.w(.cameraTag, "Photo Mode received for an unknown camera id=\(camId)")
        }
    }

    func onRecordingState(camId: UInt, available: ArsdkFeatureCameraAvailability, state: ArsdkFeatureCameraState,
                          startTimestamp: UInt64) {
        if let cameraController = self.cameraControllers[camId] {
            switch available {
            case .notAvailable:
                cameraController.camera.update(recordingState: .unavailable)
            case .available:
                switch state {
                case .inactive, .sdkCoreUnknown:
                    cameraController.camera.update(recordingState: .stopped)
                case .active:
                    cameraController.camera.update(recordingState: .started,
                                  startTime: Date(timeIntervalSince1970: Double(startTimestamp)/Double(1000)))
                }

            case .sdkCoreUnknown:  break
            }
            cameraController.camera.notifyUpdated()
            self.cameraControllers[camId] = cameraController
        } else {
            ULog.w(.cameraTag, "Recording State received for an unknown camera id=\(camId)")
        }
    }

    func onRecordingProgress(camId: UInt, result: ArsdkFeatureCameraRecordingResult, mediaId: String!) {
        if let cameraController = self.cameraControllers[camId] {
            switch result {
            case .started:
                cameraController.camera.update(recordingState: .started)
            case .stopped:
                cameraController.camera.update(recordingState: .stopped, mediaId: !mediaId.isEmpty ? mediaId: nil)
            case .stoppedNoStorageSpace:
                cameraController.camera.update(recordingState: .errorInsufficientStorageSpace)
            case .stoppedStorageTooSlow:
                cameraController.camera.update(recordingState: .errorInsufficientStorageSpeed)
            case .errorBadState:
                // ignore bad state error, onPhotoState will move state back to notAvailable
                break
            case .error:
                cameraController.camera.update(recordingState: .errorInternal)
            case .stoppedReconfigured:
                cameraController.camera.update(recordingState: .stoppedForReconfiguration)
            case .sdkCoreUnknown:  break
            }
            cameraController.camera.notifyUpdated()
            self.cameraControllers[camId] = cameraController
        } else {
            ULog.w(.cameraTag, "Recording Progress received for an unknown camera id=\(camId)")
        }
    }

    func onPhotoState(camId: UInt, available: ArsdkFeatureCameraAvailability, state: ArsdkFeatureCameraState) {
        if let cameraController = self.cameraControllers[camId] {
            switch available {
            case .notAvailable:
                cameraController.camera.update(photoState: .unavailable)
            case .available:
                switch state {
                case .inactive, .sdkCoreUnknown:
                    cameraController.camera.update(photoState: .stopped)
                case .active:
                    cameraController.camera.update(photoState: .started)
                }
            case .sdkCoreUnknown:  break
            }
            cameraController.camera.notifyUpdated()
            self.cameraControllers[camId] = cameraController
        } else {
            ULog.w(.cameraTag, "Photo State received for an unknown camera id=\(camId)")
        }
    }

    func onPhotoProgress(camId: UInt, result: ArsdkFeatureCameraPhotoResult, photoCount: UInt, mediaId: String!) {
        if let cameraController = self.cameraControllers[camId] {
            switch result {
            case .takingPhoto:
                // ignore takingPhoto, it can be called multiple time in burst mode.
                break
            case .photoTaken:
                cameraController.camera.update(photoCount: Int(photoCount))
            case .photoSaved:
                // photoSaved is sent just before state move to ready. Change state immedialty here to avoid
                // multiple notifications
                cameraController.camera.update(photoState: .stopped, mediaId: mediaId)
            case .errorNoStorageSpace:
                cameraController.camera.update(photoState: .errorInsufficientStorageSpace)
            case .errorBadState:
                // ignore bad state error, onPhotoState will move state back to notAvailable
                break
            case .error:
                cameraController.camera.update(photoState: .errorInternal)
            case .sdkCoreUnknown:  break
            }
            cameraController.camera.notifyUpdated()
            self.cameraControllers[camId] = cameraController
        } else {
            ULog.w(.cameraTag, "Photo Progress received for an unknown camera id=\(camId)")
        }
    }

    func onZoomInfo(
        camId: UInt, available: ArsdkFeatureCameraAvailability, highQualityMaximumLevel: Float, maximumLevel: Float) {

        guard let cameraController = self.cameraControllers[camId] else {
            ULog.w(.cameraTag, "Zoom info received for an unknown camera id=\(camId)")
            return
        }
        guard available != .sdkCoreUnknown else {
            ULog.w(.tag, "Unknown zoom availability, skipping this event.")
            return
        }
        let zoomIsAvailable = available == .available
        guard !zoomIsAvailable || highQualityMaximumLevel >= 1.0 && maximumLevel >= 1.0 else {
            ULog.w(.cameraTag, "Zoom bounds are not correct, skipping this event.")
            return
        }

        cameraController.camera.update(zoomIsAvailable: zoomIsAvailable)
        if zoomIsAvailable {
            cameraController.camera.update(maxLossLessZoomLevel: Double(highQualityMaximumLevel))
                .update(maxLossyZoomLevel: Double(maximumLevel))
        }
        cameraController.camera.notifyUpdated()
        self.cameraControllers[camId] = cameraController
    }

    func onZoomLevel(camId: UInt, level: Float) {
        if let cameraController = self.cameraControllers[camId] {
            cameraController.camera.update(currentZoomLevel: Double(level)).notifyUpdated()
        } else {
            ULog.w(.cameraTag, "Zoom level received for an unknown camera id=\(camId)")
        }
    }

    func onMaxZoomSpeed(camId: UInt, min: Float, max: Float, current: Float) {

        guard min <= max else {
            ULog.w(.cameraTag, "Max zoom speed bounds are not correct, skipping this event.")
            return
        }

        if let cameraController = self.cameraControllers[camId] {
            cameraController.settingDidChange(
                .maxZoomSpeed(min: Double(min), current: Double(current), max: Double(max)))
            self.cameraControllers[camId] = cameraController
        } else {
            ULog.w(.cameraTag, "Max zoom velocity received for an unknown camera id=\(camId)")
        }
    }

    func onZoomVelocityQualityDegradation(camId: UInt, allowed: UInt) {
        if let cameraController = self.cameraControllers[camId] {
            cameraController.settingDidChange(.zoomVelocityQualityDegradation(allowed: allowed != 0))
            self.cameraControllers[camId] = cameraController
        } else {
            ULog.w(.cameraTag, "Zoom velocity quality degradation allowed received for an unknown camera id=\(camId)")
        }
    }

}

// MARK: - Extensions

/// Extension that add conversion from/to arsdk enum
extension CameraMode: ArsdkMappableEnum {

    static func createSetFrom(bitField: UInt) -> Set<CameraMode> {
        var result = Set<CameraMode>()
        ArsdkFeatureCameraCameraModeBitField.forAllSet(in: bitField) { arsdkValue in
            if let mode = CameraMode.init(fromArsdk: arsdkValue) {
                result.insert(mode)
            }
        }
        return result
    }

    static let arsdkMapper = Mapper<CameraMode, ArsdkFeatureCameraCameraMode>(
        [.recording: .recording, .photo: .photo])
}

/// Extension that add conversion from/to arsdk enum
extension CameraExposureMode: ArsdkMappableEnum {

    /// Create set of camera exposure modes from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all camera modes set in bitField
    static func createSetFrom(bitField: UInt) -> Set<CameraExposureMode> {
        var result = Set<CameraExposureMode>()
        ArsdkFeatureCameraExposureModeBitField.forAllSet(in: bitField) { arsdkValue in
            if let mode = CameraExposureMode(fromArsdk: arsdkValue) {
                result.insert(mode)
            }
        }
        return result
    }

    static var arsdkMapper = Mapper<CameraExposureMode, ArsdkFeatureCameraExposureMode>([
        .automatic: .automatic,
        .automaticPreferIsoSensitivity: .automaticPreferIsoSensitivity,
        .automaticPreferShutterSpeed: .automaticPreferShutterSpeed,
        .manualIsoSensitivity: .manualIsoSensitivity,
        .manualShutterSpeed: .manualShutterSpeed,
        .manual: .manual])
}

/// Extension that add conversion from/to arsdk enum
extension CameraShutterSpeed: ArsdkMappableEnum {

    /// Create set of camera shutter speeds from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all camera shutter speeds set in bitField
    static func createSetFrom(bitField: UInt64) -> Set<CameraShutterSpeed> {
        var result = Set<CameraShutterSpeed>()
        ArsdkFeatureCameraShutterSpeedBitField.forAllSet(in: bitField) { arsdkValue in
            if let mode = CameraShutterSpeed(fromArsdk: arsdkValue) {
                result.insert(mode)
            }
        }
        return result
    }

    static var arsdkMapper = Mapper<CameraShutterSpeed, ArsdkFeatureCameraShutterSpeed>([
        .oneOver10000: .shutter1Over10000,
        .oneOver8000: .shutter1Over8000,
        .oneOver6400: .shutter1Over6400,
        .oneOver5000: .shutter1Over5000,
        .oneOver4000: .shutter1Over4000,
        .oneOver3200: .shutter1Over3200,
        .oneOver2000: .shutter1Over2000,
        .oneOver2500: .shutter1Over2500,
        .oneOver1600: .shutter1Over1600,
        .oneOver1250: .shutter1Over1250,
        .oneOver1000: .shutter1Over1000,
        .oneOver800: .shutter1Over800,
        .oneOver640: .shutter1Over640,
        .oneOver500: .shutter1Over500,
        .oneOver400: .shutter1Over400,
        .oneOver320: .shutter1Over320,
        .oneOver240: .shutter1Over240,
        .oneOver200: .shutter1Over200,
        .oneOver160: .shutter1Over160,
        .oneOver120: .shutter1Over120,
        .oneOver100: .shutter1Over100,
        .oneOver80: .shutter1Over80,
        .oneOver60: .shutter1Over60,
        .oneOver50: .shutter1Over50,
        .oneOver40: .shutter1Over40,
        .oneOver30: .shutter1Over30,
        .oneOver25: .shutter1Over25,
        .oneOver15: .shutter1Over15,
        .oneOver10: .shutter1Over10,
        .oneOver8: .shutter1Over8,
        .oneOver6: .shutter1Over6,
        .oneOver4: .shutter1Over4,
        .oneOver3: .shutter1Over3,
        .oneOver2: .shutter1Over2,
        .oneOver1_5: .shutter1Over1_5,
        .one: .shutter1])
}

/// Extension that add conversion from/to arsdk enum
extension CameraIso: ArsdkMappableEnum {

    /// Create set of camera iso sentivities from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all iso sentivities set in bitField
    static func createSetFrom(bitField: UInt64) -> Set<CameraIso> {
        var result = Set<CameraIso>()
        ArsdkFeatureCameraIsoSensitivityBitField.forAllSet(in: UInt(bitField)) { arsdkValue in
            if let mode = CameraIso(fromArsdk: arsdkValue) {
                result.insert(mode)
            }
        }
        return result
    }

    static var arsdkMapper = Mapper<CameraIso, ArsdkFeatureCameraIsoSensitivity>([
        .iso50: .iso50,
        .iso64: .iso64,
        .iso80: .iso80,
        .iso100: .iso100,
        .iso125: .iso125,
        .iso160: .iso160,
        .iso200: .iso200,
        .iso250: .iso250,
        .iso320: .iso320,
        .iso400: .iso400,
        .iso500: .iso500,
        .iso640: .iso640,
        .iso800: .iso800,
        .iso1200: .iso1200,
        .iso1600: .iso1600,
        .iso2500: .iso2500,
        .iso3200: .iso3200])
}

/// Extension that add conversion from/to arsdk enum
extension CameraEvCompensation: ArsdkMappableEnum {

    /// Create set of camera exposure compensation values from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all exposure compensation values set in bitField
    static func createSetFrom(bitField: UInt64) -> Set<CameraEvCompensation> {
        var result = Set<CameraEvCompensation>()
        ArsdkFeatureCameraEvCompensationBitField.forAllSet(in: UInt(bitField)) { arsdkValue in
            if let mode = CameraEvCompensation(fromArsdk: arsdkValue) {
                result.insert(mode)
            }
        }
        return result
    }

    static var arsdkMapper = Mapper<CameraEvCompensation, ArsdkFeatureCameraEvCompensation>([
        .evMinus3_00: .evMinus3_00,
        .evMinus2_67: .evMinus2_67,
        .evMinus2_33: .evMinus2_33,
        .evMinus2_00: .evMinus2_00,
        .evMinus1_67: .evMinus1_67,
        .evMinus1_33: .evMinus1_33,
        .evMinus1_00: .evMinus1_00,
        .evMinus0_67: .evMinus0_67,
        .evMinus0_33: .evMinus0_33,
        .ev0_00: .ev0_00,
        .ev0_33: .ev0_33,
        .ev0_67: .ev0_67,
        .ev1_00: .ev1_00,
        .ev1_33: .ev1_33,
        .ev1_67: .ev1_67,
        .ev2_00: .ev2_00,
        .ev2_33: .ev2_33,
        .ev2_67: .ev2_67,
        .ev3_00: .ev3_00])
}

/// Extension that add conversion from/to arsdk enum
extension CameraWhiteBalanceMode: ArsdkMappableEnum {

    /// Create set of white balance modes from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all white balance modes set in bitField
    static func createSetFrom(bitField: UInt) -> Set<CameraWhiteBalanceMode> {
        var result = Set<CameraWhiteBalanceMode>()
        ArsdkFeatureCameraWhiteBalanceModeBitField.forAllSet(in: bitField) { arsdkValue in
            if let mode = CameraWhiteBalanceMode(fromArsdk: arsdkValue) {
                result.insert(mode)
            }
        }
        return result
    }

    static let arsdkMapper = Mapper<CameraWhiteBalanceMode, ArsdkFeatureCameraWhiteBalanceMode>([
        .automatic: .automatic,
        .candle: .candle,
        .sunset: .sunset,
        .incandescent: .incandescent,
        .warmWhiteFluorescent: .warmWhiteFluorescent,
        .halogen: .halogen,
        .fluorescent: .fluorescent,
        .coolWhiteFluorescent: .coolWhiteFluorescent,
        .flash: .flash,
        .daylight: .daylight,
        .sunny: .sunny,
        .cloudy: .cloudy,
        .snow: .snow,
        .hazy: .hazy,
        .shaded: .shaded,
        .greenFoliage: .greenFoliage,
        .blueSky: .blueSky,
        .custom: .custom])
}

/// Extension that add conversion from/to arsdk enum
extension CameraWhiteBalanceTemperature: ArsdkMappableEnum {

    /// Create set of white balance temperatures from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all white balance temperatures set in bitField
    static func createSetFrom(bitField: UInt64) -> Set<CameraWhiteBalanceTemperature> {
        var result = Set<CameraWhiteBalanceTemperature>()
        ArsdkFeatureCameraWhiteBalanceTemperatureBitField.forAllSet(in: bitField) { arsdkValue in
            if let temperature = CameraWhiteBalanceTemperature(fromArsdk: arsdkValue) {
                result.insert(temperature)
            }
        }
        return result
    }

    static let arsdkMapper = Mapper<CameraWhiteBalanceTemperature, ArsdkFeatureCameraWhiteBalanceTemperature>([
        .k1500: .T1500,
        .k1750: .T1750,
        .k2000: .T2000,
        .k2250: .T2250,
        .k2500: .T2500,
        .k2750: .T2750,
        .k3000: .T3000,
        .k3250: .T3250,
        .k3500: .T3500,
        .k3750: .T3750,
        .k4000: .T4000,
        .k4250: .T4250,
        .k4500: .T4500,
        .k4750: .T4750,
        .k5000: .T5000,
        .k5250: .T5250,
        .k5500: .T5500,
        .k5750: .T5750,
        .k6000: .T6000,
        .k6250: .T6250,
        .k6500: .T6500,
        .k6750: .T6750,
        .k7000: .T7000,
        .k7250: .T7250,
        .k7500: .T7500,
        .k7750: .T7750,
        .k8000: .T8000,
        .k8250: .T8250,
        .k8500: .T8500,
        .k8750: .T8750,
        .k9000: .T9000,
        .k9250: .T9250,
        .k9500: .T9500,
        .k9750: .T9750,
        .k10000: .T10000,
        .k10250: .T10250,
        .k10500: .T10500,
        .k10750: .T10750,
        .k11000: .T11000,
        .k11250: .T11250,
        .k11500: .T11500,
        .k11750: .T11750,
        .k12000: .T12000,
        .k12250: .T12250,
        .k12500: .T12500,
        .k12750: .T12750,
        .k13000: .T13000,
        .k13250: .T13250,
        .k13500: .T13500,
        .k13750: .T13750,
        .k14000: .T14000,
        .k14250: .T14250,
        .k14500: .T14500,
        .k14750: .T14750,
        .k15000: .T15000])
}

/// Extension that add conversion from/to arsdk enum
extension CameraStyle: ArsdkMappableEnum {
    /// Create set of camera styles from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all camera styles set in bitField
    static func createSetFrom(bitField: UInt) -> Set<CameraStyle> {
        var result = Set<CameraStyle>()
        ArsdkFeatureCameraStyleBitField.forAllSet(in: bitField) { arsdkValue in
            if let mode = CameraStyle(fromArsdk: arsdkValue) {
                result.insert(mode)
            }
        }
        return result
    }

    static let arsdkMapper = Mapper<CameraStyle, ArsdkFeatureCameraStyle>([
        .standard: .standard,
        .plog: .plog,
        .intense: .intense,
        .pastel: .pastel])
}

/// Extension that add conversion from/to arsdk enum
extension CameraRecordingMode: ArsdkMappableEnum {

    /// Create set of recording modes from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all recording modes set in bitField
    static func createSetFrom(bitField: UInt) -> Set<CameraRecordingMode> {
        var result = Set<CameraRecordingMode>()
        ArsdkFeatureCameraRecordingModeBitField.forAllSet(in: bitField) { arsdkValue in
            if let mode = CameraRecordingMode(fromArsdk: arsdkValue) {
                result.insert(mode)
            }
        }
        return result
    }

    static let arsdkMapper = Mapper<CameraRecordingMode, ArsdkFeatureCameraRecordingMode>([
        .standard: .standard,
        .hyperlapse: .hyperlapse,
        .slowMotion: .slowMotion,
        .highFramerate: .highFramerate])
}

/// Extension that add conversion from/to arsdk enum
extension CameraRecordingResolution: ArsdkMappableEnum {

    /// Create set of recording resolution from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all recording resolutions set in bitField
    static func createSetFrom(bitField: UInt) -> Set<CameraRecordingResolution> {
        var result = Set<CameraRecordingResolution>()
        ArsdkFeatureCameraResolutionBitField.forAllSet(in: bitField) { arsdkValue in
            if let mode = CameraRecordingResolution(fromArsdk: arsdkValue) {
                result.insert(mode)
            }
        }
        return result
    }

    static let arsdkMapper = Mapper<CameraRecordingResolution, ArsdkFeatureCameraResolution>([
        .resDci4k: .resDci4k,
        .resUhd4k: .resUhd4k,
        .res1080p: .res1080p,
        .res2_7k: .res2_7k,
        .res720p: .res720p,
        .res480p: .res480p,
        .res1080pSd: .res1080pSd])
}

/// Extension that add conversion from/to arsdk enum
extension CameraRecordingFramerate: ArsdkMappableEnum {

    /// Create set of recording framerates from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all recording framerates set in bitField
    static func createSetFrom(bitField: UInt) -> Set<CameraRecordingFramerate> {
        var result = Set<CameraRecordingFramerate>()
        ArsdkFeatureCameraFramerateBitField.forAllSet(in: bitField) { arsdkValue in
            if let mode = CameraRecordingFramerate(fromArsdk: arsdkValue) {
                result.insert(mode)
            }
        }
        return result
    }

    static let arsdkMapper = Mapper<CameraRecordingFramerate, ArsdkFeatureCameraFramerate>([
        .fps24: .fps24,
        .fps25: .fps25,
        .fps30: .fps30,
        .fps48: .fps48,
        .fps50: .fps50,
        .fps60: .fps60,
        .fps96: .fps96,
        .fps100: .fps100,
        .fps120: .fps120,
        .fps9: .fps9])
}

/// Extension that add conversion from/to arsdk enum
extension CameraHyperlapseValue: ArsdkMappableEnum {
    /// Create set of hyperlapse from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all hyperlapse set in bitField
    static func createSetFrom(bitField: UInt) -> Set<CameraHyperlapseValue> {
        var result = Set<CameraHyperlapseValue>()
        ArsdkFeatureCameraHyperlapseValueBitField.forAllSet(in: bitField) { arsdkValue in
            if let value = CameraHyperlapseValue(fromArsdk: arsdkValue) {
                result.insert(value)
            }
        }
        return result
    }

    static let arsdkMapper = Mapper<CameraHyperlapseValue, ArsdkFeatureCameraHyperlapseValue>([
        .ratio15: .ratio15,
        .ratio30: .ratio30,
        .ratio60: .ratio60,
        .ratio120: .ratio120,
        .ratio240: .ratio240])
}

/// Extension that add conversion from/to arsdk enum
extension CameraPhotoMode: ArsdkMappableEnum {
    /// Create set of photo modes from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all photo modes set in bitField
    static func createSetFrom(bitField: UInt) -> Set<CameraPhotoMode> {
        var result = Set<CameraPhotoMode>()
        ArsdkFeatureCameraPhotoModeBitField.forAllSet(in: bitField) { arsdkValue in
            if let value = CameraPhotoMode(fromArsdk: arsdkValue) {
                result.insert(value)
            }
        }
        return result
    }

    static let arsdkMapper = Mapper<CameraPhotoMode, ArsdkFeatureCameraPhotoMode>([
        .single: .single,
        .bracketing: .bracketing,
        .burst: .burst,
        .timeLapse: .timeLapse,
        .gpsLapse: .gpsLapse])
}

/// Extension that add conversion from/to arsdk enum
extension CameraPhotoFormat: ArsdkMappableEnum {
    /// Create set of photo formats from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all photo formats set in bitField
    static func createSetFrom(bitField: UInt) -> Set<CameraPhotoFormat> {
        var result = Set<CameraPhotoFormat>()
        ArsdkFeatureCameraPhotoFormatBitField.forAllSet(in: bitField) { arsdkValue in
            if let value = CameraPhotoFormat(fromArsdk: arsdkValue) {
                result.insert(value)
            }
        }
        return result
    }

    static let arsdkMapper = Mapper<CameraPhotoFormat, ArsdkFeatureCameraPhotoFormat>([
        .fullFrame: .fullFrame,
        // large in not available on ArsdkFeatureCameraPhotoFormat
        .rectilinear: .rectilinear])
}

/// Extension that add conversion from/to arsdk enum
extension CameraPhotoFileFormat: ArsdkMappableEnum {
    /// Create set of photo file formats from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all photo file formats set in bitField
    static func createSetFrom(bitField: UInt) -> Set<CameraPhotoFileFormat> {
        var result = Set<CameraPhotoFileFormat>()
        ArsdkFeatureCameraPhotoFileFormatBitField.forAllSet(in: bitField) { arsdkValue in
            if let value = CameraPhotoFileFormat(fromArsdk: arsdkValue) {
                result.insert(value)
            }
        }
        return result
    }

    static let arsdkMapper = Mapper<CameraPhotoFileFormat, ArsdkFeatureCameraPhotoFileFormat>([
        .jpeg: .jpeg,
        .dng: .dng,
        .dngAndJpeg: .dngJpeg])
}

/// Extension that add conversion from/to arsdk enum
extension CameraBurstValue: ArsdkMappableEnum {
    /// Create set of photo burst value from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all photo burst values set in bitField
    static func createSetFrom(bitField: UInt) -> Set<CameraBurstValue> {
        var result = Set<CameraBurstValue>()
        ArsdkFeatureCameraBurstValueBitField.forAllSet(in: bitField) { arsdkValue in
            if let value = CameraBurstValue(fromArsdk: arsdkValue) {
                result.insert(value)
            }
        }
        return result
    }

    static let arsdkMapper = Mapper<CameraBurstValue, ArsdkFeatureCameraBurstValue>([
        .burst14Over4s: .burst14Over4s,
        .burst14Over2s: .burst14Over2s,
        .burst14Over1s: .burst14Over1s,
        .burst10Over4s: .burst10Over4s,
        .burst10Over2s: .burst10Over2s,
        .burst10Over1s: .burst10Over1s,
        .burst4Over4s: .burst4Over4s,
        .burst4Over2s: .burst4Over2s,
        .burst4Over1s: .burst4Over1s])
}

/// Extension that add conversion from/to arsdk enum
extension CameraBracketingValue: ArsdkMappableEnum {
    /// Create set of photo bracketing value from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing photo bracketing values set in bitField
    static func createSetFrom(bitField: UInt) -> Set<CameraBracketingValue> {
        var result = Set<CameraBracketingValue>()
        ArsdkFeatureCameraBracketingPresetBitField.forAllSet(in: bitField) { arsdkValue in
            if let value = CameraBracketingValue(fromArsdk: arsdkValue) {
                result.insert(value)
            }
        }
        return result
    }

    static let arsdkMapper = Mapper<CameraBracketingValue, ArsdkFeatureCameraBracketingPreset>([
        .preset1ev: .preset1ev,
        .preset2ev: .preset2ev,
        .preset3ev: .preset3ev,
        .preset1ev2ev: .preset1ev2ev,
        .preset1ev3ev: .preset1ev3ev,
        .preset2ev3ev: .preset2ev3ev,
        .preset1ev2ev3ev: .preset1ev2ev3ev])
}

/// Extension that add conversion from/to arsdk enum
extension CameraZoomControlMode: ArsdkMappableEnum {

    static let arsdkMapper = Mapper<CameraZoomControlMode, ArsdkFeatureCameraZoomControlMode>([
        .level: .level,
        .velocity: .velocity])
}

extension CameraExposureLockMode {
    /// Compare the lock mode with requested lock mode.
    ///
    /// Note : if the mode is `.region` (Lock exposure on a given region of interest), the test compares only
    /// centerX and centerY values, the width and height dimensions will be returned by the drone (they are not yet
    /// known at the moment of the request)
    ///
    /// - Parameter lockMode: the lockMode to compare
    /// - Returns: return true if the lockMode as parameter lock matches self
    func isSameRequest(as lockMode: CameraExposureLockMode?) -> Bool {
        if let lockMode = lockMode {
            switch (self, lockMode) {
            case (.none, .none),
                 (.currentValues, .currentValues):
                return true
            case let (.region(lx, ly, _, _), .region(rx, ry, _, _)):
                return lx == rx && ly == ry
            default:
                return false
            }
        }
        return false
    }
}
