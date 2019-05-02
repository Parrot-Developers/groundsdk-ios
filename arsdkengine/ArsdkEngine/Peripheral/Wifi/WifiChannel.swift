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

/// Internal band extension that brings translation to/from arsdk band enum
extension Band {

    /// Translate a band into an Arsdk band
    ///
    /// - Returns: the arsdk band
    func toArsdkBand() -> ArsdkFeatureWifiBand {
        switch self {
        case .band_2_4_Ghz:
            return .band2_4Ghz
        case .band_5_Ghz:
            return .band5Ghz
        }
    }
}

// Extension that brings translation between Arsdk wifi channel (band and channel id) and WifiChannel enum
extension WifiChannel {

    /// Failable WifiChannel initializer
    ///
    /// - Parameters:
    ///   - band: the band of the wifi channel
    ///   - channelId: the channel id
    /// - Returns: a WifiChannel if one matching the band and id exists, nil otherwise
    init?(failableFromArsdkBand band: ArsdkFeatureWifiBand, channelId: Int) {
        var this: WifiChannel?
        switch band {
        case .band2_4Ghz:
            this = wifiChannels.channels2_4Ghz[channelId]
        case .band5Ghz:
            this = wifiChannels.channels5Ghz[channelId]
        case .bandSdkCoreUnknown:
            break
        }
        if let this = this {
            self = this
        } else {
            ULog.w(.wifiTag, "Unsupported channel [band: \(band.rawValue), channelId: \(channelId)")
            return nil
        }
    }

    /// Constructor
    ///
    /// - Parameters:
    ///   - band: the band of the wifi channel
    ///   - channelId: the channel id
    /// - Returns: a WifiChannel if one matching the band and id exists, nil otherwise
    init(fromArsdkBand band: ArsdkFeatureWifiBand, channelId: Int) {
        var this: WifiChannel?
        let defaultChannel: WifiChannel
        switch band {
        case .band2_4Ghz:
            this = wifiChannels.channels2_4Ghz[channelId]
            defaultChannel = .band_2_4_channel1
        case .band5Ghz:
            this = wifiChannels.channels5Ghz[channelId]
            defaultChannel = .band_5_channel34
        case .bandSdkCoreUnknown:
            ULog.w(.wifiTag, "Band is unknown, falling back to 2.4Ghz channel 1.")
            defaultChannel = .band_2_4_channel1
        }
        if let this = this {
            self = this
        } else {
            ULog.w(.wifiTag, "Unsupported channel [band: \(band.rawValue), channelId: \(channelId)")
            self = defaultChannel
        }
    }
}

private typealias WifiChannels = (
    channels2_4Ghz: [Int: WifiChannel],
    channels5Ghz: [Int: WifiChannel])

/// Lazy var that contains a mapping between channels and WifiChannel for a given band.
private var wifiChannels: WifiChannels = {
    var channels = (channels2_4Ghz: [Int: WifiChannel](),
                    channels5Ghz: [Int: WifiChannel]())

    func sortChannels() {
        WifiChannel.allCases.forEach { channel in
            switch channel.getBand() {
            case .band_2_4_Ghz:
                channels.channels2_4Ghz[channel.getChannelId()] = channel
            case .band_5_Ghz:
                channels.channels5Ghz[channel.getChannelId()] = channel
            }
        }
    }
    sortChannels()

    return channels
}()
