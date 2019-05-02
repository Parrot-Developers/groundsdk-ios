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

/// Style customizable parameters
private class CameraStyleParameterCore: CameraStyleParameter, CustomDebugStringConvertible {

    private var backend: (_ value: Int) -> Bool

    /// Whether or not the parameter can be modified
    private (set) var mutable = false
    /// Parameter minimum value
    var min: Int {
        return range.lowerBound
    }
    /// Parameter maximum value
    var max: Int {
        return range.upperBound
    }
    private var range: ClosedRange<Int> = 0...0

    /// Parameter current value
    var value: Int {
        get {
            return _value
        }
        set {
            if mutable && _value != newValue {
                let val = range.clamp(newValue)
                if backend(val) {
                    _value = val
                }
            }
        }
    }
    private var _value = 0

    init(backend: @escaping (_ value: Int) -> Bool) {
        self.backend = backend
    }

    /// Called by the backend, sets supported modes
    ///
    /// - Parameter newSupportedModes: new supported modes
    /// - Returns: true if the setting has been changed, false else
    func update(min newMin: Int, value newValue: Int, max newMax: Int) -> Bool {
        if newMin != min || newValue != value || newMax != max {
            mutable = newMin != newMax
            range = newMin...newMax
            _value = newValue
            return true
        }
        return false
    }

    /// Clear parameter values by setting them to 0
    func clear() {
        mutable = false
        range = 0...0
        _value = 0

    }
    /// Debug description
    var debugDescription: String {
        return "\(_value) [\(range)] mutable: \(mutable)"
    }
}

/// Camera style settings
///
///  Allows set the active image style and customize its parameters
class CameraStyleSettingsCore: CameraStyleSettings, CustomDebugStringConvertible {

    /// Delegate called when the setting value is changed by setting properties
    private unowned let didChangeDelegate: SettingChangeDelegate

    // default values
    private static let defaultActiveStyle = CameraStyle.standard

    /// Timeout object.
    ///
    /// Visibility is internal for testing purposes
    let timeout = SettingTimeout()

    /// Tells if the setting value has been changed and is waiting for change confirmation
    var updating: Bool { return timeout.isScheduled }

    /// closure to call to change the value
    private let changeStyleBackend: (_ style: CameraStyle) -> Bool
    private let changeConfigBackend: (_ saturation: Int, _ contrast: Int, _ sharpness: Int) -> Bool

    /// Supported styles.
    private(set) var supportedStyles = Set<CameraStyle>()

    /// Current active style.
    var activeStyle: CameraStyle {
        get {
            return _activeStyle
        }
        set {
            if _activeStyle != newValue {
                set(activeStyle: newValue)
            }
        }
    }
    private var _activeStyle: CameraStyle = .standard

    /// Current style saturation.
    var saturation: CameraStyleParameter {
        return _saturation
    }
    private var _saturation: CameraStyleParameterCore!

    /// Current style contrast.
    var contrast: CameraStyleParameter {
        return _contrast
    }
    private var _contrast: CameraStyleParameterCore!

    /// Current style sharpness.
    var sharpness: CameraStyleParameter {
        return _sharpness
    }
    private var _sharpness: CameraStyleParameterCore!

    /// Constructor
    ///
    /// - Parameters:
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting properties
    ///   - backend: closure to call to change the setting value
    init(didChangeDelegate: SettingChangeDelegate, changeStyleBackend: @escaping (_ style: CameraStyle) -> Bool,
         changeConfigBackend: @escaping (_ saturation: Int, _ contrast: Int, _ sharpness: Int) -> Bool) {
        self.didChangeDelegate = didChangeDelegate
        self.changeStyleBackend = changeStyleBackend
        self.changeConfigBackend = changeConfigBackend
        _saturation = CameraStyleParameterCore { [unowned self] value in
            return self.set(saturation: value)
        }
        _contrast = CameraStyleParameterCore { [unowned self] value in
            return self.set(contrast: value)
        }
        _sharpness = CameraStyleParameterCore { [unowned self] value in
            return self.set(sharpness: value)
        }
    }

    /// Sets active style
    ///
    /// - Parameter style: style to set
    private func set(activeStyle style: CameraStyle) {
        guard supportedStyles.contains(style) else {
            ULog.w(.cameraTag, "Unsupported style: \(style). Supported: \(supportedStyles)")
            return
        }
        if changeStyleBackend(style) {
            let oldActiveStyle = _activeStyle
            let oldContrast = (min: _contrast.min, value: _contrast.value, max: _contrast.max)
            let oldSharpness = (min: _sharpness.min, value: _sharpness.value, max: _sharpness.max)
            let oldSaturation = (min: _saturation.min, value: _saturation.value, max: _saturation.max)
            _activeStyle = style
            // clear all parameters of previous style
            _contrast.clear()
            _sharpness.clear()
            _saturation.clear()
            timeout.schedule { [weak self] in

                if let `self` = self {
                    let styleUpdated = self.update(activeStyle: oldActiveStyle)
                    let saturationUpdated = self.update(saturation: oldSaturation)
                    let contrastUpdated = self.update(contrast: oldContrast)
                    let sharpnessUpdated = self.update(sharpness: oldSharpness)
                    if styleUpdated || saturationUpdated || contrastUpdated || sharpnessUpdated {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
            }
            didChangeDelegate.userDidChangeSetting()
        }
    }

    /// Set active syle saturation, contrast and sharpness
    ///
    /// - Parameters:
    ///   - saturation: requested saturation
    ///   - contrast: requested contrast
    ///   - sharpness: requested sharpness
    /// - Returns: true if settings have been changed, false else
    private func set(saturation: Int? = nil, contrast: Int? = nil, sharpness: Int? = nil) -> Bool {
        let oldContrast: (min: Int, value: Int, max: Int)? = contrast != nil ?
            (min: _contrast.min, value: _contrast.value, max: _contrast.max) : nil
        let oldSharpness: (min: Int, value: Int, max: Int)? = sharpness != nil ?
            (min: _sharpness.min, value: _sharpness.value, max: _sharpness.max) : nil
        let oldSaturation: (min: Int, value: Int, max: Int)? = saturation != nil ?
            (min: _saturation.min, value: _saturation.value, max: _saturation.max) : nil
        if changeConfigBackend(saturation ?? _saturation.value, contrast ?? _contrast.value,
                               sharpness ?? _sharpness.value) {
            timeout.schedule { [weak self] in

                if let `self` = self {
                    let saturationUpdated = oldSaturation != nil ? self.update(saturation: oldSaturation!) : false
                    let contrastUpdated = oldContrast != nil ? self.update(contrast: oldContrast!) : false
                    let sharpnessUpdated = oldSharpness != nil ? self.update(sharpness: oldSharpness!) : false
                    if saturationUpdated || contrastUpdated || sharpnessUpdated {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
            }
            didChangeDelegate.userDidChangeSetting()
            return true
        }
        return false
    }

    /// Called by the backend, sets supported styles
    ///
    /// - Parameter newSupportedStyles: new supported styles
    /// - Returns: true if the setting has been changed, false else
    func update(supportedStyles newSupportedStyles: Set<CameraStyle>) -> Bool {
        if supportedStyles != newSupportedStyles {
            supportedStyles = newSupportedStyles
            return true
        }
        return false
    }

    /// - Returns: true if the setting has been changed, false else
    func update(activeStyle newActiveStyle: CameraStyle) -> Bool {
        if updating || _activeStyle != newActiveStyle {
            _activeStyle = newActiveStyle
            timeout.cancel()
            return true
        }
        return false
    }

    /// - Returns: true if the setting has been changed, false else
    func update(saturation newStaturation: (min: Int, value: Int, max: Int)) -> Bool {
        let changed = _saturation.update(min: newStaturation.min, value: newStaturation.value, max: newStaturation.max)
        if updating || changed {
            timeout.cancel()
            return true
        }
        return false
    }

    /// - Returns: true if the setting has been changed, false else
    func update(contrast newContrast: (min: Int, value: Int, max: Int)) -> Bool {
        let changed = _contrast.update(min: newContrast.min, value: newContrast.value, max: newContrast.max)
        if updating || changed {
            timeout.cancel()
            return true
        }
        return false
    }

    /// - Returns: true if the setting has been changed, false else
    func update(sharpness newSharpness: (min: Int, value: Int, max: Int)) -> Bool {
        let changed = _sharpness.update(min: newSharpness.min, value: newSharpness.value, max: newSharpness.max)
        if updating || changed {
            timeout.cancel()
            return true
        }
        return false
    }

    /// Resets setting values to defaults.
    func reset() {
        supportedStyles = []
        _activeStyle = CameraStyleSettingsCore.defaultActiveStyle
        _ = _saturation.update(min: 0, value: 0, max: 0)
        _ = _contrast.update(min: 0, value: 0, max: 0)
        _ = _sharpness.update(min: 0, value: 0, max: 0)
        timeout.cancel()
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
        return "\(_activeStyle) [\(supportedStyles)] saturation: \(saturation) contrast: \(contrast) " +
        "sharpness: \(sharpness) updating: \(updating)]"
    }
}

// MARK: - objc compatibility
extension CameraStyleSettingsCore: GSCameraStyleSettings {
    /// Checks if a style is supported
    ///
    /// - Parameter style: style to check
    /// - Returns: true if the style is supported
    func isStyleSupported(_ style: CameraStyle) -> Bool {
        return supportedStyles.contains(style)
    }
}
