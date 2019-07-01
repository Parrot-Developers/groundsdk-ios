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

/// Callback called when the device controller close itself
protocol DeviceControllerStoppedListener: class {
    /// Device controller stopped itself
    ///
    /// - Parameter uid: device uid
    func onSelfStopped(uid: String)
}

/// Provides connection for a device.
class DeviceProvider: NSObject {

    /// GroundSdk API connector that this provider represents.
    private(set) var connector: DeviceConnectorCore

    /// Parent connection provider of this connection provider.
    /// Nil if there is no parent connection provider.
    private(set) var parent: DeviceProvider?

    /// Constructor
    ///
    /// - Parameter connector: device connector that this provider represents
    init(connector: DeviceConnectorCore) {
        self.connector = connector
    }

    /// Connects the device managed by the given controller
    ///
    /// - Parameters:
    ///    - deviceController: device controller whose device must be connected
    ///    - password: password to use for authentication, an empty string if no password are required
    ///
    /// - Returns: true if the connect operation was successfully initiated,
    func connect(deviceController: DeviceController, password: String) -> Bool {
        return false
    }

    /// Disconnects the device managed by the given controller
    ///
    /// As a provider may not support the disconnect operation, this method provides a default implementation that
    /// return false. Subclasses that need to support the disconnect operation may override this method to do so.
    ///
    /// - Parameter deviceController: device controller whose device must be disconnected
    ///
    /// - Returns: true if the disconnect operation was successfully initiated
    func disconnect(deviceController: DeviceController) -> Bool {
        return false
    }

    /// Forgets the device managed by the given controller.
    ///
    /// As a provider may not support the forget operation, this method provides a default implementation that
    /// does nothing. Subclasses that need to support the forget operation may override this method to do so.
    ///
    /// - Parameter deviceController: device controller whose device must be forgotten
    func forget(deviceController: DeviceController) {
    }

    /// Notifies that some conditions that control data synchronization allowance have changed.
    ///
    /// This method allows proxy device providers to know when data sync allowance conditions concerning
    /// the device they proxy change, and take appropriate measures.
    ///
    /// Default implementation does nothing.
    ///
    /// - Parameter deviceController: device controller whose data sync allowance conditions changed
    public func dataSyncAllowanceMightHaveChanged(deviceController: DeviceController) {
    }
}

// The type returned by `subscribeNoAckCommandEncoder()`
protocol RegisteredNoAckCmdEncoder {
    /// Unregister an `ArsdkCommandEncoder` previously registered in the NoAckCmdLoop
    ///
    /// - Note: the loop is running only if one (or more) commandEncoder is (are) present.
    func unregister()
}

/// Device controller protocol backend.
///
/// Used by the controller, after link connection is established, in order to send commands to the associated device.
protocol DeviceControllerBackend: class {

    /// Sends a command to the controller device.
    ///
    /// - Parameter command: command to send
    ///
    /// - Returns: true if the command could be sent
    func sendCommand(_ encoder: ((OpaquePointer) -> Int32))

    /// Creates the NoAck command loop of the controlled device.
    ///
    /// - Parameter periodMs: loop period, in milliseconds
    /// - Note: Useful only for drone devices.
    func createNoAckCmdLoop(periodMs: Int32)

    /// Delete the piloting command loop of the controlled device.
    ///
    /// - Note: Useful only for drone devices. This method unregister any ArsdkCommandEncoder previously registered
    /// in the NoAckLoop
    func deleteNoAckCmdLoop()

    /// Subscribe an `ArsdkCommandEncoder` in the NoAckCmdLoop (see: `createNoAckCmdLoop()`)
    /// The Encoder will be stored and executed in the NoAckLoop.
    ///
    /// To Unsubscribe, call the `unregister()` function  of the returned object `RegisteredNoAckCmdEncoder`
    /// You must keep a strong reference to this object and call the unregister() function in order to stop the command.
    /// However, it is also possible to directly call the function `deleteNoAckCmdLoop` to stop all the commands.
    ///
    /// - Note: The loop is running only if one (or more) commandEncoder is (are) present.
    /// - Parameter encoder: non ack command encoder.
    /// - Returns: an object that will be used for unsubscribe
    func subscribeNoAckCommandEncoder(encoder: NoAckCmdEncoder) -> RegisteredNoAckCmdEncoder

    /// Creates a tcp proxy and gets the address and port to use to reach the given port on the given model
    ///
    /// - Parameters:
    ///   - model: the model to access
    ///   - port: the port to access
    ///   - completion: completion callback that is called when the tcp proxy is created (or on error).
    ///   - tcpProxy: the proxy object. Nil if an error occurred.
    ///   - proxyAddress: the address to use in order to reach the given `port`. Nil if an error occurred.
    ///   - proxyPort: the port to use in order to reach the given `port`. If `proxyAddress` is nil, this value should
    ///                be ignored.
    func createTcpProxy(
        model: DeviceModel, port: Int,
        completion: @escaping (_ tcpProxy: ArsdkTcpProxy?, _ proxyAddress: String?, _ proxyPort: Int) -> Void)

    /// Destroy the tcp proxy in pomp thread
    ///
    /// - Parameter block: block that needs to be executed in pomp thread to destroy tcpProxy
    func destroyTcpProxy(block: @escaping() -> Void)

    /// Create a video stream instance from a url.
    ///
    /// - Parameters:
    ///    - url: stream url
    ///    - track: stream track
    ///    - listener: the listener that should be called for stream events
    /// - Returns: a new instance of a stream
    func createVideoStream(url: String, track: String, listener: SdkCoreStreamListener) -> ArsdkStream

    /// List all medias stored in the device
    ///
    /// - Parameters:
    ///   - completion: closure called when the media list has been retrieved, or if there is an error
    ///   - model: actual model to access media of. Must be drone model when connected through a proxy
    /// - Returns: low level request, that can be used to cancel the browse request
    func browseMedia(model: DeviceModel, completion: @escaping ArsdkMediaListCompletion) -> ArsdkRequest

    /// Download a media thumbnail
    ///
    /// - Parameters:
    ///   - media: media to download the thumbnail
    ///   - model: actual model to access media of. Must be drone model when connected through a proxy
    ///   - completion: closure called when the thumbnail has been downloaded or if there is an error
    /// - Returns: low level request, that can be used to cancel the download request
    func downloadMediaThumbnail(_ media: ArsdkMedia, model: DeviceModel,
                                completion: @escaping ArsdkMediaDownloadThumbnailCompletion) -> ArsdkRequest

    /// Download a media
    ///
    /// - Parameters:
    ///   - media: media to download
    ///   - model: actual model to access media of. Must be drone model when connected through a proxy
    ///   - format: requested format
    ///   - destDirectoryPath: downloaded media destination directory path
    ///   - progress: progress closure
    ///   - completion: completion closure
    /// - Returns: low level request, that can be used to cancel the download request
    func downloadMedia(_ media: ArsdkMedia, model: DeviceModel, format: ArsdkMediaResourceFormat,
                       destDirectoryPath: String, progress: @escaping ArsdkMediaDownloadProgress,
                       completion: @escaping ArsdkMediaDownloadCompletion) -> ArsdkRequest

    /// Delete a media
    ///
    /// - Parameters:
    ///   - media: media to delete
    ///   - model: actual model to access media of. Must be drone model when connected through a proxy
    ///   - completion: closure called when the media has been deleted or if there is an error
    func deleteMedia(_ media: ArsdkMedia, model: DeviceModel,
                     completion: @escaping ArsdkMediaDeleteCompletion) -> ArsdkRequest

    /// Update the controlled device with a given firmware
    ///
    /// - Parameters:
    ///   - file: Path of the firmware file
    ///   - model: actual model to access media of. Must be drone model when connected through a proxy
    ///   - progress: progress closure
    ///   - completion: completion closure
    /// - Returns: low level request that can be used to cancel the upload request
    func update(withFile file: String, model: DeviceModel, progress: @escaping ArsdkUpdateProgress,
                completion: @escaping ArsdkUpdateCompletion) -> ArsdkRequest

    /// Uploads a given file on a given server type of a drone
    ///
    /// - Parameters:
    ///   - srcPath: local path of the file
    ///   - dstPath: destination path of the file
    ///   - model: model of the device
    ///   - serverType: type of the server on which to upload
    ///   - progress: progress block
    ///   - completion: completion block
    /// - Returns: low level request that can be used to cancel the upload request
    func upload(file srcPath: String, to dstPath: String, model: DeviceModel, serverType: ArsdkFtpServerType,
                progress: @escaping ArsdkFtpRequestProgress,
                completion: @escaping ArsdkFtpRequestCompletion) -> ArsdkRequest

    /// Download crashmls from the controlled device
    ///
    /// - Parameters:
    ///   - path: Path where crashmls will be downloaded
    ///   - model: actual device model to access of crashmls.
    ///            Must be drone model when connected through a proxy
    ///   - progress: progress closure ; one crashml is downloaded.
    ///   - completion: completion closure
    /// - Returns: low level request, that can be used to cancel the download request
    func downloadCrashml(path: String, model: DeviceModel,
                         progress: @escaping ArsdkCrashmlDownloadProgress,
                         completion: @escaping ArsdkCrashmlDownloadCompletion) -> ArsdkRequest

    /// Download flight logs from the controlled device
    ///
    /// - Parameters:
    ///   - path: Path where flight logs will be downloaded
    ///   - model: actual device model to access of flight logs.
    ///            Must be drone model when connected through a proxy
    ///   - progress: progress closure ; one flight log is downloaded.
    ///   - completion: completion closure
    /// - Returns: low level request, that can be used to cancel the download request
    func downloadFlightLog(path: String, model: DeviceModel,
                           progress: @escaping ArsdkFlightLogDownloadProgress,
                           completion: @escaping ArsdkFlightLogDownloadCompletion) -> ArsdkRequest

    /// Requests to receive remote control black box data.
    ///
    /// - Parameters:
    ///   - buttonAction: remote controller button action callback
    ///   - pilotingInfo: remote controller piloting info callback
    /// - Returns: an ArsdkRequest that can be canceled
    func subscribeToRcBlackBox(buttonAction: @escaping ArsdkRcBlackBoxButtonActionCb,
                               pilotingInfo: @escaping ArsdkRcBlackBoxPilotingInfoCb) -> ArsdkRequest

}

/// Class that store a connection session state in an object.
/// Having an object that is created on each connection session allows timeout closure that weak capture it to ensure
/// checking state of the correct connect session
class ControllerConnectionSession {
    /// Connection state of the session
    enum State {
        /// Controller is fully disconnected
        case disconnected

        /// Controller is connecting
        case connecting

        /// Controller is creating the http client of the device
        case creatingDeviceHttpClient

        /// Controller is getting all settings of the device
        case gettingAllSettings

        /// Controller is getting all states of the device
        case gettingAllStates

        /// Controller is fully connected to the device
        case connected

        /// Controller is disconnecting the device
        case disconnecting
    }
    var state: State

    private unowned let deviceController: DeviceController

    /// Constructor
    ///
    /// Will set the initial state as `.disconnected`.
    ///
    /// - Parameter deviceController: the device controller owning this object (unowned)
    convenience init(deviceController: DeviceController) {
        self.init(initialState: .disconnected, deviceController: deviceController)
    }

    /// Constructor
    ///
    /// - Parameters:
    ///   - initialState: the initial state of the connection
    ///   - deviceController: the device controller owning this object (unowned)
    init(initialState: State, deviceController: DeviceController) {
        state = initialState
        self.deviceController = deviceController
    }
}

/// Base class for a device controller
class DeviceController: NSObject {

    /// Non-acknowledged command loop period, in milliseconds. `0` if disabled.
    private let noAckLoopPeriod: Int32

    /// Timeout waiting either the all states or all settings from the drone. In seconds
    private let kTimeoutInSec = 20.0

    /// Device managed by this drone controller
    private(set) var device: DeviceCore!

    /// Device representation in the persistent store
    let deviceStore: SettingsStore

    /// Device preset in the persistent store
    private(set) var presetStore: SettingsStore!

    /// Device model
    let deviceModel: DeviceModel

    /// Registered providers for this device controller, by connector uid
    private var providers = [String: DeviceProvider]()

    /// Current provider used to connect this device
    private(set) weak var activeProvider: DeviceProvider?

    /// The tcp proxy if it exists.
    /// Always nil when not connected.
    private var arsdkTcpProxy: ArsdkTcpProxy?

    /// Drone http server
    var droneServer: DroneServer?

    /// All attached component controllers
    var componentControllers = [DeviceComponentController]()

    /// Connection session of the controller
    private(set) var connectionSession: ControllerConnectionSession!

    /// Arsdk engine instance
    private(set) unowned var engine: ArsdkEngine

    /// Device controller backend, not null when device controller connection is started
    private(set) var backend: DeviceControllerBackend?

    /// Callback called when the device controller close itself
    private weak var stopListener: DeviceControllerStoppedListener?

    /// The current black box session. Nil if black box support is disabled or device is not protocol-connected
    var blackBoxSession: BlackBoxSession?

    /// get all settings command encoder
    var getAllSettingsEncoder: ((OpaquePointer) -> Int32)!

    /// get all states command encoder
    var getAllStatesEncoder: ((OpaquePointer) -> Int32)!

    /// Send the current date and time to the managed device
    var sendDateAndTime: (() -> Void)!

    /// `true` when the controller must attempt to reconnect the device after disconnection.
    var autoReconnect = false

    /// Computed property that represents whether the background data is allowed or not.
    /// This computed property might be overriden by subclasses if they have custom conditions to allow or restrict
    /// background data. Overrides **must** call super.
    var dataSyncAllowed: Bool {
        return _dataSyncAllowed
    }

    /// Private implementation of the data sync allowance.
    /// It will be changed according to the connection state. It is true as soon as the device is connected, and set
    /// back to false when device is disconnected.
    private var _dataSyncAllowed = false

    /// Memorize the previous data sync allowance value in order to notify only if it has changed.
    private var previousDataSyncAllowed = false

    /// Constructor
    ///
    /// - Parameters:
    ///    - engine: arsdk engine instance
    ///    - deviceUid: device uid
    ///    - deviceModel: device model
    ///    - nonAckLoopPeriod: non-acknowledged command loop period (in ms), `0` to disable (0 is default value)
    ///    - deviceFactory: closure to create the device managed by this controller
    init(engine: ArsdkEngine, deviceUid: String, deviceModel: DeviceModel, noAckLoopPeriod: Int32 = 0,
         deviceFactory: (_ delegate: DeviceCoreDelegate) -> DeviceCore) {

        self.noAckLoopPeriod = noAckLoopPeriod
        self.engine = engine
        self.deviceModel = deviceModel
        // load device dictionary
        self.deviceStore = SettingsStore(dictionary: engine.persistentStore.getDevice(uid: deviceUid))

        super.init()

        connectionSession = ControllerConnectionSession(deviceController: self)

        // gets presets
        let presetId: String
        if let currentPresetId: String = deviceStore.read(key: PersistentStore.devicePresetUid) {
            presetId = currentPresetId
        } else {
            presetId = PersistentStore.presetKey(forModel: deviceModel)
        }
        var presetDict: PersistentDictionary!
        presetDict = engine.persistentStore.getPreset(uid: presetId) { [unowned self] in
            presetDict.reload()
            self.componentControllers.forEach { component in component.presetDidChange() }
        }
        presetStore = SettingsStore(dictionary: presetDict)
        // create the device
        self.device = deviceFactory(self)
        if let firmwareVersionStr: String = deviceStore.read(key: PersistentStore.deviceFirmwareVersion),
            let firmwareVersion = FirmwareVersion.parse(versionStr: firmwareVersionStr) {
            self.device.firmwareVersionHolder.update(version: firmwareVersion)
        }
        self.device.stateHolder.state.update(persisted: !deviceStore.new).notifyUpdated()
    }

    /// Start the controller
    ///
    /// - Parameter stopListener: listener called if the device controller stops itself
    /// - Note: custom actions after the start should be defined in the subclasses
    final func start(stopListener: DeviceControllerStoppedListener) {
        ULog.d(.ctrlTag, "Starting deviceController \(device.uid)]")
        self.stopListener = stopListener
        controllerDidStart()
    }

    /// Stops the controller
    ///
    /// - Note: custom actions after the stop should be defined in the subclasses
    final func stop() {
        ULog.d(.ctrlTag, "Stopping deviceController \(device.uid)]")
        controllerDidStop()
    }

    /// Add a new provider for this device
    ///
    /// - Parameter provider: provider to add
    final func addProvider(_ provider: DeviceProvider) {
        if providers.updateValue(provider, forKey: provider.connector.uid) != provider {
            providersDidChange()
        }

        if autoReconnect && activeProvider == nil {
            _ = doConnect(provider: provider, password: "", cause: .connectionLost)
        }

        device.stateHolder.state.notifyUpdated()
    }

    /// Remove a provider of this device
    ///
    /// - Parameter provider: provider to remove
    final func removeProvider(_ provider: DeviceProvider) {
        if let removedProvider = providers.removeValue(forKey: provider.connector.uid) {
            if removedProvider == activeProvider {
                activeProvider = nil
                autoReconnect = true
                transitToDisconnectedState(withCause: .connectionLost)
            }
            providersDidChange()
            if providers.isEmpty && deviceStore.new {
                stopSelf()
            }

            device.stateHolder.state.notifyUpdated()
        }
    }

    /// Registered providers did change, update device connectors and known state
    ///
    /// - Note: Note that this method does not publish changes made to the device state.
    ///   Caller has the responsibility to call `notifyUpdated`.
    final func providersDidChange() {
        device.stateHolder.state.update(connectors: providers.values.map({$0.connector}))
            .update(activeConnector: activeProvider?.connector)
    }

    /// Stop self
    private final func stopSelf() {
        stop()
        stopListener?.onSelfStopped(uid: device.uid)
    }

    /// Connect this controller using the given provider
    ///
    /// - Parameters:
    ///     - provider: provider to use to connect this device
    ///     - password: if the provider supports password, the password to use, else an empty string
    ///     - cause: cause of this connection request
    /// - Returns: true if the request has been process
    final func doConnect(provider: DeviceProvider, password: String, cause: DeviceState.ConnectionStateCause) -> Bool {
        connectionSession = ControllerConnectionSession(initialState: .connecting, deviceController: self)
        activeProvider = provider
        device.stateHolder.state?.update(activeConnector: activeProvider!.connector)
            .update(connectionState: .connecting, withCause: cause).notifyUpdated()
        return activeProvider!.connect(deviceController: self, password: password)
    }

    /// Disconnects this controller.
    ///
    /// - Parameter cause: cause of this disconnection request
    /// - Returns: true if the disconnection process has started, false otherwise.
    final func doDisconnect(cause: DeviceState.ConnectionStateCause) -> Bool {
        if let activeProvider = activeProvider {
            if activeProvider.disconnect(deviceController: self) {
                device.stateHolder.state?.update(connectionState: .disconnecting,
                                              withCause: cause).notifyUpdated()
                connectionSession.state = .disconnecting
                return true
            }
        }
        return false
    }

    /// Send a command to the drone
    ///
    /// - Parameter encoder: encoder of the command to send
    final func sendCommand(_ encoder: ((OpaquePointer) -> Int32)!) {
        if let backend = backend {
            backend.sendCommand(encoder)
        } else {
            ULog.w(.ctrlTag, "sendCommand called without backend")
        }
    }

    /// List all medias stored in the device
    ///
    /// - Parameter completion: closure called when the media list has been retrieved, or if there is an error
    /// - Returns: low level request, that can be used to cancel the browse request
    final func browseMedia(completion: @escaping ArsdkMediaListCompletion) -> ArsdkRequest? {
        if let backend = backend {
            return backend.browseMedia(model: deviceModel, completion: completion)
        } else {
            ULog.w(.ctrlTag, "browseMedia called without backend")
        }
        return nil
    }

    /// Download media thumbnail
    ///
    /// - Parameters:
    ///   - media: media to download the thumbnail
    ///   - completion: closure called when the thumbnail has been downloaded or if there is an error
    /// - Returns: low level request, that can be used to cancel the download request
    final func downloadMediaThumbnail(_ media: ArsdkMedia,
                                      completion: @escaping ArsdkMediaDownloadThumbnailCompletion) -> ArsdkRequest? {
        if let backend = backend {
            return backend.downloadMediaThumbnail(media, model: deviceModel, completion: completion)
        } else {
            ULog.w(.ctrlTag, "downloadMediaThumbnail called without backend")
        }
        return nil
    }

    /// Delete a media
    ///
    /// - Parameters:
    ///   - media: media to delete
    ///   - completion: closure called when the media has been deleted or if there is an error
    /// - Returns: low level request, that can be used to cancel the delete request
    final func deleteMedia(_ media: ArsdkMedia, completion: @escaping ArsdkMediaDeleteCompletion) -> ArsdkRequest? {
        if let backend = backend {
            return backend.deleteMedia(media, model: deviceModel, completion: completion)
        } else {
            ULog.w(.ctrlTag, "deleteMedia called without backend")
        }
        return nil
    }

    final func downloadMedia(_ media: ArsdkMedia, format: ArsdkMediaResourceFormat,
                             destDirectoryPath: String, progress: @escaping ArsdkMediaDownloadProgress,
                             completion: @escaping ArsdkMediaDownloadCompletion) -> ArsdkRequest? {
        if let backend = backend {
            return backend.downloadMedia(
                media, model: deviceModel, format: format, destDirectoryPath: destDirectoryPath,
                progress: progress, completion: completion)
        } else {
            ULog.w(.ctrlTag, "downloadMedia called without backend")
        }
        return nil
    }

    /// Update the controlled device with a given firmware file
    ///
    /// - Parameters:
    ///   - file: the firmware file path
    ///   - progress: progress closure
    ///   - completion: completion closure
    /// - Returns: low level request, that can be used to cancel the upload request
    final func update(withFile file: String, progress: @escaping ArsdkUpdateProgress,
                      completion: @escaping ArsdkUpdateCompletion) -> CancelableCore? {
        if let backend = backend {
            return backend.update(
                withFile: file, model: deviceModel, progress: progress, completion: { [weak self] status in
                    completion(status)
                    if status == .ok {
                        self?.firmwareDidUpload()
                    }
            })
        } else {
            ULog.w(.ctrlTag, "update firmware called without backend")
        }
        return nil
    }

    /// Uploads a given file on a given server type of a drone
    ///
    /// - Parameters:
    ///   - file: local path of the file
    ///   - to: destination path of the file
    ///   - serverType: type of the server on which to upload
    ///   - progress: progress block
    ///   - completion: completion block
    /// - Returns: low level request that can be used to cancel the upload request
    final func upload(
        file srcPath: String, to dstPath: String, serverType: ArsdkFtpServerType,
        progress: @escaping ArsdkFtpRequestProgress, completion: @escaping ArsdkFtpRequestCompletion) -> ArsdkRequest? {
        if let backend = backend {
            return backend.upload(file: srcPath, to: dstPath, model: deviceModel, serverType: serverType,
                                  progress: progress, completion: completion)
        } else {
            ULog.w(.ctrlTag, "upload file called without backend")
        }
        return nil
    }

    /// Download crashmls from the controlled device
    ///
    /// - Parameters:
    ///   - path: path where crashmls will be downloaded
    ///   - progress: progress closure
    ///   - completion: completion closure
    /// - Returns: low level request, that can be used to cancel the download request
    final func downloadCrashml(path: String, progress: @escaping ArsdkCrashmlDownloadProgress,
                               completion: @escaping ArsdkCrashmlDownloadCompletion) -> ArsdkRequest? {
        if let backend = backend {
            return backend.downloadCrashml(path: "\(path)/", model: deviceModel, progress: progress,
                                           completion: { status in
                    completion(status)
            })
        } else {
            ULog.w(.ctrlTag, "crashml download called without backend")
        }
        return nil
    }

    /// Download flight logs from the controlled device
    ///
    /// - Parameters:
    ///   - path: path where flight logs will be downloaded
    ///   - progress: progress closure
    ///   - completion: completion closure
    /// - Returns: low level request, that can be used to cancel the download request
    final func downloadFlightLog(path: String, progress: @escaping ArsdkFlightLogDownloadProgress,
                                 completion: @escaping ArsdkFlightLogDownloadCompletion) -> ArsdkRequest? {
        if let backend = backend {
            return backend.downloadFlightLog(path: "\(path)/", model: deviceModel, progress: progress,
                                           completion: { status in
                                            completion(status)
            })
        } else {
            ULog.w(.ctrlTag, "flight log download called without backend")
        }
        return nil
    }

    /// Signal that data sync allowance might have change.
    /// If it has actually changed, notify all components controllers about that change.
    final func dataSyncAllowanceMightHaveChanged() {
        if previousDataSyncAllowed != dataSyncAllowed {
            previousDataSyncAllowed = dataSyncAllowed

            activeProvider?.dataSyncAllowanceMightHaveChanged(deviceController: self)
            componentControllers.forEach {
                $0.dataSyncAllowanceChanged(allowed: dataSyncAllowed)
            }
        }
    }

    /// Make a transition in the connection state machine
    /// As the state machine is linear, we don't need the transition
    ///
    /// - Parameter cause: disconnection cause. Ignored if error is false.
    final func transitToNextConnectionState(withCause cause: DeviceState.ConnectionStateCause? = nil) {
        switch connectionSession.state {
        case .disconnected,
             .connecting:
            connectionSession.state = .creatingDeviceHttpClient
            ULog.i(.ctrlTag, "Device \(device.uid) connected, creating the device http client")
            protocolWillConnect()
            // can force unwrap backend since we are connecting
            backend!.createTcpProxy(model: deviceModel, port: 80) { proxy, address, port in
                self.arsdkTcpProxy = proxy
                if let address = address {
                    self.droneServer = DroneServer(address: address, port: port)
                }
                // even if the creation of the tcp proxy failed, transit to next connection state.
                self.transitToNextConnectionState()
            }
        case .creatingDeviceHttpClient:
            ULog.i(.ctrlTag, "Device \(device.uid) http client created, send date/time, getting AllSettings")
            connectionSession.state = .gettingAllSettings
            sendDateAndTime()
            sendGetAllSettings()
        case .gettingAllSettings:
            connectionSession.state = .gettingAllStates
            ULog.i(.ctrlTag, "Device \(device.uid) AllSettingsChanged, getting AllStates")
            sendGetAllStates()
        case .gettingAllStates:
            // state is first changed in order to let component controllers freely ask whether data sync is allowed,
            // but do not notify them yet (they will be notified right after).
            connectionSession.state = .connected
            ULog.i(.ctrlTag, "Device \(device.uid) AllStates, ready")
            _dataSyncAllowed = true
            // calling didConnect on all component controllers.
            protocolDidConnect()
            // now we can notify the component controllers about the new data sync allowance
            dataSyncAllowanceMightHaveChanged()
            // store the device
            deviceStore.write(key: PersistentStore.deviceName, value: device.nameHolder.name) // needed for the rc
            deviceStore.write(key: PersistentStore.deviceType, value: deviceModel.internalId)
            deviceStore.write(key: PersistentStore.devicePresetUid, value: presetStore.key)
            deviceStore.commit()
            device.stateHolder.state?.update(connectionState: .connected).update(persisted: true).notifyUpdated()
        default:
            break
        }
    }

    /// Make a transition in the connection state machine to the disconnected state
    ///
    /// - Parameter cause: disconnection cause. Ignored if error is false.
    ///
    /// - Note: Note that this method does not publish changes made to the device state.
    ///   Caller has the responsibility to call `notifyUpdated`.
    final func transitToDisconnectedState(withCause cause: DeviceState.ConnectionStateCause? = nil) {
        ULog.i(.ctrlTag, "Device \(device.uid) disconnected")
        if connectionSession.state == .connected {
            // if not in disconnected state, notify all component that we will disconnect
            protocolWillDisconnect()
        }
        if connectionSession.state != .disconnected {
            let formerState = connectionSession.state
            connectionSession.state = .disconnected

            if let backend = backend {
                backend.destroyTcpProxy {
                    self.arsdkTcpProxy = nil
                }
            }

            if formerState == .connected || formerState == .disconnecting {
                protocolDidDisconnect()
            }
            _dataSyncAllowed = false
            dataSyncAllowanceMightHaveChanged()
            if let cause = cause {
                device.stateHolder.state?.update(connectionState: .disconnected, withCause: cause)
            } else {
                device.stateHolder.state?.update(connectionState: .disconnected)
            }

            if !autoReconnect || activeProvider == nil ||
                !doConnect(provider: activeProvider!, password: "", cause: .connectionLost) {
                activeProvider = nil
                device.stateHolder.state?.update(activeConnector: nil)
            }
        }
    }

    /// Ask to the managed drone to get all its settings
    /// This step is ended when AllSettingsChanged event is received
    private final func sendGetAllSettings() {
        sendCommand(getAllSettingsEncoder)
        // if all settings ended has not been received within kTimeoutInSec, disconnect from the drone
        DispatchQueue.main
            .asyncAfter(deadline: DispatchTime.now() + kTimeoutInSec) { [unowned self, weak connectionSession] in
            if connectionSession?.state == .gettingAllSettings {
                _ = self.activeProvider?.disconnect(deviceController: self)
            }
        }
    }

    /// Ask to the managed drone to get all its states
    /// This step is ended when AllStatesChanged event is received
    private final func sendGetAllStates() {
        sendCommand(getAllStatesEncoder)
        // if all states ended has not been received within kTimeoutInSec, disconnect from the drone
        DispatchQueue.main
            .asyncAfter(deadline: DispatchTime.now() + kTimeoutInSec) { [unowned self, weak connectionSession] in
            if connectionSession?.state == .gettingAllStates {
                _ = self.activeProvider?.disconnect(deviceController: self)
            }
        }
    }

    // MARK: Methods managing connection state that subclass can implements

    /// Device controller did start
    func controllerDidStart() {
    }

    /// Device controller did stop
    func controllerDidStop() {
    }

    /// About to connect the device
    func protocolWillConnect() {
        componentControllers.forEach { component in component.willConnect() }
    }

    /// Device is connected (allSettings/States received)
    func protocolDidConnect() {
        // create the nonAckCommandLoop
        self.backend?.createNoAckCmdLoop(periodMs: noAckLoopPeriod)
        componentControllers.forEach { component in component.didConnect() }
    }

    /// About to disconnect protocol
    func protocolWillDisconnect() {
        componentControllers.forEach { $0.willDisconnect() }
    }

    /// Device is disconnected
    func protocolDidDisconnect() {
        componentControllers.forEach { component in component.didDisconnect() }
        self.backend?.deleteNoAckCmdLoop()
        blackBoxSession?.close()
        blackBoxSession = nil
    }

    /// A command has been received
    /// - Parameter command: received command
    func protocolDidReceiveCommand(_ command: OpaquePointer) {
        blackBoxSession?.onCommandReceived(command)
    }

    /// Firmware upload did success
    func firmwareDidUpload() { }
}

/// Extension of DeviceController that implements DeviceCoreDelegate
extension DeviceController: DeviceCoreDelegate {

    /// Removes the device from known devices list and clear all its stored data.
    ///
    /// - Returns: true if the device has been forgotten.
    final func forget() -> Bool {
        if connectionSession.state != .disconnected {
            _ = disconnect()
        }
        ULog.i(.ctrlTag, "forgetting drone \(device.uid)]")
        componentControllers.forEach { component in component.willForget() }
        providers.values.forEach { $0.forget(deviceController: self)}
        deviceStore.clear()
        deviceStore.commit()
        device.stateHolder.state?.update(persisted: false).notifyUpdated()
        if providers.isEmpty {
            stopSelf()
        }
        return true
    }

    /// Connects the device.
    ///
    /// - Parameters:
    ///    - connector: connector to use to establish the connection
    ///    - password: password to use for authentication, nil if password is not required
    /// - Returns: true if the connection process has started
    final func connect(connector: DeviceConnector, password: String?) -> Bool {
         if let provider = providers[connector.uid] {
            ULog.d(.ctrlTag, "connecting device \(device.uid) using provider \(provider)")
            return doConnect(provider: provider, password: password ?? "", cause: .userRequest)
        }
        return false
    }

    /// Disconnects the device.
    ///
    /// This method can be used to disconnect the device when connected or to cancel the connection process if the
    /// device is currently connecting.
    ///
    /// - Returns: true if the disconnection process has started, false otherwise.
    final func disconnect() -> Bool {
        autoReconnect = false
        return doDisconnect(cause: .userRequest)
    }
}

// Backend callbacks
extension DeviceController {
    final func linkWillConnect(provider: DeviceProvider) {
        if activeProvider == nil || activeProvider == provider {
            activeProvider = provider
            autoReconnect = false
            connectionSession.state = .connecting
            device.stateHolder.state?.update(connectionState: .connecting)
                .update(activeConnector: activeProvider!.connector)
                .notifyUpdated()
        }
    }

    final func linkDidConnect(provider: DeviceProvider, backend: DeviceControllerBackend) {
        self.backend = backend

        // a proxy device controller may callback directly here (without calling linkWillConnect), so make sure to
        // pass through connecting state
        if device.stateHolder.state.connectionState != .connecting {
            linkWillConnect(provider: provider)
        }

        transitToNextConnectionState()
    }

    final func linkDidDisconnect(removing: Bool) {
        autoReconnect = autoReconnect || removing
        transitToDisconnectedState(withCause: removing ? .connectionLost : nil)
        self.backend = nil

        device.stateHolder.state.notifyUpdated()
    }

    final func linkDidCancelConnect(cause: DeviceState.ConnectionStateCause, removing: Bool) {
        autoReconnect = autoReconnect || removing
        transitToDisconnectedState(withCause: removing ? .connectionLost : cause)

        device.stateHolder.state.notifyUpdated()
    }

    final func didLoseLink() {
        ULog.i(.ctrlTag, "Device \(device.uid) did lose link")
        componentControllers.forEach { component in component.didLoseLink() }

        autoReconnect = true
        _ = doDisconnect(cause: .connectionLost)
    }

    final func didReceiveCommand(_ command: OpaquePointer) {
        protocolDidReceiveCommand(command)
        componentControllers.forEach { component in component.didReceiveCommand(command) }
    }
}

/// Extension of PersistentStore that brings dependency to GroundSdk
extension PersistentStore {
    /// Preset key for a given model
    ///
    /// - Parameter model: the model to get the key for
    /// - Returns: the key to access the preset
    static func presetKey(forModel model: DeviceModel) -> String {
        return model.description
    }
}

/// Extension of ArsdkRequest that makes it implement the Cancelable protocol
extension ArsdkRequest: CancelableCore { }
