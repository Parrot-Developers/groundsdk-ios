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

/// Engine that manages device firmwares.
///
/// Maintains both locally downloaded firmwares and remote firmwares available for download from the update server.
///
/// Downloads firmwares from the update server if required.
class FirmwareEngine: EngineBaseCore {

    /// Key used in UserDefaults dictionary
    private let storeDataKey = "firmwareEngine"

    /// For automatic checks of firmware availability, the minimum interval between two "remote list" requests.
    /// (see `autoRemoteUpdates()`).
    let minIntervalAutoCheck = TimeInterval(3600 * 24 * 7) // a week
    /// For manual checks of firmware availability, minimum interval between two "remote list" requests.
    /// (see `queryRemoteUpdates()`).
    let minIntervalUserCheck = TimeInterval(3600) // an hour

    /// Latest date on which the "Remote List" request was successfully executed. Note: this value is persistent.
    private var latestListRequestDate: Date?

    /// Set of Known models for devices in the persistent store. This set is saved with each request. Subsequently,
    /// if the set changes, a new query will be forced. Note: this value is persistent.
    private var knownModels: Set<DeviceModel> = []

    /// Firmware manager facility
    private var firmwareManager: FirmwareManagerCore!

    /// Firmware store
    let firmwareStore = FirmwareStoreCoreImpl()

    // Blacklisted firmware version store
    let blacklistStore = BlacklistedVersionStoreCoreImpl()

    /// Firmware downloader.
    private(set) var firmwareDownloader: FirmwareDownloaderCoreImpl!

    /// Update REST Api
    ///
    /// Only valid after engine is started and before engine is stopped.
    private var updateRestApi: UpdateRestApi!

    /// Current listing request
    private var listingRequest: CancelableCore?

    /// Monitor of the connectivity changes
    private var connectivityMonitor: MonitorCore?
    /// Monitor on the store
    private var storeMonitor: MonitorCore?

    /// Constructor
    ///
    /// - Parameter enginesController: engines controller
    public required init(enginesController: EnginesControllerCore) {
        ULog.d(.fwEngineTag, "Loading FirmwareEngine.")
        super.init(enginesController: enginesController)
        // reload persisting Datas
        loadData()
        firmwareManager = FirmwareManagerCore(store: enginesController.facilityStore, backend: self)

        let documentUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let firmwaresFolderUrl = documentUrl.appendingPathComponent("firmwares", isDirectory: true)
        firmwareDownloader = FirmwareDownloaderCoreImpl(engine: self, destinationFolder: firmwaresFolderUrl)

        publishUtility(firmwareStore)
        publishUtility(blacklistStore)
        publishUtility(firmwareDownloader)
    }

    public override func startEngine() {
        ULog.d(.fwEngineTag, "Starting FirmwareEngine.")

        // give access to the device stores
        firmwareStore.droneStore = utilities.getUtility(Utilities.droneStore)
        firmwareStore.rcStore = utilities.getUtility(Utilities.remoteControlStore)

        // can force unwrap because this utility is always published.
        let cloudServer = utilities.getUtility(Utilities.cloudServer)!
        updateRestApi = UpdateRestApi(cloudServer: cloudServer)
        firmwareDownloader.start(downloader: updateRestApi)

        connectivityMonitor = utilities.getUtility(
            Utilities.internetConnectivity)?.startMonitoring { [unowned self] internetAvailable in
                if internetAvailable {
                    self.autoCheckFirmwaresUpdates()
                }
        }

        storeMonitor = firmwareStore.startMonitoring { [unowned self] in
            self.firmwareManager.update(entries: Array(self.firmwareStore.firmwares.values)).notifyUpdated()
        }
    }

    override func allEnginesDidStart() {
        // remove unnecessary firmwares in case devices have changed since latest download
        firmwareStore.removeAllUnnecessaryFirmwares()

        self.firmwareManager.publish()
    }

    public override func stopEngine() {
        ULog.d(.fwEngineTag, "Stopping FirmwareEngine.")
        connectivityMonitor?.stop()
        connectivityMonitor = nil
        storeMonitor?.stop()
        storeMonitor = nil
        firmwareManager.unpublish()
    }

    /// Fetch distant informations about firmwares.
    ///
    /// Fetching will only be done if a fetch is not currently happening
    ///
    /// - Returns: true if a request was sent, false otherwise
    @discardableResult private func updateRemoteList() -> Bool {
        let supportedDevices = GroundSdkConfig.sharedInstance.supportedDevices
        if listingRequest == nil && !supportedDevices.isEmpty {
            firmwareManager.update(remoteQueryFlag: true).notifyUpdated()
            listingRequest = updateRestApi.listAvailableFirmwares(models: supportedDevices) {
                //swiftlint:disable:next closure_parameter_position
                [weak self] result, firmwares, blacklistedVersions in
                if result == .success {
                    // remember the last success date for the request
                    self?.latestListRequestDate = Date()
                    self?.saveData()
                    self?.firmwareStore.mergeRemoteFirmwares(firmwares)
                    self?.blacklistStore.mergeRemoteBlacklistedVersions(blacklistedVersions)
                }
                self?.listingRequest = nil
                self?.firmwareManager.update(remoteQueryFlag: false).notifyUpdated()
            }
            return true
        }
        return false
    }

    /// Try to update information from remote servers.
    ///
    /// - Note: This function is called when the Internet is available. The goal is to automatically check for firmware
    /// updates available in the cloud, without the application having to use the `queryRemoteUpdates()` function.
    /// This auto-check is done with a much larger minimum time interval than for forced requests of the application
    /// (see : `minIntervalAutoCheck` and `minIntervalUserCheck`)
    private func autoCheckFirmwaresUpdates() {
        // Check that the last request was made at least `minIntervalAutoCheck` seconds ago
        if let latestListRequestDate = latestListRequestDate,
            abs(latestListRequestDate.timeIntervalSinceNow) < minIntervalAutoCheck {
            return
        }
        ULog.d(.fwEngineTag, "Try autoCheckFirmwaresUpdates.")
        updateRemoteList()
    }
}

/// Extension of the engine that implements the FirmwareStore backend
extension FirmwareEngine: FirmwareManagerBackend {
    func queryRemoteUpdateInfos() -> Bool {
        // Check that the last request was made at least `minIntervalAutoCheck` seconds ago
        if let latestListRequestDate = latestListRequestDate,
            abs(latestListRequestDate.timeIntervalSinceNow) < minIntervalUserCheck {
            return false
        }
        ULog.d(.fwEngineTag, "Try queryRemoteUpdateInfos.")
        return updateRemoteList()
    }

    func download(firmware: FirmwareInfoCore, observer: @escaping (FirmwareDownloaderCoreTask) -> Void) {
        firmwareDownloader.download(firmwares: [firmware], observer: observer)
    }

    func delete(firmware: FirmwareInfoCore) -> Bool {
        return firmwareStore.delete(firmware: firmware.firmwareIdentifier)
    }
}

// MARK: - loading and saving persisting data for the FirmwareEngine
extension FirmwareEngine {

    private enum PersistingDataKeys: String {
        case listRequestDate
        case knownModels
    }

    /// Save persisting data
    private func saveData() {
        let arrayOfModels: [String] = Array(knownModels).map { $0.description }
        let savedDictionary: [String: Any?] = [
            PersistingDataKeys.listRequestDate.rawValue: latestListRequestDate,
            PersistingDataKeys.knownModels.rawValue: arrayOfModels].filter { $0.value != nil }
        GroundSdkUserDefaults(storeDataKey).storeData(savedDictionary)
    }

    /// Load persisting data
    private func loadData() {
        let loadedDictionary = GroundSdkUserDefaults(storeDataKey).loadData() as? [String: Any]
        latestListRequestDate = loadedDictionary?[PersistingDataKeys.listRequestDate.rawValue] as? Date
        let listModels = loadedDictionary?[PersistingDataKeys.knownModels.rawValue] as? [String] ?? []
        knownModels = Set(listModels.compactMap { DeviceModel.from(name: $0) })
    }
}
