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

/// Camera image styles.
@objc(GSCameraStyle)
public enum CameraStyle: Int, CustomStringConvertible {
    /// Natural look style.
    case standard
    /// Parrot Log, produce flat and desaturated images, best for post-processing.
    case plog
    /// Intense look style, providing bright colors, warm shade and high contrast.
    case intense
    /// Pastel look style, providing soft colors, cold shade and low contrast.
    case pastel

    /// Debug description.
    public var description: String {
        switch self {
        case .standard: return "standard"
        case .plog: return "plog"
        case .intense: return "intense"
        case .pastel: return "pastel"
        }
    }

    /// Set containing all possible values.
    public static let allCases: Set<CameraStyle> = [
        .standard, .plog, .intense, .pastel]
}

/// Style customizable parameters.
@objc(GSCameraStyleParameter)
public protocol CameraStyleParameter {
    /// Whether the parameter can be modified.
    var mutable: Bool { get }

    /// Parameter minimum value.
    var min: Int { get }

    /// Parameter maximum value.
    var max: Int { get }

    /// Parameter current value.
    var value: Int { get set }
}

/// Camera style settings.
///
///  Allows to set the active image style and to customize its parameters.
public protocol CameraStyleSettings: class {
    /// Tells if a setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Supported styles.
    /// An empty set means that the whole setting is currently unsupported.
    var supportedStyles: Set<CameraStyle> { get }

    /// Current active style.
    var activeStyle: CameraStyle { get set }

    /// Current style saturation.
    var saturation: CameraStyleParameter { get }

    /// Current style contrast.
    var contrast: CameraStyleParameter { get }

    /// Current style sharpness.
    var sharpness: CameraStyleParameter { get }
}

// MARK: - objc compatibility

/// Camera style settings.
///
///  Allows to set the active image style and to customize its parameters.
/// - Note: This protocol is for Objective-C compatibility only.
@objc public protocol GSCameraStyleSettings {
    /// Tells if a setting value has been changed and is waiting for change confirmation
    var updating: Bool { get }

    /// Current active style.
    var activeStyle: CameraStyle { get set }

    /// Current style saturation.
    var saturation: CameraStyleParameter { get }

    /// Current style contrast.
    var contrast: CameraStyleParameter { get }

    /// Current style sharpness.
    var sharpness: CameraStyleParameter { get }

    /// Checks if a style is supported.
    ///
    /// - Parameter style: style to check
    /// - Returns: `true` if the style is supported
    func isStyleSupported(_ style: CameraStyle) -> Bool
}
