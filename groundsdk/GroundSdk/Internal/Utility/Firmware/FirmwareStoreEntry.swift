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

/// A firmware entry in the store
struct FirmwareStoreEntry: Codable, CustomStringConvertible {
    /// Error that can happen while decoding a firmware store entry
    enum DecodingError: Error, CustomStringConvertible {

        /// Given model is invalid
        case invalidModel(String)
        /// Given product is invalid
        case invalidProduct(String)
        /// No model info given
        case noModel
        /// Given version is invalid
        case invalidVersion(String)
        /// Given remote url is invalid
        case invalidRemoteUrl(String)
        /// Given attribute is invalid
        case invalidAttribute(String)
        /// Decoded values are incompatible
        case incompatibleAttributes

        /// Debug description.
        var description: String {
            switch self {
            case .invalidModel(let model):      return "Model \(model) is unknown"
            case .invalidProduct(let product):  return "Product \(product) is unknown"
            case .noModel:                      return "No model info parsed"
            case .invalidVersion(let version):  return "Version \(version) can't be parsed"
            case .invalidRemoteUrl(let url):    return "Url \(url) can't be parsed"
            case .invalidAttribute(let attr):   return "Attribute \(attr) is unknown"
            case .incompatibleAttributes:       return "Decoded values are incompatible"
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case model
        case product
        case version
        case path
        case embeddedPath
        case remoteUrl
        case size
        case md5
        case flags
        case requiredVersion = "required_version"
        case maxVersion = "max_version"
        case preset
    }

    /// Firmware information
    let firmware: FirmwareInfoCore
    /// Indicates where the firmware update file is stored locally. `nil` if no update file is available locally
    var localUrl: URL?
    /// Indicates where the firmware update file is available remotely. `nil` if no update file is available remotely
    var remoteUrl: URL?
    /// Minimal device firmware version required to apply the update. `nil` if the update can be applied unconditionally
    let requiredVersion: FirmwareVersion?
    /// Maximal device firmware version required to apply the update. `nil` if the update can be applied unconditionally
    let maxVersion: FirmwareVersion?
    /// Whether the firmware is embedded or not in the app.
    let embedded: Bool

    /// Whether this firmware is local
    var isLocal: Bool {
        return localUrl != nil
    }

    /// Constructor
    ///
    /// - Parameters:
    ///   - firmware: firmware information
    ///   - localUrl: local file URL
    ///   - remoteUrl: remote URL
    ///   - requiredVersion: required firmware version to update with this firmware
    ///   - maxVersion: max firmware version to update with this firmware
    ///   - embedded: whether this firmware is embedded or not
    init(firmware: FirmwareInfoCore, localUrl: URL? = nil, remoteUrl: URL? = nil,
         requiredVersion: FirmwareVersion? = nil, maxVersion: FirmwareVersion? = nil, embedded: Bool) {
        self.firmware = firmware
        self.localUrl = localUrl
        self.remoteUrl = remoteUrl
        self.requiredVersion = requiredVersion
        self.maxVersion = maxVersion
        self.embedded = embedded
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(firmware.firmwareIdentifier.deviceModel.description, forKey: .model)
        try container.encode(firmware.firmwareIdentifier.version.description, forKey: .version)
        try container.encode(firmware.size, forKey: .size)
        try container.encode(firmware.checksum, forKey: .md5)
        if !firmware.attributes.isEmpty {
            try container.encode(firmware.attributes.map { $0.plistStr }, forKey: .flags)
        }

        if let minVersion = requiredVersion {
            try container.encode(minVersion.description, forKey: .requiredVersion)
        }
        if let maxVersion = maxVersion {
            try container.encode(maxVersion.description, forKey: .maxVersion)
        }
        if let localUrl = localUrl {
            if embedded {
                try container.encode(localUrl.lastPathComponent, forKey: .embeddedPath)
            } else {
                let relativePath = localUrl.path.replacingOccurrences(of: NSHomeDirectory(), with: "")
                try container.encode(relativePath, forKey: .path)
            }
        }
        if let remoteUrl = remoteUrl {
            try container.encode(remoteUrl.absoluteString, forKey: .remoteUrl)
        }
        try container.encode(embedded, forKey: .preset)
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        let decodedModel = values.contains(.model) ? try values.decode(String.self, forKey: .model) : nil
        let decodedProduct = values.contains(.product) ? try values.decode(String.self, forKey: .product) : nil
        let decodedVersion = try values.decode(String.self, forKey: .version)
        let decodedPath = values.contains(.path) ? try values.decode(String.self, forKey: .path) : nil
        let decodedEmbeddedPath = values.contains(.embeddedPath) ? try values.decode(String.self,
                                                                                     forKey: .embeddedPath) : nil
        let decodedRemoteUrl = values.contains(.remoteUrl) ? try values.decode(String.self, forKey: .remoteUrl) : nil
        let decodedSize = try values.decode(UInt64.self, forKey: .size)
        let decodedMd5 = try values.decode(String.self, forKey: .md5)
        let decodedFlags = values.contains(.flags) ? try values.decode(Array<String>.self, forKey: .flags) : []
        let decodedMinVersion = values.contains(.requiredVersion) ?
            try values.decode(String.self, forKey: .requiredVersion) : nil
        let decodedMaxVersion = values.contains(.maxVersion) ?
            try values.decode(String.self, forKey: .maxVersion) : nil
        let decodedPreset = values.contains(.preset) ? try values.decode(Bool.self, forKey: .preset) : true
        var model: DeviceModel?

        if let decodedModel = decodedModel {
            model = DeviceModel.from(name: decodedModel)
            guard model != nil else {
                throw DecodingError.invalidModel(decodedModel)
            }
        }
        if let decodedProduct = decodedProduct {
            guard model == nil else {
                throw DecodingError.incompatibleAttributes
            }

            model = DeviceModel.from(internalIdHexStr: decodedProduct)
            guard model != nil else {
                throw DecodingError.invalidProduct(decodedProduct)
            }
        }

        guard model != nil else {
            throw DecodingError.noModel
        }

        guard let version = FirmwareVersion.parse(versionStr: decodedVersion) else {
            throw DecodingError.invalidVersion(decodedVersion)
        }
        if let decodedPath = decodedPath {
            guard decodedEmbeddedPath == nil else {
                throw DecodingError.incompatibleAttributes
            }
            localUrl = URL(fileURLWithPath: NSHomeDirectory().appending(decodedPath), isDirectory: false)
        }
        if let decodedEmbeddedPath = decodedEmbeddedPath {
            guard decodedPath == nil else {
                throw DecodingError.incompatibleAttributes
            }
            localUrl = Bundle.main.url(forResource: decodedEmbeddedPath, withExtension: nil)
        }
        if let decodedRemoteUrl = decodedRemoteUrl {
            remoteUrl = URL(string: decodedRemoteUrl)
            guard remoteUrl != nil else {
                throw DecodingError.invalidRemoteUrl(decodedRemoteUrl)
            }
        }
        let attributes: [FirmwareAttribute] = try decodedFlags.map { flag in
            guard let attribute = FirmwareAttribute(from: flag) else {
                throw DecodingError.invalidAttribute(flag)
            }
            return attribute
        }
        if let decodedMinVersion = decodedMinVersion {
            requiredVersion = FirmwareVersion.parse(versionStr: decodedMinVersion)
            guard requiredVersion != nil else {
                throw DecodingError.invalidVersion(decodedMinVersion)
            }
        } else {
            requiredVersion = nil
        }
        if let decodedMaxVersion = decodedMaxVersion {
            maxVersion = FirmwareVersion.parse(versionStr: decodedMaxVersion)
            guard maxVersion != nil else {
                throw DecodingError.invalidVersion(decodedMaxVersion)
            }
        } else {
            maxVersion = nil
        }

        embedded = decodedPreset

        firmware = FirmwareInfoCore(
            firmwareIdentifier: FirmwareIdentifier(deviceModel: model!, version: version),
            attributes: Set(attributes), size: decodedSize, checksum: decodedMd5)
    }

    var description: String {
        return "\(firmware.firmwareIdentifier.description)\(embedded ? " embedded" : "")" +
            "\(isLocal ? " local" : "")"
    }
}

/// Extension of FirmwareAttribute that enables conversion from/to String
fileprivate extension FirmwareAttribute {

    private typealias AttributeMapperType = (
        attributes: [String: FirmwareAttribute],
        storableAttributes: [FirmwareAttribute: String])

    /// Lazy var which maps each flag string to each firmware attribute
    private static var storableMapper: AttributeMapperType = {
        var mapper = (attributes: [String: FirmwareAttribute](),
                      storableAttributes: [FirmwareAttribute: String]())

        func map(attribute: FirmwareAttribute, storableAttribute: String) {
            mapper.attributes[storableAttribute] = attribute
            mapper.storableAttributes[attribute] = storableAttribute
        }

        // these string cannot change. If they change, version of the FirmwareStoreEntry should change
        map(attribute: .deletesUserData, storableAttribute: "deletesUserData")

        return mapper
    }()

    /// - Note: these string cannot change. If they change, version of the FirmwareStoreEntry should change
    var plistStr: String {
        return FirmwareAttribute.storableMapper.storableAttributes[self]!
    }

    /// Failable constructor
    ///
    /// - Parameter storableAttribute: attribute as string
    init?(from storableAttribute: String) {
        guard let attribute = FirmwareAttribute.storableMapper.attributes[storableAttribute] else {
            return nil
        }
        self = attribute
    }

}
