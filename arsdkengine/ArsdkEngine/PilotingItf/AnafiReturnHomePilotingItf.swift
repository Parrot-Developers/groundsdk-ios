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

    override func setCustomLocation(latitude: Double, longitude: Double, altitude: Double) {
        sendCommand(ArsdkFeatureRth.setCustomLocationEncoder(latitude: latitude,
                                                             longitude: longitude,
                                                             altitude: Float(altitude)))
    }

    /// Send preferred target command
    ///
    /// - Parameter preferredTarget: new preferred target
    override func sendPreferredTargetCommand(_ preferredTarget: ReturnHomeTarget) {
        let homeType: ArsdkFeatureRthHomeType
        switch preferredTarget {
        case .none:
            homeType = .takeoff
        case .customPosition:
            homeType = .custom
        case .takeOffPosition:
            homeType = .takeoff
        case .controllerPosition:
            homeType = .pilot
        case .trackedTargetPosition:
            homeType = .followee
        }
        sendCommand(ArsdkFeatureRth.setPreferredHomeTypeEncoder(type: homeType))
    }

    /// Send the command to activate/deactivate auto trigger return home
    ///
    /// - Parameter active: true to activate auto trigger return home, false to deactivate it
    override func sendAutoTriggerModeCommand(active: Bool) {
        let mode: ArsdkFeatureRthAutoTriggerMode = active ? .on : .off
        sendCommand(ArsdkFeatureRth.setAutoTriggerModeEncoder(mode: mode))
    }

    /// Send the wanted ending behavior command
    ///
    /// - Parameter wantedEndingBehavior: new wanted ending behavior
    override func sendWantedEndingBehaviorCommand(_ wantedEndingBehavior: ReturnHomeEndingBehavior) {
        let endingBehavior: ArsdkFeatureRthEndingBehavior
        switch wantedEndingBehavior {
        case .landing:
            endingBehavior = .landing
        case .hovering:
            endingBehavior = .hovering
        }
        sendCommand(ArsdkFeatureRth.setEndingBehaviorEncoder(endingBehavior: endingBehavior))
    }

    /// Send return home delay command
    ///
    /// - Parameter delay: new return home delay
    override func sendHomeDelayCommand(_ delay: Int) {
        sendCommand(ArsdkFeatureRth.setDelayEncoder(delay: UInt(delay)))
    }

    /// Send min altitude command
    ///
    /// - Parameter minAltitude: new min altitude
    override func sendMinAltitudeCommand(_ minAltitude: Double) {
        sendCommand(ArsdkFeatureRth.setMinAltitudeEncoder(
            altitude: Float(minAltitude)))
    }

    /// Send ending hovering altitude command
    ///
    /// - Parameter endingHoveringAltitude: new ending hovering altitude
    override func sendEndingHoveringAltitudeCommand(_ endingHoveringAltitude: Double) {
        sendCommand(ArsdkFeatureRth.setEndingHoveringAltitudeEncoder(altitude: Float(endingHoveringAltitude)))
    }

    /// Send the command to activate/deactivate return home
    ///
    /// - Parameter active: true to activate return home, false to deactivate it
    override func sendReturnHomeCommand(active: Bool) {
        if active {
            sendCommand(ArsdkFeatureRth.returnToHomeEncoder())
        } else {
            sendCommand(ArsdkFeatureRth.abortEncoder())
        }
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureRthUid {
            ArsdkFeatureRth.decode(command, callback: self)
        }
    }
}

/// Anafi return home decode callback implementation
extension AnafiReturnHomePilotingItf: ArsdkFeatureRthCallback {
    func onState(state: ArsdkFeatureRthState, reason: ArsdkFeatureRthStateReason) {
        ULog.d(.tag, "ReturnHome: onState: state=\(state.rawValue) reason=\(reason.rawValue)")
        switch state {
        case .available:
            let availabilityReason: ReturnHomeReason
            switch reason {
            case .finished:
                availabilityReason = .finished
            case .userRequest:
                availabilityReason = .userRequested
            default:
                availabilityReason = .none
            }

            returnHomePilotingItf.update(reason: availabilityReason)
            notifyIdle()
        case .inProgress,
             .pending:
            // reset the auto trigger delay if any
            autoTriggerDelay = nil
            if pilotingItf.state != .active {
                switch reason {
                case .userRequest:
                    returnHomePilotingItf.update(reason: .userRequested)
                case .connectionLost:
                    returnHomePilotingItf.update(reason: .connectionLost)
                case .lowBattery:
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

    func onAutoTriggerMode(mode: ArsdkFeatureRthAutoTriggerMode) {
        switch mode {
        case .off:
            settingDidChange(.autoTriggerMode(false))
        case .on:
            settingDidChange(.autoTriggerMode(true))
        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown ArsdkFeatureRthAutoTriggerMode, skipping this event.")
        }
    }

    func onEndingBehavior(endingBehavior: ArsdkFeatureRthEndingBehavior) {
        switch endingBehavior {
        case .landing:
            settingDidChange(.endingBehavior(.landing))
        case .hovering:
            settingDidChange(.endingBehavior(.hovering))
        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown ArsdkFeatureRthEndingBehavior, skipping this event.")
        }
    }

    func onEndingHoveringAltitude(current: Float, min: Float, max: Float) {
        ULog.d(.tag, "ReturnHome: onEndingHoveringAltitude: current=\(current). min=\(min), max= \(max)")
        settingDidChange(.endingHoveringAltitude(Double(min), Double(current), Double(max)))
    }

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

    func onPreferredHomeType(type: ArsdkFeatureRthHomeType) {
        self.preferredTargetReceived = true
        switch type {
        case .none:
            settingDidChange(.preferredTarget(.none))
        case .takeoff:
            settingDidChange(.preferredTarget(.takeOffPosition))
        case .followee:
            settingDidChange(.preferredTarget(.trackedTargetPosition))
        case .custom:
            settingDidChange(.preferredTarget(.customPosition))
        case .pilot:
            settingDidChange(.preferredTarget(.controllerPosition))
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown home type, skipping this event.")
            return
        }
    }

    func onHomeType(type: ArsdkFeatureRthHomeType) {
        ULog.d(.tag, "ReturnHome: onHomeType: type=\(type.rawValue)")
        var homeType: ReturnHomeTarget = .none

        switch type {
        case .takeoff:
            homeType = .takeOffPosition
        case .pilot:
            homeType = .controllerPosition
        case .followee:
            homeType = .trackedTargetPosition
        case .none:
            homeType = .none
        case .custom:
            homeType = .customPosition

        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown home type, skipping this event.")
            return
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown home type, skipping this event.")
                return
        }
        returnHomePilotingItf.update(currentTarget: homeType).notifyUpdated()
    }

    func onTakeoffLocation(latitude: Double, longitude: Double, altitude: Float, fixedBeforeTakeoff: UInt) {
        updateRTHLocation(latitude: Double(latitude), longitude: Double(longitude),
                          altitude: Double(altitude))
        returnHomePilotingItf.update(gpsFixedOnTakeOff: (fixedBeforeTakeoff != 0)).notifyUpdated()
    }

    func onCustomLocation(latitude: Double, longitude: Double, altitude: Float) {
        updateRTHLocation(latitude: latitude, longitude: longitude,
                          altitude: Double(altitude))
        returnHomePilotingItf.notifyUpdated()
    }

    func onFolloweeLocation(latitude: Double, longitude: Double,
                            altitude: Float) {
        updateRTHLocation(latitude: latitude, longitude: longitude,
                          altitude: Double(altitude))
        returnHomePilotingItf.notifyUpdated()
    }

    func updateRTHLocation(latitude: Double, longitude: Double,
                           altitude: Double) {
        ULog.d(.tag, """
            ReturnHome: updateRTHLocation: latitude=\(latitude) longitude=\(longitude) altitude =\(altitude)
            """)
        if !latitude.isNaN && !longitude.isNaN && latitude != AnafiReturnHomePilotingItf.UnknownCoordinate &&
            longitude != AnafiReturnHomePilotingItf.UnknownCoordinate {
            returnHomePilotingItf.update(homeLocation: (latitude: latitude,
                                                        longitude: longitude,
                                                        altitude: altitude))
        } else {
            returnHomePilotingItf.update(homeLocation: nil)
        }
    }

    func onDelay(delay: UInt, min: UInt, max: UInt) {
        ULog.d(.tag, "ReturnHome: onReturnHomeDelayChanged: delay=\(delay)")
        settingDidChange(.autoStartOnDisconnectDelay(Int(delay)))
    }

    func onMinAltitude(current: Float, min: Float, max: Float) {
        ULog.d(.tag, "ReturnHome: onMinAltitude: value=\(current). min=\(min), max= \(max)")
        settingDidChange(.minAltitude(Double(min), Double(current), Double(max)))
    }
}
