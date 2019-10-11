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

/// Black box data
struct BlackBoxData: Encodable {

    enum CodingKeys: String, CodingKey {
        case header = "header"
        case events = "datas"
        case flightDatas = "datas_5Hz"
        case environmentDatas = "datas_1Hz"
    }

    /// Black box header
    private var header: BlackBoxHeaderData

    /// List of events
    private var events: [BlackBoxEvent] = []

    /// Flight data sample buffer (limited to the last 1 minute datas)
    private var flightDatas = BlackBoxCircularArray<BlackBoxFlightData>(size: 5 * 60)

    /// Environment data sample buffer (limited to the last 1 minute datas)
    private var environmentDatas = BlackBoxCircularArray<BlackBoxEnvironmentData>(size: 60)

    /// Constructor
    ///
    /// - Parameter drone: drone that this black box is recorded for
    init(drone: DroneCore) {
        header = BlackBoxHeaderData(drone: drone)
    }

    /// Records an event in the blackbox
    ///
    /// - Parameter event: event to record
    mutating func add(event: BlackBoxEvent) {
        events.append(event)
    }

    /// Records a new flight data
    ///
    /// - Parameter flightData: the flight data sample to record
    mutating func add(flightData: BlackBoxFlightData) {
        flightDatas.append(flightData)
    }

    /// Records a new environment data
    ///
    /// - Parameter environmentData: the environment data sample to record
    mutating func add(environmentData: BlackBoxEnvironmentData) {
        environmentDatas.append(environmentData)
    }

    /// Records the remote control data
    ///
    /// - Parameter remoteControlData: the remote control data to record
    mutating func set(remoteControlData: BlackBoxRemoteControlData) {
        header.remoteControlData = remoteControlData
    }

    /// Records the gps software version
    ///
    /// - Parameter gpsSoftwareVersion: the gps software version to record
    mutating func set(gpsSoftwareVersion: String) {
        header.gpsVersion = gpsSoftwareVersion
    }

    /// Records the motor software version
    ///
    /// - Parameter motorSoftwareVersion: the motor software version to record
    mutating func set(motorSoftwareVersion: String) {
        header.motorVersion = motorSoftwareVersion
    }

    /// Records the drone's version
    ///
    /// - Parameters:
    ///   - software: the drone's software version
    ///   - hardware: the drone's hardware version
    mutating func setProductVersion(software: String, hardware: String) {
        header.softwareVersion = software
        header.hardwareVersion = hardware
    }

    /// Records the boot id
    ///
    /// - Parameter bootId: the boot id to record
    mutating func set(bootId: String) {
        header.bootId = bootId
    }
}
