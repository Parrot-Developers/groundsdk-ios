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
import GroundSdk

/// Object to access the drone http server.
class DroneServer {

    /// Base Http URL of this session
    private let baseHttpUrl: URL

    /// Base WebSocket URL of this session
    private let baseWsUrl: URL

    /// The http session to use
    private let httpSession: HttpSessionCore

    /// The web socket client to use
    private let webSocket: WebSocket

    /// Constructor
    ///
    /// - Parameters:
    ///   - address: the address of the session
    ///   - port: port of the session
    ///   - httpSession: the http session to use.
    ///                  Callers can override the default value in order to mock the http session.
    ///   - webSocket: webSocket client to use.
    init(address: String, port: Int,
         httpSession: HttpSessionCore = HttpSessionCore(sessionConfiguration: .default),
         webSocket: WebSocket = WebSocketClient()) {
        // can force unwrap because this api is private and we ensure that all formed urls are not nil
        baseHttpUrl = URL(string: "http://\(address):\(port)")!
        baseWsUrl = URL(string: "ws://\(address):\(port)")!
        self.httpSession = httpSession
        self.webSocket = webSocket
    }

    /// Get data
    ///
    /// - Note: the request is started in this function.
    ///
    /// - Parameters:
    ///   - api: api to use
    ///   - completion: completion callback
    ///   - result: the request result
    ///   - data: the data that has been get. Nil if result is not `.success`
    /// - Returns: the request
    func getData(
        api: String,
        completion: @escaping (_ result: HttpSessionCore.Result, _ data: Data?) -> Void) -> CancelableCore {

        let request = URLRequest(url: baseHttpUrl.appendingPathComponent(api),
                                 cachePolicy: .reloadIgnoringLocalCacheData)

        return httpSession.getData(request: request, completion: completion)
    }

    /// Send a file with a put request
    ///
    /// - Note: the request is started in this function.
    ///
    /// - Parameters:
    ///   - api: api to use
    ///   - fileUrl: local file url
    ///   - timeoutInterval: the timeout interval. Default value is 60.
    ///   - progress: progress callback
    ///   - progressValue: progress percentage (from 0 to 100)
    ///   - completion: completion callback
    ///   - result: the request result
    ///   - data: data returned in the response body
    /// - Returns: the request
    func putFile(
        api: String, fileUrl: URL, timeoutInterval: TimeInterval = 60,
        progress: @escaping (_ progressValue: Int) -> Void,
        completion: @escaping (_ result: HttpSessionCore.Result, _ data: Data?) -> Void) -> CancelableCore {

        let request = URLRequest(
            url: baseHttpUrl.appendingPathComponent(api), cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: timeoutInterval)

        return httpSession.sendFile(request: request, fileUrl: fileUrl, progress: progress, completion: completion)
    }

    /// Download a file with a get request
    ///
    /// - Note: the request is started in this function.
    ///
    /// - Parameters:
    ///   - api: api to use
    ///   - Parameters: parameters to add in the http request (a dictionary [key:value], with `key` as the parameter
    /// name, and `value` as the value of the parameter. Default is [:]
    ///   - destination: destination local file url
    ///   - progress: progress callback
    ///   - progressValue: progress percentage (from 0 to 100)
    ///   - completion: completion callback
    ///   - result: the request result
    ///   - localFileUrl: the local file url of the downloaded file
    /// - Returns: the request
    func downloadFile(
        api: String, parameters: [String: String] = [:],
        destination: URL, progress: @escaping (_ progressValue: Int) -> Void,
        completion: @escaping (_ result: HttpSessionCore.Result, _ localFileUrl: URL?) -> Void) -> CancelableCore {

        var components = URLComponents(url: baseHttpUrl.appendingPathComponent(api), resolvingAgainstBaseURL: false)!
        components.queryItems = parameters.map { (key, value) in
            URLQueryItem(name: key, value: value)
        }
        let request = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData)

        return httpSession.downloadFile(
            request: request, destination: destination, progress: progress, completion: completion)
    }

    /// Download a file with a get request and uses a StreamDecoder to convert the result
    ///
    /// - Note: the request is started in this function.
    ///
    /// - Parameters:
    ///   - api: api to use
    ///   - withStreamDecoder: Custom decoder (see `StreamDecoder` Protocol)
    ///   - destination: destination local file url
    ///   - completion: completion callback
    ///   - result: the request result
    ///   - localFileUrl: the local file url of the downloaded file
    /// - Returns: the request
    open func downloadFile(
        api: String, withStreamDecoder: StreamDecoder, destination: URL,
        completion: @escaping (_ result: HttpSessionCore.Result, _ localFileUrl: URL?) -> Void) -> CancelableCore {

        let request = URLRequest(url: baseHttpUrl.appendingPathComponent(api),
                                 cachePolicy: .reloadIgnoringLocalCacheData)
        return httpSession.downloadFile(
            streamDecoder: withStreamDecoder, request: request, destination: destination, completion: completion)
    }

    /// Request a delete
    ///
    /// - Parameters:
    ///   - api: api to use
    ///   - completion: completion callback
    ///   - result: the request result
    /// - Returns: the request
    func delete(api: String, completion: @escaping (_ result: HttpSessionCore.Result) -> Void) -> CancelableCore {

        let request = URLRequest(url: baseHttpUrl.appendingPathComponent(api),
                                 cachePolicy: .reloadIgnoringLocalCacheData)
        return httpSession.delete(request: request, completion: completion)
    }

    /// Create a new websocket session
    ///
    /// - Parameters:
    ///   - api: web socket api
    ///   - delegate: delegate
    /// - Returns: new web socket session
    func newWebSocketSession(api: String, delegate: WebSocketSessionDelegate) -> WebSocketSession {
        // can force unwrap because this api is private and we ensure that all formed urls are not nil
        return webSocket.createSession(baseUrl: baseWsUrl, api: api, delegate: delegate)!
    }
}
