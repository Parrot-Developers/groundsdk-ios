//    Copyright (C) 2019 Parrot Drones SAS
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

/// Update REST Api.
class UpdateRestApi {
    /// Result of a request
    enum Result {
        /// Request succeed
        case success
        /// Request failed
        case failed
        /// Request was canceled
        case canceled
    }

    /// Cloud server utility
    private let cloudServer: CloudServerCore

    /// Cloud server base url
    private let baseUrl: URL = {
        if let alternateServer = GroundSdkConfig.sharedInstance.alternateFirmwareServer,
            let alternateUrl = URL(string: alternateServer) {
            return alternateUrl
        }
        return CloudServerCore.defaultUrl
    }()

    /// Prototype of the callback of the update listing
    ///
    /// - Parameters:
    ///   - result: the result of the listing
    ///   - firmwares: list of firmwares indexed by firmware identifier
    ///   - blacklistedVersions: Set of firmware version indexed by device model
    public typealias ListCompletionCallback = (
        _ result: Result,
        _ firmwares: [FirmwareIdentifier: FirmwareStoreEntry],
        _ blacklistedVersions: [DeviceModel: Set<FirmwareVersion>]) -> Void

    /// Constructor.
    ///
    /// - Parameter cloudServer: the cloud server to use
    init(cloudServer: CloudServerCore) {
        self.cloudServer = cloudServer
    }

    /// Fetch distant update infos for a given list of models
    ///
    /// - Parameters:
    ///   - models: list of models to fetch update infos for.
    ///   - completion: block that will be called when the request completes
    /// - Returns: a request that can be canceled.
    func listAvailableFirmwares(
        models: Set<DeviceModel>, completion: @escaping ListCompletionCallback) -> CancelableCore {

        let productsQueryValue = models.map { String(format: "%04x", $0.internalId) }.joined(separator: ",")
        return cloudServer.getData(
            baseUrl: baseUrl, api: "/apiv1/update", query: ["product": productsQueryValue]) { result, data in
            switch result {
            case .success:
                // listing firmwares is successful
                if let data = data {
                    let decoder = JSONDecoder()
                    do {
                        let requestResult = try decoder.decode(ListRequestResponse.self, from: data)
                        // transform the json object into a `FirmwareStoreEntry` dict indexed by `FirmwareIdentifier`
                        let firmwares = requestResult.firmwares.map { FirmwareStoreEntry.from(httpFirmware: $0) }
                            .compactMap { $0 }.reduce([FirmwareIdentifier: FirmwareStoreEntry]()) { dict, value in
                                var dict = dict
                                dict[value.firmware.firmwareIdentifier] = value
                                return dict
                        }
                        // Blacklisted versions could also be a list of FirmwareIdentifier
                        var blacklistedVersions: [DeviceModel: Set<FirmwareVersion>] = [:]
                        requestResult.blacklistedVersions.forEach { httpBlacklistedVersions in
                            if let model = DeviceModel.from(internalIdHexStr: httpBlacklistedVersions.product) {

                                let blacklistedVersionsForThisModel = httpBlacklistedVersions.versions
                                    .map { FirmwareVersion.parse(versionStr: $0) }.compactMap { $0 }
                                blacklistedVersions[model] = Set(blacklistedVersionsForThisModel)
                            }
                        }
                        completion(.success, firmwares, blacklistedVersions)
                    } catch let error {
                        ULog.w(.fwEngineTag, "Failed to decode data \(String(data: data, encoding: .utf8) ?? ""): " +
                            error.localizedDescription)
                        completion(.failed, [:], [:])
                    }
                }
            case .error,
                .httpError:
                completion(.failed, [:], [:])
            case .canceled:
                completion(.canceled, [:], [:])
            }
        }
    }

    /// Download a firmware
    ///
    /// - Parameters:
    ///   - url: the distant url of the firmware
    ///   - destination: the local destination where the downloaded firmware should be stored
    ///   - didProgress: progress callback
    ///   - progress: download progress, from 0 to 100.
    ///   - didComplete: completion callback
    ///   - result: the request result
    ///   - localUrl: url of the locally stored downloaded firmware. Not nil if result is `.success`.
    /// - Returns: a request that can be canceled.
    func downloadFirmware(
        from url: URL, to destination: URL,
        didProgress progressCb: @escaping (_ progress: Int) -> Void,
        didComplete completionCb: @escaping (_ result: Result, _ localUrl: URL?) -> Void) -> CancelableCore? {

        return cloudServer.downloadFileInBackground(
            url: url, destination: destination, progress: progressCb) { result, localFileUrl in
                let status: Result
                switch result {
                case .success:
                    status = .success
                case .httpError,
                     .error:
                    status = .failed
                case .canceled:
                    status = .canceled
                }
                completionCb(status, localFileUrl)
        }
    }

    /// Response of a list request
    fileprivate struct ListRequestResponse: Decodable {
        //swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case firmwares = "firmware"
            case blacklistedVersions = "blacklist"
        }

        /// List of firmware informations
        let firmwares: [HttpFirmwareInfo]
        /// List of blacklisted version
        let blacklistedVersions: [HttpBlacklistedVersions]
    }

    /// Firmware information extracted from a list request
    fileprivate struct HttpFirmwareInfo: Decodable {
        //swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case product
            case version
            case url
            case size
            case checksum = "md5"
            case requiredVersion = "required_version"
            case maxVersion = "max_version"
            case flags
        }

        /// Identifier of the product onto which the update applies (internal id as hex string).
        let product: String
        /// Version of the update firmware.
        let version: String
        /// Url to download the firmware update file.
        let url: String
        /// Size of the file in bytes.
        let size: UInt64
        /// Checksum of the update file.
        let checksum: String
        /// Required minimal version of the device firmware onto which the update can be applied.
        let requiredVersion: String?
        /// Required maximal version of the device firmware onto which the update can be applied.
        let maxVersion: String?
        /// Firmware flags.
        let flags: [String]?
    }

    /// Blacklisted versions extracted from a list request
    fileprivate struct HttpBlacklistedVersions: Decodable {
        let product: String
        let versions: [String]
    }
}

/// Extension of FirmwareStoreEntry that enables the conversion from an HttpFirmwareInfo
fileprivate extension FirmwareStoreEntry {
    /// Converts an HttpFirmwareInfo to a FirmwareStoreEntry.
    ///
    /// - Parameter httpFirmware: the firmware info
    /// - Returns: a firmware store entry if the http firmware info are parsable.
    static func from(httpFirmware: UpdateRestApi.HttpFirmwareInfo) -> FirmwareStoreEntry? {
        // for now we simply skip unknown flags, as we do not handle all of them
        let attributes = httpFirmware.flags?.map { FirmwareAttribute.from(httpAttribute: $0) }.compactMap { $0 } ?? []

        if let model = DeviceModel.from(internalIdHexStr: httpFirmware.product),
            let version = FirmwareVersion.parse(versionStr: httpFirmware.version),
            let remoteUrl = URL(string: httpFirmware.url) {

            var minVersion: FirmwareVersion?
            if let minVersionStr = httpFirmware.requiredVersion {
                minVersion = FirmwareVersion.parse(versionStr: minVersionStr)
                if minVersion == nil {
                    ULog.w(.fwEngineTag, "Could not translate min fw version \(minVersionStr) into a FirmwareVersion.")
                    return nil
                }
            }

            var maxVersion: FirmwareVersion?
            if let maxVersionStr = httpFirmware.maxVersion {
                maxVersion = FirmwareVersion.parse(versionStr: maxVersionStr)
                if maxVersion == nil {
                    ULog.w(.fwEngineTag, "Could not translate max fw version \(maxVersionStr) into a FirmwareVersion.")
                    return nil
                }
            }

            let firmwareInfo = FirmwareInfoCore(
                firmwareIdentifier: FirmwareIdentifier(deviceModel: model, version: version),
                attributes: Set(attributes), size: httpFirmware.size, checksum: httpFirmware.checksum)
            return FirmwareStoreEntry(
                firmware: firmwareInfo, remoteUrl: remoteUrl, requiredVersion: minVersion, maxVersion: maxVersion,
                embedded: false)
        }
        ULog.w(.fwEngineTag, "Could not translate httpFirmware \(httpFirmware) into a FirmwareInfo.")
        return nil
    }
}

/// Extension of FirmwareAttribute that enables the conversion from a String
fileprivate extension FirmwareAttribute {
    /// Converts a String to a FirmwareStoreEntry.
    ///
    /// - Parameter httpAttribute: the attribute as String
    /// - Returns: an attribute if the given string is known
    static func from(httpAttribute: String) -> FirmwareAttribute? {
        switch httpAttribute {
        case "delete_user_data":
            return .deletesUserData
        default:
            ULog.w(.fwEngineTag, "Could not translate httpAttribute \(httpAttribute) into a FirmwareAttribute.")
            return nil
        }
    }
}
