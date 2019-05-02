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

/// A blacklisted firmware version entry in the store
struct BlacklistStoreEntry: Codable {
    /// Error that can happen while decoding a blacklist store entry
    enum DecodingError: Error, CustomStringConvertible {

        /// Given model is invalid
        case invalidModel(String)
        /// Given version is invalid
        case invalidVersion(String)

        var description: String {
            switch self {
            case .invalidModel(let model):      return "Model \(model) is unknown"
            case .invalidVersion(let version):  return "Version \(version) can't be parsed"
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case model
        case versions
        case preset
    }

    /// Device model
    let deviceModel: DeviceModel
    /// Set of blacklisted versions.
    private(set) var versions: Set<FirmwareVersion>
    /// Whether the blacklist is provided by the app or not.
    let embedded: Bool

    /// Constructor
    ///
    /// - Parameters:
    ///   - deviceModel: device model info
    ///   - versions: set of blacklisted versions
    ///   - embedded: whether this blacklist is provided by the app or not
    init(deviceModel: DeviceModel, versions: Set<FirmwareVersion>, embedded: Bool) {
        self.deviceModel = deviceModel
        self.versions = versions
        self.embedded = embedded
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(deviceModel.description, forKey: .model)
        try container.encode(versions.map { $0.description }, forKey: .versions)
        try container.encode(embedded, forKey: .preset)
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        let decodedModel = try values.decode(String.self, forKey: .model)
        let decodedVersions = try values.decode(Array<String>.self, forKey: .versions)
        let decodedPreset = values.contains(.preset) ? try values.decode(Bool.self, forKey: .preset) : true

        guard let model = DeviceModel.from(name: decodedModel) else {
            throw DecodingError.invalidModel(decodedModel)
        }

        let versions: [FirmwareVersion] = try decodedVersions.map { versionStr in
            guard let version = FirmwareVersion.parse(versionStr: versionStr) else {
                throw DecodingError.invalidVersion(versionStr)
            }
            return version
        }

        self.deviceModel = model
        self.versions = Set(versions)
        self.embedded = decodedPreset
    }

    /// Add a list of blacklisted versions to the existing list.
    ///
    /// - Parameter versions: the blacklisted versions to add
    /// - Returns: true if the list of blacklisted versions has changed
    @discardableResult mutating func add(versions: Set<FirmwareVersion>) -> Bool {
        let hasChanged = !versions.isSubset(of: self.versions)
        self.versions.formUnion(versions)
        return hasChanged
    }
}
