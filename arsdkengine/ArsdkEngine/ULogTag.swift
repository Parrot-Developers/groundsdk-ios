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
import SdkCore

extension ULogTag {
    /// Core logging tag of arsdk engine
    static let tag = ULogTag(name: "arsdkengine")

    /// Logging tag of arsdk engine controller
    static let ctrlTag = ULogTag(name: "arsdkengine.ctrl")

    /// Logging tag of arsdk engine mapper
    static let mapperTag = ULogTag(name: "arsdkengine.mapper")

    /// Logging tag of arsdk engine firmware
    static let fwTag = ULogTag(name: "arsdkengine.firmware")

    /// Logging tag of arsdk engine flight plan
    static let flightPlanTag = ULogTag(name: "arsdkengine.flightplan")

    /// Logging tag of arsdk engine wifi
    static let wifiTag = ULogTag(name: "arsdkengine.wifi")

    /// Logging tag of arsdk engine animation
    static let animationTag = ULogTag(name: "arsdkengine.animation")

    /// Logging tag of arsdk engine camera
    static let cameraTag = ULogTag(name: "arsdkengine.camera")

    /// Logging tag of arsdk CrashML
    static let crashMLTag = ULogTag(name: "arsdkengine.crashml")

    /// Logging tag of arsdk Pud
    static let pudTag = ULogTag(name: "arsdkengine.pud")

    /// Logging tag of arsdk Media
    static let mediaTag = ULogTag(name: "arsdkengine.media")

    /// Logging tag of arsdk Gimbal
    static let gimbalTag = ULogTag(name: "arsdkengine.gimbal")

    /// Logging tag of arsdk webSocket session
    static let wsTag = ULogTag(name: "arsdkengine.ws")

    /// Logging tag of arsdk ephemeris
    static let ephemerisTag = ULogTag(name: "arsdkengine.ephemeris")

    /// Logging tag of arsdk webSocket session
    static let flightLogTag = ULogTag(name: "arsdkengine.flightlog")

    /// Logging tag of arsdk stream
    static let streamTag = ULogTag(name: "arsdkengine.stream")
}
