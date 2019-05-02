//    Copyright (C) 2019 Parrot Drones SAS
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

/// FlightLog report collector.
/// This object is in charge of all file system related actions linked to the flightLog reports.
///
/// Indeed, it is in charge of:
///  - collecting on the iOS device file system a list of flightLogs  that are waiting for upload.
///  - cleaning the empty former work directories and the not fully downloaded flightLog reports file.
///  - offering an interface to delete a given flightLog report
class FlightLogCollector {

    /// Queue where all I/O operations will run into
    private let ioQueue = DispatchQueue(label: "FlightLogCollectorQueue")

    /// Url path of the root directory where reports are stored on the user device's local file system.
    private let rootDir: URL

    /// Url path of the current work directory where logs downloaded from remote devices get stored.
    /// This directory should not be scanned nor deleted because reports might be currently downloading in it.
    private let flightLogsLocalWorkDir: URL

    /// Constructor
    ///
    /// - Parameters:
    ///   - rootDir: url path of the root directory where reports are stored
    ///   - workDir: current work directory where reports downloaded from remote devices get stored
    init(rootDir: URL, flightLogsLocalWorkDir: URL) {
        self.rootDir = rootDir
        self.flightLogsLocalWorkDir = flightLogsLocalWorkDir
    }

    /// Loads the list of local flightLogs in background.
    ///
    /// - Note:
    ///    - this function will not look into the `workDir` directory.
    ///    - this function will delete all empty folders and not fully downloaded flightLog that are not located in
    ///      `workDir`.
    ///
    /// - Parameters:
    ///   - completionCallback: callback with the the local flightLogs list
    ///   - flightLogsUrls: list of the local urls of the logs that are ready to upload
    func collectFlightLogs(completionCallback: @escaping (_ flightLogsUrls: [URL]) -> Void) {
        ioQueue.async {
            do {
                try FileManager.default.createDirectory(
                    at: self.rootDir, withIntermediateDirectories: true, attributes: nil)
            } catch let err {
                ULog.e(.flightLogEngineTag, "Failed to create folder at \(self.rootDir.path): \(err)")
                return
            }

            var toUpload: [URL] = []
            var toDelete: Set<URL> = []

            // For each dirs of the flightLogs dir (these are work dirs and former work dirs
            let dirs = try? FileManager.default.contentsOfDirectory(
                at: self.rootDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            dirs?.forEach { dir in
                // don't look in the work dir for the moment
                if dir != self.flightLogsLocalWorkDir {
                    // by default add the directory to the directories to delete. It will be removed from it if we
                    // discover a finalized flightLog inside
                    toDelete.insert(dir)

                    let logUrls = try? FileManager.default.contentsOfDirectory(
                        at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                    logUrls?.forEach { logUrl in
                        // if the report is finalized
                        if logUrl.isAFinalizedFlightLog {
                            // keep the parent folder
                            toDelete.remove(dir)

                            toUpload.append(logUrl)
                        } else {
                            toDelete.insert(logUrl)
                        }
                    }
                }
            }

            // delete all not finalized reports and empty directories
            toDelete.forEach {
                self.doDeleteFlightLog(at: $0)
            }

            DispatchQueue.main.async {
                completionCallback(toUpload)
            }
        }
    }

    /// Delete a flightLog report in background.
    ///
    /// - Parameter url: url of the flightLog report to delete
    func deleteFlightLog(at url: URL) {
        ioQueue.async {
            self.doDeleteFlightLog(at: url)
        }
    }

    /// Delete a flightLog report
    ///
    /// - Note: This function **must** be called from the `ioQueue`.
    /// - Parameter url: url of the flightLog report to delete
    private func doDeleteFlightLog(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch let err {
            ULog.e(.flightLogEngineTag, "Failed to delete \(url.path): \(err)")
        }
    }
}

/// Private extension to URL that adds FlightLogReport recognition functions
private extension URL {
    /// Whether the flightLog report located at this url is finalized (i.e. fully downloaded) or not.
    var isAFinalizedFlightLog: Bool {
        return pathExtension == "bin"
    }
}
