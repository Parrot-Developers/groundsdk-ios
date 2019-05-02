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

/// Core implementation of CameraRecordingSettings
class CameraRecordingSettingsCore: CameraRecordingSettings, CustomDebugStringConvertible {

    /// Delegate called when the setting value is changed by setting properties
    private unowned let didChangeDelegate: SettingChangeDelegate

    /// Timeout object.
    ///
    /// Visibility is internal for testing purposes
    let timeout = SettingTimeout()

    /// Tells if the setting value has been changed and is waiting for change confirmation
    var updating: Bool { return timeout.isScheduled }

    /// closure to call to change the value
    private let backend: (_ mode: CameraRecordingMode, _ resolution: CameraRecordingResolution?,
        _ framerate: CameraRecordingFramerate?, _ hyperlapse: CameraHyperlapseValue?) -> Bool

    /// supported modes
    var supportedModes: Set<CameraRecordingMode> {
        return Set(capabilities.keys)
    }

    /// Supported recording resolution for the current recording mode
    var supportedResolutions: Set<CameraRecordingResolution> {
        return supportedResolutions(forMode: _mode)
    }

    /// Supported recording framerate for the current recording mode
    var supportedFramerates: Set<CameraRecordingFramerate> {
        return supportedFramerates(forMode: _mode, resolution: _resolution)
    }

    /// Is HDR available in the current mode, resolution and framerate
    var hdrAvailable: Bool {
        return hdrAvailable(forMode: _mode, resolution: _resolution, framerate: _framerate)
    }

    /// Mode, resolution, framerate and hdr capabilities
    private var capabilities: [CameraRecordingMode: [CameraRecordingResolution: [CameraRecordingFramerate: Bool]]] = [:]

    /// Supported Hyperlapse values when mode is `hyperlapse`
    private(set) var supportedHyperlapseValues = Set<CameraHyperlapseValue>()

    /// Recording mode
    var mode: CameraRecordingMode {
        get {
            return _mode
        }
        set {
            if _mode != newValue && supportedModes.contains(newValue) && backend(newValue, nil, nil, nil) {
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
    private var _mode: CameraRecordingMode = .standard

    /// Recording resolution
    var resolution: CameraRecordingResolution {
        get {
            return _resolution
        }
        set {
            if resolution != newValue && supportedResolutions.contains(newValue) &&
                backend(_mode, newValue, nil, nil) {

                let oldResolution = _resolution
                // value sent to the backend, update setting value and mark it updating
                _resolution = newValue
                timeout.schedule { [weak self] in
                    if let `self` = self, self.update(resolution: oldResolution) {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
                didChangeDelegate.userDidChangeSetting()
            }
        }
    }
    private var _resolution = CameraRecordingResolution.resDci4k

    /// Recording framerate
    var framerate: CameraRecordingFramerate {
        get {
            return _framerate
        }
        set {
            if framerate != newValue && supportedFramerates.contains(newValue) && backend(_mode, nil, newValue, nil) {
                let oldFramerate = _framerate
                // value sent to the backend, update setting value and mark it updating
                _framerate = newValue
                timeout.schedule { [weak self] in
                    if let `self` = self, self.update(framerate: oldFramerate) {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
                didChangeDelegate.userDidChangeSetting()
            }
        }
    }
    private var _framerate = CameraRecordingFramerate.fps30

    /// Hyperlapse values when mode is `hyperlapse`
    var hyperlapseValue: CameraHyperlapseValue {
        get {
            return _hyperlapse
        }
        set {
            if hyperlapseValue != newValue && supportedHyperlapseValues.contains(newValue) &&
                backend(_mode, nil, nil, newValue) {

                let oldValue = _hyperlapse
                // value sent to the backend, update setting value and mark it updating
                _hyperlapse = newValue
                timeout.schedule { [weak self] in
                    if let `self` = self, self.update(hyperlapseValue: oldValue) {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
                didChangeDelegate.userDidChangeSetting()
            }
        }
    }
    private var _hyperlapse = CameraHyperlapseValue.ratio15

    /// Recoding bitrate for current configuration, in bit/s. Zero if unknown.
    public private(set) var bitrate: UInt = 0

    /// Constructor
    ///
    /// - Parameters:
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting properties
    ///   - backend: closure to call to change the setting value
    init(didChangeDelegate: SettingChangeDelegate, backend: @escaping (_ mode: CameraRecordingMode,
        _ resolution: CameraRecordingResolution?, _ framerate: CameraRecordingFramerate?,
        _ hyperlapse: CameraHyperlapseValue?) -> Bool) {
        self.didChangeDelegate = didChangeDelegate
        self.backend = backend
    }

    /// Gets supported recording resolutions for a specific recording mode
    ///
    /// - Parameter mode: the recording mode
    /// - Returns: supported recording resolutions for the mode
    func supportedResolutions(forMode mode: CameraRecordingMode) -> Set<CameraRecordingResolution> {
        if let resolutions = capabilities[mode]?.keys {
            return Set(resolutions)
        }
        return []
    }

    /// Gets supported recording framerates for a specific recording mode and resolution
    ///
    /// - Parameters:
    ///   - mode: the recording mode
    ///   - resolution: the recording resolution
    /// - Returns: supported recording resolutions for the mode and resolution
    func supportedFramerates(forMode mode: CameraRecordingMode, resolution: CameraRecordingResolution)
        -> Set<CameraRecordingFramerate> {
            if let framerates = capabilities[mode]?[resolution]?.keys {
                return Set(framerates)
            }
            return []
    }

    /// Tells if HDR is available for specific mode, framerate and resolution
    ///
    /// - Parameters:
    ///   - mode: the recording mode
    ///   - resolution: the recording resolution
    ///   - framerate: the recording framerate
    /// - Returns: true if hdr is available in the given mode, resolution and framerate
    func hdrAvailable(
        forMode mode: CameraRecordingMode, resolution: CameraRecordingResolution, framerate: CameraRecordingFramerate)
        -> Bool {
            return capabilities[mode]?[resolution]?[framerate] ?? false
    }

    /// Set recording mode, resolution, framerate and hyperlase value
    ///
    /// - Parameters:
    ///   - mode: requested mode
    ///   - resolution: requested resolution
    ///   - framerate: requested framerate
    ///   - hyperlapse: requested hyperlapse value when mode is `hyperlapse`
    func set(mode: CameraRecordingMode, resolution: CameraRecordingResolution, framerate: CameraRecordingFramerate,
             hyperlapseValue: CameraHyperlapseValue?) {
        guard supportedModes.contains(mode) else {
            ULog.w(.cameraTag, "Unsupported recording mode: \(mode). Supported: \(supportedModes)")
            return
        }
        guard supportedResolutions(forMode: mode).contains(resolution) else {
            ULog.w(.cameraTag, "Unsupported recording resolution: \(resolution) for mode \(mode). " +
                "Supported: \(supportedResolutions(forMode: mode))")
            return
        }
        guard supportedFramerates(forMode: mode, resolution: resolution).contains(framerate) else {
            ULog.w(.cameraTag, "Unsupported recording framerate: \(framerate) for mode \(mode). " +
                "Supported: \(supportedFramerates(forMode: mode, resolution: resolution)))")
            return
        }
        guard hyperlapseValue == nil || supportedHyperlapseValues.contains(hyperlapseValue!) else {
            ULog.w(.cameraTag, "Unsupported recording hyperlapse value: \(hyperlapseValue!). " +
                "Supported: \(supportedHyperlapseValues)")
            return
        }

        if backend(mode, resolution, framerate, hyperlapseValue ?? _hyperlapse) {
            let oldMode = _mode
            let oldResolution = _resolution
            let oldFramerate = _framerate
            let oldHyperlapseValue = _hyperlapse
            // value sent to the backend, update setting value and mark it updating
            _mode = mode
            _resolution = resolution
            _framerate = framerate
            if let hyperlapseValue = hyperlapseValue {
                _hyperlapse = hyperlapseValue
            }
            timeout.schedule { [weak self] in
                if let `self` = self {
                    let modeUpdated = self.update(mode: oldMode)
                    let resolutionUpdated = self.update(resolution: oldResolution)
                    let framerateUpdated = self.update(framerate: oldFramerate)
                    let hyperlapseUpdated = self.update(hyperlapseValue: oldHyperlapseValue)
                    if modeUpdated || resolutionUpdated || framerateUpdated || hyperlapseUpdated {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
            }
            didChangeDelegate.userDidChangeSetting()
        }
    }

    /// Called by the backend, sets supported modes, resolution and framerates
    ///
    /// - Parameter capabilities: mode, resolution and framerate capabilities
    /// - Returns: true if the setting has been changed, false else
    func update(recordingCapabilities: [CameraCore.RecordingCapabilitiesEntry]) -> Bool {
        capabilities = [:]

        for entry in recordingCapabilities {
            for mode in entry.modes {
                for resolution in entry.resolutions {
                    for framerate in entry.framerates {
                        if capabilities[mode] == nil {
                            // new mode
                            capabilities[mode] = [resolution: [framerate: entry.hdrAvailable]]
                        } else if capabilities[mode]![resolution] == nil {
                            // new resolution for existing mode
                            capabilities[mode]![resolution] = [framerate: entry.hdrAvailable]
                        } else if capabilities[mode]![resolution]![framerate] == nil {
                            // new framerate
                            capabilities[mode]![resolution]![framerate] = entry.hdrAvailable
                        }
                    }
                }
            }
        }
        return true
    }

    /// Called by the backend, sets supported hyperlapse values
    ///
    /// - Parameter newSupportedHyperlapseValues: new supported hyperlapse values
    /// - Returns: true if the setting has been changed, false else
    func update(supportedHyperlapseValues newSupportedHyperlapseValues: Set<CameraHyperlapseValue>) -> Bool {
        if supportedHyperlapseValues != newSupportedHyperlapseValues {
            supportedHyperlapseValues = newSupportedHyperlapseValues
            if let newFallbackHyperlapseValue = supportedHyperlapseValues.sorted().first,
                !supportedHyperlapseValues.contains(_hyperlapse) {

                _hyperlapse = newFallbackHyperlapseValue
            }
            return true
        }
        return false
    }

    /// Called by the backend, sets current mode
    ///
    /// - Parameter newMode: new photo mode
    /// - Returns: true if the setting has been changed, false else
    func update(mode newMode: CameraRecordingMode) -> Bool {
        if updating || _mode != newMode {
            _mode = newMode
            timeout.cancel()
            return true
        }
        return false
    }

    /// Called by the backend, sets current resolution
    ///
    /// - Parameter newResolution: new recording resolution
    /// - Returns: true if the setting has been changed, false else
    func update(resolution newResolution: CameraRecordingResolution) -> Bool {
        if updating || _resolution != newResolution {
            _resolution = newResolution
            timeout.cancel()
            return true
        }
        return false
    }

    /// Called by the backend, sets current framerate
    ///
    /// - Parameter newFramerate: new recording framerate
    /// - Returns: true if the setting has been changed, false else
    func update(framerate newFramerate: CameraRecordingFramerate) -> Bool {
        if updating || _framerate != newFramerate {
            _framerate = newFramerate
            timeout.cancel()
            return true
        }
        return false
    }

    /// Called by the backend, sets hyperlapse value
    ///
    /// - Parameter newHyperlapseValue: new hyperlapse value
    /// - Returns: true if the setting has been changed, false else
    func update(hyperlapseValue newHyperlapseValue: CameraHyperlapseValue) -> Bool {
        if updating || _hyperlapse != newHyperlapseValue {
            if supportedHyperlapseValues.contains(newHyperlapseValue) {
                _hyperlapse = newHyperlapseValue
            } else if let newFallbackHyperlapseValue = supportedHyperlapseValues.sorted().first {
                _hyperlapse = newFallbackHyperlapseValue
            }
            timeout.cancel()
            return true
        }
        return false
    }

    /// Called by the backend, sets recording bitrate
    ///
    /// - Parameter bitrate: new recording bitrate
    /// - Returns: true if the value has been changed, false else
    func update(bitrate: UInt) -> Bool {
        if self.bitrate != bitrate {
            self.bitrate = bitrate
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
        return "mode: \(_mode) resolution: \(resolution) framerate: \(framerate) hdr: \(hdrAvailable) " +
            "hyperlapse: \(_hyperlapse) bitrate: \(bitrate) [\(capabilities) \(supportedHyperlapseValues) \(updating)]"
    }
}

/// ObjC support
extension CameraRecordingSettingsCore: GSCameraRecordingSettings {

    /// Checks if a recording mode is supported
    ///
    /// - Parameter mode: mode to check
    /// - Returns: true if the mode is supported
    func isModeSupported(_ mode: CameraRecordingMode) -> Bool {
        return supportedModes.contains(mode)
    }

    /// Checks if a resolution is supported in the current mode
    ///
    /// - Parameter resolution: resolution to check
    /// - Returns: true if the resolution is supported in the current mode
    func isResolutionSupported(_ resolution: CameraRecordingResolution) -> Bool {
        return supportedResolutions.contains(resolution)
    }

    /// Checks if a resolution is supported in a specific mode
    ///
    /// - Parameters:
    ///   - mode: mode to check if a resolution is supported
    ///   - resolution: resolution to check
    /// - Returns: true if the resolution is supported in the specified mode
    func isResolutionSupported(_ resolution: CameraRecordingResolution, forMode mode: CameraRecordingMode) -> Bool {
        return supportedResolutions(forMode: mode).contains(resolution)
    }

    /// Checks if a framerate is supported in the current mode
    ///
    /// - Parameter framerate: framerate to check
    /// - Returns: true if the framerate is supported in the current mode
    func isFramerateSupported(_ framerate: CameraRecordingFramerate) -> Bool {
        return supportedFramerates.contains(framerate)
    }

    /// Checks if a framerate is supported in a specific mode and resolution
    ///
    /// - Parameters:
    ///   - mode: mode to check if a framerate is supported
    ///   - framerate: framerate to check
    ///   - resolution: resolution to check
    /// - Returns: true if the framerate is supported in the specified mode
    func isFramerateSupported(_ framerate: CameraRecordingFramerate, forMode mode: CameraRecordingMode,
                              andResolution resolution: CameraRecordingResolution) -> Bool {
        return supportedFramerates(forMode: mode, resolution: resolution).contains(framerate)
    }

    /// Checks if a hyperlapse value is supported
    ///
    /// - Parameter hyperlapseValue: hyperlapse value to check
    /// - Returns: true if the hyperlapse value is supported
    func isHyperlapseValueSupported(_ hyperlapseValue: CameraHyperlapseValue) -> Bool {
        return supportedHyperlapseValues.contains(hyperlapseValue)
    }

    /// Change recording mode, resolution, framerate and hyperlapse value
    ///
    /// - Parameters:
    ///   - mode: requested recording mode
    ///   - resolution: requested recording resolution
    ///   - framerate: requested recording framerate
    ///   - hyperlapseValue: requested hyperlapse value, -1 to keep the current value
    func gsSet(mode: CameraRecordingMode, resolution: CameraRecordingResolution,
               framerate: CameraRecordingFramerate, hyperlapseValue: Int) {
        set(mode: mode, resolution: resolution, framerate: framerate,
            hyperlapseValue: CameraHyperlapseValue(rawValue: hyperlapseValue))
    }
}

/// Pair of recording mode and resolution
private struct ModeAndResolution: Hashable, CustomStringConvertible {
    let mode: CameraRecordingMode
    let resolution: CameraRecordingResolution

    var description: String {
        return "(\(mode) \(resolution))"
    }
}
