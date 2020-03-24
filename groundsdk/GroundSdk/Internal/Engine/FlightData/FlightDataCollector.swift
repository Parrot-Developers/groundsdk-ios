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

/// Flight Data (PUDs) collector.
/// This object is in charge of all file system related actions linked to the PUD files
///
/// Indeed, it is in charge of:
///  - collecting on the iOS device file system a list of dowloaded flight datas.
///  - cleaning the empty former work directories and the not fully downloaded flight data file.
///  - offering an interface to delete a given flight data
class FlightDataCollector {

    /// Queue where all I/O operations will run into
    private let ioQueue = DispatchQueue(label: "FlightDataCollectorQueue")

    /// Url path of the root directory where flights data are stored on the user device's local file system.
    private let rootDir: URL

    /// Url path of the current work directory where flights data downloaded from remote devices get stored.
    /// This directory should not be scanned nor deleted because files might be currently downloading in it.
    private let flightDataLocalWorkDir: URL

    /// Constructor
    ///
    /// - Parameters:
    ///   - rootDir: url path of the root directory where files are stored
    ///   - flightDataLocalWorkDir: current work directory where files downloaded from remote devices get stored
    init(rootDir: URL, flightDataLocalWorkDir: URL) {
        self.rootDir = rootDir
        self.flightDataLocalWorkDir = flightDataLocalWorkDir
    }

    /// Loads the list of local flight data files in background.
    ///
    /// - Note:
    ///    - this function will not look into the `workDir` directory.
    ///    - this function will delete all empty folders and not fully downloaded files that are not located in
    ///      `workDir`.
    ///
    /// - Parameters:
    ///   - completionCallback: callback of the local FlightData list
    ///   - flightDataFiles: set of the files url that are ready.
    func collectFlightDatas(completionCallback: @escaping (_ flightDataFiles: Set<URL>) -> Void) {
        ioQueue.async {
            do {
                try FileManager.default.createDirectory(
                    at: self.rootDir, withIntermediateDirectories: true, attributes: nil)
            } catch let err {
                ULog.e(.flightDataEngineTag, "Failed to create folder at \(self.rootDir.path): \(err)")
                return
            }

            var readyFiles = Set<URL>()
            var toDelete = Set<URL>()

            // For each dirs of the flightData dir
            let dirs = try? FileManager.default.contentsOfDirectory(
                at: self.rootDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            dirs?.forEach { dir in
                // don't look in the work dir for the moment
                if dir != self.flightDataLocalWorkDir {
                    // by default add the directory to the directories to delete. It will be removed from it if we
                    // discover a finalized flight data inside
                    toDelete.insert(dir)

                    let flightDataDirs = try? FileManager.default.contentsOfDirectory(
                        at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                    flightDataDirs?.forEach { flightUrl in
                        // if the flight data file is finalized
                        if flightUrl.isAFinalizedFlightData {
                            // keep the parent folder
                            toDelete.remove(dir)
                            readyFiles.insert(flightUrl)
                        } else {
                            toDelete.insert(flightUrl)
                        }
                    }
                }
            }

            // delete all not finalized files and empty directories
            toDelete.forEach {
                self.doDeleteFlightData(at: $0)
            }

            DispatchQueue.main.async {
                completionCallback(readyFiles)
            }
        }
    }

    /// Delete a flight data in background.
    ///
    /// - Parameter url: url of the file to delete
    func deleteFlightData(at url: URL) {
        ioQueue.async {
            self.doDeleteFlightData(at: url)
        }
    }

    /// Delete a flight data file
    ///
    /// - Note: This function **must** be called from the `ioQueue`.
    /// - Parameter url: url of the flight data file to delete
    private func doDeleteFlightData(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch let err {
            ULog.e(.flightDataEngineTag, "Failed to delete \(url.path): \(err)")
        }
    }
}

/// Private extension to URL that adds FlightData recognition functions
private extension URL {
    /// Whether the flight data located at this url is finalized (i.e. fully downloaded) or not.
    var isAFinalizedFlightData: Bool {
        return pathExtension == "pud"
    }
}
