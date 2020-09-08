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

/// Instrument that informs a device's battery.
///
/// This instrument can be retrieved by:
/// ```
/// drone.getInstrument(Instruments.batteryInfo)
/// ```
public protocol BatteryInfo: Instrument {

    /// Device's current battery charge level, as an integer percentage of full charge.
    /// From 100 to 0.
    var batteryLevel: Int { get }

    /// Whether the device is currently charging.
    ///
    /// `true` if the device is charging, `false` otherwise.
    var isCharging: Bool { get }

    /// Device's current battery state of health, as an integer percentage of full health.
    /// From 100 to 0.
    /// `nil` if not available. This can happen if the drone does not know or provide this information.
    var batteryHealth: Int? { get }

    /// Device's current battery cycle count, as an integer
    /// `nil` if not available. This can happen if the drone does not know or provide this information.
    var cycleCount: Int? { get }

    /// Battery serial number or `nil` if not available.
    var serial: String? { get }
}

// MARK: Objective-C API

/// Instrument that informs a device's battery.
///
/// This instrument can be retrieved by:
/// ```
/// drone.getInstrument(Instruments.batteryInfo)
/// ```
/// - Note: This protocol is for Objective-C only. Swift must use the protocol `BatteryInfo`.
@objc
public protocol GSBatteryInfo: Instrument {

    /// Device's current battery charge level, as an integer percentage of full charge.
    /// From 100 to 0.
    var batteryLevel: Int { get }

    /// Whether the device is currently charging.
    ///
    /// `true` if the device is charging, `false` otherwise.
    var isCharging: Bool { get }

    /// Device's current battery state of health, as an integer percentage of full health.
    /// From 100 to 0.
    /// `nil` if not available. This can happen if the drone does not know or provide this information.
    @objc(batteryHealth)
    var gsBatteryHealth: NSNumber? { get }
}

/// :nodoc:
/// Instrument descriptor
@objc(GSBatteryInfoDesc)
public class BatteryInfoDesc: NSObject, InstrumentClassDesc {
    public typealias ApiProtocol = BatteryInfo
    public let uid = InstrumentUid.batteryInfo.rawValue
    public let parent: ComponentDescriptor? = nil
}
