// Copyright (C) 2020 Parrot Drones SAS
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

/// Battery gauge updater backend part.
public protocol BatteryGaugeUpdaterBackend: class {
    /// Requests preparing battery gauge update.
    func prepareUpdate()

    /// Requests battery gauge update.
    func update()
}

/// Internal battery gauge updater peripheral implementation
public class BatteryGaugeUpdaterCore: PeripheralCore, BatteryGaugeUpdater {
    /// Implementation backend
    private unowned let backend: BatteryGaugeUpdaterBackend

    /// Current progress, in percent.
    public var currentProgress: UInt = 0

    /// Current update unavailability reasons
    public var unavailabilityReasons = Set<BatteryGaugeUpdaterUnavailabilityReasons>()

    /// Gives current update state.
    public var state: BatteryGaugeUpdaterState = .readyToPrepare

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: store where this peripheral will be stored
    ///    - backend: BatteryGaugeFirmwareUpdater backend
    public init(store: ComponentStoreCore, backend: BatteryGaugeUpdaterBackend) {
        self.backend = backend
        super.init(desc: Peripherals.batteryGaugeUpdater, store: store)
    }

    /// Requests preparing battery gauge update.
    ///
    /// - Returns: true if prepare update request is sent
    public func prepareUpdate() -> Bool {
        if state == .readyToPrepare, unavailabilityReasons.isEmpty {
            backend.prepareUpdate()
            return true
        } else {
            return false
        }
    }

    /// Requests battery gauge update.
    ///
    /// - Returns: true if update request is sent
    public func update() -> Bool {
        if state == .readyToUpdate, unavailabilityReasons.isEmpty {
            backend.update()
            return true
        } else {
            return false
        }
    }

    /// Set unavailability reasons
    ///
    /// - Parameter unavailabilityReasons: new unavailability reasons
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(unavailabilityReasons newValue: Set<BatteryGaugeUpdaterUnavailabilityReasons>)
        -> BatteryGaugeUpdaterCore {
        if newValue != unavailabilityReasons {
            unavailabilityReasons = newValue
            markChanged()
        }
        return self
    }

    /// Set progress
    ///
    /// - Parameter progress: new progress
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(progress newValue: UInt)
           -> BatteryGaugeUpdaterCore {
        if newValue != currentProgress {
            currentProgress = newValue
            markChanged()
        }
        return self
    }

    /// Set state
    ///
    /// - Parameter state: new state
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(state newValue: BatteryGaugeUpdaterState)
           -> BatteryGaugeUpdaterCore {
           if newValue != state {
               state = newValue
               markChanged()
           }
           return self
       }
}
