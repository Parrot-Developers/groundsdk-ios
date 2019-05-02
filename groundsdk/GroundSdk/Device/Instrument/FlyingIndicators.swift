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

/// Flying indicator state.
@objc(GSFlyingIndicatorsState)
public enum FlyingIndicatorsState: Int, CustomStringConvertible {
    /// Drone can be in initialization state or it can be waiting for a command or a user action to takeoff.
    /// See `landedState` for more details.
    case landed
    /// Drone is flying.
    /// See `flyingState` for more details.
    case flying
    /// Autopilot has detected defective sensor(s). An emergency landing was triggered.
    case emergencyLanding
    /// Drone stopped due to an emergency.
    case emergency

    /// Debug description.
    public var description: String {
        switch self {
        case .landed:           return "landed"
        case .flying:           return "flying"
        case .emergencyLanding: return "emergencyLanding"
        case .emergency:        return "emergency"
        }
    }
}

/// Landed state when the main state is `landed`.
@objc(GSFlyingIndicatorsLandedState)
public enum FlyingIndicatorsLandedState: Int, CustomStringConvertible {
    /// Flying indicator state is not `landed`.
    case none
    /// Drone is initializing and not ready to takeoff, for instance because it's waiting for some peripheral
    /// calibration. Drone motors are not running.
    case initializing
    /// Drone is ready to initialize a take-off, by requesting either:
    /// - a take-off for a copter,
    /// - a thrown take-off for a copter,
    /// - a take-off arming for a fixed wings drone.
    case idle
    /// Motors are ramping.
    case motorRamping
    /// Drone is waiting for a user action to takeoff.
    /// It's waiting to be thrown and Drone motors are running.
    case waitingUserAction

    /// Debug description.
    public var description: String {
        switch self {
        case .none:                 return "none"
        case .initializing:         return "initializing"
        case .idle:                 return "idle"
        case .motorRamping:         return "motorRamping"
        case .waitingUserAction:    return "waitingUserAction"
        }
    }
}

/// Flying state when the main state is `flying`.
@objc(GSFlyingIndicatorsFlyingState)
public enum FlyingIndicatorsFlyingState: Int, CustomStringConvertible {
    /// Flying indicator state is not `flying`.
    case none
    /// Drone is taking off.
    case takingOff
    /// Drone is landing.
    case landing
    /// Drone is waiting for piloting orders. Drone is waiting at its current position.
    case waiting
    /// Drone has piloting orders and is flying.
    case flying

    /// Debug description.
    public var description: String {
        switch self {
        case .none:         return "none"
        case .takingOff:    return "takingOff"
        case .landing:      return "landing"
        case .waiting:      return "waiting"
        case .flying:       return "flying"
        }
    }
}

/// Flying indicators instrument. This instrument indicate the current flying state.
///
/// This instrument can be retrieved by:
/// ```
/// drone.getInstrument(Instruments.flyingIndicators)
/// ```
@objc(GSFlyingIndicators)
public protocol FlyingIndicators: Instrument {
    /// Current state.
    var state: FlyingIndicatorsState { get }

    /// Landed detail state, when state is `.landed`.
    var landedState: FlyingIndicatorsLandedState { get }

    /// Flying detail state, when state is `.flying`.
    var flyingState: FlyingIndicatorsFlyingState { get }
}

/// :nodoc:
/// Instrument descriptor
@objc(GSFlyingIndicatorsDesc)
public class FlyingIndicatorsDesc: NSObject, InstrumentClassDesc {
    public typealias ApiProtocol = FlyingIndicators
    public let uid = InstrumentUid.flyingIndicators.rawValue
    public let parent: ComponentDescriptor? = nil
}
