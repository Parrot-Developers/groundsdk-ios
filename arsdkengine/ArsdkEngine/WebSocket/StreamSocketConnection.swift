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

protocol StreamSocketConnectionDelegate: class {
    func streamSocketConnectionDidOpen(_ connection: StreamSocketConnection)
    func streamSocketConnectionHasData(_ connection: StreamSocketConnection, data: Data)
    func streamSocketConnectionHasError(_ connection: StreamSocketConnection)
    func streamSocketConnectionDidClose(_ connection: StreamSocketConnection)
}

/// Socket connection
class StreamSocketConnection: NSObject {
    /// Delegate
    weak var delegate: StreamSocketConnectionDelegate?
    /// Input stream
    private let inputStream: InputStream
    /// Output stream
    private let outputStream: OutputStream
    /// Data to write
    private var writeQueue = [Data]()
    /// Buffer for received data
    private var inputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: StreamSocketConnection.inputBufferSize)
    /// Input buffer size
    private static let inputBufferSize = 1024

    /// Constructor
    ///
    /// - Parameters:
    ///   - addr: server address
    ///   - port: server port
    init(addr: String, port: UInt32) {
        // create socker pair
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        CFStreamCreatePairWithSocketToHost(nil, addr as CFString, port, &readStream, &writeStream)
        inputStream = readStream!.takeRetainedValue()
        outputStream = writeStream!.takeRetainedValue()
        super.init()
        inputStream.delegate = self
        outputStream.delegate = self
        inputStream.schedule(in: RunLoop.current, forMode: RunLoop.Mode.default)
        outputStream.schedule(in: RunLoop.current, forMode: RunLoop.Mode.default)
    }

    /// Deinitializer
    deinit {
        inputStream.close()
        outputStream.close()
        inputBuffer.deallocate()
    }

    /// Write data to the output stream
    ///
    /// - Parameter data: data to write
    func write(data: Data) {
        queueNextBuffer(data: data)
    }

    /// Open connection
    func open() {
        inputStream.open()
        outputStream.open()
    }

    /// Write a string to the output stream
    ///
    /// - Parameter utf8string: string to write
    func write(utf8string: String) {
        if let data = utf8string.data(using: .utf8) {
            write(data: data)
        }
    }

    /// Queue next buffer to write and start writing if possible
    ///
    /// - Parameter data: data to write
    private func queueNextBuffer(data: Data) {
        writeQueue.append(data)
        writeNextBuffers()
    }

    /// Write all pending buffers or until output is full
    private func writeNextBuffers() {
        while let data = writeQueue.first, outputStream.hasSpaceAvailable {
            let written = data.withUnsafeBytes { bytes in
                return outputStream.write(bytes, maxLength: data.count)
            }
            if written < 0 {
                return
            } else if written < data.count {
                writeQueue[0] = data.advanced(by: written)
            } else {
                writeQueue.removeFirst()
            }
        }
    }
}

/// StreamDelegate
extension StreamSocketConnection: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        if eventCode.contains(.openCompleted) {
            if inputStream.streamStatus == .open && outputStream.streamStatus == .open {
                // Notify opened
                delegate?.streamSocketConnectionDidOpen(self)
            }
        }
        if eventCode.contains(.hasBytesAvailable) {
            let len = inputStream.read(inputBuffer, maxLength: StreamSocketConnection.inputBufferSize)
            if len > 0 {
                var result = Data()
                result.append(inputBuffer, count: len)
                delegate?.streamSocketConnectionHasData(self, data: result)
            }
        }
        if eventCode.contains(.hasSpaceAvailable) {
            writeNextBuffers()
        }
        if eventCode.contains(.errorOccurred) {
            delegate?.streamSocketConnectionHasError(self)
        }
        if eventCode.contains(.endEncountered) {
            delegate?.streamSocketConnectionDidClose(self)
        }
    }
}
