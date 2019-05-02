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

/// Camera exposure lock internal implementation
class CameraWhiteBalanceLockCore: CameraWhiteBalanceLock, CustomDebugStringConvertible {

    /// Delegate called when the setting value is changed by setting properties
    private unowned let didChangeDelegate: SettingChangeDelegate

    // default values
    private static let defaultLock = false

    /// Timeout object.
    ///
    /// Visibility is internal for testing purposes
    let timeout = SettingTimeout()

    /// Tells if the setting value has been changed and is waiting for change confirmation
    var updating: Bool { return timeout.isScheduled }

    /// closure to call to change the mode
    private let backend: (_ lock: Bool) -> Bool

    var locked = defaultLock

    var isLockable: Bool?

    /// Constructor
    ///
    /// - Parameters:
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting properties
    ///   - backend: closure to call to change the setting value
    init(didChangeDelegate: SettingChangeDelegate,
         backend: @escaping (_ lock: Bool) -> Bool) {
        self.didChangeDelegate = didChangeDelegate
        self.backend = backend
    }

    func setLock(lock: Bool) {
        set(lock: lock)
    }

    /// Change the mode from the api
    ///
    /// - Parameter newMode: the new mode to set
    private func set(lock newLock: Bool) {
        if locked != newLock {
            if backend(newLock) {
                let oldLock = locked
                // value sent to the backend, update setting value and mark it updating
                locked = newLock
                timeout.schedule { [weak self] in
                    if let `self` = self, self.update(lock: oldLock) {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
                didChangeDelegate.userDidChangeSetting()
            }
        }
    }

    /// Called by the backend, sets the mode
    ///
    /// - Parameter newMode: new mode
    /// - Returns: true if the setting has been changed, false else
    func update(lock newLock: Bool) -> Bool {
        if updating || locked != newLock {
            locked = newLock
            timeout.cancel()
            return true
        }
        return false
    }

    /// Called by the backend, sets the mode
    ///
    /// - Parameter newIsLockable: new is lockable
    /// - Returns: true if the setting has been changed, false else
    func update(isLockable newIsLockable: Bool?) -> Bool {
        if isLockable != newIsLockable {
            isLockable = newIsLockable
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
        return "\(locked.description) [updating: \(updating)]"
    }

}

// MARK: - objc compatibility
extension CameraWhiteBalanceLockCore: GSCameraWhiteBalanceLock {
    var isLockableSupported: Bool {
        return isLockable != nil
    }

    var gsIsLockable: Bool {
        return isLockable != nil ? isLockable! : false
    }

    var gsLocked: Bool {
        return locked
    }
}
