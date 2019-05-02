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

/// Access point indoor/outdoor environment modes.
@objc(GSEnvironment)
public enum Environment: Int, CustomStringConvertible {
    /// Wifi access point is configured for indoor use.
    case indoor
    /// Wifi access point is configured for outdoor use.
    case outdoor

    /// Debug description.
    public var description: String {
        switch self {
        case .indoor:   return "indoor"
        case .outdoor:  return "outdoor"
        }
    }
}

/// Wifi access point channel selection mode.
@objc(GSChannelSelectionMode)
public enum ChannelSelectionMode: Int, CustomStringConvertible {
    /// Channel has been selected manually.
    case manual
    /// Channel has been selected manually.
    case auto2_4GhzBand
    /// Channel has been selected automatically on the 5 GHz band.
    case auto5GhzBand
    /// Channel has been selected automatically on either the 2.4 or the 5 Ghz band.
    case autoAnyBand

    /// Debug description.
    public var description: String {
        switch self {
        case .manual:           return "manual"
        case .auto2_4GhzBand:   return "auto2.4GhzBand"
        case .auto5GhzBand:     return "auto5GhzBand"
        case .autoAnyBand:      return "autoAnyBand"
        }
    }
}

///  Wifi access point security mode.
@objc(GSSecurityMode)
public enum SecurityMode: Int, CustomStringConvertible {
    /// Access point is open and allows connection without any security check.
    case open
    /// Access point is secured using WPA2 authentication and requires a password for connection.
    case wpa2Secured

    /// Debug description.
    public var description: String {
        switch self {
        case .open:         return "open"
        case .wpa2Secured:  return "wpa2Secured"

        }
    }
}

/// Setting providing access to the Wifi access point environment setup.
@objc(GSEnvironmentSetting)
public protocol EnvironmentSetting {
    /// Tells if the setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Tells whether the setting can be altered by the application.
    ///
    /// Depending on the device, the current environment setup may not be changed.
    /// For instance, on remote control devices, the environment is hard wired to the currently
    /// or most recently connected drone, if any, and cannot be changed by the application.
    var mutable: Bool { get }

    /// Current environment mode of the access point.
    ///
    /// - Note: Altering this setting may change the set of available channels, and even result in a device
    /// disconnection since the channel currently in use might not be allowed with the new environment setup.
    var value: Environment { get set }
}

/// Setting providing access to the Wifi access point security setup.
public protocol SecurityModeSetting {
    /// Tells if the setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Access point current security mode.
    var mode: SecurityMode { get }

    /// Sets the security mode to `.open`, disabling any security checks.
    ///
    /// - Note: If the `.open` mode is not supported this function do nothing (see `supportedModes`).
    func open()

    /// Sets the security mode to `.wpa2Secured`, and secures connection to the access point using a password.
    /// Password validation is checked first (see `WifiPasswordUtil.isValid`, and nothing is done if password
    /// is not valid.
    ///
    /// - Note: If the `.wpa2Secured` mode is not supported this function do nothing (see `supportedModes`).
    ///
    ///  - Parameter password: password to secure the access point with
    ///  - Returns: `true` if password is valid, `false` otherwise
    func secureWithWpa2(password: String) -> Bool

    /// Supported modes.
    var supportedModes: Set<SecurityMode> { get }
}

/// Class with a static function to validate the syntax of a password.
@objcMembers
@objc(GSWifiPasswordUtil)
public class WifiPasswordUtil: NSObject {

    /// Regular expression in order to check the password validity.
    public static let passwordPattern = "^[\\x20-\\x7E]{8,63}$"

    /// Checks wifi password validity.
    ///
    /// - Note: A valid wifi password contains from 8 to 63 printable ASCII characters.
    /// - Parameter password: the password to validate
    /// - Returns: `true` if password is valid, `false` otherwise
    public static func isValid(_ password: String) -> Bool {
        return password.range(of: passwordPattern, options: .regularExpression) != nil
    }

    /// Private constructor for utility class.
    private override init() {}
}

/// Setting providing access to the Wifi access point channel setup.
public protocol ChannelSetting {
    /// Tells if the setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Current selection mode of the access point channel.
    var selectionMode: ChannelSelectionMode { get }

    /// Set of channels to which the access point may be configured.
    var availableChannels: Set<WifiChannel> { get }

    /// Access point's current channel.
    var channel: WifiChannel { get }

    /// Changes the access point current channel.
    ///
    /// - Parameter channel: new channel to use
    func select(channel: WifiChannel)

    /// Tells whether automatic channel selection on any frequency band is available.
    ///
    /// Some devices, for instance remote controls, don't support auto-selection.
    ///
    /// - Returns: `true` if `autoSelect()` can be called
    func canAutoSelect() -> Bool

    /// Requests the device to select the most appropriate channel for the access point automatically.
    ///
    /// The device will run its auto-selection process and eventually may change the current channel.
    /// The device will also remain in this auto-selection mode, that is, it will run auto-selection to setup
    /// the channel on subsequent boots, until the application selects a channel manually (with `select(channel:)`)
    func autoSelect()

    /// Tells whether automatic channel selection on a given frequency band is available.
    ///
    /// Depending on the country and environment setup, and the currently allowed channels, some auto-selection
    /// modes may not be available to the application.
    /// Also, some devices, for instance remote controls, don't support auto-selection.
    ///
    /// - Parameter band: the frequency band
    /// - Returns: `true` if `autoSelect()` can be called
    func canAutoSelect(onBand band: Band) -> Bool

    /// Requests the device to select the most appropriate channel for the access point automatically.
    ///
    /// The device will run its auto-selection process and eventually may change the current channel.
    /// The device will also remain in this auto-selection mode, that is, it will run auto-selection to setup
    /// the channel on subsequent boots, until the application selects a channel manually (with `select(channel:)`)
    ///
    /// - Parameter band: the frequency band on which the automatic selection should be done
    func autoSelect(onBand band: Band)
}

/// Wifi access point peripheral interface.
///
/// Allows to configure various parameters of the device's Wifi access point, such as:
/// - Environment (indoor/outdoor) setup
/// - Country
/// - Channel
/// - SSID
/// - Security
///
/// This peripheral can be retrieved by:
/// ```
/// drone.getPeripheral(Peripherals.wifiAccessPoint)
/// ```
public protocol WifiAccessPoint: Peripheral {

    /// Access point indoor/outdoor environment setting.
    ///
    /// - Note: Altering this setting may change the set of available channels, and even result in a device
    /// disconnection since the channel currently in use might not be allowed with the new environment setup.
    var environment: EnvironmentSetting { get }

    /// Access point country setting.
    ///
    /// The country can only be configured to one of the `availableCountries`. The country is a two-letter string,
    /// as ISO 3166-1-alpha-2 code.
    /// - Note: Altering this setting may change the set of available channels, and even result in a device
    /// disconnection since the channel currently in use might not be allowed with the new country setup.
    var isoCountryCode: StringSetting { get }

    /// `true` if a country has been automatically selected by the drone AND can be modified, `false` otherwise.
    var defaultCountryUsed: Bool { get }

    /// Set of countries to which the access point may be configured.
    var availableCountries: Set<String> { get }

    /// Access point channel setting.
    ///
    /// - Note: Changing the channel (either manually or through auto-selection) may result in a device disconnection.
    var channel: ChannelSetting { get }

    /// Access point Service Set IDentifier (SSID) setting.
    var ssid: StringSetting { get }

    /// Access point security setting.
    ///
    /// - Note: The device needs to be rebooted for the access point security to effectively change.
    var security: SecurityModeSetting { get }
}

/// :nodoc:
/// Wifi access point description
@objc(GSWifiAccessPointDesc)
public class WifiAccessPointDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = WifiAccessPoint
    public let uid = PeripheralUid.wifiAccessPoint.rawValue
    public let parent: ComponentDescriptor? = nil
}

// MARK: Objective-C API

/// Setting providing access to the Wifi access point channel setup.
///
/// - Note: This protocol is for Objective-C only. Swift must use the protocol `ChannelSetting`.
@objc
public protocol GSChannelSetting {
    /// Tells if the setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Current selection mode of the access point channel.
    var selectionMode: ChannelSelectionMode { get }

    /// Set of raw values of channels to which the access point may be configured.
    var availableChannelsAsInt: Set<Int> { get }

    /// Access point's current channel.
    var channel: WifiChannel { get }

    /// Changes the access point current channel.
    ///
    /// - Parameter channel: new channel to use
    func select(channel: WifiChannel)

    /// Tells whether automatic channel selection on any frequency band is available
    ///
    /// Some devices, for instance remote controls, don't support auto-selection.
    ///
    /// - Returns: `true` if `autoSelect()` can be called
    func canAutoSelect() -> Bool

    /// Requests the device to select the most appropriate channel for the access point automatically.
    ///
    /// The device will run its auto-selection process and eventually may change the current channel.
    /// The device will also remain in this auto-selection mode, that is, it will run auto-selection to setup
    /// the channel on subsequent boots, until the application selects a channel manually (with `select(channel:)`)
    func autoSelect()

    /// Tells whether automatic channel selection on a given frequency band is available.
    ///
    /// Depending on the country and environment setup, and the currently allowed channels, some auto-selection
    /// modes may not be available to the application.
    /// Also, some devices, for instance remote controls, don't support auto-selection.
    ///
    /// - Parameter band: the frequency band
    /// - Returns: `true` if `autoSelect()` can be called
    func canAutoSelect(onBand band: Band) -> Bool

    /// Requests the device to select the most appropriate channel for the access point automatically.
    ///
    /// The device will run its auto-selection process and eventually may change the current channel.
    /// The device will also remain in this auto-selection mode, that is, it will run auto-selection to setup
    /// the channel on subsequent boots, until the application selects a channel manually (with `select(channel:)`)
    ///
    /// - Parameter band: the frequency band on which the automatic selection should be done
    func autoSelect(onBand band: Band)
}

/// Setting providing access to the Wifi access point security setup.
/// - Note: This protocol is for Objective-C compatibility only.
@objc public protocol GSSecurityModeSetting {
    /// Tells if the setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Access point current security mode.
    var mode: SecurityMode { get }

    /// Sets the security mode to `.open`, disabling any security checks.
    ///
    /// - Note: If the `.open` mode is not supported this function do nothing (see `supportedModes`).
    func open()

    /// Sets the security mode to `.wpa2Secured`, and secures connection to the access point using a password.
    ///
    /// - Note: if the `.wpa2Secured` mode is not supported this function do nothing (see `supportedModes`).
    ///
    /// - Parameter password: password to secure the access point with
    /// - Returns: `true` if password is valid, `false` otherwise
    func secureWithWpa2(password: String) -> Bool

    /// Tells if a mode is supported.
    ///
    /// - Parameter mode: mode to check
    /// - Returns: `true` if the mode is supported
    func isModeSupported(_ mode: SecurityMode) -> Bool
}

/// Wifi access point peripheral interface.
///
/// Allows to configure various parameters of the device's Wifi access point, such as:
/// - Environment (indoor/outdoor) setup
/// - Country
/// - Channel
/// - SSID
/// - Security
///
/// This peripheral can be retrieved by:
/// ```
/// (id<GSWifiAccessPoint>) [drone getPeripheral:GSPeripherals.wifiAccessPoint]
/// ```
/// - note: this protocol is for Objective-C only. Swift must use the protocol `ChannelSetting`
@objc
public protocol GSWifiAccessPoint: Peripheral {

    /// Access point indoor/outdoor environment setting.
    ///
    /// - Note: Altering this setting may change the set of available channels, and even result in a device
    /// disconnection since the channel currently in use might not be allowed with the new environment setup.
    ///
    /// - Note: If in the App's configuration, the flag `GroundSdk / autoSelectWifiCountry` is enabled, this setting is
    /// set to outdoor and cannot be modified.
    var environment: EnvironmentSetting { get }

    /// Access point country setting.
    ///
    /// The country can only be configured to one of the `availableCountries`. The country is a two-letter string,
    /// as ISO 3166-1-alpha-2 code.
    /// - Note: Altering this setting may change the set of available channels, and even result in a device
    /// disconnection since the channel currently in use might not be allowed with the new country setup.
    ///
    /// - Note: If in the App's configuration, the flag `GroundSdk / autoSelectWifiCountry` is enabled, this setting
    /// cannot be modified (the country is based on the geolocation of the controller).
    var isoCountryCode: StringSetting { get }

    /// Set of raw values of countries to which the access point may be configured.
    @objc(availableCountries)
    var gsAvailableCountries: Set<String> { get }

    /// Access point channel setting.
    ///
    /// - Note: Changing the channel (either manually or through auto-selection) may result in a device disconnection.
    @objc(channel)
    var gsChannel: GSChannelSetting { get }

    /// Access point Service Set IDentifier (SSID) setting.
    ///
    /// - Note: The device needs to be rebooted for the access point SSID to effectively change.
    var ssid: StringSetting { get }

    /// Access point security setting.
    ///
    /// - Note: The device needs to be rebooted for the access point security to effectively change.
    @objc(security)
    var gsSecurity: GSSecurityModeSetting { get }
}
