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

/// Point Of Interest piloting interface component controller for the Anafi message based drones
class AnafiPoiPilotingItf: ActivablePilotingItfController {

    /// The piloting interface from which this object is the delegate
    private var poiPilotingItf: PoiPilotingItfCore {
        return pilotingItf as! PoiPilotingItfCore
    }

    /// Current targeted Point Of Interest. Nil if there’s no piloted Point Of Interest in progress
    private var currentPointOfInterest: PointOfInterestCore? {
        didSet {
            if currentPointOfInterest != oldValue {
                // set the value in the interface
                poiPilotingItf.update(currentPointOfInterest: currentPointOfInterest)
            }
        }
    }

    /// Pending request of Point Of Interest
    private var pendingPointOfInterest: PointOfInterestCore?

    /// True or false if the drone is flying
    private var isFlying = false {
        didSet {
            if isFlying != oldValue {
                updateState()
            }
        }
    }

    /// Whether POI command is available on the drone
    private var dronePoiFeatureAvailable = false

    /// Whether PilotedPOIV2 command is supported
    private var poiV2Supported = false

    /// Constructor
    ///
    /// - Parameter activationController: activation controller that owns this piloting interface controller
    init(activationController: PilotingItfActivationController) {
        super.init(activationController: activationController, sendsPilotingCommands: true)
        pilotingItf = PoiPilotingItfCore(store: droneController.drone.pilotingItfStore, backend: self)
    }

    override func didDisconnect() {
        super.didDisconnect()
        // the unavailable state will be set in unpublish
        pilotingItf.unpublish()
        // be sure to reset the current status
        currentPointOfInterest = nil
        pendingPointOfInterest = nil
        isFlying = false
        dronePoiFeatureAvailable = false
    }

    override func didConnect() {
        // the notify will be done in publish
        pilotingItf.publish()
    }

    override func requestDeactivation() {
        // remove any pending PointOfInterest request PointOfInterest
        pendingPointOfInterest = nil

        // send a stop if a current Poi is active
        if currentPointOfInterest != nil {
            sendStopPoi()
        }
    }

    override func requestActivation() {
        // check if we have a pending command received before activation sate
        if let pendingPointOfInterest = pendingPointOfInterest {
                sendStartPoi(
                    latitude: pendingPointOfInterest.latitude, longitude: pendingPointOfInterest.longitude,
                    altitude: pendingPointOfInterest.altitude, mode: pendingPointOfInterest.mode)
            self.pendingPointOfInterest = nil
        }
    }

    /// Updates the available status and the current Point Of Interest running on the drone
    ///
    /// - Parameters:
    ///   - dronePoiFeatureAvailable: true of false if the PointOfInterest Command is available on the drone
    ///   - pointOfInterest: the current pointOfInterest returned by the drone (or nil)
    private func update(dronePoiFeatureAvailable: Bool, pointOfInterest: PointOfInterestCore?) {
        var changed = false
        if self.dronePoiFeatureAvailable != dronePoiFeatureAvailable {
            self.dronePoiFeatureAvailable = dronePoiFeatureAvailable
            changed = true
        }
        if currentPointOfInterest != pointOfInterest {
            currentPointOfInterest = pointOfInterest
            changed = true
        }
        if changed {
            updateState()
        }
    }

    /// Updates the state of the piloting interface.
    ///
    /// If the drone is not flying or is marked as unavailable by the drone, the interface state is set to .unavailable
    /// Otherwise, the interface state is set to .idle if there is running Point Of Interest or to .active
    /// if there is a running Point Of Interest.
    private func updateState() {
        if isFlying && dronePoiFeatureAvailable {
            if currentPointOfInterest == nil {
                notifyIdle()
            } else {
                notifyActive()
            }
        } else {
            currentPointOfInterest = nil
            pendingPointOfInterest = nil
            notifyUnavailable()
        }
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3PilotingstateUid {
            ArsdkFeatureArdrone3Pilotingstate.decode(command, callback: self)
        }
    }
}

// MARK: - PoiPilotingItfBackend
extension AnafiPoiPilotingItf: PoiPilotingItfBackend {

    func set(pitch: Int) {
        setPitch(pitch)
    }

    func set(roll: Int) {
        setRoll(roll)
    }

    func set(verticalSpeed: Int) {
        setGaz(verticalSpeed)
    }

    func start(latitude: Double, longitude: Double, altitude: Double, mode: PointOfInterestMode) {
        switch pilotingItf.state {
        case .idle:
            pendingPointOfInterest = PointOfInterestCore(latitude: latitude, longitude: longitude, altitude: altitude,
                                                         mode: mode)
            _ = droneController.pilotingItfActivationController.activate(pilotingItf: self)
        case .active:
            sendStartPoi(latitude: latitude, longitude: longitude, altitude: altitude, mode: mode)
        case .unavailable:
            break
        }
    }

    // MARK: commands

    /// Send the command to start a Point Of Interest.
    /// Subclass must override this function to send the drone specific command.
    ///
    /// - Parameters:
    ///   - latitude: latitude of the location (in degrees) to look at
    ///   - longitude: longitude of the location (in degrees) to look at
    ///   - altitude: altitude above take off point (in meters) to look at
    ///   - mode: Point Of Interest mode
    private func sendStartPoi(latitude: Double, longitude: Double, altitude: Double, mode: PointOfInterestMode) {
        if poiV2Supported {
            let arsdkMode: ArsdkFeatureArdrone3PilotingStartpilotedpoiv2Mode
            switch mode {
            case .lockedGimbal:
                arsdkMode = .lockedGimbal
            case .freeGimbal:
                arsdkMode = .freeGimbal
            }
            sendCommand(
                ArsdkFeatureArdrone3Piloting.startPilotedPOIV2Encoder(
                    latitude: latitude, longitude: longitude, altitude: altitude, mode: arsdkMode))
        } else if mode == .lockedGimbal {
            sendCommand(
                ArsdkFeatureArdrone3Piloting.startPilotedPOIEncoder(
                    latitude: latitude, longitude: longitude, altitude: altitude))
        }
    }

    /// Send the command to cancel a Point Of Interest
    /// Subclass must override this function to send the drone specific command
    private func sendStopPoi() {
        sendCommand(ArsdkFeatureArdrone3Piloting.stopPilotedPOIEncoder())
    }
}

/// Anafi MoveTo decode callback implementation
extension AnafiPoiPilotingItf: ArsdkFeatureArdrone3PilotingstateCallback {

    /// Special value returned by `latitude` or `longitude` when the coordinate is not known.
    private static let UnknownCoordinate: Double = 500

    func onPilotedPOI(
        latitude: Double, longitude: Double, altitude: Double,
        status: ArsdkFeatureArdrone3PilotingstatePilotedpoiStatus) {

        ULog.d(.ctrlTag, "PoiPiloting: onPilotedPoi latitude=\(latitude) longitude=\(longitude)" +
            " altitude=\(altitude) status=\(status)")

        switch status {
        case .unavailable:
            currentPointOfInterest = nil
            update(dronePoiFeatureAvailable: false, pointOfInterest: nil)

        case .running:
            let newPointOfInterest: PointOfInterestCore?
            if latitude != AnafiPoiPilotingItf.UnknownCoordinate &&
                longitude != AnafiPoiPilotingItf.UnknownCoordinate &&
                altitude != AnafiPoiPilotingItf.UnknownCoordinate {
                newPointOfInterest = PointOfInterestCore(latitude: latitude, longitude: longitude, altitude: altitude,
                                                         mode: .lockedGimbal)
            } else {
                newPointOfInterest = nil
            }
            update(dronePoiFeatureAvailable: true, pointOfInterest: newPointOfInterest)

        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown onPilotedPoi status, skipping this event.")

        default:
            update(dronePoiFeatureAvailable: true, pointOfInterest: nil)
        }
    }

    func onPilotedPOIV2(latitude: Double, longitude: Double, altitude: Double,
                        mode: ArsdkFeatureArdrone3PilotingstatePilotedpoiv2Mode,
                        status: ArsdkFeatureArdrone3PilotingstatePilotedpoiv2Status) {
        ULog.d(.ctrlTag, "PoiPiloting: onPilotedPoiV2 latitude=\(latitude) longitude=\(longitude)" +
            " altitude=\(altitude) mode=\(mode) status=\(status)")

        poiV2Supported = true

        switch status {
        case .unavailable:
            currentPointOfInterest = nil
            update(dronePoiFeatureAvailable: false, pointOfInterest: nil)

        case .running:
            let newPointOfInterest: PointOfInterestCore?
            if latitude != AnafiPoiPilotingItf.UnknownCoordinate &&
                longitude != AnafiPoiPilotingItf.UnknownCoordinate &&
                altitude != AnafiPoiPilotingItf.UnknownCoordinate {
                let newMode: PointOfInterestMode?
                switch mode {
                case .lockedGimbal:
                    newMode = .lockedGimbal
                case .freeGimbal:
                    newMode = .freeGimbal
                case .sdkCoreUnknown:
                    newMode = nil
                }
                if let newMode = newMode {
                    newPointOfInterest = PointOfInterestCore(latitude: latitude, longitude: longitude,
                                                             altitude: altitude, mode: newMode)
                } else {
                    newPointOfInterest = nil
                }
            } else {
                newPointOfInterest = nil
            }

            update(dronePoiFeatureAvailable: true, pointOfInterest: newPointOfInterest)

        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown onPilotedPoiV2 status, skipping this event.")

        default:
            update(dronePoiFeatureAvailable: true, pointOfInterest: nil)
        }
    }

    /// Piloting State decode callback implementation
    func onFlyingStateChanged(state: ArsdkFeatureArdrone3PilotingstateFlyingstatechangedState) {
        // If the drone is not flying, the interface state is set to .unavailable
        // If the drone is flying without a running Point Of Interest, the interface state is set to .idle
        // If the drone is flying with a running Point Of Interest, the interface state is set to .active
        switch state {
        case .landed, .emergency, .usertakeoff, .motorRamping, .takingoff, .landing, .emergencyLanding:
            isFlying = false

        case .hovering, .flying:
            isFlying = true

        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown flying state, skipping this event.")
            return
        }
    }
}
