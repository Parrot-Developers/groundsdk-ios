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
@testable import GroundSdkMock
@testable import GroundSdk
import CoreLocation

class UserLocationCoreTests: XCTestCase {

    var mockSystemLocation: MockSystemLocationObserver!
    var userLocationUtility: SystemPositionCoreImpl!

    var changeCntHeading = 0
    var changeCntLocation = 0
    var changeCntStopped = 0
    var changeCntAuthorized = 0

    var lastHeading: CLHeading?
    var lastLocation: CLLocation?
    var currentStopped = false
    var currentAuthorized = false

    var monitorHeading: MonitorCore?
    var monitorGps: MonitorCore?

    override func setUp() {
        super.setUp()
        // create a Utility with a Mock System Location
        mockSystemLocation =  MockSystemLocationObserver()
        userLocationUtility = SystemPositionCoreImpl(withCustomSystemLocationObserver: mockSystemLocation)
    }

    /// create and start a Monitor for Heading
    func startMonitorHeading() {
        monitorHeading = userLocationUtility.startHeadingMonitoring(headingDidChange: { (heading) in
            self.changeCntHeading += 1
            self.lastHeading = heading
        })
    }

    /// free the Heading Monitor
    func stopMonitorHeading() {
        monitorHeading?.stop()
    }

    /// create and start a Monitor for Location
    func startMonitorGps() {
        monitorGps = userLocationUtility.startLocationMonitoring(passive: false, userLocationDidChange: { (location) in
            self.changeCntLocation += 1
            self.lastLocation = location
        }, stoppedDidChange: { (stopped) in
            self.changeCntStopped += 1
            self.currentStopped = stopped
        }, authorizedDidChange: { (authorized) in
            self.changeCntAuthorized += 1
            self.currentAuthorized = authorized
        })
    }

    /// free the Location Monitor
    func stopMonitorGps() {
        monitorGps?.stop()
    }

    func testInitialValue() {

        // monitor GPS and HEADING
        startMonitorGps()
        startMonitorHeading()

        // all values are updated when starting monitoring
        assertThat(changeCntHeading, equalTo(1))
        assertThat(changeCntLocation, equalTo(1))
        assertThat(changeCntStopped, equalTo(1))
        assertThat(changeCntAuthorized, equalTo(1))

        assertThat(lastLocation, nilValue())
        assertThat(lastHeading, nilValue())
        assertThat(currentStopped, `is`(false))
        assertThat(currentAuthorized, `is`(false))
    }

    func testSuspendExternalRequest() {

        // monitor GPS and HEADING
        startMonitorGps()
        startMonitorHeading()
        assertThat(changeCntStopped, equalTo(1))
        assertThat(currentStopped, `is`(false))

        userLocationUtility.requestSuspendUpdating()
        assertThat(changeCntStopped, equalTo(2))
        assertThat(currentStopped, `is`(true))

        // add more suspend request" (3 more requests)
        userLocationUtility.requestSuspendUpdating()
        userLocationUtility.requestSuspendUpdating()
        userLocationUtility.requestSuspendUpdating()

        // no change
        assertThat(changeCntStopped, equalTo(2))
        assertThat(currentStopped, `is`(true))

        // remove "suspend request" but keep one
        userLocationUtility.unrequestSuspendUpdating()
        userLocationUtility.unrequestSuspendUpdating()
        userLocationUtility.unrequestSuspendUpdating()

        // no change
        assertThat(changeCntStopped, equalTo(2))
        assertThat(currentStopped, `is`(true))
        // remove the last
        userLocationUtility.unrequestSuspendUpdating()
        assertThat(changeCntStopped, equalTo(3))
        assertThat(currentStopped, `is`(false))

        // other values are not updated
        assertThat(changeCntHeading, equalTo(1))
        assertThat(changeCntLocation, equalTo(1))
        assertThat(changeCntAuthorized, equalTo(1))
    }

    func testForceAndSuspendExternalRequest() {

        // monitor GPS and HEADING
        startMonitorGps()
        startMonitorHeading()

        userLocationUtility.requestSuspendUpdating()
        assertThat(changeCntStopped, equalTo(2))
        assertThat(currentStopped, `is`(true))
        // we are suspended : 1, Force : 0
        assertThat(mockSystemLocation.isRunningHeading, `is`(true))
        assertThat(mockSystemLocation.isRunningLocation, `is`(false))

        userLocationUtility.forceUpdating()
        assertThat(changeCntStopped, equalTo(3))
        assertThat(currentStopped, `is`(false))
        // we are suspended : 1, Force : 1
        assertThat(mockSystemLocation.isRunningHeading, `is`(true))
        assertThat(mockSystemLocation.isRunningLocation, `is`(true))

        // add one more suspend request"
        userLocationUtility.requestSuspendUpdating()
        assertThat(changeCntStopped, equalTo(3))
        assertThat(currentStopped, `is`(false))
        // we are suspended : 2, Force : 1
        assertThat(mockSystemLocation.isRunningHeading, `is`(true))
        assertThat(mockSystemLocation.isRunningLocation, `is`(true))

        // remove the force request
        userLocationUtility.stopForceUpdating()
        assertThat(changeCntStopped, equalTo(4))
        assertThat(currentStopped, `is`(true))
        // we are suspended : 2, Force : 0
        assertThat(mockSystemLocation.isRunningHeading, `is`(true))
        assertThat(mockSystemLocation.isRunningLocation, `is`(false))

        // add 2 force
        userLocationUtility.forceUpdating()
        assertThat(changeCntStopped, equalTo(5))
        assertThat(currentStopped, `is`(false))
        userLocationUtility.forceUpdating()
        assertThat(changeCntStopped, equalTo(5))
        assertThat(currentStopped, `is`(false))
        // we are suspended : 2, Force : 2
        assertThat(mockSystemLocation.isRunningHeading, `is`(true))
        assertThat(mockSystemLocation.isRunningLocation, `is`(true))

        // remove one suspend and one force (no change)
        userLocationUtility.stopForceUpdating()
        userLocationUtility.unrequestSuspendUpdating()
        assertThat(changeCntStopped, equalTo(5))
        assertThat(currentStopped, `is`(false))
        // we are suspended : 1, Force : 1
        assertThat(mockSystemLocation.isRunningHeading, `is`(true))
        assertThat(mockSystemLocation.isRunningLocation, `is`(true))

        // remove the last suspend
        userLocationUtility.unrequestSuspendUpdating()
        assertThat(changeCntStopped, equalTo(5))
        assertThat(currentStopped, `is`(false))
        // we are suspended : 0, Force : 1
        assertThat(mockSystemLocation.isRunningHeading, `is`(true))
        assertThat(mockSystemLocation.isRunningLocation, `is`(true))

        // remove the last force
        userLocationUtility.stopForceUpdating()
        assertThat(changeCntStopped, equalTo(5))
        assertThat(currentStopped, `is`(false))
        // we are suspended : 0, Force : 0
        assertThat(mockSystemLocation.isRunningHeading, `is`(true))
        assertThat(mockSystemLocation.isRunningLocation, `is`(true))

        // check that the location system is stopped without monitoring
        stopMonitorHeading()
        assertThat(mockSystemLocation.isRunningHeading, `is`(false))
        assertThat(mockSystemLocation.isRunningLocation, `is`(true))

        // check that the location system is stopped without monitoring
        stopMonitorGps()
        assertThat(mockSystemLocation.isRunningHeading, `is`(false))
        assertThat(mockSystemLocation.isRunningLocation, `is`(false))

        // other values are not updated
        assertThat(changeCntHeading, equalTo(1))
        assertThat(changeCntLocation, equalTo(1))
        assertThat(changeCntAuthorized, equalTo(1))
    }

    func testLocationUpdated() {

        // monitor GPS
        self.startMonitorGps()

        assertThat(changeCntLocation, equalTo(1))
        assertThat(lastLocation, nilValue())

        let coord2D = CLLocationCoordinate2D(latitude: 1.1, longitude: 2.2)
        let timeStampDate = Date()
        let testLocation = CLLocation(coordinate: coord2D, altitude: 3.3, horizontalAccuracy: 4.4,
                                      verticalAccuracy: 5.5, course: 0, speed: 6.6, timestamp: timeStampDate)

        let coord2D2 = CLLocationCoordinate2D(latitude: 21.1, longitude: 22.2)
        let timeStampDate2 = Date()
        let testLocation2 = CLLocation(coordinate: coord2D2, altitude: 23.3, horizontalAccuracy: 24.4,
                                       verticalAccuracy: 25.5, course: 20, speed: 26.6, timestamp: timeStampDate2)

        mockSystemLocation.simulEventLocation(location: testLocation)

        assertThat(lastLocation, presentAnd(
            `is`(latitude: 1.1, longitude: 2.2, altitude: 3.3, hAcc: 4.4, vAcc: 5.5, date: timeStampDate)))
        assertThat(changeCntLocation, equalTo(2))

        mockSystemLocation.simulEventLocation(location: testLocation2)
        assertThat(lastLocation, presentAnd(
            `is`(latitude: 21.1, longitude: 22.2, altitude: 23.3, hAcc: 24.4, vAcc: 25.5, date: timeStampDate2)))
        assertThat(changeCntLocation, equalTo(3))
    }

    func testAuthorized() {

        // set "authorized = yes" as starting condition
        mockSystemLocation.simulEventLocationNotAuthorized(authorized: true)

        // start monitor GPS
        startMonitorGps()

        assertThat(mockSystemLocation.isRunningHeading, `is`(false))
        assertThat(mockSystemLocation.isRunningLocation, `is`(true))
        assertThat(changeCntLocation, equalTo(1)) // the initial value
        assertThat(lastLocation, nilValue())
        assertThat(changeCntAuthorized, equalTo(1)) // the initial value
        assertThat(currentAuthorized, `is`(true))

        // simul a event location
        let coord2D = CLLocationCoordinate2D(latitude: 1.1, longitude: 2.2)
        let timeStampDate = Date()
        let testLocation = CLLocation(coordinate: coord2D, altitude: 3.3, horizontalAccuracy: 4.4,
                                      verticalAccuracy: 5.5, course: 0, speed: 6.6, timestamp: timeStampDate)

        mockSystemLocation.simulEventLocation(location: testLocation)
        assertThat(lastLocation, presentAnd(
            `is`(latitude: 1.1, longitude: 2.2, altitude: 3.3, hAcc: 4.4, vAcc: 5.5, date: timeStampDate)))
        assertThat(changeCntLocation, equalTo(2))

        // simul a "non authorized" Event
        mockSystemLocation.simulEventLocationNotAuthorized(authorized: false)
        assertThat(lastLocation, nilValue())
        assertThat(changeCntLocation, equalTo(3))
        assertThat(changeCntAuthorized, equalTo(2))
        assertThat(currentAuthorized, `is`(false))

        // go back "authorized == true"
        mockSystemLocation.simulEventLocationNotAuthorized(authorized: true)
        assertThat(changeCntAuthorized, equalTo(3))
        assertThat(currentAuthorized, `is`(true))

        // event location
        let coord2D2 = CLLocationCoordinate2D(latitude: 21.1, longitude: 22.2)
        let timeStampDate2 = Date()
        let testLocation2 = CLLocation(coordinate: coord2D2, altitude: 23.3, horizontalAccuracy: 24.4,
                                       verticalAccuracy: 25.5, course: 20, speed: 26.6, timestamp: timeStampDate2)

        mockSystemLocation.simulEventLocation(location: testLocation2)
        assertThat(lastLocation, presentAnd(
            `is`(latitude: 21.1, longitude: 22.2, altitude: 23.3, hAcc: 24.4, vAcc: 25.5, date: timeStampDate2)))
        assertThat(changeCntLocation, equalTo(4))

        // test the Utility's property
        assertThat(userLocationUtility.userLocation, presentAnd(
            `is`(latitude: 21.1, longitude: 22.2, altitude: 23.3, hAcc: 24.4, vAcc: 25.5, date: timeStampDate2)))
        assertThat(changeCntLocation, equalTo(4))
    }

    func testHeadingUpdated() {

        // monitor HEADING
        self.startMonitorHeading()

        assertThat(changeCntHeading, equalTo(1))
        assertThat(lastHeading, nilValue())

        // it is not possible to init a CLHeading in code with parameters
        let heading = CLHeading()

        mockSystemLocation.simulEventHeading(heading: heading)

        assertThat(changeCntHeading, equalTo(2))
        assertThat(lastHeading, present())

        assertThat(lastHeading == heading, `is`(true))
        // test the Utility's property
        assertThat(userLocationUtility.heading == heading, `is`(true))
    }

    func testUtilityPropertyLocation() {
        // without monitoring
        // - read the last Location
        let coord2D = CLLocationCoordinate2D(latitude: 1.1, longitude: 2.2)
        let timeStampDate = Date()
        let testLocation = CLLocation(coordinate: coord2D, altitude: 3.3, horizontalAccuracy: 4.4,
                                      verticalAccuracy: 5.5, course: 0, speed: 6.6, timestamp: timeStampDate)

        mockSystemLocation.simulEventLocation(location: testLocation)
        assertThat(lastLocation, nilValue()) // no monitoring

        // test the Utility's property
        assertThat(userLocationUtility.userLocation, presentAnd(
            `is`(latitude: 1.1, longitude: 2.2, altitude: 3.3, hAcc: 4.4, vAcc: 5.5, date: timeStampDate)))

        // run the location service without monitoring
        userLocationUtility.forceUpdating()
        // we are suspended : 0, Force : 1
        assertThat(mockSystemLocation.isRunningLocation, `is`(true))
    }
}

/// Mock SystemLocationObserver
class MockSystemLocationObserver: SystemLocationObserver {

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

    // SystemLocationObserver protocol
    func startLocationObserver() {
        isRunningLocation = true
    }
    func stopLocationObserver() {
        isRunningLocation = false
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
