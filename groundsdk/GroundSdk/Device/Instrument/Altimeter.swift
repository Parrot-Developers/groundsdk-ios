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

/// Instrument that informs about altitude and vertical speed.
///
/// This instrument can be retrieved by:
/// ```
/// drone.getInstrument(Instruments.altimeter)
/// ```
public protocol Altimeter: Instrument {

    /// Altitude of the drone relative to take off altitude (in meters).
    /// `nil` if not available. This can happen if the drone does not know or provide this information.
    var takeoffRelativeAltitude: Double? { get }

    /// Altitude of the drone relative to the ground (in meters).
    ///` nil` if not available. This can happen if the drone does not know or provide this information.
    ///
    /// This is the fusion of barometer and ultrasounds.
    /// - Note: May be wrong at high altitude and jump brutally when getting closer to the ground.
    var groundRelativeAltitude: Double? { get }

    /// Absolute altitude of the drone, i.e. relative to sea-level (in meters).
    /// `nil` if not available. This can happen if the drone does not know or provide this information,
    /// or if its gps is not fixed.
    var absoluteAltitude: Double? { get }

    /// Vertical speed of the drone (in meters/second).
    /// `nil` if not available. This can happen if the drone does not know or provide this information.
    ///
    /// Positive when the drone is going up, negative when the drone is going down.
    var verticalSpeed: Double? { get }

}

/// Instrument that informs about altitude.
///
/// This instrument can be retrieved by:
/// ```
/// drone.getInstrument(Instruments.altimeter)
/// ```
/// - Note: This protocol is for Objective-C only. Swift must use the protocol `Altimeter`.
@objc
public protocol GSAltimeter: Instrument {
    /// Gets the altitude of the drone relative to take off altitude (in meters).
    ///
    /// - Returns: the altitude relative to take off point.
    ///            `nil` if not available. This can happen if the drone does not know or provide this information.
    /// - Note: this method is for Objective-C only. Swift must use the property `takeoffRelativeAltitude`.
    func getTakeoffRelativeAltitude() -> NSNumber?

    /// Gets the altitude of the drone relative to the ground (in meters).
    ///
    /// This is the fusion of barometer and ultrasounds,
    /// may be wrong at high altitude and jump brutally when getting closer to the ground.
    ///
    /// - Returns: the altitude of the drone relative to the ground.
    ///            `nil` if not available. This can happen if the drone does not know or provide this information.
    /// - Note: This method is for Objective-C only. Swift must use the property `groundRelativeAltitude`.
    func getGroundRelativeAltitude() -> NSNumber?

    /// Gets the absolute altitude of the drone, i.e. relative to sea-level (in meters).
    ///
    /// - Returns: the altitude relative to sea level
    ///            `nil` if not available. This can happen if the drone does not know or provide this information,
    ///             or if its gps is not fixed.
    /// - Note: This method is for Objective-C only. Swift must use the property `absoluteAltitude`.
    func getAbsoluteAltitude() -> NSNumber?

    /// Gets the vertical speed of the drone (in m/s).
    ///
    /// Positive when the drone is going up, negative when the drone is going down.
    ///
    /// - Returns: the vertical speed of the drone.
    ///            `nil` if not available. This can happen if the drone does not know or provide this information.
    /// - Note: This method is for Objective-C only. Swift must use the property `verticalSpeed`.
    func getVerticalSpeed() -> NSNumber?
}

/// :nodoc:
/// Instrument descriptor
public class AltimeterDesc: NSObject, InstrumentClassDesc {
    public typealias ApiProtocol = Altimeter
    public let uid = InstrumentUid.altimeter.rawValue
    public let parent: ComponentDescriptor? = nil
}
