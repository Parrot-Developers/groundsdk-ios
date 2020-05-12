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

/// MAVLink command which allows to start photo capture.
public final class StartPhotoCaptureCommand: MavlinkCommand {

    /// Photo format.
    public enum Format: Int, CustomStringConvertible {
        /// Rectilinear projection (de-wrapped), JPEG format.
        case rectilinear = 12
        /// Full sensor resolution (not de-wrapped), JPEG format.
        case fullFrame = 13
        /// Full sensor resolution (not de-wrapped), JPEG and DNG format.
        case fullFrameDng = 14

        /// Debug description.
        public var description: String {
            switch self {
            case .rectilinear:  return "rectilinear"
            case .fullFrame:    return "fullFrame"
            case .fullFrameDng: return "fullFrameDng"
            }
        }
    }

    /// Elapsed time between two consecutive pictures, in seconds.
    ///
    /// If interval is 0, the value defined with `SetStillCaptureModeCommand` is used instead, else the value returned
    /// here is used and capture mode is set to `.timelapse`.
    public let interval: Double

    /// Total number of photos to capture.
    public let count: Int

    /// Photo capture format.
    public let format: Format

    /// Constructor.
    ///
    /// - Parameters:
    ///   - interval: desired elapsed time between two consecutive pictures, in seconds; if interval is 0, the value
    ///               defined with `SetStillCaptureModeCommand` is used instead, else the value given here is used and
    ///               capture mode is set to `.timelapse`
    ///   - count: total number of photos to capture; 0 to capture until `StopPhotoCaptureCommand` is sent
    ///   - format: capture format
    public init(interval: Double, count: Int, format: Format) {
        self.interval = interval
        self.count = count
        self.format = format
        super.init(type: .startPhotoCapture)
    }

    /// Constructor from generic MAVLink parameters.
    ///
    /// - Parameter parameters: generic command parameters
    convenience init?(parameters: [Double?]) {
        if let interval = parameters[0], let count = parameters[1], let rawFormat = parameters[2],
            let format = Format(rawValue: Int(rawFormat)) {
            self.init(interval: interval, count: Int(count), format: format)
        } else {
            return nil
        }
    }

    override func write(fileHandle: FileHandle, index: Int) {
        doWrite(fileHandle: fileHandle, index: index, param1: interval, param2: Double(count),
                param3: Double(format.rawValue))
    }
}
