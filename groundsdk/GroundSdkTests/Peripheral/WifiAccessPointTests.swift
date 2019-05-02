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

import XCTest
@testable import GroundSdk

/// Test WifiAccessPoint peripheral
class WifiAccessPointTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: WifiAccessPointCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        GroundSdkConfig.reload()
        GroundSdkConfig.sharedInstance.autoSelectWifiCountry = false
        store = ComponentStoreCore()
        backend = Backend()
        impl = WifiAccessPointCore(store: store!, backend: backend!)
    }

    override func tearDown() {
        GroundSdkConfig.sharedInstance.autoSelectWifiCountry = true
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.wifiAccessPoint), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.wifiAccessPoint), nilValue())
    }

    func testEnvironment() {
        GroundSdkConfig.sharedInstance.autoSelectWifiCountry = false
        impl.publish()
        var cnt = 0
        let wifiAccessPoint = store.get(Peripherals.wifiAccessPoint)!
        _ = store.register(desc: Peripherals.wifiAccessPoint) {
            cnt += 1
        }

        // test initial value
        assertThat(wifiAccessPoint, environmentIs(.outdoor, updating: false, mutable: true))
        assertThat(backend.environmentCnt, `is`(0))
        assertThat(cnt, `is`(0))

        // make setting immutable
        impl.update(environmentMutability: false).notifyUpdated()
        assertThat(wifiAccessPoint, environmentIs(.outdoor, updating: false, mutable: false))
        assertThat(cnt, `is`(1))

        // user may not change setting until notified mutable from low-level
        wifiAccessPoint.environment.value = .indoor
        assertThat(wifiAccessPoint, environmentIs(.outdoor, updating: false, mutable: false))
        assertThat(cnt, `is`(1))

        // make setting mutable
        impl.update(environmentMutability: true).notifyUpdated()
        assertThat(wifiAccessPoint, environmentIs(.outdoor, updating: false, mutable: true))
        assertThat(cnt, `is`(2))

        // mock low-level refuses changes
        backend.accept = false

        // test nothing changes if low-level denies
        wifiAccessPoint.environment.value = .indoor
        assertThat(wifiAccessPoint, environmentIs(.outdoor, updating: false, mutable: true))
        assertThat(backend.environmentCnt, `is`(1))
        assertThat(backend.environment, presentAnd(`is`(.indoor)))
        assertThat(cnt, `is`(2))

        // mock low-level accepting changes again
        backend.accept = true
        // changing to the current value should not trigger any change
        wifiAccessPoint.environment.value = .outdoor
        assertThat(wifiAccessPoint, environmentIs(.outdoor, updating: false, mutable: true))
        assertThat(backend.environmentCnt, `is`(1))
        assertThat(cnt, `is`(2))

        // user changes to a different value
        wifiAccessPoint.environment.value = .indoor
        assertThat(wifiAccessPoint, environmentIs(.indoor, updating: true, mutable: true))
        assertThat(backend.environmentCnt, `is`(2))
        assertThat(backend.environment, presentAnd(`is`(.indoor)))
        assertThat(cnt, `is`(3))

        // mock update from low-level
        impl.update(environment: .indoor).notifyUpdated()
        assertThat(wifiAccessPoint, environmentIs(.indoor, updating: false, mutable: true))
        assertThat(backend.environmentCnt, `is`(2))
        assertThat(cnt, `is`(4))

        // timeout should not do anything
        (wifiAccessPoint.environment as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(4))
        assertThat(wifiAccessPoint, environmentIs(.indoor, updating: false, mutable: true))

        // change setting
        wifiAccessPoint.environment.value = .outdoor
        assertThat(cnt, `is`(5))
        assertThat(wifiAccessPoint, environmentIs(.outdoor, updating: true, mutable: true))

        // mock timeout
        (wifiAccessPoint.environment as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(6))
        assertThat(wifiAccessPoint, environmentIs(.indoor, updating: false, mutable: true))

        // change setting from the api
        wifiAccessPoint.environment.value = .outdoor
        assertThat(cnt, `is`(7))
        assertThat(wifiAccessPoint, environmentIs(.outdoor, updating: true, mutable: true))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(8))
        assertThat(wifiAccessPoint, environmentIs(.outdoor, updating: false, mutable: true))

        // timeout should not be triggered since it has been canceled
        (wifiAccessPoint.environment as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(8))
        assertThat(wifiAccessPoint, environmentIs(.outdoor, updating: false, mutable: true))
    }

    func testCountry() {
        GroundSdkConfig.sharedInstance.autoSelectWifiCountry = false
        // add some available countries we can work with
        impl.update(availableCountries: ["FR", "DE", "ES"])

        impl.publish()
        var cnt = 0
        let wifiAccessPoint = store.get(Peripherals.wifiAccessPoint)!
        _ = store.register(desc: Peripherals.wifiAccessPoint) {
            cnt += 1
        }

        // test initial value
        assertThat(wifiAccessPoint, countryIs("", updating: false))
        assertThat(wifiAccessPoint.availableCountries, containsInAnyOrder("FR", "DE", "ES"))
        assertThat(backend.countryCnt, `is`(0))
        assertThat(cnt, `is`(0))

        // mock update from low-level
        impl.update(isoCountryCode: "FR").notifyUpdated()
        assertThat(wifiAccessPoint, countryIs("FR", updating: false))
        assertThat(wifiAccessPoint.availableCountries, containsInAnyOrder("FR", "DE", "ES"))
        assertThat(backend.countryCnt, `is`(0))
        assertThat(cnt, `is`(1))

        // mock low-level refuses changes
        backend.accept = false

        // test nothing changes if low-level denies
        wifiAccessPoint.isoCountryCode.value = "DE"
        assertThat(wifiAccessPoint, countryIs("FR", updating: false))
        assertThat(wifiAccessPoint.availableCountries, containsInAnyOrder("FR", "DE", "ES"))
        assertThat(backend.countryCnt, `is`(1))
        assertThat(backend.country, presentAnd(`is`("DE")))
        assertThat(cnt, `is`(1))

        // mock low-level accepting changes again
        backend.accept = true

        // changing to the current value should not trigger any change
        wifiAccessPoint.isoCountryCode.value = "FR"
        assertThat(wifiAccessPoint, countryIs("FR", updating: false))
        assertThat(wifiAccessPoint.availableCountries, containsInAnyOrder("FR", "DE", "ES"))
        assertThat(backend.countryCnt, `is`(1))
        assertThat(cnt, `is`(1))

        // changing to a not available country should not trigger any change
        wifiAccessPoint.isoCountryCode.value = "US"
        assertThat(wifiAccessPoint, countryIs("FR", updating: false))
        assertThat(wifiAccessPoint.availableCountries, containsInAnyOrder("FR", "DE", "ES"))
        assertThat(backend.countryCnt, `is`(1))
        assertThat(cnt, `is`(1))

        // user changes to a different value
        wifiAccessPoint.isoCountryCode.value = "ES"
        assertThat(wifiAccessPoint, countryIs("ES", updating: true))
        assertThat(wifiAccessPoint.availableCountries, containsInAnyOrder("FR", "DE", "ES"))
        assertThat(backend.countryCnt, `is`(2))
        assertThat(backend.country, presentAnd(`is`("ES")))
        assertThat(cnt, `is`(2))

        // mock update from low-level
        impl.update(isoCountryCode: "ES").notifyUpdated()
        assertThat(wifiAccessPoint, countryIs("ES", updating: false))
        assertThat(wifiAccessPoint.availableCountries, containsInAnyOrder("FR", "DE", "ES"))
        assertThat(backend.countryCnt, `is`(2))
        assertThat(cnt, `is`(3))

        // mock an available country update
        impl.update(availableCountries: ["US", "DE", "GB"]).notifyUpdated()

        // check that the list changes. Current country should also be in the list
        assertThat(wifiAccessPoint, countryIs("ES", updating: false))
        assertThat(wifiAccessPoint.availableCountries,
                   containsInAnyOrder("US", "DE", "GB", "ES"))
        assertThat(backend.countryCnt, `is`(2))
        assertThat(cnt, `is`(4))

        // change setting from the api
        wifiAccessPoint.isoCountryCode.value = "GB"
        assertThat(cnt, `is`(5))
        assertThat(wifiAccessPoint, countryIs("GB", updating: true))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(6))
        assertThat(wifiAccessPoint, countryIs("GB", updating: false))

        // timeout should not be triggered since it has been canceled
        (wifiAccessPoint.isoCountryCode as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(6))
        assertThat(wifiAccessPoint, countryIs("GB", updating: false))
    }

    func testCountryAutoSelectWifi() {
        GroundSdkConfig.sharedInstance.autoSelectWifiCountry = true
        // add some available countries we can work with
        impl.update(availableCountries: ["FR"])

        impl.publish()
        var cnt = 0
        let wifiAccessPoint = store.get(Peripherals.wifiAccessPoint)!
        _ = store.register(desc: Peripherals.wifiAccessPoint) {
            cnt += 1
        }

        // mock update from low-level
        impl.update(isoCountryCode: "FR").notifyUpdated()
        assertThat(wifiAccessPoint, countryIs("FR", updating: false))
        assertThat(wifiAccessPoint.availableCountries, containsInAnyOrder("FR"))
        assertThat(backend.countryCnt, `is`(0))
        assertThat(cnt, `is`(1))

        // mock low-level accepts changes
        backend.accept = true

        // changing to the current value should not trigger any change
        wifiAccessPoint.isoCountryCode.value = "FR"
        assertThat(wifiAccessPoint, countryIs("FR", updating: false))
        assertThat(wifiAccessPoint.availableCountries, containsInAnyOrder("FR"))
        assertThat(backend.countryCnt, `is`(0))
        assertThat(cnt, `is`(1))

        // user changes to a different value - should not trigger any change, because autoSelectWifiCountry == true
        wifiAccessPoint.isoCountryCode.value = "ES"
        assertThat(wifiAccessPoint, countryIs("FR", updating: false))
        assertThat(wifiAccessPoint.availableCountries, containsInAnyOrder("FR"))
        assertThat(backend.countryCnt, `is`(0))
        assertThat(cnt, `is`(1))
    }

    func testChannel() {
        // add some available channels we can work with
        impl.update(availableChannels: [.band_2_4_channel1, .band_2_4_channel2, .band_5_channel34, .band_5_channel36])

        impl.publish()
        var cnt = 0
        let wifiAccessPoint = store.get(Peripherals.wifiAccessPoint)!
        _ = store.register(desc: Peripherals.wifiAccessPoint) {
            cnt += 1
        }

        // test initial value
        assertThat(wifiAccessPoint, countryIs("", updating: false))
        assertThat(wifiAccessPoint.channel.availableChannels,
                   containsInAnyOrder(.band_2_4_channel1, .band_2_4_channel2, .band_5_channel34, .band_5_channel36))
        assertThat(wifiAccessPoint.channel.canAutoSelect(), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz), `is`(true))
        assertThat(wifiAccessPoint, channelIs(.band_2_4_channel1, selectionMode: .manual, updating: false))
        assertThat(backend.selectChannelCnt, `is`(0))
        assertThat(backend.autoSelectChannelCnt, `is`(0))
        assertThat(cnt, `is`(0))

        // mock low-level refuses changes
        backend.accept = false

        // test nothing changes if low-level denies
        wifiAccessPoint.channel.select(channel: .band_2_4_channel2)
        assertThat(wifiAccessPoint.channel.availableChannels,
                   containsInAnyOrder(.band_2_4_channel1, .band_2_4_channel2, .band_5_channel34, .band_5_channel36))
        assertThat(wifiAccessPoint.channel.canAutoSelect(), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz), `is`(true))
        assertThat(wifiAccessPoint, channelIs(.band_2_4_channel1, selectionMode: .manual, updating: false))
        assertThat(backend.selectChannelCnt, `is`(1))
        assertThat(backend.channel, presentAnd(`is`(.band_2_4_channel2)))
        assertThat(backend.autoSelectChannelCnt, `is`(0))
        assertThat(cnt, `is`(0))

        // test nothing changes if low-level denies auto selection (with 2.4Ghz band restriction)
        wifiAccessPoint.channel.autoSelect(onBand: .band_2_4_Ghz)
        assertThat(wifiAccessPoint.channel.availableChannels,
                   containsInAnyOrder(.band_2_4_channel1, .band_2_4_channel2, .band_5_channel34, .band_5_channel36))
        assertThat(wifiAccessPoint.channel.canAutoSelect(), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz), `is`(true))
        assertThat(wifiAccessPoint, channelIs(.band_2_4_channel1, selectionMode: .manual, updating: false))
        assertThat(backend.selectChannelCnt, `is`(1))
        assertThat(backend.autoSelectChannelCnt, `is`(1))
        assertThat(backend.band, presentAnd(`is`(.band_2_4_Ghz)))
        assertThat(cnt, `is`(0))

        // test nothing changes if low-level denies auto selection (with 5Ghz band restriction)
        wifiAccessPoint.channel.autoSelect(onBand: .band_5_Ghz)
        assertThat(wifiAccessPoint.channel.availableChannels,
                   containsInAnyOrder(.band_2_4_channel1, .band_2_4_channel2, .band_5_channel34, .band_5_channel36))
        assertThat(wifiAccessPoint.channel.canAutoSelect(), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz), `is`(true))
        assertThat(wifiAccessPoint, channelIs(.band_2_4_channel1, selectionMode: .manual, updating: false))
        assertThat(backend.selectChannelCnt, `is`(1))
        assertThat(backend.autoSelectChannelCnt, `is`(2))
        assertThat(backend.band, presentAnd(`is`(.band_5_Ghz)))
        assertThat(cnt, `is`(0))

        // test nothing changes if low-level denies auto selection (without band restriction)
        wifiAccessPoint.channel.autoSelect()
        assertThat(wifiAccessPoint.channel.availableChannels,
                   containsInAnyOrder(.band_2_4_channel1, .band_2_4_channel2, .band_5_channel34, .band_5_channel36))
        assertThat(wifiAccessPoint.channel.canAutoSelect(), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz), `is`(true))
        assertThat(wifiAccessPoint, channelIs(.band_2_4_channel1, selectionMode: .manual, updating: false))
        assertThat(backend.selectChannelCnt, `is`(1))
        assertThat(backend.autoSelectChannelCnt, `is`(3))
        assertThat(backend.band, nilValue())
        assertThat(cnt, `is`(0))

        // mock low-level accepting changes again
        backend.accept = true

        // selecting the same channel when already in manual mode should not trigger a change
        wifiAccessPoint.channel.select(channel: .band_2_4_channel1)
        assertThat(wifiAccessPoint.channel.availableChannels,
                   containsInAnyOrder(.band_2_4_channel1, .band_2_4_channel2, .band_5_channel34, .band_5_channel36))
        assertThat(wifiAccessPoint.channel.canAutoSelect(), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz), `is`(true))
        assertThat(wifiAccessPoint, channelIs(.band_2_4_channel1, selectionMode: .manual, updating: false))
        assertThat(backend.selectChannelCnt, `is`(1))
        assertThat(backend.autoSelectChannelCnt, `is`(3))
        assertThat(cnt, `is`(0))

        // selecting an unavailable channel should not trigger a change
        wifiAccessPoint.channel.select(channel: .band_2_4_channel3)
        assertThat(wifiAccessPoint.channel.availableChannels,
                   containsInAnyOrder(.band_2_4_channel1, .band_2_4_channel2, .band_5_channel34, .band_5_channel36))
        assertThat(wifiAccessPoint.channel.canAutoSelect(), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz), `is`(true))
        assertThat(wifiAccessPoint, channelIs(.band_2_4_channel1, selectionMode: .manual, updating: false))
        assertThat(backend.selectChannelCnt, `is`(1))
        assertThat(backend.autoSelectChannelCnt, `is`(3))
        assertThat(cnt, `is`(0))

        // user selects an available, different channel
        wifiAccessPoint.channel.select(channel: .band_2_4_channel2)
        assertThat(wifiAccessPoint.channel.availableChannels,
                   containsInAnyOrder(.band_2_4_channel1, .band_2_4_channel2, .band_5_channel34, .band_5_channel36))
        assertThat(wifiAccessPoint.channel.canAutoSelect(), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz), `is`(true))
        assertThat(wifiAccessPoint, channelIs(.band_2_4_channel2, selectionMode: .manual, updating: true))
        assertThat(backend.selectChannelCnt, `is`(2))
        assertThat(backend.channel, presentAnd(`is`(.band_2_4_channel2)))
        assertThat(backend.autoSelectChannelCnt, `is`(3))
        assertThat(cnt, `is`(1))

        // mock update from low-level
        impl.update(channel: .band_2_4_channel2).notifyUpdated()
        assertThat(wifiAccessPoint.channel.availableChannels,
                   containsInAnyOrder(.band_2_4_channel1, .band_2_4_channel2, .band_5_channel34, .band_5_channel36))
        assertThat(wifiAccessPoint.channel.canAutoSelect(), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz), `is`(true))
        assertThat(wifiAccessPoint, channelIs(.band_2_4_channel2, selectionMode: .manual, updating: false))
        assertThat(backend.selectChannelCnt, `is`(2))
        assertThat(backend.autoSelectChannelCnt, `is`(3))
        assertThat(cnt, `is`(2))

        // timeout should not do anything
        (wifiAccessPoint.channel as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(2))
        assertThat(wifiAccessPoint, channelIs(.band_2_4_channel2, selectionMode: .manual, updating: false))

        // user requests auto-selection on 2.4 Ghz Band
        wifiAccessPoint.channel.autoSelect(onBand: .band_2_4_Ghz)
        assertThat(wifiAccessPoint.channel.availableChannels,
                   containsInAnyOrder(.band_2_4_channel1, .band_2_4_channel2, .band_5_channel34, .band_5_channel36))
        assertThat(wifiAccessPoint.channel.canAutoSelect(), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz), `is`(true))
        assertThat(wifiAccessPoint, channelIs(.band_2_4_channel2, selectionMode: .auto2_4GhzBand, updating: true))
        assertThat(backend.selectChannelCnt, `is`(2))
        assertThat(backend.autoSelectChannelCnt, `is`(4))
        assertThat(backend.band, presentAnd(`is`(.band_2_4_Ghz)))
        assertThat(cnt, `is`(3))

        // mock update from low-level
        impl.update(channel: .band_2_4_channel1).update(selectionMode: .auto2_4GhzBand).notifyUpdated()
        assertThat(wifiAccessPoint.channel.availableChannels,
                   containsInAnyOrder(.band_2_4_channel1, .band_2_4_channel2, .band_5_channel34, .band_5_channel36))
        assertThat(wifiAccessPoint.channel.canAutoSelect(), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz), `is`(true))
        assertThat(wifiAccessPoint, channelIs(.band_2_4_channel1, selectionMode: .auto2_4GhzBand, updating: false))
        assertThat(backend.selectChannelCnt, `is`(2))
        assertThat(backend.autoSelectChannelCnt, `is`(4))
        assertThat(cnt, `is`(4))

        // user requests auto-selection on 5 Ghz Band
        wifiAccessPoint.channel.autoSelect(onBand: .band_5_Ghz)
        assertThat(wifiAccessPoint.channel.availableChannels,
                   containsInAnyOrder(.band_2_4_channel1, .band_2_4_channel2, .band_5_channel34, .band_5_channel36))
        assertThat(wifiAccessPoint.channel.canAutoSelect(), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz), `is`(true))
        assertThat(wifiAccessPoint, channelIs(.band_2_4_channel1, selectionMode: .auto5GhzBand, updating: true))
        assertThat(backend.selectChannelCnt, `is`(2))
        assertThat(backend.autoSelectChannelCnt, `is`(5))
        assertThat(backend.band, presentAnd(`is`(.band_5_Ghz)))
        assertThat(cnt, `is`(5))

        // mock update from low-level
        impl.update(channel: .band_5_channel36).update(selectionMode: .auto5GhzBand).notifyUpdated()
        assertThat(wifiAccessPoint.channel.availableChannels,
                   containsInAnyOrder(.band_2_4_channel1, .band_2_4_channel2, .band_5_channel34, .band_5_channel36))
        assertThat(wifiAccessPoint.channel.canAutoSelect(), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz), `is`(true))
        assertThat(wifiAccessPoint, channelIs(.band_5_channel36, selectionMode: .auto5GhzBand, updating: false))
        assertThat(backend.selectChannelCnt, `is`(2))
        assertThat(backend.autoSelectChannelCnt, `is`(5))
        assertThat(cnt, `is`(6))

        // user requests auto-selection on any band
        wifiAccessPoint.channel.autoSelect()
        assertThat(wifiAccessPoint.channel.availableChannels,
                   containsInAnyOrder(.band_2_4_channel1, .band_2_4_channel2, .band_5_channel34, .band_5_channel36))
        assertThat(wifiAccessPoint.channel.canAutoSelect(), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz), `is`(true))
        assertThat(wifiAccessPoint, channelIs(.band_5_channel36, selectionMode: .autoAnyBand, updating: true))
        assertThat(backend.selectChannelCnt, `is`(2))
        assertThat(backend.autoSelectChannelCnt, `is`(6))
        assertThat(backend.band, nilValue())
        assertThat(cnt, `is`(7))

        // mock update from low-level
        impl.update(channel: .band_5_channel34).update(selectionMode: .autoAnyBand).notifyUpdated()
        assertThat(wifiAccessPoint.channel.availableChannels,
                   containsInAnyOrder(.band_2_4_channel1, .band_2_4_channel2, .band_5_channel34, .band_5_channel36))
        assertThat(wifiAccessPoint.channel.canAutoSelect(), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz), `is`(true))
        assertThat(wifiAccessPoint, channelIs(.band_5_channel34, selectionMode: .autoAnyBand, updating: false))
        assertThat(backend.selectChannelCnt, `is`(2))
        assertThat(backend.autoSelectChannelCnt, `is`(6))
        assertThat(cnt, `is`(8))

        // test that user can still switch back to manual mode with the current channel
        wifiAccessPoint.channel.select(channel: .band_5_channel34)
        assertThat(wifiAccessPoint.channel.availableChannels,
                   containsInAnyOrder(.band_2_4_channel1, .band_2_4_channel2, .band_5_channel34, .band_5_channel36))
        assertThat(wifiAccessPoint.channel.canAutoSelect(), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz), `is`(true))
        assertThat(wifiAccessPoint, channelIs(.band_5_channel34, selectionMode: .manual, updating: true))
        assertThat(backend.selectChannelCnt, `is`(3))
        assertThat(backend.channel, presentAnd(`is`(.band_5_channel34)))
        assertThat(backend.autoSelectChannelCnt, `is`(6))
        assertThat(cnt, `is`(9))

        // mock update from low-level
        impl.update(channel: .band_5_channel34).update(selectionMode: .manual).notifyUpdated()
        assertThat(wifiAccessPoint.channel.availableChannels,
                   containsInAnyOrder(.band_2_4_channel1, .band_2_4_channel2, .band_5_channel34, .band_5_channel36))
        assertThat(wifiAccessPoint.channel.canAutoSelect(), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz), `is`(true))
        assertThat(wifiAccessPoint, channelIs(.band_5_channel34, selectionMode: .manual, updating: false))
        assertThat(backend.selectChannelCnt, `is`(3))
        assertThat(backend.autoSelectChannelCnt, `is`(6))
        assertThat(cnt, `is`(10))

        // mock an available channel update
        impl.update(availableChannels: [.band_2_4_channel3, .band_5_channel38]).notifyUpdated()
        // check that the list changes. Current channel should also be in the list
        assertThat(wifiAccessPoint.channel.availableChannels,
                   containsInAnyOrder(.band_5_channel34, .band_2_4_channel3, .band_5_channel38))
        assertThat(wifiAccessPoint.channel.canAutoSelect(), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz), `is`(true))
        assertThat(wifiAccessPoint, channelIs(.band_5_channel34, selectionMode: .manual, updating: false))
        assertThat(backend.selectChannelCnt, `is`(3))
        assertThat(backend.autoSelectChannelCnt, `is`(6))
        assertThat(cnt, `is`(11))

        // mock no auto-selection support
        impl.update(autoSelectSupported: false).notifyUpdated()
        assertThat(wifiAccessPoint.channel.availableChannels,
                   containsInAnyOrder(.band_5_channel34, .band_2_4_channel3, .band_5_channel38))
        assertThat(wifiAccessPoint.channel.canAutoSelect(), `is`(false))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz), `is`(false))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz), `is`(false))
        assertThat(wifiAccessPoint, channelIs(.band_5_channel34, selectionMode: .manual, updating: false))
        assertThat(backend.selectChannelCnt, `is`(3))
        assertThat(backend.autoSelectChannelCnt, `is`(6))
        assertThat(cnt, `is`(12))

        // re-enable auto-selection and mock an available channel update with only 2.4 Ghz band
        impl.update(autoSelectSupported: true).update(availableChannels: [.band_2_4_channel3]).notifyUpdated()
        assertThat(wifiAccessPoint.channel.availableChannels,
                   containsInAnyOrder(.band_5_channel34, .band_2_4_channel3))
        assertThat(wifiAccessPoint.channel.canAutoSelect(), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz), `is`(false))
        assertThat(wifiAccessPoint, channelIs(.band_5_channel34, selectionMode: .manual, updating: false))
        assertThat(backend.selectChannelCnt, `is`(3))
        assertThat(backend.autoSelectChannelCnt, `is`(6))
        assertThat(cnt, `is`(13))

        // mock an available channel update with only 5 Ghz band
        impl.update(autoSelectSupported: true).update(availableChannels: [.band_5_channel34]).notifyUpdated()
        assertThat(wifiAccessPoint.channel.availableChannels,
                   containsInAnyOrder(.band_5_channel34))
        assertThat(wifiAccessPoint.channel.canAutoSelect(), `is`(true))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz), `is`(false))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz), `is`(true))
        assertThat(wifiAccessPoint, channelIs(.band_5_channel34, selectionMode: .manual, updating: false))
        assertThat(backend.selectChannelCnt, `is`(3))
        assertThat(backend.autoSelectChannelCnt, `is`(6))
        assertThat(cnt, `is`(14))

        // mock no channels available
        impl.update(autoSelectSupported: true).update(availableChannels: []).notifyUpdated()
        assertThat(wifiAccessPoint.channel.availableChannels,
                   containsInAnyOrder(.band_5_channel34))
        assertThat(wifiAccessPoint.channel.canAutoSelect(), `is`(false))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_2_4_Ghz), `is`(false))
        assertThat(wifiAccessPoint.channel.canAutoSelect(onBand: .band_5_Ghz), `is`(false))
        assertThat(wifiAccessPoint, channelIs(.band_5_channel34, selectionMode: .manual, updating: false))
        assertThat(backend.selectChannelCnt, `is`(3))
        assertThat(backend.autoSelectChannelCnt, `is`(6))
        assertThat(cnt, `is`(15))

        // mock channels available
        impl.update(availableChannels: [.band_2_4_channel1, .band_2_4_channel2, .band_5_channel34, .band_5_channel36])
            .notifyUpdated()
        assertThat(cnt, `is`(16))

        // change setting
        wifiAccessPoint.channel.autoSelect()
        assertThat(cnt, `is`(17))
        assertThat(wifiAccessPoint, channelIs(.band_5_channel34, selectionMode: .autoAnyBand, updating: true))

        // mock timeout
        (wifiAccessPoint.channel as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(18))
        assertThat(wifiAccessPoint, channelIs(.band_5_channel34, selectionMode: .manual, updating: false))

        // change setting
        wifiAccessPoint.channel.select(channel: .band_5_channel36)
        assertThat(cnt, `is`(19))
        assertThat(wifiAccessPoint, channelIs(.band_5_channel36, selectionMode: .manual, updating: true))

        // mock timeout
        (wifiAccessPoint.channel as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(20))
        assertThat(wifiAccessPoint, channelIs(.band_5_channel34, selectionMode: .manual, updating: false))

        // change setting from the api
        wifiAccessPoint.channel.select(channel: .band_5_channel36)
        assertThat(cnt, `is`(21))
        assertThat(wifiAccessPoint, channelIs(.band_5_channel36, selectionMode: .manual, updating: true))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(22))
        assertThat(wifiAccessPoint, channelIs(.band_5_channel36, selectionMode: .manual, updating: false))

        // timeout should not be triggered since it has been canceled
        (wifiAccessPoint.channel as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(22))
        assertThat(wifiAccessPoint, channelIs(.band_5_channel36, selectionMode: .manual, updating: false))
    }

    func testSsid() {
        impl.publish()
        var cnt = 0
        let wifiAccessPoint = store.get(Peripherals.wifiAccessPoint)!
        _ = store.register(desc: Peripherals.wifiAccessPoint) {
            cnt += 1
        }

        // test initial value
        assertThat(wifiAccessPoint.ssid, allOf(`is`(""), isUpToDate()))
        assertThat(backend.ssidCnt, `is`(0))
        assertThat(cnt, `is`(0))

        // mock low-level refuses changes
        backend.accept = false

        // test nothing changes if low-level denies
        wifiAccessPoint.ssid.value =  "passdenied"
        assertThat(wifiAccessPoint.ssid, allOf(`is`(""), isUpToDate()))
        assertThat(backend.ssidCnt, `is`(1))
        assertThat(backend.ssid, presentAnd(`is`("passdenied")))
        assertThat(cnt, `is`(0))

        // mock low-level accepting changes again
        backend.accept = true

        // changing to the current value should not trigger any change
        wifiAccessPoint.ssid.value =  ""
        assertThat(wifiAccessPoint.ssid, allOf(`is`(""), isUpToDate()))
        assertThat(backend.ssidCnt, `is`(1))
        assertThat(cnt, `is`(0))

        // user changes to a different value
        wifiAccessPoint.ssid.value =  "new"
        assertThat(wifiAccessPoint.ssid, allOf(`is`("new"), isUpdating()))
        assertThat(backend.ssidCnt, `is`(2))
        assertThat(backend.ssid, presentAnd(`is`("new")))
        assertThat(cnt, `is`(1))

        // mock update from low-level
        impl.update(ssid: "low-level").notifyUpdated()
        assertThat(wifiAccessPoint.ssid, allOf(`is`("low-level"), isUpToDate()))
        assertThat(backend.ssidCnt, `is`(2))
        assertThat(cnt, `is`(2))

        // change setting from the api
        wifiAccessPoint.ssid.value =  "new"
        assertThat(cnt, `is`(3))
        assertThat(wifiAccessPoint.ssid, allOf(`is`("new"), isUpdating()))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(4))
        assertThat(wifiAccessPoint.ssid, allOf(`is`("new"), isUpToDate()))

        // timeout should not be triggered since it has been canceled
        (wifiAccessPoint.ssid as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(4))
        assertThat(wifiAccessPoint.ssid, allOf(`is`("new"), isUpToDate()))
    }

    func testValidPassword() {
        impl.publish()
        var cnt = 0
        let wifiAccessPoint = store.get(Peripherals.wifiAccessPoint)!
        _ = store.register(desc: Peripherals.wifiAccessPoint) {
            cnt += 1
        }
        backend.accept = true
        // test initial value
        assertThat(wifiAccessPoint, securityIs(.open, updating: false))
        assertThat(backend.securityCnt, `is`(0))
        assertThat(cnt, `is`(0))

        // invalid passwords
        assertThat(wifiAccessPoint.security.secureWithWpa2(password: "short"), `is`(false))
        assertThat(wifiAccessPoint.security.secureWithWpa2(password: ""), `is`(false))
        assertThat(wifiAccessPoint.security.secureWithWpa2(password: "1234567"), `is`(false))
        assertThat(wifiAccessPoint.security.secureWithWpa2(password: "bad_char_inside_\r_not_valid"), `is`(false))
        assertThat(cnt, `is`(0))

        // valid password
        assertThat(wifiAccessPoint.security.secureWithWpa2(password: "12345678"), `is`(true))
    }

    func testDefaultCountryUsed() {
        impl.publish()
        var cnt = 0
        let wifiAccessPoint = store.get(Peripherals.wifiAccessPoint)!
        _ = store.register(desc: Peripherals.wifiAccessPoint) {
            cnt += 1
        }

        // test initial value
        assertThat(wifiAccessPoint.defaultCountryUsed, `is`(false))
        assertThat(cnt, `is`(0))

        // update defaultCountryUsed
        impl.update(defaultCountryUsed: true).notifyUpdated()
        assertThat(wifiAccessPoint.defaultCountryUsed, `is`(true))
        assertThat(cnt, `is`(1))
        // test that nothing changes with the same value
        impl.update(defaultCountryUsed: true).notifyUpdated()
        assertThat(wifiAccessPoint.defaultCountryUsed, `is`(true))
        assertThat(cnt, `is`(1))
    }

    func testSecurity() {
        let allModes: Set<SecurityMode> = Set([.wpa2Secured, .open])
        impl.publish()
        var cnt = 0
        let wifiAccessPoint = store.get(Peripherals.wifiAccessPoint)!
        _ = store.register(desc: Peripherals.wifiAccessPoint) {
            cnt += 1
        }

        // test initial value
        assertThat(wifiAccessPoint, securityIs(.open, updating: false))
        assertThat(backend.securityCnt, `is`(0))
        assertThat(cnt, `is`(0))

        impl.update(supportedModes: allModes).notifyUpdated()
        assertThat(wifiAccessPoint.security.supportedModes, `is`(allModes))
        assertThat(cnt, `is`(1))

        // mock low-level refuses changes
        backend.accept = false

        // test nothing changes if low-level denies
        assertThat(wifiAccessPoint.security.secureWithWpa2(password: "passdenied"), `is`(true))
        assertThat(wifiAccessPoint, securityIs(.open, updating: false))
        assertThat(backend.securityCnt, `is`(1))
        assertThat(backend.security, presentAnd(`is`(.wpa2Secured)))
        assertThat(backend.password, presentAnd(`is`("passdenied")))
        assertThat(cnt, `is`(1))

        // mock low-level accepting changes again
        backend.accept = true

        // changing to the current value should not trigger any change
        wifiAccessPoint.security.open()
        assertThat(wifiAccessPoint, securityIs(.open, updating: false))
        assertThat(backend.securityCnt, `is`(1))
        assertThat(cnt, `is`(1))

        // user enables WPA2 security
        assertThat(wifiAccessPoint.security.secureWithWpa2(password: "password"), `is`(true))
        assertThat(wifiAccessPoint, securityIs(.wpa2Secured, updating: true))
        assertThat(backend.securityCnt, `is`(2))
        assertThat(backend.security, presentAnd(`is`(.wpa2Secured)))
        assertThat(backend.password, presentAnd(`is`("password")))
        assertThat(cnt, `is`(2))

        // mock update from low-level
        impl.update(security: .wpa2Secured).notifyUpdated()
        assertThat(wifiAccessPoint, securityIs(.wpa2Secured, updating: false))
        assertThat(backend.securityCnt, `is`(2))
        assertThat(cnt, `is`(3))

        // timeout should not do anything
        (wifiAccessPoint.security as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(3))
        assertThat(wifiAccessPoint, securityIs(.wpa2Secured, updating: false))

        // securing with WPA2 again should trigger a change, even with the same password
        assertThat(wifiAccessPoint.security.secureWithWpa2(password: "password"), `is`(true))
        assertThat(wifiAccessPoint, securityIs(.wpa2Secured, updating: true))
        assertThat(backend.securityCnt, `is`(3))
        assertThat(backend.security, presentAnd(`is`(.wpa2Secured)))
        assertThat(backend.password, presentAnd(`is`("password")))
        assertThat(cnt, `is`(4))

        // mock update from low-level
        impl.update(security: .wpa2Secured).notifyUpdated()
        assertThat(wifiAccessPoint, securityIs(.wpa2Secured, updating: false))
        assertThat(backend.securityCnt, `is`(3))
        assertThat(cnt, `is`(5))

        // user disables security
        wifiAccessPoint.security.open()
        assertThat(wifiAccessPoint, securityIs(.open, updating: true))
        assertThat(backend.securityCnt, `is`(4))
        assertThat(backend.security, presentAnd(`is`(.open)))
        assertThat(backend.password, nilValue())
        assertThat(cnt, `is`(6))

        // mock update from low-level
        impl.update(security: .open).notifyUpdated()
        assertThat(wifiAccessPoint, securityIs(.open, updating: false))
        assertThat(backend.securityCnt, `is`(4))
        assertThat(cnt, `is`(7))

        // change setting
        _ = wifiAccessPoint.security.secureWithWpa2(password: "password")
        assertThat(cnt, `is`(8))
        assertThat(wifiAccessPoint, securityIs(.wpa2Secured, updating: true))

        // mock timeout
        (wifiAccessPoint.security as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(9))
        assertThat(wifiAccessPoint, securityIs(.open, updating: false))

        // change setting from the api
        _ = wifiAccessPoint.security.secureWithWpa2(password: "password")
        assertThat(cnt, `is`(10))
        assertThat(wifiAccessPoint, securityIs(.wpa2Secured, updating: true))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(11))
        assertThat(wifiAccessPoint, securityIs(.wpa2Secured, updating: false))

        // timeout should not be triggered since it has been canceled
        (wifiAccessPoint.security as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(11))
        assertThat(wifiAccessPoint, securityIs(.wpa2Secured, updating: false))
    }

    func testSecurityModes() {
        let noMode = Set<SecurityMode>()
        let onlyWpaMode: Set<SecurityMode> = Set([.wpa2Secured])
        let allModes: Set<SecurityMode> = Set([.wpa2Secured, .open])

        impl.publish()
        var cnt = 0
        let wifiAccessPoint = store.get(Peripherals.wifiAccessPoint)!
        _ = store.register(desc: Peripherals.wifiAccessPoint) {
            cnt += 1
        }

        backend.accept = true
        assertThat(backend.securityCnt, `is`(0))

        // test initial value
        assertThat(wifiAccessPoint.security.supportedModes, `is`(noMode))
        assertThat(wifiAccessPoint, securityIs(.open, updating: false))
        assertThat(backend.securityCnt, `is`(0))
        assertThat(cnt, `is`(0))
        // same value
        impl.update(supportedModes: noMode).notifyUpdated()
        assertThat(wifiAccessPoint.security.supportedModes, `is`(noMode))
        assertThat(cnt, `is`(0))

        // try to secure with WPA2
        assertThat(wifiAccessPoint.security.secureWithWpa2(password: "password"), `is`(true))
        assertThat(wifiAccessPoint, securityIs(.open, updating: false))
        assertThat(backend.securityCnt, `is`(0))
        assertThat(cnt, `is`(0))

         // test all modes value
        impl.update(supportedModes: allModes).notifyUpdated()
        assertThat(wifiAccessPoint.security.supportedModes, `is`(allModes))
        assertThat(cnt, `is`(1))

        // user enables WPA2 security
        assertThat(wifiAccessPoint.security.secureWithWpa2(password: "password"), `is`(true))
        assertThat(wifiAccessPoint, securityIs(.wpa2Secured, updating: true))
        assertThat(backend.securityCnt, `is`(1))
        assertThat(backend.security, presentAnd(`is`(.wpa2Secured)))
        assertThat(backend.password, presentAnd(`is`("password")))
        assertThat(cnt, `is`(2))

        // test only wpa mode
        impl.update(supportedModes: onlyWpaMode).notifyUpdated()
        assertThat(wifiAccessPoint.security.supportedModes, `is`(onlyWpaMode))
        assertThat(cnt, `is`(3))
        assertThat(backend.security, presentAnd(`is`(.wpa2Secured)))
        assertThat(backend.password, presentAnd(`is`("password")))
        // no change on open
        wifiAccessPoint.security.open()
        assertThat(wifiAccessPoint, securityIs(.wpa2Secured, updating: true))
        assertThat(cnt, `is`(3))
    }
}

private class Backend: WifiAccessPointBackend {
    var accept = true

    var environmentCnt = 0
    var environment: Environment?

    var countryCnt = 0
    var country: String?

    var selectChannelCnt = 0
    var channel: WifiChannel?

    var autoSelectChannelCnt = 0
    var band: Band?

    var ssidCnt = 0
    var ssid: String?

    var securityCnt = 0
    var security: SecurityMode?
    var password: String?

    func set(environment: Environment) -> Bool {
        environmentCnt += 1
        self.environment = environment
        return accept
    }

    func set(country: String) -> Bool {
        countryCnt += 1
        self.country = country
        return accept
    }

    func set(ssid: String) -> Bool {
        ssidCnt += 1
        self.ssid = ssid
        return accept
    }

    func set(security: SecurityMode, password: String?) -> Bool {
        securityCnt += 1
        self.security = security
        self.password = password
        return accept
    }

    func select(channel: WifiChannel) -> Bool {
        selectChannelCnt += 1
        self.channel = channel
        return accept
    }

    func autoSelectChannel(onBand band: Band?) -> Bool {
        autoSelectChannelCnt += 1
        self.band = band
        return accept
    }
}
