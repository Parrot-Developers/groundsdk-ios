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

/// Guided piloting interface component controller for the Anafi message based drones
class AnafiGuidedPilotingItf: GuidedPilotingItfController {

    // Send the command for a MoveTo location
    override func sendMoveToLocationCommand(locationDirective: LocationDirective) {

        if let speed = locationDirective.speed {
            let orientationModeValue: ArsdkFeatureMoveOrientationMode
            var heading = 0.0

            switch locationDirective.orientation {
            case .none:
                orientationModeValue = .none
            case .toTarget:
                orientationModeValue = .toTarget
            case .headingStart(let headingValue):
                orientationModeValue = .headingStart
                heading = headingValue
            case .headingDuring(let headingValue):
                orientationModeValue = .headingDuring
                heading = headingValue
            }
            sendCommand(ArsdkFeatureMove.extendedMoveToEncoder(
                latitude: locationDirective.latitude, longitude: locationDirective.longitude,
                altitude: locationDirective.altitude, orientationMode: orientationModeValue,
                heading: Float(heading), maxHorizontalSpeed: Float(speed.horizontalSpeed),
                maxVerticalSpeed: Float(speed.verticalSpeed), maxYawRotationSpeed: Float(speed.yawRotationSpeed)))
        } else {
            let orientationModeValue: ArsdkFeatureArdrone3PilotingMovetoOrientationMode
            var heading = 0.0

            switch locationDirective.orientation {
            case .none:
                orientationModeValue = .none
            case .toTarget:
                orientationModeValue = .toTarget
            case .headingStart(let headingValue):
                orientationModeValue = .headingStart
                heading = headingValue
            case .headingDuring(let headingValue):
                orientationModeValue = .headingDuring
                heading = headingValue
            }
            sendCommand(ArsdkFeatureArdrone3Piloting.moveToEncoder(
                latitude: locationDirective.latitude, longitude: locationDirective.longitude,
                altitude: locationDirective.altitude, orientationMode: orientationModeValue, heading: Float(heading)))
        }
    }

    // Send the command to cancel a MoveTo location
    override func sendCancelMoveToCommand() {
        sendCommand(ArsdkFeatureArdrone3Piloting.cancelMoveToEncoder())
    }

    // Send the command to cancel a Relative Move
    override func sendCancelRelativeMoveCommand() {
        sendCommand(ArsdkFeatureArdrone3Piloting.moveByEncoder(dx: 0, dy: 0, dz: 0, dpsi: 0))
    }

    // Send the command for a Relative Move
    override func sendRelativeMoveCommand(relativeMoveDirective: RelativeMoveDirective) {
        // save this Directitive as an Initial Directive. This value will be used in the `latestFinishedFlightInfo`
        previousRelativeMove = initialRelativeMove
        initialRelativeMove = relativeMoveDirective

        let headingRadians = Float(relativeMoveDirective.headingRotation.toRadians())
        if let speed = relativeMoveDirective.speed {
            sendCommand(ArsdkFeatureMove.extendedMoveByEncoder(
                dX: Float(relativeMoveDirective.forwardComponent),
                dY: Float(relativeMoveDirective.rightComponent),
                dZ: Float(relativeMoveDirective.downwardComponent),
                dPsi: headingRadians,
                maxHorizontalSpeed: Float(speed.horizontalSpeed),
                maxVerticalSpeed: Float(speed.verticalSpeed),
                maxYawRotationSpeed: Float(speed.yawRotationSpeed)))
        } else {
            sendCommand(ArsdkFeatureArdrone3Piloting.moveByEncoder(
                dx: Float(relativeMoveDirective.forwardComponent),
                dy: Float(relativeMoveDirective.rightComponent),
                dz: Float(relativeMoveDirective.downwardComponent),
                dpsi: headingRadians))
        }
        // Temporary : considers the drone is in a `running`  state
        currentGuidedDirective = relativeMoveDirective
        // the .notifyUpdated() will be done in the  notifyActive()
        notifyActive()
    }

    override func didDisconnect() {
        guidedPilotingItf.update(unavailabilityReasons: nil)
        super.didDisconnect()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3PilotingstateUid {
            ArsdkFeatureArdrone3Pilotingstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3PilotingeventUid {
            ArsdkFeatureArdrone3Pilotingevent.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureMoveUid {
            ArsdkFeatureMove.decode(command, callback: self)
        }
    }
}

/// Anafi MoveTo decode callback implementation
extension AnafiGuidedPilotingItf: ArsdkFeatureArdrone3PilotingstateCallback {

    /// Special value returned by `latitude` or `longitude` when the coordinate is not known.
    private static let UnknownCoordinate: Double = 500

    func onMoveToChanged(
        latitude: Double, longitude: Double, altitude: Double,
        orientationMode: ArsdkFeatureArdrone3PilotingstateMovetochangedOrientationMode, heading: Float,
        status: ArsdkFeatureArdrone3PilotingstateMovetochangedStatus) {

        ULog.d(.ctrlTag, "GuidedPiloting: onMoveToChanged latitude=\(latitude) longitude=\(longitude)" +
            " altitude=\(altitude) orientation=\(orientationMode) heading=\(heading) status=\(status)")

        guard latitude != AnafiGuidedPilotingItf.UnknownCoordinate &&
            longitude != AnafiGuidedPilotingItf.UnknownCoordinate else {
                guidedPilotingItf.update(latestFinishedFlightInfo: nil).notifyUpdated()
                return
        }

        let orientationDirective: OrientationDirective
        switch orientationMode {
        case .none:
            orientationDirective = .none
        case .toTarget:
            orientationDirective = .toTarget
        case .headingStart:
            orientationDirective = .headingStart(Double(heading))
        case .headingDuring:
            orientationDirective = .headingStart(Double(heading))
        case .sdkCoreUnknown:
            ULog.w(.tag, "Unknown onMoveToChanged orientation, skipping this event")
            return
        }

        let onMoveChangedDirective = LocationDirective(
            latitude: latitude, longitude: longitude, altitude: altitude, orientation: orientationDirective, speed: nil)
        switch status {
        case .running:
            currentGuidedDirective = onMoveChangedDirective
            // the .notifyUpdated() will be done in the  notifyActive()
            notifyActive()

        case .done, .canceled, .error:
            // remove any current directive
            currentGuidedDirective = nil
            // set the finished information in the interface
            let latestFinish = FinishedLocationFlightInfoCore(
                directive: onMoveChangedDirective, wasSuccessful: status == .done )
            guidedPilotingItf.update(latestFinishedFlightInfo: latestFinish)
            if pilotingItf.state == .active
                 && (guidedPilotingItf.unavailabilityReasons?.count ?? 0) == 0 {
                // the .notifyUpdated() will be done in the  notifyIdle()
                notifyIdle()
            } else {
                pilotingItf.notifyUpdated()
            }

        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown onMoveToChanged status, skipping this event.")
            return
        }
    }

    /// Piloting State decode callback implementation
    func onFlyingStateChanged(state: ArsdkFeatureArdrone3PilotingstateFlyingstatechangedState) {
        /// if onInfo event (from ArsdkFeatureMoveCallback) is supported, listening to the flying state is of no use.
        /// This event is dropped.
        if guidedPilotingItf.unavailabilityReasons == nil {
            switch state {
            case .landed, .emergency, .usertakeoff, .motorRamping, .takingoff, .landing, .emergencyLanding:
                notifyUnavailable()

            case .hovering, .flying:
                if pilotingItf.state != .active {
                    notifyIdle()
                }

            case .sdkCoreUnknown:
                fallthrough
            @unknown default:
                // don't change anything if value is unknown
                ULog.w(.tag, "Unknown flying state, skipping this event.")
                return
            }
        }
    }
}

// Anafi MoveByEnd decode callback implementation
extension AnafiGuidedPilotingItf: ArsdkFeatureArdrone3PilotingeventCallback {

    func onMoveByEnd(
        dx: Float, dy: Float, dz: Float, dpsi: Float, error: ArsdkFeatureArdrone3PilotingeventMovebyendError) {

        ULog.d(.ctrlTag, "GuidedPiloting: onMoveByEnd dx=\(dx) dy=\(dy) dz=\(dz) dpsi=\(dpsi) error=\(error)")

        switch error {
        case .interrupted:
            // If a relative move was started before the previous one ended, the interrupted move is the previous one.
            let latestFinish = FinishedRelativeMoveFlightInfoCore(
                wasSuccessful: false, directive: previousRelativeMove, actualForwardComponent: Double(dx),
                actualRightComponent: Double(dy), actualDownwardComponent: Double(dz),
                actualHeadingRotation: Double(dpsi).toDegrees())

            guidedPilotingItf.update(latestFinishedFlightInfo: latestFinish).notifyUpdated()
            previousRelativeMove = nil

        case .ok, .unknown, .busy, .notavailable:
            // set the finished information in the interface
            let success = error == .ok
            let latestFinish = FinishedRelativeMoveFlightInfoCore(
                wasSuccessful: success, directive: initialRelativeMove, actualForwardComponent: Double(dx),
                actualRightComponent: Double(dy), actualDownwardComponent: Double(dz),
                actualHeadingRotation: Double(dpsi).toDegrees())

            // remove any current directive
            currentGuidedDirective = nil
            guidedPilotingItf.update(latestFinishedFlightInfo: latestFinish)
            // no need to keep a previous directive (used for the interrupted state)
            previousRelativeMove = nil
            // clean the initialDirective
            initialRelativeMove = nil
            // create a final information for the guidedPilotingtf
            if pilotingItf.state == .active
                && (guidedPilotingItf.unavailabilityReasons?.count ?? 0) == 0 {
                notifyIdle()
            } else {
                pilotingItf.notifyUpdated()
            }

        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown ArsdkFeatureArdrone3PilotingeventMovebyendError status, skipping this event.")
            return
        }

    }
}

// Anafi move decode callback implementation
extension AnafiGuidedPilotingItf: ArsdkFeatureMoveCallback {
    func onInfo(missingInputsBitField: UInt) {
        guidedPilotingItf.update(
            unavailabilityReasons: GuidedIssue.createSetFrom(bitField: missingInputsBitField))
        if guidedPilotingItf.unavailabilityReasons!.isEmpty {
            if guidedPilotingItf.state != .active {
                notifyIdle()
            }
        } else {
            notifyUnavailable()
        }
        guidedPilotingItf.notifyUpdated()
    }
}

extension GuidedIssue: ArsdkMappableEnum {

    /// Create set of guided issues from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all guided issues set in bitField
    static func createSetFrom(bitField: UInt) -> Set<GuidedIssue> {
        var result = Set<GuidedIssue>()
        ArsdkFeatureMoveIndicatorBitField.forAllSet(in: bitField) { arsdkValue in
            if let missing = GuidedIssue(fromArsdk: arsdkValue) {
                result.insert(missing)
            }
        }
        return result
    }
    static var arsdkMapper = Mapper<GuidedIssue, ArsdkFeatureMoveIndicator>([
        .droneGpsInfoInaccurate: .droneGps,
        .droneNotCalibrated: .droneMagneto,
        .droneNotFlying: .droneFlying,
        .droneOutOfGeofence: .droneGeofence,
        .droneTooCloseToGround: .droneMinAltitude,
        .droneAboveMaxAltitude: .droneMaxAltitude
        ])
}
