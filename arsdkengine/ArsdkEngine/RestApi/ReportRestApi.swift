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

/// Type of crash report.
public enum ReportType: CustomStringConvertible {

    /// Light report, does not contain any user-related information.
    case light

    /// Full report, may contain user-related information.
    case full

    /// Debug description.
    public var description: String {
        switch self {
        case .light:      return "light"
        case .full:       return "full"
        }
    }
}

/// Rest api for the reports downloading through an http server.
class ReportRestApi {

    /// Drone server
    private let server: DroneServer

    /// Base address to access the report api
    private let baseApi = "/api/v1/report"

    /// Constructor
    ///
    /// - Parameter server: the drone server from which report should be accessed
    init(server: DroneServer) {
        self.server = server
    }

    /// Get the list of all reports on the drone
    ///
    /// - Parameters:
    ///   - completion: the completion callback (called on the main thread)
    ///   - reportList: list of reports available on the drone
    /// - Returns: the request
    func getReportList(
        completion: @escaping (_ reportList: [Report]?) -> Void) -> CancelableCore {
            return server.getData(api: "\(baseApi)/reports") { result, data in
                switch result {
                case .success:
                    // listing the crash reports is successful
                    if let data = data {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .formatted(.iso8601Base)
                        do {
                            let reports = try decoder.decode([Report].self, from: data)
                            completion(reports)
                        } catch let error {
                            ULog.w(.crashMLTag,
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

    /// Download a given report to a given directory
    ///
    /// - Parameters:
    ///   - report: the report to download
    ///   - directory: the directory where to put the downloaded report into
    ///   - type: type of report to download, `nil` for default server report type (`ReportType.light`)
    ///   - completion: the completion callback (called on the main thread)
    ///   - fileUrl: url of the locally downloaded file. `nil` if there were an error during download or during copy
    /// - Returns: the request
    func downloadReport(
        _ report: Report, toDirectory directory: URL, type: ReportType = .light,
        completion: @escaping (_ fileUrl: URL?) -> Void) -> CancelableCore {

        let parameters: [String: String]
        switch type {
        case .light:
            parameters = ["anonymous": "yes"]
        case .full:
            parameters = ["anonymous": "no"]
        }

        return server.downloadFile(
            api: report.urlPath, parameters: parameters,
            destination: directory.appendingPathComponent(report.name + (type == .light ? ".anon" : "")),
            progress: { _ in },
            completion: { _, localFileUrl in
                completion(localFileUrl)
        })
    }

    /// Delete a given report on the device
    ///
    /// - Parameters:
    ///   - report: the report to delete
    ///   - completion: the completion callback (called on the main thread)
    ///   - success: whether the delete task was successful or not
    /// - Returns: the request
    func deleteReport(_ report: Report, completion: @escaping (_ success: Bool) -> Void) -> CancelableCore {
        return server.delete(api: "\(baseApi)/reports/\(report.name)") { result in
            switch result {
            case .success:
                completion(true)
            default:
                completion(false)
            }
        }
    }

    /// A report
    struct Report: Decodable {
        enum CodingKeys: String, CodingKey {
            case name
            case date
            case urlPath = "url"
        }

        /// Report name
        let name: String
        /// Report date
        let date: Date
        /// Report url path (needs to be appended to an address and a port at least)
        let urlPath: String
    }
}
