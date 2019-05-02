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

/// Flight Data engine.
class FlightDataEngine: EngineBaseCore {
    /// Flight Data Manager facility
    private var flightDataManager: FlightDataManagerCore!

    /// Url path of the root directory where PUDs are stored on the user device's local file system.
    ///
    /// This directory is located in the /Library folder of the phone/tablet.
    ///
    /// This directory may contain:
    /// - the current work directory (see `workDir`) , which may itself contain temporary flight data files (PUDs)
    ///   (being currently downloaded from remote devices) and finalized
    /// - previous work directories, that may themselves contain finalized PUDs, or temporary PUDs that failed to
    ///   be downloaded completely.
    ///
    /// When the engine starts, temporary files in previous work directories (other than the work directory)
    /// are deleted.
    /// Temporary files in the work directory are left untouched.
    let engineDir: URL

    /// Url path of the current work directory where flight data files downloaded from remote devices are stored.
    /// This directory is located in `engineDir`.
    let workDir: URL

    /// Name of the directory in which the Flight Datas should be stored
    private let flightDatasLocalDirName = "FlightDatas"

    /// Flight data files ready (downloaded with success)
    private var readyFlightDataFiles = Set<URL>()

    /// Flight Datas file collector.
    private var collector: FlightDataCollector!

    /// space quota in megabytes
    private var spaceQuotaInMb: Int = 0

    /// Constructor
    ///
    /// - Parameter enginesController: engines controller
    public required init(enginesController: EnginesControllerCore) {
        ULog.d(.flightDataEngineTag, "Loading FlightDataEngine.")

        let libraryDirUrl = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        engineDir = libraryDirUrl.appendingPathComponent(flightDatasLocalDirName, isDirectory: true)
        workDir = engineDir.appendingPathComponent(UUID().uuidString, isDirectory: true)
        spaceQuotaInMb = GroundSdkConfig.sharedInstance.flightDataQuotaMb ?? 0

        super.init(enginesController: enginesController)

        flightDataManager = FlightDataManagerCore(store: enginesController.facilityStore, backend: self)
        publishUtility(FlightDataStorageCoreImpl(engine: self))
        collector = createCollector()
    }

    public override func startEngine() {
        ULog.d(.flightDataEngineTag, "Starting FlightDataEngine.")

        if spaceQuotaInMb != 0 {
            try? FileManager.cleanOldInDirectory(url: engineDir, fileExt: "pud",
                                                    totalMaxSizeMb: spaceQuotaInMb, includingSubfolders: true)
        }

        collector.collectFlightDatas { [weak self] flightDatas in
            if let `self` = self, self.started {
                self.readyFlightDataFiles = self.readyFlightDataFiles.union(flightDatas)
                self.flightDataManager.update(files: self.readyFlightDataFiles).notifyUpdated()
            }
        }
        flightDataManager.publish()
    }

    public override func stopEngine() {
        ULog.d(.flightDataEngineTag, "Stopping FlightDataEngine.")
        flightDataManager.unpublish()
    }

    /// Adds a ready Flight Data.
    ///
    /// - Parameter flightData: the URL of the new flight Data
    func add(flightData: URL) {
        readyFlightDataFiles.insert(flightData)
        flightDataManager.update(files: readyFlightDataFiles).notifyUpdated()
    }

    /// Creates a collector
    ///
    /// - Returns: a new collector
    /// - Note: Visibility is internal only for testing purposes.
    func createCollector() -> FlightDataCollector {
        return FlightDataCollector(rootDir: engineDir, flightDataLocalWorkDir: workDir)
    }
}

// MARK: - concordance FlightDataManagerBackend (flight data utility backend)
extension FlightDataEngine: FlightDataManagerBackend {
    func delete(file: URL) -> Bool {
        guard readyFlightDataFiles.contains(file) else {
            ULog.w(.flightDataEngineTag, "request to remove a non existing flight Data")
            return false
        }
        readyFlightDataFiles.remove(file)
        self.collector.deleteFlightData(at: file)
        flightDataManager.update(files: readyFlightDataFiles).notifyUpdated()
        return true
    }
}
