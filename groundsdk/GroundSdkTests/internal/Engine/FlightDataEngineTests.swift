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

class FlightDataEngineTests: XCTestCase {

    var flightDataManagerRef: Ref<FlightDataManager>!
    var flightDataManager: FlightDataManager?
    var changeCnt = 0

    let httpSession = MockHttpSession()

    // need to be retained (normally retained by the EnginesController)
    private let utilityRegistry = UtilityCoreRegistry()
    private let facilityStore = ComponentStoreCore()
    private var enginesController: MockEnginesController!

    private var engine: MockFlightDataEngine!

    override func setUp() {
        super.setUp()
        GroundSdkConfig.sharedInstance.flightDataQuotaMb = 2
        enginesController = MockEnginesController(
            utilityRegistry: utilityRegistry,
            facilityStore: facilityStore,
            initEngineClosure: {
                self.engine = MockFlightDataEngine(enginesController: $0)
                return [self.engine]
        })

        flightDataManagerRef = ComponentRefCore(
            store: facilityStore,
            desc: Facilities.flightDataManager) { [unowned self] flightDataManager in
                self.flightDataManager = flightDataManager
                self.changeCnt += 1
        }
    }

    override func tearDown() {
        GroundSdkConfig.sharedInstance.flightDataQuotaMb = nil
    }

    func testPublishUnpublish() {
        // should be unavailable when the engine is not started
        assertThat(flightDataManager, nilValue())

        enginesController.start()
        assertThat(flightDataManager, present())
        assertThat(changeCnt, `is`(1))

        enginesController.stop()
        assertThat(flightDataManager, nilValue())
        assertThat(changeCnt, `is`(2))
    }

    func testDirectories() {
        // test the location of engineDir (should be in the cache folder, named FlightDatas)
        let engineDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("FlightDatas", isDirectory: true)
        assertThat(engine.engineDir, `is`(engineDir))
        assertThat(engine.workDir.deletingLastPathComponent(), `is`(engine.engineDir))
    }

    /// Test that the facility is updated when the collect finishes
    func testFacilityWhenCollectFinishes() {
        // create fake reports
        let pudA = engine.engineDir.appendingPathComponent("A.pud")
        let pudB = engine.engineDir.appendingPathComponent("B.pud")
        let pudC = engine.workDir.appendingPathComponent("C.pud")

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(engine.collectCnt, `is`(1))

        // mock collect finishes
        engine.completeCollection(result: [pudA, pudB, pudC])

        // facility updated accordingly
        assertThat(changeCnt, `is`(2))
        assertThat(flightDataManager?.files, presentAnd(`is`([pudC, pudA, pudB])))
        assertThat(engine.collectCnt, `is`(1))
        enginesController.stop()
    }

    func testFacilityAddingandRemovingPuds() {
        // create fake reports
        let pudA = engine.workDir.appendingPathComponent("A.pud")
        let pudB = engine.workDir.appendingPathComponent("B.pud")
        let emptyPud = Set<URL>()

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(flightDataManager?.files, presentAnd(`is`(emptyPud)))

        // add a pud
        utilityRegistry.getUtility(Utilities.flightDataStorage)!.notifyFlightDataReady(flightDataUrl: pudA)
        assertThat(changeCnt, `is`(2))
        assertThat(flightDataManager?.files, presentAnd(`is`([pudA])))

        // add another pud
        utilityRegistry.getUtility(Utilities.flightDataStorage)!.notifyFlightDataReady(flightDataUrl: pudB)
        assertThat(changeCnt, `is`(3))
        assertThat(flightDataManager?.files, presentAnd(`is`([pudB, pudA])))

        // add pudA again
        utilityRegistry.getUtility(Utilities.flightDataStorage)!.notifyFlightDataReady(flightDataUrl: pudA)
        assertThat(changeCnt, `is`(3))
        assertThat(flightDataManager?.files, presentAnd(`is`([pudB, pudA])))

        // delete a pud
        assertThat(engine.deleteCnt, `is`(0))
        assertThat(flightDataManager?.delete(file: pudB), `is`(true))
        utilityRegistry.getUtility(Utilities.flightDataStorage)!.notifyFlightDataReady(flightDataUrl: pudA)
        assertThat(changeCnt, `is`(4))
        assertThat(flightDataManager?.files, presentAnd(`is`([pudA])))
        assertThat(engine.deleteCnt, `is`(1))
        // try again
        assertThat(flightDataManager?.delete(file: pudB), `is`(false))
        assertThat(changeCnt, `is`(4))
        assertThat(flightDataManager?.files, presentAnd(`is`([pudA])))
        assertThat(engine.deleteCnt, `is`(1))
        // delete the last one
        assertThat(flightDataManager?.delete(file: pudA), `is`(true))
        assertThat(changeCnt, `is`(5))
        assertThat(flightDataManager?.files, presentAnd(`is`(emptyPud)))
        assertThat(engine.deleteCnt, `is`(2))

        enginesController.stop()
    }

    func testFlightDataQuota() {
        let flightDataA = engine.engineDir.appendingPathComponent("A.pud")
        let flightDataB = engine.engineDir.appendingPathComponent("B.pud")
        let flightDataC = engine.engineDir.appendingPathComponent("C.pud")
        let dataA = String.randomString(length: 4 * 1024 * 1024)
        var someDateTime = Date(timeIntervalSinceReferenceDate: 15)
        FileManager.default.createFile(atPath: flightDataA.path,
                                       contents: dataA.data(using: .utf8),
                                       attributes: [FileAttributeKey.creationDate: someDateTime])
        let dataB = String.randomString(length: 2 * 1024 * 1024)
        someDateTime = Date(timeIntervalSinceReferenceDate: 30)
        FileManager.default.createFile(atPath: flightDataB.path,
                                       contents: dataB.data(using: .utf8),
                                       attributes: [FileAttributeKey.creationDate: someDateTime])
        let dataC = String.randomString(length: 1 * 1024 * 1024)
        someDateTime = Date(timeIntervalSinceReferenceDate: 60)
        FileManager.default.createFile(atPath: flightDataC.path,
                                       contents: dataC.data(using: .utf8),
                                       attributes: [FileAttributeKey.creationDate: someDateTime])

        enginesController.start()
        assertThat(FileManager.default.fileExists(atPath: flightDataA.path), `is`(false))
        assertThat(FileManager.default.fileExists(atPath: flightDataB.path), `is`(false))
        assertThat(FileManager.default.fileExists(atPath: flightDataC.path), `is`(true))
    }
}
