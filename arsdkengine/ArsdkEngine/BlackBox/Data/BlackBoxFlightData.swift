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

/// Black box flight data sample.
///
/// Contains information about the flight such as speed, altitude, attitude received and piloting command sent
struct BlackBoxFlightData: Encodable {

    private enum CodingKeys: String, CodingKey {
        case timestamp
        case altitude = "product_alt"
        case heightAboveGround = "product_height_above_ground"
        case speed = "product_speed"
        case attitude = "product_angles"
        case pcmd = "device_pcmd"
    }

    /// Whether the data has been modified since the last `useIfChanged` call
    private(set) var hasChanged = false
    /// Latest data timestamp. Data is timestamped right before being used with `useIfChanged`.
    private(set) var timestamp = 0.0
    /// Altitude of the drone in meters above takeoff point
    var altitude = 0.0 {
        didSet {
            if oldValue != altitude {
                hasChanged = true
            }
        }
    }

    /// Height of the drone in meters above ground level
    var heightAboveGround = Float(0) {
        didSet {
            if oldValue != heightAboveGround {
                hasChanged = true
            }
        }
    }

    /// Speed of the drone
    var speed = BlackBoxSpeedData() {
        didSet {
            if oldValue != speed {
                hasChanged = true
            }
        }
    }

    /// Attitude of the drone
    var attitude = BlackBoxAttitudeData() {
        didSet {
            if oldValue != attitude {
                hasChanged = true
            }
        }
    }

    /// Piloting command sent to the drone
    var pcmd = BlackBoxDronePilotingCommandData() {
        didSet {
            if oldValue != pcmd {
                hasChanged = true
            }
        }
    }

    /// Get a timestamped flight data if this object has changed since the last `useIfChanged` call.
    ///
    /// - Returns: this object timestamped if it has changed, nil otherwise
    mutating func useIfChanged() -> BlackBoxFlightData? {
        if hasChanged {
            // Note: this changes from Android implementation where data is timestamped during the set of each value,
            // here, we timestamp the data right before using it.
            timestamp = TimeProvider.timeInterval
            hasChanged = false
            return self
        }
        return nil
    }
}

/// Speed information about the drone
struct BlackBoxSpeedData: Encodable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case speedX = "vx"
        case speedY = "vy"
        case speedZ = "vz"
    }

    /// Drone speed on the X axis in m/s
    var speedX = Float(0)
    /// Drone speed on the Y axis in m/s
    var speedY = Float(0)
    /// Drone speed on the Z axis in m/s
    var speedZ = Float(0)

    static func == (lhs: BlackBoxSpeedData, rhs: BlackBoxSpeedData) -> Bool {
        return lhs.speedX == rhs.speedX && lhs.speedY == rhs.speedY && lhs.speedZ == rhs.speedZ
    }
}

/// Attitude information about the drone
struct BlackBoxAttitudeData: Encodable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case roll
        case pitch
        case yaw
    }

    /// Drone roll angle in radian
    var roll = Float(0)
    /// Drone pitch angle in radian
    var pitch = Float(0)
    /// Drone yaw angle in radian
    var yaw = Float(0)

    static func == (lhs: BlackBoxAttitudeData, rhs: BlackBoxAttitudeData) -> Bool {
        return lhs.roll == rhs.roll && lhs.pitch == rhs.pitch && lhs.yaw == rhs.yaw
    }
}

/// Piloting command sent to the drone
struct BlackBoxDronePilotingCommandData: Encodable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case roll
        case pitch
        case yaw
        case gaz
        case flag
    }

    /// Roll value of the piloting command
    var roll = 0
    /// Pitch value of the piloting command
    var pitch = 0
    /// Yaw value of the piloting command
    var yaw = 0
    /// Gaz value of the piloting command
    var gaz = 0
    /// Flag value of the piloting command
    var flag = 0

    static func == (lhs: BlackBoxDronePilotingCommandData, rhs: BlackBoxDronePilotingCommandData) -> Bool {
        return lhs.roll == rhs.roll && lhs.pitch == rhs.pitch && lhs.yaw == rhs.yaw && lhs.gaz == rhs.gaz &&
            lhs.flag == rhs.flag
    }
}
