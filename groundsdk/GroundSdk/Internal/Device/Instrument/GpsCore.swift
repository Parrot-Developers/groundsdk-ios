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

/// Internal Gps instrument implementation
public class GpsCore: InstrumentCore, Gps {

    /// Fix status, true if gps of the drone has fixed
    private (set) public var fixed = false

    /// Location latitude (in degrees)
    /// 500 if not known
    private var latitude: Double?

    /// Location longitude (in degrees)
    /// 500 if not known
    private var longitude: Double?

    /// Time of the latest location update.
    private var timestamp: Date!

    /// Location altitude (in meters, above sea level)
    /// 0 if not known
    private var altitude: Double?

    /// Horizontal accuracy (in meter)
    /// -1 if not known.
    private var horizontalAccuracy: Double = -1

    /// Vertical accuracy (in meter)
    /// -1 if not known.
    private var verticalAccuracy: Double = -1

    /// Number of satellite used to get the location
    private(set) public var satelliteCount = 0

    /// last known GPS location if available, nil otherwise
    public var lastKnownLocation: CLLocation? {
        if let latitude = latitude, let longitude = longitude {
            let coord = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let altitudeVal = (altitude != nil) ? altitude! : 0
            return CLLocation(coordinate: coord, altitude: altitudeVal, horizontalAccuracy: horizontalAccuracy,
                              verticalAccuracy: verticalAccuracy, timestamp: timestamp)
        }
        return nil
    }

    /// Debug description
    public override var description: String {
        return "GpsCore: fixed = \(fixed), position( \(String(describing: latitude)), " +
            "\(String(describing: longitude)), \(String(describing: altitude))) " +
            "( +/-(\(horizontalAccuracy), \(verticalAccuracy) "
    }

    /// Constructor
    ///
    /// - Parameter store: component store owning this component
    public init(store: ComponentStoreCore) {
        super.init(desc: Instruments.gps, store: store)
    }
}

/// Backend callback methods
extension GpsCore {

    /// Changes the fixed value.
    ///
    /// - Parameter fixed: Whether drone's gps has fixed or not
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(fixed newValue: Bool) -> GpsCore {
        if fixed != newValue {
            markChanged()
            fixed = newValue
        }
        return self
    }

    /// Updates the latitude, longitude, altitude and date of the location values.
    ///
    /// - Parameters:
    ///   - latitude: the latitude to set
    ///   - longitude: the longitude to set
    ///   - altitude: the altitude to set
    ///   - date: the date of the location to set
    /// - Returns: self to allow call chaining
    ///
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        latitude lat: Double, longitude lng: Double, altitude alt: Double, date: Date) -> GpsCore {

        if latitude != lat || longitude != lng || altitude != alt {
            markChanged()
            latitude = lat
            longitude = lng
            altitude = alt
            timestamp = date
        }
        return self
    }

    /// Changes the horizontal accuracy value.
    ///
    /// - Parameter horizontalAccuracy: the horizontal accuracy to set
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(horizontalAccuracy newValue: Double) -> GpsCore {
        if horizontalAccuracy != newValue {
            markChanged()
            horizontalAccuracy = newValue
        }
        return self
    }

    /// Changes the vertical accuracy value.
    ///
    /// - Parameter verticalAccuracy: the vertical accuracy to set
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(verticalAccuracy newValue: Double) -> GpsCore {
        if verticalAccuracy != newValue {
            markChanged()
            verticalAccuracy = newValue
        }
        return self
    }

    /// Changes the satellite count value.
    ///
    /// - Parameter satelliteCount: the satellite count to set
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(satelliteCount newValue: Int) -> GpsCore {
        if satelliteCount != newValue {
            markChanged()
            satelliteCount = newValue
        }
        return self
    }
}
