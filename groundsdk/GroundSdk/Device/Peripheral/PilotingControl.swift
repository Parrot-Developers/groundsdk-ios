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

/// Piloting Behaviour.
@objc(GSPilotingControlBehaviour)
public enum PilotingBehaviour: Int, CustomStringConvertible {

    /// Standard piloting mode.
    case standard

    /// Piloting style is camera operated, commands are relative to camera pitch.
    case cameraOperated

    /// Debug description.
    public var description: String {
        switch self {
        case .standard:
            return "standard"
        case .cameraOperated:
            return "cameraOperated"
        }
    }

    /// Set containing all possible sources.
    public static let allCases: Set<PilotingBehaviour> = [.standard, .cameraOperated]
}

/// Peripheral managing the piloting general controls.
///
/// This peripheral can be retrieved by:
/// ```
/// device.getPeripheral(Peripherals.pilotingControl)
/// ```
public protocol PilotingControl: Peripheral {
    /// Behaviour setting.
    var behaviourSetting: PilotingBehaviourSetting { get }
}

/// Peripheral managing the piloting general controls.
///
/// - Note: this protocol is for Objective-C compatibility only.
@objc public protocol GSPilotingControl: Peripheral {
    /// Behaviour setting.
    @objc(behaviourSetting)
    var gsBehaviourSetting: GSPilotingBehaviourSetting { get }
}

/// Setting to change the piloting behaviour.
public protocol PilotingBehaviourSetting: class {
    /// Tells if the setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Current behaviour setting.
    var value: PilotingBehaviour { get set }

    /// Supported behaviours.
    var supportedBehaviours: Set<PilotingBehaviour> { get }
}

/// Setting to change the piloting behaviour.
///
/// - Note: this protocol is for Objective-C compatibility only.
@objc public protocol GSPilotingBehaviourSetting {
    /// Tells if the setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Current behaviour setting.
    var value: PilotingBehaviour { get set }

    /// Tells whether a given behaviour is supported.
    ///
    /// - Parameter behaviour: the behaviour to query
    /// - Returns: `true` if the behaviour is supported, `false` otherwise
    func isSupportedBehaviour(_ behaviour: PilotingBehaviour) -> Bool
}

/// :nodoc:
/// PilotingControl description.
@objc(GSPilotingControlDesc)
public class PilotingControlDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = PilotingControl
    public let uid = PeripheralUid.pilotingControl.rawValue
    public let parent: ComponentDescriptor? = nil
}
