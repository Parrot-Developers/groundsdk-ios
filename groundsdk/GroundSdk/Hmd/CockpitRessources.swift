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

// swiftlint:disable nesting
/// Cockpit Data
struct CockpitData: Decodable {

    /// Offset and size for a binary content
    struct BinDef: Decodable {
           enum CodingKeys: String, CodingKey {
               case offset
               case size
           }
           let offset: Int
           let size: Int
    }

    /// Interpupillar distance
    struct IpdDef: Decodable {
        enum CodingKeys: String, CodingKey {
            case defaultValue = "default"
            case max
            case min
        }
        let max: Double?
        let min: Double?
        let defaultValue: Double
    }

    /// Chromatic aberration correction
    struct ChromaCorrection: Decodable {
        enum CodingKeys: String, CodingKey {
            case red = "r"
            case green = "g"
            case blue = "b"
        }
        let red: Double?
        let green: Double?
        let blue: Double?
    }

    /// Decodable protocol
    enum CodingKeys: String, CodingKey {
        case nameDescription = "name"
        case meshSize
        case meshPositions
        case indices
        case colorFilter
        case texCoords
        case ipd
        case chromaCorrection
    }

    /// Friendly Name
    let nameDescription: String?
    /// Size of the distortion mesh in mm
    let meshSize: Double
    /// Vertex positions (distortion mesh)
    let meshPositions: BinDef
    /// Indices for meshPosition (OpenGl)
    let indices: BinDef
    /// Pixel color correction
    let colorFilter: BinDef?
    /// Texture coords (openGl)
    let texCoords: BinDef
    /// Interpupillar distance
    let ipd: IpdDef
    /// Chromatic aberration correction (scale for Red / Green / Blue)
    let chromaCorrection: ChromaCorrection?
}

extension CockpitData {
    /// Interval allowed for interpupillary distance
    var minMaxInterpupillaryDistanceMM: ClosedRange<CGFloat> {
        let min = ipd.min ?? ipd.defaultValue
        let max = ipd.max ?? ipd.defaultValue
        return (CGFloat(min) ... CGFloat(max))
    }
    /// Default interpupillary distance
    var defaultInterpupillaryDistanceMM: CGFloat {
        return CGFloat(ipd.defaultValue)
    }
    /// Correction of chromatic aberration (applied at the shader level)
    var calculatedDistScaleFactor: (red: Float, green: Float, blue: Float) {
        let red = chromaCorrection?.red ?? 1
        let green = chromaCorrection?.green ?? 1
        let blue = chromaCorrection?.blue ?? 1
        return (Float(red), Float(green), Float(blue))
    }
}

/// Class to load and use different models of glasses
class CockpitRessources {

    /// Version of the loaded ressouce file
    let version: Int
    /// Offset of the binary data in the `data` property (binary data after the JSON header)
    let binaryOffset: Int
    /// Url of the loaded ressource file
    private var fileURL: URL
    /// Datas read from the resspuce file
    private var data: Data
    /// All cockpits data obtained from the resource file
    private var cockpits: [String: CockpitData]?
    /// All cockpits names id obtained from the resource file
    var cockpitNames: [String]? {
        return cockpits?.map { $0.key }
    }

    /// Constructor
    ///
    /// - Parameter fileURL: URL of the ressource file
    init?(fileURL: URL) {

        do {
            let data = try Data(contentsOf: fileURL)
            self.fileURL = fileURL
            self.data = data
        } catch {
            ULog.e(.hmdTag, "CockitsRessources(\(fileURL)) - \(error)")
            return nil
        }

        // Magic
        var index = 20 // magic size

        //1 byte: version (1)
        version = Int(data.subdata(in: index ..< (index + 1)).int8Data())
        index += 1

        // JSON Header length (Int 4 bytes)
        let lengthJson = data.subdata(in: index ..< (index + 4)).int32Data()
        index += 4

        let dataJson = data.subdata(in: index ..< index+Int(lengthJson))
        binaryOffset = Int(index) + Int(lengthJson)
        cockpits = readCockpits(data: dataJson)
    }

    /// Reads the JSON header with all cockpits descriptions.
    ///
    /// - Parameter data: JSON Data
    /// - Returns: a dictionary of Cockpits
    private func readCockpits(data: Data) -> [String: CockpitData]? {
        let decoder = JSONDecoder()
        do {
            let cockpitData = try decoder.decode([String: CockpitData].self, from: data)
            return cockpitData
        } catch {
            ULog.e(.hmdTag, "CockpitData JSON \(error)")
        }
        return nil
    }

    /// Get a Cockpit from the cockpit name
    /// - Parameter name: Cockpit's name
    ///
    /// - Returns: The Cockpit or nil
    func getCockpit(name: String) -> CockpitData? {
        return cockpits?[name]
    }

    /// Extract the binary data from a BinDef struct
    /// - Parameter binDef: BinDef struct
    /// - Returns: an array of the extracted data
    private func getArray<EltType>(binDef: CockpitData.BinDef) -> [EltType] {

        let offset = binDef.offset + binaryOffset
        let size = binDef.size

        let dataPos = self.data.subDataNoCopy(offset: offset, size: size)

        let retArray = dataPos.withUnsafeBytes {
            Array($0.bindMemory(to: EltType.self))
        }
        return retArray
    }

    func getPositions(cockpitName: String) -> [Float32] {
        guard let cockpit = getCockpit(name: cockpitName) else {
            return [Float32]()
        }
        return getArray(binDef: cockpit.meshPositions)
    }

    func getColorsFilter(cockpitName: String) -> [Float32]? {
        guard let cockpit = getCockpit(name: cockpitName), let colorsFilter = cockpit.colorFilter else {
            return nil
        }
        return getArray(binDef: colorsFilter)
    }

    func getTextCoords(cockpitName: String) -> [Float32] {
        guard let cockpit = getCockpit(name: cockpitName) else {
            return [Float32]()
        }
        return getArray(binDef: cockpit.texCoords)
    }

    func getIndices(cockpitName: String) -> [GLuint] {
        guard let cockpit = getCockpit(name: cockpitName) else {
            return [GLuint]()
        }
        return getArray(binDef: cockpit.indices)
    }
}

// MARK: - Extention Data to get binaries Values
extension Data {

    func int8Data(atOffset: Int = 0) -> Int8 {
        return self.withUnsafeBytes { $0.load(fromByteOffset: atOffset, as: Int8.self) }
    }

    func int32Data(atOffset: Int = 0, bigEndian: Bool = false) -> Int32 {
        return self.withUnsafeBytes {
            let ret = $0.load(fromByteOffset: atOffset, as: Int32.self)
            return bigEndian ? ret : ret.bigEndian
        }
    }

    func subDataNoCopy(offset: Int, size: Int) -> Data {
        // guard offset and size are valid ...
        let segment: Data = self.withUnsafeBytes { buf in
            let mbuf = UnsafeMutablePointer(mutating: buf.bindMemory(to: UInt8.self).baseAddress!)
            return Data(bytesNoCopy: mbuf.advanced(by: offset), count: size, deallocator: .none)
        }
        return segment
    }
}
