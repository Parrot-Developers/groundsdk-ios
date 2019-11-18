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

/// A Point Of Interest to look at.
@objc(GSPointOfInterest)
public protocol PointOfInterest {
    /// Latitude of the location (in degrees) to look at.
    var latitude: Double { get }

    /// Longitude of the location (in degrees) to look at.
    var longitude: Double { get }

    /// Altitude above take off point (in meters) to look at.
    var altitude: Double { get }

    /// Point Of Interest operating mode.
    var mode: PointOfInterestMode { get }
}

/// Point Of Interest operating mode.
@objc(GSPointOfInterestMode)
public enum PointOfInterestMode: Int, CustomStringConvertible {
    /// Gimbal is locked on the Point Of Interest.
    case lockedGimbal

    /// Gimbal is freely controllable.
    case freeGimbal

    /// Debug description.
    public var description: String {
        switch self {
        case .lockedGimbal:     return "lockedGimbal"
        case .freeGimbal:       return "freeGimbal"
        }
    }
}

/// Point Of Interest piloting interface.
///
/// During a piloted Point Of Interest, the drone always points towards the given Point Of Interest but can be piloted
/// normally. However, yaw value is not settable.
///
/// There are two variants of piloted Point Of Interest:
///   - In `.lockedGimbal` mode, the gimbal always looks at the Point Of Interest. Gimbal control command is ignored by
///     the drone.
///   - In `.freeGimbal` mode, the gimbal initially looks at the Point Of Interest, and is then freely controllable by
///     the gimbal command.
///
/// This piloting interface can be retrieved by:
/// ```
/// drone.getPilotingItf(PilotingItfs.poi)
/// ```
@objc(GSPointOfInterestPilotingItf)
public protocol PointOfInterestPilotingItf: PilotingItf, ActivablePilotingItf {

    /// Current targeted Point Of Interest. `nil` if there's no piloted Point Of Interest in progress.
    var currentPointOfInterest: PointOfInterest? { get }

    /// Starts a piloted Point Of Interest in locked gimbal mode.
    ///
    /// This is equivalent to calling:
    /// ```
    /// start(latitude, longitude, altitude, .lockedGimbal)
    /// ```
    ///
    /// - Parameters:
    ///   - latitude: latitude of the location (in degrees) to look at
    ///   - longitude: longitude of the location (in degrees) to look at
    ///   - altitude: altitude above take off point (in meters) to look at
    func start(latitude: Double, longitude: Double, altitude: Double)

    /// Starts a piloted Point Of Interest.
    ///
    /// - Parameters:
    ///   - latitude: latitude of the location (in degrees) to look at
    ///   - longitude: longitude of the location (in degrees) to look at
    ///   - altitude: altitude above take off point (in meters) to look at
    ///   - mode: point of interest mode
    func start(latitude: Double, longitude: Double, altitude: Double, mode: PointOfInterestMode)

    /// Sets the current pitch value.
    ///
    /// Expressed as a signed percentage of the max pitch/roll setting (`maxPitchRoll`), in range [-100, 100].
    /// * -100 corresponds to a pitch angle of max pitch/roll towards ground (copter will fly forward)
    /// * 100 corresponds to a pitch angle of max pitch/roll towards sky (copter will fly backward)
    ///
    /// - Note: This value may be clamped if necessary, in order to respect the maximum supported physical tilt of
    /// the copter.
    ///
    /// - Parameter pitch: the new pitch value to set
    @objc(setPitch:)
    func set(pitch: Int)

    /// Sets the current roll value.
    ///
    /// Expressed as a signed percentage of the max pitch/roll setting (`maxPitchRoll`), in range [-100, 100].
    /// * -100 corresponds to a roll angle of max pitch/roll to the left (copter will fly left)
    /// * 100 corresponds to a roll angle of max pitch/roll to the right (copter will fly right)
    ///
    /// - Note: This value may be clamped if necessary, in order to respect the maximum supported physical tilt of
    /// the copter.
    ///
    /// - Parameter roll: the new roll value to set
    @objc(setRoll:)
    func set(roll: Int)

    /// Sets the current vertical speed value.
    ///
    /// Expressed as a signed percentage of the max vertical speed setting (`maxVerticalSpeed`), in range [-100, 100].
    /// * -100 corresponds to max vertical speed towards ground
    /// * 100 corresponds to max vertical speed towards sky
    ///
    /// - Parameter verticalSpeed: the new vertical speed value to set
    @objc(setVerticalSpeed:)
    func set(verticalSpeed: Int)
}

/// :nodoc:
/// Point Of Interest piloting interface description
@objc(GSPointOfInterestPilotingItfs)
public class PointOfInterestPilotingItfs: NSObject, PilotingItfClassDesc {
    public typealias ApiProtocol = PointOfInterestPilotingItf
    public let uid = PilotingItfUid.pointOfInterest.rawValue
    public let parent: ComponentDescriptor? = nil
}
