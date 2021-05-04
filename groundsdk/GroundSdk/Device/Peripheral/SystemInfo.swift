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

/// System information.
///
/// In this peripheral you can retrieve all information relative to the system of the device.
///
/// This peripheral can be retrieved by:
/// ```
/// device.getPeripheral(Peripherals.systemInfo)
/// ```
@objc(GSSystemInfo)
public protocol SystemInfo: Peripheral {

    /// Firmware version of the device.
    var firmwareVersion: String { get }

    /// Whether the device firmware version is blacklisted.
    ///
    /// If firmware is blacklisted, an update should be done as soon as possible. Some features of the device might be
    /// unavailable.
    var isFirmwareBlacklisted: Bool { get }

    /// Whether an update is required.
    var isUpdateRequired: Bool { get }

    /// Hardware version of the device.
    var hardwareVersion: String { get }

    /// Serial of the device.
    /// This serial is unique over all devices of the same type.
    /// It should be persistant, but may be changed on the factory partition of the device.
    var serial: String { get }

    /// Device board identifier.
    var boardId: String { get }

    /// Whether the reset settings is in progress.
    var isResetSettingsInProgress: Bool { get }

    /// Whether the factory reset is in progress.
    var isFactoryResetInProgress: Bool { get }

    /// Reset the settings of the device.
    ///
    /// - Returns: `true` if the reset is in progress
    func resetSettings() -> Bool

    /// Do a factory reset on the device.
    ///
    /// - Returns: `true` if the factory reset has begun
    /// - Note: This will produce a reboot of the device.
    func factoryReset() -> Bool
}

/// :nodoc:
/// SystemInfo description
@objc(GSSystemInfoDesc)
public class SystemInfoDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = SystemInfo
    public let uid = PeripheralUid.systemInfo.rawValue
    public let parent: ComponentDescriptor? = nil
}
