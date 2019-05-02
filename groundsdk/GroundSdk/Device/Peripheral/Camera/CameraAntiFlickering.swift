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

/// Camera anti-flickering modes.
@objc(GSCameraAntiFlickeringMode)
public enum CameraAntiFlickeringMode: Int, CustomStringConvertible {
    /// Anti-flickering is off.
    case off
    /// Auto detect anti-flickering.
    case automatic
    /// Force the exposure time to be an integer multiple of 10ms.
    @objc(GSCameraAntiFlickeringMode50Hz)
    case mode50Hz
    /// Force the exposure time to be an integer multiple of 8.33ms.
    @objc(GSCameraAntiFlickeringMode60Hz)
    case mode60Hz

    /// Debug description.
    public var description: String {
        switch self {
        case .off:       return "off"
        case .automatic: return "automatic"
        case .mode50Hz:  return "50Hz"
        case .mode60Hz:  return "60Hz"
        }
    }
}

/// Settings to configure camera anti-flickering options.
public protocol CameraAntiFlickeringSettings: class {
    /// Tells if a setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Supported recording modes.
    var supportedModes: Set<CameraAntiFlickeringMode> { get }

    /// Recording mode.
    var mode: CameraAntiFlickeringMode { get set }
}

// MARK: - objc compatibility

/// Setting to configure camera exposure compensation
/// - Note: This protocol is for Objective-C compatibility only.
@objc public protocol GSCameraAntiFlickeringSettings {
    /// Tells if a setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Exposure compensation value.
    var mode: CameraAntiFlickeringMode { get set }

    /// Checks if an anti-flickering mode is supported.
    ///
    /// - Parameter mode: anti-flickering mode to check
    /// - Returns: `true` if the anti-flickering mode is supported
    func isModeSupported(_ mode: CameraAntiFlickeringMode) -> Bool
}
