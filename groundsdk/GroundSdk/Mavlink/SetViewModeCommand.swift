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

/// MAVLink command which allows to set the view mode.
public final class SetViewModeCommand: MavlinkCommand {

    /// View mode.
    public enum Mode: Int, CustomStringConvertible {
        /// Drone orientation is fixed between two waypoints. Orientation changes when the waypoint is reached.
        case absolute
        /// Drone orientation changes linearly between two waypoints.
        case `continue`
        /// Drone orientation is given by a Region Of Interest.
        case roi

        /// Debug description.
        public var description: String {
            switch self {
            case .absolute: return "absolute"
            case .continue: return "continue"
            case .roi:      return "roi"
            }
        }
    }

    /// View mode.
    public let mode: Mode

    /// Index of the Region Of Interest.
    ///
    /// Value is meaningless if `mode` is not `.roi`.
    public let roiIndex: Int

    /// Constructor.
    ///
    /// - Parameters:
    ///   - mode: view mode
    ///   - roiIndex: index of the Region Of Interest if mode is `.roi` (if index is invalid, `.absolute` mode is used
    ///               instead); value is ignored for any other mode
    public init(mode: Mode, roiIndex: Int = 0) {
        self.mode = mode
        self.roiIndex = roiIndex
        super.init(type: .setViewMode)
    }

    /// Constructor from generic MAVLink parameters.
    ///
    /// - Parameter parameters: generic command parameters
    convenience init?(parameters: [Double?]) {
        if let rawMode = parameters[0], let mode = Mode(rawValue: Int(rawMode)), let roiIndex = parameters[1] {
            self.init(mode: mode, roiIndex: Int(roiIndex))
        } else {
            return nil
        }
    }

    override func write(fileHandle: FileHandle, index: Int) {
        doWrite(fileHandle: fileHandle, index: index, param1: Double(mode.rawValue), param2: Double(roiIndex))
    }
}
