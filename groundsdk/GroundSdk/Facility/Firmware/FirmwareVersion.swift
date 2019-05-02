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

/// Firmware version type.
@objc(GSFirmwareVersionType)
public enum FirmwareVersionType: Int {

    /// Development type.
    case dev

    /// Alpha type.
    case alpha

    /// Beta version.
    case beta

    /// Release candidate version.
    case rc

    /// Release version
    case release

    /// Debug description.
    public var description: String {
        switch self {
        case .dev:
            return "dev"
        case .alpha:
            return "alpha"
        case .beta:
            return "beta"
        case .rc:
            return "rc"
        case .release:
            return "release"
        }
    }
}

/// Object that represents a version of the firmware.
@objcMembers
@objc(GSFirmwareVersion)
public class FirmwareVersion: NSObject {

    /// An unknown version.
    public static let unknown = parse(versionStr: "0.0.0")!

    /// ArsdkFirmwareVersion that this FirmwareVersion represents.
    private let arsdkVersion: ArsdkFirmwareVersion

    /// Major value of the version.
    public var major: Int {
        return arsdkVersion.major
    }

    /// Minor value of the version.
    public var minor: Int {
        return arsdkVersion.minor
    }

    /// Patch value of the version.
    public var patch: Int {
        return arsdkVersion.patch
    }

    /// Type of the version.
    public var type: FirmwareVersionType {
        switch arsdkVersion.type {
        case .dev:
            return .dev
        case .alpha:
            return .alpha
        case .beta:
            return .beta
        case .release:
            return .release
        case .rc:
            return .rc
        }
    }

    /// Build number version.
    /// Only valid if type is different from .release. Negative otherwise.
    public var buildNumber: Int {
        return arsdkVersion.build
    }

    /// Description of the version.
    /// This will be major.minor.patch-typebuildNumber for alpha, beta and rc
    /// And major.minor.patch for prod type
    public override var description: String {
        if self.type == .release || self.type == .dev {
            return "\(major).\(minor).\(patch)"
        } else {
            return "\(major).\(minor).\(patch)-\(type.description)\(buildNumber)"
        }
    }

    /// Constructor.
    ///
    /// - Parameter arsdkVersion: ArsdkFirmwareVersion that this FirmwareVersion represents
    private init(arsdkVersion: ArsdkFirmwareVersion) {
        self.arsdkVersion = arsdkVersion
    }

    /// Converts a formatted version string to a FirmwareVersion.
    ///
    /// - Parameter versionStr: formatted version string to parse
    /// - Returns:  a new FirmwareVersion instance corresponding to the provided version string, or `nil` if the version
    ///             string could not be parsed
    public static func parse(versionStr: String) -> FirmwareVersion? {
        if let arsdkVersion = ArsdkFirmwareVersion(fromName: versionStr) {
            return FirmwareVersion(arsdkVersion: arsdkVersion)
        }
        return nil
    }
}

extension FirmwareVersion: Comparable {
    public static func < (lhs: FirmwareVersion, rhs: FirmwareVersion) -> Bool {
        return lhs.arsdkVersion.compare(rhs.arsdkVersion) == .orderedAscending
    }

    public static func == (lhs: FirmwareVersion, rhs: FirmwareVersion) -> Bool {
        return lhs.arsdkVersion.compare(rhs.arsdkVersion) == .orderedSame
    }

    override public func isEqual(_ object: Any?) -> Bool {
        if let otherSystemVersionCore = object as? FirmwareVersion {
            return self == otherSystemVersionCore
        }
        return false
    }

    public override var hash: Int {
        return major.hashValue &* 31 &+ minor.hashValue &* 31 &+ patch.hashValue &* 31 &+ type.hashValue &* 31
            &+ buildNumber.hashValue &* 31
    }

}
