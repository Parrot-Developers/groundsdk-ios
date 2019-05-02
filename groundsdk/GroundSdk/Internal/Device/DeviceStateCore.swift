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

/// Mutable DeviceState implementation
public class DeviceStateCore: DeviceState {

    /// Closure which will be called when the state has changed
    private var didChange: (() -> Void)?

    /// Informs about pending changes waiting for notifyUpdated call
    private var changed = false

    /// Device is persisted, i.e. there are local data for this device in the persistent store
    private(set) var persisted = false

    /// Gets one of the best connector.
    /// If there is at least one connector, the returned value won't be nil.
    var oneOfTheBestConnector: DeviceConnector? {
        guard !connectors.isEmpty else {
            return nil
        }

        return connectors.sorted(by: { connector1, connector2 -> Bool in
            return connector1.betterThan(connector2)
        })[0]
    }

    /// Gets the best connector if there is no ambiguity.
    /// If there is one (for example, if there are 2 remote control connectors), nil will be returned.
    var bestConnector: DeviceConnector? {
        guard !connectors.isEmpty else {
            return nil
        }

        var bestConnector: DeviceConnector?
        // if the device only has one connector, use it
        if connectors.count == 1 {
            bestConnector = connectors[0]
        } else {
            // search for a single remote control connector
            let remoteCtrlConnectors = connectors.filter {$0.connectorType == .remoteControl}
            if remoteCtrlConnectors.count == 1 {
                bestConnector = remoteCtrlConnectors[0]
            } else if remoteCtrlConnectors.count == 0 {
                // if there no remote connector and more than one local connector, search for a single local usb
                // connector
                let localUsbConnector = connectors.filter {$0.connectorType == .local && $0.technology == .usb}
                if localUsbConnector.count == 1 {
                    bestConnector = localUsbConnector[0]
                }
            }
        }
        return bestConnector
    }

    /// Constructor
    ///
    /// - Parameter didChange: closure which will be called when the state has changed
    internal init(didChange: @escaping () -> Void) {
        self.didChange = didChange
    }

    /// Changes device connection state and cause
    ///
    /// - Parameters:
    ///    - state: new state
    ///    - cause: reason of the state change
    /// - Returns: self to allow call chaining
    ///
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(connectionState state: ConnectionState,
                                          withCause cause: ConnectionStateCause) -> DeviceStateCore {
        changed = ((connectionState != state) || (connectionStateCause != cause))
        connectionState = state
        connectionStateCause = cause
        updateCommandsState()
        return self
    }

    /// Changes device connection state
    ///
    /// - Parameter state: new state
    /// - Returns: self to allow call chaining
    ///
    /// - Note: Changes are not notified until notifyUpdated() is called
    /// this only changes the connection state and not the reason.
    /// You might prefer to use update:connectionState:withCause:
    @discardableResult public func update(connectionState state: ConnectionState) -> DeviceStateCore {
        changed = (connectionState != state)
        connectionState = state
        updateCommandsState()
        return self
    }

    /// Tells if the device is persisted
    ///
    /// Note that changes are not notified until notifyUpdated() is called
    ///
    /// - Parameter persisted: `true` if persisted
    /// - Returns: self to allow call chaining
    @discardableResult public func update(persisted: Bool) -> DeviceStateCore {
        if persisted != self.persisted {
            changed = true
            self.persisted = persisted
            updateCommandsState()
        }
        return self
    }

    /// Changes the device connectors
    ///
    /// Note that changes are not notified until notifyUpdated() is called
    ///
    /// - Parameter connectors: device connectors
    /// - Returns: self to allow call chaining
    @discardableResult public func update(connectors: [DeviceConnectorCore]) -> DeviceStateCore {
        changed = true
        self._connectors = connectors
        updateCommandsState()
        return self
    }

    /// Changes the active connector
    ///
    /// Note that changes are not notified until notifyUpdated() is called
    ///
    /// - Parameter connector: active connector to set
    /// - Returns: self to allow call chaining
    @discardableResult public func update(activeConnector connector: DeviceConnectorCore?) -> DeviceStateCore {
        changed = true
        self._activeConnector = connector
        updateCommandsState()
        return self
    }

    /// Notify changes made by previously called setters
    public func notifyUpdated() {
        if changed {
            changed = false
            didChange?()
        }
    }

    /// Update command state (canBe<action>) based on current state info.
    /// Note: this function doesn't mark state as changed. It's assumed that the change that trigged this
    /// command state update did set the `changed` flag.
    private func updateCommandsState() {
        self.canBeForgotten =  persisted || connectors.contains { $0.connectorType == .remoteControl }
        self.canBeConnected = connectionState == .disconnected && !connectors.isEmpty
        self.canBeDisconnected = (connectionState == .connecting || connectionState == .connected) &&
            (_activeConnector?.supportsDisconnect ?? false)
    }

}
