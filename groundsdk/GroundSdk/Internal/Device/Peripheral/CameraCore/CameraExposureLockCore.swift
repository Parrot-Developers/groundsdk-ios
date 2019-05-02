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
class CameraExposureLockCore: CameraExposureLock, CustomDebugStringConvertible {

    /// Delegate called when the setting value is changed by setting properties
    private unowned let didChangeDelegate: SettingChangeDelegate

    // default values
    private static let defaultMode = CameraExposureLockMode.none

    /// Timeout object.
    ///
    /// Visibility is internal for testing purposes
    let timeout = SettingTimeout()

    /// Tells if the setting value has been changed and is waiting for change confirmation
    var updating: Bool { return timeout.isScheduled }

    /// Closure to call to change the mode
    private let backend: (_ mode: CameraExposureLockMode) -> Bool

    var mode = defaultMode

    /// Constructor
    ///
    /// - Parameters:
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting properties
    ///   - backend: closure to call to change the setting value
    init(didChangeDelegate: SettingChangeDelegate,
         backend: @escaping (_ mode: CameraExposureLockMode) -> Bool) {

        self.didChangeDelegate = didChangeDelegate
        self.backend = backend
    }

    func lockOnCurrentValues() {
        set(mode: .currentValues)
    }

    func lockOnRegion(centerX: Double, centerY: Double) {
        set(mode: .region(centerX: centerX, centerY: centerY, width: 0.0, height: 0.0))
    }

    func unlock() {
        set(mode: .none)
    }

    /// Change the mode from the api
    ///
    /// - Parameter newMode: the new mode to set
    private func set(mode newMode: CameraExposureLockMode) {
        if mode != newMode {
            if backend(newMode) {
                let oldMode = mode
                // value sent to the backend, update setting value and mark it updating
                mode = newMode
                timeout.schedule { [weak self] in
                    if let `self` = self, self.update(mode: oldMode) {
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
    func update(mode newMode: CameraExposureLockMode) -> Bool {
        if updating || mode != newMode {
            mode = newMode
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
        return "\(mode.description) [updating: \(updating)]"
    }
}

// MARK: - objc compatibility
extension CameraExposureLockCore: GSCameraExposureLock {
    var gsMode: GSCameraExposureLockMode {
        switch mode {
        case .none:             return .none
        case .currentValues:    return .currentValues
        case .region:           return .region
        }
    }

    var regionCenterX: Double {
        if case let .region(x, _, _, _) = mode {
            return x
        }
        return 0
    }

    var regionCenterY: Double {
        if case let .region(_, y, _, _) = mode {
            return y
        }
        return 0
    }

    var regionWidth: Double {
        if case let .region(_, _, width, _) = mode {
            return width
        }
        return 0
    }

    var regionHeight: Double {
        if case let .region(_, _, _, height) = mode {
            return height
        }
        return 0
    }
}
