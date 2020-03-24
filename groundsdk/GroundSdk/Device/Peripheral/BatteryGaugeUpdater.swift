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

/// Battery gauge updater state.
@objc(GSBatteryGaugeUpdaterState)
public enum BatteryGaugeUpdaterState: Int, CustomStringConvertible {
    /// Service is ready to prepare Update.
    case readyToPrepare

    /// Service preparation is in Progress.
    case preparingUpdate

    /// Service is ready to Update.
    case readyToUpdate

    /// Service update is in Progress.
    case updating

    /// An error occurred during the preparation or the update.
    ///
    /// This state is temporary, it will quickly change to .readyToPrepare afterwards.
    case error

    /// Debug description.
    public var description: String {
        switch self {
        case .readyToPrepare:
            return "readyToPrepare"
        case .preparingUpdate:
            return "preparingUpdate"
        case .readyToUpdate:
            return "readyToUpdate"
        case .updating:
            return "updating"
        case .error:
            return "error"
        }
    }
}

/// Battery gauge  updater unavailability reasons
@objc(GSBatteryGaugeUpdaterUnavailabilityReasons)
public enum BatteryGaugeUpdaterUnavailabilityReasons: Int {
    /// USB power is not provided.
    case notUsbPowered

    /// Insufficient charge
    case insufficientCharge

    /// Drone is not landed.
    case droneNotLanded

    /// Debug description.
    public var description: String {
        switch self {
        case .notUsbPowered:
            return "notUsbPowered"
        case .insufficientCharge:
            return "insufficientCharge"
        case .droneNotLanded:
            return "droneNotLanded"
        }
    }

    /// Set containing all possible sources.
    public static let allCases: Set<BatteryGaugeUpdaterUnavailabilityReasons> = [.notUsbPowered,
        .insufficientCharge, .droneNotLanded]
}

/// Battery gauge updater peripheral interface.
///
/// This peripheral allows to update the battery gauge
///
/// This peripheral can be retrieved by:
/// ```
/// device.getPeripheral(Peripherals.batteryGaugeUpdater)
/// ```
public protocol BatteryGaugeUpdater: Peripheral {
    /// Requests preparing battery gauge update.
    ///
    /// - Returns: true if prepare update request is sent
    func prepareUpdate() -> Bool

    /// Requests battery gauge update.
    ///
    /// - Returns: true if update request is sent
    func update() -> Bool

    /// Current update unavailability reasons
    var unavailabilityReasons: Set<BatteryGaugeUpdaterUnavailabilityReasons> { get }

    /// Current progress, in percent.
    var currentProgress: UInt { get }

    /// Gives current update state.
    var state: BatteryGaugeUpdaterState { get }
}

@objc public protocol GSBatteryGaugeUpdater: Peripheral {

    /// Requests preparing battery gauge update.
    ///
    /// - Returns: true if prepare update request is sent
    func prepareUpdate() -> Bool

    /// Requests battery gauge update.
    ///
    /// - Returns: true if update request is sent
    func update() -> Bool

    /// Checks is unavailability reason is present stopping the update.
    ///
    /// - Parameter reason : unavailability reason
    /// - Returns: true if unavailability reason is present, false otherwise
    func hasUnavailabilityReason(_ reason: BatteryGaugeUpdaterUnavailabilityReasons) -> Bool

    /// Current progress, in percent.
    var currentProgress: UInt { get }

    /// Gives current update state.
    var state: BatteryGaugeUpdaterState { get }
}

/// :nodoc:
/// Battery gauge updater description
@objc(GSBatteryGaugeUpdater)
public class BatteryGaugeUpdaterDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = BatteryGaugeUpdater
    public let uid = PeripheralUid.batteryGaugeUpdater.rawValue
    public let parent: ComponentDescriptor? = nil
}
