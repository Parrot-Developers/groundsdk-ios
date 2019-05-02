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

import GroundSdk
import CoreLocation

/// Mock SystemLocationObserver
class MockSystemLocation: SystemLocationObserver {

    // init callBacks.
    // The utility will set later his own callbacks in these properties
    // see: `userLocationUtility = UserLocationCoreImpl(withCustomSystemLocationObserver: mockSystemLocation)` in
    // the setup() function
    var locationDidChange: (CLLocation) -> Void = {_ in }
    var authorizedDidChange: (Bool) -> Void = {_ in }
    var headingDidChange: (CLHeading) -> Void = {_ in }

    // two booleans in order to check if the mock location engine runs
    /// true if the location update system has been enabled
    var isRunningLocation = false
    /// true if the heading update system has been enabled
    var isRunningHeading = false

    var startLocationObserverCnt = 0
    var stopLocationObserverCnt = 0

    // SystemLocationObserver protocol
    func startLocationObserver() {
        if !isRunningLocation {
            isRunningLocation = true
            startLocationObserverCnt += 1
        }
    }
    func stopLocationObserver() {
        if isRunningLocation {
            isRunningLocation = false
            stopLocationObserverCnt += 1
        }
    }
    func startHeadingObserver() {
        isRunningHeading = true
    }
    func stopHeadingObserver() {
        isRunningHeading = false
    }

    // simulation of a system location event
    func simulEventLocation(location: CLLocation) {
        locationDidChange(location)
    }

    // simulation of a system "not authorized" event
    func simulEventLocationNotAuthorized(authorized: Bool) {
        authorizedDidChange(authorized)
    }

    // simulation of a system heading event
    func simulEventHeading(heading: CLHeading) {
        headingDidChange(heading)
    }

    func requestLocation() {
    }
}
