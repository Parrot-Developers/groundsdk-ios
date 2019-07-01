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

/// Copilot source description.
@objc(GSCopilotSource)
public enum CopilotSource: Int {

    /// Use the SkyController joysticks.
    case remoteControl

    /// Use the application controls
    /// Disables the SkyController joysticks
    case application

    /// Debug description.
    public var description: String {
        switch self {
        case .remoteControl:
            return "remoteControl"
        case .application:
            return "application"
        }
    }

    /// Set containing all possible sources.
    public static let allCases: Set<CopilotSource> = [.remoteControl, .application]
}

/// Peripheral managing copilot
///
/// Copilot allows to select the source of piloting commands, either the remote control (default) or the application.
/// Selecting a source prevents the other one from sending any piloting command.
/// The piloting source is automatically reset to {@link Source#REMOTE_CONTROL remote control} when this one is
/// disconnected from the phone.
///
/// This peripheral can be retrieved by:
/// ```
/// device.getPeripheral(Peripherals.coPilot)
/// ```
public protocol Copilot: Peripheral {
    /// Copilot setting
    var setting: CopilotSetting { get }

}

/// Setting to change the piloting source
public protocol CopilotSetting: class {
    /// Tells if the setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Current source setting.
    var source: CopilotSource { get set }
}

/// :nodoc:
/// CoPilot description
@objc(GSCoPilotDesc)
public class CopilotDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = Copilot
    public let uid = PeripheralUid.copilot.rawValue
    public let parent: ComponentDescriptor? = nil
}
