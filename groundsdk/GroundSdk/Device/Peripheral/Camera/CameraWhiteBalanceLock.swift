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

/// Camera white balance lock.
///
///  Allows to lock/unlock the white balance values.
public protocol CameraWhiteBalanceLock: class {
    /// Tells if a setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Whether white balance is currently locked.
    var locked: Bool { get }

    /// Whether white balance lock is lockable.
    var isLockable: Bool? { get }

    /// Sets white balance lock setting.
    ///
    /// - Parameter lock: lock value to set
    func setLock(lock: Bool)
}

/// Camera white balance lock.
///
///  Allows to lock/unlock the white balance values.
/// - Note: This protocol is for Objective-C compatibility only.
@objc public protocol GSCameraWhiteBalanceLock {
    /// Tells if a setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Whether white balance is currently locked.
    @objc(locked)
    var gsLocked: Bool { get }

    /// Whether white balance lock is lockable.
    @objc(isLockable)
    var gsIsLockable: Bool { get }

    /// Whether white balance lock is supported.
    var isLockableSupported: Bool { get }

    /// Sets white balance lock setting.
    ///
    /// - Parameter lock: lock value to set
    func setLock(lock: Bool)
}
