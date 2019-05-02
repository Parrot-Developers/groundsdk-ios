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

/// Enum to describe the origin of the location used for reverse geocoding
private enum LocationOrigin: String {
    case systemPositionUtility
    case other
}

/// Class used to store the reverse geolocalization informations
private class Placemark: CustomStringConvertible {
    /// Keys for NSCoding
    private enum PlacemarkKeys: String {
        case placemark
        case locationOrigin
        case timeStamp
    }

    /// Placemark (result of the reverse gecoding)
    fileprivate let placemark: CLPlacemark
    /// Origin of the location
    fileprivate let locationOrigin: LocationOrigin
    /// Date of the reverseCoding request
    fileprivate let timeStamp: Date

    /// Constructor for the Placemark
    ///
    /// - Parameters:
    ///   - placemark: result of the reverse Geocoding
    ///   - origin: the origin of the location
    ///   - timeStamp: date of the geolocation result
    fileprivate init(placemark: CLPlacemark, origin: LocationOrigin, timeStamp: Date) {
        self.placemark = placemark
        self.locationOrigin = origin
        self.timeStamp = timeStamp
    }

    /// Constructor with property list. Used with the result of a GroundSdkUserDefaults.loadData()
    ///
    /// - Parameter propertyList: property list
    /// - Returns: failable, return `nil` if the if the property list is incorrect
    fileprivate convenience init?(propertyList: [String: Any]) {
        do {
            let locationOriginString = propertyList[PlacemarkKeys.locationOrigin.rawValue] as? String
            if let placeData = propertyList[PlacemarkKeys.placemark.rawValue] as? Data,
                let placemark = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(placeData) as? CLPlacemark,
                let timeStamp = propertyList[PlacemarkKeys.timeStamp.rawValue] as? Date,
                let locationOrigin = LocationOrigin(rawValue: locationOriginString ?? "" ) {
                self.init(placemark: placemark, origin: locationOrigin, timeStamp: timeStamp)
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }

    /// Get the Placemak as a property list
    ///
    /// - Returns: property list
    fileprivate func asPropertyList() -> [String: Any] {
        return [PlacemarkKeys.placemark.rawValue: NSKeyedArchiver.archivedData(withRootObject: placemark),
                PlacemarkKeys.locationOrigin.rawValue: locationOrigin.rawValue,
                PlacemarkKeys.timeStamp.rawValue: timeStamp]
    }

    /// Debug description.
    public var description: String {
        return "Placemark: placemark = \(placemark), locationOrigin = \(locationOrigin.rawValue)" +
        ", timeStamp = = \(timeStamp))"
    }
}

/// Class to store the location which will be used for the reverse geolocalization
private class Location: CustomStringConvertible {
    /// Keys for NSCoding
    private enum LocationKeys: String {
        case location
        case locationOrigin
    }

    /// Location which will be used to get the placemark
    fileprivate let location: CLLocation
    /// Origin of the location
    fileprivate let locationOrigin: LocationOrigin

    /// Constructor for the Location
    ///
    /// - Parameters:
    ///   - location: location which will be used to get the placemark
    ///   - origin: the origin of the location
    fileprivate init(location: CLLocation, origin: LocationOrigin) {
        self.location = location
        self.locationOrigin = origin
    }

    /// Constructor with property list. Used with the result of a GroundSdkUserDefaults.loadData()
    ///
    /// - Parameter propertyList: property list
    /// - Returns: failable, return `nil` if the if the property list is incorrect
    fileprivate convenience init?(propertyList: [String: Any]) {
        do {
            let locationOriginString = propertyList[LocationKeys.locationOrigin.rawValue] as? String
            if let locData = propertyList[LocationKeys.location.rawValue] as? Data,
                let location = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locData) as? CLLocation,
                let locationOrigin = LocationOrigin(rawValue: locationOriginString ?? "" ) {
                self.init(location: location, origin: locationOrigin)
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }

    /// Get the Location as a property list
    ///
    /// - Returns: property list
    fileprivate func asPropertyList() -> [String: Any] {
        return [LocationKeys.location.rawValue: NSKeyedArchiver.archivedData(withRootObject: location),
                LocationKeys.locationOrigin.rawValue: locationOrigin.rawValue]
    }
    /// Debug description.
    public var description: String {
        return "Location: location = \(location)), locationOrigin = \(locationOrigin.rawValue))"
    }
}

/// Engine providing reverse geocoding information.
/// The engine publishes the ReverseGeocoder utility and Facility
class ReverseGeocoderEngine: EngineBaseCore {

    /// Key used in UserDefaults dictionary
    private let storeDataKey = "reverseGeocoderEngine"

    /// Minimum distance (in meters) required for a location to be valid (distance compared to the previous location)
    private let MinimumDistanceMeter = CLLocationDistance(3000)

    /// Time Interval at which a new location is requested (in sec.)
    private let RequestLocationInterval = 600.0

    /// Waiting Interval, when a gecoding request fails, before to retry the request (in sec.)
    private let WaitingGeocodingErrorInterval = 60.0

    /// Timer for schedule a new location request
    private var checkLocationTimer: Timer? {
        willSet {
            // ensure that current timer is invalidated before assigning new instance or nil
            self.checkLocationTimer?.invalidate()
        }
    }

    /// Timer for retry a failed gecoding request
    private var errorRequestTimer: Timer? {
        willSet {
            // ensure that current timer is invalidated before assigning new instance or nil
            self.errorRequestTimer?.invalidate()
        }
    }

    /// Count successives error of the reverse geocoding request (after 3 errors we give up the location)
    private var errorGecodingRequestCount = 0

    /// Possible location, candidate for geolocalisation
    private var location: Location?

    /// The last location successfully localized
    private var placemark: Placemark?

    /// ReverseGeocoder facility (published in this Engine)
    private let reverseGeocoder: ReverseGeocoderCore

    /// ReverseGeocoder utility (published in this Engine)
    private let reverseGeocoderUtilityCoreImpl: ReverseGeocoderUtilityCoreImpl

    /// System Position utility (used to get a GPS position)
    private var systemPositionCore: SystemPositionCore?
    private var systemPositionMonitor: MonitorCore?

    /// InternetConnectivity Utility (monitored, to perform reverse geocoding requests when internet is available)
    private var internetConnectivityCore: InternetConnectivityCore?
    private var internetConnectivityMonitor: MonitorCore?

    /// Constructor
    ///
    /// - Parameter enginesController: engines controller
    public required init(enginesController: EnginesControllerCore) {
        // init facilities : ReverseGeocoder
        reverseGeocoder = ReverseGeocoderCore(store: enginesController.facilityStore)
        // init utilities
        reverseGeocoderUtilityCoreImpl = ReverseGeocoderUtilityCoreImpl()
        super.init(enginesController: enginesController)
        // reload persisting Datas
        loadData()
        ULog.d(.reverseGeocoderEngineTag, "Loading ReverseGeocoderEngine.")
        publishMonitorable()
    }

    /// Creates and publishes all available monitorable utilities.
    ///
    /// Only visible for tests purposes.
    func publishMonitorable() {
        publishUtility(reverseGeocoderUtilityCoreImpl)
    }

    public override func startEngine() {
        ULog.d(.reverseGeocoderEngineTag, "Starting MonitorEngine.")
        // publish facilities
        reverseGeocoder.publish()
        // start the reverseGeocoding system
        startReverseGeocoding()
    }

    public override func stopEngine() {
        ULog.d(.reverseGeocoderEngineTag, "Stopping MonitorEngine.")
        stopReverseGeocoding()
        // unpublish facilities
        reverseGeocoder.unpublish()
    }

    private func startReverseGeocoding() {
        // update values in Utility and Facility
        updateFacilityAndUtility()

        // monitor internet connectivity
        internetConnectivityCore = utilities.getUtility(Utilities.internetConnectivity)
        internetConnectivityMonitor = internetConnectivityCore?.startMonitoring(with: { [unowned self] available in
            if available {
                self.errorGecodingRequestCount = 0
                self.reverseGeocondingLocation()
            }
        })

        // get the system position utility
        systemPositionCore = utilities.getUtility(Utilities.systemPosition)
        systemPositionMonitor = systemPositionCore?.startLocationMonitoring(
            passive: true, userLocationDidChange: { [unowned self] newLocation in
                if let newLocation = newLocation {
                    self.tryToAddNewLocation(newLocation: newLocation, locationOrigin: .systemPositionUtility)
                }
            },
            stoppedDidChange: {_ in },
            authorizedDidChange: {[unowned self] newAuthorized in
                if newAuthorized {
                    // When starting a new app, the authorization is asked to the user. If the user agrees the
                    // used of localization services, it's can take a long time to wait the timer
                    // (see: `newLocationScheduledRequest()`). So, we force a new location request at this moment
                    self.newLocationScheduledRequest()
                }
        })

        // auto update the location every `RequestLocationInterval` seconds
        newLocationScheduledRequest()
        checkLocationTimer = Timer.scheduledTimer(
            timeInterval: RequestLocationInterval, target: self, selector: #selector(newLocationScheduledRequest),
            userInfo: nil, repeats: true)
    }

    private func stopReverseGeocoding() {
        checkLocationTimer = nil
        errorRequestTimer = nil
        systemPositionMonitor?.stop()
        systemPositionMonitor = nil
        internetConnectivityMonitor?.stop()
        internetConnectivityMonitor = nil
    }

    /// Periodic check in order to obtain a new location.
    @objc
    private func newLocationScheduledRequest() {
        systemPositionCore?.requestOneLocation()
    }

    /// Updates the reverseGeocoder utility and facility
    private func updateFacilityAndUtility() {
        // Update the Utility
        reverseGeocoderUtilityCoreImpl.update(placemark: placemark?.placemark)
        // Update the Facility
        reverseGeocoder.update(placemark: placemark?.placemark).notifyUpdated()
    }

    /// Test if the new position is far enough from the previous location. If YES, add this
    /// "candidate location" for a future reverseGeoconding
    ///
    /// - Parameters:
    ///   - newLocation: the location to be tested and possibly valid for geocoding
    ///   - locationOrigin: the origin of the location
    private func tryToAddNewLocation(newLocation: CLLocation, locationOrigin: LocationOrigin) {
        var addThisLocation = false
        // find a known position in order to compare distance
        // if there is no previous location, we use the "geolocalized" position if exists
        if let precedLocation = ((location != nil) ? location!.location : placemark?.placemark.location) {
            let distanceMeter = precedLocation.distance(from: newLocation)
            addThisLocation = (distanceMeter >= MinimumDistanceMeter)
        } else {
            // this is the first location we have
            addThisLocation = true
        }

        if addThisLocation {
            location = Location(location: newLocation, origin: locationOrigin)
            // save persisting data
            saveData()
            errorGecodingRequestCount = 0
            reverseGeocondingLocation()
        }
    }

    /// Reverse Geocoding the candidate `self.location`. This function checks if we have a location and if internet
    /// is available.
    @objc
    private func reverseGeocondingLocation() {
        errorRequestTimer = nil
        // do nothing if we have no candidate location or if internet is not available
        if let location = location, internetConnectivityCore?.internetAvailable == true {
            let origin = location.locationOrigin
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(
                location.location, completionHandler: { [weak self] placemarks, error in
                    if let this = self {
                        if error != nil {
                            // Error, we try an other request later (max 3 times)
                            this.errorGecodingRequestCount += 1
                            if this.errorGecodingRequestCount > 3 {
                                // cancel this location (after 3 errors)
                                this.location = nil
                                this.saveData()
                            } else {
                                // try later
                                this.errorRequestTimer = Timer.scheduledTimer(
                                    timeInterval: this.WaitingGeocodingErrorInterval, target: this,
                                    selector: #selector(this.reverseGeocondingLocation), userInfo: nil, repeats: false)
                            }
                        } else {
                            // No Error
                            if let placemark = placemarks?.first {
                                // New Placemark
                                this.placemark = Placemark(
                                    placemark: placemark, origin: origin, timeStamp: Date())
                                this.updateFacilityAndUtility()
                            }
                            this.location = nil
                            this.errorGecodingRequestCount = 0
                            this.saveData()
                        }
                    }
            })
        }
    }
}

// MARK: - loading and saving persisting data
extension ReverseGeocoderEngine {

    private enum PersistingDataKeys: String {
        case locationData
        case placemarkData
    }

    /// Save persisting data
    private func saveData() {
        let savedDictionary = [
            PersistingDataKeys.placemarkData.rawValue: placemark?.asPropertyList(),
            PersistingDataKeys.locationData.rawValue: location?.asPropertyList()].filter { $0.value != nil }
        GroundSdkUserDefaults(storeDataKey).storeData(savedDictionary)
    }

    /// Load persisting data
    private func loadData() {
        let loadedDictionary = GroundSdkUserDefaults(storeDataKey).loadData() as? [String: Any]
        if let placemarkProperties = loadedDictionary?[PersistingDataKeys.placemarkData.rawValue] as? [String: Any] {
            placemark = Placemark(propertyList: placemarkProperties)
        } else {
            placemark = nil
        }
        if let locationProperties = loadedDictionary?[PersistingDataKeys.locationData.rawValue] as? [String: Any] {
            location = Location(propertyList: locationProperties)
        } else {
            location = nil
        }
    }
}
