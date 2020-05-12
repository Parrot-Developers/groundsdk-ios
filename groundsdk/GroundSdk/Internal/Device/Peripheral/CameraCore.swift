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

/// Camera backend.
public protocol CameraBackend: class {
    /// Changes the camera mode
    ///
    /// - Parameter mode: new mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(mode: CameraMode) -> Bool

    /// Changes camera exposure mode
    ///
    /// - Parameters:
    ///   - exposureMode: requested exposure mode
    ///   - manualShutterSpeed: requested shutter speed when mode is `manualShutterSpeed` or `manual`
    ///   - manualIsoSensitivity: requested iso sensitivity when mode is `manualIsoSensitivity` or `manual`
    ///   - maximumIsoSensitivity: maximum iso sensitivity when mode is `automatic`
    ///   - autoExposureMeteringMode: auto exposure metering mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(exposureMode: CameraExposureMode, manualShutterSpeed: CameraShutterSpeed,
             manualIsoSensitivity: CameraIso, maximumIsoSensitivity: CameraIso,
             autoExposureMeteringMode: CameraAutoExposureMeteringMode) -> Bool

    /// Changes the exposure lock mode
    ///
    /// - Parameter exposureLockMode: requested exposure lock mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(exposureLockMode: CameraExposureLockMode) -> Bool

    /// Changes camera exposure compensation
    ///
    /// - Parameter exposureCompensation: requested exposure compensation value
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(exposureCompensation: CameraEvCompensation) -> Bool

    /// Changes the white balance mode
    ///
    /// - Parameters:
    ///   - whiteBalanceMode: requested white balance mode
    ///   - customTemperature: white balance temperature when mode is `custom`
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(whiteBalanceMode: CameraWhiteBalanceMode, customTemperature: CameraWhiteBalanceTemperature) -> Bool

    /// Changes the white balance lock
    ///
    /// - Parameter whiteBalanceLock: requested white balance lock
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(whiteBalanceLock: Bool) -> Bool

    /// Changes the active image style
    ///
    /// - Parameter activeStyle: requested image style
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(activeStyle: CameraStyle) -> Bool

    /// Changes the active image style parameters
    ///
    /// - Parameter styleParameters: new saturation, contrast and sharpness parameters
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(styleParameters: (saturation: Int, contrast: Int, sharpness: Int)) -> Bool

    /// Changes the recording mode
    ///
    /// - Parameters:
    ///   - recordingMode: requested recording mode
    ///   - resolution: requested recording resolution, nil to keep the current resolution of the requested mode
    ///   - framerate: requested recording framerate, nil to keep the current framerate of the requested mode
    ///   - hyperlapse: requested hyperlapse value when mode is `hyperlapse`
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(recordingMode: CameraRecordingMode, resolution: CameraRecordingResolution?,
             framerate: CameraRecordingFramerate?, hyperlapse: CameraHyperlapseValue?) -> Bool

    /// Changes auto-record setting
    ///
    /// - Parameter autoRecord: requested auto-record setting value
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(autoRecord: Bool) -> Bool

    /// Changes the photo mode
    ///
    /// - Parameters:
    ///   - photoMode: requested photo mode
    ///   - format: requested photo format
    ///   - fileFormat: requested photo file format
    ///   - burst: request bust value when photo mode is `burst`
    ///   - bracketing: request bracketing value when photo mode is `bracketing`
    ///   - captureInterval: capture interval value
    /// Current time-lapse interval value (in seconds) when the photo mode is time_lapse.
    /// Current GPS-lapse interval value (in meters) when the photo mode is gps_lapse.
    /// Ignored in other modes.
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(photoMode: CameraPhotoMode, format: CameraPhotoFormat?, fileFormat: CameraPhotoFileFormat?,
             burst: CameraBurstValue?, bracketing: CameraBracketingValue?, gpslapseCaptureInterval: Double?,
             timelapseCaptureInterval: Double?) -> Bool

    /// Change hdr setting
    ///
    /// - Parameter hdr: new hdr setting value
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(hdr: Bool) -> Bool

    /// Sets the max zoom speed
    ///
    /// - Parameter maxZoomSpeed: the new max zoom speed
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(maxZoomSpeed: Double) -> Bool

    /// Sets the quality degradation allowance during zoom change with velocity.
    ///
    /// - Parameter qualityDegradationAllowance: the new allowance
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(qualityDegradationAllowance: Bool) -> Bool

    /// Start taking photo(s)
    ///
    /// - Returns: true if the command has been sent, false otherwise
    func startPhotoCapture() -> Bool

    /// Stop taking photo(s)
    ///
    /// - Returns: true if the command has been sent, false otherwise
    func stopPhotoCapture() -> Bool

    /// Start recording
    ///
    /// - Returns: true if the command has been sent, false otherwise
    func startRecording() -> Bool

    /// Stop recording
    ///
    /// - Returns: true if the command has been sent, false otherwise
    func stopRecording() -> Bool

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
    func control(mode: CameraZoomControlMode, target: Double)

    /// Sets alignment offsets.
    ///
    /// - Parameter yawOffset: the new offset to apply to the yaw axis
    /// - Parameter pitchOffset: the new offset to apply to the pitch axis
    /// - Parameter rollOffset: the new offset to apply to the roll axis
    /// - Returns: true if the command has been sent, false otherwise
    func set(yawOffset: Double, pitchOffset: Double, rollOffset: Double) -> Bool

    /// Factory reset camera alignment.
    ///
    /// - Returns: true if the command has been sent, false otherwise
    func resetAlignment() -> Bool
}

/// Camera peripheral implementation
public class CameraCore: PeripheralCore, Camera {
    /// implementation backend
    private unowned let backend: CameraBackend

    /// Whether this camera is active or not
    public private(set) var isActive: Bool = false

    /// Camera mode switcher, to select recording or photo mode if supported
    public var modeSetting: CameraModeSetting {
        return _modeSetting
    }
    /// Internal storage for mode settings
    private var _modeSetting: CameraModeSettingCore!

    /// Exposure settings
    public var exposureSettings: CameraExposureSettings {
        return _exposureSettings
    }
    /// Internal storage for exposure settings
    private var _exposureSettings: CameraExposureSettingsCore!

    /// Exposure compensation setting
    public var exposureCompensationSetting: CameraExposureCompensationSetting {
        return _exposureCompensationSetting
    }
    /// Internal storage for exposure compensation settings
    private var _exposureCompensationSetting: CameraExposureCompensationSettingCore!

    /// White balance settings
    public var whiteBalanceSettings: CameraWhiteBalanceSettings {
        return _whiteBalanceSettings
    }
    /// Internal storage for white balance settings
    private var _whiteBalanceSettings: CameraWhiteBalanceSettingsCore!

    public var whiteBalanceLock: CameraWhiteBalanceLock? {
        return isActive ? _whiteBalanceLock : nil
    }
    /// Internal storage for white balance lock
    private var _whiteBalanceLock: CameraWhiteBalanceLockCore?

    /// Style settings
    public var styleSettings: CameraStyleSettings {
        return _styleSettings
    }
    /// Internal storage for style settings
    private var _styleSettings: CameraStyleSettingsCore!

    /// Settings when mode is `recording`
    public var recordingSettings: CameraRecordingSettings {
        return _recordingSettings
    }
    /// Internal storage for recording settings
    private var _recordingSettings: CameraRecordingSettingsCore!

    /// Auto start and stop recording setting.
    public var autoRecordSetting: BoolSetting? {
        return _autoRecordSetting
    }
    /// Internal storage for autorecord settings
    private var _autoRecordSetting: BoolSettingCore?

    /// Settings when mode is `photo`
    public var photoSettings: CameraPhotoSettings {
        return _photoSettings
    }
    /// Internal storage for photo settings
    private var _photoSettings: CameraPhotoSettingsCore!

    /// Hdr settings
    public var hdrSetting: BoolSetting? {
        return _hdrSetting
    }
    /// Internal storage for hdr settings
    private var _hdrSetting: BoolSettingCore?

    /// Exposure lock
    public var exposureLock: CameraExposureLock? {
        return isActive ? _exposureLock : nil
    }
    /// Internal storage for exposure lock
    private var _exposureLock: CameraExposureLockCore?

    /// Is HDR available in the current mode and configuration
    public var hdrAvailable: Bool {
        switch _modeSetting.mode {
        case .recording:
            return _recordingSettings.hdrAvailable
        case .photo:
            return _photoSettings.hdrAvailable
        }
    }

    /// recording state
    public var recordingState: CameraRecordingState {
        return _recordingState
    }
    /// Internal storage for recording state
    private var _recordingState = CameraRecordingStateCore()

    /// photo state
    public var photoState: CameraPhotoState {
        return _photoState
    }
    /// Internal storage for photo state
    private var _photoState = CameraPhotoStateCore()

    /// HDR state
    public private (set) var hdrState = false

    /// Camera zoom.
    public var zoom: CameraZoom? {
        return _zoom
    }
    /// Internal storage for zoom
    private var _zoom: CameraZoomCore?

    /// Camera alignment
    public var alignment: CameraAlignment? {
        return isActive ? _alignment : nil
    }
    /// Internal camera alignment
    private var _alignment: CameraAlignmentCore?

    /// Constructor
    ///
    /// - Parameters:
    ///    - desc: component descriptor
    ///    - store: store where this peripheral will be stored
    ///    - backend: Camera backend
    public init(_ desc: ComponentDescriptor, store: ComponentStoreCore, backend: CameraBackend) {
        self.backend = backend
        super.init(desc: desc, store: store)
        createSettings()
    }

    /// Creates all non optional settings
    private func createSettings() {
        _modeSetting = CameraModeSettingCore(didChangeDelegate: self) { [unowned self] mode in
            return self.backend.set(mode: mode)
        }

        _exposureSettings = CameraExposureSettingsCore(didChangeDelegate: self) {
            // swiftlint:disable:next closure_parameter_position
            [unowned self] (mode, shutterSpeed, isoSensitivity, maxIsoSensitivity, autoExposureMeteringMode) in
            return self.backend.set(exposureMode: mode, manualShutterSpeed: shutterSpeed,
                                    manualIsoSensitivity: isoSensitivity, maximumIsoSensitivity: maxIsoSensitivity,
                                    autoExposureMeteringMode: autoExposureMeteringMode)
        }

        _exposureCompensationSetting = CameraExposureCompensationSettingCore(didChangeDelegate: self) {
            // swiftlint:disable:next closure_parameter_position
            [unowned self] value in
            return self.backend.set(exposureCompensation: value)
        }

        _whiteBalanceSettings = CameraWhiteBalanceSettingsCore(didChangeDelegate: self) {
            // swiftlint:disable:next closure_parameter_position
            [unowned self] mode, customTemperature in
            return self.backend.set(whiteBalanceMode: mode, customTemperature: customTemperature)
        }

        _styleSettings =  CameraStyleSettingsCore(
            didChangeDelegate: self,
            changeStyleBackend: { [unowned self] style in
                return self.backend.set(activeStyle: style)
            },
            changeConfigBackend: { [unowned self] saturation, contrast, sharpness in
                return self.backend.set(styleParameters: (saturation, contrast, sharpness))
            }
        )

        _recordingSettings = CameraRecordingSettingsCore(didChangeDelegate: self) {
            // swiftlint:disable:next closure_parameter_position
            [unowned self] (mode, resolution, framerate, hyperlapse) in
            return self.backend.set(recordingMode: mode, resolution: resolution, framerate: framerate,
                                    hyperlapse: hyperlapse)
        }

        _photoSettings = CameraPhotoSettingsCore(didChangeDelegate: self) {
            // swiftlint:disable:next closure_parameter_position
    [unowned self] (mode, format, fileFormat, burst, bracketing, gpslapseCaptureInterval, timelapseCaptureInterval) in
            return self.backend.set(photoMode: mode, format: format, fileFormat: fileFormat,
                                    burst: burst, bracketing: bracketing,
                                    gpslapseCaptureInterval: gpslapseCaptureInterval,
                                    timelapseCaptureInterval: timelapseCaptureInterval)
        }
    }

    /// Tells if startRecording can be called
    public var canStartRecord: Bool {
        return _recordingState.functionState.isStopped
    }

    /// Tells if stopRecord can be called
    public var canStopRecord: Bool {
        return _recordingState.functionState == .started
    }

    /// Tells if startPhoto can be called
    public var canStartPhotoCapture: Bool {
        return photoState.functionState == .stopped
    }

    /// Tells if stopPhoto can be called
    public var canStopPhotoCapture: Bool {
        return photoState.functionState == .started &&
            (photoSettings.mode == .gpsLapse || photoSettings.mode == .timeLapse)
    }

    /// Start recording. Can be called when `recordingState.state` is `ready`
    public func startRecording() {
        if _recordingState.functionState.isStopped && backend.startRecording() {
            update(recordingState: .starting)
            notifyUpdated()
        }
    }

    /// Stop recording. Can be called when `recordingState.state` is `inProgress`
    public func stopRecording() {
        if recordingState.functionState == .started && backend.stopRecording() {
            update(recordingState: .stopping)
            markChanged()
            notifyUpdated()
        }
    }

    /// Start taking photo(s). Can be called when `photoState` is `ready`
    public func startPhotoCapture() {
        if photoState.functionState == .stopped && backend.startPhotoCapture() {
            update(photoState: .started, photoCount: 0)
            notifyUpdated()
        }
    }

    /// Stop taking photo(s). Can be called when `photoState` is `takingPhotos`
    public func stopPhotoCapture() {
        if photoState.functionState == .started && backend.stopPhotoCapture() {
            update(photoState: .stopping, photoCount: 0)
            notifyUpdated()
        }
    }

    override func reset() {
        // recreate non optional settings
        isActive = false
        _whiteBalanceLock = nil
        _exposureLock = nil
        _zoom = nil
        _alignment = nil
        createSettings()
    }

    /// Create zoom
    private func createZoom() -> CameraZoomCore {
        return CameraZoomCore(backend: self, settingDidChangeDelegate: self)
    }

    /// Update active camera flag
    ///
    /// - Parameter active: active camera
    /// - Returns: self to allow call chaining
    @discardableResult public func updateActiveFlag(active: Bool) -> CameraCore {
        if _exposureLock != nil || _whiteBalanceLock != nil || self.hdrAvailable {
            markChanged()
        }

        if active != self.isActive {
            self.isActive = active
            markChanged()
        }
        return self
    }

    /// Debug description
    public override var description: String {
        return "CameraCore \(_modeSetting!) \(_exposureSettings!) \(_whiteBalanceSettings!) " +
        "\(_recordingSettings!) \(_photoSettings!)"
    }
}

// MARK: - Objc Support
/// Extension adding objc GSCamera conformance
extension CameraCore: GSCamera {
    /// Camera mode switcher, to select recording or photo mode if supported
    public var gsModeSetting: GSCameraModeSetting {
        return _modeSetting
    }

    /// Exposure settings
    public var gsExposureSettings: GSCameraExposureSettings {
        return _exposureSettings
    }

    public var gsExposureLock: GSCameraExposureLock? {
        return _exposureLock
    }

    /// Camera alignment
    public var gsAlignment: GSCameraAlignment? {
        return _alignment
    }

    /// Exposure compensation setting
    public var gsExposureCompensationSetting: GSCameraExposureCompensationSetting {
        return _exposureCompensationSetting
    }

    /// White balance settings
    public var gsWhiteBalanceSettings: GSCameraWhiteBalanceSettings {
        return _whiteBalanceSettings
    }

    public var gsWhiteBalanceLock: GSCameraWhiteBalanceLock? {
        return _whiteBalanceLock
    }

    /// Style settings
    public var gsStyleSettings: GSCameraStyleSettings {
        return _styleSettings
    }

    /// Settings when the camera is in recording mode
    public var gsRecordingSettings: GSCameraRecordingSettings {
        return _recordingSettings
    }

    /// Settings when the camera is in photo mode
    public var gsPhotoSettings: GSCameraPhotoSettings {
        return _photoSettings
    }
}

// MARK: - Backend
/// Backend callback methods
extension CameraCore {

    /// Struct to store one entry of recording capabilities
    public struct RecordingCapabilitiesEntry {
        /// Supported recording modes
        public let modes: Set<CameraRecordingMode>
        /// Supported recording resolutions with respect to the supported recording modes
        public let resolutions: Set<CameraRecordingResolution>
        /// Supported recording framerates with respect to the supported recording modes and resolutions
        public let framerates: Set<CameraRecordingFramerate>
        /// Availability of HDR
        public let hdrAvailable: Bool

        /// Constructor
        ///
        /// - Parameters:
        ///    - modes: supported recording modes
        ///    - resolutions: recording resolutions supported in those `modes`
        ///    - framerates: recording framerates supported in those `modes` and `resolutions`
        ///    - hdrAvailable: availability of HDR
        public init(modes: Set<CameraRecordingMode>, resolutions: Set<CameraRecordingResolution>,
                    framerates: Set<CameraRecordingFramerate>, hdrAvailable: Bool) {
            self.modes = modes
            self.resolutions = resolutions
            self.framerates = framerates
            self.hdrAvailable = hdrAvailable
        }
    }

    /// Struct to store one entry of photo capabilities
    public struct PhotoCapabilitiesEntry {
        /// Supported photo modes
        public let modes: Set<CameraPhotoMode>
        /// Supported photo formats with respect to the supported photo modes
        public let formats: Set<CameraPhotoFormat>
        /// Supported photo file formats with respect to the supported photo modes and formats
        public let fileFormats: Set<CameraPhotoFileFormat>
        /// Availability of HDR
        public let hdrAvailable: Bool

        /// Constructor
        ///
        /// - Parameters:
        ///   - modes: supported photo modes
        ///   - formats: photo formats supported in those `modes`
        ///   - fileFormats: photo file formats supported in those `modes` and `formats`
        ///   - hdrAvailable: availability of HDR
        public init(modes: Set<CameraPhotoMode>, formats: Set<CameraPhotoFormat>,
                    fileFormats: Set<CameraPhotoFileFormat>, hdrAvailable: Bool) {
            self.modes = modes
            self.formats = formats
            self.fileFormats = fileFormats
            self.hdrAvailable = hdrAvailable
        }
    }

    // MARK: Mode

    /// Changes supported camera modes
    ///
    /// - Parameter supportedModes: new supported camera modes
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(supportedModes newSupportedMode: Set<CameraMode>) -> CameraCore {
        if _modeSetting.update(supportedModes: newSupportedMode) {
            markChanged()
        }
        return self
    }

    /// Changes camera mode
    ///
    /// - Parameter mode: new camera mode
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(mode newMode: CameraMode) -> CameraCore {
        if  _modeSetting.update(mode: newMode) {
            markChanged()
        }
        return self
    }

    // MARK: Exposure

    /// Changes supported camera exposure modes
    ///
    /// - Parameter supportedExposureModes: new supported camera exposure modes
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(supportedExposureModes newSupportedMode: Set<CameraExposureMode>)
        -> CameraCore {
            if _exposureSettings.update(supportedModes: newSupportedMode) {
                markChanged()
            }
            return self
    }

    /// Changes camera exposure mode
    ///
    /// - Parameter exposureMode: new camera exposure mode
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(exposureMode newExposureMode: CameraExposureMode) -> CameraCore {
        if _exposureSettings.update(mode: newExposureMode) {
            markChanged()
        }
        return self
    }

    /// Changes supported camera manual shutter speeds
    ///
    /// - Parameter supportedManualShutterSpeeds: new supported camera manual shutter speeds
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        supportedManualShutterSpeeds newSupportedShutterSpeeds: Set<CameraShutterSpeed>) -> CameraCore {
            if _exposureSettings.update(supportedManualShutterSpeeds: newSupportedShutterSpeeds) {
                markChanged()
            }
            return self
    }

    /// Changes camera manual shutter speed
    ///
    /// - Parameter manualShutterSpeed: new camera manual shutter speed
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(manualShutterSpeed newShutterSpeed: CameraShutterSpeed) -> CameraCore {
        if _exposureSettings.update(manualShutterSpeed: newShutterSpeed) {
            markChanged()
        }
        return self
    }

    /// Changes supported camera manual iso sensitivity
    ///
    /// - Parameter supportedManualIsoSensitivity: new supported camera manual iso sensitivity
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(supportedManualIsoSensitivity newSupportedIsoSensitivity: Set<CameraIso>)
        -> CameraCore {
            if _exposureSettings.update(supportedManualIsoSensitivity: newSupportedIsoSensitivity) {
                markChanged()
            }
            return self
    }

    /// Changes camera manual iso sensitivity
    ///
    /// - Parameter manualIsoSensitivity: new camera manual iso sensitivity
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(manualIsoSensitivity newIsoSensitivity: CameraIso) -> CameraCore {
        if _exposureSettings.update(manualIsoSensitivity: newIsoSensitivity) {
            markChanged()
        }
        return self
    }

    /// Changes supported camera maximum iso sensitivity
    ///
    /// - Parameter supportedMaximumIsoSensitivity: new supported camera maximum iso sensitivity
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(supportedMaximumIsoSensitivity newMaximumIsoSensitivity: Set<CameraIso>)
        -> CameraCore {
            if _exposureSettings.update(supportedMaximumIsoSensitivity: newMaximumIsoSensitivity) {
                markChanged()
            }
            return self
    }

    /// Changes camera maximum iso sensitivity
    ///
    /// - Parameter maximumIsoSensitivity: new camera maximum iso sensitivity
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(maximumIsoSensitivity newMaximumIsoSensitivity: CameraIso) -> CameraCore {
        if _exposureSettings.update(maximumIsoSensitivity: newMaximumIsoSensitivity) {
            markChanged()
        }
        return self
    }

    /// Changes camera auto exposure metering mode
    ///
    /// - Parameter autoExposureMeteringMode: new camera auto exposure metering mode
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(autoExposureMeteringMode
        newAutoExposureMeteringMode: CameraAutoExposureMeteringMode) -> CameraCore {
        if _exposureSettings.update(autoExposureMeteringMode: newAutoExposureMeteringMode) {
            markChanged()
        }
        return self
    }

    /// Change exposure lock
    ///
    /// - Parameter exposureLockMode: new exposure lock mode value
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(exposureLockMode: CameraExposureLockMode) -> CameraCore {
        if _exposureLock == nil {
            _exposureLock = CameraExposureLockCore(didChangeDelegate: self) { [unowned self] mode in
                return self.backend.set(exposureLockMode: mode)
            }
            if isActive {
                markChanged()
            }
        }
        if _exposureLock!.update(mode: exposureLockMode) {
            if isActive {
                markChanged()
            }
        }
        return self
    }

    // MARK: Exposure Compensation

    /// Changes supported camera exposure compensation values
    ///
    /// - Parameter supportedExposureCompensationValues: new supported camera exposure compensation values
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        supportedExposureCompensationValues newExposureCompensations: Set<CameraEvCompensation>) -> CameraCore {
        if _exposureCompensationSetting.update(supportedValues: newExposureCompensations) {
            markChanged()
        }
        return self
    }

    /// Changes camera exposure compensation value
    ///
    /// - Parameter exposureCompensationValue: new exposure compensation value
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(exposureCompensationValue newExposureCompensationValue: CameraEvCompensation)
        -> CameraCore {
            if _exposureCompensationSetting.update(value: newExposureCompensationValue) {
                markChanged()
            }
            return self
    }

    // MARK: White Balance

    /// Changes supported camera white balance modes
    ///
    /// - Parameter supportedWhiteBalanceModes: new supported white balance modes
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(supportedWhiteBalanceModes newSupportedModes: Set<CameraWhiteBalanceMode>)
        -> CameraCore {
            if _whiteBalanceSettings.update(supportedModes: newSupportedModes) {
                markChanged()
            }
            return self
    }

    /// Changes camera white balance mode
    ///
    /// - Parameter whiteBalanceMode: new white balance mode
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(whiteBalanceMode newWhiteBalanceMode: CameraWhiteBalanceMode) -> CameraCore {
        if _whiteBalanceSettings.update(mode: newWhiteBalanceMode) {
            markChanged()
        }
        return self
    }

    /// Changes camera white balance lock supported
    ///
    /// - Parameter whiteBalanceMode: new white balance lock supported
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(whiteBalanceLockSupported: Bool?) -> CameraCore {
        if whiteBalanceLockSupported == nil {
            if _whiteBalanceLock != nil {
                _whiteBalanceLock = nil
                if isActive {
                    markChanged()
                }
            }
            return self
        }
        if _whiteBalanceLock == nil {
            _whiteBalanceLock = CameraWhiteBalanceLockCore(didChangeDelegate: self) { [unowned self] isLockable in
                return self.backend.set(whiteBalanceLock: isLockable)
            }
            if isActive {
                markChanged()
            }
        }

        if _whiteBalanceLock!.update(isLockable: whiteBalanceLockSupported) {
            if isActive {
                markChanged()
            }
        }
        return self
    }

    /// Change white balance lock
    ///
    /// - Parameter white balance lock: new white balance lock value
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(whiteBalanceLock: Bool) -> CameraCore {
        if _whiteBalanceLock == nil {
           return self
        }
        if _whiteBalanceLock!.update(lock: whiteBalanceLock) {
            markChanged()
        }
        return self
    }

    // MARK: Styles

    /// Changes supported styles
    ///
    /// - Parameter supportedStyles: new supported styles
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(supportedStyles newSsupportedStyles: Set<CameraStyle>) -> CameraCore {
        if _styleSettings.update(supportedStyles: newSsupportedStyles) {
            markChanged()
        }
        return self
    }

    /// Changes timelapse interval min
    ///
    /// - Parameter timelapseIntervalMin: new timelapse interval min
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(timelapseIntervalMin newTimelapseIntervalMin: Double) -> CameraCore {
        if _photoSettings.update(timelapseIntervalMin: newTimelapseIntervalMin) {
            markChanged()
        }
        return self
    }

    /// Changes gpslapse interval min
    ///
    /// - Parameter gpslapseIntervalMin: new gpslapse interval min
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(gpslapseIntervalMin newGpslapseIntervalMin: Double) -> CameraCore {
        if _photoSettings.update(gpslapseIntervalMin: newGpslapseIntervalMin) {
            markChanged()
        }
        return self
    }

    /// Changes active style.
    ///
    /// - Parameter activeStyle: new active style
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(activeStyle newActiveStyle: CameraStyle) -> CameraCore {
        if _styleSettings.update(activeStyle: newActiveStyle) {
            markChanged()
        }
        return self
    }

    /// Changes saturation style setting
    ///
    /// - Parameter saturation: new saturation
    /// - Returns: self to allow call chaining
    @discardableResult public func update(saturation: (min: Int, value: Int, max: Int)) -> CameraCore {
        let saturationChanged = _styleSettings.update(saturation: saturation)
        if saturationChanged {
            markChanged()
        }
        return self
    }

    /// Changes contrast style setting
    ///
    /// - Parameter contrast: new contrast
    /// - Returns: self to allow call chaining
    @discardableResult public func update(contrast: (min: Int, value: Int, max: Int)) -> CameraCore {
        let contrastChanged = _styleSettings.update(contrast: contrast)
        if contrastChanged {
            markChanged()
        }
        return self
    }

    /// Changes sharpness style setting
    ///
    /// - Parameter sharpness: new sharpness
    /// - Returns: self to allow call chaining
    @discardableResult public func update(sharpness: (min: Int, value: Int, max: Int)) -> CameraCore {
        let sharpnessChanged = _styleSettings.update(sharpness: sharpness)
        if sharpnessChanged {
            markChanged()
        }
        return self
    }

    /// Changes supported camera custom white balance temperatures
    ///
    /// - Parameter supportedCustomWhiteBalanceTemperatures: new supported custom white balance temperatures
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        supportedCustomWhiteBalanceTemperatures newSupportedCustomTemperatures: Set<CameraWhiteBalanceTemperature>)
        -> CameraCore {
            if _whiteBalanceSettings.update(supportedCustomTemperatures: newSupportedCustomTemperatures) {
                markChanged()
            }
            return self
    }

    /// Changes camera custom white balance temperature
    ///
    /// - Parameter customWhiteBalanceTemperature: new custom white balance temperature
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(customWhiteBalanceTemperature newTemperature: CameraWhiteBalanceTemperature)
        -> CameraCore {
            if _whiteBalanceSettings.update(customTemperature: newTemperature) {
                markChanged()
            }
            return self
    }

    // MARK: HDR

    /// Change HDR setting
    ///
    /// - Parameter hdrSetting: new HDR setting value
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(hdrSetting: Bool) -> CameraCore {
        if _hdrSetting == nil {
            _hdrSetting = BoolSettingCore(didChangeDelegate: self) { [unowned self] value in
                return self.backend.set(hdr: value)
            }
            markChanged()
        }
        if _hdrSetting!.update(value: hdrSetting) {
            markChanged()
        }
        return self
    }

    /// Change actual HDR state
    ///
    /// - Parameter hdrState: new HDR state
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(hdrState: Bool) -> CameraCore {
        if self.hdrState != hdrState {
            self.hdrState = hdrState
            markChanged()
        }
        return self
    }

    // MARK: Recording

    /// Changes supported modes, resolution and framerates
    ///
    /// - Parameter recordingCapabilities: new supported modes, resolution and framerates
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(recordingCapabilities: [RecordingCapabilitiesEntry]) -> CameraCore {
        if _recordingSettings.update(recordingCapabilities: recordingCapabilities) {
            markChanged()
        }
        return self
   }

    /// Changes camera recording mode
    ///
    /// - Parameter recordingMode: new camera recording mode
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(recordingMode newMode: CameraRecordingMode) -> CameraCore {
        if _recordingSettings.update(mode: newMode) {
            markChanged()
        }
        return self
    }

    /// Changes recording resolution
    ///
    /// - Parameter recordingResolution: new recording resolution for the current recording mode
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(recordingResolution newResolution: CameraRecordingResolution)
        -> CameraCore {
            if _recordingSettings.update(resolution: newResolution) {
                markChanged()
            }
            return self
    }

    /// Changes recording resolution
    ///
    /// - Parameter recordingResolution: new recording resolution for the current recording mode
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(recordingFramerate newFramerate: CameraRecordingFramerate)
        -> CameraCore {
            if _recordingSettings.update(framerate: newFramerate) {
                markChanged()
            }
            return self
    }

    /// Changes supported recording hyperlapse values
    ///
    /// - Parameter supportedHyperlapseValues: new supported recording hyperlapse values
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        supportedRecordingHyperlapseValues newHyperlapsValues: Set<CameraHyperlapseValue>)
        -> CameraCore {
            if _recordingSettings.update(supportedHyperlapseValues: newHyperlapsValues) {
                markChanged()
            }
            return self
    }

    /// Changes recording hyperlapse value
    ///
    /// - Parameter recordingHyperlapseValue: new recording hyperlapse value
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(recordingHyperlapseValue newHyperlapseValue: CameraHyperlapseValue)
        -> CameraCore {
            if _recordingSettings.update(hyperlapseValue: newHyperlapseValue) {
                markChanged()
            }
            return self
    }

    /// Change recording bitrate
    ///
    /// - Parameter recordingBitrate: new recording bitrate
    /// - Returns: true if the value has been changed, false else
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(recordingBitrate bitrate: UInt) -> CameraCore {
        if _recordingSettings.update(bitrate: bitrate) {
            markChanged()
        }
        return self
    }

    // MARK: auto-record

    /// Change auto-record setting
    ///
    /// - Parameter value: new auto-record setting value
    /// - Returns: true if the value has been changed, false else
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(autoRecord value: Bool) -> CameraCore {
        if _autoRecordSetting == nil {
            _autoRecordSetting = BoolSettingCore(didChangeDelegate: self) { [unowned self] value in
                return self.backend.set(autoRecord: value)
            }
            markChanged()
        }
        if _autoRecordSetting!.update(value: value) {
            markChanged()
        }
        return self
    }

    // MARK: Photo

    /// Changes supported camera photo modes, formats and fileformats
    ///
    /// - Parameter photoCapabilities: new photo capabilities
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(photoCapabilities: [PhotoCapabilitiesEntry]) -> CameraCore {
        if _photoSettings.update(photoCapabilities: photoCapabilities) {
            markChanged()
        }
        return self
    }

    /// Changes camera photo mode
    ///
    /// - Parameter supportedPhotoModes: new camera photo mode
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(photoMode newMode: CameraPhotoMode) -> CameraCore {
        if _photoSettings.update(mode: newMode) {
            markChanged()
        }
        return self
    }

    /// Changes photo format
    ///
    /// - Parameter photoFormat: new photo format for current photo mode
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(photoFormat newFormat: CameraPhotoFormat) -> CameraCore {
        if _photoSettings.update(format: newFormat) {
            markChanged()
        }
        return self
    }

    /// Changes timelapse capture interval
    ///
    /// - Parameter timelapseCaptureInterval: new timelapse capture interval for current photo mode
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(timelapseCaptureInterval newTimelapseCaptureInterval: Double) -> CameraCore {
        if _photoSettings.update(timelapseCaptureInterval: newTimelapseCaptureInterval) {
            markChanged()
        }
        return self
    }

    /// Changes gpslapse capture interval
    ///
    /// - Parameter gpslapseCaptureInterval: new gpslapse capture interval for current photo mode
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(gpslapseCaptureInterval newGpslapseCaptureInterval: Double) -> CameraCore {
        if _photoSettings.update(gpslapseCaptureInterval: newGpslapseCaptureInterval) {
            markChanged()
        }
        return self
    }

    /// Changes photo file format
    ///
    /// - Parameter photoFileFormat: new photo file formats for current photo format
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(photoFileFormat newFileFormat: CameraPhotoFileFormat) -> CameraCore {
        if _photoSettings.update(fileFormat: newFileFormat) {
            markChanged()
        }
        return self
    }

    /// Changes supported photo burst values
    ///
    /// - Parameter supportedPhotoBurstValues: new supported photo burst values
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(supportedPhotoBurstValues newBurstValues: Set<CameraBurstValue>)
        -> CameraCore {
            if _photoSettings.update(supportedBurstValues: newBurstValues) {
                markChanged()
            }
            return self
    }

    /// Changes photo burst value
    ///
    /// - Parameter photoBurstValue: new photo burst value
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(photoBurstValue newBurstValue: CameraBurstValue) -> CameraCore {
        if _photoSettings.update(burstValue: newBurstValue) {
            markChanged()
        }
        return self
    }

    /// Changes supported photo bracketing values
    ///
    /// - Parameter supportedBracketingValues: new supported photo bracketing values
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        supportedPhotoBracketingValues newBracketingValues: Set<CameraBracketingValue>) -> CameraCore {
            if _photoSettings.update(supportedBracketingValues: newBracketingValues) {
                markChanged()
            }
            return self
    }

    /// Changes photo bracketing value
    ///
    /// - Parameter photoBracketingValue: new photo bracketing value
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        photoBracketingValue newBracketingValue: CameraBracketingValue) -> CameraCore {

        if _photoSettings.update(bracketingValue: newBracketingValue) {
            markChanged()
        }
        return self
    }

    /// Changes recording state
    ///
    /// - Parameters:
    ///   - newState: new state
    ///   - startTime: recording start time
    ///   - mediaId: id of the media when event is `photo_saved`
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        recordingState newState: CameraRecordingFunctionState, startTime: Date? =  nil,
        mediaId: String? = nil) -> CameraCore {
        if _recordingState.update(functionState: newState, startTime: startTime, mediaId: mediaId) {
            markChanged()
        }
        return self
    }

    /// Changes photo count
    ///
    /// - Parameters:
    ///   - photoCount: new photo count, when event is `taking_photo`
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(photoCount: Int) -> CameraCore {
        if _photoState.update(photoCount: photoCount) {
            markChanged()
        }
        return self
    }

    /// Changes photo state
    ///
    /// - Parameters:
    ///   - newState: new state
    ///   - photoCount: new photo count, when event is `taking_photo`
    ///   - mediaId: id of the media when event is `photo_saved`
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        photoState newState: CameraPhotoFunctionState, photoCount: Int? = nil, mediaId: String? = nil) -> CameraCore {
        if _photoState.update(functionState: newState, photoCount: photoCount, mediaId: mediaId) {
            markChanged()
        }
        return self
    }

    /// Changes zoom availability
    ///
    /// - Parameter zoomIsAvailable: new availability
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(zoomIsAvailable newValue: Bool) -> CameraCore {
        // create the zoom if it was not already created
        if _zoom == nil {
            _zoom = createZoom()
            markChanged()
        }
        if _zoom!.update(isAvailable: newValue) {
            markChanged()
        }
        return self
    }

    /// Changes zoom level
    ///
    /// - Parameter currentZoomLevel: new zoom level
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(currentZoomLevel newValue: Double) -> CameraCore {
        // create the zoom if it was not already created
        if _zoom == nil {
            _zoom = createZoom()
            markChanged()
        }
        if _zoom!.update(currentLevel: newValue) {
            markChanged()
        }
        return self
    }

    /// Changes max lossy (i.e. with quality degradation) zoom level
    ///
    /// - Parameter maxLossyZoomLevel: new max lossy zoom level
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(maxLossyZoomLevel newValue: Double) -> CameraCore {
        // create the zoom if it was not already created
        if _zoom == nil {
            _zoom = createZoom()
            markChanged()
        }
        if _zoom!.update(maxLossyLevel: newValue) {
            markChanged()
        }
        return self
    }

    /// Changes max loss less (i.e. without quality degradation) zoom level
    ///
    /// - Parameter maxLossLessZoomLevel: new max loss less zoom level
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(maxLossLessZoomLevel newValue: Double) -> CameraCore {
        // create the zoom if it was not already created
        if _zoom == nil {
            _zoom = createZoom()
            markChanged()
        }
        if _zoom!.update(maxLossLessLevel: newValue) {
            markChanged()
        }
        return self
    }

    /// Changes quality degradation allowance during zoom change with velocity
    ///
    /// - Parameter qualityDegradationAllowed: new allowance
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(qualityDegradationAllowed newValue: Bool) -> CameraCore {
        // create the zoom if it was not already created
        if _zoom == nil {
            _zoom = createZoom()
            markChanged()
        }
        if _zoom!.update(qualityDegradationAllowed: newValue) {
            markChanged()
        }
        return self
    }

    /// Changes max zoom speed setting
    ///
    /// - Parameters:
    ///   - maxZoomSpeedLowerBound: new max lower bound, nil if bound does not change
    ///   - maxZoomSpeed: new setting value, nil if it does not change
    ///   - maxZoomSpeedUpperBound: new max upper bound, nil if bound does not change
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        maxZoomSpeedLowerBound: Double?, maxZoomSpeed: Double?,
        maxZoomSpeedUpperBound: Double?) -> CameraCore {

        // create the zoom if it was not already created
        if _zoom == nil {
            _zoom = createZoom()
            markChanged()
        }
        if _zoom!.update(
            maxSpeedLowerBound: maxZoomSpeedLowerBound,
            maxSpeed: maxZoomSpeed,
            maxSpeedUpperBound: maxZoomSpeedUpperBound) {

            markChanged()
        }
        return self
    }

    /// Reset the zoom values.
    ///
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func resetZoomValues() -> CameraCore {
        if let _zoom = _zoom {
            _zoom.resetValues()
            markChanged()
        }
        return self
    }

    /// Changes alignments offsets.
    ///
    /// - Parameters:
    ///   - yawLowerBound: new yaw offset lower bound
    ///   - yaw: new yaw offset value
    ///   - yawUpperBound: new yaw offset upper bound
    ///   - pitchLowerBound: new pitch offset lower bound
    ///   - pitch: new pitch offset value
    ///   - pitchUpperBound: new pitch offset upper bound
    ///   - rollLowerBound: new roll offset lower bound
    ///   - roll: new roll offset value
    ///   - rollUpperBound: new roll offset upper bound
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(yawLowerBound: Double, yaw: Double, yawUpperBound: Double,
                                          pitchLowerBound: Double, pitch: Double, pitchUpperBound: Double,
                                          rollLowerBound: Double, roll: Double, rollUpperBound: Double) -> CameraCore {
        if _alignment == nil {
            _alignment = CameraAlignmentCore(backend: self, didChangeDelegate: self)
            if isActive {
                markChanged()
            }
        }
        if _alignment!.update(yawLowerBound: yawLowerBound, yaw: yaw, yawUpperBound: yawUpperBound) {
            if isActive {
                markChanged()
            }
        }
        if _alignment!.update(pitchLowerBound: pitchLowerBound, pitch: pitch, pitchUpperBound: pitchUpperBound) {
            if isActive {
                markChanged()
            }
        }
        if _alignment!.update(rollLowerBound: rollLowerBound, roll: roll, rollUpperBound: rollUpperBound) {
            if isActive {
                markChanged()
            }
        }
        return self
    }

    /// Cancels all pending settings rollbacks.
    ///
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func cancelSettingsRollback() -> CameraCore {
        _modeSetting.cancelRollback { markChanged() }
        _exposureSettings.cancelRollback { markChanged() }
        _exposureLock?.cancelRollback { markChanged() }
        _exposureCompensationSetting.cancelRollback { markChanged() }
        _whiteBalanceSettings.cancelRollback { markChanged() }
        _styleSettings.cancelRollback { markChanged() }
        _recordingSettings.cancelRollback { markChanged() }
        _photoSettings.cancelRollback { markChanged() }
        _autoRecordSetting?.cancelRollback { markChanged() }
        _hdrSetting?.cancelRollback { markChanged() }
        _zoom?.cancelSettingsRollback { markChanged() }
        _whiteBalanceLock?.cancelRollback { markChanged() }
        _alignment?.cancelRollback { markChanged() }
        return self
    }
}

// MARK: - CameraZoomBackend
/// Camera zoom backend implementation
extension CameraCore: CameraZoomBackend {
    func set(maxZoomSpeed: Double) -> Bool {
        return backend.set(maxZoomSpeed: maxZoomSpeed)
    }

    func set(qualityDegradationAllowance: Bool) -> Bool {
        return backend.set(qualityDegradationAllowance: qualityDegradationAllowance)
    }

    func control(mode: CameraZoomControlMode, target: Double) {
        backend.control(mode: mode, target: target)
    }
}

// MARK: - CameraAlignmentBackend
/// Camera alignment backend implementation
extension CameraCore: CameraAlignmentBackend {
    func set(yawOffset: Double, pitchOffset: Double, rollOffset: Double) -> Bool {
        return backend.set(yawOffset: yawOffset, pitchOffset: pitchOffset, rollOffset: rollOffset)
    }

    func resetAlignment() -> Bool {
        return backend.resetAlignment()
    }
}
