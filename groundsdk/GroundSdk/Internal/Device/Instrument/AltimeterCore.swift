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

/// Internal Altimeter instrument implementation
public class AltimeterCore: InstrumentCore, Altimeter {

    /// Altitude of the drone relative to take off altitude (in m)
    private (set) public var takeoffRelativeAltitude: Double?

    /// Altitude of the drone relative to the ground (in m)
    private (set) public var groundRelativeAltitude: Double?

    /// Absolute altitude of the drone, i.e. relative to sea-level (in m).
    private (set) public var absoluteAltitude: Double?

    /// Vertical speed of the drone (in m/s)
    /// Positive speed means that the drone is going up
    private (set) public var verticalSpeed: Double?

    /// Debug description
    public override var description: String {
        return "AltimeterCore: \n" +
            "TakeOff altitude: \(String(describing: takeoffRelativeAltitude))" +
            "Ground altitude: \(String(describing: groundRelativeAltitude))" +
            "Absolute altitude: \(String(describing: absoluteAltitude))" +
            "Vertical speed: \(String(describing: verticalSpeed))"
    }

    /// Constructor
    ///
    /// - Parameter store: component store owning this component
    public init(store: ComponentStoreCore) {
        super.init(desc: Instruments.altimeter, store: store)
    }
}

/// Backend callback methods
extension AltimeterCore {

    /// Changes the altitude relative to take off.
    ///
    /// - Note: Setting this value also sets the `takeoffRelativeAltitudeAvailable` to `true`.
    ///
    /// - Parameter takeoffRelativeAltitude: the altitude to set
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(takeoffRelativeAltitude newValue: Double?) -> AltimeterCore {
        if takeoffRelativeAltitude != newValue {
            markChanged()
            takeoffRelativeAltitude = newValue
        }
        return self
    }

    /// Changes the altitude relative to the ground.
    ///
    /// - Note: Setting this value also sets the `groundRelativeAltitudeAvailable` to `true`.
    ///
    /// - Parameter groundRelativeAltitude: the altitude to set
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(groundRelativeAltitude newValue: Double?) -> AltimeterCore {
        if groundRelativeAltitude != newValue {
            markChanged()
            groundRelativeAltitude = newValue
        }
        return self
    }

    /// Changes the altitude relative to sea level.
    /// - Note: Setting this value also sets the `absoluteAltitudeAvailable` to `true`.
    ///
    /// - Parameter absoluteAltitude: the altitude to set
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(absoluteAltitude newValue: Double?) -> AltimeterCore {
        if absoluteAltitude != newValue {
            markChanged()
            absoluteAltitude = newValue
        }
        return self
    }

    /// Changes the vertical speed.
    /// - Note: Setting this value also sets the `verticalSpeedAvailable` to `true`.
    ///
    /// - Parameter verticalSpeed: the altitude to set
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(verticalSpeed newValue: Double?) -> AltimeterCore {
        if verticalSpeed != newValue {
            markChanged()
            verticalSpeed = newValue
        }
        return self
    }
}

extension AltimeterCore: GSAltimeter {
    public func getTakeoffRelativeAltitude() -> NSNumber? {
        return takeoffRelativeAltitude as NSNumber?
    }

    public func getGroundRelativeAltitude() -> NSNumber? {
        return groundRelativeAltitude as NSNumber?
    }

    public func getAbsoluteAltitude() -> NSNumber? {
        return absoluteAltitude as NSNumber?
    }

    public func getVerticalSpeed() -> NSNumber? {
        return verticalSpeed as NSNumber?
    }
}
