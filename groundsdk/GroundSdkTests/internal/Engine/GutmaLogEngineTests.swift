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

import XCTest
@testable import GroundSdk
import GroundSdkMock

class GutmaLogEngineTests: XCTestCase {

    var gutmaLogManagerRef: Ref<GutmaLogManager>!
    var gutmaLogManager: GutmaLogManager?
    var changeCnt = 0

    let httpSession = MockHttpSession()

    // need to be retained (normally retained by the EnginesController)
    private let utilityRegistry = UtilityCoreRegistry()
    private let facilityStore = ComponentStoreCore()
    private var enginesController: MockEnginesController!

    private var engine: MockGutmaLogEngine!

    override func setUp() {
        super.setUp()
        GroundSdkConfig.sharedInstance.gutmaLogQuotaMb = 2
        enginesController = MockEnginesController(
            utilityRegistry: utilityRegistry,
            facilityStore: facilityStore,
            initEngineClosure: {
                self.engine = MockGutmaLogEngine(enginesController: $0)
                return [self.engine]
        })

        gutmaLogManagerRef = ComponentRefCore(
            store: facilityStore,
            desc: Facilities.gutmaLogManager) { [unowned self] gutmaLogManager in
                self.gutmaLogManager = gutmaLogManager
                self.changeCnt += 1
        }
    }

    override func tearDown() {
        GroundSdkConfig.sharedInstance.gutmaLogQuotaMb = nil
    }

    func testPublishUnpublish() {
        // should be unavailable when the engine is not started
        assertThat(gutmaLogManager, nilValue())

        enginesController.start()
        assertThat(gutmaLogManager, present())
        assertThat(changeCnt, `is`(1))

        enginesController.stop()
        assertThat(gutmaLogManager, nilValue())
        assertThat(changeCnt, `is`(2))
    }

    func testDirectories() {
        // test the location of engineDir (should be in cache folder, named GutmaLogs)
        let engineDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("GutmaLogs", isDirectory: true)
        assertThat(engine.engineDir, `is`(engineDir))
        assertThat(engine.workDir.deletingLastPathComponent(), `is`(engine.engineDir))
    }

    /// test that the facility is update when the collect finishes
    func testFacilityWhenCollectFinished() {
        // create Fake logs
        let gutmaA = engine.engineDir.appendingPathComponent("A.gutma")
        let gutmaB = engine.engineDir.appendingPathComponent("B.gutma")
        let gutmaC = engine.workDir.appendingPathComponent("C.gutma")

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(engine.collectCnt, `is`(1))

        // mock collect finishes
        engine.completeCollection(result: [gutmaA, gutmaB, gutmaC])

        // facility updated accordingly
        assertThat(changeCnt, `is`(2))
        assertThat(gutmaLogManager?.files, presentAnd(`is`([gutmaC, gutmaA, gutmaB])))
        assertThat(engine.collectCnt, `is`(1))
        enginesController.stop()
    }

    func testFacilityAddingAndRemovingGutmas() {
        // create Fake reports
        let gutmaA = engine.workDir.appendingPathComponent("A.gutma")
        let gutmaB = engine.workDir.appendingPathComponent("B.gutma")
        let emptyGutma = Set<URL>()

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(gutmaLogManager?.files, presentAnd(`is`(emptyGutma)))

        // add gutma
        utilityRegistry.getUtility(Utilities.gutmaLogStorage)!.notifyGutmaLogReady(gutmaLogUrl: gutmaA)
        assertThat(changeCnt, `is`(2))
        assertThat(gutmaLogManager?.files, presentAnd(`is`([gutmaA])))

        // add another gutma
        utilityRegistry.getUtility(Utilities.gutmaLogStorage)!.notifyGutmaLogReady(gutmaLogUrl: gutmaB)
        assertThat(changeCnt, `is`(3))
        assertThat(gutmaLogManager?.files, presentAnd(`is`([gutmaA, gutmaB])))

        // add gutmaA again
        utilityRegistry.getUtility(Utilities.gutmaLogStorage)!.notifyGutmaLogReady(gutmaLogUrl: gutmaA)
        assertThat(changeCnt, `is`(3))
        assertThat(gutmaLogManager?.files, presentAnd(`is`([gutmaA, gutmaB])))

        // delete gutma
        assertThat(engine.deleteCnt, `is`(0))
        assertThat(gutmaLogManager?.delete(file: gutmaB), `is`(true))
        utilityRegistry.getUtility(Utilities.gutmaLogStorage)!.notifyGutmaLogReady(gutmaLogUrl: gutmaA)
        assertThat(changeCnt, `is`(4))
        assertThat(gutmaLogManager?.files, presentAnd(`is`([gutmaA])))
        assertThat(engine.deleteCnt, `is`(1))
        // try again
        assertThat(gutmaLogManager?.delete(file: gutmaB), `is`(false))
        assertThat(changeCnt, `is`(4))
        assertThat(gutmaLogManager?.files, presentAnd(`is`([gutmaA])))
        assertThat(engine.deleteCnt, `is`(1))
        // delete the last one
        assertThat(gutmaLogManager?.delete(file: gutmaA), `is`(true))
        assertThat(changeCnt, `is`(5))
        assertThat(gutmaLogManager?.files, presentAnd(`is`(emptyGutma)))
        assertThat(engine.deleteCnt, `is`(2))
    }

    func testGutmaLogQuota() {
        // create fake reports
        let gutmaLogA = engine.engineDir.appendingPathComponent("A.gutma")
        let gutmaLogB = engine.engineDir.appendingPathComponent("B.gutma")
        let gutmaLogC = engine.engineDir.appendingPathComponent("C.gutma")
        let dataA = String.randomString(length: 4 * 1024 * 1024)
        var someDateTime = Date(timeIntervalSinceReferenceDate: 15)
        FileManager.default.createFile(atPath: gutmaLogA.path,
                                       contents: dataA.data(using: .utf8),
                                       attributes: [FileAttributeKey.creationDate: someDateTime])
        let dataB = String.randomString(length: 2 * 1024 * 1024)
        someDateTime = Date(timeIntervalSinceReferenceDate: 30)
        FileManager.default.createFile(atPath: gutmaLogB.path,
                                       contents: dataB.data(using: .utf8),
                                       attributes: [FileAttributeKey.creationDate: someDateTime])
        let dataC = String.randomString(length: 1 * 1024 * 1024)
        someDateTime = Date(timeIntervalSinceReferenceDate: 60)
        FileManager.default.createFile(atPath: gutmaLogC.path,
                                       contents: dataC.data(using: .utf8),
                                       attributes: [FileAttributeKey.creationDate: someDateTime])

        enginesController.start()
        assertThat(FileManager.default.fileExists(atPath: gutmaLogA.path), `is`(false))
        assertThat(FileManager.default.fileExists(atPath: gutmaLogB.path), `is`(false))
        assertThat(FileManager.default.fileExists(atPath: gutmaLogC.path), `is`(true))
    }
}
