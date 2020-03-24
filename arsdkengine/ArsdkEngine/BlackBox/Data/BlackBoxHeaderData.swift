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

/// Black box header data
///
/// Contains information such as the black box version, operating system version, operating device model,
/// black box monotonic timestamps base...
struct BlackBoxHeaderData: Encodable {
    private enum CodingKeys: String, CodingKey {
        case blackBoxVersion = "blackbox_version"
        case osVersion = "device_os"
        case deviceModel = "device_model"
        case date = "date"
        case timestampBase = "timestamp_base"
        case uid = "product_serial"
        case model = "product_id"
        case hardwareVersion = "product_fw_hard"
        case softwareVersion = "product_fw_soft"
        case motorVersion = "product_motor_version"
        case gpsVersion = "product_gps_version"
        case academyId = "academy_id"
        case bootId = "boot_id"
        case remoteControlData = "remote_controller"
    }

    /// Black box version
    let blackBoxVersion = "1.0.6"
    /// OS version
    let osVersion = "iOS \(AppInfoCore.systemVersion)"
    /// Device model
    let deviceModel = AppInfoCore.deviceModel
    /// Formatted date
    let date: String
    /// Timestamp base
    let timestampBase = TimeProvider.timeInterval   // TODO: this field is new, check if it is ok.
    /// Drone's uid
    let uid: String
    /// Drone's model
    let model: String
    /// Drone's hardware version
    var hardwareVersion: String?
    /// Drone's software version
    var softwareVersion: String?
    /// Drone's motor version
    var motorVersion: String?
    /// Drone's gps version
    var gpsVersion: String?
    /// User's academy id
    var academyId: String? // TODO: defined here but needs academy integration.
    /// Drone's boot id
    var bootId: String?
    /// Remote controller information
    var remoteControlData: BlackBoxRemoteControlData?

    /// Constructor
    ///
    /// - Parameter drone: drone that this black box header is recorded for
    init(drone: DroneCore) {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = NSTimeZone.system
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        date = dateFormatter.string(from: Date())

        uid = drone.uid
        model = drone.model.internalId.description
    }
}
