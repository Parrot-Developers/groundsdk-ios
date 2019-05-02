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

/// Beeper peripheral interface.
///
/// This peripheral allows playing an alert sound.
///
/// This peripheral can be retrieved by:
/// ```
/// device.getPeripheral(Peripherals.beeper)
/// ```
@objc(GSBeeper)
public protocol Beeper: Peripheral {

    /// Whether the device is currently playing an alert sound.
    ///
    /// `true` if the device is currently playing an alert sound, `false` otherwise.
    var alertSoundPlaying: Bool { get }

    /// Commands the device to play an alert sound.
    ///
    /// The alert sound shall be stopped with `stopAlertSound`.
    ///
    /// - Returns: `true` if the start alert sound operation could be initiated, `false` otherwise
    func startAlertSound() -> Bool

    /// Commands the device to stop playing the alert sound.
    ///
    /// - Returns: `true` if the stop alert sound operation could be initiated, `false` otherwise
    func stopAlertSound() -> Bool
}

/// :nodoc:
/// Beeper description
@objc(GSBeeperDesc)
public class BeeperDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = Beeper
    public let uid = PeripheralUid.beeper.rawValue
    public let parent: ComponentDescriptor? = nil
}
