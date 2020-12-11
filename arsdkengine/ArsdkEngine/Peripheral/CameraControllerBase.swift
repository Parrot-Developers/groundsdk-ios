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

/// Base camera component controller for camera
class CameraControllerBase: CameraBackend {

    /// Component settings key
    public static let settingKey = "Camera-main"

    /// Camera component
    private(set) var camera: CameraCore!

    /// Store device specific values
    private var deviceStore: SettingsStore?

    /// Preset store
    private var presetStore: SettingsStore?

    /// Camera global activation state
    private var active: Bool = false

    /// All settings that can be stored
    enum SettingKey: String, StoreKey {
        case modeKey = "mode"
        case hdrKey = "hdr"
        case recordingKey = "recording"
        case hyperlapseValueKey = "hyperlapse"
        case autoRecordKey = "autoRecord"
        case photoKey = "photo"
        case burstValueKey  = "burst"
        case bracketingValueKey  = "bracketing"
        case maxZoomSpeedKey = "maxZoomSpeed"
        case zoomVelocityQualityDegradationAllowedKey = "zoomVelocityQualityDegAllowed"
        case exposureKey = "exposure"
        case exposureCompensationKey = "exposureCompensation"
        case exposureCompensationValuesKey = "exposureCompensationValues"
        case exposureModeValueKey = "exposureMode"
        case exposureManualShutterSpeedValueKey = "exposureManualShutterSpeed"
        case exposureManualIsoSensitivityValueKey = "exposureManualIsoSensitivity"
        case exposureMaximumIsoSensitivityValueKey = "exposureMaximumIsoSensitivity"
        case autoExposureMeteringModeValueKey = "autoExposureMeteringMode"
        case shutterSpeedKey = "shutterSpeed"
        case whiteBalanceKey = "whiteBalance"
        case whiteBalanceModeValueKey = "whiteBalanceMode"
        case whiteBalanceTemperatureValueKey = "whiteBalanceTemperature"
        case styleKey = "style"
        case activeStyleKey = "activeStyle"
        case saturationKey = "saturation"
        case contrastKey = "contrast"
        case sharpnessKey = "sharpness"
        case modelKey = "model"
        case timelapseIntervalMinKey = "timelapseIntervalMin"
        case gpslapseIntervalMinKey = "gpslapseIntervalMin"
    }

    /// Stored settings
    enum Setting: Hashable {
        case mode(CameraMode)
        case hdr(Bool)
        case recording(mode: CameraRecordingMode, resolution: CameraRecordingResolution,
            framerate: CameraRecordingFramerate, hyperlapse: CameraHyperlapseValue)
        case autoRecord(Bool)
        case photo(mode: CameraPhotoMode, format: CameraPhotoFormat, fileFormat: CameraPhotoFileFormat,
            burst: CameraBurstValue, bracketing: CameraBracketingValue, captureInterval: Double)
        case maxZoomSpeed(min: Double, current: Double, max: Double)
        case zoomVelocityQualityDegradation(allowed: Bool)
        case whiteBalance(mode: CameraWhiteBalanceMode, customTemperature: CameraWhiteBalanceTemperature)
        case exposure(mode: CameraExposureMode, manualShutterSpeed: CameraShutterSpeed,
            manualIsoSensitivity: CameraIso, maximumIsoSensitivity: CameraIso,
            autoExposureMeteringMode: CameraAutoExposureMeteringMode)
        case exposureCompensation(CameraEvCompensation)
        case style(activeStyle: CameraStyle, saturation: Int, contrast: Int, sharpness: Int)
        case saturation(min: Int, current: Int, max: Int)
        case contrast(min: Int, current: Int, max: Int)
        case sharpness(min: Int, current: Int, max: Int)
        case model(model: Model)

        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .mode: return .modeKey
            case .hdr: return .hdrKey
            case .recording: return .recordingKey
            case .autoRecord: return .autoRecordKey
            case .photo: return .photoKey
            case .maxZoomSpeed: return .maxZoomSpeedKey
            case .zoomVelocityQualityDegradation: return .zoomVelocityQualityDegradationAllowedKey
            case .exposureCompensation: return .exposureCompensationKey
            case .exposure: return .exposureKey
            case .whiteBalance: return .whiteBalanceKey
            case .style: return .activeStyleKey
            case .saturation: return .saturationKey
            case .contrast: return .contrastKey
            case .sharpness: return .sharpnessKey
            case .model: return .modelKey
            }
        }

        /// All values to allow enumerating settings
        static let allCases: [Setting] = [
            .mode(.recording),
            .hdr(false),
            .recording(mode: .standard, resolution: .resDci4k, framerate: .fps30, hyperlapse: .ratio15),
            .autoRecord(false),
            .photo(mode: .single, format: .rectilinear, fileFormat: .jpeg, burst: .burst14Over4s,
            bracketing: .preset1ev, captureInterval: 0.0),
            .maxZoomSpeed(min: 0.0, current: 0.0, max: 0.0),
            .zoomVelocityQualityDegradation(allowed: true),
            .whiteBalance(mode: .automatic, customTemperature: .k1500),
            .exposure(mode: .manual, manualShutterSpeed: .oneOver10000,
                      manualIsoSensitivity: .iso1200, maximumIsoSensitivity: .iso3200,
                      autoExposureMeteringMode: .standard),
            .exposureCompensation(.ev0_00),
            .style(activeStyle: .standard, saturation: 0, contrast: 0, sharpness: 0),
            .saturation(min: 0, current: 0, max: 0),
            .contrast(min: 0, current: 0, max: 0),
            .sharpness(min: 0, current: 0, max: 0),
            .model(model: .main)
        ]

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }

        static func == (lhs: Setting, rhs: Setting) -> Bool {
            return lhs.key == rhs.key
        }
    }

    /// Stored capabilities for settings
    enum Capabilities {
        case mode(Set<CameraMode>)
        case recording([CameraCore.RecordingCapabilitiesEntry])
        case hyperlapseValue(Set<CameraHyperlapseValue>)
        case photo([CameraCore.PhotoCapabilitiesEntry])
        case burstValue(Set<CameraBurstValue>)
        case bracketingValue(Set<CameraBracketingValue>)
        case whiteBalanceMode(Set<CameraWhiteBalanceMode>)
        case whiteBalanceTemperature(Set<CameraWhiteBalanceTemperature>)
        case exposureCompensationValues(Set<CameraEvCompensation>)
        case exposureMode(Set<CameraExposureMode>)
        case exposureShutterSpeed(Set<CameraShutterSpeed>)
        case exposureManualIsoSensitivity(Set<CameraIso>)
        case exposureMaximumIsoSensitivity(Set<CameraIso>)
        case style(Set<CameraStyle>)
        case timelapseIntervalMin(min: Double)
        case gpslapseIntervalMin(min: Double)

        /// All values to allow enumerating settings
        static let allCases: [Capabilities] = [
            .mode([]),
            .recording([]),
            .hyperlapseValue([]),
            .photo([]),
            .burstValue([]),
            .bracketingValue([]),
            .whiteBalanceMode([]),
            .whiteBalanceTemperature([]),
            .exposureCompensationValues([]),
            .exposureMode([]),
            .exposureShutterSpeed([]),
            .exposureManualIsoSensitivity([]),
            .exposureMaximumIsoSensitivity([]),
            .style([]),
            .timelapseIntervalMin(min: 0.0),
            .gpslapseIntervalMin(min: 0.0)
        ]

        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .mode: return .modeKey
            case .recording: return .recordingKey
            case .hyperlapseValue: return .hyperlapseValueKey
            case .photo: return .photoKey
            case .burstValue: return .burstValueKey
            case .bracketingValue: return .bracketingValueKey
            case .whiteBalanceMode: return .whiteBalanceModeValueKey
            case .whiteBalanceTemperature: return .whiteBalanceTemperatureValueKey
            case .exposureCompensationValues: return .exposureCompensationValuesKey
            case .exposureMode: return .exposureModeValueKey
            case .exposureShutterSpeed: return .exposureManualShutterSpeedValueKey
            case .exposureManualIsoSensitivity: return .exposureManualIsoSensitivityValueKey
            case .exposureMaximumIsoSensitivity: return .exposureMaximumIsoSensitivityValueKey
            case .style: return .styleKey
            case .timelapseIntervalMin: return .timelapseIntervalMinKey
            case .gpslapseIntervalMin: return .gpslapseIntervalMinKey
            }
        }
    }

    /// Setting values as received from the drone
    private var droneSettings = Set<Setting>()

    /// Store recording values for each mode
    private var recordingPresets: RecordingPresets!

    /// Store photo values for each mode
    private var photoPresets: PhotoPresets!

    /// Store white balance values
    private var whiteBalancePresets: WhiteBalancePresets!

    /// Store exposure values
    private var exposurePresets: ExposurePresets!

    /// Store exposure compensation values
    private var exposureCompensationPresets: ExposureCompensationPresets!

    /// Store style values
    private var stylePresets: StylePresets!

    /// Latest supported exposure compensation values received from the device.
    private var supportedValueExposureCompensation: Set<CameraEvCompensation> = []

    /// Model of camera
    public var model: Model?

    /// Whether the drone is connected or not
    public var connected: Bool = false

    /// Constructor
    ///
    /// - Parameters:
    ///    - peripheralStore: store where this peripheral will be stored
    ///    - deviceStore: store for device specific values
    ///    - presetStore: preset store
    ///    - model: model of camera
    init(peripheralStore: ComponentStoreCore, deviceStore: SettingsStore?, presetStore: SettingsStore?,
         model: Model?) {
        self.deviceStore = deviceStore
        self.presetStore = presetStore

        if let model = model {
            self.model = model
        } else {
            if let _model: Model = presetStore?.read(key: SettingKey.modelKey) {
                self.model = _model
            } else {
                self.model = .main
            }
        }

        switch self.model! {
        case .main:
            camera = MainCameraCore(store: peripheralStore, backend: self)

        case .thermal:
            camera = ThermalCameraCore(store: peripheralStore, backend: self)

        case .blendedThermal:
            camera = BlendedThermalCameraCore(store: peripheralStore, backend: self)
        default:
            break
        }
        recordingPresets = RecordingPresets(recordingSetting: camera.recordingSettings)
        photoPresets = PhotoPresets(photoSettings: camera.photoSettings)
        whiteBalancePresets = WhiteBalancePresets(whiteBalanceSetting: camera.whiteBalanceSettings)
        exposurePresets = ExposurePresets(exposureSettings: camera.exposureSettings)
        exposureCompensationPresets = ExposureCompensationPresets(
            exposureCompensationSetting: camera.exposureCompensationSetting)
        stylePresets = StylePresets(styleSettings: camera.styleSettings)

        // load settings
        if let deviceStore = deviceStore, let presetStore = presetStore, !deviceStore.new && !presetStore.new {
            loadPresets()
            camera.publish()
        }
    }

    /// Activate camera
    /// Does nothing in case the camera is already active
    public func activate() {
        if active {
            return
        }
        active = true
        camera.updateActiveFlag(active: true).notifyUpdated()
    }

    public func didConnect() {
        connected = true
        applyAllPresets()
    }

    public func didDisconnect() {
        connected = false
        // unpublish if offline settings are disabled
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            camera.unpublish()
        }
    }

    /// Publish camera
    public func publish() {
        camera.publish()
    }

    /// Deactivate camera
    /// Does nothing in case the camera is already inactive
    public func deactivate() {
        if !active {
            return
        }
        active = false
        // reset values
        camera.cancelSettingsRollback().updateActiveFlag(active: false)
        camera.resetZoomValues()
        if !connected {
            // set bitrate to unknown
            camera.update(recordingBitrate: 0)
            // force photo and recording state to unavailable
            camera.update(photoState: .unavailable)
            camera.update(recordingState: .unavailable)
        }
        camera.notifyUpdated()
    }

    public func willForget() {
        deviceStore?.clear()
        camera.unpublish()
    }

    /// Set camera mode
    /// - Parameter mode: new mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
   func set(mode: CameraMode) -> Bool {
        presetStore?.write(key: SettingKey.modeKey.rawValue, value: mode).commit()
        if connected {
            return sendCameraModeCommand(mode)
        } else {
            camera.update(mode: mode).notifyUpdated()
            return false
        }
    }

    /// Change camera exposure mode
    ///
    /// - Parameters:
    ///   - exposureMode: requested exposure mode
    ///   - manualShutterSpeed: requested shutter speed when mode is `manualShutterSpeed` or `manual`
    ///   - manualIsoSensitivity: requested iso sensitivity when mode is `manualIsoSensitivity` or `manual`
    ///   - maximumIsoSensitivity: maximum iso sensitivity when mode is `automatic`
    ///   - autoExposureMeteringMode: requested auto exposure metering mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(exposureMode: CameraExposureMode, manualShutterSpeed: CameraShutterSpeed,
             manualIsoSensitivity: CameraIso, maximumIsoSensitivity: CameraIso,
             autoExposureMeteringMode: CameraAutoExposureMeteringMode) -> Bool {

        let shouldSendCommand = exposureMode != exposurePresets.mode
                                || manualShutterSpeed != exposurePresets.manualShutterSpeed
                                || manualIsoSensitivity != exposurePresets.manualIsoSensitivity
                                || maximumIsoSensitivity != exposurePresets.maximumIsoSensitivity

        exposurePresets.update(mode: exposureMode, manualShutterSpeed: manualShutterSpeed,
                               manualIsoSensitivity: manualIsoSensitivity,
                                maximumIsoSensitivity: maximumIsoSensitivity,
                                autoExposureMeteringMode: autoExposureMeteringMode)
        presetStore?.write(key: SettingKey.exposureKey, value: exposurePresets.data).commit()

        if connected && shouldSendCommand && sendExposureCommand(
            exposureMode: exposureMode, manualShutterSpeed: manualShutterSpeed,
            manualIsoSensitivity: manualIsoSensitivity, maximumIsoSensitivity: maximumIsoSensitivity,
            autoExposureMeteringMode: autoExposureMeteringMode) {

            camera.update(exposureMode: exposureMode).update(manualShutterSpeed: manualShutterSpeed)
                .update(manualIsoSensitivity: manualIsoSensitivity)
                .update(maximumIsoSensitivity: maximumIsoSensitivity)
                .update(autoExposureMeteringMode: autoExposureMeteringMode)
            computeEVCompensationAvailableValues()
            return true

        } else {
            camera.update(exposureMode: exposureMode).update(manualShutterSpeed: manualShutterSpeed)
                .update(manualIsoSensitivity: manualIsoSensitivity)
                .update(maximumIsoSensitivity: maximumIsoSensitivity)
                .update(autoExposureMeteringMode: autoExposureMeteringMode)
            computeEVCompensationAvailableValues()
            camera.notifyUpdated()
        }

        return false
    }

    /// Computes and updates exposure compensation available values.
    /// In manual exposure mode and in exposure lock mode, exposure compensation setting is not available.
    /// So in those cases, the list of supported exposure compensation values is cleared.
    func computeEVCompensationAvailableValues() {
        if (camera.exposureLock != nil && (camera.exposureLock!.mode != .none))
            || (camera.exposureSettings.mode == .manual) {
            camera.update(supportedExposureCompensationValues: [])
        } else {
            camera.update(supportedExposureCompensationValues: supportedValueExposureCompensation)
        }
    }

    func set(exposureLockMode: CameraExposureLockMode) -> Bool {
        return connected && sendExposureLockCommand(mode: exposureLockMode)
    }

    /// Change camera exposure compensation
    ///
    /// - Parameter exposureCompensation: requested exposure compensation value
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(exposureCompensation: CameraEvCompensation) -> Bool {
        let shouldSendCommand = exposureCompensation != exposureCompensationPresets.exposureCompensation
        exposureCompensationPresets.update(exposureCompensation: exposureCompensation)
        presetStore?.write(key: SettingKey.exposureCompensationKey.rawValue,
                           value: exposureCompensationPresets.data).commit()

        if connected && shouldSendCommand
            && sendExposureCompensationCommand(value: exposureCompensation) {
            camera.update(exposureCompensationValue: exposureCompensation)
            return true
        } else {
            camera.update(exposureCompensationValue: exposureCompensation)
                .notifyUpdated()
        }
        return false
    }

    /// Change the white balance mode
    ///
    /// - Parameters:
    ///   - whiteBalanceMode: requested white balance mode
    ///   - customTemperature: white balance temperature when mode is `custom`
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(whiteBalanceMode: CameraWhiteBalanceMode, customTemperature: CameraWhiteBalanceTemperature) -> Bool {
        let shouldSendCommand = customTemperature != whiteBalancePresets.customTemperature
                                || whiteBalanceMode != whiteBalancePresets.mode

        whiteBalancePresets.update(mode: whiteBalanceMode, customTemperature: customTemperature)
        presetStore?.write(key: SettingKey.whiteBalanceKey.rawValue, value: whiteBalancePresets.data).commit()

        if connected && shouldSendCommand
            && sendWhiteBalanceCommand(mode: whiteBalanceMode, customTemperature: customTemperature) {
            camera.update(whiteBalanceMode: whiteBalanceMode).update(customWhiteBalanceTemperature: customTemperature)
            return true
        } else {
            camera.update(whiteBalanceMode: whiteBalanceMode).update(customWhiteBalanceTemperature: customTemperature)
                  .notifyUpdated()
        }
        return false
    }

    /// Change the white balance lock
    ///
    /// - Parameter whiteBalanceLock: white balance lock
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(whiteBalanceLock: Bool) -> Bool {
        return sendWhiteBalanceLockedCommand(lock: whiteBalanceLock)
    }
    /// Change hdr setting
    ///
    /// - Parameter hdr: new hdr setting value
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(hdr: Bool) -> Bool {
        presetStore?.write(key: SettingKey.hdrKey.rawValue, value: hdr).commit()
        if connected {
            return sendHdrSettingCommand(hdr)
        } else {
            camera.update(hdrSetting: hdr).notifyUpdated()
            return false
        }
    }

    /// Changes the active image style
    ///
    /// - Parameter activeStyle: requested image style
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(activeStyle: CameraStyle) -> Bool {
        let shouldSendCommand = activeStyle != stylePresets.activeStyle
        stylePresets.update(activeStyle: activeStyle)
        presetStore?.write(key: SettingKey.activeStyleKey.rawValue, value: stylePresets.data).commit()

        if connected && shouldSendCommand
            && sendActiveStyleCommand(style: activeStyle) {
            camera.update(activeStyle: activeStyle)
            return true
        } else {
            camera.update(activeStyle: activeStyle).notifyUpdated()
        }
        return false
    }

    /// Changes the active image style parameters
    ///
    /// - Parameter styleParameters: new saturation, contrast and sharpness parameters
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(styleParameters: (saturation: Int, contrast: Int, sharpness: Int)) -> Bool {
        let shouldSendCommand = styleParameters.saturation != stylePresets.saturation
            || styleParameters.contrast != stylePresets.contrast || styleParameters.sharpness != stylePresets.sharpness
        stylePresets.update(saturation: styleParameters.saturation, contrast: styleParameters.contrast,
                            sharpness: styleParameters.sharpness)
        presetStore?.write(key: SettingKey.activeStyleKey.rawValue, value: stylePresets.data).commit()

        // read min & max value for each parameters
        var minSaturation = 0
        var maxSaturation = 0
        var minContrast = 0
        var maxContrast = 0
        var minSharpness = 0
        var maxSharpness = 0

        if let rangeSaturation: (min: Int, max: Int) = deviceStore?.readRange(key: SettingKey.saturationKey),
           let rangeContrast: (min: Int, max: Int) = deviceStore?.readRange(key: SettingKey.contrastKey),
           let rangeSharpness: (min: Int, max: Int) = deviceStore?.readRange(key: SettingKey.sharpnessKey) {
            minSaturation = rangeSaturation.min
            maxSaturation = rangeSaturation.max
            minContrast = rangeContrast.min
            maxContrast = rangeContrast.max
            minSharpness = rangeSharpness.min
            maxSharpness = rangeSharpness.max
        }

        if connected && shouldSendCommand
            && sendStyleParameterCommand(saturation: styleParameters.saturation, contrast: styleParameters.contrast,
                                         sharpness: styleParameters.sharpness) {
            camera.update(saturation: (min: minSaturation, value: styleParameters.saturation, max: maxSaturation))
            camera.update(contrast: (min: minContrast, value: styleParameters.contrast, max: maxContrast))
            camera.update(sharpness: (min: minSharpness, value: styleParameters.sharpness, max: maxSharpness))

            return true
        } else {
            camera.update(saturation: (min: minSaturation, value: styleParameters.saturation, max: maxSaturation))
            camera.update(contrast: (min: minContrast, value: styleParameters.contrast, max: maxContrast))
            camera.update(sharpness: (min: minSharpness, value: styleParameters.sharpness, max: maxSharpness))
            camera.notifyUpdated()
        }
        return false
    }

    /// Change the recording mode
    ///
    /// - Parameters:
    ///   - recordingMode: requested recording mode
    ///   - resolution: requested recording resolution, nil to keep the current resolution of the requested mode
    ///   - framerate: requested recording framerate, nil to keep the current framerate of the requested mode
    ///   - hyperlapse: requested hyperlapse value when mode is `hyperlapse`
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(recordingMode: CameraRecordingMode, resolution: CameraRecordingResolution?,
             framerate: CameraRecordingFramerate?, hyperlapse: CameraHyperlapseValue?) -> Bool {
        let resolution = resolution ?? recordingPresets.resolution(forMode: recordingMode)
        let framerate = framerate ?? recordingPresets.framerate(forMode: recordingMode, resolution: resolution)
        let fallbackHyperlapse = camera.recordingSettings.supportedHyperlapseValues.contains(
            recordingPresets.hyperlapseValue) ?
                recordingPresets.hyperlapseValue :
            camera.recordingSettings.supportedHyperlapseValues.sorted().first ?? .ratio15
        let hyperlapse = hyperlapse ?? fallbackHyperlapse
        let shouldSendCommand = (recordingMode != recordingPresets.mode ||
            resolution != recordingPresets.resolution(forMode: recordingMode) ||
            framerate != recordingPresets.framerate(forMode: recordingMode, resolution: resolution) ||
            (recordingMode == .hyperlapse && hyperlapse != fallbackHyperlapse))
        // update preset with new value
        recordingPresets.update(mode: recordingMode, resolution: resolution, framerate: framerate,
                                hyperlapseValue: hyperlapse, userSet: true)
        presetStore?.write(key: SettingKey.recordingKey, value: recordingPresets.data).commit()

        if connected && shouldSendCommand && sendRecordingCommand(
            recordingMode: recordingMode, resolution: resolution, framerate: framerate, hyperlapse: hyperlapse) {
            // update with new mode, resolution and framerate
            camera.update(recordingMode: recordingMode).update(recordingResolution: resolution)
                .update(recordingFramerate: framerate).update(recordingHyperlapseValue: hyperlapse)
            return true
        } else {
            camera.update(recordingMode: recordingMode).update(recordingResolution: resolution)
                .update(recordingFramerate: framerate).update(recordingHyperlapseValue: hyperlapse).notifyUpdated()
        }
        return false
    }

    /// Changes auto-record setting
    ///
    /// - Parameter autoRecord: requested auto-record setting value
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(autoRecord: Bool) -> Bool {
        presetStore?.write(key: SettingKey.autoRecordKey.rawValue, value: autoRecord).commit()
        if connected {
            return sendAutoRecordCommand(autoRecord)
        } else {
            camera.update(autoRecord: autoRecord).notifyUpdated()
            return false
        }
    }

    /// Change the photo mode
    ///
    /// - Parameters:
    ///   - photoMode: requested photo mode
    ///   - format: requested photo format
    ///   - fileFormat: requested photo file format
    ///   - burst: request bust value when photo mode is `burst`
    ///   - bracketing: request bracketing value when photo mode is `bracketing`
    ///   - gpslapseCaptureInterval: GPS-lapse interval value (in meters) when the photo mode is gps_lapse
    ///   - timelapseCaptureInterval: time-lapse interval value (in seconds) when the photo mode is time_lapse
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(photoMode: CameraPhotoMode, format: CameraPhotoFormat?, fileFormat: CameraPhotoFileFormat?,
             burst: CameraBurstValue?, bracketing: CameraBracketingValue?, gpslapseCaptureInterval: Double?,
             timelapseCaptureInterval: Double?) -> Bool {
        // get values from preset if required
        let format = format ?? photoPresets.format(forMode: photoMode)
        let fileFormat = fileFormat ?? photoPresets.fileFormat(forMode: photoMode, format: format)
        let fallbackBurst = camera.photoSettings.supportedBurstValues.contains(photoPresets.burstValue) ?
            photoPresets.burstValue :
            camera.photoSettings.supportedBurstValues.sorted().first ?? .burst14Over4s
        let burst = burst ?? fallbackBurst
        let fallbackBracketing = camera.photoSettings.supportedBracketingValues.contains(photoPresets.bracketingValue) ?
            photoPresets.bracketingValue :
            camera.photoSettings.supportedBracketingValues.sorted().first ?? .preset1ev
        let bracketing = bracketing ?? fallbackBracketing
        var captureIntervalToSend = 0.0

        if photoMode == .gpsLapse {
            if let gpslapseCaptureInterval = gpslapseCaptureInterval {
                captureIntervalToSend = gpslapseCaptureInterval
            } else {
                captureIntervalToSend = camera.photoSettings.gpslapseCaptureInterval
            }
        } else if photoMode == .timeLapse {
            if let timelapseCaptureInterval = timelapseCaptureInterval {
                captureIntervalToSend = timelapseCaptureInterval
            } else {
                captureIntervalToSend = camera.photoSettings.timelapseCaptureInterval
            }
        }

        let shouldSendCommand = (photoMode != photoPresets.mode || format != photoPresets.format(forMode: photoMode) ||
            (fileFormat != photoPresets.fileFormat(forMode: photoMode, format: format)) ||
            (photoMode == .burst && burst != fallbackBurst) ||
            (photoMode == .bracketing && bracketing != fallbackBracketing) ||
            (photoMode == .gpsLapse && captureIntervalToSend != photoPresets.gpslapseCaptureIntervalValue) ||
            (photoMode == .timeLapse && captureIntervalToSend != photoPresets.timelapseCaptureIntervalValue))
        // update preset with new value
        photoPresets.update(mode: photoMode, format: format, fileFormat: fileFormat,
                            burstValue: burst, bracketingValue: bracketing,
                            gpslapseCaptureIntervalValue: (photoMode == .gpsLapse ? captureIntervalToSend : nil),
                            timelapseCaptureIntervalValue: (photoMode == .timeLapse ? captureIntervalToSend : nil),
                            userSet: true)
        presetStore?.write(key: SettingKey.photoKey, value: photoPresets.data).commit()

        if connected && shouldSendCommand && sendPhotoCommand(
            photoMode: photoMode, photoFormat: format, photoFileFormat: fileFormat,
            bustValue: burst, bracketingValue: bracketing, captureInterval: captureIntervalToSend) {

            // update with new mode, resolution and framerate
            camera.update(photoMode: photoMode).update(photoFormat: format).update(photoFileFormat: fileFormat)
                .update(photoBurstValue: burst).update(photoBracketingValue: bracketing)
            if photoMode == .gpsLapse {
                camera.update(gpslapseCaptureInterval: captureIntervalToSend)
            } else if photoMode == .timeLapse {
                camera.update(timelapseCaptureInterval: captureIntervalToSend)
            }
            return true
        } else {
            camera.update(photoMode: photoMode).update(photoFormat: format).update(photoFileFormat: fileFormat)
                .update(photoBurstValue: burst).update(photoBracketingValue: bracketing)
            if photoMode == .gpsLapse {
                camera.update(gpslapseCaptureInterval: captureIntervalToSend)
            } else if photoMode == .timeLapse {
                camera.update(timelapseCaptureInterval: captureIntervalToSend)
            }

            camera.notifyUpdated()
        }
        return false
    }

    /// Sets the max zoom speed
    ///
    /// - Parameter maxZoomSpeed: the new max zoom speed
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(maxZoomSpeed: Double) -> Bool {
        presetStore?.write(key: SettingKey.maxZoomSpeedKey, value: maxZoomSpeed).commit()
        if connected {
            return sendMaxZoomSpeedCommand(value: maxZoomSpeed)
        } else {
            camera.update(
                maxZoomSpeedLowerBound: nil, maxZoomSpeed: maxZoomSpeed, maxZoomSpeedUpperBound: nil)
                .notifyUpdated()
        }
        return false
    }

    /// Sets the quality degradation allowance during zoom change with velocity.
    ///
    /// - Parameter qualityDegradationAllowance: the new allowance
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(qualityDegradationAllowance: Bool) -> Bool {
        presetStore?.write(key: SettingKey.zoomVelocityQualityDegradationAllowedKey, value: qualityDegradationAllowance)
            .commit()
        if connected {
            return sendZoomVelocityQualityDegradationAllowanceCommand(value: qualityDegradationAllowance)
        } else {
            camera.update(qualityDegradationAllowed: qualityDegradationAllowance).notifyUpdated()
        }
        return false
    }

    /// Control the zoom.
    ///
    /// Unit of the `target` depends on the value of the `mode` parameter:
    ///    - `.level`: target is in zoom level.1 means no zoom.
    ///                This value will be clamped to the `maxLossyLevel` if it is greater than this value.
    ///    - `.velocity`: value is in signed ratio (from -1 to 1) of `maxVelocity` setting value.
    ///                   Negative values will produce a zoom out, positive value will zoom in.
    ///
    /// - Parameters:
    ///   - mode: the mode that should be used to control the zoom.
    ///   - target: Either level or velocity zoom target, clamped in the correct range
    func control(mode: CameraZoomControlMode, target: Double) {
        // Subclass must override this function to set the value
    }

    /// Sets alignment offsets.
    ///
    /// - Parameter yawOffset: the new offset to apply to the yaw axis
    /// - Parameter pitchOffset: the new offset to apply to the pitch axis
    /// - Parameter rollOffset: the new offset to apply to the roll axis
    /// - Returns: true if the command has been sent, false otherwise
    func set(yawOffset: Double, pitchOffset: Double, rollOffset: Double) -> Bool {
        if connected {
            return sendAlignementCommand(yaw: yawOffset, pitch: pitchOffset, roll: rollOffset)
        }
        return false
    }

    /// Factory reset camera alignment.
    ///
    /// - Returns: true if the command has been sent, false otherwise
    func resetAlignment() -> Bool {
        if connected {
            return sendResetAlignmentCommand()
        }
        return false
    }

    /// Start taking photo(s)
    ///
    /// - Returns: true if the command has been sent, false else
    func startPhotoCapture() -> Bool {
        if connected {
            return sendStartPhotoCommand()
        }
        return false
    }

    /// Stop taking photo(s)
    ///
    /// - Returns: true if the command has been sent, false else
    func stopPhotoCapture() -> Bool {
        if connected {
            return sendStopPhotoCommand()
        }
        return false
    }

    /// Start recording
    ///
    /// - Returns: true if the command has been sent, false else
    func startRecording() -> Bool {
        if connected && active {
            return sendStartRecordingCommand()
        }
        return false
    }

    /// Stop recording
    ///
    /// - Returns: true if the command has been sent, false else
    func stopRecording() -> Bool {
        if connected && active {
            return sendStopRecordingCommand()
        }
        return false
    }

    /// Send mode command. Subclass must override this function to send the command
    ///
    /// - Parameter mode: requested mode
    /// - Returns: true if the command has been sent
    func sendCameraModeCommand(_ mode: CameraMode) -> Bool {
        return false
    }

    /// Send exposure command. Subclass must override this function to send the command
    ///
    /// - Parameters:
    ///   - exposureMode: requested mode
    ///   - manualShutterSpeed: requested shutter speed
    ///   - manualIsoSensitivity: requested iso sensitivity
    ///   - maximumIsoSensitivity: requested maximum iso sensitivity
    ///   - autoExposureMeteringMode: requested auto exposure metering mode
    /// - Returns: true if the command has been sent
    func sendExposureCommand(
        exposureMode: CameraExposureMode, manualShutterSpeed: CameraShutterSpeed, manualIsoSensitivity: CameraIso,
        maximumIsoSensitivity: CameraIso, autoExposureMeteringMode: CameraAutoExposureMeteringMode) -> Bool {
        return false
    }

    /// Sends exposure lock command. Subclass must override this function to send the command
    ///
    /// - Parameter mode: requested lock mode
    /// - Returns: true if the command has been sent
    func sendExposureLockCommand(mode: CameraExposureLockMode) -> Bool {
        return false
    }

    /// Send exposure compensation command. Subclass must override this function to send the command
    ///
    /// - Parameter value: requested exposure compensation
    /// - Returns: true if the command has been sent
    func sendExposureCompensationCommand(value: CameraEvCompensation) -> Bool {
        return false
    }

    /// Send white balance command. Subclass must override this function to send the command
    ///
    /// - Parameters:
    ///   - mode: requested mode
    ///   - customTemperature: requested temperature
    /// - Returns: true if the command has been sent
    func sendWhiteBalanceCommand(
        mode: CameraWhiteBalanceMode, customTemperature: CameraWhiteBalanceTemperature) -> Bool {
        return false
    }

    /// Send white balance lock command. Subclass must override this function to send the command
    ///
    /// - Parameter lock: requested lock
    /// - Returns: true if the command has been sent
    func sendWhiteBalanceLockedCommand(lock: Bool) -> Bool {
        return false
    }

    /// Send hdr setting command. Subclass must override this function to send the command
    ///
    /// - Parameter hdr: hdr setting value
    /// - Returns: true if the command has been sent
    func sendHdrSettingCommand(_ hdr: Bool) -> Bool {
        return false
    }

    /// Send command to set the active image style. Subclass must override this function to send the command.
    ///
    /// - Parameter style: style to set
    /// - Returns: true if the command has been sent
    func sendActiveStyleCommand(style: CameraStyle) -> Bool {
        return false
    }

    /// Send command to change active style parameters. Subclass must override this function to send the command.
    ///
    /// - Parameters:
    ///   - saturation: new saturation value
    ///   - contrast: new contrast value
    ///   - sharpness: new sharpness value
    func sendStyleParameterCommand(saturation: Int, contrast: Int, sharpness: Int) -> Bool {
        return false
    }

    /// Send recording settings command. Subclass must override this function to send the command
    ///
    /// - Parameters:
    ///   - recordingMode: requested recording mode
    ///   - resolution: requested resolution
    ///   - framerate: requested framerate
    ///   - hyperlapse: requested hyperlapse value
    /// - Returns: true if the command has been sent
    func sendRecordingCommand(
        recordingMode: CameraRecordingMode, resolution: CameraRecordingResolution, framerate: CameraRecordingFramerate,
        hyperlapse: CameraHyperlapseValue) -> Bool {
        return false
    }

    /// Send auto-record command
    ///
    /// - Parameter value: requested value
    /// - Returns: true if the command has been sent
    func sendAutoRecordCommand(_ value: Bool) -> Bool {
        return false
    }

    /// Send photo settings command. Subclass must override this function to send the command
    ///
    /// - Parameters:
    ///   - photoMode: requested photo mode
    ///   - photoFormat: requested format
    ///   - photoFileFormat: requested file format
    ///   - bustValue: requested burst value
    ///   - bracketingValue: requested hyperlapse
    ///   - captureInterval: capture interval
    /// - Returns: true if the command has been sent
    func sendPhotoCommand(
        photoMode: CameraPhotoMode, photoFormat: CameraPhotoFormat, photoFileFormat: CameraPhotoFileFormat,
        bustValue: CameraBurstValue, bracketingValue: CameraBracketingValue, captureInterval: Double) -> Bool {
        return false
    }

    /// Send take picture command. Subclass must override this function to send the command
    ///
    /// - Returns: true if the command has been sent
    func sendStartPhotoCommand() -> Bool {
        return false
    }

    /// Send stop taking picture(s) command. Subclass must override this function to send the command
    ///
    /// - Returns: true if the command has been sent
    func sendStopPhotoCommand() -> Bool {
        return false
    }

    /// Send start recording command. Subclass must override this function to send the command
    ///
    /// - Returns: true if the command has been sent
    func sendStartRecordingCommand() -> Bool {
        return false
    }

    /// Send stop recording command. Subclass must override this function to send the command
    ///
    /// - Returns: true if the command has been sent
    func sendStopRecordingCommand() -> Bool {
        return false
    }

    /// Send max zoom velocity. Subclass must override this function to send the command
    ///
    /// - Parameter value: the max zoom velocity tan(deg)/s.
    /// - Returns: true if the command has been sent
    func sendMaxZoomSpeedCommand(value: Double) -> Bool {
        return false
    }

    /// Send whether quality degradation is allowed when changing the zoom with velocity.
    /// Subclass must override this function to send the command
    ///
    /// - Parameter value: the new allowance
    /// - Returns: true if the command has been sent
    func sendZoomVelocityQualityDegradationAllowanceCommand(value: Bool) -> Bool {
        return false
    }

    /// Send camera alignment offsets.
    ///
    /// - Parameters:
    ///   - yaw: alignment offset applied to the yaw axis, in degrees
    ///   - pitch: alignment offset applied to the pitch axis, in degrees
    ///   - roll: alignment offset applied to the roll axis, in degrees
    /// - Returns: true if the command has been sent
    func sendAlignementCommand(yaw: Double, pitch: Double, roll: Double) -> Bool {
        return false
    }

    /// Send command to reset camera alignment.
    ///
    /// - Returns: true if the command has been sent
    func sendResetAlignmentCommand() -> Bool {
        return false
    }

    /// Preset has been changed
    func presetDidChange(presetStore: SettingsStore) {
        // reload preset store
        self.presetStore = presetStore
        loadPresets()
        if connected {
            applyAllPresets()
        }
    }

    /// Apply early presets
    ///
    /// Iterate settings received during connection
    /// These setting should be applied before any other
    private func applyEarlyPresets() {
        // iterate settings received during the connection
        for setting in droneSettings {
            switch setting {
            case .hdr(let hdr):
                if let preset: Bool = presetStore?.read(key: setting.key) {
                    if preset != hdr {
                        _ = sendHdrSettingCommand(preset)
                    }
                    camera.update(hdrSetting: preset)
                } else {
                    camera.update(hdrSetting: hdr)
                }
            default:
                break
            }
        }
    }

    /// Apply all presets
    private func applyAllPresets() {
        // NOTE: due to possible race condition on the firmware side, apply auto HDR first,
        //       before any photo and (in particular) recording configuration
        applyEarlyPresets()

        // first configure settings for the mode the drone is NOT in, to avoid extraneous pipeline reconfiguration
        let cameraModeBeforeSwitch = self.camera.modeSetting.mode
        if cameraModeBeforeSwitch != .photo {
            applyPhotoPreset()
        }
        if cameraModeBeforeSwitch != .recording {
            applyRecordingPreset()
        }

        // then switch to preset camera mode
        applyCameraModePreset()
        if cameraModeBeforeSwitch == .photo {
            applyPhotoPreset()
        }
        if cameraModeBeforeSwitch == .recording {
            applyRecordingPreset()
        }

        // apply rest of configuration
        applyOtherPresets()
    }

    /// Load saved settings
    private func loadPresets() {
        if let presetStore = presetStore, let deviceStore = deviceStore {
            for setting in Setting.allCases {
                switch setting {
                case .mode:
                    if let supportedModesValues: StorableArray<CameraMode> = deviceStore.read(key: setting.key),
                        let mode: CameraMode = presetStore.read(key: setting.key) {
                        let supportedModes = Set(supportedModesValues.storableValue)
                        if supportedModes.contains(mode) {
                            camera.update(supportedModes: supportedModes).update(mode: mode)
                        }
                    }
                case .hdr:
                    if let hdr: Bool = presetStore.read(key: setting.key) {
                        camera.update(hdrSetting: hdr)
                    }
                case .recording:
                    if let recordingCapabilities: StorableArray<CameraCore.RecordingCapabilitiesEntry> =
                        deviceStore.read(key: setting.key),
                        let recordingPresetsData: RecordingPresets.Data = presetStore.read(key: setting.key),
                        let supportedHyperlapseValues: StorableArray<CameraHyperlapseValue> =
                            deviceStore.read(key: SettingKey.hyperlapseValueKey) {
                        recordingPresets.load(data: recordingPresetsData)
                        camera.update(recordingCapabilities: recordingCapabilities.storableValue)
                            .update(supportedRecordingHyperlapseValues: Set(supportedHyperlapseValues.storableValue))
                            .update(recordingMode: recordingPresets.mode)
                            .update(recordingResolution: recordingPresets.resolution)
                            .update(recordingFramerate: recordingPresets.framerate)
                            .update(recordingHyperlapseValue: recordingPresets.hyperlapseValue)
                    }
                case .autoRecord:
                    if let value: Bool = presetStore.read(key: setting.key) {
                        camera.update(autoRecord: value)
                    }
                case .photo:
                    if let photoCapabilities: StorableArray<CameraCore.PhotoCapabilitiesEntry> =
                        deviceStore.read(key: setting.key),
                        let photoPresetsData: PhotoPresets.Data = presetStore.read(key: setting.key),
                        let supportedBurstValues: StorableArray<CameraBurstValue> =
                            deviceStore.read(key: SettingKey.burstValueKey),
                        let supportedBracketingValues: StorableArray<CameraBracketingValue> =
                            deviceStore.read(key: SettingKey.bracketingValueKey) {
                        photoPresets.load(data: photoPresetsData)
                        camera.update(photoCapabilities: photoCapabilities.storableValue)
                            .update(supportedPhotoBurstValues: Set(supportedBurstValues.storableValue))
                            .update(supportedPhotoBracketingValues: Set(supportedBracketingValues.storableValue))
                            .update(photoMode: photoPresets.mode).update(photoFormat: photoPresets.format)
                            .update(photoFileFormat: photoPresets.fileFormat)
                            .update(photoBurstValue: photoPresets.burstValue)
                            .update(photoBracketingValue: photoPresets.bracketingValue)
                            .update(gpslapseCaptureInterval: photoPresets.gpslapseCaptureIntervalValue)
                            .update(timelapseCaptureInterval: photoPresets.timelapseCaptureIntervalValue)
                    }
                case .maxZoomSpeed:
                    if let current: Double = presetStore.read(key: setting.key),
                        let range: (min: Double, max: Double) = deviceStore.readRange(key: setting.key) {
                        camera.update(
                            maxZoomSpeedLowerBound: range.min, maxZoomSpeed: current,
                            maxZoomSpeedUpperBound: range.max)
                    }
                case .zoomVelocityQualityDegradation:
                    if let allowed: Bool = presetStore.read(key: setting.key) {
                        camera.update(qualityDegradationAllowed: allowed)
                    }
                case .exposure:
                    if  let supportedExposureModes: StorableArray<CameraExposureMode> =
                        deviceStore.read(key: SettingKey.exposureModeValueKey),
                        let supportedManualShutterSpeeds: StorableArray<CameraShutterSpeed> =
                        deviceStore.read(key: SettingKey.exposureManualShutterSpeedValueKey),
                        let supportedManualIsoSensitivity: StorableArray<CameraIso> =
                        deviceStore.read(key: SettingKey.exposureManualIsoSensitivityValueKey),
                        let supportedMaximumIsoSensitivity: StorableArray<CameraIso> =
                        deviceStore.read(key: SettingKey.exposureMaximumIsoSensitivityValueKey),
                        let exposurePresetsData: ExposurePresets.Data = presetStore.read(key: setting.key) {
                        exposurePresets.load(data: exposurePresetsData)
                        camera.update(supportedExposureModes: Set(supportedExposureModes.storableValue))
                            .update(supportedManualShutterSpeeds: Set(supportedManualShutterSpeeds.storableValue))
                            .update(supportedManualIsoSensitivity: Set(supportedManualIsoSensitivity.storableValue))
                            .update(supportedMaximumIsoSensitivity: Set(supportedMaximumIsoSensitivity.storableValue))
                            .update(exposureMode: exposurePresets.mode)
                            .update(manualShutterSpeed: exposurePresets.manualShutterSpeed)
                            .update(manualIsoSensitivity: exposurePresets.manualIsoSensitivity)
                            .update(maximumIsoSensitivity: exposurePresets.maximumIsoSensitivity)
                            .update(autoExposureMeteringMode: exposurePresets.autoExposureMeteringMode)
                    }

                case .exposureCompensation:
                    if let supportedCompensation: StorableArray<CameraEvCompensation> =
                        deviceStore.read(key: SettingKey.exposureCompensationValuesKey),
                        let exposureCompensationPresetsData: ExposureCompensationPresets.Data = presetStore.read(
                            key: setting.key) {
                        exposureCompensationPresets.load(data: exposureCompensationPresetsData)
                        supportedValueExposureCompensation = Set(supportedCompensation.storableValue)

                        camera.update(supportedExposureCompensationValues: supportedValueExposureCompensation)
                            .update(exposureCompensationValue: exposureCompensationPresets.exposureCompensation)
                        computeEVCompensationAvailableValues()
                    }
                case .style:
                    if let supportedModes: StorableArray<CameraStyle> =
                        deviceStore.read(key: SettingKey.styleKey),
                        let stylePresetsData: StylePresets.Data = presetStore.read(key: setting.key) {
                        stylePresets.load(data: stylePresetsData)
                        camera.update(supportedStyles: Set(supportedModes.storableValue))
                            .update(activeStyle: stylePresets.activeStyle)

                    }
                case .saturation:
                    if let rangeSaturation: (min: Int, max: Int)
                        = deviceStore.readRange(key: setting.key),
                        let stylePresetsData: StylePresets.Data = presetStore.read(key: SettingKey.activeStyleKey) {
                        stylePresets.load(data: stylePresetsData)
                        camera.update(saturation: (min: rangeSaturation.min, value: stylePresets.saturation,
                                                   max: rangeSaturation.max))
                    }
                case .contrast:
                    if let rangeContrast: (min: Int, max: Int)
                        = deviceStore.readRange(key: setting.key),
                        let stylePresetsData: StylePresets.Data = presetStore.read(key: SettingKey.activeStyleKey) {
                        stylePresets.load(data: stylePresetsData)
                        camera.update(contrast: (min: rangeContrast.min, value: stylePresets.contrast,
                                                   max: rangeContrast.max))
                    }
                case .sharpness:
                    if let rangeSharpness: (min: Int, max: Int)
                        = deviceStore.readRange(key: setting.key),
                        let stylePresetsData: StylePresets.Data = presetStore.read(key: SettingKey.activeStyleKey) {
                        stylePresets.load(data: stylePresetsData)
                        camera.update(sharpness: (min: rangeSharpness.min, value: stylePresets.sharpness,
                                                   max: rangeSharpness.max))
                    }
                case .whiteBalance:
                    if let supportedModes: StorableArray<CameraWhiteBalanceMode> =
                            deviceStore.read(key: SettingKey.whiteBalanceModeValueKey),
                        let whiteBalancePresetsData: WhiteBalancePresets.Data = presetStore.read(key: setting.key),
                        let supportedCustomTemperature: StorableArray<CameraWhiteBalanceTemperature> =
                            deviceStore.read(key: SettingKey.whiteBalanceTemperatureValueKey) {
                                whiteBalancePresets.load(data: whiteBalancePresetsData)
                                camera.update(supportedWhiteBalanceModes: Set(supportedModes.storableValue))
                                    .update(supportedCustomWhiteBalanceTemperatures:
                                            Set(supportedCustomTemperature.storableValue))
                                    .update(whiteBalanceMode: whiteBalancePresets.mode)
                                    .update(customWhiteBalanceTemperature: whiteBalancePresets.customTemperature)
                    }
                case .model:
                    break
                }
            }
            camera.notifyUpdated()
        }
    }

    /// Called when the drone is connected, save all settings received during the connection and not yet in the preset
    /// store, and all received settings ranges
    public func storeNewPresets() {
        if let deviceStore = deviceStore, let presetStore = presetStore {
            for setting in droneSettings {
                switch setting {
                case .mode (let mode):
                    presetStore.writeIfNew(key: setting.key, value: mode)
                case .hdr(let hdr):
                    presetStore.writeIfNew(key: setting.key, value: hdr)
                case .recording(let mode, let resolution, let framerate, let hyperlapseValue):
                    if !presetStore.hasEntry(key: setting.key) {
                        recordingPresets.update(mode: mode, resolution: resolution, framerate: framerate,
                                                hyperlapseValue: hyperlapseValue, userSet: false)
                        presetStore.write(key: setting.key, value: recordingPresets.data)
                    }
                case .autoRecord(let autoRecord):
                    presetStore.writeIfNew(key: setting.key, value: autoRecord)
                case .photo(let mode, let format, let fileFormat, let burst, let bracketing, let captureInterval):
                    if !presetStore.hasEntry(key: setting.key) {
                        photoPresets.update(mode: mode, format: format, fileFormat: fileFormat,
                                            burstValue: burst, bracketingValue: bracketing,
                                            gpslapseCaptureIntervalValue: mode == .gpsLapse ? captureInterval : nil,
                                            timelapseCaptureIntervalValue: mode == .timeLapse ? captureInterval : nil,
                                            userSet: false)
                        presetStore.write(key: setting.key, value: photoPresets.data)
                    }
                case .maxZoomSpeed(let lowerBound, let value, let upperBound):
                    presetStore.writeIfNew(key: setting.key, value: value)
                    deviceStore.writeRange(key: setting.key, min: lowerBound, max: upperBound)
                case .zoomVelocityQualityDegradation(let allowed):
                    presetStore.writeIfNew(key: setting.key, value: allowed)
                case .whiteBalance(let mode, let customTemperature):
                    if !presetStore.hasEntry(key: setting.key) {
                        whiteBalancePresets.update(mode: mode, customTemperature: customTemperature)
                        presetStore.write(key: setting.key, value: whiteBalancePresets.data)
                    }
                case .exposure(let mode, let manualShutterSpeed, let manualIsoSensitivity,
                               let maximumIsoSensitivity, let autoExposureMeteringMode):
                    if !presetStore.hasEntry(key: setting.key) {
                        exposurePresets.update(mode: mode, manualShutterSpeed: manualShutterSpeed,
                                               manualIsoSensitivity: manualIsoSensitivity,
                                               maximumIsoSensitivity: maximumIsoSensitivity,
                                               autoExposureMeteringMode: autoExposureMeteringMode)
                        presetStore.write(key: setting.key, value: exposurePresets.data)
                    }
                case .exposureCompensation(let value):
                    if !presetStore.hasEntry(key: setting.key) {
                        exposureCompensationPresets.update(exposureCompensation: value)
                        presetStore.write(key: setting.key, value: value)
                    }
                case .style(let activeStyle, let saturation, let contrast, let sharpness):
                    stylePresets.update(activeStyle: activeStyle)
                    stylePresets.update(saturation: saturation, contrast: contrast, sharpness: sharpness)
                    presetStore.writeIfNew(key: setting.key, value: stylePresets.data)
                case .saturation(let min, let current, let max):
                    presetStore.writeIfNew(key: setting.key, value: current)
                    deviceStore.writeRange(key: setting.key, min: min, max: max)
                case .contrast(let min, let current, let max):
                    presetStore.writeIfNew(key: setting.key, value: current)
                    deviceStore.writeRange(key: setting.key, min: min, max: max)
                case .sharpness(let min, let current, let max):
                    presetStore.writeIfNew(key: setting.key, value: current)
                    deviceStore.writeRange(key: setting.key, min: min, max: max)
                case .model(let model):
                    presetStore.writeIfNew(key: setting.key, value: model)
                }
            }
            deviceStore.commit()
            presetStore.commit()
        }
    }

    /// Apply camera mode preset
    private func applyCameraModePreset() {
        for setting in droneSettings {
            switch setting {
            case .mode (let mode):
                if let preset: CameraMode = presetStore?.read(key: setting.key) {
                    if preset != mode {
                        _ = sendCameraModeCommand(preset)
                    }
                    camera.update(mode: preset)
                } else {
                    camera.update(mode: mode)
                }
            default:
                break
            }
        }
    }

    /// Apply photo preset
    private func applyPhotoPreset() {
        for setting in droneSettings {
            switch setting {
            case .photo(let mode, let format, let fileFormat, let burst, let bracketing, let captureInterval):
                if let photoPresetsData: PhotoPresets.Data = presetStore?.read(key: setting.key) {
                    photoPresets.load(data: photoPresetsData)
                    let presetMode = photoPresets.mode
                    let presetFormat = photoPresets.format
                    let presetFileFormat = photoPresets.fileFormat
                    let presetBurst = photoPresets.burstValue
                    let presetBracketing = photoPresets.bracketingValue
                    var presetCaptureIntervalClamped = 0.0
                    if presetMode == .gpsLapse {
                        presetCaptureIntervalClamped = photoPresets.gpslapseCaptureIntervalValue
                    } else if presetMode == .timeLapse {
                        presetCaptureIntervalClamped = photoPresets.timelapseCaptureIntervalValue
                    }

                    if presetMode != mode || presetFormat != format || presetFileFormat != fileFormat ||
                        (presetMode == .burst && presetBurst != burst) ||
                        (presetMode == .bracketing && presetBracketing != bracketing) ||
                        ((presetMode == .gpsLapse || presetMode == .timeLapse)
                            && (presetCaptureIntervalClamped != captureInterval)) {
                        _ = sendPhotoCommand(
                            photoMode: presetMode, photoFormat: presetFormat, photoFileFormat: presetFileFormat,
                            bustValue: presetBurst, bracketingValue: presetBracketing,
                            captureInterval: presetCaptureIntervalClamped)
                    }
                    camera.update(photoMode: presetMode).update(photoFormat: presetFormat)
                        .update(photoFileFormat: presetFileFormat)
                    if presetMode == .burst {
                        camera.update(photoBurstValue: presetBurst)
                    } else if presetMode == .bracketing {
                        camera.update(photoBracketingValue: presetBracketing)
                    } else if presetMode == .timeLapse {
                        camera.update(timelapseCaptureInterval: presetCaptureIntervalClamped)
                    } else if presetMode == .gpsLapse {
                        camera.update(gpslapseCaptureInterval: presetCaptureIntervalClamped)
                    }
                } else {
                    camera.update(photoMode: mode).update(photoFormat: format)
                        .update(photoFileFormat: fileFormat)
                    if mode == .burst {
                        camera.update(photoBurstValue: burst)
                    } else if mode == .bracketing {
                        camera.update(photoBracketingValue: bracketing)
                    } else if mode == .gpsLapse {
                        camera.update(gpslapseCaptureInterval: captureInterval)
                    } else if mode == .timeLapse {
                        camera.update(timelapseCaptureInterval: captureInterval)
                    }
                }
            default:
                break
            }
        }
    }

    /// Apply recording preset
    private func applyRecordingPreset() {
        for setting in droneSettings {
            switch setting {
            case .recording(let mode, let resolution, let framerate, let hyperlapseValue):
                if let recordingPresetsData: RecordingPresets.Data = presetStore?.read(key: setting.key) {
                    recordingPresets.load(data: recordingPresetsData)
                    let presetMode = recordingPresets.mode
                    let presetResolution = recordingPresets.resolution
                    let presetFramerate = recordingPresets.framerate
                    let presetHyperlapseValue = recordingPresets.hyperlapseValue
                    if presetMode != mode || presetResolution != resolution || presetFramerate != framerate ||
                        (presetMode == .hyperlapse && presetHyperlapseValue != hyperlapseValue) {
                        _ = sendRecordingCommand(
                            recordingMode: presetMode, resolution: presetResolution, framerate: presetFramerate,
                            hyperlapse: presetHyperlapseValue)
                    }
                    camera.update(recordingMode: presetMode).update(recordingResolution: presetResolution)
                        .update(recordingFramerate: presetFramerate)
                    if presetMode == .hyperlapse {
                        camera.update(recordingHyperlapseValue: presetHyperlapseValue)
                    }
                } else {
                    camera.update(recordingMode: mode).update(recordingResolution: resolution)
                        .update(recordingFramerate: framerate)
                    if mode == .hyperlapse {
                        camera.update(recordingHyperlapseValue: hyperlapseValue)
                    }
                }
            default:
                break
            }
        }
    }

    /// Apply other presets
    ///
    /// Iterate settings received during connection
    private func applyOtherPresets() {
        // iterate settings received during the connection
        for setting in droneSettings {
            switch setting {
            case .autoRecord (let autoRecord):
                if let preset: Bool = presetStore?.read(key: setting.key) {
                    if preset != autoRecord {
                        _ = sendAutoRecordCommand(preset)
                    }
                    camera.update(autoRecord: preset)
                } else {
                    camera.update(autoRecord: autoRecord)
                }
            case .maxZoomSpeed(let lowerBound, let value, let upperBound):
                if let preset: Double = presetStore?.read(key: setting.key) {
                    if preset != value {
                        _ = sendMaxZoomSpeedCommand(value: preset)
                    }
                    camera.update(
                        maxZoomSpeedLowerBound: lowerBound, maxZoomSpeed: preset,
                        maxZoomSpeedUpperBound: upperBound)
                } else {
                    camera.update(
                        maxZoomSpeedLowerBound: lowerBound, maxZoomSpeed: value,
                        maxZoomSpeedUpperBound: upperBound)
                }
            case .zoomVelocityQualityDegradation(let allowed):
                if let preset: Bool = presetStore?.read(key: setting.key) {
                    if preset != allowed {
                        _ = sendZoomVelocityQualityDegradationAllowanceCommand(value: preset)
                    }
                    camera.update(qualityDegradationAllowed: preset)
                } else {
                    camera.update(qualityDegradationAllowed: allowed)
                }
            case .whiteBalance(let mode, let customTemperature):
                if let whiteBalancePresetsData: WhiteBalancePresets.Data = presetStore?.read(key: setting.key) {
                    whiteBalancePresets.load(data: whiteBalancePresetsData)
                    let presetMode = whiteBalancePresets.mode
                    let presetCustomTemperature = whiteBalancePresets.customTemperature
                    if presetMode != mode
                        || (presetMode == .custom && presetCustomTemperature != customTemperature) {
                        _ = sendWhiteBalanceCommand(mode: presetMode, customTemperature: presetCustomTemperature)

                        camera.update(whiteBalanceMode: presetMode)
                        camera.update(customWhiteBalanceTemperature: presetCustomTemperature)
                    } else {
                        camera.update(whiteBalanceMode: mode)
                        camera.update(customWhiteBalanceTemperature: customTemperature)
                    }
                }
            case .exposure(let mode, let manualShutterSpeed, let manualIsoSensitivity,
                           let maximumIsoSensitivity, let autoExposureMeteringMode):
                if let exposurePresetsData: ExposurePresets.Data = presetStore?.read(key: setting.key) {
                    exposurePresets.load(data: exposurePresetsData)
                    let presetMode = exposurePresets.mode
                    let presetManualShutterSpeed = exposurePresets.manualShutterSpeed
                    let presetManualIsoSensitivity = exposurePresets.manualIsoSensitivity
                    let presetMaximumIsoSensitivity = exposurePresets.maximumIsoSensitivity
                    let presetAutoExposureMeteringMode = exposurePresets.autoExposureMeteringMode
                    if presetMode != mode
                        || ((presetMode == .manual || presetMode == .manualShutterSpeed)
                            && presetManualShutterSpeed != manualShutterSpeed)
                        || ((presetMode == .manual || presetMode == .manualIsoSensitivity)
                            && presetManualIsoSensitivity != manualIsoSensitivity)
                        || ((presetMode == .automatic || presetMode == .automaticPreferShutterSpeed
                            || presetMode == .automaticPreferIsoSensitivity)
                            && presetMaximumIsoSensitivity != maximumIsoSensitivity) {
                        _ = sendExposureCommand(exposureMode: presetMode, manualShutterSpeed: presetManualShutterSpeed,
                                                manualIsoSensitivity: presetManualIsoSensitivity,
                                                maximumIsoSensitivity: presetMaximumIsoSensitivity,
                                                autoExposureMeteringMode: presetAutoExposureMeteringMode)

                        camera.update(exposureMode: presetMode).update(manualShutterSpeed: presetManualShutterSpeed)
                            .update(manualIsoSensitivity: presetManualIsoSensitivity)
                            .update(maximumIsoSensitivity: presetMaximumIsoSensitivity)
                        .update(autoExposureMeteringMode: presetAutoExposureMeteringMode)
                    } else {
                        camera.update(exposureMode: mode).update(manualShutterSpeed: manualShutterSpeed)
                            .update(manualIsoSensitivity: manualIsoSensitivity)
                            .update(maximumIsoSensitivity: maximumIsoSensitivity)
                        .update(autoExposureMeteringMode: autoExposureMeteringMode)
                    }
                }
            case .exposureCompensation(let value):
                if let exposureCompensationPresetsData: ExposureCompensationPresets.Data = presetStore?.read(
                    key: setting.key) {
                    exposureCompensationPresets.load(data: exposureCompensationPresetsData)
                    let preset = exposureCompensationPresets.exposureCompensation
                    if preset != value {
                        _ = sendExposureCompensationCommand(value: preset)
                    }
                    camera.update(exposureCompensationValue: preset)
                } else {
                    camera.update(exposureCompensationValue: value)
                }
            case .style(let activeStyle, let saturation, let contrast, let sharpness):
                if let stylePresetsData: StylePresets.Data = presetStore?.read(key: setting.key) {
                    stylePresets.load(data: stylePresetsData)
                    let presetActiveStyle = stylePresets.activeStyle
                    if presetActiveStyle != activeStyle {
                        _ = sendActiveStyleCommand(style: presetActiveStyle)
                        camera.update(activeStyle: presetActiveStyle)
                    } else {
                        camera.update(activeStyle: activeStyle)
                    }

                    let presetSaturation = stylePresets.saturation
                    let presetContrast = stylePresets.contrast
                    let presetSharpness = stylePresets.sharpness

                    if presetSaturation != saturation || presetContrast != contrast || presetSharpness != sharpness {
                        _ = sendStyleParameterCommand(saturation: presetSaturation, contrast: presetContrast,
                                                      sharpness: presetSharpness)
                    }
                }
            case .saturation(let min, let current, let max):
                if let preset: Int = presetStore?.read(key: setting.key) {
                    camera.update(saturation: (min: min, value: preset, max: max))
                } else {
                    camera.update(saturation: (min: min, value: current, max: max))
                }
            case .contrast(let min, let current, let max):
                if let preset: Int = presetStore?.read(key: setting.key) {
                    camera.update(contrast: (min: min, value: preset, max: max))
                } else {
                    camera.update(contrast: (min: min, value: current, max: max))
                }
            case .sharpness(let min, let current, let max):
                if let preset: Int = presetStore?.read(key: setting.key) {
                    camera.update(sharpness: (min: min, value: preset, max: max))
                } else {
                    camera.update(sharpness: (min: min, value: current, max: max))
                }
            case .model:
                break
            default:
                break
            }
        }
    }

    /// Called when a command that notify a setting change has been received
    ///
    /// - Parameter setting: setting that changed
    func settingDidChange(_ setting: Setting) {
        droneSettings.update(with: setting)

        switch setting {
        case .mode(let mode):
            camera.update(mode: mode)
        case .hdr(let hdr):
            camera.update(hdrSetting: hdr)
        case .recording(let mode, let resolution, let framerate, let hyperlapseValue):
            camera.update(recordingMode: mode).update(recordingResolution: resolution)
                .update(recordingFramerate: framerate)
            if mode == .hyperlapse {
                camera.update(recordingHyperlapseValue: hyperlapseValue)
            }
            recordingPresets.update(mode: mode, resolution: resolution, framerate: framerate,
                                    hyperlapseValue: hyperlapseValue, userSet: false)
        case .autoRecord(let autoRecord):
            camera.update(autoRecord: autoRecord)
        case .photo(let mode, let format, let fileFormat, let burstValue, let bracketingValue, let captureInterval):
            camera.update(photoMode: mode).update(photoFormat: format).update(photoFileFormat: fileFormat)
            if mode == .burst {
                camera.update(photoBurstValue: burstValue)
            } else if mode == .bracketing {
                camera.update(photoBracketingValue: bracketingValue)
            } else if mode == .gpsLapse {
                camera.update(gpslapseCaptureInterval: captureInterval)
            } else if mode == .timeLapse {
                camera.update(timelapseCaptureInterval: captureInterval)
            }
            photoPresets.update(mode: mode, format: format, fileFormat: fileFormat, burstValue: burstValue,
                                bracketingValue: bracketingValue,
                                gpslapseCaptureIntervalValue: mode == .gpsLapse ? captureInterval : nil,
                                timelapseCaptureIntervalValue: mode == .timeLapse ? captureInterval : nil,
                                userSet: false)
        case .maxZoomSpeed(let lowerBound, let value, let upperBound):
            camera.update(
                maxZoomSpeedLowerBound: lowerBound, maxZoomSpeed: value,
                maxZoomSpeedUpperBound: upperBound)
            deviceStore?.writeRange(key: setting.key, min: lowerBound, max: upperBound)
        case .zoomVelocityQualityDegradation(let allowed):
            camera.update(qualityDegradationAllowed: allowed)
        case .whiteBalance(let mode, let customTemperature):
            camera.update(whiteBalanceMode: mode).update(customWhiteBalanceTemperature: customTemperature)
            whiteBalancePresets.update(mode: mode, customTemperature: customTemperature)
        case .exposure(let mode, let manualShutterSpeed, let manualIsoSensitivity,
                       let maximumIsoSensitivity, let autoExposureMeteringMode):
            camera.update(exposureMode: mode).update(manualShutterSpeed: manualShutterSpeed)
                .update(manualIsoSensitivity: manualIsoSensitivity)
                .update(maximumIsoSensitivity: maximumIsoSensitivity)
                exposurePresets.update(mode: mode, manualShutterSpeed: manualShutterSpeed,
                                   manualIsoSensitivity: manualIsoSensitivity,
                                   maximumIsoSensitivity: maximumIsoSensitivity,
                                   autoExposureMeteringMode: autoExposureMeteringMode)
        case .exposureCompensation(let exposureCompensation):
            camera.update(exposureCompensationValue: exposureCompensation)
            exposureCompensationPresets.update(exposureCompensation: exposureCompensation)
        case .style(let activeStyle, let saturation, let contrast, let sharpness):
            camera.update(activeStyle: activeStyle)
            stylePresets.update(activeStyle: activeStyle)
            stylePresets.update(saturation: saturation, contrast: contrast, sharpness: sharpness)
        case .saturation(let min, let current, let max):
            camera.update(saturation: (min: min, value: current, max: max))
            deviceStore?.writeRange(key: setting.key, min: min, max: max)
        case .contrast(let min, let current, let max):
            camera.update(contrast: (min: min, value: current, max: max))
            deviceStore?.writeRange(key: setting.key, min: min, max: max)
        case .sharpness(let min, let current, let max):
            camera.update(sharpness: (min: min, value: current, max: max))
            deviceStore?.writeRange(key: setting.key, min: min, max: max)
        case .model:
            break
        }
        deviceStore?.commit()
        camera.notifyUpdated()
    }

    /// Process stored capabilities changes
    ///
    /// Update camera and device store. Note caller must call `camera.notifyUpdated()` to notify change
    ///
    /// - Parameter capabilities: changed capabilities
    func capabilitiesDidChange(_ capabilities: Capabilities) {
        switch capabilities {
        case .mode(let modes):
            deviceStore?.write(key: capabilities.key, value: StorableArray(Array(modes)))
            camera.update(supportedModes: modes)
        case .recording(let values):
            deviceStore?.write(key: capabilities.key, value: StorableArray(values))
            camera.update(recordingCapabilities: values)
        case .hyperlapseValue(let hyperlapseValues):
            deviceStore?.write(key: capabilities.key, value: StorableArray(Array(hyperlapseValues)))
            camera.update(supportedRecordingHyperlapseValues: hyperlapseValues)
        case .photo(let values):
            deviceStore?.write(key: capabilities.key, value: StorableArray(values))
            camera.update(photoCapabilities: values)
        case .burstValue(let values):
            deviceStore?.write(key: capabilities.key, value: StorableArray(Array(values)))
            camera.update(supportedPhotoBurstValues: values)
        case .bracketingValue(let values):
            deviceStore?.write(key: capabilities.key, value: StorableArray(Array(values)))
            camera.update(supportedPhotoBracketingValues: values)
        case .whiteBalanceMode(let values):
            deviceStore?.write(key: capabilities.key, value: StorableArray(Array(values)))
            camera.update(supportedWhiteBalanceModes: values)
        case .whiteBalanceTemperature(let values):
            deviceStore?.write(key: capabilities.key, value: StorableArray(Array(values)))
            camera.update(supportedCustomWhiteBalanceTemperatures: values)
        case .exposureCompensationValues(let values):
            deviceStore?.write(key: capabilities.key, value: StorableArray(Array(values)))
            computeEVCompensationAvailableValues()
        case .exposureMode(let values):
            deviceStore?.write(key: capabilities.key, value: StorableArray(Array(values)))
            camera.update(supportedExposureModes: values)
        case .exposureShutterSpeed(let values):
            deviceStore?.write(key: capabilities.key, value: StorableArray(Array(values)))
            camera.update(supportedManualShutterSpeeds: values)
        case .exposureManualIsoSensitivity(let values):
            deviceStore?.write(key: capabilities.key, value: StorableArray(Array(values)))
            camera.update(supportedManualIsoSensitivity: values)
        case .exposureMaximumIsoSensitivity(let values):
            deviceStore?.write(key: capabilities.key, value: StorableArray(Array(values)))
            camera.update(supportedMaximumIsoSensitivity: values)
        case .style(let values):
            deviceStore?.write(key: capabilities.key, value: StorableArray(Array(values)))
            camera.update(supportedStyles: values)
        case .timelapseIntervalMin(let min):
            deviceStore?.write(key: capabilities.key, value: min)
            camera.update(timelapseIntervalMin: min)
        case .gpslapseIntervalMin(let min):
            deviceStore?.write(key: capabilities.key, value: min)
            camera.update(gpslapseIntervalMin: min)
        }
        deviceStore?.commit()
    }

    func updateAvailableValues(supportedValue: Set<CameraEvCompensation>) {
        supportedValueExposureCompensation = supportedValue
        capabilitiesDidChange(.exposureCompensationValues(supportedValueExposureCompensation))
    }
}

// MARK: - Local settings

/// Store local recording settings
private struct RecordingPresets {

    /// Settings data, storable
    struct Data: StorableType {
        /// Current recording mode
        var mode = CameraRecordingMode.standard
        /// Resolution for each mode
        var resolutionsByMode = [CameraRecordingMode: CameraRecordingResolution]()
        /// Framerate for each mode
        var frameratesByMode = [CameraRecordingMode: CameraRecordingFramerate]()
        // Current hyperlapse value
        var hyperlapseValue = CameraHyperlapseValue.ratio15

        /// Store keys
        private enum Key {
            static let mode = "mode"
            static let resolutions = "resolutions"
            static let framerates = "framerates"
            static let hyperlapse = "hyperlapse"
        }

        /// Constructor with default data
        init() {
        }

        /// Constructor from store data
        ///
        /// - Parameter content: store data
        init?(from content: AnyObject?) {
            if let content = StorableDict<String, AnyStorable>(from: content),
                let mode = CameraRecordingMode(content[Key.mode]),
                let resolutionsByMode = StorableDict<CameraRecordingMode, CameraRecordingResolution>(
                    content[Key.resolutions]),
                let frameratesByMode = StorableDict<CameraRecordingMode, CameraRecordingFramerate>(
                    content[Key.framerates]),
                let hyperlapseValue = CameraHyperlapseValue(content[Key.hyperlapse]) {
                self.mode = mode
                self.resolutionsByMode = resolutionsByMode.storableValue
                self.frameratesByMode = frameratesByMode.storableValue
                self.hyperlapseValue = hyperlapseValue
            } else {
                return nil
            }
        }

        /// Convert data to storable
        ///
        /// - Returns: Storable containing data
        func asStorable() -> StorableProtocol {
            return StorableDict<String, AnyStorable>([
                Key.mode: AnyStorable(mode),
                Key.resolutions: AnyStorable(resolutionsByMode),
                Key.framerates: AnyStorable(frameratesByMode),
                Key.hyperlapse: AnyStorable(hyperlapseValue)])
        }
    }

    /// Settings data
    private(set) var data: Data
    /// Camera recording settings, used to get capabilities
    private let recordingSetting: CameraRecordingSettings

    /// Constructor
    ///
    /// - Parameter recordingSetting: camera recording settings
    init(recordingSetting: CameraRecordingSettings) {
        self.data = Data()
        self.recordingSetting = recordingSetting
    }

    /// Recoding mode
    var mode: CameraRecordingMode {
        return data.mode
    }

    /// Resolution for a specific mode
    ///
    /// - Parameter mode: mode to get resolution from
    /// - Returns: resolution for this mode
    func resolution(forMode mode: CameraRecordingMode) -> CameraRecordingResolution {
        if let resolution = data.resolutionsByMode[mode] {
            if recordingSetting.supportedResolutions(forMode: mode).contains(resolution) {
                return resolution
            }
        }
        // Return the first supported value
        if let resolution = recordingSetting.supportedResolutions(forMode: mode).sorted().first {
            return resolution
        }
        // no supported value, return a hard-coded value
        return .res1080p
    }

    /// Resolution for the current mode
    var resolution: CameraRecordingResolution {
        return resolution(forMode: mode)
    }

    /// Framerate for a specific mode and resolution
    ///
    /// - Parameters:
    ///   - mode: mode: mode to get framerate from
    ///   - resolution: resolution to get framerate from
    /// - Returns: framerate for the mode and resolution
    func framerate(forMode mode: CameraRecordingMode, resolution: CameraRecordingResolution)
        -> CameraRecordingFramerate {
        if let framerate = data.frameratesByMode[mode] {
            if recordingSetting.supportedFramerates(forMode: mode, resolution: resolution).contains(framerate) {
                return framerate
            }
        }
        // Return the highest supported value
        if let framerate = recordingSetting.supportedFramerates(forMode: mode, resolution: resolution).sorted().last {
            return framerate
        }
        // no supported value, return a hard-coded value
        return .fps30
    }

    /// Framerate for the current mode and resolution
    var framerate: CameraRecordingFramerate {
        return framerate(forMode: mode, resolution: resolution)
    }

    /// Hyperlapse value
    var hyperlapseValue: CameraHyperlapseValue {
        return data.hyperlapseValue
    }

    /// Initialise from data
    ///
    /// - Parameter data: data to load
    mutating func load(data: Data) {
        self.data = data
    }

    /// Update
    ///
    /// - Parameters:
    ///   - mode: new mode
    ///   - resolution: new resolution for the mode
    ///   - framerate: new framerate for the mode and resolution
    ///   - hyperlapseValue: new hyperlapse value
    ///   - userSet: whether or not these values are set by the user (i.e. by gsdk)
    mutating func update(mode: CameraRecordingMode, resolution: CameraRecordingResolution,
                         framerate: CameraRecordingFramerate, hyperlapseValue: CameraHyperlapseValue, userSet: Bool) {
        data.mode = mode
        data.resolutionsByMode[mode] = resolution
        data.frameratesByMode[mode] = framerate
        if userSet || mode == .hyperlapse {
            data.hyperlapseValue = hyperlapseValue
        }
    }
}

/// Store local photo settings
private struct PhotoPresets {

    /// Settings data, storable
    struct Data: StorableType {
        /// Current photo mode
        var mode = CameraPhotoMode.single
        /// Photo format for each mode
        var formatByMode = [CameraPhotoMode: CameraPhotoFormat]()
        /// Photo Ffle format for each mode
        var fileFormatByMode = [CameraPhotoMode: CameraPhotoFileFormat]()
        // Current burst value
        var burstValue = CameraBurstValue.burst14Over4s
        // Current bracketing value
        var bracketingValue = CameraBracketingValue.preset1ev
        // Current timelapse capture interval value
        var timelapseCaptureIntervalValue = 0.0
        // Current gpslapse capture interval value
        var gpslapseCaptureIntervalValue = 0.0

        /// Store keys
        private enum Key {
            static let mode = "mode"
            static let formats = "formats"
            static let fileFormats = "fileFormats"
            static let burst = "burst"
            static let bracketing = "bracketing"
            static let timelapseCaptureInterval = "timelapseCaptureInterval"
            static let gpslapseCaptureInterval = "gpslapseCaptureInterval"
        }

        /// Constructor with default data
        init() {
        }

        /// Constructor from store data
        ///
        /// - Parameter content: store data
        init?(from content: AnyObject?) {
            if let content = StorableDict<String, AnyStorable>(from: content),
                let mode = CameraPhotoMode(content[Key.mode]),
                let formatByMode = StorableDict<CameraPhotoMode, CameraPhotoFormat>(content[Key.formats]),
                let fileFormatByMode = StorableDict<CameraPhotoMode, CameraPhotoFileFormat>(content[Key.fileFormats]),
                let burstValue = CameraBurstValue(content[Key.burst]),
                let bracketingValue = CameraBracketingValue(content[Key.bracketing]),
                let timelapseCaptureIntervalValue = Double(content[Key.timelapseCaptureInterval]),
                let gpslapseCaptureIntervalValue = Double(content[Key.gpslapseCaptureInterval]) {
                self.mode = mode
                self.formatByMode = formatByMode.storableValue
                self.fileFormatByMode = fileFormatByMode.storableValue
                self.burstValue = burstValue
                self.bracketingValue = bracketingValue
                self.timelapseCaptureIntervalValue = timelapseCaptureIntervalValue
                self.gpslapseCaptureIntervalValue = gpslapseCaptureIntervalValue
            } else {
                return nil
            }
        }

        /// Convert data to storable
        ///
        /// - Returns: Storable containing data
        func asStorable() -> StorableProtocol {
            return StorableDict<String, AnyStorable>([
                Key.mode: AnyStorable(mode),
                Key.formats: AnyStorable(formatByMode),
                Key.fileFormats: AnyStorable(fileFormatByMode),
                Key.burst: AnyStorable(burstValue),
                Key.bracketing: AnyStorable(bracketingValue),
                Key.timelapseCaptureInterval: AnyStorable(timelapseCaptureIntervalValue),
                Key.gpslapseCaptureInterval: AnyStorable(gpslapseCaptureIntervalValue)])
        }
    }

    /// Settings data
    private(set) var data: Data
    /// Camera photo settings, used to get capabilities
    private let photoSettings: CameraPhotoSettings

    /// Constructor
    ///
    /// - Parameter photoSettings: camera photo settings
    init(photoSettings: CameraPhotoSettings) {
        self.data = Data()
        self.photoSettings = photoSettings
    }

    /// Photo mode
    var mode: CameraPhotoMode {
        return data.mode
    }

    /// Photo format for a specific mode
    ///
    /// - Parameter mode: mode to get format from
    /// - Returns: format for this mode
    func format(forMode mode: CameraPhotoMode) -> CameraPhotoFormat {
        if let format = data.formatByMode[mode] {
            if photoSettings.supportedFormats(forMode: mode).contains(format) {
                return format
            }
        }
        // Return the first supported value
        if let format = photoSettings.supportedFormats(forMode: mode).sorted().first {
            return format
        }
        // no supported value, return a hard-coded value
        return .rectilinear
    }

    /// Format for current mode
    var format: CameraPhotoFormat {
        return format(forMode: data.mode)
    }

    /// File format for a specific mode and format
    ///
    /// - Parameters:
    ///   - mode: mode: mode to get file format from
    ///   - format: format to get file format from
    /// - Returns: file format for the mode and format
    func fileFormat(forMode mode: CameraPhotoMode, format: CameraPhotoFormat) -> CameraPhotoFileFormat {
        if let fileFormat = data.fileFormatByMode[mode] {
            if photoSettings.supportedFileFormats(forMode: mode, format: format).contains(fileFormat) {
                return fileFormat
            }
        }

        // Return the first supported value
        if let fileFormat = photoSettings.supportedFileFormats(forMode: mode, format: format).sorted().first {
            return fileFormat
        }
        // no supported value, return a hard-coded value
        return .jpeg
    }

    /// File format for the current mode and format
    var fileFormat: CameraPhotoFileFormat {
        return fileFormat(forMode: data.mode, format: format)
    }

    /// Burst value
    var burstValue: CameraBurstValue {
        return data.burstValue
    }

    /// Bracketing value
    var bracketingValue: CameraBracketingValue {
        return data.bracketingValue
    }

    /// Timelapse capture interval value
    var timelapseCaptureIntervalValue: Double {
        return data.timelapseCaptureIntervalValue
    }

    /// Gpslapse capture interval value
    var gpslapseCaptureIntervalValue: Double {
        return data.gpslapseCaptureIntervalValue
    }

    /// Initialise from data
    ///
    /// - Parameter data: data to load
    mutating func load(data: Data) {
        self.data = data
    }

    /// Update
    ///
    /// - Parameters:
    ///   - mode: new mode
    ///   - format: new format
    ///   - fileFormat: new file format
    ///   - burstValue: new burst value
    ///   - bracketingValue: new bracketing value
    ///   - gpslapseCaptureIntervalValue: gps-lapse interval
    ///   - timelapseCaptureIntervalValue: time-lapse interval
    ///   - userSet: whether or not these values are set by the user (i.e. by gsdk)
    mutating func update(mode: CameraPhotoMode, format: CameraPhotoFormat, fileFormat: CameraPhotoFileFormat,
                         burstValue: CameraBurstValue, bracketingValue: CameraBracketingValue,
                         gpslapseCaptureIntervalValue: Double?, timelapseCaptureIntervalValue: Double?, userSet: Bool) {
        data.mode = mode
        data.formatByMode[mode] = format
        data.fileFormatByMode[mode] = fileFormat
        if let gpslapseCaptureIntervalValue = gpslapseCaptureIntervalValue, userSet || mode == .gpsLapse {
            data.gpslapseCaptureIntervalValue = gpslapseCaptureIntervalValue
        }
        if let timelapseCaptureIntervalValue = timelapseCaptureIntervalValue, userSet || mode == .timeLapse {
            data.timelapseCaptureIntervalValue = timelapseCaptureIntervalValue
        }
        if userSet || mode == .burst {
            data.burstValue = burstValue
        }
        if userSet || mode == .bracketing {
            data.bracketingValue = bracketingValue
        }
    }
}

/// Store exposure settings
private struct ExposurePresets {

    /// Settings data, storable
    struct Data: StorableType {
        /// Current mode
        var mode = CameraExposureMode.automatic
        /// Current manual shutter speed
        var manualShutterSpeed = CameraShutterSpeed.one
        /// Current manual iso sensitivity
        var manualIsoSensitivity = CameraIso.iso100
        /// Current maximum iso sensitivity
        var maximumIsoSensitivity = CameraIso.iso3200
        /// Standard auto exposure metering mode
        var autoExposureMeteringMode = CameraAutoExposureMeteringMode.standard

        /// Store keys
        private enum Key {
            static let mode = "mode"
            static let manualShutterSpeed = "manualShutterSpeed"
            static let manualIsoSensitivity = "manualIsoSensitivity"
            static let maximumIsoSensitivity = "maximumIsoSensitivity"
            static let autoExposureMeteringMode = "autoExposureMeteringMode"

        }

        /// Constructor with default data
        init() {
        }

        /// Constructor from store data
        ///
        /// - Parameter content: store data
        init?(from content: AnyObject?) {

            if let content = StorableDict<String, AnyStorable>(from: content),
                let mode = CameraExposureMode(content[Key.mode]),
                let manualShutterSpeed = CameraShutterSpeed(content[Key.manualShutterSpeed]),
                let manualIsoSensitivity = CameraIso(content[Key.manualIsoSensitivity]),
                let maximumIsoSensitivity = CameraIso(content[Key.maximumIsoSensitivity]),
                let autoExposureMeteringMode = CameraAutoExposureMeteringMode(
                    content[Key.autoExposureMeteringMode]) {
                self.mode = mode
                self.manualShutterSpeed = manualShutterSpeed.storableValue
                self.manualIsoSensitivity = manualIsoSensitivity.storableValue
                self.maximumIsoSensitivity = maximumIsoSensitivity.storableValue
                self.autoExposureMeteringMode = autoExposureMeteringMode.storableValue
            } else {
                return nil
            }
        }

        /// Convert data to storable
        ///
        /// - Returns: Storable containing data
        func asStorable() -> StorableProtocol {
            return StorableDict<String, AnyStorable>([
                Key.mode: AnyStorable(mode),
                Key.manualShutterSpeed: AnyStorable(manualShutterSpeed),
                Key.manualIsoSensitivity: AnyStorable(manualIsoSensitivity),
                Key.maximumIsoSensitivity: AnyStorable(maximumIsoSensitivity),
                Key.autoExposureMeteringMode: AnyStorable(autoExposureMeteringMode)
            ])
        }
    }

    /// Settings data
    private(set) var data: Data
    /// Exposure settings, used to get capabilities
    private let exposureSettings: CameraExposureSettings

    /// Constructor
    ///
    /// - Parameter exposureSettings: camera exposure settings
    init(exposureSettings: CameraExposureSettings) {
        self.data = Data()
        self.exposureSettings = exposureSettings
    }

    /// Exposure mode
    var mode: CameraExposureMode {
        return data.mode
    }

    /// Exposure manual shutter speed
    var manualShutterSpeed: CameraShutterSpeed {
        return data.manualShutterSpeed
    }

    /// Exposure manual iso sensitivity
    var manualIsoSensitivity: CameraIso {
        return data.manualIsoSensitivity
    }

    /// Auto exposure metering mode
    var autoExposureMeteringMode: CameraAutoExposureMeteringMode {
        return data.autoExposureMeteringMode
    }

    /// Exposure maximum iso sensitivity
    var maximumIsoSensitivity: CameraIso {
        return data.maximumIsoSensitivity
    }

    /// Initialise from data
    ///
    /// - Parameter data: data to load
    mutating func load(data: Data) {
        self.data = data
    }

    /// Update
    ///
    /// - Parameters:
    ///   - mode: new mode
    ///   - manualShutterSpeed: new manual shutter speed
    ///   - manualIsoSensitivity: new manual iso sensitivity
    ///   - maximumIsoSensitivity: new maximum iso sensitivity
    ///   - autoExposureMeteringMode: new auto exposure metering mode
    mutating func update(mode: CameraExposureMode, manualShutterSpeed: CameraShutterSpeed,
                         manualIsoSensitivity: CameraIso, maximumIsoSensitivity: CameraIso,
                         autoExposureMeteringMode: CameraAutoExposureMeteringMode) {
        data.mode = mode
        data.manualShutterSpeed = manualShutterSpeed
        data.manualIsoSensitivity = manualIsoSensitivity
        data.maximumIsoSensitivity = maximumIsoSensitivity
        data.autoExposureMeteringMode = autoExposureMeteringMode
    }
}

/// Store exposure balance settings
private struct StylePresets {

    /// Settings data, storable
    struct Data: StorableType {
        /// Current active style
        var activeStyle = CameraStyle.standard
        /// Current saturation
        var saturation = 0
        /// Current contrast
        var contrast = 0
        /// Current sharpness
        var sharpness = 0
        /// Store keys
        private enum Key {
            static let activeStyle = "activeStyle"
            static let saturation = "saturation"
            static let contrast = "contrast"
            static let sharpness = "sharpness"
        }

        /// Constructor with default data
        init() {
        }

        /// Constructor from store data
        ///
        /// - Parameter content: store data
        init?(from content: AnyObject?) {
            if let content = StorableDict<String, AnyStorable>(from: content),
                let activeStyle = CameraStyle(content[Key.activeStyle]),
                let saturation = Int(content[Key.saturation]),
                let contrast = Int(content[Key.contrast]),
                let sharpness = Int(content[Key.sharpness]) {
                self.activeStyle = activeStyle
                self.saturation = saturation
                self.contrast = contrast
                self.sharpness = sharpness
            } else {
                return nil
            }
        }

        /// Convert data to storable
        ///
        /// - Returns: Storable containing data
        func asStorable() -> StorableProtocol {
            return StorableDict<String, AnyStorable>([
                Key.activeStyle: AnyStorable(activeStyle),
                Key.saturation: AnyStorable(saturation),
                Key.contrast: AnyStorable(contrast),
                Key.sharpness: AnyStorable(sharpness)])
        }
    }

    /// Settings data
    private(set) var data: Data
    /// Style settings, used to get capabilities
    private let styleSettings: CameraStyleSettings

    /// Constructor
    ///
    /// - Parameter styleSettings: style settings
    init(styleSettings: CameraStyleSettings) {
        self.data = Data()
        self.styleSettings = styleSettings
    }

    /// Active style
    var activeStyle: CameraStyle {
        return data.activeStyle
    }

    /// Saturation
    var saturation: Int {
        return data.saturation
    }

    /// Contrast
    var contrast: Int {
        return data.contrast
    }

    /// Sharpness
    var sharpness: Int {
        return data.sharpness
    }

    /// Initialise from data
    ///
    /// - Parameter data: data to load
    mutating func load(data: Data) {
        self.data = data
    }

    /// Update
    ///
    /// - Parameters:
    ///   - saturation: new saturation
    ///   - contrast: new contrast
    ///   - sharpness: new sharpness
    mutating func update(saturation: Int, contrast: Int, sharpness: Int) {
        data.saturation = saturation
        data.contrast = contrast
        data.sharpness = sharpness
    }

    /// Update
    ///
    /// - Parameter: activeStyle: new activeStyle
    mutating func update(activeStyle: CameraStyle) {
        data.activeStyle = activeStyle
    }
}

/// Store local white balance settings
private struct WhiteBalancePresets {

    /// Settings data, storable
    struct Data: StorableType {
        /// Current recording mode
        var mode = CameraWhiteBalanceMode.automatic
        /// Current custom temperature
        var customTemperature = CameraWhiteBalanceTemperature.k1500

        /// Store keys
        private enum Key {
            static let mode = "mode"
            static let customTemperature = "customTemperature"
        }

        /// Constructor with default data
        init() {
        }

        /// Constructor from store data
        ///
        /// - Parameter content: store data
        init?(from content: AnyObject?) {
            if let content = StorableDict<String, AnyStorable>(from: content),
                let mode = CameraWhiteBalanceMode(content[Key.mode]),
                let customTemperature = CameraWhiteBalanceTemperature(content[Key.customTemperature]) {
                self.mode = mode.storableValue
                self.customTemperature = customTemperature.storableValue
            } else {
                return nil
            }
        }

        /// Convert data to storable
        ///
        /// - Returns: Storable containing data
        func asStorable() -> StorableProtocol {
            return StorableDict<String, AnyStorable>([
                Key.mode: AnyStorable(mode),
                Key.customTemperature: AnyStorable(customTemperature)])
        }
    }

    /// Settings data
    private(set) var data: Data
    /// White balance settings, used to get capabilities
    private let whiteBalanceSetting: CameraWhiteBalanceSettings

    /// Constructor
    ///
    /// - Parameter whiteBalanceSetting: camera recording settings
    init(whiteBalanceSetting: CameraWhiteBalanceSettings) {
        self.data = Data()
        self.whiteBalanceSetting = whiteBalanceSetting
    }

    /// White balance mode
    var mode: CameraWhiteBalanceMode {
        return data.mode
    }

    /// White balance temperature
    var customTemperature: CameraWhiteBalanceTemperature {
        return data.customTemperature
    }

    /// Initialise from data
    ///
    /// - Parameter data: data to load
    mutating func load(data: Data) {
        self.data = data
    }

    /// Update
    ///
    /// - Parameters:
    ///   - mode: new mode
    ///   - customTemperature: custom temperature
    mutating func update(mode: CameraWhiteBalanceMode, customTemperature: CameraWhiteBalanceTemperature) {
        data.mode = mode
        data.customTemperature = customTemperature
    }
}

/// Store local exposure compensation settings
private struct ExposureCompensationPresets {

    /// Settings data, storable
    struct Data: StorableType {
        /// Current exposure compensation
        var exposureCompensation = CameraEvCompensation.ev0_00

        /// Store keys
        private enum Key {
            static let exposureCompensation = "exposureCompensation"
        }

        /// Constructor with default data
        init() {
        }

        /// Constructor from store data
        ///
        /// - Parameter content: store data
        init?(from content: AnyObject?) {
            if let content = StorableDict<String, AnyStorable>(from: content),
                let exposureCompensation = CameraEvCompensation(content[Key.exposureCompensation]) {
                self.exposureCompensation = exposureCompensation.storableValue
            } else {
                return nil
            }
        }

        /// Convert data to storable
        ///
        /// - Returns: Storable containing data
        func asStorable() -> StorableProtocol {
            return StorableDict<String, AnyStorable>([
                Key.exposureCompensation: AnyStorable(exposureCompensation)])
        }
    }

    /// Settings data
    private(set) var data: Data
    /// Exposure compensation settings, used to get capabilities
    private let exposureCompensationSetting: CameraExposureCompensationSetting

    /// Constructor
    ///
    /// - Parameter exposureCompensationSetting: exposure compensation settings
    init(exposureCompensationSetting: CameraExposureCompensationSetting) {
        self.data = Data()
        self.exposureCompensationSetting = exposureCompensationSetting
    }

    /// Exposure compensation
    var exposureCompensation: CameraEvCompensation {
        return data.exposureCompensation
    }

    /// Initialise from data
    ///
    /// - Parameter data: data to load
    mutating func load(data: Data) {
        self.data = data
    }

    /// Update
    ///
    /// - Parameter exposureCompensation: exposure compensation
    mutating func update(exposureCompensation: CameraEvCompensation) {
        data.exposureCompensation = exposureCompensation
    }
}

// MARK: - Storable extensions

extension CameraMode: StorableEnum {
    static var storableMapper = Mapper<CameraMode, String>([
        .recording: "recording",
        .photo: "photo"])
}

extension Model: StorableEnum {
    static var storableMapper = Mapper<Model, String>([
        .main: "main",
        .thermal: "thermal",
        .blendedThermal: "blendedThermal"])
}

extension CameraExposureMode: StorableEnum {
    static var storableMapper = Mapper<CameraExposureMode, String>([
        .automatic: "automatic",
        .automaticPreferIsoSensitivity: "automaticPreferIsoSensitivity",
        .automaticPreferShutterSpeed: "automaticPreferShutterSpeed",
        .manualIsoSensitivity: "manualIsoSensitivity",
        .manualShutterSpeed: "manualShutterSpeed",
        .manual: "manual"
        ])
}

extension CameraAutoExposureMeteringMode: StorableEnum {
    static var storableMapper = Mapper<CameraAutoExposureMeteringMode, String>([
        .standard: "standard",
        .centerTop: "centerTop"
        ])
}

extension CameraStyle: StorableEnum {
    static var storableMapper = Mapper<CameraStyle, String>([
        .standard: "standard",
        .plog: "plog",
        .intense: "intense",
        .pastel: "pastel"
        ])
}

extension CameraShutterSpeed: StorableEnum {
    static var storableMapper = Mapper<CameraShutterSpeed, String>([
        .oneOver10000: "1/10000s",
        .oneOver8000: "1/8000s",
        .oneOver6400: "1/6400s",
        .oneOver5000: "1/5000s",
        .oneOver4000: "1/4000s",
        .oneOver3200: "1/3200s",
        .oneOver2500: "1/2500s",
        .oneOver2000: "1/2000s",
        .oneOver1600: "1/1600s",
        .oneOver1250: "1/1250s",
        .oneOver1000: "1/1000s",
        .oneOver800: "1/800s",
        .oneOver640: "1/640s",
        .oneOver500: "1/500s",
        .oneOver400: "1/400s",
        .oneOver320: "1/320s",
        .oneOver240: "1/240s",
        .oneOver200: "1/200s",
        .oneOver160: "1/160s",
        .oneOver120: "1/120s",
        .oneOver100: "1/100s",
        .oneOver80: "1/80s",
        .oneOver60: "1/60s",
        .oneOver50: "1/50s",
        .oneOver40: "1/40s",
        .oneOver30: "1/30s",
        .oneOver25: "1/25s",
        .oneOver15: "1/15s",
        .oneOver10: "1/10s",
        .oneOver8: "1/8s",
        .oneOver6: "1/6s",
        .oneOver4: "1/4s",
        .oneOver3: "1/3s",
        .oneOver2: "1/2s",
        .oneOver1_5: "1/1.5s",
        .one: "1s"
        ])
}
extension CameraIso: StorableEnum {
    static var storableMapper = Mapper<CameraIso, String>([
        .iso50: "iso 50",
        .iso64: "iso 64",
        .iso80: "iso 80",
        .iso100: "iso 100",
        .iso125: "iso 125",
        .iso160: "iso 160",
        .iso200: "iso 200",
        .iso250: "iso 250",
        .iso320: "iso 320",
        .iso400: "iso 400",
        .iso500: "iso 500",
        .iso640: "iso 640",
        .iso800: "iso 800",
        .iso1200: "iso 1200",
        .iso1600: "iso 1600",
        .iso2500: "iso 2500",
        .iso3200: "iso 3200"
        ])
}

extension CameraWhiteBalanceMode: StorableEnum {
    static var storableMapper = Mapper<CameraWhiteBalanceMode, String>([
        .automatic: "automatic",
        .candle: "candle",
        .sunset: "sunset",
        .incandescent: "incandescent",
        .warmWhiteFluorescent: "warmWhiteFluorescent",
        .halogen: "halogen",
        .fluorescent: "fluorescent",
        .coolWhiteFluorescent: "coolWhiteFluorescent",
        .flash: "flash",
        .daylight: "daylight",
        .sunny: "sunny",
        .cloudy: "cloudy",
        .snow: "snow",
        .hazy: "hazy",
        .shaded: "shaded",
        .greenFoliage: "greenFoliage",
        .blueSky: "blueSky",
        .custom: "custom"])
}

extension CameraWhiteBalanceTemperature: StorableEnum {
    static var storableMapper = Mapper<CameraWhiteBalanceTemperature, String>([
        .k1500: "k1500",
        .k1750: "k1750",
        .k2000: "k2000",
        .k2250: "k2250",
        .k2500: "k2500",
        .k2750: "k2750",
        .k3000: "k3000",
        .k3250: "k3250",
        .k3500: "k3500",
        .k3750: "k3750",
        .k4000: "k4000",
        .k4250: "k4250",
        .k4500: "k4500",
        .k4750: "k4750",
        .k5000: "k5000",
        .k5250: "k5250",
        .k5500: "k5500",
        .k5750: "k5750",
        .k6000: "k6000",
        .k6250: "k6250",
        .k6500: "k6500",
        .k6750: "k6750",
        .k7000: "k7000",
        .k7250: "k7250",
        .k7500: "k7500",
        .k7750: "k7750",
        .k8000: "k8000",
        .k8250: "k8250",
        .k8500: "k8500",
        .k8750: "k8750",
        .k9000: "k9000",
        .k9250: "k9250",
        .k9500: "k9500",
        .k9750: "k9750",
        .k10000: "k10000",
        .k10250: "k10250",
        .k10500: "k10500",
        .k10750: "k10750",
        .k11000: "k11000",
        .k11250: "k11250",
        .k11500: "k11500",
        .k11750: "k11750",
        .k12000: "k12000",
        .k12250: "k12250",
        .k12500: "k12500",
        .k12750: "k12750",
        .k13000: "k13000",
        .k13250: "k13250",
        .k13500: "k13500",
        .k13750: "k13750",
        .k14000: "k14000",
        .k14250: "k14250",
        .k14500: "k14500",
        .k14750: "k14750",
        .k15000: "k15000"])
}

extension CameraRecordingMode: StorableEnum {
    static var storableMapper = Mapper<CameraRecordingMode, String>([
        .standard: "standard",
        .hyperlapse: "photo",
        .slowMotion: "slowMotion",
        .highFramerate: "highFramerate"])
}

extension CameraRecordingResolution: StorableEnum {
    static var storableMapper = Mapper<CameraRecordingResolution, String>([
        .resUhd8k: "uhd8k",
        .res5k: "5k",
        .resDci4k: "dci4k",
        .resUhd4k: "uhd4k",
        .res2_7k: "2.7k",
        .res1080p: "1080p",
        .res720p: "720p",
        .res720pSd: "720pSd",
        .res480p: "480p",
        .res1080pSd: "1080pSd"])
}

extension CameraRecordingFramerate: StorableEnum {
    static let storableMapper = Mapper<CameraRecordingFramerate, String>([
        .fps8_6: "fps8_6",
        .fps9: "9",
        .fps10: "fps10",
        .fps15: "15",
        .fps20: "20",
        .fps24: "24",
        .fps25: "25",
        .fps30: "30",
        .fps48: "48",
        .fps50: "50",
        .fps60: "60",
        .fps96: "96",
        .fps100: "100",
        .fps120: "120",
        .fps192: "192",
        .fps200: "200",
        .fps240: "240"
        ])
}

extension CameraHyperlapseValue: StorableEnum {
    static let storableMapper = Mapper<CameraHyperlapseValue, String>([
        .ratio15: "15",
        .ratio30: "30",
        .ratio60: "60",
        .ratio120: "120",
        .ratio240: "240"])
}

extension CameraPhotoMode: StorableEnum {
    static var storableMapper = Mapper<CameraPhotoMode, String>([
        .single: "single",
        .bracketing: "bracketing",
        .burst: "burst",
        .timeLapse: "timeLapse",
        .gpsLapse: "gpsLapse"])
}

extension CameraPhotoFormat: StorableEnum {
    static var storableMapper = Mapper<CameraPhotoFormat, String>([
        .fullFrame: "fullFrame",
        .large: "large",
        .rectilinear: "rectilinear"])
}

extension CameraPhotoFileFormat: StorableEnum {
    static var storableMapper = Mapper<CameraPhotoFileFormat, String>([
        .jpeg: "jpeg",
        .dng: "dng",
        .dngAndJpeg: "dngJpeg"])
}

extension CameraBurstValue: StorableEnum {
    static var storableMapper = Mapper<CameraBurstValue, String>([
        .burst14Over4s: "24/4",
        .burst14Over2s: "24/3",
        .burst14Over1s: "24/1",
        .burst10Over4s: "10/4",
        .burst10Over2s: "10/2",
        .burst10Over1s: "10/1",
        .burst4Over4s: "4/4",
        .burst4Over2s: "4/2",
        .burst4Over1s: "4/1"])
}

extension CameraBracketingValue: StorableEnum {
    static var storableMapper = Mapper<CameraBracketingValue, String>([
        .preset1ev: "1ev",
        .preset2ev: "2ev",
        .preset3ev: "3ev",
        .preset1ev2ev: "1ev2ev",
        .preset1ev3ev: "1ev3ev",
        .preset2ev3ev: "2ev3ev",
        .preset1ev2ev3ev: "1ev2ev3ev"])
}

extension CameraEvCompensation: StorableEnum {
    static var storableMapper = Mapper<CameraEvCompensation, String>([
        .evMinus3_00: "evMinus3_00",
        .evMinus2_67: "-2.67 ev",
        .evMinus2_33: "-2.33 ev",
        .evMinus2_00: "-2.00 ev",
        .evMinus1_67: "-1.67 ev",
        .evMinus1_33: "-1.33 ev",
        .evMinus1_00: "-1.00 ev",
        .evMinus0_67: "-0.67 ev",
        .evMinus0_33: "-0.33 ev",
        .ev0_00: "0.00 ev",
        .ev0_33: "+0.33 ev",
        .ev0_67: "+0.67 ev",
        .ev1_00: "+1.00 ev",
        .ev1_33: "+1.33 ev",
        .ev1_67: "+1.67 ev",
        .ev2_00: "+2.00 ev",
        .ev2_33: "+2.33 ev",
        .ev2_67: "+2.67 ev",
        .ev3_00: "+3.00 ev"
        ])
}

extension CameraCore.RecordingCapabilitiesEntry: StorableType {

    private enum Key: String {
        case modes, resolutions, framerates, hdr
    }

    init?(from content: AnyObject?) {
        if let content = StorableDict<String, AnyStorable>(from: content),
            let modes = StorableArray<CameraRecordingMode>(content[Key.modes.rawValue]),
            let resolutions = StorableArray<CameraRecordingResolution>(content[Key.resolutions.rawValue]),
            let framerates = StorableArray<CameraRecordingFramerate>(content[Key.framerates.rawValue]),
            let hdrAvailable = Bool(AnyStorable(content[Key.hdr.rawValue])) {
            self = CameraCore.RecordingCapabilitiesEntry(
                modes: Set(modes.storableValue), resolutions: Set(resolutions.storableValue),
                framerates: Set(framerates.storableValue), hdrAvailable: hdrAvailable)
        } else {
            return nil
        }
    }

    func asStorable() -> StorableProtocol {
        return StorableDict([
            Key.modes.rawValue: AnyStorable(Array(modes)),
            Key.resolutions.rawValue: AnyStorable(Array(resolutions)),
            Key.framerates.rawValue: AnyStorable(Array(framerates)),
            Key.hdr.rawValue: AnyStorable(hdrAvailable)])
    }
}

extension CameraCore.PhotoCapabilitiesEntry: StorableType {

    private enum Key: String {
        case modes, formats, fileFormats, hdr
    }

    init?(from content: AnyObject?) {
        if let content = StorableDict<String, AnyStorable>(from: content),
            let modes = StorableArray<CameraPhotoMode>(content[Key.modes.rawValue]),
            let formats = StorableArray<CameraPhotoFormat>(content[Key.formats.rawValue]),
            let fileFormats = StorableArray<CameraPhotoFileFormat>(content[Key.fileFormats.rawValue]),
            let hdrAvailable = Bool(AnyStorable(content[Key.hdr.rawValue])) {
            self = CameraCore.PhotoCapabilitiesEntry(
                modes: Set(modes.storableValue), formats: Set(formats.storableValue),
                fileFormats: Set(fileFormats.storableValue), hdrAvailable: hdrAvailable)
        } else {
            return nil
        }
    }

    func asStorable() -> StorableProtocol {
        return StorableDict([
            Key.modes.rawValue: AnyStorable(Array(modes)),
            Key.formats.rawValue: AnyStorable(Array(formats)),
            Key.fileFormats.rawValue: AnyStorable(Array(fileFormats)),
            Key.hdr.rawValue: AnyStorable(hdrAvailable)])
    }
}
