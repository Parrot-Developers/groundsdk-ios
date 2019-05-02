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

/// Utility protocol allowing to access flight log engine internal storage.
///
/// This mainly allows to query the location where flightLog files should be stored and
/// to notify the engine when new flightLogs have been downloaded.
public protocol FlightLogStorageCore: UtilityCore {

    /// Directory where new flight log files may be downloaded.
    ///
    /// Inside this directory, flightLog downloaders may create temporary folders, that have a `.tmp` suffix to their
    /// name. Those folders will be cleaned up by the flight log engine when appropriate.
    ///
    /// Any directory with another name is considered to be a valid flightLog by the flightLog engine
    ///
    /// Multiple downloaders may be assigned the same download directory. As a consequence, flightLog  directories
    /// that a downloader may create should have a name as unique as possible to avoid collision.
    ///
    /// The directory in question might not be existing, and the caller as the responsibility to create it if necessary,
    /// but should ensure to do so on a background thread.
    var workDir: URL { get }

    /// Notifies the flight Log engine that a new flightLog as been downloaded.
    ///
    /// - Note: the flightLog file must be located in `workDir`.
    ///
    /// - Parameter flightLogUrl: URL of the downloaded flightLog file
    func notifyFlightLogReady(flightLogUrl: URL)
}

/// Implementation of the `FlightLogStorage` utility.
class FlightLogStorageCoreImpl: FlightLogStorageCore {

    let desc: UtilityCoreDescriptor = Utilities.flightLogStorage

    /// Engine that acts as a backend for this utility.
    unowned let engine: FlightLogEngine

    var workDir: URL {
        return engine.workDir
    }

    /// Constructor
    ///
    /// - Parameter engine: the engine acting as a backend for this utility
    init(engine: FlightLogEngine) {
        self.engine = engine
    }

    func notifyFlightLogReady(flightLogUrl: URL) {
        guard flightLogUrl.deletingLastPathComponent() == workDir else {
            ULog.w(.flightLogStorageTag, "flightLogUrl \(flightLogUrl) is not located in the flighLog directory " +
                "\(workDir)")
            return
        }
        engine.add(flightLogUrl: flightLogUrl)
    }
}

/// Flight Log storage utility description
public class FlightLogStorageCoreDesc: NSObject, UtilityCoreApiDescriptor {
    public typealias ApiProtocol = FlightLogStorageCore
    public let uid = UtilityUid.flightLogStorage.rawValue
}
