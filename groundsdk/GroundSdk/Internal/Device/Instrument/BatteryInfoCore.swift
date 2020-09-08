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

/// Internal battery info instrument implementation
public class BatteryInfoCore: InstrumentCore, BatteryInfo {

    /// Device's current battery charge level, as an integer percentage of full charge.
    /// From 100 to 0.
    private (set) public var batteryLevel = 0

    /// Tells whether the device is currently charging.
    ///
    /// `true` if the device is charging, `false` otherwise
    private (set) public var isCharging = false

    /// Device's current battery state of health, as an integer percentage of full health.
    /// From 100 to 0.
    private (set) public var batteryHealth: Int?

    /// Device's current battery cycle count
    private (set) public var cycleCount: Int?

    /// Device's battery serial
    private (set) public var serial: String?

    /// Debug description
    public override var description: String {
        return "BatteryInfo: level = \(batteryLevel)"
    }

    /// Constructor
    ///
    /// - Parameter store: component store owning this component
    public init(store: ComponentStoreCore) {
        super.init(desc: Instruments.batteryInfo, store: store)
    }
}

/// Backend callback methods
extension BatteryInfoCore {

    /// Changes battery level value.
    ///
    /// - Parameter batteryLevel: the level to set
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(batteryLevel newValue: Int) -> BatteryInfoCore {
        if batteryLevel != newValue {
            markChanged()
            batteryLevel = newValue
        }
        return self
    }

    /// Updates whether the device is currently charging.
    ///
    /// - Parameter isCharging: the battery is charging or not
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(isCharging newValue: Bool) -> BatteryInfoCore {
        if isCharging != newValue {
            markChanged()
            isCharging = newValue
        }
        return self
    }

    /// Changes battery level value.
    ///
    /// - Parameter batteryHealth: the health to set
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(batteryHealth newValue: Int?) -> BatteryInfoCore {
        if batteryHealth != newValue {
            markChanged()
            batteryHealth = newValue
        }
        return self
    }

    /// Changes battery cycle count.
    ///
    /// - Parameter cycleCount: the cycle count to set
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(cycleCount newValue: Int?) -> BatteryInfoCore {
        if cycleCount != newValue {
            markChanged()
            cycleCount = newValue
        }
        return self
    }

    /// Changes battery serial.
    ///
    /// - Parameter serial: the serial to set
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(serial newValue: String) -> BatteryInfoCore {
        if serial != newValue {
            markChanged()
            serial = newValue
        }
        return self
    }
}

// MARK: Objective-C API

extension BatteryInfoCore: GSBatteryInfo {

    public var gsBatteryHealth: NSNumber? {

        if let batteryHealth = self.batteryHealth {
            return NSNumber(value: batteryHealth)
        }
        return nil
    }
}
