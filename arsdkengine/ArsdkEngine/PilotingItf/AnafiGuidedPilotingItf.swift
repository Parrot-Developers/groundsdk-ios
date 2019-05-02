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
    override func sendMoveToLocationCommand(locationDirective: LocationDirectiveCore) {
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

    // Send the command to cancel a MoveTo location
    override func sendCancelMoveToCommand() {
        sendCommand(ArsdkFeatureArdrone3Piloting.cancelMoveToEncoder())
    }

    // Send the command to cancel a Relative Move
    override func sendCancelRelativeMoveCommand() {
        sendCommand(ArsdkFeatureArdrone3Piloting.moveByEncoder(dx: 0, dy: 0, dz: 0, dpsi: 0))
    }

    // Send the command for a Relative Move
    override func sendRelativeMoveCommand(relativeMoveDirective: RelativeMoveDirectiveCore) {
        // save this Directitive as an Initial Directive. This value will be used in the `latestFinishedFlightInfo`
        previousRelativeMove = initialRelativeMove
        initialRelativeMove = relativeMoveDirective

        let headingRadians = Float(relativeMoveDirective.headingRotation.toRadians())
        sendCommand(ArsdkFeatureArdrone3Piloting.moveByEncoder(
            dx: Float(relativeMoveDirective.forwardComponent),
            dy: Float(relativeMoveDirective.rightComponent),
            dz: Float(relativeMoveDirective.downwardComponent),
            dpsi: headingRadians))
        // Temporary : considers the drone is in a `running`  state
        currentGuidedDirective = relativeMoveDirective
        // the .notifyUpdated() will be done in the  notifyActive()
        notifyActive()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3PilotingstateUid {
            ArsdkFeatureArdrone3Pilotingstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3PilotingeventUid {
            ArsdkFeatureArdrone3Pilotingevent.decode(command, callback: self)
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

        let onMoveChangedDirective = LocationDirectiveCore (
            latitude: latitude, longitude: longitude, altitude: altitude, orientation: orientationDirective)
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
            if pilotingItf.state == .active {
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
        switch state {
        case .landed, .emergency, .usertakeoff, .motorRamping, .takingoff, .landing, .emergencyLanding:
            notifyUnavailable()

        case .hovering, .flying:
            if pilotingItf.state != .active {
                notifyIdle()
            }

        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown flying state, skipping this event.")
            return
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
            if pilotingItf.state == .active {
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
