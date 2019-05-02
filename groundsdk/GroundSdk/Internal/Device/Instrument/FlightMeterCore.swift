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

/// Internal FlightMeter instrument implementation
public class FlightMeterCore: InstrumentCore, FlightMeter {

    private(set) public var totalFlightDuration = 0

    private(set) public var lastFlightDuration = 0

    private(set) public var totalFlights = 0

    /// Debug description
    public override var description: String {
        return "FlightMeter: totalFlightDuration = \(totalFlightDuration), totalFlights = \(totalFlights)"
    }

    /// Constructor
    ///
    /// - Parameter store: component store owning this component
    public init(store: ComponentStoreCore) {
        super.init(desc: Instruments.flightMeter, store: store)
    }
}

/// Backend callback methods
extension FlightMeterCore {

    /// Changes the totalFlightDuration value.
    ///
    /// - Parameter totalFlightDuration: total flight duration in seconds
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(totalFlightDuration newValue: Int) -> FlightMeterCore {
        if totalFlightDuration != newValue {
            markChanged()
            totalFlightDuration = newValue
        }
        return self
    }

    /// Changes the lastFlightDuration value.
    ///
    /// - Parameter lastFlightDuration: last flight duration in seconds
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(lastFlightDuration newValue: Int) -> FlightMeterCore {
        if lastFlightDuration != newValue {
            markChanged()
            lastFlightDuration = newValue
        }
        return self
    }

    /// Changes the totalFlights value.
    ///
    /// - Parameter totalFlights: total flights performed by the drone
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(totalFlights newValue: Int) -> FlightMeterCore {
        if totalFlights != newValue {
            markChanged()
            totalFlights = newValue
        }
        return self
    }
}
