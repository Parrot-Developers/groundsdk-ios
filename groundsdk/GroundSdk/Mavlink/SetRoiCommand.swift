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

/// MAVLink command which allows to set a Region Of Interest.
public final class SetRoiCommand: MavlinkCommand {

    /// Value always used for region of interest mode; set to MAV_ROI_LOCATION.
    private static let roiMode = 3.0

    /// Latitude of the region of interest, in degrees.
    public let latitude: Double

    /// Longitude of the region of interest, in degrees.
    public let longitude: Double

    /// Altitude of the region of interest above take off point, in meters.
    public let altitude: Double

    /// Constructor.
    ///
    /// - Parameters:
    ///   - latitude: latitude of the region of interest, in degrees
    ///   - longitude: longitude of the region of interest, in degrees
    ///   - altitude: altitude of the region of interest above take off point, in meters
    public init(latitude: Double, longitude: Double, altitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        super.init(type: .setRoi)
    }

    /// Constructor from generic MAVLink parameters.
    ///
    /// - Parameter parameters: generic command parameters
    convenience init?(parameters: [Double?]) {
        if let latitude = parameters[4], let longitude = parameters[5], let altitude = parameters[6] {
            self.init(latitude: latitude, longitude: longitude, altitude: altitude)
        } else {
            return nil
        }
    }

    override func write(fileHandle: FileHandle, index: Int) {
        doWrite(fileHandle: fileHandle, index: index, param1: SetRoiCommand.roiMode, latitude: latitude,
                longitude: longitude, altitude: altitude)
    }
}
