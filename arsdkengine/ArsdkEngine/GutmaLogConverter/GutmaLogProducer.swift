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
import GroundSdk

/// GutmaLog producer that does the conversion from FlightLog
class GutmaLogProducer: FileConverter {
    /// Extension of GUTMAs log files
    private var outFileExtension = "gutma"

    /// Dir to store GUTMAs files
    private var workDir: URL {
        return gutmaLogStorage.workDir
    }

    /// Gutma log storage utility
    private var gutmaLogStorage: GutmaLogStorageCore

    /// Constructor
    ///
    /// - Parameter gutmaLogStorage: gutma log storage utility
    private init(gutmaLogStorage: GutmaLogStorageCore) {
        self.gutmaLogStorage = gutmaLogStorage
    }

    /// Create a new `GutmaLogProducer` instance
    ///
    /// - Parameter controller: device controller owning this component controller (weak)
    static func create(deviceController: DeviceController) -> GutmaLogProducer? {
        if let gutmaLogStorage = deviceController.engine.utilities.getUtility(Utilities.gutmaLogStorage) {
            return GutmaLogProducer(gutmaLogStorage: gutmaLogStorage)
        } else {
            return nil
        }
    }

    /// Converts a flight log to GUTMA format
    ///
    /// - Parameter file: URL of the flight log to convert
    /// - Returns: `true` if the conversion is successful, `false` otherwise
    func convert(_ file: URL) -> Bool {
        // create directory to store the output GUTMA file
        do {
            try FileManager.default.createDirectory(
                at: self.workDir, withIntermediateDirectories: true, attributes: nil)
        } catch let err {
            ULog.e(.gutmaLogTag, "Failed to create folder at \(self.workDir.path): \(err)")
            return false
        }
        // getting the filename of the output GUTMA file
        // by changing the extentsion of the input flight log to the GUTMA extension
        let gutmaLogFileName = file
            .deletingPathExtension()
            .appendingPathExtension(outFileExtension)
            .lastPathComponent
        let gutmaLog = URL(fileURLWithPath: gutmaLogFileName, relativeTo: self.workDir)
        // Call the SDKCore to convert the file
        let res = FileConverterAPI.convert(file.path, outFile: gutmaLog.path, format: .gutma)
        if res {
            ULog.d(.gutmaLogTag, "flight log converted")
            gutmaLogStorage.notifyGutmaLogReady(gutmaLogUrl: URL(fileURLWithPath: gutmaLog.path))
        } else {
            ULog.w(.gutmaLogTag, "No Gutma file generated")
        }
        return res
    }
}
