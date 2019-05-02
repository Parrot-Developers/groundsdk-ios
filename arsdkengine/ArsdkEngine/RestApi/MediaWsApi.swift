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

/// WebSocket API notifying changes of mediastore content
class MediaWsApi {

    /// Drone server
    private let server: DroneServer
    /// closure called when the websocket notify changes of media store content
    private let contentDidChange: () -> Void
    /// Active websocket session
    private var webSocketSession: WebSocketSession?

    /// notification API
    private let api = "/api/v1/media/notifications"

    /// Constructor
    ///
    /// - Parameters:
    ///   - server: the drone server from which medias should be accessed
    ///   - eventCb: callback called when media store content has changed
    init(server: DroneServer, eventCb: @escaping () -> Void) {
        self.server = server
        self.contentDidChange = eventCb
        startSession()
    }

    /// Starts the websocket session
    private func startSession() {
        webSocketSession = server.newWebSocketSession(api: api, delegate: self)
    }

    /// Notification event.
    private struct Event: Decodable {

        /// Event type
        enum EventType: String, Decodable {
            /// The first resource of a new media has been created
            case mediaCreated = "media_created"
            /// The last resource of a media has been removed
            case mediaRemoved = "media_removed"
            /// A new resource of an existing media has been created
            case resourceCreated = "resource_created"
            /// A resource of a media has been removed, the media still has remaining resource
            case resourceRemoved = "resource_removed"
            /// All media have been removed
            case allMediaRemoved = "all_media_removed"
            /// Media database indexing state has changed
            case indexingStateChanged = "indexing_state_changed"
        }
        /// event name
        let name: EventType
    }
}

extension MediaWsApi: WebSocketSessionDelegate {

    func webSocketSessionDidReceiveMessage(_ data: Data) {
        ULog.d(.mediaTag, String(data: data, encoding: .utf8))

        // decode message
        do {
            let event = try JSONDecoder().decode(Event.self, from: data)
            switch event.name {
            case .mediaCreated, .mediaRemoved, .resourceCreated, .resourceRemoved, .allMediaRemoved,
                 .indexingStateChanged:
                contentDidChange()
            }
        } catch let error {
            ULog.w(.mediaTag, "Failed to decode data: \(error.localizedDescription)")
        }
    }

    func webSocketSessionDidDisconnect() {
        // Unexpected disconnect, retry
        webSocketSession = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250)) { [weak self] in
            self?.startSession()
        }
    }

    func webSocketSessionConnectionDidFail() {
        // Connection failure, retry
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [weak self] in
            self?.startSession()
        }
    }
}
