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
import GroundSdk

/// Wifi access point base class and wifi scanner component controller for ArDrone3 message based drones
class WifiAccessPointController: DeviceComponentController {

    /// Wifi access point component
    var wifiAccessPoint: WifiAccessPointCore!

    /// Wifi scanner component
    var wifiScanner: WifiScannerCore!

    /// Map of occupation rate, by channel
    var scannedChannels = [WifiChannel: Int]()

    /// Current access point environment
    var environment: Environment?

    /// Set of channels currently available for outdoor mode use
    var outdoorChannels: Set<WifiChannel> = []

    /// Set of channels currently available for indoor mode use
    var indoorChannels: Set<WifiChannel> = []

    // Current access point country
    var country = "" {
        didSet {
            if GroundSdkConfig.sharedInstance.autoSelectWifiCountry {
                // reduce the available country list (only the current country must be present)
                availableCountries = Set([country])
            }
            wifiAccessPoint.update(isoCountryCode: country)
        }
    }

    /// Set of available countries
    var availableCountries =  Set<String>() {
        didSet {
            wifiAccessPoint.update(availableCountries: availableCountries)
            checkDefaultCountryUsed()
        }
    }

    /// True when the access point is in automatic country selection mode, otherwise false
    var automaticCountrySelectionEnabled = false {
        didSet {
            checkDefaultCountryUsed()
        }
    }

    /// Reverse geocoder monitor
    private var reverseGeocoderMonitor: MonitorCore?
    /// Reverse geocoder Utility
    private var reverseGeocoderUtility: ReverseGeocoderUtilityCore?

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        wifiScanner = WifiScannerCore(store: deviceController.device.peripheralStore, backend: self)
        wifiAccessPoint = WifiAccessPointCore(store: deviceController.device.peripheralStore, backend: self)
    }

    /// Drone is connected
    override func didConnect() {
        wifiScanner.publish()
        wifiAccessPoint.publish()
        // Checks if the App is in the autoSelectWifiCountry mode :
        // - if Yes, the reverseGeocoder utility will define the country. Furthermore, the Environement is forced to
        // `outdoor'.
        if GroundSdkConfig.sharedInstance.autoSelectWifiCountry {
            reverseGeocoderUtility = deviceController.engine.utilities.getUtility(Utilities.reverseGeocoder)
            // Be sure that the environement is .outdoor
            if environment != .outdoor {
                _ = sendOutdoorCommand(outdoor: true)
            }
            wifiAccessPoint.update(environmentMutability: false)

            // reduce the available country list (only the current country must be present)
            availableCountries = Set([country])

            // Monitor the reverseGeocoder
            reverseGeocoderMonitor = reverseGeocoderUtility?
                .startReverseGeocoderMonitoring { [unowned self] placemark in
                    if let isoCountryCode = placemark?.isoCountryCode, isoCountryCode != self.country {
                        _ = self.sendSetCountryCommand(isoCountry: isoCountryCode)
                    }
            }
        }
    }

    /// Drone is disconnected
    override func didDisconnect() {
        wifiScanner.unpublish()
        wifiAccessPoint.unpublish()
        reverseGeocoderMonitor?.stop()
        reverseGeocoderMonitor = nil
        // reset to default
        country = ""
        availableCountries = []
        automaticCountrySelectionEnabled = false
        environment = nil
        scannedChannels = [:]
        outdoorChannels = []
        indoorChannels = []
    }

    /// Checks if a country has been selected automatically and can be edited. The flag `defaultCountryUsed` is updated
    /// according to.
    ///
    /// - Note: It is not possible to change the country in some cases to comply with local legislation. Depending on
    /// the class of the device, the list is constrained by code at the engine level (see `countriesWithLockRule`
    /// for ARDrone3) or restricted directly by the drone in the received list of available countries
    /// (see `WifiFeatureWifiAccessPoint`).
    private func checkDefaultCountryUsed() {
        let defaultCountryUsed =  automaticCountrySelectionEnabled && availableCountries.count > 1
        wifiAccessPoint.update(defaultCountryUsed: defaultCountryUsed)
    }

    // MARK: - Send Commands - Can be overriden in the wifiAccess drone class

    ///  Set wifi indoor/outdoor mode.
    ///
    /// - Parameter outdoor: true if it should use outdoor wifi settings, false otherwise
    /// - Returns: true if the command has been sent
    func sendOutdoorCommand(outdoor: Bool) -> Bool { return false }
    /// Set the country for Wifi products.
    ///
    /// - Parameter isoCountry: Country code with ISO 3166 format
    func sendSetCountryCommand(isoCountry: String) -> Bool { return false }
    /// Set the product name (SSID for Wifi products)
    ///
    /// - Parameter name: product name (SSID)
    /// - Returns: true if the command has been sent
    func sendProductNameCommand(name: String) -> Bool { return false }
    /// Set wifi security type.
    ///
    /// - Parameters:
    ///   - security: security mode
    ///   - password: password used to secure the access point, nil for .open security mode
    /// - Returns: true if the command has been sent
    func sendSetSecurityCommand(security: SecurityMode, password: String?) -> Bool { return false }
    /// Select channel of chosen band to put the drone's access point on this channel.
    ///
    /// - Parameter channel: the chosen channel
    /// - Returns: true if the command has been sent
    func sendSetChannelCommand(channel: WifiChannel) -> Bool { return false }
    /// Requests auto-selection of the most appropriate access point channel
    ///
    /// - Parameter band: frequency band to restrict auto-selection to, nil to allow any band
    /// - Returns: true if the command has been sent
    func sendAutoSelectChannelCommand(onBand band: Band?) -> Bool { return false }
    /// Starts scanning channels occupation rate.
    ///
    /// - Returns: true if the command has been sent
    func sendStartScanCommand() -> Bool { return false }
}

/// Wifi access point backend implementation.
extension WifiAccessPointController: WifiAccessPointBackend {

    func set(environment: Environment) -> Bool {
        switch environment {
        case .indoor:
            return sendOutdoorCommand(outdoor: false)
        case .outdoor:
            return sendOutdoorCommand(outdoor: true)
        }
    }

    func set(country: String) -> Bool {
        return sendSetCountryCommand(isoCountry: country)
    }

    func set(ssid: String) -> Bool {
        return sendProductNameCommand(name: ssid)
    }

    func set(security: SecurityMode, password: String?) -> Bool {
        return sendSetSecurityCommand(security: security, password: password)
    }

    func select(channel: WifiChannel) -> Bool {
        return sendSetChannelCommand(channel: channel)
    }

    func autoSelectChannel(onBand band: Band?) -> Bool {
        return sendAutoSelectChannelCommand(onBand: band)
    }
}

/// Wifi scanner backend implementation.
/// Can be overriden in the wifiAccess drone class.
extension WifiAccessPointController: WifiScannerBackend {
    func startScan() {
        if !wifiScanner.scanning {
            scannedChannels.removeAll()
            _ = sendStartScanCommand()
            wifiScanner.update(scannedChannels: scannedChannels)
                .update(scanning: true)
                .notifyUpdated()
        }
    }

    func stopScan() {
        if wifiScanner.scanning {
            scannedChannels.removeAll()
            wifiScanner.update(scannedChannels: scannedChannels)
                .update(scanning: false)
                .notifyUpdated()
        }
    }
}
