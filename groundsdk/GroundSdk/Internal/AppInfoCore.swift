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
//    * Neither the name of Parrot nor the names
//      of its contributors may be used to endorse or promote products
//      derived from this software without specific prior written
//      permission.
//
//    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//    COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
//    OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
//    AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
//    OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//    SUCH DAMAGE.

import Foundation
import UIKit

/// Wrapper to access application and sdk info from Bundles
public class AppInfoCore {
    /// Application bundle identifier string
    public static let appBundle = Bundle.main.bundleId
    /// Application version string
    public static let appVersion = Bundle.main.versionString
    /// GroundSdk bundle identifier string
    public static let sdkBundle = Bundle(for: GroundSdk.self).bundleId
    /// GroundSdk version string
    public static let sdkVersion = Bundle(for: GroundSdk.self).versionString
    /// Device model string
    public static let deviceModel = UIDevice.current.model
    /// System version string
    public static let systemVersion = UIDevice.current.systemVersion
}

// Extension to extract info from bundle
private extension Bundle {

    /// Non optional bundleIdentifier
    var bundleId: String {
        return bundleIdentifier ?? "unknown"
    }

    /// Version string
    var versionString: String {
        let version = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
#if !DEBUG
        // special case for parrot applications: strip `-rcX` for release build
        if bundleId.starts(with: "com.parrot") && !bundleId.contains(".inhouse"),
            let index = version.range(of: "-rc")?.lowerBound {
            return String(version[..<index])
        }
#endif
        return version
    }
}
