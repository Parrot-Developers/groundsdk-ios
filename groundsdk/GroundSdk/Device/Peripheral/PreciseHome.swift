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

/// Precise home modes.
@objc(GSPreciseHomeMode)
public enum PreciseHomeMode: Int, CustomStringConvertible {
    /// Precise home is off.
    case disabled
    /// Precise home is enabled, in standard mode.
    case standard

    /// Debug description.
    public var description: String {
        switch self {
        case .disabled: return "disabled"
        case .standard: return "standard"
        }
    }
}

/// Precise home state.
@objc(GSPreciseHomeState)
public enum PreciseHomeState: Int {
    /// Precise home unavailable.
    case unavailable

    /// Precise home available.
    case available

    /// Precise home is active.
    case active

    /// Debug description.
    public var description: String {
        switch self {
        case .unavailable:
            return "unavailable"
        case .available:
            return "available"
        case .active:
            return "active"
        }
    }
}

/// Setting to change the precise home mode.
public protocol PreciseHomeSetting: class {
    /// Tells if the setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Supported modes.
    var supportedModes: Set<PreciseHomeMode> { get }

    /// Current precise home mode setting.
    var mode: PreciseHomeMode { get set }
}

/// Peripheral managing precise home.
///
/// This peripheral can be retrieved by:
/// ```
/// device.getPeripheral(Peripherals.preciseHome)
/// ```
public protocol PreciseHome: Peripheral {
    /// Precise home setting.
    var setting: PreciseHomeSetting { get }

    /// Actual state of precise home.
    var state: PreciseHomeState { get }
}

/// :nodoc:
/// PreciseHome description
@objc(GSPreciseHomeDesc)
public class PreciseHomeDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = PreciseHome
    public let uid = PeripheralUid.preciseHome.rawValue
    public let parent: ComponentDescriptor? = nil
}

// MARK: - objc compatibility

/// Setting to change the precise home mode
/// - Note: this protocol is for Objective-C compatibility only.
@objc public protocol GSPreciseHomeSetting {
    /// Tells if a setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Precise home mode setting.
    var mode: PreciseHomeMode { get set }

    /// Checks if a mode is supported.
    ///
    /// - Parameter mode: mode to check
    /// - Returns: `true` if the mode is supported
    func isModeSupported(_ mode: PreciseHomeMode) -> Bool
}

/// Peripheral managing precise home.
/// - Note: this protocol is for Objective-C compatibility only.
@objc public protocol GSPreciseHome {
    /// Precise home setting.
    @objc(setting)
    var gsSetting: GSPreciseHomeSetting { get }

    /// Actual precise home state.
    var state: PreciseHomeState { get }
}
