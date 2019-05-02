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
//    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES LOSS
//    OF USE, DATA, OR PROFITS OR BUSINESS INTERRUPTION) HOWEVER CAUSED
//    AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
//    OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//    SUCH DAMAGE.

import Foundation
import XCTest

@testable import ArsdkEngine
@testable import GroundSdk
import SdkCoreTesting

class FlightDataDecoderTests: XCTestCase {

    // files in test bundle
    let binaryPudName = "anafi_binary_pud_1"
    let expectedResultName = "expected_result.pud"

    // out files (in document)
    let resultName = "file_result.pud"

    var testBundle: Bundle!

    override func setUp() {
        testBundle = Bundle(for: type(of: self))
        super.setUp()
    }

    func testConvertAfile() {
        let inData = getBundleDataWithFileName(binaryPudName)
        assertThat(inData, present())

        // be sure we have no result file
        deleteFile(name: resultName)
        let dataEmpy = getDocumentDataWithFileName(resultName)
        assertThat(dataEmpy, nilValue())

        // get a decoder
        let pudDecoder = PudStreamDecoder()
        // get a writer and decode file
        let fileResultUrl = getDocumentUrlWithFileName(resultName)
        let pudWriter = StreamWriter(withFileUrl: fileResultUrl, streamDecoder: pudDecoder)
        var nbError = 0
        do {
            try pudWriter.processData(inData)
        } catch {
            nbError += 1
        }
        // end stream
        do {
            try pudWriter.processData(nil)
        } catch {
            nbError += 1
        }
        assertThat(nbError, `is`(0))

        print ("Pud generated file \(pudWriter.resultUrl)")

        let okJson = compareFilesJson(documentFileName: resultName, bundleFileName: expectedResultName)
        assertThat(okJson, `is`(true))
    }

    func testConvertAfileWithChunks() {

        var inData = getBundleDataWithFileName(binaryPudName)
        assertThat(inData, present())

        // be sure we have no result file
        deleteFile(name: resultName)
        let dataEmpy = getDocumentDataWithFileName(resultName)
        assertThat(dataEmpy, nilValue())

        // get a decoder
        let pudDecoder = PudStreamDecoder()
        // get a writer and decode file
        let fileResultUrl = getDocumentUrlWithFileName(resultName)
        let pudWriter = StreamWriter(withFileUrl: fileResultUrl, streamDecoder: pudDecoder)

        let totalBinarySize = inData!.count
        let chunkSize = totalBinarySize / 100
        var nbError = 0
        while inData!.count > 0 {
            let currentChunkSize = min(chunkSize, inData!.count)
            let chunkData  = inData?.subdata(in: 0..<currentChunkSize)
            do {
                try pudWriter.processData(chunkData)
            } catch {
                nbError += 1
            }
            inData!.removeSubrange(0..<currentChunkSize)
        }
        // end stream
        do {
            try pudWriter.processData(nil)
        } catch {
            nbError += 1
        }
        assertThat(nbError, `is`(0))

        print ("Pud generated file \(pudWriter.resultUrl)")

        let okJson = compareFilesJson(documentFileName: resultName, bundleFileName: expectedResultName)
        assertThat(okJson, `is`(true))
    }

    func testConvertACorruptedFileWithChunks() {
        var inData = getBundleDataWithFileName(binaryPudName)
        assertThat(inData, present())

        // be sure we have no result file
        deleteFile(name: resultName)
        let dataEmpy = getDocumentDataWithFileName(resultName)
        assertThat(dataEmpy, nilValue())

        // get a decoder
        let pudDecoder = PudStreamDecoder()
        // get a writer and decode file
        let fileResultUrl = getDocumentUrlWithFileName(resultName)
        let pudWriter = StreamWriter(withFileUrl: fileResultUrl, streamDecoder: pudDecoder)

        let totalBinarySize = inData!.count
        let chunkSize = totalBinarySize / 100
        var isError = false
        var chunkNumber = 0
        while inData!.count > 0 {
            let currentChunkSize = min(chunkSize, inData!.count)
            let chunkData  = inData?.subdata(in: 0..<currentChunkSize)
            do {
                // CORRUPTION
                if chunkNumber != 66 {
                    try pudWriter.processData(chunkData)
                }
            } catch {
                isError = true
            }
            inData!.removeSubrange(0..<currentChunkSize)
            chunkNumber += 1
        }
        // end stream
        do {
            try pudWriter.processData(nil)
        } catch {
            isError = true
        }
        assertThat(isError, `is`(true))
        let resultData = getDocumentDataWithFileName(resultName)
        assertThat(resultData, nilValue())
    }
}

extension FlightDataDecoderTests {

    /// Compare Json values from two files
    ///
    /// - Parameters:
    ///   - documentFileName: name of the file in documents
    ///   - bundleFileName: name of the file in Bundle
    /// - Returns: true if each file contains a Json and if they are equal, false otherwise
    func compareFilesJson(documentFileName: String, bundleFileName: String) -> Bool {
        var retOk = false
        // get data from documentFileName file and compare with bundleFileName file
        if let resultData = getDocumentDataWithFileName(documentFileName),
            let bundleResult = getBundleDataWithFileName(bundleFileName),
            let resultJson = try? JSONSerialization.jsonObject(with: resultData, options: []) as! [String: Any],
            let bundleJson =  try? JSONSerialization.jsonObject(with: bundleResult, options: []) as! [String: Any] {
            let resulNSDictionary = NSDictionary(dictionary: resultJson)
            retOk = resulNSDictionary.isEqual(to: bundleJson)
        }
        return retOk
    }

    func getDocumentUrlWithFileName(_ name: String ) -> URL {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let url = NSURL(fileURLWithPath: path)
        let fileResultUrl = url.appendingPathComponent(name)
        return fileResultUrl!
    }

    func getBundleUrlWithFileName(_ name: String ) -> URL {
        let url = testBundle.url(forResource: name, withExtension: "")
        assertThat(url, present())
        return url!
    }

    func getBundleDataWithFileName(_ name: String ) -> Data? {
        let url = getBundleUrlWithFileName(name)
        let data = try? Data(contentsOf: url)
        return data
    }

    func getDocumentDataWithFileName(_ name: String ) -> Data? {
        let urlIn = getDocumentUrlWithFileName(name)
        let data = try? Data(contentsOf: urlIn)
        return data
    }

    func deleteFile(name: String) {
        let fileManager = FileManager.default
        let url = getDocumentUrlWithFileName(name)
        // delete file if exists
        if fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                assert(false)
            }
        }
    }
}
