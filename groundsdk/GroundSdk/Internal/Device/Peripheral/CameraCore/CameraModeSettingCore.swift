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

class CameraModeSettingCore: CameraModeSetting, CustomDebugStringConvertible {
    /// Delegate called when the setting value is changed by setting properties
    private unowned let didChangeDelegate: SettingChangeDelegate

    /// Timeout object.
    ///
    /// Visibility is internal for testing purposes
    let timeout = SettingTimeout()

    /// Tells if the setting value has been changed and is waiting for change confirmation
    var updating: Bool { return timeout.isScheduled }

    /// Supported modes
    private(set) var supportedModes = Set<CameraMode>()
    /// Current mode
    var mode: CameraMode {
        get {
            return _mode
        }
        set {
            if _mode != newValue && supportedModes.contains(newValue) {
                if backend(newValue) {
                    let oldValue = _mode
                    // value sent to the backend, update setting value and mark it updating
                    _mode = newValue
                    timeout.schedule { [weak self] in
                        if let `self` = self, self.update(mode: oldValue) {
                            self.didChangeDelegate.userDidChangeSetting()
                        }
                    }
                    didChangeDelegate.userDidChangeSetting()
                }
            }
        }
    }

    /// Camera mode
    private var _mode: CameraMode = .recording

    /// Closure to call to change the value
    private let backend: ((CameraMode) -> Bool)

    /// Constructor
    ///
    /// - Parameters:
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting properties
    ///   - backend: closure to call to change the setting value
    init(didChangeDelegate: SettingChangeDelegate, backend: @escaping (CameraMode) -> Bool) {
        self.didChangeDelegate = didChangeDelegate
        self.backend = backend
    }

    /// Called by the backend, sets supported modes
    func update(supportedModes newSupportedModes: Set<CameraMode>) -> Bool {
        if supportedModes != newSupportedModes {
            supportedModes = newSupportedModes
            return true
        }
        return false
    }

    /// Called by the backend, change the current mode data
    ///
    /// - Parameter mode: new camera mode
    /// - Returns: true if the setting has been changed, false else
    func update(mode newMode: CameraMode) -> Bool {
        if updating || _mode != newMode {
            _mode = newMode
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
        return "mode: \(_mode) \(supportedModes) updating: [\(updating)]"
    }
}

/// Objc support
extension CameraModeSettingCore: GSCameraModeSetting {
    func isModeSupported(_ mode: CameraMode) -> Bool {
        return supportedModes.contains(mode)
    }
}
