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

/// Rest api for the flight logs downloading through an http server.
class FlightLogRestApi {

    /// Drone server
    private let server: DroneServer

    /// Base address to access the flight log api
    private let baseApi = "/api/v1/fdr/lite_records"

    /// Constructor
    ///
    /// - Parameter server: the drone server from which flight log should be accessed
    init(server: DroneServer) {
        self.server = server
    }

    /// Get the list of all flight logs on the drone
    ///
    /// - Parameters:
    ///   - completion: the completion callback (called on the main thread)
    ///   - flightLogList: list of flight logs available on the drone
    /// - Returns: the request
    func getFlightLogList(
        completion: @escaping (_ flightLogList: [FlightLog]?) -> Void) -> CancelableCore {
        return server.getData(api: "\(baseApi)") { result, data in
            switch result {
            case .success:
                // listing the flight logs is successful
                if let data = data {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .formatted(.iso8601Base)
                    do {
                        let flightLogs = try decoder.decode([FlightLog].self, from: data)
                        completion(flightLogs)
                    } catch let error {
                        ULog.w(.flightLogTag,
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

    /// Download a given flight log to a given directory
    ///
    /// - Parameters:
    ///   - flightLog: the flight log to download
    ///   - directory: the directory where to put the downloaded flight log into
    ///   - deviceUid: the device uid
    ///   - completion: the completion callback (called on the main thread)
    ///   - fileUrl: url of the locally downloaded file. `nil` if there were an error during download or during copy
    /// - Returns: the request
    func downloadFlightLog(
        _ flightLog: FlightLog, toDirectory directory: URL, deviceUid: String,
        completion: @escaping (_ fileUrl: URL?) -> Void) -> CancelableCore {

        return server.downloadFile(
            api: flightLog.urlPath,
            destination: directory.appendingPathComponent(deviceUid + "_" + flightLog.name),
            progress: { _ in },
            completion: { _, localFileUrl in
                completion(localFileUrl)
        })
    }

    /// Delete a given flight log on the device
    ///
    /// - Parameters:
    ///   - flight log: the flight log to delete
    ///   - completion: the completion callback (called on the main thread)
    ///   - success: whether the delete task was successful or not
    /// - Returns: the request
    func deleteFlightLog(_ flightLog: FlightLog, completion: @escaping (_ success: Bool) -> Void) -> CancelableCore {
        return server.delete(api: "\(baseApi)/lite_records/\(flightLog.name)") { result in
            switch result {
            case .success:
                completion(true)
            default:
                completion(false)
            }
        }
    }

    /// A flightLog
    struct FlightLog: Decodable {
        enum CodingKeys: String, CodingKey {
            case name
            case date
            case urlPath = "url"
        }

        /// Flight log name
        let name: String
        /// Flight log date
        let date: Date
        /// Flight log url path (needs to be appended to an address and a port at least)
        let urlPath: String
    }
}
