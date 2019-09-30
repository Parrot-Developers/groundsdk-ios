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
import GroundSdk

/// Extension that add conversion from/to arsdk enum
extension PilotingBehaviour: ArsdkMappableEnum {

    /// Create set of piloting behaviours from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all piloting behaviours in bitField
    static func createSetFrom(bitField: UInt) -> Set<PilotingBehaviour> {
        var result = Set<PilotingBehaviour>()
        ArsdkFeaturePilotingStyleStyleBitField.forAllSet(in: bitField) { arsdkValue in
            if let value = PilotingBehaviour(fromArsdk: arsdkValue) {
                result.insert(value)
            }
        }
        return result
    }

    static let arsdkMapper = Mapper<PilotingBehaviour, ArsdkFeaturePilotingStyleStyle>([
        .standard: .standard,
        .cameraOperated: .cameraOperated])
}

/// PilotingControl peripheral controller
class AnafiPilotingControl: DeviceComponentController, PilotingControlBackend {

    /// PilotingControl component
    private(set) var pilotingControl: PilotingControlCore!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {

        super.init(deviceController: deviceController)
        pilotingControl = PilotingControlCore(store: deviceController.device.peripheralStore, backend: self)
    }

    override func willConnect() {
        pilotingControl.update(supportedBehaviours: [.standard]).update(behaviour: .standard)
        super.willConnect()
    }

    override func didConnect() {
        pilotingControl.publish()
        super.didConnect()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        pilotingControl.unpublish()
        super.didDisconnect()
    }

    func set(behaviour: PilotingBehaviour) -> Bool {
        if connected {
            return sendPilotingBehaviourCommand(behaviour)
        } else {
            pilotingControl.update(behaviour: behaviour).notifyUpdated()
            return false
        }
    }

    /// Send piloting behaviour command.
    ///
    /// - Parameter behaviour: requested behaviour
    /// - Returns: true if the command has been sent
    func sendPilotingBehaviourCommand(_ behaviour: PilotingBehaviour) -> Bool {
        if let style = behaviour.arsdkValue {
            sendCommand(ArsdkFeaturePilotingStyle.setStyleEncoder(style: style))
            return true
        } else {
            return false
        }
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeaturePilotingStyleUid {
            ArsdkFeaturePilotingStyle.decode(command, callback: self)
        }
    }
}

/// Piloting style decode callback implementation.
extension AnafiPilotingControl: ArsdkFeaturePilotingStyleCallback {
    func onStyle(style: ArsdkFeaturePilotingStyleStyle) {
        switch style {
        case .standard:
            pilotingControl.update(behaviour: .standard).notifyUpdated()
        case .cameraOperated:
            pilotingControl.update(behaviour: .cameraOperated).notifyUpdated()
        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown ArsdkFeaturePilotingStyleStyle, skipping this event.")
            return
        }
    }

    func onCapabilities(stylesBitField: UInt) {
        let supported = PilotingBehaviour.createSetFrom(bitField: stylesBitField)
        pilotingControl.update(supportedBehaviours: supported).notifyUpdated()
    }
}
