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
import XCTest
@testable import ArsdkEngine
@testable import GroundSdk
import SdkCoreTesting

class GuidedPilotingItfTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var guidedPilotingItf: GuidedPilotingItf?
    var guidedPilotingItfRef: Ref<GuidedPilotingItf>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        guidedPilotingItfRef = drone.getPilotingItf(PilotingItfs.guided) { [unowned self] pilotingItf in
            self.guidedPilotingItf = pilotingItf
            self.changeCnt += 1
        }
        changeCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected and not known
        assertThat(guidedPilotingItf, `is`(nilValue()))

        // connect the drone, piloting interface should be published
        connect(drone: drone, handle: 1)
        assertThat(guidedPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        assertThat(guidedPilotingItf!.state, `is`(.unavailable))

        // disconnect drone
        disconnect(drone: drone, handle: 1)
        assertThat(guidedPilotingItf, nilValue())
        assertThat(changeCnt, `is`(2)) // should have been unactivated and deactivated
    }

    func testMoveToCmd() {

        connect(drone: drone, handle: 1)
        assertThat(guidedPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // flying
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
         assertThat(guidedPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(2))

        // use a Double -> Float -> Double conversion for the Heading
        let floatHeading = Float(4.4)
        let doubleHeading = Double(floatHeading)

        // send a moveToLocation command
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingMoveto(
            latitude: 1.1, longitude: 2.2, altitude: 3.3, orientationMode: .headingStart, heading: floatHeading))

        let moveToDirective = LocationDirective(latitude: 1.1, longitude: 2.2, altitude: 3.3,
                                                orientation: .headingStart(4.4), speed: nil)
        guidedPilotingItf!.move(directive: moveToDirective)

        // MoveTo is running
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateMovetochangedEncoder(
                latitude: 1.1, longitude: 2.2, altitude: 3.3, orientationMode: .headingStart, heading: floatHeading,
                status: .running))

        assertThat(changeCnt, `is`(3))
        let theNewLocationDirective = guidedPilotingItf!.currentDirective as! LocationDirective

        assertThat(theNewLocationDirective, `is`(
            latitude: 1.1, longitude: 2.2, altitude: 3.3, orientation: .headingStart(doubleHeading)))

        // The guided Piloting interface should be active
        assertThat(guidedPilotingItf!.state, `is`(.active))

        // MoveTo is finished
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateMovetochangedEncoder(
                latitude: 1.1, longitude: 2.2, altitude: 3.3, orientationMode: .headingStart, heading: floatHeading,
                status: .done))

        assertThat(changeCnt, `is`(4))
        assertThat(guidedPilotingItf!.currentDirective, `is`(nilValue()))
        let finishedLocationDirective = guidedPilotingItf!.latestFinishedFlightInfo as! FinishedLocationFlightInfoCore

        assertThat(finishedLocationDirective, `is`(
            latitude: 1.1, longitude: 2.2, altitude: 3.3, orientation: .headingStart(doubleHeading),
            wasSuccessful: true))

        // The guided Piloting interface should be idle
        assertThat(guidedPilotingItf!.state, `is`(.idle))

        // landed and state unavailable
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(guidedPilotingItf!.state, `is`(.unavailable))
        assertThat(changeCnt, `is`(5))
    }

    func testExtendedMoveToCmd() {

        connect(drone: drone, handle: 1)
        assertThat(guidedPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // flying
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
         assertThat(guidedPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(2))

        // use a Double -> Float -> Double conversion for the Heading
        let floatHeading = Float(4.4)
        let doubleHeading = Double(floatHeading)

        // send a moveToLocation command
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.moveExtendedMoveTo(
            latitude: 1.1, longitude: 2.2, altitude: 3.3, orientationMode: .headingStart, heading: floatHeading,
            maxHorizontalSpeed: 2.3, maxVerticalSpeed: 1.5, maxYawRotationSpeed: 2.7))

        let speed = GuidedPilotingSpeed(horizontalSpeed: 2.3, verticalSpeed: 1.5, yawRotationSpeed: 2.7)
        let moveToDirective = LocationDirective(latitude: 1.1, longitude: 2.2, altitude: 3.3,
                                                orientation: .headingStart(4.4), speed: speed)
        guidedPilotingItf!.move(directive: moveToDirective)

        // MoveTo is running
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateMovetochangedEncoder(
                latitude: 1.1, longitude: 2.2, altitude: 3.3, orientationMode: .headingStart, heading: floatHeading,
                status: .running))

        assertThat(changeCnt, `is`(3))
        let theNewLocationDirective = guidedPilotingItf!.currentDirective as! LocationDirective

        assertThat(theNewLocationDirective, `is`(
            latitude: 1.1, longitude: 2.2, altitude: 3.3, orientation: .headingStart(doubleHeading)))

        // The guided Piloting interface should be active
        assertThat(guidedPilotingItf!.state, `is`(.active))

        // MoveTo is finished
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateMovetochangedEncoder(
                latitude: 1.1, longitude: 2.2, altitude: 3.3, orientationMode: .headingStart, heading: floatHeading,
                status: .done))

        assertThat(changeCnt, `is`(4))
        assertThat(guidedPilotingItf!.currentDirective, `is`(nilValue()))
        let finishedLocationDirective = guidedPilotingItf!.latestFinishedFlightInfo as! FinishedLocationFlightInfoCore

        assertThat(finishedLocationDirective, `is`(
            latitude: 1.1, longitude: 2.2, altitude: 3.3, orientation: .headingStart(doubleHeading),
            wasSuccessful: true))

        // The guided Piloting interface should be idle
        assertThat(guidedPilotingItf!.state, `is`(.idle))

        // landed and state unavailable
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(guidedPilotingItf!.state, `is`(.unavailable))
        assertThat(changeCnt, `is`(5))
    }

    func testStartAndStopMoveToCmd() {

        connect(drone: drone, handle: 1)
        assertThat(guidedPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // flying and state idle
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        assertThat(guidedPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(2))

        // use a Double -> Float -> Double conversion for the Heading
        let floatHeading = Float(4.4)
        let doubleHeading = Double(floatHeading)

        // send a move To location command
        expectCommand(
            handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingMoveto(
                latitude: 1.1, longitude: 2.2, altitude: 3.3, orientationMode: .headingStart, heading: floatHeading))

        let moveToDirective = LocationDirective(latitude: 1.1, longitude: 2.2, altitude: 3.3,
                                                orientation: .headingStart(4.4), speed: nil)
        guidedPilotingItf!.move(directive: moveToDirective)

        // MoveTo is running
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateMovetochangedEncoder(
                latitude: 1.1, longitude: 2.2, altitude: 3.3, orientationMode: .headingStart, heading: floatHeading,
                status: .running))

        assertThat(changeCnt, `is`(3))
        let theNewLocationDirective = guidedPilotingItf!.currentDirective as! LocationDirective

        assertThat(theNewLocationDirective, `is`(
            latitude: 1.1, longitude: 2.2, altitude: 3.3, orientation: .headingStart(doubleHeading)))

        // The guided Piloting interface should be active
        assertThat(guidedPilotingItf!.state, `is`(.active))

        // MoveTo should be cancelled
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingCancelmoveto())

        // Stop the MoveTo deactivating the interface
        assertThat(guidedPilotingItf!.deactivate(), `is`(true))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateMovetochangedEncoder(
                latitude: 1.1, longitude: 2.2, altitude: 3.3, orientationMode: .headingStart, heading: floatHeading,
                status: .canceled))

        assertThat(changeCnt, `is`(4))
        assertThat(guidedPilotingItf!.currentDirective, `is`(nilValue()))
        let finishedLocationDirective = guidedPilotingItf!.latestFinishedFlightInfo as! FinishedLocationFlightInfoCore

        assertThat(finishedLocationDirective, `is`(
            latitude: 1.1, longitude: 2.2, altitude: 3.3, orientation: .headingStart(doubleHeading),
            wasSuccessful: false))

        // The guided Piloting interface should be idle
        assertThat(guidedPilotingItf!.state, `is`(.idle))
    }

    func testMoveRelativeCmd() {

        connect(drone: drone, handle: 1)
        assertThat(guidedPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // flying and state idle
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        assertThat(guidedPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(2))

        // send a relative move command
        expectCommand(
            handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingMoveby(
                dx: 1.1, dy: -2.2, dz: 3.3, dpsi: Float( (-0.4).toRadians() )))

        let initialRequestedMoveBy = RelativeMoveDirective(
            forwardComponent: 1.1, rightComponent: -2.2, downwardComponent: 3.3, headingRotation: -0.4, speed: nil)
        guidedPilotingItf!.move(directive: initialRequestedMoveBy)

        // The guided Piloting interface should be active
        assertThat(guidedPilotingItf!.state, `is`(.active))
        assertThat(guidedPilotingItf!.currentDirective as? RelativeMoveDirective, presentAnd(`is`(
            forwardComponent: 1.1, rightComponent: -2.2, downwardComponent: 3.3, headingRotation: -0.4)))

        assertThat(changeCnt, `is`(3))

        // relative move is running, encode the end of the move (no error)
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingeventMovebyendEncoder(
                dx: 11.1, dy: -22.2, dz: 33.3, dpsi: .pi, error: .ok))

        // The guided Piloting interface should be idle
        assertThat(guidedPilotingItf!.state, `is`(.idle))

        // The moveTo is finished
        assertThat(changeCnt, `is`(4))
        assertThat(guidedPilotingItf!.currentDirective, `is`(nilValue()))
        assertThat(guidedPilotingItf!.latestFinishedFlightInfo, `is`(present()))
        let finishedDirective = guidedPilotingItf!.latestFinishedFlightInfo as? FinishedRelativeMoveFlightInfoCore

        let angle = Double(Float.pi).toDegrees()
        assertThat(finishedDirective, presentAnd(`is`(
            wasSuccessful: true, directive: initialRequestedMoveBy, actualForwardComponent: Double(Float(11.1)),
            actualRightComponent: Double(Float(-22.2)), actualDownwardComponent: Double(Float(33.3)),
            actualHeadingRotation: angle )))

        // The guided Piloting interface should be idle
        assertThat(guidedPilotingItf!.state, `is`(.idle))
    }

    func testMoveExtendedRelativeCmd() {

        connect(drone: drone, handle: 1)
        assertThat(guidedPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // flying and state idle
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        assertThat(guidedPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(2))

        expectCommand(
            handle: 1, expectedCmd: ExpectedCmd.moveExtendedMoveBy(
                dX: 1.1, dY: -2.2, dZ: 3.3, dPsi: Float( (-0.4).toRadians()), maxHorizontalSpeed: 2.1,
                maxVerticalSpeed: 1.2, maxYawRotationSpeed: 0.7))

        let speed = GuidedPilotingSpeed(horizontalSpeed: 2.1, verticalSpeed: 1.2, yawRotationSpeed: 0.7)
        let initialRequestedMoveBy = RelativeMoveDirective(
            forwardComponent: 1.1, rightComponent: -2.2, downwardComponent: 3.3, headingRotation: -0.4, speed: speed)

        // send an extended relative move command
        guidedPilotingItf!.move(directive: initialRequestedMoveBy)

        // The guided Piloting interface should be active
        assertThat(guidedPilotingItf!.state, `is`(.active))
        assertThat(guidedPilotingItf!.currentDirective as? RelativeMoveDirective, presentAnd(`is`(
            forwardComponent: 1.1, rightComponent: -2.2, downwardComponent: 3.3, headingRotation: -0.4)))

        assertThat(changeCnt, `is`(3))

        // relative move is running, encode the end of the move (no error)
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingeventMovebyendEncoder(
                dx: 11.1, dy: -22.2, dz: 33.3, dpsi: .pi, error: .ok))

        // The guided Piloting interface should be idle
        assertThat(guidedPilotingItf!.state, `is`(.idle))

        // The moveTo is finished
        assertThat(changeCnt, `is`(4))
        assertThat(guidedPilotingItf!.currentDirective, `is`(nilValue()))
        assertThat(guidedPilotingItf!.latestFinishedFlightInfo, `is`(present()))
        let finishedDirective = guidedPilotingItf!.latestFinishedFlightInfo as? FinishedRelativeMoveFlightInfoCore

        let angle = Double(Float.pi).toDegrees()
        assertThat(finishedDirective, presentAnd(`is`(
            wasSuccessful: true, directive: initialRequestedMoveBy, actualForwardComponent: Double(Float(11.1)),
            actualRightComponent: Double(Float(-22.2)), actualDownwardComponent: Double(Float(33.3)),
            actualHeadingRotation: angle )))

        // The guided Piloting interface should be idle
        assertThat(guidedPilotingItf!.state, `is`(.idle))
    }

    func testMoveRelativeInterruptedCmd() {

        connect(drone: drone, handle: 1)
        assertThat(guidedPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // flying and state idle
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        assertThat(guidedPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(2))

        // send a relative move command (move #1)
        expectCommand(
            handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingMoveby(
                dx: 1.1, dy: -2.2, dz: 3.3, dpsi: Float( (-0.4).toRadians() )))

        // remember this directive (directive #1)
        let initialRequestedMoveByNumberOne = RelativeMoveDirective(
            forwardComponent: 1.1, rightComponent: -2.2, downwardComponent: 3.3, headingRotation: -0.4, speed: nil)
        // do the move #1
        guidedPilotingItf!.move(directive: initialRequestedMoveByNumberOne)

        // The guided Piloting interface should be active
        assertThat(guidedPilotingItf!.state, `is`(.active))
        assertThat(changeCnt, `is`(3))
        assertThat(guidedPilotingItf!.currentDirective as? RelativeMoveDirective, presentAnd(`is`(
            forwardComponent: 1.1, rightComponent: -2.2, downwardComponent: 3.3, headingRotation: -0.4)))

        // interrupt the move with an new one (directive #2)
        expectCommand(
            handle: 1, expectedCmd: ExpectedCmd.ardrone3PilotingMoveby(
                dx: 5, dy: 6, dz: 7, dpsi: Float( (8).toRadians())))
        let initialRequestedMoveByNumberTwo = RelativeMoveDirective(
        forwardComponent: 5, rightComponent: 6, downwardComponent: 7, headingRotation: 8, speed: nil)
        // send the command (directive #2)
        guidedPilotingItf!.move(directive: initialRequestedMoveByNumberTwo)

        // the drone interrupts the first directive
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingeventMovebyendEncoder(
                dx: 0.1, dy: 0.2, dz: 0.3, dpsi: 0, error: .interrupted))

        // the current is the second directive
        assertThat(guidedPilotingItf!.currentDirective as? RelativeMoveDirective, presentAnd(`is`(
            forwardComponent: 5, rightComponent: 6, downwardComponent: 7, headingRotation: 8)))

        // The guided Piloting interface should be still active
        assertThat(guidedPilotingItf!.state, `is`(.active))

        // The latest should be the first one is finished
        assertThat(guidedPilotingItf!.latestFinishedFlightInfo, `is`(present()))
        let finishedDirective = guidedPilotingItf!.latestFinishedFlightInfo as? FinishedRelativeMoveFlightInfoCore

        // the move 1 was interrupted and present in the latestFlight Info
        assertThat(finishedDirective, presentAnd(`is`(
            wasSuccessful: false, directive: initialRequestedMoveByNumberOne,
            actualForwardComponent: Double(Float(0.1)), actualRightComponent: Double(Float(0.2)),
            actualDownwardComponent: Double(Float(0.3)), actualHeadingRotation: 0 )))
    }

    func testUnavailabilityReasons() {
        connect(drone: drone, handle: 1)
        assertThat(guidedPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        assertThat(guidedPilotingItf!.state, `is`(.unavailable))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.moveInfoEncoder(
            missingInputsBitField: Bitfield<ArsdkFeatureMoveIndicator>.of(.droneGps, .droneMagneto)))
        assertThat(changeCnt, `is`(2))
        assertThat(guidedPilotingItf!.unavailabilityReasons!, containsInAnyOrder(.droneGpsInfoInaccurate,
            .droneNotCalibrated))
        assertThat(guidedPilotingItf!.state, `is`(.unavailable))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.moveInfoEncoder(
            missingInputsBitField: Bitfield<ArsdkFeatureMoveIndicator>.of(.droneGps, .droneMagneto)))
        assertThat(changeCnt, `is`(2))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.moveInfoEncoder(
            missingInputsBitField: Bitfield<ArsdkFeatureMoveIndicator>.of()))
        assertThat(guidedPilotingItf!.state, `is`(.idle))
        assertThat(guidedPilotingItf!.unavailabilityReasons!, `is`([]))
        assertThat(changeCnt, `is`(3))

        // should do nothing
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(guidedPilotingItf!.state, `is`(.idle))
        assertThat(changeCnt, `is`(3))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.moveInfoEncoder(
            missingInputsBitField: Bitfield<ArsdkFeatureMoveIndicator>.of(.droneMinAltitude, .droneMaxAltitude)))
        assertThat(guidedPilotingItf!.unavailabilityReasons!, `is`([.droneAboveMaxAltitude, .droneTooCloseToGround]))
        assertThat(changeCnt, `is`(4))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.moveInfoEncoder(
            missingInputsBitField: Bitfield<ArsdkFeatureMoveIndicator>.of(.droneGeofence)))
        assertThat(guidedPilotingItf!.unavailabilityReasons!, `is`([.droneOutOfGeofence]))
        assertThat(changeCnt, `is`(5))

        disconnect(drone: drone, handle: 1)
        assertThat(guidedPilotingItf, `is`(nilValue()))
    }
}
