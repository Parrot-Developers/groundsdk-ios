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

/// Engine that is in charge of the auto connection.
class AutoConnectionEngine: EngineBaseCore {
    /// AutoConnection facility.
    private var autoConnection: AutoConnectionCore!

    /// Drone store.
    private var droneStore: DroneStoreUtilityCore!

    /// Monitor of the drone store.
    ///
    /// Kept to be able to stop monitoring.
    /// `nil` when the engine is not monitoring the drone store.
    private var droneStoreMonitor: MonitorCore?

    /// Remote control store.
    private var rcStore: RemoteControlStoreUtilityCore!

    /// Monitor of the remote control store.
    ///
    /// Kept to be able to stop monitoring.
    /// `nil` when the engine is not monitoring the remote control store.
    private var remoteControlStoreMonitor: MonitorCore?

    /// Current remote control elected for auto-connection, `nil` if none.
    private var currentRc: RemoteControlCore?

    /// Current drone selected for auto-connection, `nil` if none.
    private var currentDrone: DroneCore? {
        didSet {
            latestCurrentDrone = oldValue
        }
    }

    /// Latest current drone selected for auto-connection, `nil` if none.
    private var latestCurrentDrone: DroneCore?

    /// Drone that the auto-connection should try to reconnect, `nil` if none.
    private var droneToReconnect: DroneCore?

    /// Whether or not the autoconnection is started.
    private var autoConnectionStarted = false

    /// `true` when `processDeviceList` is executing.
    private var processing = false

    /// `true` when a device list change notification was received while `processing` is `true`.
    private var shouldProcessAgain = false

    /// Constructor.
    ///
    /// - Parameter enginesController: engines controller
    public required init(enginesController: EnginesControllerCore) {
        ULog.d(.autoConnectEngineTag, "Loading AutoConnection engine.")
        super.init(enginesController: enginesController)
        autoConnection = AutoConnectionCore(store: enginesController.facilityStore, backend: self)
    }

    override public func startEngine() {
        ULog.d(.autoConnectEngineTag, "Starting AutoConnection engine.")
        droneStore = utilities.getUtility(Utilities.droneStore)
        rcStore = utilities.getUtility(Utilities.remoteControlStore)

        if GroundSdkConfig.sharedInstance.autoConnectionAtStartup {
            _ = startAutoConnection()
        }

        // publish facility
        autoConnection.publish()
    }

    override public func stopEngine() {
        ULog.d(.autoConnectEngineTag, "Stopping AutoConnection engine.")
        autoConnection.unpublish()

         _ = stopAutoConnection()
    }

    /// Starts the auto connection.
    private func doStartAutoConnection() {
        autoConnectionStarted = true
        ULog.d(.autoConnectEngineTag, "Starting auto connection.")

        currentDrone = nil
        currentRc = nil
        droneToReconnect = nil

        autoConnection.update(state: .started)

        droneStoreMonitor = droneStore.startMonitoring(deviceInfoDidChange: {
            if self.currentDrone == $0 {
                self.autoConnection.notifyDroneStateChanged()
            }
        }, storeDidChange: {
            self.deviceListDidChange()
        })

        remoteControlStoreMonitor = rcStore.startMonitoring(deviceInfoDidChange: {
            if self.currentRc == $0 {
                self.autoConnection.notifyRemoteControlStateChanged()
            }
        }, storeDidChange: {
            self.deviceListDidChange()
        })

        // trigger the autoconnection with the current state of the stores
        deviceListDidChange()

        autoConnection.notifyUpdated()
    }

    /// Stops the auto connection.
    private func doStopAutoConnection() {
        droneStoreMonitor?.stop()
        remoteControlStoreMonitor?.stop()
        autoConnectionStarted = false
        autoConnection.update(state: .stopped).update(drone: nil).update(remoteControl: nil).notifyUpdated()
        ULog.d(.autoConnectEngineTag, "Stopped auto connection.")
    }

    /// Notified when a device is either added, removed or changes. Triggers an auto-connection pass.
    ///
    /// - Note: this method is merely an optimization to prevent immediate recursion into `processDeviceList()`
    ///  while devices are connected or disconnected by that method.
    ///  The auto-connection would (and should) work the same if `processDeviceList` was called directly.
    private func deviceListDidChange() {
        if processing {
            shouldProcessAgain = true
        } else {
            processing = true
            repeat {
                shouldProcessAgain = false
                processDeviceList()
            } while shouldProcessAgain
            processing = false
        }
    }

    /// Called when device list (either rc or drone) changed.
    /// This function applies the autoconnection algorithm to the visible devices.
    ///
    /// Updates the current drone and remote control of the facility.
    private func processDeviceList() {
        autoConnectRemoteControl()

        autoConnectDrone()

        // publish currently auto-connected devices
        autoConnection.update(remoteControl: currentRc).update(drone: currentDrone).notifyUpdated()
    }

    /// Tries to connect to the best visible remote control
    private func autoConnectRemoteControl() {
        // if at least one rc is visible, pick the best one
        if let bestRc = getBestRc() {
            // the best one is elected for auto-connection
            currentRc = bestRc

            // ensure best rc is connecting or connected (if possible)
            if !bestRc.isAtLeastConnecting {
                if bestRc.canBeConnected {
                    _ = bestRc.connect(connector: bestRc.oneOfTheBestConnector, password: nil)
                }
                ULog.d(.autoConnectEngineTag, "Not connected to the best rc \(bestRc), try to connect to it.")
            } else if !bestRc.usesOneOfTheBestConnector && bestRc.canBeDisconnected {
                // disconnect rc if not connected with best connector. Next pass will reconnect with proper connector
                _ = bestRc.disconnect()
                ULog.d(.autoConnectEngineTag, "Disconnecting from \(bestRc) because it is not connected through the " +
                    "best connector.")
            }
            // ensure all other visible remote controls are disconnected
            rcStore.getDevices().filter { $0.visible && $0 != bestRc }.forEach { rcToDisconnect in
                if rcToDisconnect.canBeDisconnected {
                    if droneToReconnect == nil {
                        droneToReconnect = dronesConnectedWithRemoteControl(rcToDisconnect).first
                        ULog.d(.autoConnectEngineTag, "Will try later to connect to drone " +
                            "\(String(describing: droneToReconnect)).")
                    }
                    _ = rcToDisconnect.disconnect()
                    ULog.d(.autoConnectEngineTag, "Disconnect from \(rcToDisconnect) because it is not the best rc.")
                }
            }
        } else {
            // if no rc are visible, there is no remote control elected for auto-connection
            currentRc = nil
        }
    }

    /// Tries to connect to the best visible drone
    ///
    /// - Note: it should be called after having set the currentRc since this algorithm use this variable
    private func autoConnectDrone() {
        if let currentRc = currentRc { // Drone with RC auto-connection
            // first disconnect all drones that are not connected or connecting to the RC
            let dronesToDisconnect = droneStore.getDevices().filter {
                if let activeConnector = $0.activeConnector {
                    return activeConnector.uid != currentRc.uid
                }
                return false
            }
            var bestDroneDisconnected: DroneCore?
            dronesToDisconnect.forEach { droneToDisconnect in
                if droneToDisconnect.canBeDisconnected {
                    if let bestConnector = bestDroneDisconnected?.oneOfTheBestConnector {
                        if droneToDisconnect.oneOfTheBestConnector!.betterThan(bestConnector) {
                            bestDroneDisconnected = droneToDisconnect
                        }
                    } else {
                        bestDroneDisconnected = droneToDisconnect
                    }
                    _ = droneToDisconnect.disconnect()
                    ULog.d(.autoConnectEngineTag, "Disconnect from \(droneToDisconnect) because it is not connected " +
                        "through \(currentRc).")
                }
            }
            if droneToReconnect == nil {
                droneToReconnect = bestDroneDisconnected
                ULog.d(.autoConnectEngineTag, "Will try later to connect to drone " +
                    "\(String(describing: droneToReconnect)).")
            }

            // if the current rc is already connected to a drone, use it as current drone
            let connectedDronesToCurrentRc = dronesConnectedWithRemoteControl(currentRc)
            if !connectedDronesToCurrentRc.isEmpty {
                currentDrone = connectedDronesToCurrentRc.first
                droneToReconnect = nil
                ULog.d(.autoConnectEngineTag, "\(currentRc) is already connected to \(currentDrone!).")
            } else if currentRc.connected { // if the current rc is connected
                // if the drone to reconnect is visible through the current rc
                if let droneToReconnectRemoteConnector = droneToReconnect?.getRemoteConnector(from: currentRc) {
                    _ = droneToReconnect?.connect(connector: droneToReconnectRemoteConnector, password: nil)
                    ULog.d(.autoConnectEngineTag, "Reconnect \(String(describing: droneToReconnect)) to \(currentRc).")
                    currentDrone = droneToReconnect
                    droneToReconnect = nil
                } else {
                    // if drone to reconnect is not visible through the rc right when rc is connected, wait for it to be
                    // visible
                    currentDrone = nil
                }
            }
        } else if let bestDrone = getBestDrone() {    // Drone without rc auto-connection
            currentDrone = bestDrone

            // ensure best drone is connecting or connected (if possible)
            if !bestDrone.isAtLeastConnecting {
                if bestDrone.canBeConnected {
                    _ = bestDrone.connect(connector: bestDrone.oneOfTheBestConnector, password: nil)
                }
                ULog.d(.autoConnectEngineTag, "Not connected to the best drone \(bestDrone), try to connect to it.")
            } else if !bestDrone.usesOneOfTheBestConnector && bestDrone.canBeDisconnected {
                // disconnect drone if not connected with best connector. Next pass will reconnect with proper connector
                _ = bestDrone.disconnect()
                ULog.d(.autoConnectEngineTag, "Disconnecting from \(bestDrone) because it is not connected through " +
                    "the best connector.")
            }
            // ensure all other visible drones are disconnected
            droneStore.getDevices().filter { $0.visible && $0 != bestDrone }.forEach { droneToDisconnect in
                if droneToDisconnect.canBeDisconnected {
                    _ = droneToDisconnect.disconnect()
                }
                ULog.d(.autoConnectEngineTag, "Disconnect from \(droneToDisconnect) because it is not the best drone.")
            }
        } else {
            // if no drone are visible, there is no drone elected for auto-connection
            currentDrone = nil
        }
    }

    /// Gets all the drones connected/connecting/disconnecting through a given remote control
    ///
    /// - Parameter rc: the remote control
    /// - Returns: an array of all drones that are connected/connecting/disconnecting through the remote control
    private func dronesConnectedWithRemoteControl(_ rc: RemoteControlCore) -> [DroneCore] {
        return droneStore.getDevices().filter { $0.activeConnector?.uid == rc.uid }
    }

    /// Gets the best remote control.
    ///
    /// The best one is the remote control that has the best connector.
    /// In case of equality, this function will return one of the bests.
    ///
    /// - Returns: one of the best remote control if it found one, nil otherwise.
    private func getBestRc() -> RemoteControlCore? {
        return rcStore.getDevices().reduce(nil, { (bestRcTmp, rc) -> RemoteControlCore? in
            if let bestConnector = rc.stateHolder.state.oneOfTheBestConnector {
                if let bestRcTmp = bestRcTmp {
                    if bestConnector.betterThan(bestRcTmp.stateHolder.state.oneOfTheBestConnector!) {
                        return rc
                    }
                } else {
                    return rc
                }
            }
            return bestRcTmp
        })
    }

    /// Chooses between two drones. Prefers the last connected
    ///
    /// - Parameters:
    ///   - drone1: drone1 for the choice
    ///   - drone2: drone2 for the choice
    /// - Returns: returns the latest connected drone if any, drone2 otherwise
    private func prefersTheLatestCurrentDrone(drone1: DroneCore, drone2: DroneCore) -> DroneCore? {
        if drone1 == latestCurrentDrone {
            return drone1
        } else {
            return drone2
        }
    }

    /// Gets the best drone.
    ///
    /// The best one is the drone that has the best connector.
    /// In case of equality, this function will return one of the bests which is connecting/connected.
    ///
    /// - Returns: one of the best drone if it found one, nil otherwise.
    private func getBestDrone() -> DroneCore? {
        return droneStore.getDevices().reduce(nil, { (bestDroneTmp, drone) -> DroneCore? in
            if let bestConnector = drone.stateHolder.state.oneOfTheBestConnector {
                if let bestDroneTmp = bestDroneTmp {
                    let bestConnectorOfBestDrone = bestDroneTmp.stateHolder.state.oneOfTheBestConnector!
                    if bestConnector == bestConnectorOfBestDrone {
                        if (bestDroneTmp.stateHolder.state.connectionState == .connecting ||
                            bestDroneTmp.stateHolder.state.connectionState == .connected) &&
                            (drone.stateHolder.state.connectionState != .connecting &&
                                drone.stateHolder.state.connectionState != .connected) {
                            return bestDroneTmp
                        } else {
                            return prefersTheLatestCurrentDrone(drone1: bestDroneTmp, drone2: drone)
                        }
                    } else if bestConnector.betterThan(bestConnectorOfBestDrone) {
                        if bestConnector == bestConnectorOfBestDrone &&
                            (bestDroneTmp.stateHolder.state.connectionState == .connecting ||
                                bestDroneTmp.stateHolder.state.connectionState == .connected) {
                            return bestDroneTmp
                        }
                        return drone
                    }
                } else {
                    return drone
                }
            }
            return bestDroneTmp
        })
    }

    /// Gets the list of connecting or connected drones.
    ///
    /// - Returns: a list of all drones that are currently connecting or connected.
    private func getConnectingOrConnectedDrones() -> [DroneCore] {
        return droneStore.getDevices().filter {
            $0.stateHolder.state.connectionState == .connecting || $0.stateHolder.state.connectionState == .connected
        }
    }

    /// Gets the list of connecting or connected remote control.
    ///
    /// - Returns: a list of all remote controls that are currently connecting or connected.
    private func getConnectingOrConnectedRcs() -> [RemoteControlCore] {
        return rcStore.getDevices().filter {
            $0.stateHolder.state.connectionState == .connecting || $0.stateHolder.state.connectionState == .connected
        }
    }

    /// Disconnect all devices that can be disconnected.
    private func disconnectAllDevices() {
        ULog.d(.autoConnectEngineTag, "Disconnection all devices.")
        rcStore.getDevices().forEach {
            if $0.stateHolder.state.canBeDisconnected {
                _ = $0.disconnect()
            }
        }
        droneStore.getDevices().forEach {
            if $0.stateHolder.state.canBeDisconnected {
                _ = $0.disconnect()
            }
        }
    }

    /// Disconnects all connecting or connected drones that are directly connected (their connector type is local).
    ///
    /// Also sets `latestDirectlyConnectedDrone` with the last connected/connecting drone in order to try
    /// to connect to it when the rc connection will be done
    private func disconnectAllDirectlyConnectedDrones() {
        getConnectingOrConnectedDrones().filter {
            $0.stateHolder.state.canBeDisconnected && $0.stateHolder.state.activeConnector!.connectorType == .local
            }.forEach {
                droneToReconnect = $0
                _ = $0.disconnect()
        }
    }

    /// Disconnect all remote controls that can be disconnected
    private func disconnectRcs() {
        rcStore.getDevices().filter { $0.stateHolder.state.canBeDisconnected }
            .forEach {
                _ = $0.disconnect()
        }
    }
}

/// Extension of the Autoconnection engine that implements the autoconnection facility backend.
extension AutoConnectionEngine: AutoConnectionBackend {
    public func startAutoConnection() -> Bool {
        guard !autoConnectionStarted else {
            return false
        }

        doStartAutoConnection()
        return true
    }

    public func stopAutoConnection() -> Bool {
        guard autoConnectionStarted else {
            return false
        }

        doStopAutoConnection()
        return true
    }
}

/// Private extension of DeviceCore that add helper computed properties
private extension DeviceCore {
    /// Whether or not the device is connecting or connected
    var isAtLeastConnecting: Bool {
        let connectionState = stateHolder.state.connectionState
        return connectionState == .connecting || connectionState == .connected
    }

    /// Whether the device is currently connected
    var connected: Bool {
        return stateHolder.state.connectionState == .connected
    }

    /// Whether the device can be connected
    var canBeConnected: Bool {
        return stateHolder.state.canBeConnected
    }

    /// Whether the device can be disconnected
    var canBeDisconnected: Bool {
        return stateHolder.state.canBeDisconnected
    }

    /// Gets one of the best connector.
    /// If there is at least one connector, the returned value won't be nil.
    var oneOfTheBestConnector: DeviceConnector? {
        return stateHolder.state.oneOfTheBestConnector
    }

    /// Active connector
    var activeConnector: DeviceConnector? {
        return stateHolder.state.activeConnector
    }

    /// Available connectors
    var connectors: [DeviceConnector] {
        return stateHolder.state.connectors
    }

    /// Whether the device is currently visible. (If the list of its connectors is not empty).
    var visible: Bool {
        return !connectors.isEmpty
    }

    /// Whether the current active connector is the best one.
    /// If the device is not currently visible or connected, returns false.
    var usesOneOfTheBestConnector: Bool {
        if let activeConnector = activeConnector, let oneOfTheBestConnector = oneOfTheBestConnector {
            return activeConnector.betterOrEqualTo(oneOfTheBestConnector)
        }
        return false
    }

    /// Gets a remote connector provided by the given remote control
    ///
    /// - Parameter remoteControl: the remote control
    /// - Returns: a remote control connector or nil if the device can't be connected or if it is not visible through
    ///   the given remote control
    func getRemoteConnector(from remoteControl: RemoteControlCore) -> DeviceConnector? {
        return (canBeConnected) ? connectors.filter { $0.uid == remoteControl.uid }.first : nil
    }
}
