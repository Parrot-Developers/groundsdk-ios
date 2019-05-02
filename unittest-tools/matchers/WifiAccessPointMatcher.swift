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

import GroundSdk

func environmentIs(_ environment: Environment, updating: Bool, mutable: Bool) -> Matcher<WifiAccessPoint> {
    return Matcher("\(environment) [updating: \(updating), mutable: \(mutable)]") { (wifiAccessPoint) -> MatchResult in
        let environmentSetting = wifiAccessPoint.environment
        if environmentSetting.value != environment || environmentSetting.updating != updating ||
            environmentSetting.mutable != mutable {
            return .mismatch("\(environmentSetting.value) [updating: \(environmentSetting.updating)," +
                "mutable: \(environmentSetting.mutable)]")
        }
        return .match
    }
}

func countryIs(_ isoCountryCode: String, updating: Bool) -> Matcher<WifiAccessPoint> {
    return Matcher("\(isoCountryCode) [updating: \(updating)]") { (wifiAccessPoint) -> MatchResult in
        let countrySetting = wifiAccessPoint.isoCountryCode
        if countrySetting.value != isoCountryCode || countrySetting.updating != updating {
            return .mismatch("\(countrySetting.value) [updating: \(countrySetting.updating)]")
        }
        return .match
    }
}

func channelIs(_ channel: WifiChannel, selectionMode: ChannelSelectionMode,updating: Bool)
    -> Matcher<WifiAccessPoint> {
        let description = "\(channel) [selectionMode: \(selectionMode) updating: \(updating)]"
        return Matcher(description) { (wifiAccessPoint) -> MatchResult in
            let channelSetting = wifiAccessPoint.channel
            if channelSetting.channel != channel || channelSetting.selectionMode != selectionMode ||
                channelSetting.updating != updating {
                return .mismatch("\(channelSetting.channel) "
                    + "[selectionMode: \(channelSetting.selectionMode) " +
                    "updating: \(channelSetting.updating)]")
            }
            return .match
        }
}

func securityIs(_ mode: SecurityMode, updating: Bool) -> Matcher<WifiAccessPoint> {
        return Matcher("\(mode) [updating: \(updating)]") { (wifiAccessPoint) -> MatchResult in
            let securitySetting = wifiAccessPoint.security
            if securitySetting.mode != mode || securitySetting.updating != updating {
                return .mismatch("\(securitySetting.mode) [updating: \(securitySetting.updating)]")
            }
            return .match
        }
}
