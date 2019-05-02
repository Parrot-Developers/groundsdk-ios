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
import MapKit
import Contacts

class MockReverseGeocoder: ReverseGeocoderUtilityCore {
    let desc: UtilityCoreDescriptor = Utilities.reverseGeocoder

    var placemark: CLPlacemark? {
        didSet {
            monitors.forEach { $0.placemarkDidChange?(placemark) }
        }
    }

    private var monitors = Set<ReverseGeocoderMonitor>()

    func startReverseGeocoderMonitoring(placemarkDidChange: @escaping (CLPlacemark?) -> Void) -> MonitorCore {
        let monitor = ReverseGeocoderMonitor(monitorable: self, placemarkDidChange: placemarkDidChange)
        monitors.insert(monitor)
        // call callBacks for initializing values
        monitor.placemarkDidChange?(placemark)
        return monitor
    }

    private class ReverseGeocoderMonitor: NSObject, MonitorCore {
        fileprivate var placemarkDidChange: ((CLPlacemark?) -> Void)?
        private let monitorable: MockReverseGeocoder

        fileprivate init(monitorable: MockReverseGeocoder,
                         placemarkDidChange: @escaping (CLPlacemark?) -> Void) {
            self.monitorable = monitorable
            self.placemarkDidChange = placemarkDidChange
        }

        public func stop() {
            placemarkDidChange = nil
            monitorable.monitors.remove(self)
        }
    }

    static var fr: CLPlacemark {
        let coordinate = CLLocationCoordinate2D(latitude: 48.878974, longitude: 2.367566)
        let addr = CNMutablePostalAddress()
        addr.isoCountryCode = "fr"
        return MKPlacemark(coordinate: coordinate, postalAddress: addr)
    }

    static var us: CLPlacemark {
        let coordinate = CLLocationCoordinate2D(latitude: 37.3314, longitude: -121.9818)
        let addr = CNMutablePostalAddress()
        addr.isoCountryCode = "us"
        return MKPlacemark(coordinate: coordinate, postalAddress: addr)
    }
}
