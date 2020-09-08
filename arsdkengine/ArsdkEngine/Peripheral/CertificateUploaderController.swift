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

/// Certificate uploader delegate
protocol CertificateUploaderDelegate: class {

    /// Configure the uploader
    func configure()

    /// Reset the uploader
    func reset()

    /// Upload a given certificate file on the drone.
    ///
    /// - Parameters:
    ///   - filepath: local path of the certificate file
    ///   - completion: the completion callback (called on the main thread)
    ///   - success: true or false if the upload is done with success
    /// - Returns: a request that can be canceled
    func upload(certificate
        filepath: String, completion: @escaping (_ success: Bool) -> Void) -> CancelableCore?
}

/// Base controller for certificate uploader peripheral
class CertificateUploaderController: DeviceComponentController, CertificateUploaderBackend {

    /// Certificate uploader component
    private var certificateUploader: CertificateUploaderCore!

    // swiftlint:disable weak_delegate
    /// Delegate to upload the certificate
    private var delegate: CertificateUploaderDelegate

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        self.delegate = HttpCertificateUploaderDelegate(deviceController: deviceController)
        super.init(deviceController: deviceController)
        certificateUploader = CertificateUploaderCore(store: deviceController.device.peripheralStore, backend: self)
    }

    /// Drone is connected
    override func didConnect() {
        super.didConnect()
        certificateUploader.publish()
        delegate.configure()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        certificateUploader.unpublish()
    }

    /// Drone is about to be forgotten
    override func willForget() {
        certificateUploader.unpublish()
        super.willForget()
    }

    func upload(certificate filepath: String) {
        _ = delegate.upload(certificate: filepath, completion: { success in
            if !success {
                ULog.w(.credentialTag, "HTTP - Upload of certificate file failed")
            }
        })
    }
}
