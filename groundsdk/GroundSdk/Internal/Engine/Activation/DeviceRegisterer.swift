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

/// Device activation registerer.
class DeviceRegisterer {
    /// Registration result
    enum RegistrationResult {
        /// Registration is successful
        case success
        /// Server error. Another attempt might succeed.
        case serverError
        /// Connection error. Another attempt might succeed.
        case connectionError
        /// Request sent had an error. Device should not be registered anymore to avoid infinite retry.
        /// This kind of error is a development error and can normally be fixed in the code.
        case badRequest
        /// Registration has failed. Device should not be registered anymore to avoid infinite retry.
        case registrationFailed
        /// Request has been canceled
        case canceled
    }

    /// Cloud server utility
    private let cloudServer: CloudServerCore
    /// Json encoder
    private let jsonEncoder = JSONEncoder()

    /// Constructor.
    ///
    /// - Parameter cloudServer: the cloud server to register the products on
    init(cloudServer: CloudServerCore) {
        self.cloudServer = cloudServer
    }

    /// Register a list of devices.
    ///
    /// - Parameters:
    ///   - devices: list of registration infos about the devices to register
    ///   - completionCallback: completion callback
    /// - Returns: a request that can be canceled.
    func register(
        devices: [Info], completionCallback: @escaping (_ result: RegistrationResult) -> Void) -> CancelableCore? {
        do {
            let plistData = try jsonEncoder.encode(devices)

            return cloudServer.sendData(
                api: "/apiv1/activation", data: plistData, method: .post,
                requestCustomization: { $0.setValue("application/json", forHTTPHeaderField: "Content-type") },
                completion: { result, _ in

                    let registrationResult: RegistrationResult
                    switch result {
                    case .success:
                        registrationResult = .success
                    case .httpError(let errorCode):
                        switch errorCode {
                        case 400,   // bad request
                        403,        // forbidden
                        415:        // Unsupported Media Type
                            registrationResult = .badRequest
                        case 429,   // too many requests
                             _ where errorCode >= 500:   // server error, try again later
                            registrationResult = .serverError
                        default:
                            // by default, blame the error on the registration in order to mark products as registered.
                            registrationResult = .registrationFailed
                        }
                    case .error(let error):
                        switch (error  as NSError).urlError {
                        case .canceled:
                            registrationResult = .canceled
                        case .connectionError:
                            registrationResult = .connectionError
                        case .otherError:
                            // by default, blame the error on the registration in order to mark products as registered.
                            registrationResult = .registrationFailed
                        }
                    case .canceled:
                        registrationResult = .canceled
                    }
                    completionCallback(registrationResult)

            })
        } catch let err {
            ULog.e(.activationEngineTag, "Failed to encode data: \(err)")
            return nil
        }
    }

    /// Info about a device that can be registered
    struct Info: Encodable {
        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case uid = "serial"
            case firmware
        }

        /// Uid of the device
        let uid: String
        /// Firmware version as string of the device
        let firmware: String
    }
}
