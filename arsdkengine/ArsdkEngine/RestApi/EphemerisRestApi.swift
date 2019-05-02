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
//    SUCH DAMAGE

import Foundation
import GroundSdk

/// Rest api for Ephemeris to upload on Drone.
class EphemerisRestApi {

    /// Result of an upload request
    enum Result: CustomStringConvertible {
        /// The request succeed
        case success
        /// The request failed
        case error
        /// The request has been canceled
        case canceled

        /// Debug description.
        public var description: String {
            switch self {
            case .success:  return "success"
            case .error:    return "error"
            case .canceled: return "canceled"
            }
        }
    }

    /// Drone server
    private let server: DroneServer

    /// Constructor
    ///
    /// - Parameter server: the drone server that the upload should use
    init(server: DroneServer) {
        self.server = server
    }

    /// Updates the ephemeris with local ephemeris
    ///
    /// - Note:
    ///     - No check will be done on the ephemeris to know if it matches with the Ephemeris from the drone
    ///     - The returned task should be kept in order to cancel the upload. The upload will continue even if is not
    ///       kept
    ///
    /// - Parameters:
    ///   - ephemeris: the ephemeris to upload with
    ///   - completion: the completion callback (called on the main thread)
    ///   - result: the completion status
    func upload(
        ephemeris: URL, completion: @escaping (_ result: Result) -> Void) -> CancelableCore {
        return server.putFile(api: "/api/v1/upload/ephemeris", fileUrl: ephemeris, progress: {_ in},
                              completion: { result, _ in
                switch result {
                case .success:
                    ULog.w(.ephemerisTag, "ephemeris success upload")
                    completion (.success)
                case .error, .httpError:
                    ULog.w(.ephemerisTag, "ephemeris error upload")
                    completion(.error)
                case .canceled:
                    ULog.w(.ephemerisTag, "ephemeris canceled upload")
                    completion(.canceled)
                }
        })
    }
}
