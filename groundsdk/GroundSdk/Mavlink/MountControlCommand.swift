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

/// MAVLink command which allows to control the camera tilt.
public final class MountControlCommand: MavlinkCommand {

    /// Value always used for mount mode; set to MAV_MOUNT_MODE_MAVLINK_TARGETING.
    private static let mode = 2.0

    /// Camera tilt angle, in degrees.
    public let tiltAngle: Double

    /// Constructor.
    ///
    /// - Parameter tiltAngle: tilt angle value, in degrees
    public init(tiltAngle: Double) {
        self.tiltAngle = tiltAngle
        super.init(type: .mountControl)
    }

    /// Constructor from generic MAVLink parameters.
    ///
    /// - Parameter parameters: generic command parameters
    convenience init?(parameters: [Double?]) {
        if let tiltAngle = parameters[0] {
            self.init(tiltAngle: tiltAngle)
        } else {
            return nil
        }
    }

    override func write(fileHandle: FileHandle, index: Int) {
        doWrite(fileHandle: fileHandle, index: index, param1: tiltAngle, altitude: MountControlCommand.mode)
    }
}
