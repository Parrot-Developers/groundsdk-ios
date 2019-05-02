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

/// Instrument that informs about speeds.
///
/// This instrument can be retrieved by:
/// ```
/// drone.getInstrument(Instruments.speedometer)
/// ```
public protocol Speedometer: Instrument {

    /// Overall speed on the horizontal plan relative to the ground, in meters/second.
    var groundSpeed: Double { get }

    /// Drone current speed along the north axis, relative to the ground, in meters/second.
    ///
    /// A negative value means that the drone moves to the South.
    var northSpeed: Double { get }

    /// Drone current speed along the east axis, relative to the ground, in meters/second.
    ///
    /// A negative value means that the drone moves to the West.
    var eastSpeed: Double { get }

    /// Drone current speed along the down axis, relative to the ground, in meters/second.
    ///
    /// A negative value means that the drone moves upward.
    var downSpeed: Double { get }

    /// Drone current speed along its front axis on the horizontal plane, relative to the ground, in meters/second.
    ///
    /// A negative value means that the drone moves backward.
    var forwardSpeed: Double { get }

    /// Drone current speed along its right axis on the horizontal plane, relative to the ground, in meters/second.
    ///
    /// A negative value means that the drone moves to the left.
    var rightSpeed: Double { get }
}

/// Instrument that informs about speeds.
///
/// This instrument can be retrieved by:
/// ```
/// drone.getInstrument(Instruments.speedometer)
/// ```
/// - Note: This protocol is for Objective-C only. Swift must use the protocol `Speedometer`.
@objc
public protocol GSSpeedometer: Instrument {
    /// Gets the overall speed on the horizontal plan relative to the ground, in meters/second.
    ///
    /// - Returns: the speed on the horizontal plan relative to the ground
    /// - Note: this method is for Objective-C only. Swift must use the property `groundSpeed`.
    func getGroundSpeed() -> Double
}

/// :nodoc:
/// Instrument descriptor
public class SpeedometerDesc: NSObject, InstrumentClassDesc {
    public typealias ApiProtocol = Speedometer
    public let uid = InstrumentUid.speedometer.rawValue
    public let parent: ComponentDescriptor? = nil
}
