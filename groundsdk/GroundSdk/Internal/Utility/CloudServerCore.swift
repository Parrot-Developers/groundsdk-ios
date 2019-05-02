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
import UIKit

/// Object to access Parrot cloud server.
///
/// This utility can be forced unwrapped when accessed since this utility will always be accessible.
public class CloudServerCore: UtilityCore {

    public let desc: UtilityCoreDescriptor = Utilities.cloudServer

    /// Base URL of this session
    static public let defaultUrl = URL(string: "https://appcentral.parrot.com")!

    /// The http session to use
    private let httpSession: HttpSessionCore

    /// The http session to use to download/upload files in background
    private let bgHttpSession: HttpSessionCore

    /// Utility store
    private let utilityRegistry: UtilityCoreRegistry

    /// Creates a custom session configuration, based on the default one and with a custom user agent.
    ///
    /// - Returns: a custom session configuration
    public static func customSessionConfiguration() -> URLSessionConfiguration {
        let urlSession = URLSessionConfiguration.default
        urlSession.addHttpAdditionalHeaders()
        return urlSession
    }

    /// Creates a custom background session configuration with a custom user agent.
    ///
    /// - Returns: a custom session configuration
    public static func customBgSessionConfiguration() -> URLSessionConfiguration {
        let urlSession = URLSessionConfiguration.background(withIdentifier: "gsdk")
        urlSession.addHttpAdditionalHeaders()
        return urlSession
    }

    /// Constructor
    ///
    /// - Parameters:
    ///   - utilityCoreRegistery: utilityStore
    ///   - httpSession: the http session to use.
    ///                  Callers can override the default value in order to mock the http session.
    ///   - bgHttpSession: the background http session to use.
    ///                    Callers can override the default value in order to mock the http session.
    public init(
        utilityRegistry: UtilityCoreRegistry,
        httpSession: HttpSessionCore = HttpSessionCore(sessionConfiguration: customSessionConfiguration()),
        bgHttpSession: HttpSessionCore = HttpSessionCore(sessionConfiguration: customBgSessionConfiguration())) {
        self.utilityRegistry = utilityRegistry
        self.httpSession = httpSession
        self.bgHttpSession = bgHttpSession
    }

    /// Get data
    ///
    /// - Note: the request is started in this function.
    ///
    /// - Parameters:
    ///   - baseUrl: server base url. Use default server URL if not provided.
    ///   - api: api to use
    ///   - query: list of params to pass to the request. Default is `nil`.
    ///   - completion: completion callback
    ///   - result: the request result
    ///   - data: the data that has been get. `nil` if result is not `.success`.
    /// - Returns: the request
    public func getData(
        baseUrl: URL = CloudServerCore.defaultUrl,
        api: String,
        query: [String: String]? = nil,
        completion: @escaping (_ result: HttpSessionCore.Result, _ data: Data?) -> Void) -> CancelableCore {

        var urlComponents = URLComponents(url: baseUrl.appendingPathComponent(api), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = query?.map { return URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: urlComponents.url!)
        updateHeader(&request)
        return httpSession.getData(request: request, completion: completion)
    }

    /// Send data
    ///
    /// - Note: the request is started in this function.
    ///
    /// - Parameters:
    ///   - baseUrl: server base url. Use default server URL if not provided.
    ///   - api: api to use
    ///   - data: data to send
    ///   - method: the method to use to send the data
    ///   - requestCustomization: closure that will be called after that the `URLRequest` has been created. This request
    ///                           can be customized by the caller through this closure.
    ///   - completion: completion callback
    ///   - result: the request result
    ///   - data: the data that has been get. `nil` if result is not `.success`
    /// - Returns: the request
    public func sendData(
        baseUrl: URL = CloudServerCore.defaultUrl,
        api: String,
        data: Data?,
        method: HttpSessionCore.SendMethod = .put,
        requestCustomization: (inout URLRequest) -> Void = { _ in },
        completion: @escaping (_ result: HttpSessionCore.Result, _ data: Data?) -> Void) -> CancelableCore {

        var request = URLRequest(url: baseUrl.appendingPathComponent(api))
        requestCustomization(&request)
        request.httpBody = data

        return httpSession.sendData(request: request, method: method, completion: completion)
    }

    /// Send a file
    ///
    /// - Note: the request is started in this function.
    ///
    /// - Parameters:
    ///   - baseUrl: server base url. Use default server URL if not provided.
    ///   - api: api to use
    ///   - fileUrl: local file url
    ///   - method: the method to use to send the file
    ///   - requestCustomization: closure that will be called after that the `URLRequest` has been created. This request
    ///                           can be customized by the caller through this closure.
    ///   - progress: progress callback
    ///   - progressValue: progress percentage (from 0 to 100)
    ///   - completion: completion callback
    ///   - result: the request result
    /// - Returns: the request
    public func sendFile(
        baseUrl: URL = CloudServerCore.defaultUrl,
        api: String, fileUrl: URL,
        method: HttpSessionCore.SendMethod = .put,
        requestCustomization: (inout URLRequest) -> Void = { _ in },
        progress: @escaping (_ progressValue: Int) -> Void,
        completion: @escaping (_ result: HttpSessionCore.Result, _ data: Data?) -> Void) -> CancelableCore {

        var request = URLRequest(url: baseUrl.appendingPathComponent(api))
        requestCustomization(&request)
        updateHeader(&request)

        return httpSession.sendFile(
            request: request, method: method, fileUrl: fileUrl, progress: progress, completion: completion)
    }

    /// Download a file with a get request
    ///
    /// - Note: the request is started in this function.
    ///
    /// - Parameters:
    ///   - baseUrl: server base url. Use default server URL if not provided.
    ///   - api: api to use
    ///   - destination: destination local file url
    ///   - progress: progress callback
    ///   - progressValue: progress percentage (from 0 to 100)
    ///   - completion: completion callback
    ///   - result: the request result
    ///   - localFileUrl: the local file url of the downloaded file. Note that when the completion closure exits, this
    ///                   local file will deleted.
    /// - Returns: the request
    public func downloadFile(
        baseUrl: URL = CloudServerCore.defaultUrl,
        api: String, destination: URL, progress: @escaping (_ progressValue: Int) -> Void,
        completion: @escaping (_ result: HttpSessionCore.Result, _ localFileUrl: URL?) -> Void) -> CancelableCore {

        var request = URLRequest(url: baseUrl.appendingPathComponent(api))
        updateHeader(&request)
        return httpSession.downloadFile(
            request: request, destination: destination, progress: progress, completion: completion)
    }

    /// Download a file with a get request in background.
    ///
    /// - Note:
    ///   - the request is started in this function.
    ///   - the download might be continued in background
    ///   - the application should catch `application(:handleEventsForBackgroundURLSession:completionHandler:)` in the
    ///     AppDelegate class and give the completionHandler back to GroundSdk through
    ///     `GroundSdk.setBackgroundUrlSessionCompletionHandler(completionHandler:forSessionIdentifier)`.
    ///
    /// - Parameters:
    ///   - baseUrl: server base url. Use default server URL if not provided.
    ///   - url: url of the file to download
    ///   - destination: destination local file url
    ///   - progress: progress callback
    ///   - progressValue: progress percentage (from 0 to 100)
    ///   - completion: completion callback
    ///   - result: the request result
    ///   - localFileUrl: the local file url of the downloaded file. Note that when the completion closure exits, this
    ///                   local file will deleted.
    /// - Returns: the request
    public func downloadFileInBackground(
        baseUrl: URL = CloudServerCore.defaultUrl,
        url: URL, destination: URL, progress: @escaping (_ progressValue: Int) -> Void,
        completion: @escaping (_ result: HttpSessionCore.Result, _ localFileUrl: URL?) -> Void) -> CancelableCore {

        let request = URLRequest(url: url)
        return bgHttpSession.downloadFile(
            request: request, destination: destination, progress: progress, completion: completion)
    }

    /// Request a delete
    ///
    /// - Parameters:
    ///   - baseUrl: server base url. Use default server URL if not provided.
    ///   - api: api to use
    ///   - completion: completion callback
    ///   - result: the request result
    /// - Returns: the request
    public func delete(
        baseUrl: URL = CloudServerCore.defaultUrl,
        api: String,
        completion: @escaping (_ result: HttpSessionCore.Result) -> Void) -> CancelableCore {

        var request = URLRequest(url: baseUrl.appendingPathComponent(api))
        updateHeader(&request)
        return httpSession.delete(request: request, completion: completion)
    }

    /// Add or remove the field "x-account" in the http header
    ///
    /// - Note: this function is called when a request is asked to the session. The UserAccount Utility is used in order
    /// to retrieve the userAccount information
    ///
    /// - Parameter httpSessionCore: the httpSessionCore for which we update the http header
    private func updateHeader(_ request: inout URLRequest) {
        // User Account Info is present
        let userAccountUtility = utilityRegistry.getUtility(Utilities.userAccount)
        if let userAccountValue = userAccountUtility?.userAccountInfo?.account {
            // add the field "x-account" in the http header
            request.addValue(userAccountValue, forHTTPHeaderField: "x-account")
        }
    }
}

// URLSessionConfiguration extension to add some headers
private extension URLSessionConfiguration {

    /// Add User agent and api key headers
    func addHttpAdditionalHeaders() {
        // user agent
        let userAgent = "\(AppInfoCore.appBundle)/\(AppInfoCore.appVersion) " +
            "(\(UIDevice.current.systemName); \(UIDevice.identifier); \(UIDevice.current.systemVersion)) " +
        "\(AppInfoCore.sdkBundle)/\(AppInfoCore.sdkVersion)"
        var additionalHeaders = ["User-Agent": userAgent]

        // Application key if present
        if let applicationKey = GroundSdkConfig.sharedInstance.applicationKey {
            additionalHeaders["x-api-key"] = applicationKey
        }

        httpAdditionalHeaders = additionalHeaders
    }
}

/// Description of the Cloud server utility
public class CloudServerCoreDesc: NSObject, UtilityCoreApiDescriptor {
    public typealias ApiProtocol = CloudServerCore
    public let uid = UtilityUid.cloudServer.rawValue
}
