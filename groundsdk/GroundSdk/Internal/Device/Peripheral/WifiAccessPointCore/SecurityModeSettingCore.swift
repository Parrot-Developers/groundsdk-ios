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

//// Core implementation of the SecurityModeSetting protocol
class SecurityModeSettingCore: SecurityModeSetting {

    /// Values of this setting that can be sent to the backend
    enum SettingValue {
        /// disable security
        case open
        /// wpa 2 with a password
        case wpa2(password: String)
    }

    /// Delegate called when the setting value is changed by setting `value` property
    private unowned let didChangeDelegate: SettingChangeDelegate

    /// Timeout object.
    ///
    /// Visibility is internal for testing purposes
    let timeout = SettingTimeout()

    /// Tells if the setting value has been changed and is waiting for change confirmation
    var updating: Bool { return timeout.isScheduled }

    private(set) var mode = SecurityMode.open

    private(set) var supportedModes = Set<SecurityMode>()

    /// Closure to call to change the value
    private let backend: (SettingValue) -> Bool

    /// Constructor
    ///
    /// - Parameters:
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting `value` property
    ///   - backend: closure to call to change the setting value
    init(didChangeDelegate: SettingChangeDelegate, backend: @escaping (SettingValue) -> Bool) {
        self.didChangeDelegate = didChangeDelegate
        self.backend = backend
    }

    func open() {
        guard supportedModes.contains(.open) else {
            return
        }
        if mode != .open {
            if backend(.open) {
                let oldMode = mode
                mode = .open
                timeout.schedule { [weak self] in
                    if let `self` = self, self.update(mode: oldMode) {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
                didChangeDelegate.userDidChangeSetting()
            }
        }
    }

    func secureWithWpa2(password: String) -> Bool {
        guard WifiPasswordUtil.isValid(password) else {
            return false
        }
        guard supportedModes.contains(.wpa2Secured) else {
            return true
        }
        if backend(.wpa2(password: password)) {
            let oldMode = mode
            mode = .wpa2Secured
            timeout.schedule { [weak self] in
                if let `self` = self, self.update(mode: oldMode) {
                    self.didChangeDelegate.userDidChangeSetting()
                }
            }
            didChangeDelegate.userDidChangeSetting()
        }
        return true
    }

    /// Called by the backend, change the setting data
    ///
    /// - Parameter value:  the new security mode
    /// - Returns: true if the setting has been changed, false otherwise
    func update(mode newValue: SecurityMode) -> Bool {
        if updating || mode != newValue {
            mode = newValue
            timeout.cancel()
            return true
        }
        return false
    }

    /// Called by the backend, sets supported modes
    ///
    /// - Parameter supportedModes: new set of security mode
    /// - Returns: true if the set has been changed, false otherwise
    func update(supportedModes newSupportedModes: Set<SecurityMode>) -> Bool {
        if supportedModes != newSupportedModes {
            supportedModes = newSupportedModes
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
}

/// Extension of SecurityModeSettingCore to conform to the ObjC GSSecurityModeSetting protocol
extension SecurityModeSettingCore: GSSecurityModeSetting {
    func isModeSupported(_ mode: SecurityMode) -> Bool {
        return supportedModes.contains(mode)
    }
}
