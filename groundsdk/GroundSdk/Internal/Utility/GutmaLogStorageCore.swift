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

/// Utility protocol allowing to access gutma log engine internal storage.
///
/// This mainly allows to query the location where GutmaLog files should be stored and
/// to notify the engine when new GutmaLogs have been converted.
public protocol GutmaLogStorageCore: UtilityCore {
    /// Directory where new gutma logs files may be stored.
    ///
    /// Multiple converters may be assigned the same convert directory. As a consequence, GutmaLog  directories
    /// that a converter may create should have a name as unique as possible to avoid collision.
    ///
    /// The directory in question might not be existing, and the caller as the responsibility to create it if necessary,
    /// but should ensure to do so on a background thread.
    var workDir: URL { get }

    /// Notifies the gutma Log engine that a new GutmaLog as been converted.
    ///
    /// - Note: the GutmaLog file must be located in `workDir`.
    ///
    /// - Parameter gutmaLogUrl: URL of the converted Gutma log
    func notifyGutmaLogReady(gutmaLogUrl: URL)
}

/// Implementation of the `GutmaLogStorage` utility.
class GutmaLogStorageCoreImpl: GutmaLogStorageCore {

    let desc: UtilityCoreDescriptor = Utilities.gutmaLogStorage

    /// Engine that acts as a backend for this utility.
    unowned let engine: GutmaLogEngine

    var workDir: URL {
        return engine.workDir
    }

    /// Constructor
    ///
    /// - Parameter engine: the engine acting as a backend for this utility
    init(engine: GutmaLogEngine) {
        self.engine = engine
    }

    func notifyGutmaLogReady(gutmaLogUrl: URL) {
        guard gutmaLogUrl.deletingLastPathComponent() == workDir else {
            ULog.w(.gutmaLogEngineTag, "GutmaLogUrl \(gutmaLogUrl) " +
                "is not located in the GutmaLog directory \(workDir)")
            return
        }
        engine.add(gutmaLog: gutmaLogUrl)
    }
}

/// Gutma Log storage utility description
public class GutmaLogStorageCoreDesc: NSObject, UtilityCoreApiDescriptor {
    public typealias ApiProtocol = GutmaLogStorageCore
    public let uid = UtilityUid.gutmaLogStorage.rawValue
}
