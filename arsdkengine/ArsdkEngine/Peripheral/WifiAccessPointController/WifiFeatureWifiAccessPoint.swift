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

/// Wifi access point and wifi scanner component controller for Wifi feature based drones
class WifiFeatureWifiAccessPoint: WifiAccessPointController {

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureWifiUid {
            ArsdkFeatureWifi.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCommonSettingsstateUid {
            ArsdkFeatureCommonSettingsstate.decode(command, callback: self)
        }
    }

    // MARK: - Send Commands
    override func sendOutdoorCommand(outdoor: Bool) -> Bool {
        if outdoor {
            sendCommand(ArsdkFeatureWifi.setEnvironmentEncoder(environment: .outdoor))
        } else {
            sendCommand(ArsdkFeatureWifi.setEnvironmentEncoder(environment: .indoor))
        }
        return true
    }

    override func sendSetCountryCommand(isoCountry: String) -> Bool {
        sendCommand(ArsdkFeatureWifi.setCountryEncoder(selectionMode: .manual, code: isoCountry))
        return true
    }

    override func sendProductNameCommand(name: String) -> Bool {
        sendCommand(ArsdkFeatureCommonSettings.productNameEncoder(name: name))
        return true
    }

    override func sendSetSecurityCommand(security: SecurityMode, password: String?) -> Bool {
        switch security {
        case .open:
            sendCommand(ArsdkFeatureWifi.setSecurityEncoder(type: .open, key: "", keyType: .plain))
        case .wpa2Secured:
            // can force unwrapp because password is not nil when security is wpa2 secured
            sendCommand(ArsdkFeatureWifi.setSecurityEncoder(type: .wpa2, key: password!, keyType: .plain))
        }
        return true
    }

    override func sendSetChannelCommand(channel: WifiChannel) -> Bool {
        sendCommand(ArsdkFeatureWifi.setApChannelEncoder(
            type: .manual,
            band: channel.getBand().toArsdkBand(),
            channel: UInt(channel.getChannelId())))
        return true
    }

    override func sendAutoSelectChannelCommand(onBand band: Band?) -> Bool {
        var selectionType = ArsdkFeatureWifiSelectionType.autoAll
        if let band = band {
            switch band {
            case .band_2_4_Ghz:
                selectionType = .auto2_4Ghz
            case .band_5_Ghz:
                selectionType = .auto5Ghz
            }
        }
        sendCommand(ArsdkFeatureWifi.setApChannelEncoder(
            type: selectionType,
            band: .band2_4Ghz,
            channel: 0))
        return true
    }

    override func sendStartScanCommand() -> Bool {
        sendCommand(ArsdkFeatureWifi.scanEncoder(
            bandBitField: Bitfield<ArsdkFeatureWifiBand>.of(.band2_4Ghz, .band5Ghz)))
        return true
    }
}

/// Wifi feature decode callback implementation
extension WifiFeatureWifiAccessPoint: ArsdkFeatureWifiCallback {
    func onScannedItem(ssid: String!, rssi: Int, band: ArsdkFeatureWifiBand, channel: UInt, listFlagsBitField: UInt) {
        if wifiScanner.scanning {
            let clearList = ArsdkFeatureGenericListFlagsBitField.isSet(.empty, inBitField: listFlagsBitField)
            if clearList {
                scannedChannels.removeAll()
            } else {
                if ArsdkFeatureGenericListFlagsBitField.isSet(.first, inBitField: listFlagsBitField) {
                    scannedChannels.removeAll()
                }

                if let channel = WifiChannel(failableFromArsdkBand: band, channelId: Int(channel)) {
                    let currentCount = scannedChannels[channel] ?? 0
                    if ArsdkFeatureGenericListFlagsBitField.isSet(.remove, inBitField: listFlagsBitField) {
                        scannedChannels[channel] = max(currentCount - 1, 0)
                    } else {
                        scannedChannels[channel] = currentCount + 1
                    }
                }
            }

            if clearList || ArsdkFeatureGenericListFlagsBitField.isSet(.last, inBitField: listFlagsBitField) {
                wifiScanner.update(scannedChannels: scannedChannels).notifyUpdated()

                // send again the scan command
                sendCommand(
                    ArsdkFeatureWifi.scanEncoder(
                        bandBitField: Bitfield<ArsdkFeatureWifiBand>.of(.band2_4Ghz, .band5Ghz)))
            }
        }
    }

    func onAuthorizedChannel(
        band: ArsdkFeatureWifiBand, channel: UInt, environmentBitField: UInt, listFlagsBitField: UInt) {
        let clearList = ArsdkFeatureGenericListFlagsBitField.isSet(.empty, inBitField: listFlagsBitField)
        if clearList {
            indoorChannels.removeAll()
            outdoorChannels.removeAll()
        } else {
            if ArsdkFeatureGenericListFlagsBitField.isSet(.first, inBitField: listFlagsBitField) {
                indoorChannels.removeAll()
                outdoorChannels.removeAll()
            }

            if let channel = WifiChannel(failableFromArsdkBand: band, channelId: Int(channel)) {
                // add or remove it from the correct set
                if ArsdkFeatureWifiEnvironmentBitField.isSet(.indoor, inBitField: environmentBitField) {
                    if ArsdkFeatureGenericListFlagsBitField.isSet(.remove, inBitField: listFlagsBitField) {
                        indoorChannels.remove(channel)
                    } else {
                        indoorChannels.insert(channel)
                    }
                }
                if ArsdkFeatureWifiEnvironmentBitField.isSet(.outdoor, inBitField: environmentBitField) {
                    if ArsdkFeatureGenericListFlagsBitField.isSet(.remove, inBitField: listFlagsBitField) {
                        outdoorChannels.remove(channel)
                    } else {
                        outdoorChannels.insert(channel)
                    }
                }
            }
        }

        if let environment = environment,
            clearList || ArsdkFeatureGenericListFlagsBitField.isSet(.last, inBitField: listFlagsBitField) {
            switch environment {
            case .indoor:
                wifiAccessPoint.update(availableChannels: indoorChannels).notifyUpdated()
            case .outdoor:
                wifiAccessPoint.update(availableChannels: outdoorChannels).notifyUpdated()
            }
        }
    }

    func onApChannelChanged(type: ArsdkFeatureWifiSelectionType, band: ArsdkFeatureWifiBand, channel: UInt) {
        let selectionMode: ChannelSelectionMode
        switch type {
        case .autoAll:
            selectionMode = .autoAnyBand
        case .auto2_4Ghz:
            selectionMode = .auto2_4GhzBand
        case .auto5Ghz:
            selectionMode = .auto5GhzBand
        case .manual:
            selectionMode = .manual
        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown wifi selection type, skipping this event.")
            return
        }
        wifiAccessPoint.update(selectionMode: selectionMode)
            .update(channel: WifiChannel(fromArsdkBand: band, channelId: Int(channel)))
            .notifyUpdated()
    }

    func onSecurityChanged(type: ArsdkFeatureWifiSecurityType, key: String!, keyType: ArsdkFeatureWifiSecurityKeyType) {
        switch type {
        case .open:
            wifiAccessPoint.update(security: .open).notifyUpdated()
        case .wpa2:
            wifiAccessPoint.update(security: .wpa2Secured).notifyUpdated()
        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown wifi security type, skipping this event.")
            return
        }
    }

    func onSupportedSecurityTypes(typesBitField: UInt) {
        var supportedModes = Set<SecurityMode>()
        ArsdkFeatureWifiSecurityTypeBitField.forAllSet(in: typesBitField) { securityType in
            switch securityType {
            case .open :
                supportedModes.insert(.open)
            case .wpa2 :
                supportedModes.insert(.wpa2Secured)
            case .sdkCoreUnknown :
                ULog.w(.tag, "Unknown SupportedSecurityType, skipping this event.")
            }
        }
        wifiAccessPoint.update(supportedModes: supportedModes).notifyUpdated()
    }

    func onCountryChanged(selectionMode: ArsdkFeatureWifiCountrySelection, code: String!) {
        country = code
        automaticCountrySelectionEnabled = (selectionMode == .auto)
        sendCommand(ArsdkFeatureWifi.updateAuthorizedChannelsEncoder())
        wifiAccessPoint.notifyUpdated()
    }

    func onEnvironmentChanged(environment: ArsdkFeatureWifiEnvironment) {
        switch environment {
        case .indoor:
            self.environment = .indoor
            wifiAccessPoint.update(availableChannels: indoorChannels)
        case .outdoor:
            self.environment = .outdoor
            wifiAccessPoint.update(availableChannels: outdoorChannels)
        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown wifi environment, skipping this event.")
            return
        }

        if let newEnvironment = self.environment {
            wifiAccessPoint.update(environment: newEnvironment).notifyUpdated()
        }
    }

    func onSupportedCountries(countries: String!) {
        // force all codes in uppercase and check thant each code is valid
        let acceptedIso = Locale.isoRegionCodes
        let trimCharSet = CharacterSet.whitespacesAndNewlines
        let countrySet: Set<String> = Set(
            countries.components(separatedBy: ";").map { $0.uppercased().trimmingCharacters(in: trimCharSet) }
                .filter { acceptedIso.contains($0) })
        // log errors if any
        if countries.count != countrySet.count {
            let rejectedCountries = countries.components(separatedBy: ";")
                .map { $0.uppercased().trimmingCharacters(in: trimCharSet) }.filter { !acceptedIso.contains($0) }
            ULog.w(.tag, "Unknown countries: \(rejectedCountries) or duplicates exist")
        }
        availableCountries = countrySet
        wifiAccessPoint.notifyUpdated()
    }
}

/// Common wifi state decode callback implementation
extension WifiFeatureWifiAccessPoint: ArsdkFeatureCommonSettingsstateCallback {

    func onProductNameChanged(name: String!) {
        wifiAccessPoint.update(ssid: name).notifyUpdated()
    }
}
