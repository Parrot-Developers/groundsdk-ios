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

/// Removable user storage component controller for UserStorage feature based devices
class UserStorageRemovableUserStorage: DeviceComponentController {
    /// Removable user storage component
    private var removableUserStorage: RemovableUserStorageCore!

    /// `true` if formatting is allowed in state `.ready`.
    private var formatWhenReadyAllowed = false

    /// `true` if formatting result event is supported by the drone.
    private var formatResultEvtSupported = false

    /// `true` when a format request was sent and a formatting result event is expected.
    private var waitingFormatResult = false

    /// Latest state received from device.
    private var latestState: RemovableUserStorageState?

    /// State received during formatting, that will be notified after formatting result.
    private var pendingState: RemovableUserStorageState?

    /// `true` if formatting type is supported by the drone.
    private var formattingTypeSupported = false

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        removableUserStorage = RemovableUserStorageCore(store: deviceController.device.peripheralStore, backend: self)
    }

    override func didConnect() {
        removableUserStorage.publish()
    }

    override func didDisconnect() {
        removableUserStorage.unpublish()
        waitingFormatResult = false
        latestState = nil
        pendingState = nil
        formattingTypeSupported = false
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureUserStorageUid {
            ArsdkFeatureUserStorage.decode(command, callback: self)
        }
    }

    /// Updates state and formatting capability according to this state and notify changes
    ///
    /// - Parameter state: new state to set
    private func updateState(_ state: RemovableUserStorageState) {
        removableUserStorage.update(state: state)
            .update(canFormat: (state == .needFormat || (formatWhenReadyAllowed && state == .ready)))
            .notifyUpdated()
    }

    private func updateFormattingType(_ formattingType: Set<FormattingType>) {
        removableUserStorage.update(supportedFormattingTypes: formattingType).notifyUpdated()
    }

    private func updateFormatProgress(formattingStep: FormattingStep, formattingProgress: Int) {
        removableUserStorage.update(formattingStep: formattingStep, formattingProgress: formattingProgress)
                             .notifyUpdated()
    }
}

/// Removable user storage backend implementation
extension UserStorageRemovableUserStorage: RemovableUserStorageCoreBackend {
    func format(formattingType: FormattingType, newMediaName: String?) -> Bool {
        if !formattingTypeSupported {
            sendCommand(ArsdkFeatureUserStorage.formatEncoder(label: newMediaName ?? ""))
        } else {
            switch formattingType {
            case .quick:
                sendCommand(ArsdkFeatureUserStorage.formatWithTypeEncoder(label: newMediaName ?? "", type: .quick))
            case .full:
                sendCommand(ArsdkFeatureUserStorage.formatWithTypeEncoder(label: newMediaName ?? "", type: .full))
            }
        }
        if formatResultEvtSupported {
            waitingFormatResult = true
            updateState(.formatting)
        }
        return true
    }
}

/// User storage decode callback implementation
extension UserStorageRemovableUserStorage: ArsdkFeatureUserStorageCallback {
    func onInfo(name: String!, capacity: UInt64) {
        removableUserStorage.update(name: name, capacity: Int64(capacity)).notifyUpdated()
    }

    func onMonitor(availableBytes: UInt64) {
        removableUserStorage.update(availableSpace: Int64(availableBytes)).notifyUpdated()
    }

    func onState(
        physicalState: ArsdkFeatureUserStoragePhyState, fileSystemState: ArsdkFeatureUserStorageFsState,
        attributeBitField: UInt, monitorEnabled: UInt, monitorPeriod: UInt) {

        var state = RemovableUserStorageState.noMedia
        switch physicalState {
        case .undetected:
            state = .noMedia
        case .tooSmall:
            state = .mediaTooSmall
        case .tooSlow:
            state = .mediaTooSlow
        case .usbMassStorage:
            state = .usbMassStorage
        case .available:
            switch fileSystemState {
            case .unknown:
                state = .mounting
            case .formatNeeded:
                state = .needFormat
            case .formatting:
                state = .formatting
            case .ready:
                state = .ready
            case .error:
                state = .error
            case .sdkCoreUnknown:
                ULog.w(.tag, "Unknown fileSystemState, skipping this event.")
                return
            }
        case .sdkCoreUnknown:
            ULog.w(.tag, "Unknown physicalState, skipping this event.")
            return
        }
        if !formatResultEvtSupported && latestState == .formatting {
            // format result when the drone does not support the format result event
            if state == .ready {
                updateState(.formattingSucceeded)
            } else if state == .needFormat || state == .error {
                updateState(.formattingFailed)
            }
        }

        if waitingFormatResult && state != .formatting {
            // new state will be notified after reception of formatting result
            pendingState = state
        } else {
            updateState(state)
        }
        latestState = state
        if state == .ready && monitorEnabled == 0 {
            sendCommand(ArsdkFeatureUserStorage.startMonitoringEncoder(period: 0))
        } else if state != .ready && monitorEnabled == 1 {
            sendCommand(ArsdkFeatureUserStorage.stopMonitoringEncoder())
        }
    }

    func onFormatResult(result: ArsdkFeatureUserStorageFormattingResult) {
        switch result {
        case .error:
            updateState(.formattingFailed)
        case .denied:
            updateState(.formattingDenied)
            if let lastState = latestState {
                // since in that case the device will not send another state,
                // restore latest state received before formatting
                updateState(lastState)
            }
        case .success:
            updateState(.formattingSucceeded)
        case .sdkCoreUnknown:
            ULog.w(.tag, "Unknown result, skipping this event.")
        }
        if let pendingState = pendingState {
            updateState(pendingState)
            self.pendingState = nil
        }
        waitingFormatResult = false
    }

    func onCapabilities(supportedFeaturesBitField: UInt) {
        formatResultEvtSupported = ArsdkFeatureUserStorageFeatureBitField.isSet(.formatResultEvtSupported,
                                                                                inBitField: supportedFeaturesBitField)
        formatWhenReadyAllowed = ArsdkFeatureUserStorageFeatureBitField.isSet(.formatWhenReadyAllowed,
                                                                                inBitField: supportedFeaturesBitField)
        if let latestState = latestState {
            updateState(latestState)
        }
    }

    func onSupportedFormattingTypes(supportedTypesBitField: UInt) {
        formattingTypeSupported = true
        var availableFormattingType: Set<FormattingType> = []
        if ArsdkFeatureUserStorageFormattingTypeBitField.isSet(.quick, inBitField: supportedTypesBitField) {
            availableFormattingType.insert(.quick)
        }
        if ArsdkFeatureUserStorageFormattingTypeBitField.isSet(.full, inBitField: supportedTypesBitField) {
            availableFormattingType.insert(.full)
        }
        updateFormattingType(availableFormattingType)
    }

    func onFormatProgress(step: ArsdkFeatureUserStorageFormattingStep, percentage: UInt) {
        var formattingStep: FormattingStep = .partitioning
        switch step {
        case .partitioning:
            formattingStep = .partitioning
        case .clearingData:
            formattingStep = .clearingData
        case .creatingFs:
            formattingStep = .creatingFs
        case .sdkCoreUnknown:
            ULog.w(.tag, "Unknown result, skipping this event.")
        }
        updateFormatProgress(formattingStep: formattingStep, formattingProgress: Int(percentage))
    }
}
