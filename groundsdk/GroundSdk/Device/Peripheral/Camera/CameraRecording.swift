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

/// Camera recording modes.
@objc(GSCameraRecordingMode)
public enum CameraRecordingMode: Int, CustomStringConvertible {
    /// Standard recording mode.
    case standard
    /// Records accelerated videos. Records 1 of n frames.
    case hyperlapse
    /// Records slowed down videos.
    case slowMotion
    /// Record high-framerate videos (playback speed is x1).
    case highFramerate

    /// Debug description.
    public var description: String {
        switch self {
        case .standard:       return "standard"
        case .hyperlapse:     return "hyperlapse"
        case .slowMotion:     return "slowMotion"
        case .highFramerate:  return "highFramerate"
        }
    }

    /// Set containing all possible values.
    public static let allCases: Set<CameraRecordingMode> = [.standard, .hyperlapse, .slowMotion, .highFramerate]
}

/// Camera recording resolutions.
@objc(GSCameraRecordingResolution)
public enum CameraRecordingResolution: Int, CustomStringConvertible, Comparable {
    /// 4096x2160 pixels (4k cinema)
    @objc(GSCameraRecordingResolutionDci4k)
    case resDci4k
    /// 3840x2160 pixels (UHD)
    @objc(GSCameraRecordingResolutionUhd4k)
    case resUhd4k
    /// 2704x1524 pixels
    @objc(GSCameraRecordingResolution2_7k)
    case res2_7k
    /// 1920x1080 pixels (Full HD)
    @objc(GSCameraRecordingResolution1080p)
    case res1080p
    /// 1440x1080 pixels (SD)
    @objc(GSCameraRecordingResolution1080pSd)
    case res1080pSd
    /// 1280x720 pixels (HD)
    @objc(GSCameraRecordingResolution720p)
    case res720p
    /// 1280x720 pixels (SD)
    @objc(GSCameraRecordingResolution720pSd)
    case res720pSd
    /// 856x480 pixels
    @objc(GSCameraRecordingResolution480p)
    case res480p

    /// Comparator.
    public static func < (lhs: CameraRecordingResolution, rhs: CameraRecordingResolution) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    /// Debug description.
    public var description: String {
        switch self {
        case .resDci4k:     return "DCI 4k"
        case .resUhd4k:     return "UHD 4k"
        case .res2_7k:      return "2.7k"
        case .res1080p:     return "1080p"
        case .res1080pSd:   return "1080pSd"
        case .res720p:      return "720p"
        case .res720pSd:    return "720pSd"
        case .res480p:      return "480p"
        }
    }

    /// Set containing all possible values.
    public static let allCases: Set<CameraRecordingResolution> = [
        .resDci4k, .resUhd4k, .res2_7k, .res1080p, .res1080pSd, .res720p, .res720pSd, .res480p]
}

/// Camera recording frame rates.
@objc(GSCameraRecordingFramerate)
public enum CameraRecordingFramerate: Int, CustomStringConvertible, Comparable {
    /// 9 fps - For thermal only, capture triggered by thermal sensor.
    @objc(GSCameraRecordingFramerate9)
    case fps9
    /// 15 fps.
    @objc(GSCameraRecordingFramerate15)
    case fps15
    /// 20 fps.
    @objc(GSCameraRecordingFramerate20)
    case fps20
    /// 23.97 fps.
    @objc(GSCameraRecordingFramerate24)
    case fps24
    /// 25 fps.
    @objc(GSCameraRecordingFramerate25)
    case fps25
    /// 29.97 fps.
    @objc(GSCameraRecordingFramerate30)
    case fps30
    /// 48 fps.
    @objc(GSCameraRecordingFramerate48)
    case fps48
    /// 50 fps.
    @objc(GSCameraRecordingFramerate50)
    case fps50
    /// 59.94 fps.
    @objc(GSCameraRecordingFramerate60)
    case fps60
    /// 95.88 fps.
    @objc(GSCameraRecordingFramerate96)
    case fps96
    /// 100 fps.
    @objc(GSCameraRecordingFramerate100)
    case fps100
    /// 120 fps.
    @objc(GSCameraRecordingFramerate120)
    case fps120
    /// 191.81 fps.
    @objc(GSCameraRecordingFramerate192)
    case fps192
    /// 200 fps.
    @objc(GSCameraRecordingFramerate200)
    case fps200
    /// 239.76 fps.
    @objc(GSCameraRecordingFramerate240)
    case fps240

    /// Comparator.
    public static func < (lhs: CameraRecordingFramerate, rhs: CameraRecordingFramerate) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    /// Debug description.
    public var description: String {
        switch self {
        case .fps9:     return "9"
        case .fps15:    return "15"
        case .fps20:    return "20"
        case .fps24:    return "24"
        case .fps25:    return "25"
        case .fps30:    return "30"
        case .fps48:    return "48"
        case .fps50:    return "50"
        case .fps60:    return "60"
        case .fps96:    return "96"
        case .fps100:   return "100"
        case .fps120:   return "120"
        case .fps192:   return "192"
        case .fps200:   return "200"
        case .fps240:   return "240"
        }
    }

    /// Set containing all possible values.
    public static let allCases: Set<CameraRecordingFramerate> = [
        .fps9, .fps15, .fps20, .fps24, .fps25, .fps30, .fps48, .fps50, .fps60, .fps96, .fps100, .fps120, .fps192,
        .fps200, .fps240]
}

/// Camera hyperlapse values for recording mode `hyperlapse`.
@objc(GSCameraHyperlapseValue)
public enum CameraHyperlapseValue: Int, CustomStringConvertible, Comparable {
    /// Record 1 of 15 frames.
    case ratio15
    /// Record 1 of 30 frames.
    case ratio30
    /// Record 1 of 60 frames.
    case ratio60
    /// Record 1 of 120 frames.
    case ratio120
    /// Record 1 of 240 frames.
    case ratio240

    /// Comparator.
    public static func < (lhs: CameraHyperlapseValue, rhs: CameraHyperlapseValue) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    /// Debug description.
    public var description: String {
        switch self {
        case .ratio15:  return "1/15"
        case .ratio30:  return "1/30"
        case .ratio60:  return "1/60"
        case .ratio120:  return "1/120"
        case .ratio240:  return "1/240"
        }
    }

    /// Set containing all possible values.
    public static let allCases: Set<CameraHyperlapseValue> = [
        .ratio15, .ratio30, .ratio60, .ratio120, .ratio240]
}

/// Camera recording function state.
@objc(GSCameraRecordingFunctionState)
public enum CameraRecordingFunctionState: Int, CustomStringConvertible {
    /// Camera video record function is inoperable at present.
    /// When entering this state latest saved media id and startTime are reset to nil.
    case unavailable

    /// Video record is stopped and ready to be started.
    case stopped

    /// Video record is starting.
    /// This state is entered from `stopped` after a call to `startRecording()`.
    case starting

    /// Camera is currently recording a video.
    case started

    /// Video record is stopping.
    case stopping

    /// Video record auto stopped because of internal reconfiguration.
    /// This state is transient: state switches back to `stopped` immediately after.
    case stoppedForReconfiguration

    /// Video record has stopped due to insufficient storage space on the drone.
    /// This state is  transient: state switches back to `stopped` immediately after.
    case errorInsufficientStorageSpace

    /// Video record has stopped because storage is too slow.
    /// This state is  transient: state switches back to `stopped` immediately after.
    case errorInsufficientStorageSpeed

    /// Video record has stopped due to an internal error.
    /// Warning: this state can be temporary, and can be quickly followed by the state .stopped or .unavailable.
    case errorInternal

    /// Debug description.
    public var description: String {
        switch self {
        case .unavailable:                   return "unavailable"
        case .stopped:                       return "stopped"
        case .starting:                      return "starting"
        case .started:                       return "started"
        case .stopping:                      return "stopping"
        case .stoppedForReconfiguration:     return "stoppedForReconfiguration"
        case .errorInsufficientStorageSpace: return "errorInsufficientStorageSpace"
        case .errorInsufficientStorageSpeed: return "errorInsufficientStorageSpeed"
        case .errorInternal:                 return "errorInternal"
        }
    }

    /// Tells if it's one of the stopped case.
    var isStopped: Bool {
        switch self {
        case .stopped, .errorInsufficientStorageSpace, .errorInsufficientStorageSpeed, .errorInternal,
             .stoppedForReconfiguration:
            return true
        default: return false
        }
    }
}

/// Camera recording setting.
///
///  Allows to configure the camera recording mode and parameters, such as:
/// - Recording resolution,
/// - Recording framerate,
/// - Hyperalpse value for hyperlapse mode.
public protocol CameraRecordingSettings: class {
    /// Tells if a setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Supported recording modes.
    var supportedModes: Set<CameraRecordingMode> { get }

    /// Supported recording resolutions in the current mode.
    var supportedResolutions: Set<CameraRecordingResolution> { get }

    /// Supported recording resolutions in the current mode.
    var supportedFramerates: Set<CameraRecordingFramerate> { get }

    /// Supported Hyperlapse values when mode is `hyperlapse`.
    var supportedHyperlapseValues: Set<CameraHyperlapseValue> { get }

    /// Recording mode.
    var mode: CameraRecordingMode { get set }

    /// Recording resolution.
    var resolution: CameraRecordingResolution { get set }

    /// Recording framerate.
    var framerate: CameraRecordingFramerate { get set }

    /// Hyperlapse values when mode is `hyperlapse`.
    var hyperlapseValue: CameraHyperlapseValue { get set }

    /// Whether HDR is available in the current mode, resolution and framerate.
    var hdrAvailable: Bool { get }

    /// Recoding bitrate for current configuration, in bit/s. Zero if unknown.
    var bitrate: UInt { get }

    /// Gets supported recording resolutions for a specific recording mode.
    ///
    /// - Parameter mode: the recording mode
    /// - Returns: supported recording resolutions for the mode
    func supportedResolutions(forMode mode: CameraRecordingMode) -> Set<CameraRecordingResolution>

    /// Gets supported recording framerates for a specific recording mode and resolution.
    ///
    /// - Parameters:
    ///   - mode: the recording mode
    ///   - resolution: the recording resolution
    /// - Returns: supported recording resolutions for the mode and resolution
    func supportedFramerates(forMode mode: CameraRecordingMode, resolution: CameraRecordingResolution)
        -> Set<CameraRecordingFramerate>

    /// Tells whether HDR is available for specific mode, framerate and resolution.
    ///
    /// - Parameters:
    ///   - mode: the recording mode
    ///   - resolution: the recording resolution
    ///   - framerate: the recording framerate
    /// - Returns: `true` if hdr is available in the given mode, resolution and framerate
    func hdrAvailable(
        forMode mode: CameraRecordingMode, resolution: CameraRecordingResolution, framerate: CameraRecordingFramerate)
        -> Bool

    /// Sets recording mode, resolution, framerate and hyperlase values.
    ///
    /// - Parameters:
    ///   - mode: requested mode
    ///   - resolution: requested resolution
    ///   - framerate: requested framerate
    ///   - hyperlapseValue: requested hyperlapse value when mode is `hyperlapse`
    func set(mode: CameraRecordingMode, resolution: CameraRecordingResolution, framerate: CameraRecordingFramerate,
             hyperlapseValue: CameraHyperlapseValue?)
}

/// Recording progress event.
@objc(GSCameraRecordingState)
public protocol CameraRecordingState {
    /// Current camera recording function state.
    var functionState: CameraRecordingFunctionState { get }

    /// Recording start time, when functionState is `started`.
    var startTime: Date? { get }

    /// Media id, when latestEvent is `stopped` or one of the error state.
    var mediaId: String? { get }

    /// Gets current recording duration.
    ///
    /// - Returns: current recording duration or 0 when recording is not started
    func getDuration() -> TimeInterval
}

// MARK: - objc compatibility

/// Settings to configure recording mode and options
/// - Note: This protocol is for Objective-C compatibility only.
@objc public protocol GSCameraRecordingSettings {
    /// Tells if a setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Recording mode.
    var mode: CameraRecordingMode { get set }

    /// Recording resolution.
    var resolution: CameraRecordingResolution { get set }

    /// Recording framerate.
    var framerate: CameraRecordingFramerate { get }

    /// Hyperlapse values when mode is `hyperlapse`.
    var hyperlapseValue: CameraHyperlapseValue { get }

    /// Whether HDR is available in the current mode, resolution and framerate.
    var hdrAvailable: Bool { get }

    /// Checks if a recording mode is supported.
    ///
    /// - Parameter mode: mode to check
    /// - Returns: `true` if the mode is supported
    func isModeSupported(_ mode: CameraRecordingMode) -> Bool

    /// Checks if a resolution is supported in the current mode.
    ///
    /// - Parameter resolution: resolution to check
    /// - Returns: `true` if the resolution is supported in the current mode
    func isResolutionSupported(_ resolution: CameraRecordingResolution) -> Bool

    /// Checks if a resolution is supported in a specific mode.
    ///
    /// - Parameters:
    ///   - mode: mode to check if a resolution is supported
    ///   - resolution: resolution to check
    /// - Returns: `true` if the resolution is supported in the specified mode
    func isResolutionSupported(_ resolution: CameraRecordingResolution, forMode mode: CameraRecordingMode) -> Bool

    /// Checks if a framerate is supported in the current mode.
    ///
    /// - Parameter framerate: framerate to check
    /// - Returns: `true` if the framerate is supported in the current mode
    func isFramerateSupported(_ framerate: CameraRecordingFramerate) -> Bool

    /// Checks if a framerate is supported in a specific mode and resolution.
    ///
    /// - Parameters:
    ///   - mode: mode to check if a framerate is supported
    ///   - framerate: framerate to check
    ///   - resolution: resolution to check
    /// - Returns: `true` if the framerate is supported in the specified mode
    func isFramerateSupported(_ framerate: CameraRecordingFramerate, forMode mode: CameraRecordingMode,
                              andResolution resolution: CameraRecordingResolution) -> Bool

    /// Tells whether HDR is available for specific mode, framerate and resolution.
    ///
    /// - Parameters:
    ///   - mode: the recording mode
    ///   - resolution: the recording resolution
    ///   - framerate: the recording framerate
    /// - Returns: `true` if hdr is available in the given mode, resolution and framerate
    @objc(isHdrAvailableForMode:resolution:framerate:)
    func hdrAvailable(
        forMode mode: CameraRecordingMode, resolution: CameraRecordingResolution, framerate: CameraRecordingFramerate)
        -> Bool

    /// Checks if a hyperlapse value is supported.
    ///
    /// - Parameter hyperlapseValue: hyperlapse value to check
    /// - Returns: `true` if the hyperlapse value is supported
    func isHyperlapseValueSupported(_ hyperlapseValue: CameraHyperlapseValue) -> Bool

    /// Changes recording mode, resolution, framerate and hyperlapse values.
    ///
    /// - Parameters:
    ///   - mode: requested recording mode
    ///   - resolution: requested recording resolution
    ///   - framerate: requested recording framerate
    ///   - hyperlapseValue: requested hyperlapse value, -1 to keep the current value
    @objc(setMode:resolution:framerate:hyperlapseValue:)
    func gsSet(mode: CameraRecordingMode, resolution: CameraRecordingResolution, framerate: CameraRecordingFramerate,
               hyperlapseValue: Int)
}
