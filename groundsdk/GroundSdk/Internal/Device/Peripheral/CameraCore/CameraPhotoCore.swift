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

/// Core implementation of CameraPhotoSettings
class CameraPhotoSettingsCore: CameraPhotoSettings, CustomDebugStringConvertible {

    /// Delegate called when the setting value is changed by setting properties
    private unowned let didChangeDelegate: SettingChangeDelegate

    /// Timeout object.
    ///
    /// Visibility is internal for testing purposes
    let timeout = SettingTimeout()

    /// Tells if the setting value has been changed and is waiting for change confirmation
    var updating: Bool { return timeout.isScheduled }

    /// closure to call to change the value
    private let backend: (_ mode: CameraPhotoMode, _ format: CameraPhotoFormat?, _ fileFormat: CameraPhotoFileFormat?,
    _ burst: CameraBurstValue?, _ bracketing: CameraBracketingValue?, _ gpslapseCaptureInterval: Double?,
    _ timelapseCaptureInterval: Double?) -> Bool

    /// supported modes
    var supportedModes: Set<CameraPhotoMode> {
        return Set(capabilities.keys)
    }
    /// Supported photo format in the current mode
    var supportedFormats: Set<CameraPhotoFormat> {
        return supportedFormats(forMode: _mode)
    }

    /// Supported file formats in the current photo format
    var supportedFileFormats: Set<CameraPhotoFileFormat> {
        return supportedFileFormats(forMode: _mode, format: _format)
    }

    /// Mode, format, file format and hdr capabilities
    private var capabilities: [CameraPhotoMode: [CameraPhotoFormat: [CameraPhotoFileFormat: Bool]]] = [:]

    /// Supported burst values when mode is `burst`
    private(set) var supportedBurstValues = Set<CameraBurstValue>()

    /// Supported bracketing values when mode is `bracketing`
    private(set) var supportedBracketingValues = Set<CameraBracketingValue>()

    /// Is HDR available in the current mode, format and file format
    var hdrAvailable: Bool {
        return hdrAvailable(forMode: _mode, format: _format, fileFormat: _fileFormat)
    }

    /// Photo mode
    var mode: CameraPhotoMode {
        get {
            return _mode
        }
        set {
            if mode != newValue && supportedModes.contains(newValue) && backend(newValue, nil, nil, nil, nil, nil,
                                                                                nil) {
                let oldMode = _mode
                // value sent to the backend, update setting value and mark it updating
                _mode = newValue
                timeout.schedule { [weak self] in
                    if let `self` = self, self.update(mode: oldMode) {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
                didChangeDelegate.userDidChangeSetting()
            }
        }
    }
    private var _mode: CameraPhotoMode = .single

    /// Photo format
    var format: CameraPhotoFormat {
        get {
            return _format
        }
        set {
            if format != newValue && supportedFormats.contains(newValue) && backend(_mode, newValue,
                                                                                    nil, nil, nil, nil, nil) {
                let oldFormat = _format
                // value sent to the backend, update setting value and mark it updating
                _format = newValue
                timeout.schedule { [weak self] in
                    if let `self` = self, self.update(format: oldFormat) {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
                didChangeDelegate.userDidChangeSetting()
            }
        }
    }
    private var _format: CameraPhotoFormat = .rectilinear

    /// Photo file format
    var fileFormat: CameraPhotoFileFormat {
        get {
            return _fileFormat
        }
        set {
            if fileFormat != newValue && supportedFileFormats.contains(newValue) &&
                backend(_mode, nil, newValue, nil, nil, nil, nil) {

                let oldFileFormat = _fileFormat
                // value sent to the backend, update setting value and mark it updating
                _fileFormat = newValue
                timeout.schedule { [weak self] in
                    if let `self` = self, self.update(fileFormat: oldFileFormat) {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
                didChangeDelegate.userDidChangeSetting()
            }
        }
    }
    private var _fileFormat: CameraPhotoFileFormat = .jpeg

    /// Burst value when mode is `burst`
    var burstValue: CameraBurstValue {
        get {
            return _burst
        }
        set {
            if burstValue != newValue && supportedBurstValues.contains(newValue) &&
                backend(_mode, nil, nil, newValue, nil, nil, nil) {

                let oldBurstValue = _burst
                // value sent to the backend, update setting value and mark it updating
                _burst = newValue
                timeout.schedule { [weak self] in
                    if let `self` = self, self.update(burstValue: oldBurstValue) {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
                didChangeDelegate.userDidChangeSetting()
            }
        }
    }
    private var _burst: CameraBurstValue = .burst14Over4s

    /// Bracketing value when mode is `bracketing`
    var bracketingValue: CameraBracketingValue {
        get {
            return _bracketing
        }
        set {
            if bracketingValue != newValue && supportedBracketingValues.contains(newValue) &&
                backend(_mode, nil, nil, nil, newValue, nil, nil) {

                let oldBracketingValue = _bracketing
                // value sent to the backend, update setting value and mark it updating
                _bracketing = newValue
                timeout.schedule { [weak self] in
                    if let `self` = self, self.update(bracketingValue: oldBracketingValue) {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
                didChangeDelegate.userDidChangeSetting()
            }
        }
    }
    private var _bracketing = CameraBracketingValue.preset1ev

    /// gpslapse capture interval value
    var gpslapseCaptureInterval: Double {
        get {
            return _gpslapseCaptureInterval
        }
        set {
            let clampValue = supportedGpslapseIntervals.clamp(newValue)
            if gpslapseCaptureInterval != clampValue &&
                backend(_mode, nil, nil, nil, nil, clampValue, nil) {

                let oldCaptureInterval = _gpslapseCaptureInterval
                // value sent to the backend, update setting value and mark it updating
                _gpslapseCaptureInterval = clampValue
                timeout.schedule { [weak self] in
                    if let `self` = self, self.update(gpslapseCaptureInterval: oldCaptureInterval) {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
                didChangeDelegate.userDidChangeSetting()
            }
        }
    }

    private var _gpslapseCaptureInterval = 0.0

    /// timelapse capture interval value
    var timelapseCaptureInterval: Double {
        get {
            return _timelapseCaptureInterval
        }
        set {
            let clampValue = supportedTimelapseIntervals.clamp(newValue)
            if timelapseCaptureInterval != clampValue &&
                backend(_mode, nil, nil, nil, nil, nil, clampValue) {

                let oldCaptureInterval = _timelapseCaptureInterval
                // value sent to the backend, update setting value and mark it updating
                _timelapseCaptureInterval = clampValue
                timeout.schedule { [weak self] in
                    if let `self` = self, self.update(timelapseCaptureInterval: oldCaptureInterval) {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
                didChangeDelegate.userDidChangeSetting()
            }
        }
    }
    private var _timelapseCaptureInterval = 0.0

    var supportedTimelapseIntervals: ClosedRange<Double> {
        return _supportedTimelapseIntervals
    }
    private var _supportedTimelapseIntervals = 0.0...Double.greatestFiniteMagnitude

    var supportedGpslapseIntervals: ClosedRange<Double> {
        return _supportedGpslapseIntervals
    }
    private var _supportedGpslapseIntervals = 0.0...Double.greatestFiniteMagnitude

    /// Constructor
    ///
    /// - Parameters:
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting properties
    ///   - backend: closure to call to change the setting value
    init(didChangeDelegate: SettingChangeDelegate,
         backend: @escaping (_ mode: CameraPhotoMode, _ format: CameraPhotoFormat?,
        _ fileFormat: CameraPhotoFileFormat?, _ burst: CameraBurstValue?,
        _ bracketing: CameraBracketingValue?, _ gpslapseCaptureInterval: Double?, _ timelapseCaptureInterval: Double?)
        -> Bool) {
        self.didChangeDelegate = didChangeDelegate
        self.backend = backend
    }

    /// Gets supported photo formats for a specific photo mode
    ///
    /// - Parameter mode: the photo mode
    /// - Returns: supported photo formats for the mode
    func supportedFormats(forMode mode: CameraPhotoMode) -> Set<CameraPhotoFormat> {
        if let formats = capabilities[mode]?.keys {
            return Set(formats)
        }
        return []
    }

    /// Gets supported photo file formats for a specific photo format
    ///
    /// - Parameters:
    ///   - mode: the photo mode
    ///   - format: the foto format
    /// - Returns: supported photo file formats for the mode and format
    func supportedFileFormats(forMode mode: CameraPhotoMode, format: CameraPhotoFormat) -> Set<CameraPhotoFileFormat> {
        if let fileFormats = capabilities[mode]?[format]?.keys {
            return Set(fileFormats)
        }
        return []
    }

    /// Tells if HDR is available for specific mode, format and file format
    ///
    /// - Parameters:
    ///   - mode: the photo mode
    ///   - format: the photo format
    ///   - fileFormat: the photo file format
    /// - Returns: true if hdr is available in the given mode, format and file format
    func hdrAvailable(forMode mode: CameraPhotoMode, format: CameraPhotoFormat, fileFormat: CameraPhotoFileFormat)
        -> Bool {
            return capabilities[mode]?[format]?[fileFormat] ?? false
    }

    /// Sets photo mode, format, file format, burst and bracketing value
    ///
    /// - Parameters:
    ///   - mode: photo mode
    ///   - format: photo format
    ///   - fileFormat: photo file format
    ///   - burst: burst value when photo mode is `burst`
    ///   - bracketing: bracketing value when photo mode is `bracketing`
    ///   - gpslapseCaptureInterval: timelapse capture interval value
    ///   - timelapseCaptureInterval: timelapse capture interval value
    func set(mode: CameraPhotoMode, format: CameraPhotoFormat, fileFormat: CameraPhotoFileFormat,
             burstValue: CameraBurstValue?, bracketingValue: CameraBracketingValue?,
             gpslapseCaptureIntervalValue: Double?, timelapseCaptureIntervalValue: Double?) {
        guard supportedModes.contains(mode) else {
            ULog.w(.cameraTag, "Unsupported photo mode: \(mode). Supported: \(supportedModes)")
            return
        }
        guard supportedFormats(forMode: mode).contains(format) else {
            ULog.w(.cameraTag, "Unsupported photo format: \(format) for mode \(mode). " +
                "Supported: \(supportedFormats(forMode: mode))")
            return
        }
        guard supportedFileFormats(forMode: mode, format: format).contains(fileFormat) else {
            ULog.w(.cameraTag, "Unsupported photo file format: \(fileFormat) for mode \(mode) and format \(format). " +
                "Supported: \(supportedFileFormats(forMode: mode, format: format))")
            return
        }
        guard burstValue == nil || supportedBurstValues.contains(burstValue!) else {
            ULog.w(.cameraTag, "Unsupported photo burst value: \(burstValue!). " +
                "Supported: \(supportedBurstValues)")
            return
        }
        guard bracketingValue == nil || supportedBracketingValues.contains(bracketingValue!) else {
            ULog.w(.cameraTag, "Unsupported photo bracketing value: \(bracketingValue!). " +
                "Supported: \(supportedBracketingValues)")
            return
        }

        let gpslapseCaptureIntervalValueClamped = gpslapseCaptureIntervalValue != nil ?
            supportedGpslapseIntervals.clamp(gpslapseCaptureIntervalValue!) : nil

        let timelapseCaptureIntervalValueClamped = timelapseCaptureIntervalValue != nil ?
            supportedTimelapseIntervals.clamp(timelapseCaptureIntervalValue!) : nil

        if backend(mode, format, fileFormat, burstValue, bracketingValue, gpslapseCaptureIntervalValueClamped,
                   timelapseCaptureIntervalValueClamped) {
            let oldMode = _mode
            let oldFormat = _format
            let oldFileFormat = _fileFormat
            let oldBurstValue = _burst
            let oldBracketingValue = _bracketing
            let oldTimelapseCaptureIntervalValue = _timelapseCaptureInterval
            let oldGpslapseCaptureIntervalValue = _gpslapseCaptureInterval

            // value sent to the backend, update setting value and mark it updating
            _mode = mode
            _format = format
            _fileFormat = fileFormat
            if let burstValue = burstValue {
                _burst = burstValue
            }
            if let bracketingValue = bracketingValue {
                _bracketing = bracketingValue
            }
            if let gpslapseCaptureIntervalValue = gpslapseCaptureIntervalValueClamped {
                 _gpslapseCaptureInterval = gpslapseCaptureIntervalValue
            }
            if let timelapseCaptureInternalValue = timelapseCaptureIntervalValueClamped {
                 _timelapseCaptureInterval = timelapseCaptureInternalValue
            }

            timeout.schedule { [weak self] in
                if let `self` = self {
                    let modeUpdated = self.update(mode: oldMode)
                    let formatUpdated = self.update(format: oldFormat)
                    let fileFormatUpdated = self.update(fileFormat: oldFileFormat)
                    let burstUpdated = self.update(burstValue: oldBurstValue)
                    let bracketingUpdated = self.update(bracketingValue: oldBracketingValue)
                    let timelapseUpdated = self.update(timelapseCaptureInterval: oldTimelapseCaptureIntervalValue)
                    let gpslapseUpdated = self.update(gpslapseCaptureInterval: oldGpslapseCaptureIntervalValue)

                    if modeUpdated || formatUpdated || fileFormatUpdated || burstUpdated || bracketingUpdated
                        || gpslapseUpdated  || timelapseUpdated {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
            }
            didChangeDelegate.userDidChangeSetting()
        }
    }

    /// Called by the backend, sets supported modes, formats and file formats
    ///
    /// - Parameter capabilities: mode, formats and file formats capabilities
    /// - Returns: true if the setting has been changed, false else
    func update(photoCapabilities: [CameraCore.PhotoCapabilitiesEntry]) -> Bool {
        capabilities = [:]

        for entry in photoCapabilities {
            for mode in entry.modes {
                for format in entry.formats {
                    for fileFormat in entry.fileFormats {
                        if capabilities[mode] == nil {
                            // new mode
                            capabilities[mode] = [format: [fileFormat: entry.hdrAvailable]]
                        } else if capabilities[mode]![format] == nil {
                            // new format for existing mode
                            capabilities[mode]![format] = [fileFormat: entry.hdrAvailable]
                        } else if capabilities[mode]![format]![fileFormat] == nil {
                            // new framerate
                            capabilities[mode]![format]![fileFormat] = entry.hdrAvailable
                        }
                    }
                }
            }
        }
        return true
    }

    /// Called by the backend, sets current mode
    ///
    /// - Parameter newMode: new photo mode
    /// - Returns: true if the setting has been changed, false else
    func update(mode newMode: CameraPhotoMode) -> Bool {
        if updating || _mode != newMode {
            _mode = newMode
            timeout.cancel()
            return true
        }
        return false
    }

    /// Called by the backend, sets current formats
    ///
    /// - Parameter newFormat: new photo format
    /// - Returns: true if the setting has been changed, false else
    func update(format newFormat: CameraPhotoFormat) -> Bool {
        if updating || _format != newFormat {
            _format = newFormat
            timeout.cancel()
            return true
        }
        return false
    }

    /// Called by the backend, sets current file format
    ///
    /// - Parameter newFileFormat: new photo file format
    /// - Returns: true if the setting has been changed, false else
    func update(fileFormat newFileFormat: CameraPhotoFileFormat) -> Bool {
        if updating || _fileFormat != newFileFormat {
            _fileFormat = newFileFormat
            timeout.cancel()
            return true
        }
        return false
    }

    /// Called by the backend, sets supported burst values
    ///
    /// - Parameter newSupportedBurstValues: new supported burst value
    /// - Returns: true if the setting has been changed, false else
    func update(supportedBurstValues newSupportedBurstValues: Set<CameraBurstValue>) -> Bool {
        if supportedBurstValues != newSupportedBurstValues {
            supportedBurstValues = newSupportedBurstValues
            if let newFallbackBurstValue = supportedBurstValues.sorted().first, !supportedBurstValues.contains(_burst) {
                _burst = newFallbackBurstValue
            }
            return true
        }
        return false
    }

    /// Called by the backend, sets current burst value
    ///
    /// - Parameter newBurstValue: new burst value
    /// - Returns: true if the setting has been changed, false else
    func update(burstValue newBurstValue: CameraBurstValue) -> Bool {
        if updating || _burst != newBurstValue {
            if supportedBurstValues.contains(newBurstValue) {
                _burst = newBurstValue
            } else if let newFallbackBurstValue = supportedBurstValues.sorted().first {
                _burst = newFallbackBurstValue
            }
            timeout.cancel()
            return true
        }
        return false
    }

    /// Called by the backend, sets supported bracketing values
    ///
    /// - Parameter newSupportedBracketingValues: new supported bracketing value
    /// - Returns: true if the setting has been changed, false else
    func update(supportedBracketingValues newSupportedBracketingValues: Set<CameraBracketingValue>) -> Bool {
        if supportedBracketingValues != newSupportedBracketingValues {
            supportedBracketingValues = newSupportedBracketingValues
            if let newFallbackBracketingValue = supportedBracketingValues.sorted().first,
                !supportedBracketingValues.contains(_bracketing) {

                _bracketing = newFallbackBracketingValue
            }
            return true
        }
        return false
    }

    /// Called by the backend, sets current bracketing value
    ///
    /// - Parameter newBracketingValue: new bracketing value
    /// - Returns: true if the setting has been changed, false else
    func update(bracketingValue newBracketingValue: CameraBracketingValue) -> Bool {
        if updating || _bracketing != newBracketingValue {
            if supportedBracketingValues.contains(newBracketingValue) {
                _bracketing = newBracketingValue
            } else if let newFallbackBracketingValue = supportedBracketingValues.sorted().first {
                _bracketing = newFallbackBracketingValue
            }
            timeout.cancel()
            return true
        }
        return false
    }

    /// Called by the backend, sets current timelapse capture interval
    ///
    /// - Parameter newTimelapseCaptureInterval: new timelapse capture interval
    /// - Returns: true if the setting has been changed, false else
    func update(timelapseCaptureInterval newTimelapseCaptureInterval: Double) -> Bool {
        if updating || _timelapseCaptureInterval != newTimelapseCaptureInterval {
            _timelapseCaptureInterval = newTimelapseCaptureInterval
            timeout.cancel()
            return true
        }
        return false
    }

    /// Called by the backend, sets current gpslapse capture interval
    ///
    /// - Parameter newGpslapseCaptureInterval: new gpslapse capture interval
    /// - Returns: true if the setting has been changed, false else
    func update(gpslapseCaptureInterval newGpslapseCaptureInterval: Double) -> Bool {
        if updating || _gpslapseCaptureInterval != newGpslapseCaptureInterval {
            _gpslapseCaptureInterval = newGpslapseCaptureInterval
            timeout.cancel()
            return true
        }
        return false
    }

    /// Called by the backend, sets current gpslapse interval min
    ///
    /// - Parameter newGpslapseIntervalMin: new gpslapse interval min
    /// - Returns: true if the setting has been changed, false else
    func update(gpslapseIntervalMin newGpslapseIntervalMin: Double) -> Bool {
        if updating || _gpslapseCaptureInterval != newGpslapseIntervalMin {
            _supportedGpslapseIntervals = newGpslapseIntervalMin...Double.greatestFiniteMagnitude
            _gpslapseCaptureInterval = _supportedGpslapseIntervals.clamp(_gpslapseCaptureInterval)
            timeout.cancel()
            return true
        }
        return false
    }

    /// Called by the backend, sets current timelapse interval min
    ///
    /// - Parameter newTimelapseIntervalMin: new timelapse interval min
    /// - Returns: true if the setting has been changed, false else
    func update(timelapseIntervalMin newTimelapseIntervalMin: Double) -> Bool {
        if updating || _timelapseCaptureInterval != newTimelapseIntervalMin {
            _supportedTimelapseIntervals = newTimelapseIntervalMin...Double.greatestFiniteMagnitude
            _timelapseCaptureInterval = _supportedTimelapseIntervals.clamp(_timelapseCaptureInterval)

            timeout.cancel()
            return true
        }
        return false
    }

    /// Cancels any pending rollback.
    ///
    /// - Parameter completionClosure: block that will be called if a rollback was pending
    func cancelRollback(completionClosure: () -> Void) {
        if timeout.isScheduled {
            timeout.cancel()
            completionClosure()
        }
    }

    /// Debug description
    var debugDescription: String {
        return "mode: \(_mode) \(supportedModes) format: \(_format) \(supportedFormats) " +
            "fileFormat: \(_fileFormat) \(supportedFileFormats) burst: \(_burst) \(supportedBurstValues) " +
            "bracketing: \(_bracketing) \(supportedBracketingValues)\(updating)]"
    }
}

/// ObjC support
extension CameraPhotoSettingsCore: GSCameraPhotoSettings {
    func isModeSupported(_ mode: CameraPhotoMode) -> Bool {
        return supportedModes.contains(mode)
    }

    func isFormatSupported(_ format: CameraPhotoFormat) -> Bool {
        return supportedFormats.contains(format)
    }

    func isFormatSupported(_ format: CameraPhotoFormat, forMode mode: CameraPhotoMode) -> Bool {
        return supportedFormats(forMode: mode).contains(format)
    }

    func isFileFormatSupported(_ fileformat: CameraPhotoFileFormat) -> Bool {
        return supportedFileFormats.contains(fileformat)
    }

    func isFileFormatSupported(_ fileformat: CameraPhotoFileFormat, forPhotoMode: CameraPhotoMode,
                               andPhotoFormat photoFormat: CameraPhotoFormat) -> Bool {
        return supportedFileFormats(forMode: mode, format: photoFormat).contains(fileformat)
    }

    func isBurstValueSupported(_ burstValue: CameraBurstValue) -> Bool {
        return supportedBurstValues.contains(burstValue)
    }

    func isBracketingValueSupported(_ bracketingValue: CameraBracketingValue) -> Bool {
        return supportedBracketingValues.contains(bracketingValue)
    }

    var gsMinSupportedGpslapseIntervals: Double {
        return _supportedGpslapseIntervals.lowerBound
    }

    var gsMaxSupportedGpslapseIntervals: Double {
        return _supportedGpslapseIntervals.upperBound
    }

    var gsMinSupportedTimelapseIntervals: Double {
        return _supportedTimelapseIntervals.lowerBound
    }

    var gsMaxSupportedTimelapseIntervals: Double {
        return _supportedTimelapseIntervals.upperBound
    }

    func gsSet(mode: CameraPhotoMode, format: CameraPhotoFormat, fileFormat: CameraPhotoFileFormat,
               burstValue: Int, bracketingValue: Int, gpslapseCaptureIntervalValue gpslapseValue: Double,
               timelapseCaptureIntervalValue timelapseValue: Double) {
        set(mode: mode, format: format, fileFormat: fileFormat, burstValue: CameraBurstValue(rawValue: burstValue),
            bracketingValue: CameraBracketingValue(rawValue: bracketingValue),
            gpslapseCaptureIntervalValue: gpslapseValue, timelapseCaptureIntervalValue: timelapseValue)
    }
}

/// Pair of photo mode and format
private struct ModeAndFormat: Hashable, CustomStringConvertible {
    let mode: CameraPhotoMode
    let format: CameraPhotoFormat

    var description: String {
        return "(\(mode) \(format))"
    }
}
