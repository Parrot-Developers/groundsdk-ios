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

/// Black box environment data sample.
///
/// Contains information such as the current drone location, controller location, wifi signal level...
struct BlackBoxEnvironmentData: Encodable {

    private enum CodingKeys: String, CodingKey {
        case timestamp
        case droneLocation = "product_gps"
        case controllerLocation = "device_gps"
        case rcPcmd = "mpp_pcmd"
        case rssi = "wifi_rssi"
        case batteryVoltage = "product_battery_voltage"
    }

    /// Whether the data has been modified since the last `useIfChanged` call
    private(set) var hasChanged = false
    /// Latest data timestamp. Data is timestamped right before being used with `useIfChanged`.
    private(set) var timestamp = 0.0
    /// Wifi signal level
    var rssi = 0 {
        didSet {
            if oldValue != rssi {
                hasChanged = true
            }
        }
    }

    /// Drone location
    var droneLocation = BlackBoxLocationData() {
        didSet {
            if oldValue != droneLocation {
                hasChanged = true
            }
        }
    }

    /// Controller location
    var controllerLocation = BlackBoxLocationData() {
        didSet {
            if oldValue != controllerLocation {
                hasChanged = true
            }
        }
    }

    /// Piloting command given by the remote control
    var rcPcmd = BlackBoxRcPilotingCommandData() {
        didSet {
            if oldValue != rcPcmd {
                hasChanged = true
            }
        }
    }

    /// Battery voltage
    var batteryVoltage = 0 {
        didSet {
            if oldValue != batteryVoltage {
                hasChanged = true
            }
        }
    }

    /// Get a timestamped flight data if this object has changed since the last `useIfChanged` call.
    ///
    /// - Returns: this object timestamped if it has changed, nil otherwise
    mutating func useIfChanged() -> BlackBoxEnvironmentData? {
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

/// Piloting command sent to the drone with a remote control
struct BlackBoxRcPilotingCommandData: Encodable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case roll
        case pitch
        case yaw
        case gaz
        case source
    }

    /// Roll value of the piloting command
    var roll = 0
    /// Pitch value of the piloting command
    var pitch = 0
    /// Yaw value of the piloting command
    var yaw = 0
    /// Gaz value of the piloting command
    var gaz = 0
    /// Source of the piloting command
    var source = 0

    static func == (lhs: BlackBoxRcPilotingCommandData, rhs: BlackBoxRcPilotingCommandData) -> Bool {
        return lhs.roll == rhs.roll && lhs.pitch == rhs.pitch && lhs.yaw == rhs.yaw && lhs.gaz == rhs.gaz &&
            lhs.source == rhs.source
    }
}
