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

/// Core implementation of CameraExposureCompensationSetting
class CameraExposureCompensationSettingCore: CameraExposureCompensationSetting, CustomDebugStringConvertible {

    /// Delegate called when the setting value is changed by setting properties
    private unowned let didChangeDelegate: SettingChangeDelegate

    // default values
    private static let defaultValue = CameraEvCompensation.ev0_00

    /// Timeout object.
    ///
    /// Visibility is internal for testing purposes
    let timeout = SettingTimeout()

    /// Tells if the setting value has been changed and is waiting for change confirmation
    var updating: Bool { return timeout.isScheduled }

    /// closure to call to change the value
    private let backend: (_ exposureCompensation: CameraEvCompensation) -> Bool

    /// Supported exposure compensation values
    private(set) var supportedValues = Set<CameraEvCompensation>()

    /// Exposure mode
    var value: CameraEvCompensation {
        get {
            return _value
        }
        set {
            if _value != newValue && supportedValues.contains(newValue) && backend(newValue) {
                let oldValue = _value
                // value sent to the backend, update setting value and mark it updating
                _value = newValue
                timeout.schedule { [weak self] in
                    if let `self` = self, self.update(value: oldValue) {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
                didChangeDelegate.userDidChangeSetting()
            }
         }
    }
    private var _value = defaultValue

    /// Constructor
    ///
    /// - Parameters:
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting properties
    ///   - backend: closure to call to change the setting value
    init(didChangeDelegate: SettingChangeDelegate,
         backend: @escaping (_ exposureCompensation: CameraEvCompensation) -> Bool) {
        self.didChangeDelegate = didChangeDelegate
        self.backend = backend
    }

    /// Called by the backend, sets exposure compensation values
    ///
    /// - Parameter newSupportedModes: new supported mode
    /// - Returns: true if the setting has been changed, false else
    func update(supportedValues newSupportedValues: Set<CameraEvCompensation>) -> Bool {
        if supportedValues != newSupportedValues {
            supportedValues = newSupportedValues
            return true
        }
        return false
    }

    /// Called by the backend, sets current exposure compensation value
    ///
    /// - Parameter newValue: new exposure compensation value
    /// - Returns: true if the setting has been changed, false else
    func update(value newValue: CameraEvCompensation) -> Bool {
        if updating || _value != newValue {
            _value = newValue
            timeout.cancel()
            return true
        }
        return false
    }

    /// Resets setting values to defaults.
    func reset() {
        supportedValues = []
        _value = CameraExposureCompensationSettingCore.defaultValue
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
        return "(value: \(_value) \(supportedValues)) [\(updating)]"
    }
}

/// Objc support
extension CameraExposureCompensationSettingCore: GSCameraExposureCompensationSetting {

    /// Checks if an exposure compensation value is supported
    ///
    /// - Parameter value: exposure compensation value to check
    /// - Returns: true if the exposure compensation value is supported
    func isValueSupported(_ value: CameraEvCompensation) -> Bool {
        return supportedValues.contains(value)
    }
}
