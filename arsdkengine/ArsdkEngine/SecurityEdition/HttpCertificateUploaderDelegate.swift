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

/// Certificate uploader for Http
class HttpCertificateUploaderDelegate: CertificateUploaderDelegate {

    /// Security edition REST Api.
    private var certificateUploaderApi: CertificateUploaderRestApi?

    /// DeviceController, used to upload the firmware.
    private let deviceController: DeviceController

    /// Constructor
    ///
    /// - Parameter deviceController: the device controller
    init(deviceController: DeviceController) {
        self.deviceController = deviceController
    }

    /// Configure
    func configure() {
        if let droneServer = deviceController.droneServer {
            certificateUploaderApi = CertificateUploaderRestApi(server: droneServer)
        }
    }

    /// Reset
    func reset() {
        certificateUploaderApi = nil
    }

    /// Upload the certificate
    ///
    /// - Parameters:
    ///   - certificate: certificate file path
    ///   - completion: completion callback
    func upload(certificate filepath: String, completion: @escaping (Bool) -> Void) -> CancelableCore? {
        return certificateUploaderApi?.upload(filepath: filepath, completion: { success in
            if success {
                completion(true)
            } else {
                completion(false)
                ULog.w(.credentialTag, "HTTP - Upload of certificate file failed")
            }
        })
    }
}
