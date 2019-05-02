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

/// Rest api for the flight data (PUD) downloading through an http server.
class PudRestApi {

    /// Drone server
    private let server: DroneServer

    /// Base address to access the report api
    private let baseApi = "/api/v1/pud"

    /// Constructor
    ///
    /// - Parameter server: the drone server from which PUDs should be accessed
    init(server: DroneServer) {
        self.server = server
    }

    /// Get the list of all flight data files (PUDs) on the drone
    ///
    /// - Parameters:
    ///   - completion: the completion callback (called on the main thread)
    ///   - pudList: list of flight data files available on the drone
    /// - Returns: the request
    func getPudList(
        completion: @escaping (_ pudList: [Pud]?) -> Void) -> CancelableCore {
            return server.getData(api: "\(baseApi)/puds") { result, data in
                switch result {
                case .success:
                    // listing the PUDs is successful
                    if let data = data {
                        let decoder = JSONDecoder()
                        do {
                            let reports = try decoder.decode([Pud].self, from: data)
                            completion(reports)
                        } catch let error {
                            ULog.w(.pudTag,
                                   "Failed to decode data \(String(data: data, encoding: .utf8) ?? ""): " +
                                    error.localizedDescription)
                            completion(nil)
                        }
                    }
                default:
                    completion(nil)
                }
            }
    }

    /// Download a given pud to a given directory
    ///
    /// - Parameters:
    ///   - pud: the pud to download
    ///   - directory: the directory where to put the downloaded report into
    ///   - completion: the completion callback (called on the main thread)
    ///   - fileUrl: url of the locally downloaded file. `nil` if there were an error during download or during copy
    /// - Returns: the request
    func downloadPud(
        _ pud: Pud, toDirectory directory: URL,
        completion: @escaping (_ fileUrl: URL?) -> Void) -> CancelableCore {

        return server.downloadFile(
            api: pud.urlPath, withStreamDecoder: PudStreamDecoder(),
            destination: directory.appendingPathComponent(pud.name), completion: { _, localFileUrl in
                completion(localFileUrl)
        })

    }

    /// Delete a given report on the device
    ///
    /// - Parameters:
    ///   - pud: the pud to delete
    ///   - completion: the completion callback (called on the main thread)
    ///   - success: whether the delete task was successful or not
    /// - Returns: the request
    func deletePud(_ pud: Pud, completion: @escaping (_ success: Bool) -> Void) -> CancelableCore {
        return server.delete(api: "\(baseApi)/puds/\(pud.name)") { result in
            switch result {
            case .success:
                completion(true)
            default:
                completion(false)
            }
        }
    }

    /// A Pud
    struct Pud: Decodable {
        enum CodingKeys: String, CodingKey {
            case name
            case date
            case urlPath = "url"
        }

        /// Pud name
        let name: String
        /// Pud date
        let date: String
        /// Pud url path (needs to be appended to an address and a port at least)
        let urlPath: String
    }
}
