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

/// MAVLink command which allows to set the still capture mode.
public final class SetStillCaptureModeCommand: MavlinkCommand {

    /// Still capture mode.
    public enum Mode: Int, CustomStringConvertible {
        /// Time-lapse mode (photos taken at regular time intervals).
        case timelapse = 0
        /// GPS-lapse mode (photos taken at regular GPS position intervals).
        case gpslapse = 1

        /// Debug description.
        public var description: String {
            switch self {
            case .timelapse: return "timelapse"
            case .gpslapse:  return "gpslapse"
            }
        }
    }

    /// Still capture mode.
    public let mode: Mode

    /// Time-lapse interval in seconds (if mode is `.timelapse`), or GPS-lapse interval in meters (if mode is
    /// `.gpslapse`).
    public let interval: Double

    /// Constructor.
    ///
    /// - Parameters:
    ///   - mode: still capture mode
    ///   - interval: time-lapse interval in seconds (if mode is `.timelapse`), or GPS-lapse interval in meters (if mode
    ///               is `.gpslapse`)
    public init(mode: Mode, interval: Double) {
        self.mode = mode
        self.interval = interval
        super.init(type: .setStillCaptureMode)
    }

    /// Constructor from generic MAVLink parameters.
    ///
    /// - Parameter parameters: generic command parameters
    convenience init?(parameters: [Double?]) {
        if let rawMode = parameters[0], let mode = Mode(rawValue: Int(rawMode)),
            let interval = parameters[1] {
            self.init(mode: mode, interval: interval)
        } else {
            return nil
        }
    }

    override func write(fileHandle: FileHandle, index: Int) {
        doWrite(fileHandle: fileHandle, index: index, param1: Double(mode.rawValue), param2: interval)
    }
}
