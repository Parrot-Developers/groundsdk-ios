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
import XCTest

@testable import ArsdkEngine
@testable import GroundSdk
import SdkCoreTesting

class WifiFeatureWifiAccessPointTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var wifiScanner: WifiScanner?
    var wifiScannerRef: Ref<WifiScanner>?
    var scannerChangeCnt = 0

    var wifiAccessPoint: WifiAccessPoint?
    var wifiAccessPointRef: Ref<WifiAccessPoint>?
    var accessPointCnt = 0

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        wifiScannerRef = drone.getPeripheral(Peripherals.wifiScanner) { [unowned self] wifiScanner in
            self.wifiScanner = wifiScanner
            self.scannerChangeCnt += 1
        }
        scannerChangeCnt = 0

        wifiAccessPointRef = drone.getPeripheral(Peripherals.wifiAccessPoint) { [unowned self] wifiAccessPoint in
            self.wifiAccessPoint = wifiAccessPoint
            self.accessPointCnt += 1
        }
        accessPointCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(wifiScanner, nilValue())
        assertThat(wifiAccessPoint, nilValue())

        connect(drone: drone, handle: 1)
        assertThat(wifiScanner, present())
        assertThat(scannerChangeCnt, `is`(1))
        assertThat(wifiAccessPoint, present())
        assertThat(accessPointCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(wifiScanner, nilValue())
        assertThat(scannerChangeCnt, `is`(2))
        assertThat(wifiAccessPoint, nilValue())
        assertThat(accessPointCnt, `is`(2))
    }

    func testScan() {
        connect(drone: drone, handle: 1)
        // check default values
        assertThat(wifiScanner!.scanning, `is`(false))
        WifiChannel.allCases.forEach {
            assertThat(wifiScanner!.getOccupationRate(forChannel: $0), `is`(0))
        }
        assertThat(scannerChangeCnt, `is`(1))

        // user starts scan
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.wifiScan(bandBitField: 3))
        wifiScanner!.startScan()

        assertThat(wifiScanner!.scanning, `is`(true))
        WifiChannel.allCases.forEach {
            assertThat(wifiScanner!.getOccupationRate(forChannel: $0), `is`(0))
        }
        assertThat(scannerChangeCnt, `is`(2))

        // user starts scan should do nothing
        wifiScanner!.startScan()

        assertThat(wifiScanner!.scanning, `is`(true))
        WifiChannel.allCases.forEach {
            assertThat(wifiScanner!.getOccupationRate(forChannel: $0), `is`(0))
        }
        assertThat(scannerChangeCnt, `is`(2))

        // check start scan while already scanning is no-op
        wifiScanner!.startScan()
        assertThat(wifiScanner!.scanning, `is`(true))
        WifiChannel.allCases.forEach {
            assertThat(wifiScanner!.getOccupationRate(forChannel: $0), `is`(0))
        }
        assertThat(scannerChangeCnt, `is`(2))

        // mock some scan results
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.wifiScannedItemEncoder(
            ssid: "A", rssi: 0, band: .band2_4Ghz, channel: 1,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))

        // assert that no change occurs until end of list is notified
        assertThat(wifiScanner!.scanning, `is`(true))
        WifiChannel.allCases.forEach {
            assertThat(wifiScanner!.getOccupationRate(forChannel: $0), `is`(0))
        }
        assertThat(scannerChangeCnt, `is`(2))

        // mock more scan results
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.wifiScannedItemEncoder(
            ssid: "B", rssi: 0, band: .band2_4Ghz, channel: 1, listFlagsBitField: 0))

        // notify end of list
        // since the user did not stop scan yet, this will trigger a new scan operation
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.wifiScan(bandBitField: 3))
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.wifiScannedItemEncoder(
            ssid: "C", rssi: 0, band: .band2_4Ghz, channel: 2,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))
        assertThat(wifiScanner!.scanning, `is`(true))
        assertThat(wifiScanner!.getOccupationRate(forChannel: .band_2_4_channel1), `is`(2))
        assertThat(wifiScanner!.getOccupationRate(forChannel: .band_2_4_channel2), `is`(1))
        WifiChannel.allCases.forEach {
            if $0 != .band_2_4_channel1 && $0 != .band_2_4_channel2 {
                assertThat(wifiScanner!.getOccupationRate(forChannel: $0), `is`(0))
            }
        }
        assertThat(scannerChangeCnt, `is`(3))

        // user stops scan
        wifiScanner!.stopScan()

        assertThat(wifiScanner!.scanning, `is`(false))
        WifiChannel.allCases.forEach {
            assertThat(wifiScanner!.getOccupationRate(forChannel: $0), `is`(0))
        }
        assertThat(scannerChangeCnt, `is`(4))

        //mock more scan results
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.wifiScannedItemEncoder(
            ssid: "D", rssi: 0, band: .band2_4Ghz, channel: 1, listFlagsBitField: 0))

        // notify end of list
        // since the user did stop scan, this won't trigger a new scan operation
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.wifiScannedItemEncoder(
            ssid: "E", rssi: 0, band: .band5Ghz, channel: 34,
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))

        // latest scan results should not be propagated to user
        assertThat(wifiScanner!.scanning, `is`(false))
        WifiChannel.allCases.forEach {
            assertThat(wifiScanner!.getOccupationRate(forChannel: $0), `is`(0))
        }
        assertThat(scannerChangeCnt, `is`(4))

        // user stops again should do nothing scan
        wifiScanner!.stopScan()

        assertThat(wifiScanner!.scanning, `is`(false))
        WifiChannel.allCases.forEach {
            assertThat(wifiScanner!.getOccupationRate(forChannel: $0), `is`(0))
        }
        assertThat(scannerChangeCnt, `is`(4))
    }

    func testEnvironment() {
        connect(drone: drone, handle: 1)

        // check default values
        assertThat(wifiAccessPoint!, environmentIs(.outdoor, updating: false, mutable: true))
        assertThat(accessPointCnt, `is`(1))

        // mock some available channels from low-level...
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.wifiAuthorizedChannelEncoder(
                band: .band2_4Ghz,
                channel: 1,
                environmentBitField: Bitfield<ArsdkFeatureWifiEnvironment>.of(.indoor, .outdoor),
            listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.wifiAuthorizedChannelEncoder(
                band: .band2_4Ghz,
                channel: 2,
                environmentBitField: Bitfield<ArsdkFeatureWifiEnvironment>.of(.outdoor),
                listFlagsBitField: 0))
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.wifiAuthorizedChannelEncoder(
                band: .band2_4Ghz,
                channel: 3,
                environmentBitField: Bitfield<ArsdkFeatureWifiEnvironment>.of(.indoor),
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))

        assertThat(accessPointCnt, `is`(1))
        // while environment is not received, available channels should only contain current channel
        assertThat(wifiAccessPoint!.channel.availableChannels, `is`([.band_2_4_channel1]))

        // mock initial environment from low-level
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.wifiEnvironmentChangedEncoder(environment: .indoor))
        assertThat(wifiAccessPoint!, environmentIs(.indoor, updating: false, mutable: true))
        assertThat(accessPointCnt, `is`(2))
        // ensure channels are from the indoor list
        assertThat(wifiAccessPoint!.channel.availableChannels, containsInAnyOrder(.band_2_4_channel1,
                                                                                  .band_2_4_channel3))

        // user change environment
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.wifiSetEnvironment(environment: .outdoor))
        wifiAccessPoint!.environment.value = .outdoor
        assertThat(wifiAccessPoint!, environmentIs(.outdoor, updating: true, mutable: true))
        assertThat(accessPointCnt, `is`(3))
        // ensure channels are still from the indoor list
        assertThat(wifiAccessPoint!.channel.availableChannels, containsInAnyOrder(.band_2_4_channel1,
                                                                                  .band_2_4_channel3))

        // mock response from low-level
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.wifiEnvironmentChangedEncoder(environment: .outdoor))
        assertThat(wifiAccessPoint!, environmentIs(.outdoor, updating: false, mutable: true))
        assertThat(accessPointCnt, `is`(4))
        // ensure channels are from the outdoor list
        assertThat(wifiAccessPoint!.channel.availableChannels, containsInAnyOrder(.band_2_4_channel1,
                                                                                  .band_2_4_channel2))
    }

    func testCountry() {
        connect(drone: drone, handle: 1)

        // check default values
        assertThat(wifiAccessPoint!, countryIs("", updating: false))
        assertThat(wifiAccessPoint!.availableCountries, empty())
        assertThat(accessPointCnt, `is`(1))

        // mock initial countries from low-level
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.wifiSupportedCountriesEncoder(countries: "FR;US;DE;ES"))
        assertThat(wifiAccessPoint!.availableCountries, containsInAnyOrder("FR", "US", "DE", "ES"))
        assertThat(wifiAccessPoint!, countryIs("", updating: false))
        assertThat(accessPointCnt, `is`(2))

        // mock country from low-level (should trigger an available channel request)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.wifiUpdateAuthorizedChannels())
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.wifiCountryChangedEncoder(selectionMode: .manual, code: "FR"))
        assertThat(wifiAccessPoint!.availableCountries, containsInAnyOrder("FR", "US", "DE", "ES"))
        assertThat(wifiAccessPoint!, countryIs("FR", updating: false))
        assertThat(accessPointCnt, `is`(3))

        // user changes country
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.wifiSetCountry(selectionMode: .manual, code: "DE"))
        wifiAccessPoint!.isoCountryCode.value = "DE"

        assertThat(wifiAccessPoint!.availableCountries, containsInAnyOrder("FR", "US", "DE", "ES"))
        assertThat(wifiAccessPoint!, countryIs("DE", updating: true))
        assertThat(accessPointCnt, `is`(4))

        // mock country update from low-level (should trigger an available channel request)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.wifiUpdateAuthorizedChannels())
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.wifiCountryChangedEncoder(selectionMode: .manual, code: "US"))
        assertThat(wifiAccessPoint!.availableCountries, containsInAnyOrder("FR", "US", "DE", "ES"))
        assertThat(wifiAccessPoint!, countryIs("US", updating: false))
        assertThat(accessPointCnt, `is`(5))
    }

    func testChannel() {
        connect(drone: drone, handle: 1)

        // check default values
        assertThat(wifiAccessPoint!, channelIs(.band_2_4_channel1, selectionMode: .manual, updating: false))
        assertThat(accessPointCnt, `is`(1))

        // mock some available channels from low-level...
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.wifiAuthorizedChannelEncoder(
                band: .band2_4Ghz,
                channel: 1,
                environmentBitField: Bitfield<ArsdkFeatureWifiEnvironment>.of(.indoor, .outdoor),
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.wifiAuthorizedChannelEncoder(
                band: .band2_4Ghz,
                channel: 2,
                environmentBitField: Bitfield<ArsdkFeatureWifiEnvironment>.of(.indoor, .outdoor),
                listFlagsBitField: 0))
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.wifiAuthorizedChannelEncoder(
                band: .band5Ghz,
                channel: 34,
                environmentBitField: Bitfield<ArsdkFeatureWifiEnvironment>.of(.indoor, .outdoor),
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))

        // then mock environment from low-level
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.wifiEnvironmentChangedEncoder(environment: .indoor))

        assertThat(wifiAccessPoint!, channelIs(.band_2_4_channel1, selectionMode: .manual, updating: false))
        assertThat(accessPointCnt, `is`(2))

        // user changes channel
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.wifiSetApChannel(type: .manual, band: .band5Ghz, channel: 34))
        wifiAccessPoint!.channel.select(channel: .band_5_channel34)
        assertThat(wifiAccessPoint!, channelIs(.band_5_channel34, selectionMode: .manual, updating: true))
        assertThat(accessPointCnt, `is`(3))

        // mock response from low level
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.wifiApChannelChangedEncoder(type: .manual, band: .band5Ghz, channel: 34))
        assertThat(wifiAccessPoint!, channelIs(.band_5_channel34, selectionMode: .manual, updating: false))
        assertThat(accessPointCnt, `is`(4))

        // user auto-selects channel on any band
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.wifiSetApChannel(
            type: .autoAll, band: .band2_4Ghz, channel: 0))
        wifiAccessPoint!.channel.autoSelect()
        assertThat(wifiAccessPoint!, channelIs(.band_5_channel34, selectionMode: .autoAnyBand, updating: true))
        assertThat(accessPointCnt, `is`(5))

        // mock response from low level
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.wifiApChannelChangedEncoder(
                type: .autoAll, band: .band2_4Ghz, channel: 2))
        assertThat(wifiAccessPoint!, channelIs(.band_2_4_channel2, selectionMode: .autoAnyBand, updating: false))
        assertThat(accessPointCnt, `is`(6))

        // user auto-selects channel on 2.4 Ghz band
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.wifiSetApChannel(
                type: .auto2_4Ghz, band: .band2_4Ghz, channel: 0))
        wifiAccessPoint!.channel.autoSelect(onBand: .band_2_4_Ghz)
        assertThat(wifiAccessPoint!, channelIs(.band_2_4_channel2, selectionMode: .auto2_4GhzBand, updating: true))
        assertThat(accessPointCnt, `is`(7))

        // mock response from low level
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.wifiApChannelChangedEncoder(
                type: .auto2_4Ghz, band: .band2_4Ghz, channel: 2))
        assertThat(wifiAccessPoint!, channelIs(.band_2_4_channel2, selectionMode: .auto2_4GhzBand, updating: false))
        assertThat(accessPointCnt, `is`(8))

        // user auto-selects channel on 5 Ghz band
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.wifiSetApChannel(
                type: .auto5Ghz, band: .band2_4Ghz, channel: 0))
        wifiAccessPoint!.channel.autoSelect(onBand: .band_5_Ghz)
        assertThat(wifiAccessPoint!, channelIs(.band_2_4_channel2, selectionMode: .auto5GhzBand, updating: true))
        assertThat(accessPointCnt, `is`(9))

        // mock response from low level
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.wifiApChannelChangedEncoder(
                type: .auto5Ghz, band: .band5Ghz, channel: 34))
        assertThat(wifiAccessPoint!, channelIs(.band_5_channel34, selectionMode: .auto5GhzBand, updating: false))
        assertThat(accessPointCnt, `is`(10))
    }

    func testAvailableChannels() {
        connect(drone: drone, handle: 1)

        // check default values
        assertThat(wifiAccessPoint!.channel.availableChannels, containsInAnyOrder(.band_2_4_channel1))
        assertThat(wifiAccessPoint!.environment.value, `is`(.outdoor))
        assertThat(accessPointCnt, `is`(1))

        // receive environment from low-level
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.wifiEnvironmentChangedEncoder(environment: .outdoor))

        assertThat(wifiAccessPoint!.channel.availableChannels, containsInAnyOrder(.band_2_4_channel1))
        assertThat(wifiAccessPoint!, channelIs(.band_2_4_channel1, selectionMode: .manual, updating: false))
        assertThat(accessPointCnt, `is`(1))

        // receive available channels
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.wifiAuthorizedChannelEncoder(
                band: .band2_4Ghz,
                channel: 1,
                environmentBitField: Bitfield<ArsdkFeatureWifiEnvironment>.of(.outdoor),
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.first)))
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.wifiAuthorizedChannelEncoder(
                band: .band2_4Ghz,
                channel: 2,
                environmentBitField: Bitfield<ArsdkFeatureWifiEnvironment>.of(.indoor, .outdoor),
                listFlagsBitField: 0))

        // ensure no update yet
        assertThat(wifiAccessPoint!.channel.availableChannels, containsInAnyOrder(.band_2_4_channel1))
        assertThat(wifiAccessPoint!, channelIs(.band_2_4_channel1, selectionMode: .manual, updating: false))
        assertThat(accessPointCnt, `is`(1))

        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.wifiAuthorizedChannelEncoder(
                band: .band5Ghz,
                channel: 34,
                environmentBitField: Bitfield<ArsdkFeatureWifiEnvironment>.of(.indoor),
                listFlagsBitField: 0))
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.wifiAuthorizedChannelEncoder(
                band: .band5Ghz,
                channel: 36,
                environmentBitField: Bitfield<ArsdkFeatureWifiEnvironment>.of(.indoor, .outdoor),
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))

        // available channels should only contain outdoor authorized channels (+ current channel)
        assertThat(wifiAccessPoint!.channel.availableChannels, `is`(
            [.band_2_4_channel1, .band_2_4_channel2, .band_5_channel36]))
        assertThat(accessPointCnt, `is`(2))

        // environment change from low-level
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.wifiEnvironmentChangedEncoder(environment: .indoor))
        // available channels should only contain indoor authorized channels (+ current channel)
        assertThat(wifiAccessPoint!.channel.availableChannels, `is`(
            [.band_2_4_channel1, .band_2_4_channel2, .band_5_channel34, .band_5_channel36]))
        assertThat(accessPointCnt, `is`(3))

        // channel change from low-level
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.wifiApChannelChangedEncoder(type: .manual, band: .band5Ghz, channel: 38))
        // available channels should only contain indoor authorized channels (+ current channel)
        assertThat(wifiAccessPoint!.channel.availableChannels, `is`(
            [.band_2_4_channel2, .band_5_channel34, .band_5_channel36, .band_5_channel38]))
        assertThat(accessPointCnt, `is`(4))

        // receive a new available channel
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.wifiAuthorizedChannelEncoder(
                band: .band5Ghz,
                channel: 40,
                environmentBitField: Bitfield<ArsdkFeatureWifiEnvironment>.of(.indoor),
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.last)))
        // available channels should only contain indoor authorized channels (+ current channel)
        assertThat(wifiAccessPoint!.channel.availableChannels, `is`(
            [.band_2_4_channel2, .band_5_channel34, .band_5_channel36, .band_5_channel38, .band_5_channel40]))
        assertThat(accessPointCnt, `is`(5))

        // receive a channel removal
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.wifiAuthorizedChannelEncoder(
                band: .band5Ghz,
                channel: 36,
                environmentBitField: Bitfield<ArsdkFeatureWifiEnvironment>.of(.indoor),
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.remove, .last)))
        // available channels should only contain indoor authorized channels (+ current channel)
        assertThat(wifiAccessPoint!.channel.availableChannels, `is`(
            [.band_2_4_channel2, .band_5_channel34, .band_5_channel38, .band_5_channel40]))
        assertThat(accessPointCnt, `is`(6))

        // receive a list clear
        mockArsdkCore.onCommandReceived(
            1,
            encoder: CmdEncoder.wifiAuthorizedChannelEncoder(
                band: .band2_4Ghz,
                channel: 0,
                environmentBitField: 0,
                listFlagsBitField: Bitfield<ArsdkFeatureGenericListFlags>.of(.empty)))
        assertThat(wifiAccessPoint!.channel.availableChannels, `is`([.band_5_channel38]))
        assertThat(accessPointCnt, `is`(7))
    }

    func testSsid() {
        connect(drone: drone, handle: 1)

        // check default values
        assertThat(wifiAccessPoint!.ssid, allOf(`is`(""), isUpToDate()))
        assertThat(accessPointCnt, `is`(1))

        // mock initial ssid from low-level
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonSettingsstateProductnamechangedEncoder(name: "ssid"))
        assertThat(wifiAccessPoint!.ssid, allOf(`is`("ssid"), isUpToDate()))
        assertThat(accessPointCnt, `is`(2))

        // user changes ssid
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.commonSettingsProductname(name: "newSsid"))
        wifiAccessPoint!.ssid.value = "newSsid"
        assertThat(wifiAccessPoint!.ssid, allOf(`is`("newSsid"), isUpdating()))
        assertThat(accessPointCnt, `is`(3))

        // mock answer from low-level
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonSettingsstateProductnamechangedEncoder(name: "newSsid"))
        assertThat(wifiAccessPoint!.ssid, allOf(`is`("newSsid"), isUpToDate()))
        assertThat(accessPointCnt, `is`(4))
    }

    func testSecurity() {
        let supportedSecurityModes = [SecurityMode.open, SecurityMode.wpa2Secured]
        connect(drone: drone, handle: 1) {
            // receive automatic mode
            self.mockArsdkCore!.onCommandReceived(
                1, encoder: CmdEncoder.wifiSupportedSecurityTypesEncoder(
                    typesBitField: Bitfield.of(supportedSecurityModes)))

        }

        // check default values
        assertThat(wifiAccessPoint!, securityIs(.open, updating: false))
        assertThat(accessPointCnt, `is`(1))
        assertThat(wifiAccessPoint!.security.supportedModes, `is`(Set(supportedSecurityModes)))

        // user changes security
        expectCommand(
            handle: 1, expectedCmd: ExpectedCmd.wifiSetSecurity(type: .wpa2, key: "password", keyType: .plain))
        assertThat(wifiAccessPoint!.security.secureWithWpa2(password: "password"), `is`(true))

        assertThat(wifiAccessPoint!, securityIs(.wpa2Secured, updating: true))
        assertThat(accessPointCnt, `is`(2))

        // mock response from low-level
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.wifiSecurityChangedEncoder(type: .wpa2, key: "pwd", keyType: .plain))
        assertThat(wifiAccessPoint!, securityIs(.wpa2Secured, updating: false))
        assertThat(accessPointCnt, `is`(3))

        // user disables security
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.wifiSetSecurity(type: .open, key: "", keyType: .plain))
        wifiAccessPoint!.security.open()
        assertThat(wifiAccessPoint!, securityIs(.open, updating: true))
        assertThat(accessPointCnt, `is`(4))

        // mock response from low-level
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.wifiSecurityChangedEncoder(type: .open, key: "", keyType: .plain))
        assertThat(wifiAccessPoint!, securityIs(.open, updating: false))
        assertThat(accessPointCnt, `is`(5))

        // supported mode .open removed (only wpa is present)
        let supportedSecurityOnlyWpa = [SecurityMode.wpa2Secured]
        self.mockArsdkCore!.onCommandReceived(
            1, encoder: CmdEncoder.wifiSupportedSecurityTypesEncoder(
                typesBitField: Bitfield.of(supportedSecurityOnlyWpa)))
        assertThat(accessPointCnt, `is`(6))
        assertThat(wifiAccessPoint!.security.supportedModes, `is`(Set(supportedSecurityOnlyWpa)))
        // simulation: the security is in wpa mode
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.wifiSecurityChangedEncoder(type: .wpa2, key: "simulpassword", keyType: .plain))
        assertThat(wifiAccessPoint!, securityIs(.wpa2Secured, updating: false))
        assertThat(accessPointCnt, `is`(7))
        // user try to disable the security (but it's not supported now)
        wifiAccessPoint!.security.open()
        assertThat(wifiAccessPoint!, securityIs(.wpa2Secured, updating: false))
        assertThat(accessPointCnt, `is`(7))
    }

    func testAutomaticCountryNoLock() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.wifiSupportedCountriesEncoder(countries: "FR;US;DE;ES"))
            // receive country
            // this will trigger an available channels request
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.wifiUpdateAuthorizedChannels())
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.wifiCountryChangedEncoder(selectionMode: .auto, code: "US"))
        }
        assertThat(wifiAccessPoint!.defaultCountryUsed, `is`(true))
        assertThat(accessPointCnt, `is`(1))
    }

    func testDefaultCountryUsedAfterManualSetting() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.wifiSupportedCountriesEncoder(countries: "FR;US;DE;ES"))
            // receive country
            // this will trigger an available channels request
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.wifiUpdateAuthorizedChannels())
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.wifiCountryChangedEncoder(selectionMode: .manual, code: "FR"))
        }
        assertThat(wifiAccessPoint!.defaultCountryUsed, `is`(false))
        assertThat(accessPointCnt, `is`(1))
    }

    func testAutomaticContryWithLock() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.wifiSupportedCountriesEncoder(countries: "US"))
            // receive country
            // this will trigger an available channels request
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.wifiUpdateAuthorizedChannels())
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.wifiCountryChangedEncoder(selectionMode: .auto, code: "US"))
        }
        assertThat(wifiAccessPoint!.defaultCountryUsed, `is`(false))
        assertThat(accessPointCnt, `is`(1))
    }

    func testAppAutoSelectWifi() {

        GroundSdkConfig.sharedInstance.autoSelectWifiCountry = true

        connect(drone: drone, handle: 1) {
            // receive indoor mode
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.wifiEnvironmentChangedEncoder(environment: .indoor))

            // should send outdor
            self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.wifiSetEnvironment(environment: .outdoor))
        }

        assertThat(accessPointCnt, `is`(1))

        // mock country from low-level (should trigger an available channel request)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.wifiUpdateAuthorizedChannels())
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.wifiCountryChangedEncoder(selectionMode: .manual, code: "FR"))
        assertThat(accessPointCnt, `is`(2))

        assertThat(wifiAccessPoint!, countryIs("FR", updating: false))

        // user changes country or environment - nothing happens
        self.mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.wifiEnvironmentChangedEncoder(environment: .outdoor))
        assertThat(accessPointCnt, `is`(3))
        wifiAccessPoint!.isoCountryCode.value = "DE"
        assertThat(wifiAccessPoint!, countryIs("FR", updating: false))
        wifiAccessPoint!.environment.value = .outdoor
        assertThat(wifiAccessPoint!, environmentIs(.outdoor, updating: false, mutable: false))
        assertThat(accessPointCnt, `is`(3))

        // Mock a geoLocation
        self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.wifiSetCountry(selectionMode: .manual, code: "us"))
        reverseGeocoder.placemark = MockReverseGeocoder.us

        // Mock an other geoLocation (fr)
        self.expectCommand(handle: 1, expectedCmd: ExpectedCmd.wifiSetCountry(selectionMode: .manual, code: "fr"))
        reverseGeocoder.placemark = MockReverseGeocoder.fr
    }
}
