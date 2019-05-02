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

/// Protocol for creating classes that can act as decoding for a StreamWriter
public protocol StreamDecoder {

    /// Process the Data ("in" stream) et returns the decoded Data
    ///
    /// The class that decodes the data can store the data and defer the returned data.
    ///
    /// A last call to this function will always be done at the end of the stream with `nil` in data.
    /// At this final call (data == nil), all remaining decoded stream must be returned.
    ///
    /// - Parameter data: data to be processed or `nil` to indicate that the stream is complete and that it is the
    /// last call.
    /// - Returns: decoded Data to write, nil if there is no data to write at this moment.
    /// - Throws: Error if failed.
    func decodeStream(_ data: Data?) throws -> Data?
}

/// Errors for the StreamWriter
enum StreamWriterError: Error {
    /// Incorrect filename
    case badFileName
    /// Unable to create the file
    case creatingfile
    /// Unable to open a FileHandler for writing
    case openFile
    /// Unable to write data in the file
    case write
    /// Unable to finalize the file
    case finalize
    /// Decoding Error
    case decoding(Error)
}

extension StreamWriterError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .badFileName:
            return NSLocalizedString("StreamWriterError - badFileName", comment: "Incorrect filename")
        case .creatingfile:
            return NSLocalizedString("StreamWriterError - creatingfile", comment: "Unable to create the file")
        case .openFile:
            return NSLocalizedString(
                "StreamWriterError - openFile", comment: "Unable to open a FileHandler for writing")
        case .write:
            return NSLocalizedString("StreamWriterError - write", comment: "Unable to write data in the file")
        case .finalize:
            return NSLocalizedString("StreamWriterError - finalize", comment: "Unable to finalize the file")
        case .decoding(let error):
            return NSLocalizedString("StreamWriterError - decoding", comment: "\(error.localizedDescription)")
        }
    }
}

/// This Class is used to process stream data (IN) and write the result into a file. This Class used a StreamDecoder
/// object in order to decode the stream.
class StreamWriter {

    /// URL of the file to be created when receiving data. The file will be available at the end of the stream
    /// processing. During the process, a temporary file is used
    public let resultUrl: URL

    /// Custom object in order to decode the stream
    private let streamDecoder: StreamDecoder

    /// URL of the temporary file used during the process
    private var temporaryUrl: URL?

    /// File extension of a temporary file
    private let temporaryExtension = "tmp"

    /// FileHandle for write in the temporary file
    private var fileHandle: FileHandle?

    /// Constructor
    ///
    /// - Parameters:
    ///   - withFileUrl: URL of the file to be created when receiving data
    ///   - streamDecoder: StreamDecoder object to use
    init(withFileUrl: URL, streamDecoder: StreamDecoder) {
        resultUrl = withFileUrl
        self.streamDecoder = streamDecoder
    }

    /// Add data to be processed
    ///
    /// - Parameter data: data to be processed or `nil` to indicate that the stream is complete
    /// - Throws: StreamWriteError
    public func processData(_ data: Data?) throws {
        if fileHandle == nil {
            try openFileHandle()
        }

        // Gives Data to decoder and get data to write
        let outData: Data?
        do {
            try outData = streamDecoder.decodeStream(data)
        } catch {
            throw (StreamWriterError.decoding(error))
        }

        // write data if the decoder returns some data
        if let outData = outData {
            fileHandle?.write(outData)
        }

        // test if it is the end of the stream
        if data == nil {
            fileHandle?.closeFile()
            fileHandle = nil
            let fileManager = FileManager.default
            // delete result file if exists
            if fileManager.fileExists(atPath: resultUrl.path) {
                try? fileManager.removeItem(at: resultUrl)
            }
            // Move the temporary file to the resultFile
            do {
                try FileManager.default.moveItem(at: temporaryUrl!, to: resultUrl)
            } catch {
                throw (StreamWriterError.finalize)
            }
        }
    }

    /// This function open the FileHandle for writing.
    ///
    /// - Note: If the temporary file was existing before, it is first deleted. Then, the temporary file is created and
    /// the the fileHandle is open.
    ///
    /// - Throws: StreamWriterError
    private func openFileHandle() throws {

        guard fileHandle == nil else {
            return
        }
        let fileManager = FileManager.default
        temporaryUrl = resultUrl.deletingPathExtension().appendingPathExtension(temporaryExtension)

        if let tmpPath = temporaryUrl?.path {
            // delete temporary if exists
            if fileManager.fileExists(atPath: tmpPath) {
                do {
                    try fileManager.removeItem(atPath: tmpPath)
                } catch {
                    throw(StreamWriterError.creatingfile)
                }
            }
            // create directory if needed
            do {
                try FileManager.default.createDirectory(
                    at: resultUrl.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)

            } catch {
                throw(StreamWriterError.creatingfile)
            }
            // create file
            if  !fileManager.createFile(atPath: tmpPath, contents: nil, attributes: nil) {
                throw(StreamWriterError.creatingfile)
            }
            // open fileHandle
            if let fileHandle = FileHandle(forWritingAtPath: tmpPath) {
                fileHandle.seekToEndOfFile()
                self.fileHandle = fileHandle
            } else {
                throw(StreamWriterError.openFile)
            }
        }
    }

    /// Deinit - clean any job if any
    deinit {
        if let fileHandle = fileHandle, let tmpPath = temporaryUrl?.path {
            fileHandle.closeFile()
            let fileManager = FileManager.default
            try? fileManager.removeItem(atPath: tmpPath)
        }
    }
}
