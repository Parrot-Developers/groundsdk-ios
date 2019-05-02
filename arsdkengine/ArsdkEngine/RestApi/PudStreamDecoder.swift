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
import CoreLocation

/// Errors for the Pud decoder
enum PudError: Error {
    /// Incorrect or missing header
    case badHeader
    /// Incorrect or missing columns description
    case badColumnsDescription
    /// Incomplete file
    case incompleteFile
}
extension PudError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .badHeader:
            return NSLocalizedString("PudError - badHeader", comment: "Incorrect or missing header")
        case .badColumnsDescription:
            return NSLocalizedString(
                "PudError - badColumnsDescription", comment: "Incorrect or missing columns description")
        case .incompleteFile:
            return NSLocalizedString("PudError - incompleteFile", comment: "Incomplete or corrupted datas")
        }
    }
}

/// StreamDecoder in order to convert PUDs files
class PudStreamDecoder: StreamDecoder {

    /// States for the decode processing
    private enum DecoderState {
        case waitingHeader, loopLines, writingHeadersColumns, stopped
        func nextState () -> DecoderState {
            switch self {
            case .waitingHeader:
                return .writingHeadersColumns
            case .writingHeadersColumns:
                return .loopLines
            default:
                return .stopped
            }
        }
    }

    /// BinaryType, represents types described in the binary Pud file
    private enum BinaryType {
        case integer
        case bool
        case float
        case double

        init?(_ rawString: String) {
            switch rawString {
            case "integer": self = .integer
            case "boolean": self = .bool
            case "float": self = .float
            case "double": self = .double
            default:
                return nil
            }
        }
    }

    /// A column description as received in the Pud file
    private struct ColumnDescription {
        let name: String
        let size: Int
        let binaryType: BinaryType

        init?(properties: [String: Any]) {
            if let name = properties["name"] as? String,
                let size = properties["size"] as? Int,
                let binaryType = BinaryType(properties["type"] as? String ?? "") {

                self.name = name
                self.size = size
                self.binaryType = binaryType
            } else {
                return nil
            }
        }
    }

    /// Minimal allocation buffer for streamDecoder
    static private let minimalBufferSize = 2048

    /// Charset used to trim JSON
    static private let trimCharSetJson =  CharacterSet(charactersIn: "{}\n ")

    /// Interval between two 'time' infos, over which the rest of binary data is considered invalid and dropped
    static private let maxTimeInterval = 10000

    /// Special value returned by `latitude` or `longitude` when the coordinate is not known.
    private static let unknownCoordinate: Double = 500

    /// Name of the received field "details_headers". This field contains an array with all columns descriptions
    private let inDetailsHeadersName = "details_headers"

    /// State of the Stream Decoder
    private var state = DecoderState.waitingHeader

    /// Data to be processed
    private var dataToProcess = Data(capacity: minimalBufferSize)

    /// All general informations to write at the end of the generated file
    private var outFinalInformations: [String: Any]?

    /// Columns descriptions
    private var columns: [ColumnDescription]?
    /// Size in bytes of one line (sum of columns size)
    private var lineSize = 0
    /// count the count of written lines
    private var linesCount = 0

    /// Latest time info parsed from input binary data.
    private var latestTime = 0

    /// Time when the drone started flying, parsed from input binary data. `nil` if not known yet.
    private var flightStartTime: Int?

    /// Time the drone spent flying. Computed from input binary data based on the drone flying state changes.
    private var flyingTime = 0

    /// Counts alerts from input binary data.
    private var alertCount = 0

    /// Latest Alert from binary data.
    private var latestAlert = ArsdkFeatureArdrone3PilotingstateAlertstatechangedState.none

    /// Device GPS availability, parsed from input binary data.
    private var gpsAvailable = false

    /// First meaningful device location parsed from binary data.
    private var firstDeviceLocation: CLLocationCoordinate2D?

    /// Latest meaningful controller location parsed from binary data.
    private var latestControllerLocation: CLLocationCoordinate2D?

    // Stream Decoder Concordance
    func decodeStream(_ data: Data?) throws -> Data? {
        var retData: Data?
        if let data = data {
            dataToProcess.append(data)

            var stop = false
            while !stop && state != .stopped {
                switch state {
                case .waitingHeader:
                    // look for the header (a readable JSON header, null terminated)
                    if let resultDetectHeaderLength = detectHeaderLength() {
                        let dataHeader = dataToProcess.subdata(in: 0..<resultDetectHeaderLength)
                        // remove the header and the \0 byte
                        dataToProcess.removeSubrange(0..<(resultDetectHeaderLength+1))
                        // extract the header and convert it to a dictionary
                        var header: [String: Any]?
                        do {
                            header = try JSONSerialization.jsonObject(with: dataHeader, options: []) as? [String: Any]
                        } catch {
                            throw (PudError.badHeader)
                        }
                        // checks and process the header
                        if let header = header, processReceivedHeader(header: header) == true {
                            state = state.nextState()
                        } else {
                            throw (PudError.badHeader)
                        }
                    } else {
                        // header is not yet detected. We try later
                        stop = true
                    }

                case .writingHeadersColumns:
                    // add { at the beginning of the json file
                    retData = "{".data(using: .utf8)
                    // add columns descriptions
                    if let headerColumns = headerColumnsJson() {
                        retData?.append(headerColumns)
                    } else {
                        throw PudError.badColumnsDescription
                    }
                    // Prepare the netx field: add ","details_data":["
                    let strAdd = ",\"details_data\":["
                    retData?.append(strAdd.data(using: .utf8)!)
                    state = state.nextState()

                case .loopLines:
                    while dataToProcess.count >= lineSize {
                        // process \(lineSize) bytes in the buffer dataToProcess
                        if let lineData = processALine() {
                            // alloc a retData if none
                            if retData == nil {
                                retData = Data(capacity: PudStreamDecoder.minimalBufferSize)
                            }
                            linesCount += 1
                            if linesCount > 1 {
                                // add ',' if it is not the first line
                                retData!.append((",".data(using: .utf8))!)
                            }
                            // write the line
                            retData!.append(lineData)
                        }
                        // remove the proceed line (advance the buffer)
                        dataToProcess.removeSubrange(0..<lineSize)
                    }
                    // no more data (empty buffer or insufficent size)
                    stop = true

                default:
                    stop = true
                }
            } // end while
        } else {
            // data is nil, this is the end of the stream
            // Check that we have no pending data, otherwise the stream had stopped before reaching the end of the file
            if dataToProcess.count > 0 {
                throw(PudError.incompleteFile)
            }

            // finalise the outut
            // close the array of values
            let strAdd = "],"
            retData = strAdd.data(using: .utf8)

            // add global informations
            if let addData = getGlobalInformation() {
                retData!.append(addData)
            } else {
                throw(PudError.incompleteFile)
            }

            // close Json
            let strAddEnd = "}"
            retData!.append((strAddEnd.data(using: .utf8))!)
        }
        return retData
    }

    /// Search the header in `dataToProcess``. The header should be \0 end terminated
    ///
    /// - Returns: returns the length of the header if it was found, nil otherwise
    private func detectHeaderLength() -> Int? {
        return dataToProcess.index(where: { $0 == 0 })
    }

    /// Process data received in the header of the flight data file.
    ///
    ///  - Keep all generic informations in order to write them later at the end of the output file. See
    /// `outFinalInformations`. Remove the value `detailsHeadersName` and add computed values
    ///  - Process all columns descriptions
    ///
    /// - Parameter header: the received header in the flight data file
    /// - Returns: true if header is OK, false otherwise
    private func processReceivedHeader(header: [String: Any]) -> Bool {

        guard let receivedHeaders = header[inDetailsHeadersName] as? [[String: Any]] else {
            return false
        }
        // Keep all generic informations. These values will be rewritten at the end of the stream
        outFinalInformations = header
        outFinalInformations?.removeValue(forKey: inDetailsHeadersName)

        // Process columns description in `receivedHeaders`
        columns = receivedHeaders.compactMap { ColumnDescription(properties: $0) }

        // compute the size of one line (sum of columns size)
        lineSize =  (columns?.reduce(0) { tmpSize, entry in tmpSize + entry.size }) ?? 0
        if lineSize <= 0 {
            return false
        }
        return true
    }

    /// Return a JSON for the field "details_headers", describing all columns names
    ///
    /// - Note: this function add a extra column "speed"
    ///
    /// - Returns: a JSON Data object, or nil in an error occurs
    private func headerColumnsJson() -> Data? {
        var retData: Data?
        let encoder = JSONEncoder()
        // add a Column for speed
        var columnsNames = columns?.map({ $0.name })
        columnsNames?.append("speed")
        if let columnsNames = columnsNames, let dataColumnsJson = try? encoder.encode(columnsNames) {
            let strAdd = "\"details_headers\":"
            retData = strAdd.data(using: .utf8)!
            retData!.append(dataColumnsJson)
        }
        return retData
    }

    /// Reads and decodes a row of data in the global input buffer of the stream (`dataToProcess`). In addition,
    /// some calculated data is added to the result (such as speed). Finally, some data is collected in order to be
    /// written later at the end of the stream (such as Gps positions, flight time or alerts)
    ///
    /// - Note: `dataToProcess` must contain at least one row of data (this function does not check the actual size
    /// of `dataToProcess`
    ///
    /// - Note: The timestamp of each line is checked. In case of inconsistency the parsing is stopped and nil
    /// is returned
    ///
    /// - Returns: a JSON Data object corresponding to the decoded line, or nil in an error occurs
    private func processALine () -> Data? {
        /// read buffer position
        var indexInLine = 0
        /// values collected from binary
        var values = [Any]()
        /// time read in the row
        var timeRead: Int?
        /// computed speed
        var speedSquare = 0.0

        var productLatitude: Double?
        var productLongitude: Double?
        var controllerLatitude: Double?
        var controllerLongitude: Double?

        // For each espected column, read the value from binary
        columns?.forEach { aColumn in
            let addValue: Any
            switch aColumn.binaryType {
            case .integer:
                addValue = dataToProcess.getInt(at: indexInLine, size: aColumn.size)
            case .float:
                addValue = dataToProcess.getFloat32(at: indexInLine)
            case .double:
                addValue = dataToProcess.getFloat64(at: indexInLine)
            case .bool:
                addValue = dataToProcess.getBool(at: indexInLine, size: aColumn.size)
            }
            indexInLine += aColumn.size
            values.append(addValue)

            /// process computed values
            switch aColumn.name {
            case "time":
                timeRead = addValue as? Int ?? 0

            case "speed_vx", "speed_vy", "speed_vz":
                let speed = addValue as? Double ?? 0.0
                speedSquare += pow(speed, 2)

            case "product_gps_available":
                let available =  addValue as? Bool ?? false
                gpsAvailable = available || gpsAvailable

            case "product_gps_latitude":
                productLatitude = addValue as? Double

            case "product_gps_longitude":
                productLongitude = addValue as? Double

            case "controller_gps_latitude":
                controllerLatitude = addValue as? Double

            case "controller_gps_longitude":
                controllerLongitude = addValue as? Double

            case "alert_state":
                let intValue = addValue as? Int ?? -1
                let alert: ArsdkFeatureArdrone3PilotingstateAlertstatechangedState =
                    ArsdkFeatureArdrone3PilotingstateAlertstatechangedState(rawValue: intValue) ?? .none
                if alert != latestAlert {
                    switch alert {
                    case .user, .cutOut, .tooMuchAngle:
                        alertCount += 1
                    default:
                        break
                    }
                    latestAlert = alert
                }

            case "flying_state":
                let intValue = addValue as? Int ?? -1
                let flyingState: ArsdkFeatureArdrone3PilotingstateFlyingstatechangedState =
                    ArsdkFeatureArdrone3PilotingstateFlyingstatechangedState(rawValue: intValue) ?? .sdkCoreUnknown
                switch flyingState {
                case .landed:
                    if let flightStartTime = flightStartTime, let timeRead = timeRead {
                        flyingTime += timeRead - flightStartTime
                        self.flightStartTime = nil
                    }
                case .takingoff, .hovering, .flying:
                    if flightStartTime == nil, let timeRead = timeRead {
                        flightStartTime = timeRead
                    }
                default:
                    break
                }
            default:
                break
            }
        } // end parsing all columns

        // update latest time
        if let timeRead = timeRead {
            if timeRead < latestTime || timeRead > latestTime + PudStreamDecoder.maxTimeInterval {
                // Error: stop parsing if time is incoherent
                return nil
            }
            latestTime = timeRead
        }

        // write computed speed value
        if speedSquare.isInfinite || speedSquare.isNaN {
            values.append(0.0)
        } else {
            values.append(sqrt(speedSquare))
        }

        // the new line is now ready to be Json endoded
        let jsonObjet = try? JSONSerialization.data(withJSONObject: values, options: [])

        // Keep other "global informations" for later (processed at the end of the stream)
        // update known first device location
        if firstDeviceLocation == nil {
            if let productLatitude =  productLatitude, let productLongitude = productLongitude,
                productLatitude != PudStreamDecoder.unknownCoordinate,
                productLongitude != PudStreamDecoder.unknownCoordinate {
                let productLocation = CLLocationCoordinate2D(latitude: productLatitude, longitude: productLongitude)
                if CLLocationCoordinate2DIsValid(productLocation) {
                    firstDeviceLocation = productLocation
                }
            }
        }
        // update known lastest controller location
        if let controllerLatitude =  controllerLatitude, let controllerLongitude = controllerLongitude,
            controllerLatitude != PudStreamDecoder.unknownCoordinate,
            controllerLongitude != PudStreamDecoder.unknownCoordinate {
            let controllerLocation = CLLocationCoordinate2D(
                latitude: controllerLatitude, longitude: controllerLongitude)
            if CLLocationCoordinate2DIsValid(controllerLocation) {
                latestControllerLocation = controllerLocation
            }
        }
        return jsonObjet
    }

    /// Returns the latest JSON informations (end of the file)
    /// - The general information read in the initial header
    /// - The values collected and calculated when parsing the datas
    ///
    /// - Returns: a JSON Data object, or nil in an error occurs
    private func getGlobalInformation() -> Data? {

        // finalize flying time if necessary
        if let flightStartTime = flightStartTime {
            flyingTime += latestTime - flightStartTime
        }

        // Add the values that were retrieved at the beginning of the stream
        var outValues = outFinalInformations ?? [String: Any]()

        // write collected data
        outValues["crash"] =  alertCount
        outValues["total_run_time"] = latestTime
        outValues["run_time"] = flyingTime
        outValues["gps_available"] = gpsAvailable
        let location = firstDeviceLocation == nil ? latestControllerLocation : firstDeviceLocation
        if let location = location {
            outValues["gps_latitude"] = location.latitude
            outValues["gps_longitude"] = location.longitude
        } else {
            outValues["gps_latitude"] = PudStreamDecoder.unknownCoordinate
            outValues["gps_longitude"] = PudStreamDecoder.unknownCoordinate
        }

        // add information in Data
        let jsonObjet = try? JSONSerialization.data(withJSONObject: outValues, options: [])
        if let jsonObjet = jsonObjet, let strJson = String(data: jsonObjet, encoding: .utf8) {
            return strJson.trimmingCharacters(in: PudStreamDecoder.trimCharSetJson).data(using: .utf8)
        }

        return jsonObjet
    }

}

// MARK: - Extention Data to get binaries Values
extension Data {

    func getInt(at index: Int, size: Int ) -> Int {
        switch size {
        case 2:
            let ret = self.subdata(in: index ..< (index + size)).withUnsafeBytes { (ptr: UnsafePointer<Int16>)  in
                ptr.pointee
            }
            return Int(ret)
        case 4:
            let ret = self.subdata(in: index ..< (index + size)).withUnsafeBytes { (ptr: UnsafePointer<Int32>)  in
                ptr.pointee
            }
            return Int(ret)
        case 8:
            let ret = self.subdata(in: index ..< (index + size)).withUnsafeBytes { (ptr: UnsafePointer<Int64>)  in
                ptr.pointee
            }
            return Int(ret)
        default: // 1
            let ret = self.subdata(in: index ..< (index + size)).withUnsafeBytes { (ptr: UnsafePointer<Int8>)  in
                ptr.pointee
            }
            return Int(ret)
        }
    }

    func getBool(at index: Int, size: Int ) -> Bool {
        let valInt = self.getInt(at: index, size: size)
        return valInt != 0
    }

    func getFloat32(at index: Int) -> Float32 {
        let retFloat: Float32

            let ret = self.subdata(in: index ..< (index + 4)).withUnsafeBytes { (ptr: UnsafePointer<Float32>)  in
                ptr.pointee
            }
            retFloat = ret

        if retFloat.isNaN || retFloat.isInfinite {
            return 0.0
        }
        return retFloat
    }

    func getFloat64(at index: Int) -> Float64 {
        let retFloat: Float64

        let ret = self.subdata(in: index ..< (index + 8)).withUnsafeBytes { (ptr: UnsafePointer<Float64>)  in
            ptr.pointee
        }
        retFloat = ret

        if retFloat.isNaN || retFloat.isInfinite {
            return 0.0
        }
        return retFloat
    }
}
