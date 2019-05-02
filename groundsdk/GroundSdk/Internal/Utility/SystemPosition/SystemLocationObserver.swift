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
import CoreLocation

/// Interface for the Class using the Core Location services and able to provide the GPS coordinates of the device
/// as well as the magnetic heading.
public protocol SystemLocationObserver {

    /// The callback that should be called when the device Location changes
    var locationDidChange: (_ lastLocation: CLLocation) -> Void {get set}
    /// The callback that should be called when the authorization changes
    var authorizedDidChange: (_ authorized: Bool) -> Void {get set}
    /// The callback that should be called when the heading changes
    var headingDidChange: (_ heading: CLHeading) -> Void {get set}

    /// Starts the generation of updates that report the user’s current location.
    ///
    /// - Note: If the locationObserver is already started, this function does nothing.
    func startLocationObserver()

    /// Stops the generation of location updates.
    ///
    /// - Note: If the locationObserver is already stopped, this function does nothing.
    func stopLocationObserver()

    /// Starts the generation of updates that report the user’s magnetic heading
    ///
    /// - Note: If the headingObserver is already started, this function does nothing.
    func startHeadingObserver()

    /// Stops the generation of heading updates.
    ///
    /// - Note: If the headingObserver is already stopped, this function does nothing.
    func stopHeadingObserver()

    /// Requests the one-time delivery of the user’s current location.
    ///
    /// - Note: The CLLocationManager.requestLocation will be called. If GPS request is already started
    /// (see `startLocationObserver()`), this function does nothing.
    func requestLocation()

}

/// Class using the Core Location services and able to provide the GPS coordinates of the device as well
/// as the magnetic heading.
class SystemLocationObserverCore: NSObject, SystemLocationObserver {

    /// The callback that should be called when the device Location changes
    var locationDidChange: (_ lastLocation: CLLocation) -> Void
    /// The callback that should be called when the authorization changes
    var authorizedDidChange: (_ authorized: Bool) -> Void
    /// The callback that should be called when the heading changes
    var headingDidChange: (_ heading: CLHeading) -> Void

    /// Whether the system Location update has been requested
    private var locationUpdateRequested = false

    /// Whether the system Heading update has been requested
    private var headingUpdateRequested = false

    /// System Core Location services Manager
    private let locationManager = CLLocationManager()

    /// Constructor
    ///
    /// - Parameters:
    ///    - locationDidChange: the callback that should be called when the device Location changes
    ///    - authorizedDidChange: the callback that should be called when the device authorization changes
    ///    - headingDidChange: the callback that should be called when the heading changes
    required init(locationDidChange: @escaping (_ lastLocation: CLLocation) -> Void,
                  authorizedDidChange: @escaping (_ authorized: Bool) -> Void,
                  headingDidChange: @escaping (_ heading: CLHeading) -> Void) {
        self.locationDidChange = locationDidChange
        self.authorizedDidChange = authorizedDidChange
        self.headingDidChange = headingDidChange
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    }

    /// Starts the generation of updates that report the user’s current location.
    func startLocationObserver() {
        if !locationUpdateRequested {
            locationUpdateRequested = true
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
        }
    }

    /// Stops the generation of location updates.
    func stopLocationObserver() {
        if locationUpdateRequested {
            locationUpdateRequested = false
            locationManager.stopUpdatingLocation()
        }
    }

    /// Starts the generation of updates that report the user’s magnetic heading
    func startHeadingObserver() {
        if !headingUpdateRequested {
            headingUpdateRequested = true
            locationManager.startUpdatingHeading()
        }
    }

    /// Stops the generation of heading updates.
    func stopHeadingObserver() {
        if headingUpdateRequested {
            headingUpdateRequested = false
            locationManager.stopUpdatingHeading()
        }
    }

    func requestLocation() {
        // Checks that coninous updates are not active
        if !locationUpdateRequested {
            locationManager.requestWhenInUseAuthorization()
            locationManager.requestLocation()
        }
    }
}

// MARK: CLLocationManagerDelegate
extension SystemLocationObserverCore: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // keeps the last location
        if let lastLocation = locations.last {
            locationDidChange(lastLocation)
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        let authorized = (status == .authorizedAlways || status == .authorizedWhenInUse)
        authorizedDidChange(authorized)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
        headingDidChange(heading)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError: Error) {
        // nothing to do
    }
}
