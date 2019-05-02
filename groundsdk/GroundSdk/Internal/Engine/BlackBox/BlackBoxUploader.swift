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
//    * Neither the name of Parrot nor the names
//      of its contributors may be used to endorse or promote products
//      derived from this software without specific prior written
//      permission.
//
//    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//    COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
//    OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
//    AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
//    OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//    SUCH DAMAGE.

import Foundation

/// This object is in charge of uploading black boxes to the server.
class BlackBoxUploader {

    /// Uploader error
    enum UploadError: Error {
        /// Report is not well formed. Hence, it can be deleted.
        case badReport
        /// Server error. crash report should not be deleted because another try might succeed.
        case serverError
        /// Connection error, crash report should not be deleted because another try might succeed.
        case connectionError
        /// Request sent had an error. Crash report can be deleted even though the file is not corrupted to avoid
        /// infinite retry.
        /// This kind of error is a development error and can normally be fixed in the code.
        case badRequest
        /// Upload has been canceled. Crash report should be kept in order to retry its upload later.
        case canceled
    }

    /// Prototype of the callback of upload completion
    ///
    /// - Parameters:
    ///   - report: the report that should have been uploaded
    ///   - error: the error if upload was not successful, nil otherwise
    public typealias CompletionCallback = (_ report: BlackBox, _ error: UploadError?) -> Void

    /// Cloud server utility
    private let cloudServer: CloudServerCore

    /// Constructor.
    ///
    /// - Parameter cloudServer: the cloud server to upload reports with
    init(cloudServer: CloudServerCore) {
        self.cloudServer = cloudServer
    }

    /// Upload a crash report on Parrot cloud server.
    ///
    /// - Parameters:
    ///   - blackBox: the black box to upload
    ///   - completionCallback: closure that will be called when the upload completes.
    /// - Returns: a request that can be canceled.
    func upload(blackBox: BlackBox, completionCallback: @escaping CompletionCallback) -> CancelableCore {
        ULog.d(.crashReportEngineTag, "Will upload black box \(blackBox.url)")
        return cloudServer.sendFile(
            api: "/apiv1/bbox",
            fileUrl: blackBox.url, method: .post,
            requestCustomization: { $0.setValue("application/gzip", forHTTPHeaderField: "Content-type") },
            progress: { _ in },
            completion: { result, _ in
                var uploadError: UploadError?
                switch result {
                case .success:
                    break
                case .httpError(let errorCode):
                    switch errorCode {
                    case 400,   // bad request
                         403:   // bad api called
                        uploadError = .badRequest
                    case 429,   // too many requests
                         _ where errorCode >= 500:   // server error, try again later
                        uploadError = .serverError
                    default:
                        // by default, blame the error on the report in order to delete it.
                        uploadError = .badReport
                    }
                case .error(let error):
                    switch (error  as NSError).urlError {
                    case .canceled:
                        uploadError = .canceled
                    case .connectionError:
                        uploadError = .connectionError
                    case .otherError:
                        // by default, blame the error on the report in order to delete it.
                        uploadError = .badReport
                    }
                case .canceled:
                    uploadError = .canceled
                }
                completionCallback(blackBox, uploadError)
        })
    }
}
