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

/// Alarm with a level.
@objcMembers
@objc(GSAlarm)
public class Alarm: NSObject {

    /// Kind of alarm.
    @objc(GSAlarmKind)
    public enum Kind: Int, CustomStringConvertible {
        /// The drone power is low.
        case power

        /// Motors have been cut out.
        case motorCutOut

        /// Emergency due to user's request.
        case userEmergency

        /// Motor error.
        case motorError

        /// Battery is too hot.
        case batteryTooHot

        /// Battery is too cold.
        case batteryTooCold

        /// Hovering is difficult due to a lack of GPS positioning and not enough light to use its vertical camera.
        case hoveringDifficultiesNoGpsTooDark

        /// Hovering is difficult due to a lack of GPS positioning and drone is too high to use its vertical camera.
        case hoveringDifficultiesNoGpsTooHigh

        /// Drone will soon forcefully and automatically land because some battery issue (e.g. low power, low or high
        /// temperature...) does not allow to continue flying safely.
        ///
        /// When at level
        ///   - `.off`: battery is OK and no automatic landing is scheduled;
        ///   - `.warning`: some battery issues have been detected, which will soon prevent the drone
        ///     from flying safely. Automatic landing is scheduled;
        ///   - `.critical`: battery issues are now so critical that the drone cannot continue flying
        ///     safely. Automatic landing is about to start in a matter of seconds
        ///
        /// Remaining delay before automatic landing begins (when scheduled both at `.warning` and `.critical` levels),
        /// is accessible through the property `automaticLandingDelay` and the instrument is updated each time
        /// this value changes.
        case automaticLandingBatteryIssue

        /// Wind strength alters the drone ability to fly properly.
        ///
        ///   - `.off`: wind is not strong enough to have significant impact on drone flight.
        ///   - `.warning`: wind is strong enough to alter the drone ability to fly properly.
        ///   - `.critical`: wind is so strong that the drone is completely unable to fly.
        case wind

        /// Vertical camera sensor alters the drone ability to fly safely.
        ///
        ///   - `.off`: No problem detected for the vertical camera
        ///   - `.critical`: Problems with the vertical camera resulted in a deterioration of flight stabilization.
        /// Flying is not recommended.
        case verticalCamera

        /// Vibrations alters the drone ability to fly properly.
        ///
        ///   - `.off`: detected vibration level is normal and has no impact on drone flight.
        ///   - `.warning`: detected vibration level is strong enough to alter the drone ability to fly
        ///     properly, potentially because propellers are not tightly screwed.
        ///   - `.critical`: detected vibration level is so strong that the drone is completely unable to
        ///     fly properly, indicating a serious drone malfunction.
        case strongVibrations

        /// A magnetic element disturbs the drone's magnetometer and alters the drone ability to fly safely.
        case magnetometerPertubation

        /// The local terrestrial magnetic field is too weak to allow to fly safely.
        case magnetometerLowEarthField

        /// Location information sent by the controller is unreliable.
        case unreliableControllerLocation

        /// Debug description.
        public var description: String {
            switch self {
            case .power:                            return "power"
            case .motorCutOut:                      return "motorCutOut"
            case .userEmergency:                    return "userEmergency"
            case .motorError:                       return "motorError"
            case .batteryTooHot:                    return "batteryTooHot"
            case .batteryTooCold:                   return "batteryTooCold"
            case .hoveringDifficultiesNoGpsTooDark: return "hoveringDifficultiesNoGpsTooDark"
            case .hoveringDifficultiesNoGpsTooHigh: return "hoveringDifficultiesNoGpsTooHigh"
            case .automaticLandingBatteryIssue:     return "automaticLandingBatteryIssue"
            case .wind:                             return "wind"
            case .verticalCamera:                   return "verticalCamera"
            case .strongVibrations:                 return "strongVibrations"
            case .magnetometerPertubation:          return "magnetometerPertubation"
            case .magnetometerLowEarthField:        return "magnetometerLowEarthField"
            case .unreliableControllerLocation:     return "unreliableControllerLocation"
            }
        }

        /// Set containing all possible kind of alarm.
        public static let allCases: Set<Kind> = [.power, .motorCutOut, .userEmergency, .motorError, .batteryTooHot,
                                                 .batteryTooCold, .hoveringDifficultiesNoGpsTooDark,
                                                 .hoveringDifficultiesNoGpsTooHigh,
                                                 .automaticLandingBatteryIssue, .wind,
                                                 .verticalCamera, .strongVibrations, .magnetometerPertubation,
                                                 .magnetometerLowEarthField, .unreliableControllerLocation]
    }

    /// Alarm level.
    @objc(GSAlarmLevel)
    public enum Level: Int, CustomStringConvertible {
        /// Alarm not available.
        /// Used when the linked alarm type is not supported by the drone.
        case notAvailable

        /// Alarm is off.
        case off

        /// Alarm is at warning level.
        case warning

        /// Alarm is at critical level.
        case critical

        /// Debug description.
        public var description: String {
            switch self {
            case .notAvailable: return "notAvailable"
            case .off:          return "off"
            case .warning:      return "warning"
            case .critical:     return "critical"
            }
        }
    }

    /// Kind of the alarm.
    public let kind: Kind

    /// Level of the alarm.
    public internal(set) var level: Level

    /// Constructor.
    ///
    /// - Parameters:
    ///    - kind: the kind of the alarm
    ///    - level: the initial level of the alarm
    internal init(kind: Kind, level: Level) {
        self.kind = kind
        self.level = level
    }

    /// Debug description.
    public override var description: String {
        return "Alarm \(kind): \(level)"
    }
}

/// Instrument that informs about alarms.
///
/// This instrument can be retrieved by:
/// ```
/// drone.getInstrument(Instruments.alarms)
/// ```
@objc(GSAlarms)
public protocol Alarms: Instrument {

    /// Delay in seconds before the drone starts an automatic landing.
    ///
    /// The actual reason why automatic landing is scheduled depends on which of the following alarms is currently 'on'
    /// (i.e. `.warning` or `.critical`):
    ///   - `.automaticLandingBatteryIssue`
    ///
    /// When one of those alarms is in such a state, then this method tells when automatic landing procedure
    /// is about to start.
    /// Otherwise (when all those alarms are `.off`), no automatic landing procedure is currently scheduled and this
    /// property consequently returns 0.
    var automaticLandingDelay: TimeInterval { get }

    /// Gets the alarm of a given kind.
    ///
    /// - Parameter kind: the kind of alarm to get
    /// - Returns: the alarm
    func getAlarm(kind: Alarm.Kind) -> Alarm
}

/// :nodoc:
/// Instrument descriptor
@objc(GSAlarmsDesc)
public class AlarmsDesc: NSObject, InstrumentClassDesc {
    public typealias ApiProtocol = Alarms
    public let uid = InstrumentUid.alarms.rawValue
    public let parent: ComponentDescriptor? = nil
}
