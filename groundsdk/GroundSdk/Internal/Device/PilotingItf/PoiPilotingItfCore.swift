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

/// Implementation of PointOfInterest
public class PointOfInterestCore: PointOfInterest, Equatable {
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double
    /// Constructor
    ///
    /// - Parameters:
    ///   - latitude: Latitude of the location (in degrees) to look at.
    ///   - longitude: Longitude of the location (in degrees) to look at.
    ///   - altitude: Altitude above take off point (in meters) to look at.
    public init(latitude: Double, longitude: Double, altitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
    }
    // MARK: Equatable protocol concordance
    public static func == (lhs: PointOfInterestCore, rhs: PointOfInterestCore) -> Bool {
        return (lhs.latitude == rhs.latitude) && (lhs.longitude == rhs.longitude) && (lhs.altitude == rhs.altitude)
    }
}

/// PoiPilotingItf backend protocol
public protocol PoiPilotingItfBackend: ActivablePilotingItfBackend {
    /// Starts a piloted Point Of Interest.
    ///
    /// - Parameters:
    ///   - latitude: latitude of the location (in degrees) to look at
    ///   - longitude: longitude of the location (in degrees) to look at
    ///   - altitude: altitude above take off point (in meters) to look at
    func start(latitude: Double, longitude: Double, altitude: Double)

    /// Sets the current pitch value.
    ///
    /// Expressed as a signed percentage of the max pitch/roll setting (`maxPitchRoll`), in range [-100, 100].
    /// * -100 corresponds to a pitch angle of max pitch/roll towards ground (copter will fly forward)
    /// * 100 corresponds to a pitch angle of max pitch/roll towards sky (copter will fly backward)
    ///
    /// - Note: this value may be clamped if necessary, in order to respect the maximum supported physical tilt of
    /// the copter.
    ///
    /// - Parameter pitch: the new pitch value to set
    func set(pitch: Int)

    /// Sets the current roll value.
    ///
    /// Expressed as a signed percentage of the max pitch/roll setting (`maxPitchRoll`), in range [-100, 100].
    /// * -100 corresponds to a roll angle of max pitch/roll to the left (copter will fly left)
    /// * 100 corresponds to a roll angle of max pitch/roll to the right (copter will fly right)
    ///
    /// - Note: this value may be clamped if necessary, in order to respect the maximum supported physical tilt of
    /// the copter.
    ///
    /// - Parameter roll: the new roll value to set
    func set(roll: Int)

    /// Sets the current vertical speed value.
    ///
    /// Expressed as a signed percentage of the max vertical speed setting (`maxVerticalSpeed`), in range [-100, 100].
    /// * -100 corresponds to max vertical speed towards ground
    /// * 100 corresponds to max vertical speed towards sky
    ///
    /// - Parameter verticalSpeed: the new vertical speed value to set
    func set(verticalSpeed: Int)
}

/// Internal Poi piloting interface implementation
public class PoiPilotingItfCore: ActivablePilotingItfCore, PointOfInterestPilotingItf {

    public var currentPointOfInterest: PointOfInterest? { return _currentPointOfInterest }
    /// Internal implementation of currentPointOfInterest
    private var _currentPointOfInterest: PointOfInterestCore?

    /// Super class backend as PoiPilotingItfBackend
    private var poiBackend: PoiPilotingItfBackend {
        return backend as! PoiPilotingItfBackend
    }

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: store where this interface will be stored
    ///    - backend: PoiPilotingItf backend
    public init(store: ComponentStoreCore, backend: PoiPilotingItfBackend) {
        super.init(desc: PilotingItfs.pointOfInterest, store: store, backend: backend)
    }

    // MARK: API methods
    public func start(latitude: Double, longitude: Double, altitude: Double) {
        if state != .unavailable {
            poiBackend.start(latitude: latitude, longitude: longitude, altitude: altitude)
        }
    }

    public func set(pitch: Int) {
        poiBackend.set(pitch: signedPercentInterval.clamp(pitch))
    }

    public func set(roll: Int) {
        poiBackend.set(roll: signedPercentInterval.clamp(roll))
    }

    public func set(verticalSpeed: Int) {
        poiBackend.set(verticalSpeed: signedPercentInterval.clamp(verticalSpeed))
    }

    override func reset() {
        super.reset()
        _currentPointOfInterest = nil
    }
}

/// Backend callback methods
extension PoiPilotingItfCore {
    /// Change currentPointOfInterest
    ///
    /// - Parameter currentPointOfInterest: new currentPointOfInterest
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(currentPointOfInterest value: PointOfInterestCore?) -> PoiPilotingItfCore {
        if _currentPointOfInterest != value {
            _currentPointOfInterest = value
            markChanged()
        }
        return self
    }
}
