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

func `is`(latitude: Double,
          longitude: Double,
          altitude: Double,
          orientation: OrientationDirective) -> Matcher<LocationDirective> {

    return allOf(
        Matcher<LocationDirective>("latitude: (\(latitude)") { $0.latitude == latitude },
        Matcher<LocationDirective>("longitude: (\(longitude)") { $0.longitude == longitude },
        Matcher<LocationDirective>("altitude: (\(altitude)") { $0.altitude == altitude },
        Matcher<LocationDirective>("orientation: (\(orientation)") { $0.orientation == orientation }
    )
}

func `is`(forwardComponent: Double, rightComponent: Double, downwardComponent: Double,
          headingRotation: Double) -> Matcher<RelativeMoveDirective> {

    return allOf(
        Matcher<RelativeMoveDirective>("forwardComponent: (\(forwardComponent)") {
            $0.forwardComponent == forwardComponent
        },
        Matcher<RelativeMoveDirective>("rightComponent: (\(rightComponent)") {
            $0.rightComponent == rightComponent
        },

        Matcher<RelativeMoveDirective>("downwardComponent: (\(downwardComponent)") {
            $0.downwardComponent == downwardComponent
        },
        Matcher<RelativeMoveDirective>("headingRotation: (\(headingRotation)") {
            $0.headingRotation == headingRotation
        }
    )
}

func `is`(latitude: Double, longitude: Double, altitude: Double, orientation: OrientationDirective,
          wasSuccessful: Bool) -> Matcher<FinishedLocationFlightInfo> {

    return allOf(
        Matcher<FinishedLocationFlightInfo>("latitude: (\(latitude)") { $0.directive.latitude == latitude },
        Matcher<FinishedLocationFlightInfo>("longitude: (\(longitude)") { $0.directive.longitude == longitude },
        Matcher<FinishedLocationFlightInfo>("altitude: (\(altitude)") { $0.directive.altitude == altitude },
        Matcher<FinishedLocationFlightInfo>("orientation: (\(orientation)") { $0.directive.orientation == orientation },
        Matcher<FinishedLocationFlightInfo>("wasSuccessful: (\(wasSuccessful)") {$0.wasSuccessful == wasSuccessful }
    )
}

func `is`(wasSuccessful: Bool, directive: RelativeMoveDirective?, actualForwardComponent: Double,
          actualRightComponent: Double, actualDownwardComponent: Double,
          actualHeadingRotation: Double) -> Matcher<FinishedRelativeMoveFlightInfo> {

    return allOf(
        Matcher<FinishedRelativeMoveFlightInfo>(
            "directive.forwardComponent: (\(String(describing: directive?.forwardComponent))") {
                $0.directive?.forwardComponent == directive?.forwardComponent
        },
        Matcher<FinishedRelativeMoveFlightInfo>(
            "directive.rightComponent: (\(String(describing: directive?.rightComponent))") {
                $0.directive?.rightComponent == directive?.rightComponent
        },
        Matcher<FinishedRelativeMoveFlightInfo>(
            "directive.downwardComponent: (\(String(describing: directive?.downwardComponent))") {
                $0.directive?.downwardComponent == directive?.downwardComponent
        },
        Matcher<FinishedRelativeMoveFlightInfo>(
            "directive.headingRotation: (\(String(describing: directive?.headingRotation))") {
                $0.directive?.headingRotation == directive?.headingRotation
        },
        Matcher<FinishedRelativeMoveFlightInfo>("actualForwardComponent: (\(actualForwardComponent)") {
            $0.actualForwardComponent == actualForwardComponent
        },
        Matcher<FinishedRelativeMoveFlightInfo>("actualRightComponent: (\(actualRightComponent)") {
            $0.actualRightComponent == actualRightComponent
        },
        Matcher<FinishedRelativeMoveFlightInfo>("actualDownwardComponent: (\(actualDownwardComponent)") {
            $0.actualDownwardComponent == actualDownwardComponent
        },
        Matcher<FinishedRelativeMoveFlightInfo>("actualHeadingRotation: (\(actualHeadingRotation)") {
            $0.actualHeadingRotation == actualHeadingRotation
        },
        Matcher<FinishedRelativeMoveFlightInfo>("wasSuccessful: (\(wasSuccessful)") {$0.wasSuccessful == wasSuccessful }
    )
}


