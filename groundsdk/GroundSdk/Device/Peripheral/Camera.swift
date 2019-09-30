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

/// Camera protocol.
///
/// Provides access to the device's camera in order to take pictures and to record videos.
/// Also provides access to various camera settings, such as:
/// - Exposure,
/// - EV compensation,
/// - White balance,
/// - Recording mode, resolution and framerate selection,
/// - Photo mode, format and file format selection.
public protocol Camera {

    /// Whether the camera is active.
    /// This state may change depending on the current mode of the drone. For example the activation / deactivation of
    /// the thermal mode can activate / deactivate some cameras.
    var isActive: Bool { get }

    /// Camera mode setting.
    /// This setting allows to change the camera's current operating mode.
    var modeSetting: CameraModeSetting { get }

    /// Camera exposure settings.
    /// This setting allows to configure the camera's current exposure mode, shutter speed, iso sensitivity and
    /// maximum iso sensitivity
    var exposureSettings: CameraExposureSettings { get }

    /// Camera EV (Exposure Value) compensation setting.
    /// This setting allows to configure the camera's current ev compensation when current exposure mode in not
    /// `.manual`.
    /// - Note: This setting is only available when exposure mode is `.manual`.
    var exposureCompensationSetting: CameraExposureCompensationSetting { get }

    /// Camera white balance settings.
    /// This setting allows to configure the camera's current white balance mode and temperature parameters.
    var whiteBalanceSettings: CameraWhiteBalanceSettings { get }

    /// White balance lock.
    /// `nil` if white balance lock is not available or when device is not connected.
    var whiteBalanceLock: CameraWhiteBalanceLock? { get }

    /// HDR setting.
    /// Tell if HDR must be activated when available in current recording/photo setting.
    /// `nil` if HDR is not supported by this camera.
    var hdrSetting: BoolSetting? { get }

    /// Camera image styles settings.
    /// This setting allows to select and customize the current image style.
    /// - Note: This setting is only available when the drone is connected.
    var styleSettings: CameraStyleSettings { get }

    /// Camera recording mode settings.
    /// These settings allow to configure the camera's recording mode, resolution and framerate parameters.
    var recordingSettings: CameraRecordingSettings { get }

    /// Camera photo mode settings.
    /// These settings allow to configure the camera's photo mode, format and file format parameters.
    var photoSettings: CameraPhotoSettings { get }

    /// Auto start and stop recording setting.
    /// When enabled, if the drone is in `.recording` mode, recording starts when taking-off and stops after landing.
    /// `nil` if auto-record is not supported by this camera.
    var autoRecordSetting: BoolSetting? { get }

    /// Exposure lock.
    /// `nil` if exposure lock is not available and when device is not connected.
    var exposureLock: CameraExposureLock? { get }

    /// Recording state.
    var recordingState: CameraRecordingState { get }

    /// Photo state.
    var photoState: CameraPhotoState { get }

    /// HDR state.
    /// Tell if HDR is currently active
    var hdrState: Bool { get }

    /// Whether HDR is available in the current mode and configuration.
    var hdrAvailable: Bool { get }

    /// Camera zoom.
    ///
    /// `nil` if zoom is not supported by this camera.
    var zoom: CameraZoom? { get }

    /// Camera alignment.
    /// `nil` if camera is not the active camera, if device is not connected or if alignment is not supported.
    var alignment: CameraAlignment? { get }

    /// Whether `startRecording` can be called.
    var canStartRecord: Bool { get }

    /// Whether `stopRecord` can be called.
    var canStopRecord: Bool { get }

    /// Whether `startPhotoCapture` can be called.
    var canStartPhotoCapture: Bool { get }

    /// Whether `stopPhotoCapture` can be called.
    var canStopPhotoCapture: Bool { get }

    /// Starts recording. Can be called when `recordingState.functionState` is `ready`.
    func startRecording()

    /// Stops recording. Can be called when `recordingState.functionState` is `inProgress`.
    func stopRecording()

    /// Starts taking photo(s). Can be called when `canStartPhotoCapture` is `true`.
    func startPhotoCapture()

    /// Stops taking photos(s). Can be called when `canStopPhotoCapture` is `true`.
    /// The command is only sent when `photoSettings.mode` is `gpslapse` or `timelapse`.
    func stopPhotoCapture()
}

// MARK: - objc compatibility

/// Camera protocol.
/// - Note: This protocol is for Objective-C compatibility only.
@objc public protocol GSCamera {

    /// Whether the camera is active.
    /// This state may change depending on the current mode of the drone. For example the activation / deactivation of
    /// the thermal mode can activate / deactivate some cameras.
    var isActive: Bool { get }

    /// Camera mode switcher, to select recording or photo mode if supported.
    @objc(modeSetting)
    var gsModeSetting: GSCameraModeSetting { get }

    /// Exposure settings.
    @objc(exposureSettings)
    var gsExposureSettings: GSCameraExposureSettings { get }

    /// Exposure compensation setting.
    @objc(exposureCompensationSetting)
    var gsExposureCompensationSetting: GSCameraExposureCompensationSetting { get }

    /// White balance settings.
    @objc(whiteBalanceSettings)
    var gsWhiteBalanceSettings: GSCameraWhiteBalanceSettings { get }

    /// White balance lock.
    /// `nil` if white balance lock is not available or when device is not connected.
    @objc(whiteBalanceLock)
    var gsWhiteBalanceLock: GSCameraWhiteBalanceLock? { get }

    /// HDR setting.
    /// Tells if HDR must be activated when available in current recording/photo setting.
    /// `nil` if HDR is not supported by this camera.
    var hdrSetting: BoolSetting? { get }

    /// Style settings.
    @objc(styleSettings)
    var gsStyleSettings: GSCameraStyleSettings { get }

    /// Settings when the camera is in recording mode.
    @objc(recordingSettings)
    var gsRecordingSettings: GSCameraRecordingSettings { get }

    /// Auto start and stop recording setting.
    /// When enabled, if the drone is in `.recording` mode, recording starts when taking-off and stops after landing.
    /// `nil` if auto-record is not supported by this camera.
    var autoRecordSetting: BoolSetting? { get }

    /// Settings when the camera is in photo mode.
    @objc(photoSettings)
    var gsPhotoSettings: GSCameraPhotoSettings { get }

    /// Exposure lock.
    /// `nil` if exposure lock is not available and when device is not connected.
    @objc(exposureLock)
    var gsExposureLock: GSCameraExposureLock? { get }

    /// HDR state.
    /// Tell if HDR is currently active.
    var hdrState: Bool { get }

    /// Camera zoom.
    ///
    /// `nil` if zoom is not supported by this camera.
    var zoom: CameraZoom? { get }

    /// Camera alignment.
    /// `nil` if camera is not the active camera, if device is not connected or if alignment is not supported.
    @objc(alignment)
    var gsAlignment: GSCameraAlignment? { get }

    /// Recording function state.
    var recordingState: CameraRecordingState { get }

    /// Photo state.
    var photoState: CameraPhotoState { get }

    /// Whether `startRecording` can be called.
    var canStartRecord: Bool { get }

    /// Whether `stopRecord` can be called.
    var canStopRecord: Bool { get }

    /// Whether `startPhotoCapture` can be called.
    var canStartPhotoCapture: Bool { get }

    /// Whether `stopPhotoCapture` can be called.
    var canStopPhotoCapture: Bool { get }

    /// Starts recording. Can be called when `recordingState.state` is `ready`.
    func startRecording()

    /// Stops recording. Can be called when `recordingState.state` is `inProgress`.
    func stopRecording()

    /// Starts taking photo(s). Can be called when `canStartPhotoCapture` is `true`.
    func startPhotoCapture()

    /// Stops taking photos(s). Can be called when `canStopPhotoCapture` is `true`.
    /// The command is only sent when `photoSettings.mode` is `gpslapse` or `timelapse`.
    func stopPhotoCapture()
}
