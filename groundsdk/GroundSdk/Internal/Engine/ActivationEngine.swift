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

/// Registers known devices the activation server.
///
/// Drones and remote control are registered on the activation server.
///
/// Every time Internet becomes available or a new drone is added to drone store, this engine computes the list of
/// devices to register. If this list is not empty, it sends a register request to the activation server.
class ActivationEngine: EngineBaseCore {

    /// Uid of the simulator. Need to be excluded from the registrable devices
    private let simulatorUid = "000000000000000000"
    /// Set of all excluded uids.
    /// Mainly contains the simulator uid and all possible default devices uids.
    private let excludedUids: Set<String>

    /// Persistent store
    private var gsdkUserdefaults: GroundSdkUserDefaults!
    /// Key of the activated device list in the persistent store
    private let devicesKey = "devices"

    /// Drone store.
    /// Only usable when the engine is started.
    private var droneStore: DroneStoreUtilityCore!
    /// Remote control store.
    /// Only usable when the engine is started.
    private var rcStore: RemoteControlStoreUtilityCore!

    /// Monitor of the drone store.
    /// Only usable when the engine is started.
    private var droneStoreMonitor: MonitorCore!

    private var internetConnectivity: InternetConnectivityCore!

    /// Monitor of the connectivity changes
    /// Only usable when the engine is started.
    private var connectivityMonitor: MonitorCore!

    /// Device registerer
    private var registerer: DeviceRegisterer!
    /// Current registration request
    var currentRequest: CancelableCore?

    /// Set of devices already registered.
    private var registeredDevices: Set<String>!

    /// Constructor
    ///
    /// - Parameter enginesController: engines controller
    public required init(enginesController: EnginesControllerCore) {
        ULog.d(.activationEngineTag, "Loading ActivationEngine.")

        var excludedUids: Set<String> = [simulatorUid]
        // default devices uid are made from the description of the model
        excludedUids.formUnion(DeviceModel.allDevices.map { $0.description })
        self.excludedUids = excludedUids

        super.init(enginesController: enginesController)

        gsdkUserdefaults = createGsdkUserDefaults()
        registeredDevices = getRegisteredDevices()
    }

    /// Creates and returns an instance of GroundSdkUserDefaults
    ///
    /// - Returns: the user defaults that will be used to store persistent data from this engine
    func createGsdkUserDefaults() -> GroundSdkUserDefaults {
        return GroundSdkUserDefaults("activation")
    }

    public override func startEngine() {
        ULog.d(.activationEngineTag, "Starting ActivationEngine.")

        registerer = DeviceRegisterer(cloudServer: utilities.getUtility(Utilities.cloudServer)!)

        droneStore = utilities.getUtility(Utilities.droneStore)
        rcStore = utilities.getUtility(Utilities.remoteControlStore)

        internetConnectivity = utilities.getUtility(Utilities.internetConnectivity)!
        connectivityMonitor = internetConnectivity.startMonitoring { [unowned self] internetAvailable in
            if internetAvailable {
                self.registerUnregisteredDevices()
            }
        }

        // Only monitor drone store to avoid doing two requests when a user connects to an unregistered drone through
        // an unregistered remote control.
        // We are aware that doing so will postpone registration of an unregistered remote control when it is not
        // connected to any unregistered drone.
        // Also monitor deviceInfoDidChange to be informed when the device is persisted (i.e. at least connected once).
        droneStoreMonitor = droneStore.startMonitoring(didAddDevice: { [unowned self] _ in
            self.registerUnregisteredDevices()
            }, deviceInfoDidChange: { [unowned self] _ in
                self.registerUnregisteredDevices()
        })
    }

    public override func stopEngine() {
        ULog.d(.activationEngineTag, "Stopping ActivationEngine.")

        droneStoreMonitor.stop()
        connectivityMonitor.stop()
    }

    /// Gets the already registered devices.
    ///
    /// This will get the results from the persistent store.
    ///
    /// - Returns: the list of the registered devices uids
    private func getRegisteredDevices() -> Set<String> {
        let storedData: [String: Any]? = gsdkUserdefaults.loadData() as? [String: Any]
        if let registeredDevices = storedData?[devicesKey] as? [String] {
            return Set<String>(registeredDevices)
        }
        return []
    }

    /// Whether a given device needs to be registered.
    ///
    /// - Parameter device: the device
    /// - Returns: true if the device needs to be registered (i.e. has not been already registered by this app, on this
    ///            phone).
    private func deviceNeedToBeRegistered(_ device: DeviceCore) -> Bool {
        let uid = device.uid
        return device.stateHolder.state.persisted &&
            !registeredDevices.contains(uid) &&
            !excludedUids.contains(uid) &&
            hasRegistrableBoardId(device)
    }

    /// Tells whether the given device may be registered based on his board id.
    ///
    /// - Parameter device: device to test
    /// - Returns: `true` if the device may be registered, otherwise `false`
    private func hasRegistrableBoardId(_ device: DeviceCore) -> Bool {
        guard let boardId = device.boardIdHolder.boardId else {
            return false
        }
        return !boardId.starts(with: "0x") ||
            Int(boardId.suffix(2), radix: 16) ?? 0 == 0
    }

    /// Gets the list of the devices (drones and rcs) to register
    ///
    /// - Returns: a list of all devices that needs to be registered.
    private func getDevicesToRegister() -> [DeviceRegisterer.Info] {
        var devices = [DeviceRegisterer.Info]()
        let dronesToBeRegistered = droneStore.getDevices().filter({ deviceNeedToBeRegistered($0) })
            .map { DeviceRegisterer.Info(uid: $0.uid, firmware: $0.firmwareVersionHolder.version.description) }
        let rcsToBeRegistered = rcStore.getDevices().filter({ deviceNeedToBeRegistered($0) })
            .map { DeviceRegisterer.Info(uid: $0.uid, firmware: $0.firmwareVersionHolder.version.description) }
        devices.append(contentsOf: dronesToBeRegistered)
        devices.append(contentsOf: rcsToBeRegistered)

        return devices
    }

    /// Callback called when some devices have been registered.
    ///
    /// - Parameter devices: list of registered devices
    private func devicesDidRegister(devices: [DeviceRegisterer.Info]) {
        registeredDevices.formUnion(devices.map { $0.uid })

        gsdkUserdefaults.storeData([devicesKey: Array(registeredDevices)])

        // register new devices if needed
        registerUnregisteredDevices()
    }

    /// Registers devices that are not yet registered.
    ///
    /// Registers devices only if Internet is available or if there is no ongoing register request.
    private func registerUnregisteredDevices() {
        if internetConnectivity.internetAvailable && currentRequest == nil {
            let devicesToRegister = getDevicesToRegister()
            if !devicesToRegister.isEmpty {
                currentRequest = registerer.register(devices: devicesToRegister) { result in
                    // strong ref on self is kept intentionally to be sure to store the result

                    self.currentRequest = nil

                    switch result {
                    case .success:
                        self.devicesDidRegister(devices: devicesToRegister)
                    case .registrationFailed, .badRequest:
                        // request failed to due to another error,
                        // mark the devices as 'registered' to not try to register again them later
                        self.devicesDidRegister(devices: devicesToRegister)
                    case .serverError, .connectionError, .canceled:
                        // if request failed due to server error or if request was cancelled,
                        // retry later
                        ULog.w(.activationEngineTag, "Failed to register devices \(devicesToRegister), retry later")
                    }
                }
            }
        }
    }
}
