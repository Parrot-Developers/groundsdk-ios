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

/// Rest api for the update through an http server.
class UpdateRestApi {

    /// Result of an update request
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
    /// - Parameter server: the drone server that the update should use
    init(server: DroneServer) {
        self.server = server
    }

    /// Updates the device with a local firmware
    ///
    /// - Note:
    ///     - No check will be done on the firmware to know if it matches with the device's model. If a check should
    ///       be done, then the caller must do it.
    ///     - The returned task should be kept in order to cancel the upload. The upload will continue even if is not
    ///       kept
    ///
    /// - Parameters:
    ///   - firmware: the of the firmware to update with
    ///   - progress: the progress callback (called on the main thread)
    ///   - progressValue: the current upload progress
    ///   - completion: the completion callback (called on the main thread)
    ///   - result: the completion result
    /// - Returns: The request.
    func update(
        withFirmware firmware: URL, progress: @escaping (_ progressValue: Int) -> Void,
        completion: @escaping (_ result: Result) -> Void) -> CancelableCore {

        return server.putFile(
            api: "/api/v1/update/upload", fileUrl: firmware, timeoutInterval: 120,
            progress: progress) { result, _ in
                switch result {
                case .success:
                    completion(.success)
                case .error, .httpError:
                    completion(.error)
                case .canceled:
                    completion(.canceled)
                }
        }
    }
}
