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

/// Anti-flickering modes.
@objc(GSAntiflickerMode)
public enum AntiflickerMode: Int, CustomStringConvertible {
    /// Anti-flickering is off.
    case off
    /// Anti-flickering set to 50hz.
    @objc(GSAntiflickerMode50Hz)
    case mode50Hz
    /// Anti-flickering set to 60hz.
    @objc(GSAntiflickerMode60Hz)
    case mode60Hz
    /// Anti-flickering automatically either managed by the drone or based on the location.
    case auto

    /// Debug description.
    public var description: String {
        switch self {
        case .off: return "off"
        case .mode50Hz: return "50hz"
        case .mode60Hz: return "60hz"
        case .auto: return "auto"
        }
    }
}

/// Anti-flickering value.
@objc(GSAntiflickerValue)
public enum AntiflickerValue: Int, CustomStringConvertible {
    /// Unknown value. Drone didn't notify current value.
    case unknown
    /// Anti-flickering is off.
    case off
    /// Anti-flickering set to 50hz.
    @objc(GSAntiflickerValue50Hz)
    case value50Hz
    /// Anti-flickering set to 60hz.
    @objc(GSAntiflickerValue60Hz)
    case value60Hz

    /// Debug description.
    public var description: String {
        switch self {
        case .unknown: return "unknown"
        case .off: return "off"
        case .value50Hz: return "50hz"
        case .value60Hz: return "60hz"
        }
    }
}

/// Setting to change the anti-flickering mode.
public protocol AntiflickerSetting: class {
    /// Whether the setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Supported modes.
    var supportedModes: Set<AntiflickerMode> { get }

    /// Current anti-flickering mode setting.
    var mode: AntiflickerMode { get set }
}

/// Peripheral managing anti-flickering.
///
/// Anti-flickering is a global setting of a drone and is used by all drone cameras.
///
/// This peripheral can be retrieved by:
/// ```
/// device.getPeripheral(Peripherals.antiflicker)
/// ```
public protocol Antiflicker: Peripheral {
    /// Antiflicker setting.
    var setting: AntiflickerSetting { get }

    /// Current anti-flickering value. Useful when mode is one of the automatic mode.
    var value: AntiflickerValue { get }
}

/// :nodoc:
/// Antiflicker description
@objc(GSAntiflickerDesc)
public class AntiflickerDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = Antiflicker
    public let uid = PeripheralUid.antiflicker.rawValue
    public let parent: ComponentDescriptor? = nil
}

// MARK: - objc compatibility

/// Setting to change the anti-flickering mode.
/// - Note: This protocol is for Objective-C compatibility only.
@objc public protocol GSAntiflickerSetting {
    /// Whether the setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Antiflicker mode setting.
    var mode: AntiflickerMode { get set }

    /// Tells if a mode is supported.
    ///
    /// - Parameter mode: mode to check
    /// - Returns: `true` if the mode is supported
    func isModeSupported(_ mode: AntiflickerMode) -> Bool
}

/// Peripheral managing anti-flickering.
/// - Note: This protocol is for Objective-C compatibility only.
@objc public protocol GSAntiflicker {
    /// Antiflicker setting.
    @objc(setting)
    var gsSetting: GSAntiflickerSetting { get }

    /// Current anti-flickering value. Useful when mode is one of the automatic mode.
    var value: AntiflickerValue { get }
}
