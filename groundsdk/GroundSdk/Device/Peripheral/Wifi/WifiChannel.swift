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

/// Frequency band into which a Wifi channel operates.
@objc(GSBand)
public enum Band: Int, CustomStringConvertible {
    /// 2.4 Ghz band.
    case band_2_4_Ghz
    /// 5 Ghz band.
    case band_5_Ghz

    /// Set containing all bands.
    public static let allCases: Set<Band> = [.band_2_4_Ghz, .band_5_Ghz]

    /// Debug description.
    public var description: String {
        switch self {
        case .band_2_4_Ghz: return "2.4Ghz"
        case .band_5_Ghz:   return "5Ghz"

        }
    }
}

/// Wifi channel.
@objc(GSWifiChannel)
public enum WifiChannel: Int, CustomStringConvertible {
    /// Wifi channel 1 on band 2.4Ghz
    case band_2_4_channel1
    /// Wifi channel 2 on band 2.4Ghz
    case band_2_4_channel2
    /// Wifi channel 3 on band 2.4Ghz
    case band_2_4_channel3
    /// Wifi channel 4 on band 2.4Ghz
    case band_2_4_channel4
    /// Wifi channel 5 on band 2.4Ghz
    case band_2_4_channel5
    /// Wifi channel 6 on band 2.4Ghz
    case band_2_4_channel6
    /// Wifi channel 7 on band 2.4Ghz
    case band_2_4_channel7
    /// Wifi channel 8 on band 2.4Ghz
    case band_2_4_channel8
    /// Wifi channel 9 on band 2.4Ghz
    case band_2_4_channel9
    /// Wifi channel 10 on band 2.4Ghz
    case band_2_4_channel10
    /// Wifi channel 11 on band 2.4Ghz
    case band_2_4_channel11
    /// Wifi channel 12 on band 2.4Ghz
    case band_2_4_channel12
    /// Wifi channel 13 on band 2.4Ghz
    case band_2_4_channel13
    /// Wifi channel 14 on band 2.4Ghz
    case band_2_4_channel14

    /// Wifi channel 34 on band 5Ghz
    case band_5_channel34
    /// Wifi channel 36 on band 5Ghz
    case band_5_channel36
    /// Wifi channel 38 on band 5Ghz
    case band_5_channel38
    /// Wifi channel 40 on band 5Ghz
    case band_5_channel40
    /// Wifi channel 42 on band 5Ghz
    case band_5_channel42
    /// Wifi channel 44 on band 5Ghz
    case band_5_channel44
    /// Wifi channel 46 on band 5Ghz
    case band_5_channel46
    /// Wifi channel 48 on band 5Ghz
    case band_5_channel48
    /// Wifi channel 50 on band 5Ghz
    case band_5_channel50
    /// Wifi channel 52 on band 5Ghz
    case band_5_channel52
    /// Wifi channel 54 on band 5Ghz
    case band_5_channel54
    /// Wifi channel 56 on band 5Ghz
    case band_5_channel56
    /// Wifi channel 58 on band 5Ghz
    case band_5_channel58
    /// Wifi channel 60 on band 5Ghz
    case band_5_channel60
    /// Wifi channel 62 on band 5Ghz
    case band_5_channel62
    /// Wifi channel 64 on band 5Ghz
    case band_5_channel64

    /// Wifi channel 100 on band 5Ghz
    case band_5_channel100
    /// Wifi channel 102 on band 5Ghz
    case band_5_channel102
    /// Wifi channel 104 on band 5Ghz
    case band_5_channel104
    /// Wifi channel 106 on band 5Ghz
    case band_5_channel106
    /// Wifi channel 108 on band 5Ghz
    case band_5_channel108
    /// Wifi channel 110 on band 5Ghz
    case band_5_channel110
    /// Wifi channel 112 on band 5Ghz
    case band_5_channel112
    /// Wifi channel 114 on band 5Ghz
    case band_5_channel114
    /// Wifi channel 116 on band 5Ghz
    case band_5_channel116
    /// Wifi channel 118 on band 5Ghz
    case band_5_channel118
    /// Wifi channel 120 on band 5Ghz
    case band_5_channel120
    /// Wifi channel 122 on band 5Ghz
    case band_5_channel122
    /// Wifi channel 124 on band 5Ghz
    case band_5_channel124
    /// Wifi channel 126 on band 5Ghz
    case band_5_channel126
    /// Wifi channel 128 on band 5Ghz
    case band_5_channel128

    /// Wifi channel 132 on band 5Ghz
    case band_5_channel132
    /// Wifi channel 134 on band 5Ghz
    case band_5_channel134
    /// Wifi channel 136 on band 5Ghz
    case band_5_channel136
    /// Wifi channel 138 on band 5Ghz
    case band_5_channel138
    /// Wifi channel 140 on band 5Ghz
    case band_5_channel140
    /// Wifi channel 142 on band 5Ghz
    case band_5_channel142
    /// Wifi channel 144 on band 5Ghz
    case band_5_channel144

    /// Wifi channel 149 on band 5Ghz
    case band_5_channel149
    /// Wifi channel 151 on band 5Ghz
    case band_5_channel151
    /// Wifi channel 153 on band 5Ghz
    case band_5_channel153
    /// Wifi channel 155 on band 5Ghz
    case band_5_channel155
    /// Wifi channel 157 on band 5Ghz
    case band_5_channel157
    /// Wifi channel 159 on band 5Ghz
    case band_5_channel159
    /// Wifi channel 161 on band 5Ghz
    case band_5_channel161

    /// Wifi channel 165 on band 5Ghz
    case band_5_channel165

    /// Set containing all wifi channels
    public static let allCases: Set<WifiChannel> =
        [.band_2_4_channel1, .band_2_4_channel2, .band_2_4_channel3, .band_2_4_channel4, .band_2_4_channel5,
         .band_2_4_channel6, .band_2_4_channel7, .band_2_4_channel8, .band_2_4_channel9, .band_2_4_channel10,
         .band_2_4_channel11, .band_2_4_channel12, .band_2_4_channel13, .band_2_4_channel14, .band_5_channel34,
         .band_5_channel36, .band_5_channel38, .band_5_channel40, .band_5_channel42, .band_5_channel44,
         .band_5_channel46, .band_5_channel48, .band_5_channel50, .band_5_channel52, .band_5_channel54,
         .band_5_channel56, .band_5_channel58, .band_5_channel60, .band_5_channel62, .band_5_channel64,
         .band_5_channel100, .band_5_channel102, .band_5_channel104, .band_5_channel106, .band_5_channel108,
         .band_5_channel110, .band_5_channel112, .band_5_channel114, .band_5_channel116, .band_5_channel118,
         .band_5_channel120, .band_5_channel122, .band_5_channel124, .band_5_channel126, .band_5_channel128,
         .band_5_channel132, .band_5_channel134, .band_5_channel136, .band_5_channel138, .band_5_channel140,
         .band_5_channel142, .band_5_channel144, .band_5_channel149, .band_5_channel151, .band_5_channel153,
         .band_5_channel155, .band_5_channel157, .band_5_channel159, .band_5_channel161, .band_5_channel165]

    // swiftlint:disable function_body_length

    /// Retrieves the frequency band where this channel operates.
    ///
    /// - Returns: the channel frequency band
    public func getBand() -> Band {
        switch self {
        case .band_2_4_channel1,
             .band_2_4_channel2,
             .band_2_4_channel3,
             .band_2_4_channel4,
             .band_2_4_channel5,
             .band_2_4_channel6,
             .band_2_4_channel7,
             .band_2_4_channel8,
             .band_2_4_channel9,
             .band_2_4_channel10,
             .band_2_4_channel11,
             .band_2_4_channel12,
             .band_2_4_channel13,
             .band_2_4_channel14:
            return .band_2_4_Ghz

        case .band_5_channel34,
             .band_5_channel36,
             .band_5_channel38,
             .band_5_channel40,
             .band_5_channel42,
             .band_5_channel44,
             .band_5_channel46,
             .band_5_channel48,
             .band_5_channel50,
             .band_5_channel52,
             .band_5_channel54,
             .band_5_channel56,
             .band_5_channel58,
             .band_5_channel60,
             .band_5_channel62,
             .band_5_channel64,
             .band_5_channel100,
             .band_5_channel102,
             .band_5_channel104,
             .band_5_channel106,
             .band_5_channel108,
             .band_5_channel110,
             .band_5_channel112,
             .band_5_channel114,
             .band_5_channel116,
             .band_5_channel118,
             .band_5_channel120,
             .band_5_channel122,
             .band_5_channel124,
             .band_5_channel126,
             .band_5_channel128,
             .band_5_channel132,
             .band_5_channel134,
             .band_5_channel136,
             .band_5_channel138,
             .band_5_channel140,
             .band_5_channel142,
             .band_5_channel144,
             .band_5_channel149,
             .band_5_channel151,
             .band_5_channel153,
             .band_5_channel155,
             .band_5_channel157,
             .band_5_channel159,
             .band_5_channel161,
             .band_5_channel165:
            return .band_5_Ghz
        }
    }

    // swiftlint:disable cyclomatic_complexity

    /// Retrieves the channel identifier.
    ///
    /// - Returns: the channel identifier
    public func getChannelId() -> Int {
        switch self {
        case .band_2_4_channel1:    return 1
        case .band_2_4_channel2:    return 2
        case .band_2_4_channel3:    return 3
        case .band_2_4_channel4:    return 4
        case .band_2_4_channel5:    return 5
        case .band_2_4_channel6:    return 6
        case .band_2_4_channel7:    return 7
        case .band_2_4_channel8:    return 8
        case .band_2_4_channel9:    return 9
        case .band_2_4_channel10:   return 10
        case .band_2_4_channel11:   return 11
        case .band_2_4_channel12:   return 12
        case .band_2_4_channel13:   return 13
        case .band_2_4_channel14:   return 14
        case .band_5_channel34:     return 34
        case .band_5_channel36:     return 36
        case .band_5_channel38:     return 38
        case .band_5_channel40:     return 40
        case .band_5_channel42:     return 42
        case .band_5_channel44:     return 44
        case .band_5_channel46:     return 46
        case .band_5_channel48:     return 48
        case .band_5_channel50:     return 50
        case .band_5_channel52:     return 52
        case .band_5_channel54:     return 54
        case .band_5_channel56:     return 56
        case .band_5_channel58:     return 58
        case .band_5_channel60:     return 60
        case .band_5_channel62:     return 62
        case .band_5_channel64:     return 64
        case .band_5_channel100:    return 100
        case .band_5_channel102:    return 102
        case .band_5_channel104:    return 104
        case .band_5_channel106:    return 106
        case .band_5_channel108:    return 108
        case .band_5_channel110:    return 110
        case .band_5_channel112:    return 112
        case .band_5_channel114:    return 114
        case .band_5_channel116:    return 116
        case .band_5_channel118:    return 118
        case .band_5_channel120:    return 120
        case .band_5_channel122:    return 122
        case .band_5_channel124:    return 124
        case .band_5_channel126:    return 126
        case .band_5_channel128:    return 128
        case .band_5_channel132:    return 132
        case .band_5_channel134:    return 134
        case .band_5_channel136:    return 136
        case .band_5_channel138:    return 138
        case .band_5_channel140:    return 140
        case .band_5_channel142:    return 142
        case .band_5_channel144:    return 144
        case .band_5_channel149:    return 149
        case .band_5_channel151:    return 151
        case .band_5_channel153:    return 153
        case .band_5_channel155:    return 155
        case .band_5_channel157:    return 157
        case .band_5_channel159:    return 159
        case .band_5_channel161:    return 161
        case .band_5_channel165:    return 165
        }
    }

    // swiftlint:enable cyclomatic_complexity function_body_length

    /// Debug description.
    public var description: String {
        return "\(getBand().description)-\(getChannelId())"
    }
}

/// Helper class to retrieve the band and channel identifier from a wifi channel.
/// - Note: This class should only be used on Objective-C.
///         In Swift, use `WifiChannel.getChannelId()` and `WifiChannel.getBand()`
@objcMembers
public class GSWifiChannelInfo: NSObject {
    /// Retrieves the frequency band where this channel operates.
    ///
    /// - Parameter wifiChannel: the wifi channel from which to get the band
    /// - Returns: the channel frequency band
    public static func getBand(fromWifiChannel wifiChannel: WifiChannel) -> Band {
        return wifiChannel.getBand()
    }

    /// Retrieves the channel identifier.
    ///
    /// - Parameter wifiChannel: the wifi channel from which to get the channel identifier
    /// - Returns: the channel identifier
    public static func getChannelId(fromWifiChannel wifiChannel: WifiChannel) -> Int {
        return wifiChannel.getChannelId()
    }

    // private init for helper class
    private override init() {

    }
}
