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

/// Antiflicker component controller for camera feature message based drones
class CameraFeatureAntiflicker: AntiflickerController {

    /// Send mode command. Subclass must override this function to send the command
    ///
    /// - Parameters:
    ///   - mode: requested mode.
    ///   - locationBasedValue: if mode is auto, the corresponding value set from current location if available.
    /// - Returns: true if the command has been sent
    override func sendModeCommand(_ mode: AntiflickerMode, locationBasedValue: AntiflickerValue? = nil) -> Bool {
        switch mode {
        case .off, .mode50Hz, .mode60Hz:
            sendCommand(ArsdkFeatureCamera.setAntiflickerModeEncoder(mode: mode.arsdkValue!))
            return true
        case .auto:
            if let locationBasedValue = locationBasedValue, antiflicker.value != locationBasedValue {
                sendCommand(ArsdkFeatureCamera.setAntiflickerModeEncoder(mode: locationBasedValue.arsdkValue!))
                return true
            }
        }
        return false
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCameraUid {
            ArsdkFeatureCamera.decode(command, callback: self)
        }
    }
}

// MARK: - ArsdkFeatureCameraCallback
extension CameraFeatureAntiflicker: ArsdkFeatureCameraCallback {

    func onAntiflickerCapabilities(supportedModesBitField: UInt) {
        capabilitiesDidChange(.mode(AntiflickerMode.createSetFrom(bitField: supportedModesBitField)))
    }

    func onAntiflickerMode(mode arsdkMode: ArsdkFeatureCameraAntiflickerMode,
                           value arsdkValue: ArsdkFeatureCameraAntiflickerMode) {
        guard let mode = AntiflickerMode(fromArsdk: arsdkMode) else {
            ULog.w(.cameraTag, "Invalid antiflicker mode: \(arsdkMode.rawValue)")
            return
        }
        guard let value = AntiflickerValue(fromArsdk: arsdkValue) else {
            ULog.w(.cameraTag, "Invalid antiflicker value: \(arsdkValue.rawValue)")
            return
        }
        antiflicker.update(value: value)
        if antiflicker.setting.mode != .auto || droneSupportsAutoMode {
            settingDidChange(.mode(mode))
        } else {
            settingDidChange(.mode(.auto))
        }
        antiflicker.notifyUpdated()
    }
}

/// Extension that add conversion from/to arsdk enum
extension AntiflickerMode: ArsdkMappableEnum {

    /// Create set of anti-flicker modes from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all anti-flicker modes in bitField
    static func createSetFrom(bitField: UInt) -> Set<AntiflickerMode> {
        var result = Set<AntiflickerMode>()
        ArsdkFeatureCameraAntiflickerModeBitField.forAllSet(in: bitField) { arsdkValue in
            if let value = AntiflickerMode(fromArsdk: arsdkValue) {
                result.insert(value)
            }
        }
        return result
    }

    static let arsdkMapper = Mapper<AntiflickerMode, ArsdkFeatureCameraAntiflickerMode>([
        .off: .off,
        .mode50Hz: .mode50hz,
        .mode60Hz: .mode60hz,
        .auto: .auto])
}

/// Extension that add conversion from/to arsdk enum
extension AntiflickerValue: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<AntiflickerValue, ArsdkFeatureCameraAntiflickerMode>([
        .off: .off,
        .value50Hz: .mode50hz,
        .value60Hz: .mode60hz])
}
