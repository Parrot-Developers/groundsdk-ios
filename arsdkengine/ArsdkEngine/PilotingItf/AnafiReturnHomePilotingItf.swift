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

/// Return home piloting interface component controller for the Anafi message based drones
class AnafiReturnHomePilotingItf: ReturnHomePilotingItfController {

    /// Special value returned by `latitude` or `longitude` when the coordinate is not known.
    private static let UnknownCoordinate: Double = 500

    override func sendCancelAutoTrigger() {
        sendCommand(ArsdkFeatureRth.cancelAutoTriggerEncoder())
    }

    /// Send set preferred target command
    ///
    /// - Parameter preferredTarget: new preferred target
    override func sendPreferredTargetCommand(_ preferredTarget: ReturnHomeTarget) {
        let homeType: ArsdkFeatureArdrone3GpssettingsHometypeType
        switch preferredTarget {
        case .takeOffPosition:
            homeType = .takeoff
        case .controllerPosition:
            homeType = .pilot
        case .trackedTargetPosition:
            homeType = .followee
        }
        sendCommand(ArsdkFeatureArdrone3Gpssettings.homeTypeEncoder(type: homeType))
    }

    /// Send return home delay command
    ///
    /// - Parameter delay: new return home delay
    override func sendHomeDelayCommand(_ delay: Int) {
        sendCommand(ArsdkFeatureArdrone3Gpssettings.returnHomeDelayEncoder(delay: UInt(delay)))
    }

    /// Send set min altitude command
    ///
    /// - Parameter minAltitude: new min altitude
    override func sendMinAltitudeCommand(_ minAltitude: Double) {
        sendCommand(ArsdkFeatureArdrone3Gpssettings.returnHomeMinAltitudeEncoder(value: Float(minAltitude)))
    }

    /// Send the command to activate/deactivate return home
    ///
    /// - Parameter active: true to activate return home, false to deactivate it
    override func sendReturnHomeCommand(active: Bool) {
        sendCommand(ArsdkFeatureArdrone3Piloting.navigateHomeEncoder(start: active ? 1 : 0))
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3PilotingstateUid {
            ArsdkFeatureArdrone3Pilotingstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3GpssettingsstateUid {
            ArsdkFeatureArdrone3Gpssettingsstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3GpsstateUid {
            ArsdkFeatureArdrone3Gpsstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureRthUid {
            ArsdkFeatureRth.decode(command, callback: self)
        }
    }
}

/// Anafi Piloting State decode callback implementation
extension AnafiReturnHomePilotingItf: ArsdkFeatureArdrone3PilotingstateCallback {
    func onNavigateHomeStateChanged(
        state: ArsdkFeatureArdrone3PilotingstateNavigatehomestatechangedState,
        reason: ArsdkFeatureArdrone3PilotingstateNavigatehomestatechangedReason) {
        ULog.d(.tag, "ReturnHome: navigateHomeStateChanged: state=\(state.rawValue) reason=\(reason.rawValue)")
        switch state {
        case .available:
            let availabilityReason: ReturnHomeReason
            switch reason {
            case .finished:
                availabilityReason = .finished
            case .userrequest:
                availabilityReason = .userRequested
            default:
                availabilityReason = .none
            }

            returnHomePilotingItf.update(reason: availabilityReason)
            notifyIdle()
        case .inprogress,
             .pending:
            // reset the auto trigger delay if any
            autoTriggerDelay = nil
            if pilotingItf.state != .active {
                switch reason {
                case .userrequest:
                    returnHomePilotingItf.update(reason: .userRequested)
                case .connectionlost:
                    returnHomePilotingItf.update(reason: .connectionLost)
                case .lowbattery:
                    returnHomePilotingItf.update(reason: .powerLow)
                case .finished,
                     .stopped,
                     .enabled,
                     .disabled:
                    returnHomePilotingItf.update(reason: .none)
                case .sdkCoreUnknown:
                    // don't change anything if value is unknown
                    ULog.w(.tag, "Unknown reason, reason won't be modified and might be wrong.")
                }
                notifyActive()
            }
        case .unavailable:
            returnHomePilotingItf.update(reason: .none)
            notifyUnavailable()
        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown navigate home state, skipping this event.")
            return
        }
        pilotingItf.notifyUpdated()
    }
}

/// Anafi Return Home decode callback implementation
extension AnafiReturnHomePilotingItf: ArsdkFeatureRthCallback {
    func onHomeReachability(status: ArsdkFeatureRthHomeReachability) {
        switch status {
        case .reachable:
            homeReachability = .reachable
        case .notReachable:
            homeReachability = .notReachable
        case .critical:
            homeReachability = .critical
        case .unknown:
            homeReachability = .unknown
        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown ArsdkFeatureRthHomeReachability, skipping this event.")
        }
        returnHomePilotingItf.notifyUpdated()
    }

    func onRthAutoTrigger(reason: ArsdkFeatureRthAutoTriggerReason, delay: UInt) {
        switch reason {
        case .none:
            autoTriggerDelay = nil
        case .batteryCriticalSoon:
            autoTriggerDelay = TimeInterval(delay)
        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown ArsdkFeatureRthAutoTriggerReason, skipping this event.")
        }
        returnHomePilotingItf.notifyUpdated()
    }
}

/// Anafi Gps Settings State decode callback implementation
extension AnafiReturnHomePilotingItf: ArsdkFeatureArdrone3GpssettingsstateCallback {
    func onHomeChanged(latitude: Double, longitude: Double, altitude: Double) {
        ULog.d(.ctrlTag, "ReturnHome: onHomeChanged: latitude=\(latitude) longitude=\(longitude) altitude =\(altitude)")
        if latitude != AnafiReturnHomePilotingItf.UnknownCoordinate &&
            longitude != AnafiReturnHomePilotingItf.UnknownCoordinate {
            returnHomePilotingItf.update(homeLocation: (latitude: latitude, longitude: longitude, altitude: altitude))
                .notifyUpdated()
        } else {
            returnHomePilotingItf.update(homeLocation: nil) .notifyUpdated()
        }
    }

    func onHomeTypeChanged(type: ArsdkFeatureArdrone3GpssettingsstateHometypechangedType) {
        ULog.d(.ctrlTag, "ReturnHome: onHomeTypeChanged: type=\(type.rawValue)")
        switch type {
        case .takeoff:
            settingDidChange(.preferredTarget(.takeOffPosition))
        case .pilot:
            settingDidChange(.preferredTarget(.controllerPosition))
        case .followee:
            settingDidChange(.preferredTarget(.trackedTargetPosition))
        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown home type, skipping this event.")
            return
        }
    }

    func onReturnHomeDelayChanged(delay: UInt) {
        ULog.d(.ctrlTag, "ReturnHome: onReturnHomeDelayChanged: delay=\(delay)")
        settingDidChange(.autoStartOnDisconnectDelay(Int(delay)))
    }

    func onReturnHomeMinAltitudeChanged(value: Float, min: Float, max: Float) {
        ULog.d(.ctrlTag, "ReturnHome: onReturnHomeMinAltitudeChanged: value=\(value). min=\(min), max= \(max)")
        settingDidChange(.minAltitude(Double(min), Double(value), Double(max)))
    }
}

/// Anafi Gps State decode callback implementation
extension AnafiReturnHomePilotingItf: ArsdkFeatureArdrone3GpsstateCallback {
    func onHomeTypeChosenChanged(type: ArsdkFeatureArdrone3GpsstateHometypechosenchangedType) {
        ULog.d(.ctrlTag, "ReturnHome: onHomeTypeChosenChanged: type=\(type.rawValue)")
        switch type {
        case .takeoff:
            returnHomePilotingItf.update(currentTarget: .takeOffPosition, gpsFixedOnTakeOff: true)
        case .firstFix:
            returnHomePilotingItf.update(currentTarget: .takeOffPosition, gpsFixedOnTakeOff: false)
        case .pilot:
            returnHomePilotingItf.update(currentTarget: .controllerPosition, gpsFixedOnTakeOff: true)
        case .followee:
            break
        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown home type, skipping this event.")
            return
        }
        returnHomePilotingItf.notifyUpdated()
    }
}
