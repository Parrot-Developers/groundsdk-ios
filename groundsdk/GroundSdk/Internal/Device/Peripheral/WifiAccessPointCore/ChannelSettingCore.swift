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

/// Channel setting core implementation
class ChannelSettingCore: ChannelSetting {
    /// Values of this setting that can be sent to the backend
    enum SettingValue {
        /// Sets the access point channel
        case select(channel: WifiChannel)
        /// Requests auto-selection of the most appropriate access point channel, with optional band restriction
        case autoSelectChannel(band: Band?)
    }

    /// Delegate called when the setting value is changed by setting `value` property
    private unowned let didChangeDelegate: SettingChangeDelegate

    /// Timeout object.
    ///
    /// Visibility is internal for testing purposes
    let timeout = SettingTimeout()

    /// Tells if the setting value has been changed and is waiting for change confirmation
    var updating: Bool { return timeout.isScheduled }

    private(set) var selectionMode = ChannelSelectionMode.manual

    public var availableChannels: Set<WifiChannel> {
        // add the current channel
        var availableChannels = _availableChannels
        availableChannels.insert(channel)
        return availableChannels
    }

    private(set) var channel = WifiChannel.band_2_4_channel1

    /// Set of channels to which the access point may be configured, as given by the device
    private var _availableChannels: Set<WifiChannel> = []

    /// Set of available bands.
    private var availableBands: Set<Band> = []

    /// Whether or not the automatic selection is supported by the device.
    private var autoSelectSupported = true

    /// Backend in charge of handling the changes
    private let backend: (SettingValue) -> Bool

    /// Constructor
    ///
    /// - Parameters:
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting `value` property
    ///   - backend: closure to call to change the setting value
    init(didChangeDelegate: SettingChangeDelegate, backend: @escaping (SettingValue) -> Bool) {
        self.didChangeDelegate = didChangeDelegate
        self.backend = backend
    }

    func select(channel newChannel: WifiChannel) {
        if (channel != newChannel || selectionMode != .manual) && _availableChannels.contains(newChannel) {
            if backend(.select(channel: newChannel)) {
                let oldChannel = channel
                let oldSelectionMode = selectionMode
                // value sent to the backend, update setting value and mark it updating
                channel = newChannel
                selectionMode = .manual
                timeout.schedule { [weak self] in
                    if let `self` = self {
                        let channelUpdated = self.update(channel: oldChannel)
                        let selectionModeUpdated = self.update(selectionMode: oldSelectionMode)
                        if channelUpdated || selectionModeUpdated {
                            self.didChangeDelegate.userDidChangeSetting()
                        }
                    }
                }
                didChangeDelegate.userDidChangeSetting()
            }
        }
    }

    func canAutoSelect() -> Bool {
        return autoSelectSupported && !availableBands.isEmpty
    }

    func autoSelect() {
        if canAutoSelect() {
            if backend(.autoSelectChannel(band: nil)) {
                let oldSelectionMode = selectionMode
                selectionMode = .autoAnyBand
                timeout.schedule { [weak self] in
                    if let `self` = self, self.update(selectionMode: oldSelectionMode) {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
                didChangeDelegate.userDidChangeSetting()
            }
        }
    }

    func canAutoSelect(onBand band: Band) -> Bool {
        return autoSelectSupported && availableBands.contains(band)
    }

    func autoSelect(onBand band: Band) {
        if canAutoSelect(onBand: band) {
            if backend(.autoSelectChannel(band: band)) {
                let oldSelectionMode = selectionMode
                switch band {
                case .band_2_4_Ghz:
                    selectionMode = .auto2_4GhzBand
                case .band_5_Ghz:
                    selectionMode = .auto5GhzBand
                }
                timeout.schedule { [weak self] in
                    if let `self` = self, self.update(selectionMode: oldSelectionMode) {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
                didChangeDelegate.userDidChangeSetting()
            }
        }
    }

    /// Update the list of available channels
    ///
    /// Also update the set of available bands.
    ///
    /// - Parameter newValue: the set of available channels
    /// - Returns: true if the set has been changed
    func update(availableChannels newValue: Set<WifiChannel>) -> Bool {
        if _availableChannels != newValue || updating {
            _availableChannels = newValue
            availableBands.removeAll()
            // compute all available bands from those channels to know which selection modes are available
            _availableChannels.forEach {
                availableBands.insert($0.getBand())
                // if we already have all bands, no need to iterate further
                if availableBands == Band.allCases {
                    return
                }
            }
            return true
        }
        return false
    }

    /// Update the current channel.
    ///
    /// - Parameter newValue: the new channel
    /// - Returns: true if the channel has been changed
    func update(channel newValue: WifiChannel) -> Bool {
        if channel != newValue || updating {
            channel = newValue
            timeout.cancel()
            return true
        }
        return false
    }

    /// Update the ability of this setting to make an automatic selection.
    ///
    /// - Parameter newValue: the new value
    /// - Returns: true if the automatic selection availability has been changed
    func update(autoSelectSupported newValue: Bool) -> Bool {
        if autoSelectSupported != newValue {
            autoSelectSupported = newValue
            return true
        }
        return false
    }

    /// Update the selection mode.
    ///
    /// - Parameter newValue: the new selection mode
    /// - Returns: true if the selection mode has been changed
    func update(selectionMode newValue: ChannelSelectionMode) -> Bool {
        if selectionMode != newValue || updating {
            selectionMode = newValue
            timeout.cancel()
            return true
        }
        return false
    }

    /// Cancels any pending rollback.
    ///
    /// - Parameter completionClosure: block that will be called if a rollback was pending
    func cancelRollback(completionClosure: () -> Void) {
        if timeout.isScheduled {
            timeout.cancel()
            completionClosure()
        }
    }
}

/// Extension of ChannelSettingCore to conform to the ObjC GSChannelSetting protocol
extension ChannelSettingCore: GSChannelSetting {
    public var availableChannelsAsInt: Set<Int> {
        return Set(availableChannels.map { $0.rawValue })
    }
}
