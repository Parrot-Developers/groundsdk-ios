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

/// Photo modes.
@objc(GSCameraPhotoMode)
public enum CameraPhotoMode: Int, CustomStringConvertible {
    /// Photo mode that allows to take a single photo.
    case single
    /// Photo mode that allows to take a burst of multiple photos, each using different EV compensation values.
    case bracketing
    /// Photo mode that allows to take a burst of photos.
    case burst
    /// Photo mode that allows to take frames at a regular time interval.
    case timeLapse
    /// Photo mode that allows to take frames at a regular GPS position interval.
    case gpsLapse

    /// Debug description.
    public var description: String {
        switch self {
        case .single:     return "single"
        case .bracketing: return "bracketing"
        case .burst:      return "burst"
        case .timeLapse:  return "timeLapse"
        case .gpsLapse:   return "gpsLapse"
        }
    }

    /// Set containing all possible values.
    public static let allCases: Set<CameraPhotoMode> = [.single, .bracketing, .burst]
}

/// Photo formats.
@objc(GSCameraPhotoFormat)
public enum CameraPhotoFormat: Int, Comparable, CustomStringConvertible {
    /// Uses a rectilinear projection, de-warped.
    case rectilinear
    /// Uses full sensor resolution, not de-warped.
    case fullFrame
    /// Uses a large projection, partially de-warped.
    case large

    /// Debug description.
    public var description: String {
        switch self {
        case .rectilinear: return "rectilinear"
        case .fullFrame:   return "fullFrame"
        case .large:       return "large"
        }
    }

    /// Comparator.
    public static func < (lhs: CameraPhotoFormat, rhs: CameraPhotoFormat) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    /// Set containing all possible values.
    public static let allCases: Set<CameraPhotoFormat> = [.rectilinear, .fullFrame, .large]
}

/// Photo file formats.
@objc(GSCameraPhotoFileFormat)
public enum CameraPhotoFileFormat: Int, Comparable, CustomStringConvertible {
    /// Photo stored in JPEG format.
    case jpeg
    /// Photo stored in DNG format.
    case dng
    /// Photo stored in both DNG and JPEG formats.
    case dngAndJpeg

    /// Debug description.
    public var description: String {
        switch self {
        case .jpeg:       return "JPEG"
        case .dng:        return "DNG"
        case .dngAndJpeg: return "DNG & JPEG"
        }
    }

    /// Comparator.
    public static func < (lhs: CameraPhotoFileFormat, rhs: CameraPhotoFileFormat) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    /// Set containing all possible values.
    public static let allCases: Set<CameraPhotoFileFormat> = [.jpeg, .dng, .dngAndJpeg]
}

/// Burst value when photo mode is `burst`.
@objc(GSCameraBurstValue)
public enum CameraBurstValue: Int, CustomStringConvertible, Comparable {
    /// Takes 14 different photos regularly over 4 seconds.
    @objc(GSCameraBurst14Over4s)
    case burst14Over4s
    /// Takes 14 different photos regularly over 2 seconds.
    @objc(GSCameraBurst14Over2s)
    case burst14Over2s
    /// Takes 14 different photos regularly over 1 seconds.
    @objc(GSCameraBurst14Over1s)
    case burst14Over1s
    /// Takes 10 different photos regularly over 4 seconds.
    @objc(GSCameraBurst10Over4s)
    case burst10Over4s
    /// Takes 10 different photos regularly over 2 seconds.
    @objc(GSCameraBurst10Over2s)
    case burst10Over2s
    /// Takes 10 different photos regularly over 1 seconds.
    @objc(GSCameraBurst10Over1s)
    case burst10Over1s
    /// Takes 4 different photos regularly over 4 seconds.
    @objc(GSCameraBurst4Over4s)
    case burst4Over4s
    /// Takes 4 different photos regularly over 3 seconds.
    @objc(GSCameraBurst4Over2s)
    case burst4Over2s
    /// Takes 4 different photos regularly over 1 seconds.
    @objc(GSCameraBurst4Over1s)
    case burst4Over1s

    /// Debug description.
    public var description: String {
        switch self {
        case .burst14Over4s: return "14 Over 4s"
        case .burst14Over2s: return "14 Over 2s"
        case .burst14Over1s: return "14 Over 1s"
        case .burst10Over4s: return "10 Over 4s"
        case .burst10Over2s: return "10 Over 2s"
        case .burst10Over1s: return "10 Over 1s"
        case .burst4Over4s:  return "4 Over 4s"
        case .burst4Over2s:  return "4 Over 3s"
        case .burst4Over1s:  return "4 Over 1s"
        }
    }

    /// Comparator.
    public static func < (lhs: CameraBurstValue, rhs: CameraBurstValue) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    /// Set containing all possible values.
    public static let allCases: Set<CameraBurstValue> = [
        .burst14Over4s, .burst14Over2s, .burst14Over1s, .burst10Over4s, .burst10Over2s, .burst10Over1s,
        .burst4Over4s, .burst4Over2s, .burst4Over1s]
}

/// Bracketing value when photo mode is `bracketing`.
@objc(GSCameraBracketingPreset)
public enum CameraBracketingValue: Int, CustomStringConvertible, Comparable {
    /// Takes 3 pictures applying, in order, -1 EV, 0 EV and +1 EV exposure compensation values.
    @objc(GSCameraBracketingPreset1ev)
    case preset1ev
    /// Takes 3 pictures applying, in order, -2 EV, 0 EV and +2 EV exposure compensation values.
    @objc(GSCameraBracketingPreset2ev)
    case preset2ev
    /// Takes 3 pictures applying, in order, -3 EV, 0 EV and +3 EV exposure compensation values.
    @objc(GSCameraBracketingPreset3ev)
    case preset3ev
    /// Takes 5 pictures applying, in order, -2 EV, -1 EV, 0 EV, +1 EV, and +2 EV exposure compensation values.
    @objc(GSCameraBracketingPreset1ev2ev)
    case preset1ev2ev
    /// Takes 5 pictures applying, in order, -3 EV, -1 EV, 0 EV, +1 EV, and +3 EV exposure compensation values.
    @objc(GSCameraBracketingPreset1ev3ev)
    case preset1ev3ev
    /// Takes 5 pictures applying, in order, -3 EV, -2 EV, 0 EV, +2 EV, and +3 EV exposure compensation values.
    @objc(GSCameraBracketingPreset2ev3ev)
    case preset2ev3ev
    /// Takes 7 pictures applying, in order, -3 EV, -2 EV, -1 EV, 0 EV, +1 EV, +2 EV, and +3 EV exposure
    /// compensation values.
    @objc(GSCameraBracketingPreset1ev2ev3ev)
    case preset1ev2ev3ev

    /// Debug description.
    public var description: String {
        switch self {
        case .preset1ev:        return "preset1ev"
        case .preset2ev:        return "preset2ev"
        case .preset3ev:        return "preset3ev"
        case .preset1ev2ev:     return "preset1ev2ev"
        case .preset1ev3ev:     return "preset1ev3ev"
        case .preset2ev3ev:     return "preset2ev3ev"
        case .preset1ev2ev3ev:  return "preset1ev2ev3ev"
        }
    }

    /// Comparator.
    public static func < (lhs: CameraBracketingValue, rhs: CameraBracketingValue) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    /// Set containing all possible values.
    public static let allCases: Set<CameraBracketingValue> = [
        .preset1ev, .preset2ev, .preset3ev, .preset1ev2ev, .preset1ev3ev, .preset2ev3ev, .preset1ev2ev3ev]
}

/// Camera photo function state.
@objc(GSCameraPhotoFunctionState)
public enum CameraPhotoFunctionState: Int, CustomStringConvertible {
    /// Camera photo function is inoperable at present.
    /// When entering this state latest saved media id is reset to nil and current taken photo count is reset to 0
    case unavailable

    /// Camera photo function is ready to be operated.
    case stopped

    /// Camera is currently taking a photo.
    /// This state is entered after a successful call to `takePhoto()`, or if the application connects to a drone
    /// while the latter is currently taking photo(s).
    case started

    /// Photo could not be saved due to insufficient storage space on the drone.
    /// This state is entered when taking photo(s) fails for the aforementioned reason, and is transient:
    /// state switches back to `ready` immediately after.
    case errorInsufficientStorageSpace

    /// Photo could not be saved due to an internal error.
    /// Warning: this state can be temporary, and can be quickly followed by the state .ready or .unavailable.
    case errorInternal

    /// Photo capture is stopping.
    /// This state is entered from taking photo(s) after a call from stopPhotoCapture.
    case stopping

    /// Debug description.
    public var description: String {
        switch self {
        case .unavailable:                   return "unavailable"
        case .stopped:                       return "stopped"
        case .started:                       return "started"
        case .errorInsufficientStorageSpace: return "errorInsufficientStorageSpace"
        case .errorInternal:                 return "errorInternal"
        case .stopping:                      return "stopping"
        }
    }
}

/// Camera photo setting.
///
/// Allows to configure the camera photo mode and parameters, such as:
/// - Photo format,
/// - Photo file format,
/// - Burst value (for {@link Mode#BURST burst mode},
/// - Bracketing value (for {@link Mode#BRACKETING bracketing mode}.
public protocol CameraPhotoSettings: class {
    /// Tells if a setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Supported photo modes.
    /// An empty set means that the whole setting is currently unsupported.
    var supportedModes: Set<CameraPhotoMode> { get }

    /// Supported photo format in the current mode.
    var supportedFormats: Set<CameraPhotoFormat> { get }

    /// Supported file formats in the current mode.
    var supportedFileFormats: Set<CameraPhotoFileFormat> { get }

    /// Supported burst values when mode is `burst`.
    var supportedBurstValues: Set<CameraBurstValue> { get }

    /// Supported bracketing values when mode is `burst`.
    var supportedBracketingValues: Set<CameraBracketingValue> { get }

    /// Whether HDR is available in the current mode, format and file format
    var hdrAvailable: Bool { get }

    /// Photo mode.
    /// Value should be considered meaningless in case the set of `supportedModes` is empty.
    var mode: CameraPhotoMode { get set }

    /// Photo format.
    var format: CameraPhotoFormat { get set }

    /// Photo file format.
    var fileFormat: CameraPhotoFileFormat { get set }

    /// Burst value when mode is `burst`.
    var burstValue: CameraBurstValue { get set }

    /// Bracketing value when mode is `bracketing`.
    var bracketingValue: CameraBracketingValue { get set }

    /// Current time-lapse interval value (in seconds) when the photo mode is time_lapse.
    /// Ignored in other modes.
    var timelapseCaptureInterval: Double { get set }

    /// Current GPS-lapse interval value (in meters) when the photo mode is gps_lapse.
    /// Ignored in other modes.
    var gpslapseCaptureInterval: Double { get set }

    /// Range of supported timelapseInterval.
    var supportedTimelapseIntervals: ClosedRange<Double> { get }

    /// Range of supported gpslapseInterval.
    var supportedGpslapseIntervals: ClosedRange<Double> { get }

    /// Gets supported photo formats for a specific photo mode.
    ///
    /// - Parameter mode: the photo mode
    /// - Returns: supported photo formats for the mode
    func supportedFormats(forMode mode: CameraPhotoMode) -> Set<CameraPhotoFormat>

    /// Gets supported photo file formats for a specific photo mode and format.
    ///
    /// - Parameters:
    ///   - mode: photo mode
    ///   - format: the photo format
    /// - Returns: supported photo file formats for specified mode and format
    func supportedFileFormats(forMode mode: CameraPhotoMode, format: CameraPhotoFormat) -> Set<CameraPhotoFileFormat>

    /// Tells whether HDR is available for specific mode, format and file format.
    ///
    /// - Parameters:
    ///   - mode: the photo mode
    ///   - format: the photo format
    ///   - fileFormat: the photo file format
    /// - Returns: `true` if hdr is supported in the given mode, format and file format
    func hdrAvailable(forMode mode: CameraPhotoMode, format: CameraPhotoFormat, fileFormat: CameraPhotoFileFormat)
        -> Bool

    /// Changes photo mode, format, file format, burst and bracketing values.
    ///
    /// - Parameters:
    ///   - mode: photo mode
    ///   - format: photo format
    ///   - fileFormat: photo file format
    ///   - burstValue: burst value when photo mode is `burst`
    ///   - bracketingValue: bracketing value when photo mode is `bracketing`
    ///   - captureInterval: capture interval
    /// Current time-lapse interval value (in seconds) when the photo mode is time_lapse.
    /// Current GPS-lapse interval value (in meters) when the photo mode is gps_lapse.
    /// Ignored in other modes.
    func set(mode: CameraPhotoMode, format: CameraPhotoFormat, fileFormat: CameraPhotoFileFormat,
             burstValue: CameraBurstValue?, bracketingValue: CameraBracketingValue?,
             gpslapseCaptureIntervalValue: Double?, timelapseCaptureIntervalValue: Double?)
}

/// State of the camera photo function.
@objc(GSCameraPhotoState)
public protocol CameraPhotoState {
    /// Current camera photo function state.
    var functionState: CameraPhotoFunctionState { get }

    /// Number of photo taken in the session (useful for burst and hyperlapse),
    /// valid when functionState is `takingPhotos`.
    var photoCount: Int { get }

    /// Identifier of the latest saved photo media.
    /// Available when functionState `ready` and when some photo were taken beforehand during the same connected
    /// session with the drone.
    var mediaId: String? { get }
}

// MARK: - objc compatibility

/// Settings to configure photo mode and options
/// - Note: This protocol is for Objective-C compatibility only.
@objc public protocol GSCameraPhotoSettings {
    /// Tells if a setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Photo mode.
    var mode: CameraPhotoMode { get set }

    /// Photo format.
    var format: CameraPhotoFormat { get set }

    /// Photo file format.
    var fileFormat: CameraPhotoFileFormat { get set }

    /// Burst value when mode is `burst`.
    var burstValue: CameraBurstValue { get set }

    /// Bracketing value when mode is `bracketing`.
    var bracketingValue: CameraBracketingValue { get set }

    /// Whether HDR is available in the current mode, format and file format.
    var hdrAvailable: Bool { get }

    /// Current time-lapse interval value (in seconds) when the photo mode is time_lapse.
    /// Ignored in other modes.
    var timelapseCaptureInterval: Double { get set }

    /// Current GPS-lapse interval value (in meters) when the photo mode is gps_lapse.
    /// Ignored in other modes.
    var gpslapseCaptureInterval: Double { get set}

    /// Minimum supported timelapseInterval.
    var gsMinSupportedTimelapseIntervals: Double { get }

    /// Maximum supported timelapseInterval.
    var gsMaxSupportedTimelapseIntervals: Double { get }

    /// Minimum supported gpslapseInterval.
    var gsMinSupportedGpslapseIntervals: Double { get }

    /// Maximum supported gpslapseInterval.
    var gsMaxSupportedGpslapseIntervals: Double { get }

    /// Checks if a photo mode is supported.
    ///
    /// - Parameter mode: mode to check
    /// - Returns: `true` if the mode is supported
    func isModeSupported(_ mode: CameraPhotoMode) -> Bool

    /// Checks if a photo format is supported in the current mode.
    ///
    /// - Parameter format: photo format to check
    /// - Returns: `true` if the photo format is supported in the current mode
    func isFormatSupported(_ format: CameraPhotoFormat) -> Bool

    /// Checks if a photo format is supported in a specific mode.
    ///
    /// - Parameters:
    ///   - mode: mode to check if a photo format is supported
    ///   - format: photo format to check
    /// - Returns: `true` if the photo format is supported in specified mode
    func isFormatSupported(_ format: CameraPhotoFormat, forMode mode: CameraPhotoMode) -> Bool

    /// Checks if a photo file format is supported in the current mode.
    ///
    /// - Parameter fileformat: file format to check
    /// - Returns: `true` if the file format is supported in the current mode
    func isFileFormatSupported(_ fileformat: CameraPhotoFileFormat) -> Bool

    /// Checks if a photo file format is supported in a specific photo mode and format.
    ///
    /// - Parameters:
    ///   - mode: mode to check if a photo format is supported
    ///   - photoFormat: photo format to check if a file format is supported
    ///   - fileFormat: file format to check
    /// - Returns: `true` if the file format is supported in specified mode and format
    func isFileFormatSupported(_ fileformat: CameraPhotoFileFormat, forPhotoMode: CameraPhotoMode,
                               andPhotoFormat photoFormat: CameraPhotoFormat) -> Bool

    /// Checks if a burst value is supported.
    ///
    /// - Parameter burstValue: burst value to check
    /// - Returns: `true` if the burst value is supported
    func isBurstValueSupported(_ burstValue: CameraBurstValue) -> Bool

    /// Checks if a bracketing value is supported.
    ///
    /// - Parameter bracketingValue: bracketing value to check
    /// - Returns: `true` if the bracketing value is supported
    func isBracketingValueSupported(_ bracketingValue: CameraBracketingValue) -> Bool

    /// Tells whether HDR is available for specific mode, format and file format.
    ///
    /// - Parameters:
    ///   - mode: the photo mode
    ///   - format: the photo format
    ///   - fileFormat: the photo file format
    /// - Returns: `true` if hdr is available in the given mode, format and file format
    @objc(isHdrAvailableForMode:format:fileFormat:)
    func hdrAvailable(forMode mode: CameraPhotoMode, format: CameraPhotoFormat, fileFormat: CameraPhotoFileFormat)
        -> Bool

    /// Changes photo mode, format, file format, burst and bracketing value.
    ///
    /// - Parameters:
    ///   - mode: photo mode
    ///   - format: photo format
    ///   - fileFormat: photo file format,
    ///   - burstValue: burst value when photo mode is `burst`, -1 to keep current burst value
    ///   - bracketingValue: bracketing value when photo mode is `bracketing`, -1 to keep current bracketing value
    ///   - captureInterval: capture interval
    /// Current time-lapse interval value (in seconds) when the photo mode is time_lapse.
    /// Current GPS-lapse interval value (in meters) when the photo mode is gps_lapse.
    /// Ignored in other modes.
    @objc(setMode:format:fileformat:burstValue:bracketingValue:gpslapseCaptureIntervalValue:
    timelapseCaptureIntervalValue:)
    func gsSet(mode: CameraPhotoMode, format: CameraPhotoFormat, fileFormat: CameraPhotoFileFormat,
               burstValue: Int, bracketingValue: Int, gpslapseCaptureIntervalValue: Double,
               timelapseCaptureIntervalValue: Double)
}
