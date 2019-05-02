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

/// This class is a delegate of the engine and manages devices connected directly by arsdk (versus device
/// connected using a proxy device)
class Arsdk: NSObject {

    /// Arsdk engine
    private unowned let engine: ArsdkEngine
    /// Arsdk control instance
    private(set) var arsdkCore: ArsdkCore!

    /// Constructor
    ///
    /// - Parameter engine: arsdk engine instance
    required init(engine: ArsdkEngine) {
        self.engine = engine
        super.init()
        arsdkCore = engine.createArsdkCore(listener: self)
    }

    /// Start arsdk
    func start() {
        arsdkCore.start()
    }

    /// Stop arsdk
    func stop() {
        arsdkCore.stop()
    }

    override var description: String {
        return "Arsdk"
    }
}

/// Extension of Arsdk that implements ArsdkFacadeListener
extension Arsdk: ArsdkCoreListener {

    func onDeviceAdded(_ uid: String, type: Int, backendType: ArsdkBackendType,
                       name: String, handle: CShort) {
        if let model = DeviceModel.from(internalId: type),
            let provider = ArsdkDeviceProvider.getProvider(backendType: backendType) {
            let deviceController = engine.getOrCreateDeviceController(uid: uid, model: model, name: name)
            provider.backends[deviceController] = ArsdkDeviceCtrlBackend(
                arsdk: self, deviceHandle: handle, deviceController: deviceController, provider: provider)
            deviceController.addProvider(provider)
        }
    }

    func onDeviceRemoved(_ uid: String, type: Int, backendType: ArsdkBackendType, handle: Int16) {
        if let deviceController = engine.deviceControllers[uid],
            let provider = ArsdkDeviceProvider.getProvider(backendType: backendType) {
            deviceController.removeProvider(provider)
            provider.backends[deviceController] = nil
        }
    }
}

private class ArsdkDeviceProvider: DeviceProvider {

    /// Local device provider, that uses Wifi technology.
    private static let wifi = ArsdkDeviceProvider(connector: LocalDeviceConnectorCore.wifi)
    /// Local device provider, that uses BLE technology.
    private static let ble = ArsdkDeviceProvider(connector: LocalDeviceConnectorCore.ble)
    /// Local device provider, that uses usb technology.
    private static let usb = ArsdkDeviceProvider(connector: LocalDeviceConnectorCore.usb)

    /// List of devices this provider handles, by controller instance
    var backends = [DeviceController: ArsdkDeviceCtrlBackend]()

    /// Connects the device managed by the given controller
    ///
    /// - Parameters:
    ///    - deviceController: device controller whose device must be connected
    ///    - password: password to use for authentication, an empty string if no password are required
    /// - Returns: true if the connect operation was successfully initiated,
    override func connect(deviceController: DeviceController, password: String) -> Bool {
        if let backend = backends[deviceController] {
            return backend.connect()
        } else {
            ULog.w(.ctrlTag, "Trying to connect an unknown device")
        }
        return false
    }

    /// Disconnects the device managed by the given controller
    ///
    /// As a provider may not support the disconnect operation, this method provides a default implementation that
    /// return false. Subclasses that need to support the disconnect operation may override this method to do so.
    ///
    /// - Parameter deviceController: device controller whose device must be disconnected
    /// - Returns: true if the disconnect operation was successfully initiated
    override func disconnect(deviceController: DeviceController) -> Bool {
        if let backend = backends[deviceController] {
            return backend.disconnect()
        } else {
            ULog.w(.ctrlTag, "Trying to disconnect an unknown device")
        }
        return false
    }

    static func getProvider(backendType: ArsdkBackendType) -> ArsdkDeviceProvider? {
        switch backendType {
        case .net:
            return ArsdkDeviceProvider.wifi
        case .ble:
            return ArsdkDeviceProvider.ble
        case .mux:
            return ArsdkDeviceProvider.usb
        case .unknown:
            return nil
        }
    }
}

/// DeviceControllerBackend that interface with arsdk
class ArsdkDeviceCtrlBackend: NSObject, DeviceControllerBackend {

    /// Class used for storing No Ack commands. Objects are allocated in `subscribeNoAckCommandEncoder()`
    class ArsdkRegisteredNoAckCmdEncoder: NSObject, RegisteredNoAckCmdEncoder {
        fileprivate let registeredEncoder: () -> (ArsdkCommandEncoder?)
        fileprivate let type: ArsdkNoAckCmdType
        private weak var arsdkDeviceCtrlBackend: ArsdkDeviceCtrlBackend?

        /// Constructor
        ///
        /// - Parameters:
        ///   - encoder: the closure for the NoAck Command (closure that returns an ArsdkCommandEncoder)
        ///   - arsdkDeviceCtrlBackend: the instance who owns the registeredNoAckEncoders set
        fileprivate init(
            encoder: @escaping () -> (ArsdkCommandEncoder?), type: ArsdkNoAckCmdType,
            arsdkDeviceCtrlBackend: ArsdkDeviceCtrlBackend) {

            self.registeredEncoder = encoder
            self.type = type
            self.arsdkDeviceCtrlBackend = arsdkDeviceCtrlBackend
            super.init()
        }

        func unregister() {
            arsdkDeviceCtrlBackend?.removeRegisteredNoAckEncoder(registeredNoAckEncoder: self)
            // set nil in ref of the master class, to avoid redoing a unregister
            arsdkDeviceCtrlBackend = nil
        }
    }

    /// Storage of ArsdkCommandEncoder(s) registered in the NoAck Command Loop. Elements of this Set are
    //  added by the function `subscribeNoAckCommandEncoder()` and removed with
    /// `ArsdkRegisteredNoAckCmdEncoder.unregister()`.
    /// This Set is sent to the NoAckCommandLoop with the ArsdkCore function : `setNoAckCommands()`
    private var registeredNoAckEncoders = Set<ArsdkRegisteredNoAckCmdEncoder>()

    /// Arsdk instance that created this backend
    private unowned let arsdk: Arsdk
    /// Arsdk handle for this backend
    private let deviceHandle: CShort
    /// Provider for this backend
    private let provider: DeviceProvider
    /// Device controller
    private unowned let deviceController: DeviceController

    init(arsdk: Arsdk, deviceHandle: CShort, deviceController: DeviceController, provider: DeviceProvider) {
        self.arsdk = arsdk
        self.deviceHandle = deviceHandle
        self.provider = provider
        self.deviceController = deviceController
    }

    func connect() -> Bool {
        arsdk.arsdkCore.connectDevice(deviceHandle, deviceListener: self)
        return true
    }

    func disconnect() -> Bool {
        arsdk.arsdkCore.disconnectDevice(deviceHandle)
        return true
    }

    func sendCommand(_ encoder: ((OpaquePointer) -> Int32)) {
        arsdk.arsdkCore.sendCommand(deviceHandle, encoder: encoder)
    }

    /// Send all NoAckCdeEncoders to the NoAckCommandLoop
    ///
    /// An array of <NoAckStorage *>, containing all closure encoders is allocated and sent to the NoAck Command Loop
    private func updateNoAckCmdLoop() {
        let encodersArray = registeredNoAckEncoders.map {
            NoAckStorage(cmdEncoder: $0.registeredEncoder, type: $0.type)!
        }
        arsdk.arsdkCore.setNoAckCommands(encoders: encodersArray, handle: deviceHandle)
    }

    /// Remove a previously registered NoAck Command (registered with `subscribeNoAckCommandEncoder(_)`)
    ///
    /// - Note: this function is called by the ArsdkRegisteredNoAckCmdEncoder's `unregister()` function
    ///
    /// - Parameter registeredNoAckEncoder: encoder registered (kept in self.registeredNoAckEncoders)
    private func removeRegisteredNoAckEncoder (registeredNoAckEncoder: ArsdkRegisteredNoAckCmdEncoder) {
        if registeredNoAckEncoders.remove(registeredNoAckEncoder) != nil {
            // the registeredNoAckEncoder was removed, update the list in the command Loop
            updateNoAckCmdLoop()
        }
    }

    func createNoAckCmdLoop(periodMs: Int32) {
        guard periodMs > 0 else {
            return
        }
        arsdk.arsdkCore.createNoAckCmdLoop(deviceHandle, periodMs: periodMs)
        // send the existing Command List if any
        updateNoAckCmdLoop()
    }

    func deleteNoAckCmdLoop() {
        registeredNoAckEncoders.removeAll()
        arsdk.arsdkCore.deleteNoAckCmdLoop(deviceHandle)
    }

    func subscribeNoAckCommandEncoder(encoder: NoAckCmdEncoder) -> RegisteredNoAckCmdEncoder {

        let newCommandEncoder = ArsdkRegisteredNoAckCmdEncoder(encoder: encoder.encoder, type: encoder.type,
                                                               arsdkDeviceCtrlBackend: self)
        registeredNoAckEncoders.insert(newCommandEncoder)
        updateNoAckCmdLoop()
        return newCommandEncoder
    }

    func createTcpProxy(
        model: DeviceModel, port: Int,
        completion: @escaping (_ tcpProxy: ArsdkTcpProxy?, _ proxyAddress: String?, _ proxyPort: Int) -> Void) {
        arsdk.arsdkCore.createTcpProxy(
            deviceHandle, deviceType: model.internalId, port: UInt16(port), completion: completion)
    }

    func destroyTcpProxy(block: @escaping () -> Void) {
        arsdk.arsdkCore.dispatch_sync {
            block()
        }
    }

    func createVideoStream(url: String, track: String, listener: SdkCoreStreamListener) -> ArsdkStream {
        return arsdk.arsdkCore.createVideoStream(deviceHandle, url: url, track: track, listener: listener)
    }

    func browseMedia(model: DeviceModel, completion: @escaping ArsdkMediaListCompletion) -> ArsdkRequest {
        return arsdk.arsdkCore.listMedia(deviceHandle, deviceType: model.internalId, completion: completion)
    }

    func downloadMediaThumbnail(_ media: ArsdkMedia, model: DeviceModel,
                                completion: @escaping ArsdkMediaDownloadThumbnailCompletion)
        -> ArsdkRequest {
            return arsdk.arsdkCore.downloadMediaThumnail(
                deviceHandle, deviceType: model.internalId, media: media, completion: completion)
    }

    func downloadMedia(_ media: ArsdkMedia, model: DeviceModel, format: ArsdkMediaResourceFormat,
                       destDirectoryPath: String,
                       progress: @escaping ArsdkMediaDownloadProgress,
                       completion: @escaping ArsdkMediaDownloadCompletion) -> ArsdkRequest {
        return arsdk.arsdkCore.downloadMedia(
            deviceHandle, deviceType: model.internalId, media: media, format: format,
            destDirectoryPath: destDirectoryPath, progress: progress, completion: completion)
    }

    func deleteMedia(_ media: ArsdkMedia, model: DeviceModel,
                     completion: @escaping ArsdkMediaDeleteCompletion) -> ArsdkRequest {
        return arsdk.arsdkCore.deleteMedia(deviceHandle, deviceType: model.internalId, media: media,
                                           completion: completion)
    }

    func update(withFile file: String, model: DeviceModel, progress: @escaping ArsdkUpdateProgress,
                completion: @escaping ArsdkUpdateCompletion) -> ArsdkRequest {
        return arsdk.arsdkCore.updateFirwmare(deviceHandle, deviceType: model.internalId, file: file,
                                              progress: progress, completion: completion)
    }

    func upload(file srcPath: String, to dstPath: String, model: DeviceModel, serverType: ArsdkFtpServerType,
                progress: @escaping ArsdkFtpRequestProgress,
                completion: @escaping ArsdkFtpRequestCompletion) -> ArsdkRequest {
        return arsdk.arsdkCore.ftpUpload(
            deviceHandle, deviceType: model.internalId, serverType: serverType, srcPath: srcPath, dstPth: dstPath,
            progress: progress, completion: completion)
    }

    func downloadCrashml(path: String, model: DeviceModel,
                         progress: @escaping ArsdkCrashmlDownloadProgress,
                         completion: @escaping ArsdkCrashmlDownloadCompletion) -> ArsdkRequest {
        return arsdk.arsdkCore.downloadCrashml(deviceHandle, deviceType: model.internalId, path: path,
                                               progress: progress, completion: completion)
    }

    func downloadFlightLog(path: String, model: DeviceModel,
                           progress: @escaping ArsdkFlightLogDownloadProgress,
                           completion: @escaping ArsdkFlightLogDownloadCompletion) -> ArsdkRequest {
        return arsdk.arsdkCore.downloadFlightLog(deviceHandle, deviceType: model.internalId, path: path,
                                               progress: progress, completion: completion)
    }

    func subscribeToRcBlackBox(
        buttonAction: @escaping ArsdkRcBlackBoxButtonActionCb,
        pilotingInfo: @escaping ArsdkRcBlackBoxPilotingInfoCb) -> ArsdkRequest {
        return arsdk.arsdkCore.subscribeToRcBlackBox(
            handle: deviceHandle, buttonAction: buttonAction, pilotingInfo: pilotingInfo)
    }
}

/// Extension of Arsdk that implements ArsdkCoreDeviceListener
extension ArsdkDeviceCtrlBackend: ArsdkCoreDeviceListener {
    func onConnecting() {
        deviceController.linkWillConnect(provider: provider)
    }

    func onConnected() {
        deviceController.linkDidConnect(provider: provider, backend: self)
    }

    func onDisconnected(_ removing: Bool) {
        deviceController.linkDidDisconnect(removing: removing)
        if removing {
            // if device is disconnected because it's about to be removed, also remove the provider
            // to make it not connectable with this provider.
            deviceController.removeProvider(provider)
        }
    }

    func onConnectionCancel(_ reason: ArsdkConnCancelReason, removing: Bool) {
        var cause: DeviceState.ConnectionStateCause
        switch reason {
        case .local:
            cause = .userRequest
        case .remote:
            cause = .failure
        case .reject:
            cause = .refused
        }
        deviceController.linkDidCancelConnect(cause: cause, removing: removing)
        if removing {
            // if device is disconnected because it's about to be removed, also remove the provider
            // to make it not connectable with this provider.
            deviceController.removeProvider(provider)
        }
    }

    func onLinkDown() {
        deviceController.didLoseLink()
    }

    func onCommandReceived(_ command: OpaquePointer) {
        deviceController.didReceiveCommand(command)
    }
}
