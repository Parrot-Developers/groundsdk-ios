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

/// Drone system info component controller for Anafi message based drones
class AnafiSystemInfo: ArsdkSystemInfo {

    /// First part of the serial. Need to be stored in a variable because the serial is not received atomically
    var serialHigh: String? {
        didSet(newVal) {
            tryToUpdateSerial()
        }
    }
    /// Second part of the serial. Need to be stored in a variable because the serial is not received atomically
    var serialLow: String? {
        didSet(newVal) {
            tryToUpdateSerial()
        }
    }

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        backend = self
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCommonSettingsstateUid {
            ArsdkFeatureCommonSettingsstate.decode(command, callback: self)
        }
    }

    /// Updates the serial of the systemInfo if the two parts of the serial are available
    private func tryToUpdateSerial() {
        if let serialLow = serialLow, let serialHigh = serialHigh {
            systemInfo.update(serial: serialHigh + serialLow).notifyUpdated()
            deviceStore.write(key: PersistedDataKey.serial, value: serialHigh + serialLow).commit()
            self.serialLow = nil
            self.serialHigh = nil
        }
    }
}

/// ArsdkSystemInfo backend implementation
extension AnafiSystemInfo: ArsdkSystemInfoBackend {
    func doResetSettings() -> Bool {
        sendCommand(ArsdkFeatureCommonSettings.resetEncoder())
        return true
    }

    func doFactoryReset() -> Bool {
        sendCommand(ArsdkFeatureCommonFactory.resetEncoder())
        return true
    }
}

/// Common settings state decode callback implementation
extension AnafiSystemInfo: ArsdkFeatureCommonSettingsstateCallback {
    func onProductVersionChanged(software: String!, hardware: String!) {
        systemInfo.update(hardwareVersion: hardware)
        firmwareVersionDidChange(versionStr: software)
        systemInfo.notifyUpdated()
        deviceStore.write(key: PersistedDataKey.hardwareVersion, value: hardware).commit()
    }

    func onProductSerialHighChanged(high: String!) {
        serialHigh = high
    }

    func onProductSerialLowChanged(low: String!) {
        serialLow = low
    }

    func onResetChanged() {
        systemInfo.resetSettingsEnded().notifyUpdated()
    }

    func onBoardIdChanged(id: String!) {
        systemInfo.update(boardId: id).notifyUpdated()
        deviceStore.write(key: PersistedDataKey.boardId, value: id).commit()
    }
}
