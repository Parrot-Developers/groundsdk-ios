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
import MapKit

class ReverseGeocoderUtilityCoreTests: XCTestCase {

    var  reverseGeocoderUtility: ReverseGeocoderUtilityCoreImpl!

    var changeCntPlacemark = 0

    var lastPlacemark: CLPlacemark?

    var monitorReverseGeocoder: MonitorCore?

    override func setUp() {
        super.setUp()
        reverseGeocoderUtility = ReverseGeocoderUtilityCoreImpl()
    }

    /// create and start a Monitor for ReverseGeocoder
    func startMonitorReverseGeocoder() {
        monitorReverseGeocoder =  reverseGeocoderUtility.startReverseGeocoderMonitoring(
            placemarkDidChange: { (placemark) in
                self.changeCntPlacemark += 1
                self.lastPlacemark = placemark
        })
    }

    /// free the Monitor
    func stopMonitorReverseGeocoder() {
        monitorReverseGeocoder?.stop()
        monitorReverseGeocoder = nil
        changeCntPlacemark = 0
    }

    func testInitialValue() {

        // monitor ReverseGeocoder
        startMonitorReverseGeocoder()

        // all values are updated when starting monitoring
        assertThat(lastPlacemark, nilValue())
    }

    func testPlacemarkUpdated() {

        // monitor ReverseGeocoder
        startMonitorReverseGeocoder()

        assertThat(changeCntPlacemark, equalTo(1))
        assertThat(lastPlacemark, nilValue())

        // Check that setting same value from low-level does not trigger the notification
        reverseGeocoderUtility.update(placemark: nil)
        assertThat(changeCntPlacemark, equalTo(1))
        assertThat(lastPlacemark, nilValue())

        // value change from low-level
        let coord2D = CLLocationCoordinate2D(latitude: 1.1, longitude: 2.2)
        let customPlacemark: CLPlacemark = MKPlacemark(coordinate: coord2D, addressDictionary: nil)
        reverseGeocoderUtility.update(placemark: customPlacemark)
        assertThat(changeCntPlacemark, equalTo(2))
        assertThat(lastPlacemark, presentAnd(`is`(placeLatitude: 1.1, placeLongitude: 2.2)))

        // stop and restart monitor
        stopMonitorReverseGeocoder()
        assertThat(changeCntPlacemark, equalTo(0))
        startMonitorReverseGeocoder()
        assertThat(changeCntPlacemark, equalTo(1))
        assertThat(lastPlacemark, presentAnd(`is`(placeLatitude: 1.1, placeLongitude: 2.2)))

        // value change from low-level
        let coord2D2 = CLLocationCoordinate2D(latitude: 3.3, longitude: 4.4)
        let customPlacemark2: CLPlacemark = MKPlacemark(coordinate: coord2D2, addressDictionary: nil)
        reverseGeocoderUtility.update(placemark: customPlacemark2)
        assertThat(changeCntPlacemark, equalTo(2))
        assertThat(lastPlacemark, presentAnd(`is`(placeLatitude: 3.3, placeLongitude: 4.4)))
    }
}
