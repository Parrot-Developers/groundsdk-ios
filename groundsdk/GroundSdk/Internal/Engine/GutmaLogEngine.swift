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

/// Gutma Log engine.
class GutmaLogEngine: EngineBaseCore {
    /// Gutma Log Manager facility
    private var gutmaLogManager: GutmaLogManagerCore!

    /// Url path of the root directory where GUTMAs are stored on the user device's local file system.
    ///
    /// This directory is located in the /Library folder of the phone/tablet.
    ///
    /// This directory may contain:
    /// - the current work directory (see `workDir`) , which may itself contain temporary flight data files (GUTMAs)
    ///   (being currently converted from remote devices) and finalized
    /// - previous work directories, that may themselves contain finalized GUTMAs, or temporary GUTMAs that failed to
    ///   be converted completely.
    ///
    /// When the engine starts, temporary files in previous work directories (other than the work directory)
    /// are deleted.
    /// Temporary files in the work directory are left untouched.
    let engineDir: URL

    /// Url path of the current work directory where converted log files converted from flight log files are stored.
    /// This directory is located in `engineDir`.
    let workDir: URL

    /// Name of the directory in which the converted logs should be stored
    private let gutmaLogsLocalDirName = "GutmaLogs"

    /// Converted Log files ready (converted with success)
    private var readyGutmaLogFiles = Set<URL>()

    /// Converted log files collector.
    private var collector: GutmaLogCollector!

    /// Space quota in megabytes
    private var spaceQuotaInMb: Int = 0

    /// Constructor
    ///
    /// - Parameter enginesController: engines controller
    public required init(enginesController: EnginesControllerCore) {
        ULog.d(.gutmaLogEngineTag, "Loading gutmaLogEngine.")

        let libraryDirUrl = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        engineDir = libraryDirUrl.appendingPathComponent(gutmaLogsLocalDirName, isDirectory: true)
        workDir = engineDir.appendingPathComponent(UUID().uuidString, isDirectory: true)
        spaceQuotaInMb = GroundSdkConfig.sharedInstance.gutmaLogQuotaMb ?? 0

        super.init(enginesController: enginesController)

        gutmaLogManager = GutmaLogManagerCore(store: enginesController.facilityStore, backend: self)
        publishUtility(GutmaLogStorageCoreImpl(engine: self))
        collector = createCollector()
    }

    public override func startEngine() {
        ULog.d(.gutmaLogEngineTag, "Starting GutmaLogEngine.")

        if spaceQuotaInMb != 0 {
            try? FileManager.cleanOldInDirectory(url: engineDir, fileExt: "gutma",
                                                 totalMaxSizeMb: spaceQuotaInMb, includingSubfolders: true)
        }

        collector.collectGutmaLogs { [weak self] gutmaLogs in
            ULog.d(.gutmaLogEngineTag, "GutmaLog (local) \(gutmaLogs)")
            if let self = self, self.started {
                self.readyGutmaLogFiles = self.readyGutmaLogFiles.union(gutmaLogs)
                self.gutmaLogManager.update(files: self.readyGutmaLogFiles).notifyUpdated()
            }
        }
        gutmaLogManager.publish()
    }

    public override func stopEngine() {
        ULog.d(.gutmaLogEngineTag, "Stopping GutmaLogEngine.")
        gutmaLogManager.unpublish()
    }

    /// Adds a ready Converted Log.
    ///
    /// - Parameter GutmaLog: the URL of the new converted Log
    func add(gutmaLog: URL) {
        readyGutmaLogFiles.insert(gutmaLog)
        gutmaLogManager.update(files: readyGutmaLogFiles).notifyUpdated()
    }

    /// Creates a collector
    ///
    /// - Returns: a new collector
    /// - Note: Visibility is internal only for testing purposes.
    func createCollector() -> GutmaLogCollector {
        return GutmaLogCollector(rootDir: engineDir, gutmaLogsLocalWorkDir: workDir)
    }
}

// MARK: - concordance GutmaLogManagerBackend (gutma log utility backend)
extension GutmaLogEngine: GutmaLogManagerBackend {
    func delete(file: URL) -> Bool {
        guard readyGutmaLogFiles.contains(file) else {
            ULog.w(.gutmaLogEngineTag, "request to remove a non existing gutma Log")
            return false
        }
        readyGutmaLogFiles.remove(file)
        self.collector.deleteGutmaLog(at: file)
        gutmaLogManager.update(files: readyGutmaLogFiles).notifyUpdated()
        return true
    }
}
