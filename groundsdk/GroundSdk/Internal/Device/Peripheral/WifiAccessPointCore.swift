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

/// Wifi access point backend
public protocol WifiAccessPointBackend: class {

    /// Sets the access point environment
    ///
    /// - Parameter environment: new environment
    /// - Returns: true if the value could successfully be set or sent to the device, false otherwise
    func set(environment: Environment) -> Bool

    /// Sets the access point country
    ///
    /// - Parameter country: new country
    /// - Returns: true if the value could successfully be set or sent to the device, false otherwise
    func set(country: String) -> Bool

    /// Sets the access point ssid
    ///
    /// - Parameter ssid: new ssid
    /// - Returns: true if the value could successfully be set or sent to the device, false otherwise
    func set(ssid: String) -> Bool

    /// Sets the access point security
    ///
    /// - Parameters:
    ///   - security: new security mode
    ///   - password: password used to secure the access point, nil for `.open` security mode
    /// - Returns: true if the value could successfully be set or sent to the device, false otherwise
    func set(security: SecurityMode, password: String?) -> Bool

    /// Sets the access point channel
    ///
    /// - Parameter channel: new channel
    /// - Returns: true if the value could successfully be set or sent to the device, false otherwise
    func select(channel: WifiChannel) -> Bool

    /// Requests auto-selection of the most appropriate access point channel
    ///
    /// - Parameter band: frequency band to restrict auto-selection to, nil to allow any band
    /// - Returns: true if the value could successfully be set or sent to the device, false otherwise
    func autoSelectChannel(onBand band: Band?) -> Bool
}

/// Internal implementation of the Wifi access point
public class WifiAccessPointCore: PeripheralCore, WifiAccessPoint {

    public var environment: EnvironmentSetting {
        return environmentSetting
    }

    public var isoCountryCode: StringSetting {
        return countrySetting
    }

    public private(set) var defaultCountryUsed = false

    public var ssid: StringSetting {
        return ssidSetting
    }

    public var security: SecurityModeSetting {
        return securitySetting
    }

    public var channel: ChannelSetting {
        return channelSetting
    }

    /// Core implementation of the environment setting
    private var environmentSetting: EnvironmentSettingCore!

    /// Core implementation of the country setting
    private var countrySetting: StringSettingCore!

    /// Core implementation of the ssid setting
    private var ssidSetting: StringSettingCore!

    /// Core implementation of the channel setting
    private var channelSetting: ChannelSettingCore!

    /// Core implementation of the security setting
    private var securitySetting: SecurityModeSettingCore!

    public var availableCountries: Set<String> {
        // add the current country
        var availableCountries = _availableCountries
        if isoCountryCode.value != "" {
            availableCountries.insert(isoCountryCode.value)
        }
        return availableCountries
    }

    /// Available countries
    private var _availableCountries: Set<String> = []

    /// Implementation backend
    private unowned let backend: WifiAccessPointBackend

    /// Constructor
    ///
    /// - Parameters:
    ///   - store: store where this peripheral will be stored
    ///   - backend: wifi scanner backend
    public init(store: ComponentStoreCore, backend: WifiAccessPointBackend) {
        self.backend = backend
        super.init(desc: Peripherals.wifiAccessPoint, store: store)
        environmentSetting = EnvironmentSettingCore(didChangeDelegate: self) { [unowned self] environment in
            return self.backend.set(environment: environment)
        }
        countrySetting = StringSettingCore(didChangeDelegate: self) { [unowned self] country in
            return self._availableCountries.contains(country) && backend.set(country: country)
        }
        ssidSetting = StringSettingCore(didChangeDelegate: self) { [unowned self] ssid in
            return self.backend.set(ssid: ssid)
        }
        channelSetting = ChannelSettingCore(didChangeDelegate: self) { [unowned self] settingValue in
            switch settingValue {
            case .select(let channel):
                return self.backend.select(channel: channel)
            case .autoSelectChannel(let band):
                return self.backend.autoSelectChannel(onBand: band)
            }
        }
        securitySetting = SecurityModeSettingCore(didChangeDelegate: self) { [unowned self] settingValue in
            switch settingValue {
            case .open:
                return self.backend.set(security: .open, password: nil)
            case .wpa2(let password):
                return self.backend.set(security: .wpa2Secured, password: password)
            }
       }
    }
}

/// Backend callback methods
extension WifiAccessPointCore {
    /// Changes available countries.
    ///
    /// - Parameter newValue: new set of available countries
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(availableCountries newValue: Set<String>) -> WifiAccessPointCore {
        if _availableCountries != newValue {
            markChanged()
            _availableCountries = newValue
        }
        return self
    }

    /// Changes current country.
    ///
    /// - Parameter newValue: new country
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(isoCountryCode newValue: String) -> WifiAccessPointCore {
        if countrySetting.update(value: newValue) {
            markChanged()
        }
        return self
    }

    /// Changes defaultCountryUsed.
    ///
    /// - Parameter defaultCountryUsed: new defaultCountryUsed value
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(defaultCountryUsed newValue: Bool) -> WifiAccessPointCore {
        if defaultCountryUsed != newValue {
            defaultCountryUsed = newValue
            markChanged()
        }
        return self
    }

    /// Changes current ssid.
    ///
    /// - Parameter newValue: new ssid
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(ssid newValue: String) -> WifiAccessPointCore {
        if ssidSetting.update(value: newValue) {
            markChanged()
        }
        return self
    }

    /// Changes current environment.
    ///
    /// - Parameter newValue: new environment
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(environment newValue: Environment) -> WifiAccessPointCore {
        if environmentSetting.update(value: newValue) {
            markChanged()
        }
        return self
    }

    /// Changes current environment mutability.
    ///
    /// - Parameter newValue: new environment mutability
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(environmentMutability newValue: Bool) -> WifiAccessPointCore {
        if environmentSetting.update(mutable: newValue) {
            markChanged()
        }
        return self
    }

    /// Changes current available channels.
    ///
    /// - Parameter newValue: new available channels
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(availableChannels newValue: Set<WifiChannel>) -> WifiAccessPointCore {
        if channelSetting.update(availableChannels: newValue) {
            markChanged()
        }
        return self
    }

    /// Changes current channel.
    ///
    /// - Parameter newValue: new channel
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(channel newValue: WifiChannel) -> WifiAccessPointCore {
        if channelSetting.update(channel: newValue) {
            markChanged()
        }
        return self
    }

    /// Changes whether channel auto selection is supported.
    ///
    /// - Parameter newValue: new value
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(autoSelectSupported newValue: Bool) -> WifiAccessPointCore {
        if channelSetting.update(autoSelectSupported: newValue) {
            markChanged()
        }
        return self
    }

    /// Changes current selection mode.
    ///
    /// - Parameter newValue: new selection mode
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(selectionMode newValue: ChannelSelectionMode) -> WifiAccessPointCore {
        if channelSetting.update(selectionMode: newValue) {
            markChanged()
        }
        return self
    }

    /// Changes current security.
    ///
    /// - Parameter newValue: new security mode
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(security newValue: SecurityMode) -> WifiAccessPointCore {
        if securitySetting.update(mode: newValue) {
            markChanged()
        }
        return self
    }

    /// Changes supported security modes
    ///
    /// - Parameter supportedModes: new supported security modes
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(supportedModes newSupportedMode: Set<SecurityMode>) -> WifiAccessPointCore {
        if securitySetting.update(supportedModes: newSupportedMode) {
            markChanged()
        }
        return self
    }

    /// Cancels all pending settings rollbacks.
    ///
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func cancelSettingsRollback() -> WifiAccessPointCore {
        environmentSetting.cancelRollback { markChanged() }
        countrySetting.cancelRollback { markChanged() }
        ssidSetting.cancelRollback { markChanged() }
        channelSetting.cancelRollback { markChanged() }
        securitySetting.cancelRollback { markChanged() }
        return self
    }
}

/// Extension of WifiAccessPointCore that conforms to ObjC protocol GSWifiAccessPoint
extension WifiAccessPointCore: GSWifiAccessPoint {

    public var gsAvailableCountries: Set<String> {
        return Set(availableCountries.map { $0 })
    }

    public var gsChannel: GSChannelSetting {
        return channelSetting
    }

    public var gsSecurity: GSSecurityModeSetting {
        return securitySetting
    }
}
