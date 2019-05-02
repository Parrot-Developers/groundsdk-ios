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

/// Websocket client delegate
protocol WebSocketSessionDelegate: class {
    /// A message has been received
    ///
    /// - Parameter data: received message data
    func webSocketSessionDidReceiveMessage(_ data: Data)
    /// Web socket did disconnect
    func webSocketSessionDidDisconnect()
    /// Web socket connection did fail
    func webSocketSessionConnectionDidFail()
}

/// A web socket client session
protocol WebSocketSession {
    /// Constructor
    ///
    /// - Parameters:
    ///   - baseUrl: websocket server baser url. Scheme must be `ws`
    ///   - api: websocket api for this session
    ///   - delegate: delegate
    init?(baseUrl: URL, api: String, delegate: WebSocketSessionDelegate)
}

/// A web socket client
protocol WebSocket {
    func createSession(baseUrl: URL, api: String, delegate: WebSocketSessionDelegate) -> WebSocketSession?
}

/// Default implementation of WebSocket
class WebSocketClient: WebSocket {
    func createSession(baseUrl: URL, api: String, delegate: WebSocketSessionDelegate) -> WebSocketSession? {
        return WebSocketClientSession(baseUrl: baseUrl, api: api, delegate: delegate)
    }
}

/// A basic websocket session implementation
/// This implementation is not compliant with the spec. Only text messages are supported
/// Binary, Ping, Pong messages are not implemented.
/// Messages split in multiple frames are not supported
class WebSocketClientSession: WebSocketSession {

    /// Socket connection
    private var connection: StreamSocketConnection
    /// Delegate
    private weak var delegate: WebSocketSessionDelegate?
    /// Input buffer
    private var inputBuffer = Data()
    /// True when websocket protocol is connected
    private var connected = false

    /// HTTP header separator
    private let httpHeaderSeparator = "\r\n\r\n".data(using: .utf8)!

    /// Constructor
    ///
    /// - Parameters:
    ///   - baseUrl: websocket server baser url. Scheme must be `ws`
    ///   - api: websocket api for this session
    ///   - delegate: delegate
    required init?(baseUrl: URL, api: String, delegate: WebSocketSessionDelegate) {
        if let urlComponents = NSURLComponents(
            url: baseUrl.appendingPathComponent(api), resolvingAgainstBaseURL: false),
            urlComponents.scheme == "ws", let host = urlComponents.host {
            connection = StreamSocketConnection(addr: host, port: urlComponents.port?.uint32Value ?? 80)
            connection.write(utf8string: buildConnectHeader(host: host, path: urlComponents.path ?? "/"))
            self.delegate = delegate
            connection.delegate = self
            ULog.d(.wsTag, "Opening WebSocket session to \(baseUrl.appendingPathComponent(api))")
            connection.open()
        } else {
            return nil
        }
    }

    deinit {
        ULog.d(.wsTag, "Closing WebSocket session")
    }

    /// Build the http connection header
    ///
    /// - Parameters:
    ///   - host: host to connect to
    ///   - path: websocket path
    /// - Returns: connection header
    private func buildConnectHeader(host: String, path: String) -> String {
        return """
        GET \(path) HTTP/1.1\r
        Host: \(host)\r
        Upgrade: websocket\r
        Connection: Upgrade\r
        Sec-WebSocket-Version: 13\r
        Sec-WebSocket-Key: \(generateKey())\r
        \r\n
        """
    }

    /// Generate the websocket key
    ///
    /// - Returns: web socket key
    private func generateKey() -> String {
        let bytes = (0..<4).map { _ in arc4random() }
        return Data(bytes: UnsafePointer(bytes), count: bytes.count * MemoryLayout<UInt32>.size).base64EncodedString()
    }

    /// Process received data
    ///
    /// - Parameter data: received data
    private func processInputData(_ data: Data) {
        // collect received data
        inputBuffer += data
        // Process http header if not connect and the whole header has been received
        if !connected, let headerSeparatorPos = inputBuffer.range(of: httpHeaderSeparator),
            let response = String(data: inputBuffer.subdata(in: 0..<headerSeparatorPos.lowerBound), encoding: .utf8) {
            connected = processHttpResponse(response)
            if connected {
                // connected: remove header data from input buffer
                inputBuffer = inputBuffer.subdata(in: headerSeparatorPos.upperBound..<inputBuffer.count)
            } else {
                ULog.w(.wsTag, "WebSocket connection did Fail")
                delegate?.webSocketSessionConnectionDidFail()
            }
        }
        // Already connected, process remaining data as websocket frame
        if connected {
            processWebSocketFrames()
        }
    }

    /// Process all web socket frames from the input buffer
    private func processWebSocketFrames() {
        var frame: Frame?
        repeat {
            frame = Frame(data: inputBuffer)
            if let frame = frame {
                inputBuffer = inputBuffer.subdata(in: frame.len..<inputBuffer.count)
                // only supports complete text frames
                if frame.opCode == .text {
                    delegate?.webSocketSessionDidReceiveMessage(frame.payload)
                }
            }
        } while frame != nil
    }

    /// Process http response
    ///
    /// - Parameter response: received http response
    /// - Returns: true if response is valid
    private func processHttpResponse(_ response: String) -> Bool {
        // only check it's "101 Switching Protocols"
        return response.starts(with: "HTTP/1.1 101")
    }

    /// A Web socket frame
    private struct Frame {
        /// Frane opCode
        enum OpCode: UInt8 {
            case continuation = 0x00
            case text = 0x01
            case binary = 0x02
            case connectionClose = 0x08
            case ping = 0x09
            case pong = 0x0a
        }

        /// frame length
        let len: Int
        /// Frame is complete
        let fin: Bool
        /// frame opCode
        let opCode: OpCode
        /// Frame masking data
        let mask: UInt16?
        /// Frame payload
        let payload: Data

        /// Create a frame from received data
        ///
        /// - Parameter data: received data
        init?(data: Data) {
            var fin: Bool?
            var opCode: OpCode?
            var len: Int?
            var mask: UInt16?
            var headerLen: Int = 2
            if data.count > 2 {
                fin = data[0] & 0x80 != 0
                opCode = OpCode(rawValue: data[0] & 0x0F)
                let maskBit = data[1] & 0x80 != 0
                let lenBase = data[1] & 0x7F
                switch lenBase {
                case 0...125:
                    len = Int(lenBase)
                case 126:
                    if data.count >= 4 {
                        len = data.subdata(in: 2..<4).withUnsafeBytes {(buf: UnsafePointer<UInt16>) -> Int in
                            return Int(buf[0].bigEndian)
                        }
                        headerLen += 2
                    }
                case 127:
                    if data.count >= 10 {
                        len = data.subdata(in: 2..<10).withUnsafeBytes {(buf: UnsafePointer<Int>) -> Int in
                            return Int(bigEndian: Int(buf[0]))
                        }
                        headerLen += 8
                    }
                default: break
                }

                if maskBit {
                    mask = data.subdata(
                        in: headerLen..<headerLen+2).withUnsafeBytes {(buf: UnsafePointer<UInt16>) -> UInt16 in
                            return buf[0]
                    }
                    headerLen += 2
                }
            }
            if let fin = fin, let opCode = opCode, let len = len, data.count >= len + headerLen {
                self.fin = fin
                self.opCode = opCode
                self.len = len + headerLen
                self.mask = mask
                self.payload = data.subdata(in: headerLen..<len+headerLen)
            } else {
                return nil
            }
        }
    }
}

/// Socket connection delegate
extension WebSocketClientSession: StreamSocketConnectionDelegate {
    internal func streamSocketConnectionDidOpen(_ connection: StreamSocketConnection) {
    }

    internal func streamSocketConnectionHasData(_ connection: StreamSocketConnection, data: Data) {
        processInputData(data)
    }

    internal func streamSocketConnectionHasError(_ connection: StreamSocketConnection) {
        ULog.d(.wsTag, "WebSocket streamSocketConnectionHasError")
        delegate?.webSocketSessionConnectionDidFail()
    }

    internal func streamSocketConnectionDidClose(_ connection: StreamSocketConnection) {
        ULog.d(.wsTag, "WebSocket streamSocketConnectionDidClose")
        delegate?.webSocketSessionDidDisconnect()
    }
}
