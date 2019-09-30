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

/// BlackBoxReport collector.
/// This object is in charge of all file system related actions linked to the black boxes.
///
/// Indeed, it is in charge of:
///  - collecting on the iOS device file system a list of black boxes that are waiting for upload.
///  - cleaning the empty former work directories and the not fully downloaded black box files.
///  - offering an interface to delete a given black box
///  - offering an interface to archive black box data into a black box report file placed in the current work directory
class BlackBoxCollector {

    /// Queue where all I/O operations will run into
    private let ioQueue = DispatchQueue(label: "BlackBoxCollectorQueue")

    /// Url path of the root directory where reports are stored on the user device's local file system.
    private let rootDir: URL

    /// Url path of the current work directory where reports downloaded from remote devices get stored.
    /// This directory should not be scanned nor deleted because reports might be currently downloading in it.
    private let workDir: URL

    /// The json encoder used to archive data
    private let jsonEncoder = JSONEncoder()

    /// File extension of a non finalized report
    fileprivate static let nonFinalizedFileExtension = "tmp"

    /// Blackbox public folder
    private var blackboxPublicFolder: String? = GroundSdkConfig.sharedInstance.blackboxPublicFolder

    /// Constructor
    ///
    /// - Parameters:
    ///   - rootDir: url path of the root directory where reports are stored
    ///   - workDir: current work directory where reports downloaded from remote devices get stored
    init(rootDir: URL, workDir: URL) {
        self.rootDir = rootDir
        self.workDir = workDir
    }

    /// Loads the list of local black boxes in background.
    ///
    /// - Note:
    ///    - this function will not look into the `workDir` directory.
    ///    - this function will delete all empty folders and not fully downloaded black boxes that are not located in
    ///      `workDir`.
    ///
    /// - Parameters:
    ///   - completionCallback: callback of the local black boxes list
    ///   - reports: list of the black box reports that are ready to upload
    func collectBlackBoxes(completionCallback: @escaping (_ reports: [BlackBox]) -> Void) {
        ioQueue.async {
            do {
                try FileManager.default.createDirectory(
                    at: self.rootDir, withIntermediateDirectories: true, attributes: nil)
            } catch let err {
                ULog.e(.blackBoxEngineTag, "Failed to create folder at \(self.rootDir.path): \(err)")
                return
            }

            var toUpload: [BlackBox] = []
            var toDelete: Set<URL> = []

            // For each dirs of the reports dir (these are work dirs and former work dirs
            let dirs = try? FileManager.default.contentsOfDirectory(
                at: self.rootDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            dirs?.forEach { dir in
                // don't look in the work dir for the moment
                if dir != self.workDir {
                    // by default add the directory to the directories to delete. It will be removed from it if we
                    // discover a finalized report inside
                    toDelete.insert(dir)

                    let reports = try? FileManager.default.contentsOfDirectory(
                        at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                    reports?.forEach { report in
                        // if the report is finalized
                        if report.isAFinalizedBlackBox {
                            // keep the parent folder
                            toDelete.remove(dir)

                            toUpload.append(BlackBox(url: report))
                        } else {
                            toDelete.insert(report)
                        }
                    }
                }
            }

            // delete all not finalized reports and empty directories
            toDelete.forEach {
                self.doDeleteBlackBox(at: $0)
            }

            DispatchQueue.main.async {
                completionCallback(toUpload)
            }
        }
    }

    /// Delete a black box in background.
    ///
    /// - Parameter url: url of the black box report to delete
    func deleteBlackBox(at url: URL) {
        ioQueue.async {
            self.doDeleteBlackBox(at: url)
        }
    }

    /// Archive a black box data on the file system (onto a black box report file).
    ///
    /// - Parameters:
    ///   - blackBoxData: the black box encodable data
    ///   - blackBoxArchived: the callback that will be called if the archive task succeed.
    ///   - report: the newly created report
    func archive<T: Encodable>(blackBoxData: T, blackBoxArchived: @escaping (_ report: BlackBox) -> Void) {
        ioQueue.async {
            do {
                try FileManager.default.createDirectory(
                    at: self.workDir, withIntermediateDirectories: true, attributes: nil)
            } catch let err {
                ULog.e(.blackBoxEngineTag, "Failed to create folder at \(self.workDir.path): \(err)")
                return
            }

            let encodedBlackBoxData: Data
            do {
                encodedBlackBoxData = try self.jsonEncoder.encode(blackBoxData)
            } catch let err {
                ULog.e(.blackBoxEngineTag, "Failed to encode data: \(err)")
                return
            }

            guard let gzipedBlackBox = (encodedBlackBoxData as NSData).compress() else {
                ULog.e(.blackBoxEngineTag, "Failed to gzip blackbox data.")
                return
            }

            let blackBoxMd5 = (gzipedBlackBox as NSData).computeMd5()
            let finalizedFileUrl = self.workDir.appendingPathComponent(blackBoxMd5)
            let tmpFileUrl = finalizedFileUrl.appendingPathExtension(BlackBoxCollector.nonFinalizedFileExtension)
            FileManager.default.createFile(atPath: tmpFileUrl.path, contents: gzipedBlackBox, attributes: nil)
            do {
                try FileManager.default.moveItem(at: tmpFileUrl, to: finalizedFileUrl)
            } catch let err {
                ULog.e(.blackBoxEngineTag, "Failed to replace file at \(tmpFileUrl) with file \(finalizedFileUrl): " +
                    "\(err)")
                return
            }

            self.copyToPublicFolder(finalizedFileUrl, blackBoxMd5)

            DispatchQueue.main.async {
                blackBoxArchived(BlackBox(url: finalizedFileUrl))
            }
        }
    }

    /// Copies the given black box file to the public folder if it is configured.
    ///
    /// - Parameters:
    ///   - fileToCopy: file to copy
    ///   - name: name of file
    /// - Returns: result of copy
    private func copyToPublicFolder(_ fileToCopy: URL, _ name: String) {
        if let blackboxPublicFolder = blackboxPublicFolder {
            let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let blackboxPublicFolderPath = documentPath.appendingPathComponent(blackboxPublicFolder)

            /// create directory if it doesn't exist.
            do {
                try FileManager.default.createDirectory(at: blackboxPublicFolderPath,
                                                        withIntermediateDirectories: true, attributes: nil)
                ULog.d(.blackBoxEngineTag, "Directory created at: \(blackboxPublicFolderPath.absoluteString)")
            } catch let error as NSError {
                ULog.w(.blackBoxEngineTag, "Unable to create directory \(error.debugDescription)")
                return
            }
            /// copy blackbox file.
            let newPath = documentPath.appendingPathComponent(blackboxPublicFolder + "/" + name)
            do {
                try FileManager.default.copyItem(at: fileToCopy, to: newPath)
            } catch  let err {
                ULog.e(.blackBoxEngineTag, "Failed to copy file at \(newPath)" +
                    " with file \(fileToCopy): \(err)")
            }
        }
    }

    /// Delete a black box
    ///
    /// - Note: This function **must** be called from the `ioQueue`.
    /// - Parameter url: url of the black box to delete
    private func doDeleteBlackBox(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch let err {
            ULog.e(.blackBoxEngineTag, "Failed to delete \(url.path): \(err)")
        }
    }
}

/// Private extension to URL that adds BlackBoxes recognition functions
private extension URL {
    /// Whether the black box located at this url is finalized (i.e. fully downloaded) or not.
    var isAFinalizedBlackBox: Bool {
        return pathExtension != BlackBoxCollector.nonFinalizedFileExtension
    }
}
