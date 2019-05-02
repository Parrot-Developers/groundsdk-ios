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

/// Camera mode.
@objc(GSCameraMode)
public enum CameraMode: Int, CustomStringConvertible {
    /// Camera mode that is best suited to record videos.
    /// - Note: Depending on the device, it may also be possible to take photos while in this mode.
    case recording
    /// Camera mode that is best suited to take photos.
    case photo

    /// Debug description.
    public var description: String {
        switch self {
        case .recording: return "recording"
        case .photo:     return "photo"
        }
    }
}

/// Setting to change the camera mode.
public protocol CameraModeSetting: class {
    /// Tells if the setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Supported modes.
    var supportedModes: Set<CameraMode> { get }

    /// Current camera mode.
    var mode: CameraMode { get set }
}

// MARK: - objc compatibility

/// Setting to change the camera mode
/// - Note: This protocol is for Objective-C compatibility only.
@objc public protocol GSCameraModeSetting {
    /// Tells if a setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Camera mode.
    var mode: CameraMode { get set }

    /// Checks if a mode is supported
    ///
    /// - Parameter mode: mode to check
    /// - Returns: `true` if the mode is supported
    func isModeSupported(_ mode: CameraMode) -> Bool
}
