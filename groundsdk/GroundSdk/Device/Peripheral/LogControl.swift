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

/// Log Control peripheral interface.
///
/// This peripheral allows to deactivate logs on the drone.
///
/// This peripheral can be retrieved by:
/// ```
/// device.getPeripheral(Peripherals.logControl)
/// ```
public protocol LogControl: Peripheral {
    /// Indicates if the logs are enabled on the drone.
    var areLogsEnabled: Bool { get }

    /// Indicates if the deactivate command is supported.
    var canDeactivateLogs: Bool { get }

    /// Requests the deactivation of logs.
    ///
    /// - Note: The logs stay disabled for the session, and will be
    ///     enabled again at the next restart. This method has no action if
    ///     canDeactivateLogs is `false`
    ///
    /// - Returns: `true` if the deactivation has been asked, `false` otherwise
    func deactivateLogs() -> Bool
}

/// :nodoc:
/// LogControl description
public class LogControlDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = LogControl
    public let uid = PeripheralUid.logControl.rawValue
    public let parent: ComponentDescriptor? = nil
}
