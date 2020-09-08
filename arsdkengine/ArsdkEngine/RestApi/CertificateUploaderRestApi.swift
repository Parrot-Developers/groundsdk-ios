// Copyright (C) 2020 Parrot Drones SAS
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

/// Rest api for certificate upload on http server.
class CertificateUploaderRestApi {

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
    /// - Parameter server: the drone server that the update should use
    init(server: DroneServer) {
        self.server = server
    }

    /// Upload a SecurityEdition certificate to the device with a local file
    ///
    /// - Parameters:
    ///   - filepath: certificate's filepath to upload
    ///   - completion: the completion callback (called on the main thread)
    ///   - success: true or false if the upload is done with success
    /// - Returns: The request.
    func upload(filepath: String,
                completion: @escaping (_ success: Bool) -> Void) -> CancelableCore {
        return server.putFile(
            api: "/api/v1/credential/certificate", fileUrl: URL(fileURLWithPath: filepath),
            progress: { _ in }, completion: { result, _ in
                switch result {
                case .success:
                    ULog.w(.credentialTag, "certificate upload success upload")
                    completion(true)
                case .error, .httpError:
                    ULog.w(.credentialTag, "certificate upload error upload")
                    completion(false)
                case .canceled:
                    ULog.w(.credentialTag, "certificate upload canceled upload")
                    completion(false)
                }
        })
    }
}
