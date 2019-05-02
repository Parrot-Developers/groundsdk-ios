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

import XCTest
import CoreLocation
@testable import GroundSdk

/// Test UserLocation facility
class UserLocationTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: UserLocationCore!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        impl = UserLocationCore(store: store)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Facilities.userLocation), present())
        impl.unpublish()
        assertThat(store!.get(Facilities.userLocation), nilValue())
    }

    func testLocationUpdateStopped() {
        impl.publish()
        var cnt = 0
        let userLocation = store.get(Facilities.userLocation)!
        _ = store.register(desc: Facilities.userLocation) {
            cnt += 1
        }

        // test initial value
        assertThat(userLocation.stopped, `is`(false))

        // Check that setting same value from low-level does not trigger the notification
        impl.update(stopped: false).notifyUpdated()
        assertThat(userLocation.stopped, `is`(false))
        assertThat(cnt, `is`(0))

        // mock value change from low-level
        impl.update(stopped: true).notifyUpdated()
        assertThat(userLocation.stopped, `is`(true))
        assertThat(cnt, `is`(1))
    }

    func testDeviceLocationAuthorized() {
        impl.publish()
        var cnt = 0
        let userLocation = store.get(Facilities.userLocation)!
        _ = store.register(desc: Facilities.userLocation) {
            cnt += 1
        }

        // test initial value
        assertThat(userLocation.authorized, `is`(false))

        // Check that setting same value from low-level does not trigger the notification
        impl.update(authorized: false).notifyUpdated()
        assertThat(userLocation.authorized, `is`(false))
        assertThat(cnt, `is`(0))

        // mock value change from low-level
        impl.update(authorized: true).notifyUpdated()
        assertThat(userLocation.authorized, `is`(true))
        assertThat(cnt, `is`(1))
    }

    func testUserLocation() {
        impl.publish()
        var cnt = 0
        let userLocation = store.get(Facilities.userLocation)!
        _ = store.register(desc: Facilities.userLocation) {
            cnt += 1
        }

        // test initial value
        assertThat(userLocation.location, nilValue())

        // Check that setting same value from low-level does not trigger the notification
        impl.update(userLocation: nil).notifyUpdated()
        assertThat(userLocation.location, nilValue())
        assertThat(cnt, `is`(0))

        // mock value change from low-level
        let coord2D = CLLocationCoordinate2D(latitude: 1.1, longitude: 2.2)
        let timeStampDate = Date()
        let testLocation = CLLocation(coordinate: coord2D, altitude: 3.3, horizontalAccuracy: 4.4,
                                      verticalAccuracy: 5.5, course: 0, speed: 6.6, timestamp: timeStampDate)
        impl.update(userLocation: testLocation).notifyUpdated()
        assertThat(userLocation.location, presentAnd(
            `is`(latitude: 1.1, longitude: 2.2, altitude: 3.3, hAcc: 4.4, vAcc: 5.5, date: timeStampDate)))
        assertThat(cnt, `is`(1))
    }
}
