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

extension ULogTag {

    /// Logging tag of ground sdk
    static let tag = ULogTag(name: "gsdk")

    /// Logging tag of ground sdk core (internal)
    static let coreTag = ULogTag(name: "gsdk.core")

    /// Logging tag of video in ground sdk core (internal)
    static let coreVideoTag = ULogTag(name: "gsdk.core.video")

    /// Logging tag of media in ground sdk core (internal)
    static let coreMediaTag = ULogTag(name: "gsdk.core.media")

    /// Logging tag of firmware handling in ground sdk core (internal)
    static let coreFwTag = ULogTag(name: "gsdk.core.fw")

    /// Logging tag of camera handling in ground sdk core (internal)
    static let cameraTag = ULogTag(name: "gsdk.core.camera")

    /// Logging tag of ground sdk autoconnection engine (internal)
    static let autoConnectEngineTag = ULogTag(name: "gsdk.core.engine.autoconnect")

    /// Logging tag of ground sdk system engine (internal)
    static let systemEngineTag = ULogTag(name: "gsdk.core.engine.system")

    /// Logging tag of ground sdk crash report engine (internal)
    static let crashReportEngineTag = ULogTag(name: "gsdk.core.engine.crashreport")

    /// Logging tag of ground sdk flight data (PUDs) engine (internal)
    static let flightDataEngineTag = ULogTag(name: "gsdk.core.engine.flightdata")

    /// Logging tag of ground sdk flight log engine (internal)
    static let flightLogEngineTag = ULogTag(name: "gsdk.core.engine.flightlog")

    /// Logging tag of ground sdk black box engine (internal)
    static let blackBoxEngineTag = ULogTag(name: "gsdk.core.engine.blackbox")

    /// Logging tag of ground sdk firmware engine (internal)
    static let fwEngineTag = ULogTag(name: "gsdk.core.engine.firmware")

    /// Logging tag of ground sdk activation engine (internal)
    static let activationEngineTag = ULogTag(name: "gsdk.core.engine.activation")

    /// Logging tag of ground sdk internet monitor (internal)
    static let internetConnectivityTag = ULogTag(name: "gsdk.core.utility.internet")

    /// Logging tag of ground sdk crash reporter utility (internal)
    static let crashReportStorageTag = ULogTag(name: "gsdk.core.utility.crashreport")

    /// Logging tag of ground sdk crash reporter utility (internal)
    static let flightDataStorageTag = ULogTag(name: "gsdk.core.utility.flightdata")

    /// Logging tag of ground sdk flightLog reporter utility (internal)
    static let flightLogStorageTag = ULogTag(name: "gsdk.core.utility.flightlog")

    /// Logging tag of http client
    static let httpClientTag = ULogTag(name: "gsdk.core.httpclient")

    /// Logging tag of ground sdk reverseGeocoding engine (internal)
    static let reverseGeocoderEngineTag = ULogTag(name: "gsdk.core.engine.reversegeocoding")

    /// Logging tag of ground sdk GroundSdkUserDefaults (internal)
    static let groundSdkUserDefaultsTag = ULogTag(name: "gsdk.core.userdefaults")

    /// Logging tag of ground sdk user account engine (internal)
    static let userAccountEngineTag = ULogTag(name: "gsdk.core.engine.useraccount")

    /// Ephemeris tag of ground sdk ephemeris engine (internal)
    static let ephemerisEngineTag = ULogTag(name: "gsdk.core.engine.ephemeris")

    /// FileManager Extension tag of ground sdk (internal)
    static let fileManagerExtensionTag = ULogTag(name: "gsdk.core.filemanager")

    /// Logging tag of stream in ground sdk core (internal)
    static let streamTag = ULogTag(name: "gsdk.core.stream")

    /// Logging tag of ground sdk video stream engine (internal)
    static let videoStreamEngineTag = ULogTag(name: "gsdk.core.engine.stream")

    /// tag myparrot debug
    static let myparrot = ULogTag(name: "MYPARROT-gsdkv1-")

    /// tag Hmd
    static let hmdTag = ULogTag(name: "gsdk.hmd")
}
