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

/// Utility protocol allowing to access crash report engine internal storage.
///
/// This mainly allows crash report downloaders to query the location where they should store downloaded reports and
/// to notify the engine when new reports have been downloaded.
public protocol CrashReportStorageCore: UtilityCore {

    /// Directory where new crash reports may be downloaded.
    ///
    /// Inside this directory, report downloaders may create temporary folders, that have a `.tmp` suffix to their name,
    /// for any purpose they see fit. Those folders will be cleaned up by the crash report engine when appropriate.
    ///
    /// Any directory with another name is considered to be a valid report by the crash report engine, which may try to
    /// upload it at some point.
    ///
    /// Multiple downloaders may be assigned the same download directory. As a consequence, report directories that a
    /// downloader may create should have a name as unique as possible to avoid collision.
    ///
    /// The directory in question might not be existing, and the caller as the responsibility to create it if necessary,
    /// but should ensure to do so on a background thread.
    var workDir: URL { get }

    /// Notifies the crash report engine that a new report as been downloaded and is ready to be uploaded.
    ///
    /// - Note: the crash report should be located in `workDir`.
    ///
    /// - Parameter reportUrl: directory of the downloaded report
    func notifyReportReady(reportUrlCollection: [URL])
}

/// Implementation of the `CrashReportStorage` utility.
class CrashReportStorageCoreImpl: CrashReportStorageCore {

    let desc: UtilityCoreDescriptor = Utilities.crashReportStorage

    /// Engine that acts as a backend for this utility.
    unowned let engine: CrashReportEngine

    var workDir: URL {
        return engine.workDir
    }

    /// Constructor
    ///
    /// - Parameter engine: the engine acting as a backend for this utility
    init(engine: CrashReportEngine) {
        self.engine = engine
    }

    func notifyReportReady(reportUrlCollection: [URL]) {
        for reportUrl in reportUrlCollection {
            guard reportUrl.deletingLastPathComponent() == workDir else {
                ULog.w(.crashReportStorageTag, "Report \(reportUrl) is not located in the crash reports directory " +
                    "\(workDir)")
                return
            }

            engine.add(reportUrl: reportUrl)
        }
    }
}

/// Crash report storage utility description
public class CrashReportStorageCoreDesc: NSObject, UtilityCoreApiDescriptor {
    public typealias ApiProtocol = CrashReportStorageCore
    public let uid = UtilityUid.crashReportStorage.rawValue
}
