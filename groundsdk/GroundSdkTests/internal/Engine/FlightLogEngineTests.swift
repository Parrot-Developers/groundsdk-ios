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

class FlightLogEngineTests: XCTestCase {

    var flightLogReporterRef: Ref<FlightLogReporter>!
    var flightLogReporter: FlightLogReporter?
    var changeCnt = 0

    let internetConnectivity = MockInternetConnectivity()
    let userAccountUtility = UserAccountUtilityCoreImpl()

    let httpSession = MockHttpSession()

    // need to be retained (normally retained by the EnginesController)
    private let utilityRegistry = UtilityCoreRegistry()
    private let facilityStore = ComponentStoreCore()
    private var enginesController: MockEnginesController!

    private var engine: MockFlightLogEngine!

    override func setUp() {
        super.setUp()
        GroundSdkConfig.sharedInstance.flightLogQuotaMb = 2
        enginesController = MockEnginesController(
            utilityRegistry: utilityRegistry,
            facilityStore: facilityStore,
            initEngineClosure: {
                self.engine = MockFlightLogEngine(enginesController: $0)
                return [self.engine]
        })

        utilityRegistry.publish(utility: internetConnectivity)
        utilityRegistry.publish(utility: userAccountUtility)
        utilityRegistry.publish(utility: CloudServerCore(utilityRegistry: utilityRegistry, httpSession: httpSession))

        // add a user, otherwise the flightLog process is inactive
        // (the default is "no user" and "anonymous data not allowed")
        userAccountUtility.update(userAccountInfo: UserAccountInfoCore(account: "mockUserForFlightLog",
                                            accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.allowUpload))

        flightLogReporterRef = ComponentRefCore(
            store: facilityStore,
            desc: Facilities.flightLogReporter) { [unowned self] flightLogReporter in
                self.flightLogReporter = flightLogReporter
                self.changeCnt += 1
        }
    }

    override func tearDown() {
        GroundSdkConfig.sharedInstance.flightLogQuotaMb = nil
    }

    func testPublishUnpublish() {
        // should be unavailable when the engine is not started
        assertThat(flightLogReporter, nilValue())

        enginesController.start()
        assertThat(flightLogReporter, present())
        assertThat(changeCnt, `is`(1))

        enginesController.stop()
        assertThat(flightLogReporter, nilValue())
        assertThat(changeCnt, `is`(2))
    }

    func testDirectories() {
        // test the location of engineDir (should be in the cache folder, named FlightLogs)
        let engineDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("FlightLogs", isDirectory: true)
        assertThat(engine.engineDir, `is`(engineDir))
        assertThat(engine.workDir.deletingLastPathComponent(), `is`(engine.engineDir))
    }

    /// No flight log if the user is nil and if anonymous data are not allowed
    func testAnonymousDataNotAllowed() {
        // create fake reports
        let flightLogA = engine.engineDir.appendingPathComponent("A.bin")
        let flightLogB = engine.engineDir.appendingPathComponent("B.bin")
        let flightLogC = engine.workDir.appendingPathComponent("C.bin")

        enginesController.start()

        // erase old account from setUp
        userAccountUtility.update(userAccountInfo: UserAccountInfoCore(account: nil,
                                            anonymousDataPolicy: AnonymousDataPolicy.deny,
                                            accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload))
        // internet is available
        internetConnectivity.mockInternetAvailable = true

        assertThat(changeCnt, `is`(1))
        assertThat(flightLogReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))

        // mock collect finishes
        engine.completeCollection(result: [flightLogA, flightLogB])

        let task = httpSession.popLastTask() as? MockUploadTask
        assertThat(task, nilValue())
        assertThat(flightLogReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 2))))
        assertThat(engine.collectCnt, `is`(1))

        // should not delete file if no user & no anonymous data allowed
        assertThat(engine.latestDeletedFlightLogUrl, nilValue())

        // no user account and anonymous data allowed should not trigger upload
        userAccountUtility.update(userAccountInfo: UserAccountInfoCore(account: nil,
                                            anonymousDataPolicy: AnonymousDataPolicy.allow,
                                            accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload))
        utilityRegistry.getUtility(Utilities.flightLogStorage)!.notifyFlightLogReady(flightLogUrl: flightLogC)

        assertThat(flightLogReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 3))))
        assertThat(engine.pendingFlightLogUrls, hasCount(3))

        enginesController.stop()
    }

    /// Test that the upload is triggered when there is internet and the collect finishes
    func testUploadTriggeredWhenCollectFinishesBeforeReportAddedAndInternet() {
        // create fake reports
        let flightLogA = engine.engineDir.appendingPathComponent("A.bin")
        let flightLogB = engine.engineDir.appendingPathComponent("B.bin")
        let flightLogC = engine.workDir.appendingPathComponent("C.bin")
        // internet is available
        internetConnectivity.mockInternetAvailable = true

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(flightLogReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))

        // mock collect finishes
        engine.completeCollection(result: [flightLogA, flightLogB])

        let task = httpSession.popLastTask() as! MockUploadTask

        // after completion, upload should be triggered and facility updated accordingly
        assertThat(changeCnt, `is`(2))
        assertThat(flightLogReporter, presentAnd(allOf(isUploading(), has(pendingCount: 2))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(task.fileUrl, `is`(flightLogA))
        assertThat(task.request.allHTTPHeaderFields?["x-account"], presentAnd(`is`("mockUserForFlightLog")))
        assertThat(engine.pendingFlightLogUrls, contains(flightLogA, flightLogB))

        // check that when report is added, it is added at the end of the list
        // should not trigger a change count since flightLogReporter is Uploading already
        // file has been added to pending list url.
        utilityRegistry.getUtility(Utilities.flightLogStorage)!.notifyFlightLogReady(flightLogUrl: flightLogC)
        assertThat(changeCnt, `is`(2))
        assertThat(flightLogReporter, presentAnd(allOf(isUploading(), has(pendingCount: 3))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(engine.pendingFlightLogUrls, contains(flightLogA, flightLogB, flightLogC))

        enginesController.stop()
    }

    /// Test that the upload is triggered when there is internet and the collect finishes
    func testUploadTriggeredWhenReportAddedBeforeCollectFinishesAndInternet() {
        // create fake reports
        let flightLogA = engine.engineDir.appendingPathComponent("A.bin")
        let flightLogB = engine.engineDir.appendingPathComponent("B.bin")
        let flightLogC = engine.workDir.appendingPathComponent("C.bin")
        // internet is available
        internetConnectivity.mockInternetAvailable = true

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(flightLogReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))

        // mock report added, after that, upload should be triggered and facility updated accordingly
        utilityRegistry.getUtility(Utilities.flightLogStorage)!.notifyFlightLogReady(flightLogUrl: flightLogC)
        let task = httpSession.popLastTask() as! MockUploadTask

        assertThat(changeCnt, `is`(2))
        assertThat(flightLogReporter, presentAnd(allOf(isUploading(), has(pendingCount: 1))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(task.fileUrl, `is`(flightLogC))
        assertThat(engine.pendingFlightLogUrls, contains(flightLogC))

        // mock collect finishes
        engine.completeCollection(result: [flightLogA, flightLogB])

        // check that when reports are added, they are added at the end of the list
        // should not trigger a change count since flightLogReporter is Uploading already
        // files have been added to pending list url.
        assertThat(changeCnt, `is`(2))
        assertThat(flightLogReporter, presentAnd(allOf(isUploading(), has(pendingCount: 3))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(engine.pendingFlightLogUrls, contains(flightLogC, flightLogA, flightLogB))

        enginesController.stop()
    }

    // check that download does not try to start if there is no internet connectivity
    func testStartWithoutInternet() {
        // create fake reports
        let flightLogA = engine.engineDir.appendingPathComponent("A.bin")
        let flightLogB = engine.engineDir.appendingPathComponent("B.bin")
        let flightLogC = engine.workDir.appendingPathComponent("C.bin")

        enginesController.start()
        // internet is not available
        internetConnectivity.mockInternetAvailable = false

        assertThat(changeCnt, `is`(1))
        assertThat(flightLogReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))

        // mock report added, since no internet, upload should not begin
        utilityRegistry.getUtility(Utilities.flightLogStorage)!.notifyFlightLogReady(flightLogUrl: flightLogC)

        assertThat(changeCnt, `is`(2))
        assertThat(flightLogReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 1))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(engine.pendingFlightLogUrls, contains(flightLogC))

        // mock collect finishes
        engine.completeCollection(result: [flightLogA, flightLogB])

        assertThat(changeCnt, `is`(3))
        assertThat(flightLogReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 3))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(engine.pendingFlightLogUrls, contains(flightLogC, flightLogA, flightLogB))

        // change internet connectivity, upload should start
        internetConnectivity.mockInternetAvailable = true
        let task = httpSession.popLastTask() as! MockUploadTask

        assertThat(changeCnt, `is`(4))
        assertThat(flightLogReporter, presentAnd(allOf(isUploading(), has(pendingCount: 3))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(task.fileUrl, `is`(flightLogC))
        assertThat(engine.pendingFlightLogUrls, contains(flightLogC, flightLogA, flightLogB))

        enginesController.stop()
    }

    func testStopWhenUploading() {
        // create fake reports
        let flightLogA = engine.engineDir.appendingPathComponent("A.bin")
        let flightLogB = engine.engineDir.appendingPathComponent("B.bin")
        // internet is available
        internetConnectivity.mockInternetAvailable = true

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(flightLogReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))

        // mock collect finishes
        engine.completeCollection(result: [flightLogA, flightLogB])
        let task = httpSession.popLastTask() as! MockUploadTask

        // after completion, upload should be triggered and facility updated accordingly
        assertThat(changeCnt, `is`(2))
        assertThat(flightLogReporter, presentAnd(allOf(isUploading(), has(pendingCount: 2))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(task.fileUrl, `is`(flightLogA))
        assertThat(task.request.allHTTPHeaderFields?["x-account"], presentAnd(`is`("mockUserForFlightLog")))
        assertThat(engine.pendingFlightLogUrls, contains(flightLogA, flightLogB))

        enginesController.stop()
        assertThat(engine.pendingFlightLogUrls, contains(flightLogA, flightLogB))
    }

    func testInternetLostAndRegained() {
        // create fake reports
        let flightLogA = engine.engineDir.appendingPathComponent("A.bin")
        let flightLogB = engine.engineDir.appendingPathComponent("B.bin")
        // internet is available
        internetConnectivity.mockInternetAvailable = true

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(flightLogReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))

        // mock collect finishes
        engine.completeCollection(result: [flightLogA, flightLogB])
        var task = httpSession.popLastTask() as! MockUploadTask

        // after completion, upload should be triggered and facility updated accordingly
        assertThat(changeCnt, `is`(2))
        assertThat(flightLogReporter, presentAnd(allOf(isUploading(), has(pendingCount: 2))))
        assertThat(task.fileUrl, `is`(flightLogA))
        assertThat(task.request.allHTTPHeaderFields?["x-account"], presentAnd(`is`("mockUserForFlightLog")))
        assertThat(engine.pendingFlightLogUrls, contains(flightLogA, flightLogB))

        // mock internet lost
        internetConnectivity.mockInternetAvailable = false

        // check that the task has been canceled (for the moment, the api should not change)
        assertThat(task.cancelCalls, `is`(1))
        assertThat(changeCnt, `is`(2))

        // mock cancelation
        task.mock(error: NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled))
        assertThat(changeCnt, `is`(3))

        assertThat(flightLogReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 2))))
        assertThat(httpSession.tasks, empty())
        assertThat(engine.pendingFlightLogUrls, contains(flightLogA, flightLogB))

        // mock internet regained
        internetConnectivity.mockInternetAvailable = true
        task = httpSession.popLastTask() as! MockUploadTask

        assertThat(changeCnt, `is`(4))
        assertThat(flightLogReporter, presentAnd(allOf(isUploading(), has(pendingCount: 2))))
        assertThat(task.fileUrl, `is`(flightLogA))
        assertThat(task.request.allHTTPHeaderFields?["x-account"], presentAnd(`is`("mockUserForFlightLog")))
        assertThat(engine.pendingFlightLogUrls, contains(flightLogA, flightLogB))
    }

    func testUploadSuccess() {
        // create fake reports
        let flightLogA = engine.engineDir.appendingPathComponent("A.bin")
        let flightLogB = engine.engineDir.appendingPathComponent("B.bin")
        // internet is available
        internetConnectivity.mockInternetAvailable = true

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(flightLogReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))

        // mock collect finishes
        engine.completeCollection(result: [flightLogA, flightLogB])

        // after completion, upload should be triggered and facility updated accordingly
        var task = httpSession.popLastTask() as! MockUploadTask
        assertThat(changeCnt, `is`(2))
        assertThat(flightLogReporter, presentAnd(allOf(isUploading(), has(pendingCount: 2))))
        assertThat(task.fileUrl, `is`(flightLogA))
        assertThat(task.request.allHTTPHeaderFields?["x-account"], presentAnd(`is`("mockUserForFlightLog")))
        assertThat(engine.pendingFlightLogUrls, contains(flightLogA, flightLogB))

        // mock upload succeed
        task.mockCompletion(statusCode: 200)

        // after success, flight log should be deleted from the file system and from the list of pending flight log,
        // and a new upload should start
        task = httpSession.popLastTask() as! MockUploadTask
        assertThat(changeCnt, `is`(3))
        assertThat(flightLogReporter, presentAnd(allOf(isUploading(), has(pendingCount: 1))))
        assertThat(task.fileUrl, `is`(flightLogB))
        assertThat(engine.pendingFlightLogUrls, contains(flightLogB))
        assertThat(engine.latestDeletedFlightLogUrl, presentAnd(`is`(flightLogA)))

        // mock last upload succeed
        task.mockCompletion(statusCode: 200)

        assertThat(changeCnt, `is`(4))
        assertThat(flightLogReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(httpSession.tasks, empty())
        assertThat(engine.pendingFlightLogUrls, empty())
        assertThat(engine.latestDeletedFlightLogUrl, presentAnd(`is`(flightLogB)))
    }

    func testUploadFailure() {
        // create fake reports
        let badReport = engine.engineDir.appendingPathComponent("A.bin")
        let badServer = engine.engineDir.appendingPathComponent("B.bin")
        let connectionError = engine.engineDir.appendingPathComponent("C.bin")
        let goodFlightLog = engine.engineDir.appendingPathComponent("D.bin")
        // internet is available
        internetConnectivity.mockInternetAvailable = true

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(flightLogReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))

        // mock collect finishes
        engine.completeCollection(result: [badReport, badServer, connectionError, goodFlightLog])

        // after completion, upload should be triggered and facility updated accordingly
        var task = httpSession.popLastTask() as! MockUploadTask
        assertThat(changeCnt, `is`(2))
        assertThat(flightLogReporter, presentAnd(allOf(isUploading(), has(pendingCount: 4))))
        assertThat(task.fileUrl, `is`(badReport))
        assertThat(engine.pendingFlightLogUrls, contains(badReport, badServer, connectionError, goodFlightLog))

        // mock upload failed with error badReport
        task.mock(error: NSError(domain: NSPOSIXErrorDomain, code: Int(EISDIR)))

        // receiving a bad report error should delete the report and upload the next one
        task = httpSession.popLastTask() as! MockUploadTask
        assertThat(changeCnt, `is`(3))
        assertThat(flightLogReporter, presentAnd(allOf(isUploading(), has(pendingCount: 3))))
        assertThat(task.fileUrl, `is`(badServer))
        assertThat(engine.pendingFlightLogUrls, contains(badServer, connectionError, goodFlightLog))
        assertThat(engine.latestDeletedFlightLogUrl, presentAnd(`is`(badReport)))

        // mock upload failed with error serverError
        task.mockCompletion(statusCode: 415)

        // receiving a bad server error should delete the report and upload the next one
        task = httpSession.popLastTask() as! MockUploadTask
        assertThat(changeCnt, `is`(4))
        assertThat(flightLogReporter, presentAnd(allOf(isUploading(), has(pendingCount: 2))))
        assertThat(task.fileUrl, `is`(connectionError))
        assertThat(engine.pendingFlightLogUrls, contains(connectionError, goodFlightLog))
        assertThat(engine.latestDeletedFlightLogUrl, presentAnd(`is`(badServer)))

        // mock upload failed with error connectionError
        task.mock(error: NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut))

        // receiving a connection error should stop the upload but not delete the flight log nor remove
        ///it from the upload queue
        assertThat(changeCnt, `is`(5))
        assertThat(flightLogReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 2))))
        assertThat(httpSession.tasks, empty())
        assertThat(engine.pendingFlightLogUrls, contains(connectionError, goodFlightLog))
        // should not have changed
        assertThat(engine.latestDeletedFlightLogUrl, presentAnd(`is`(badServer)))
    }

    func testFlightLogQuota() {
        GroundSdkConfig.sharedInstance.flightLogQuotaMb = 2
        let flightLogA = engine.engineDir.appendingPathComponent("A.bin")
        let flightLogB = engine.engineDir.appendingPathComponent("B.bin")
        let flightLogC = engine.engineDir.appendingPathComponent("C.bin")
        var someDateTime = Date(timeIntervalSinceReferenceDate: 15)
        let dataA = String.randomString(length: 4 * 1024 * 1024)
        FileManager.default.createFile(atPath: flightLogA.path,
                                        contents: dataA.data(using: .utf8),
                                        attributes: [FileAttributeKey.creationDate: someDateTime])
        let dataB = String.randomString(length: 2 * 1024 * 1024)
        someDateTime = Date(timeIntervalSinceReferenceDate: 30)
        FileManager.default.createFile(atPath: flightLogB.path,
                                       contents: dataB.data(using: .utf8),
                                       attributes: [FileAttributeKey.creationDate: someDateTime])
        let dataC = String.randomString(length: 1 * 1024 * 1024)
        someDateTime = Date(timeIntervalSinceReferenceDate: 60)
        FileManager.default.createFile(atPath: flightLogC.path,
                                       contents: dataC.data(using: .utf8),
                                       attributes: [FileAttributeKey.creationDate: someDateTime])

        enginesController.start()
        assertThat(FileManager.default.fileExists(atPath: flightLogA.path), `is`(false))
        assertThat(FileManager.default.fileExists(atPath: flightLogB.path), `is`(false))
        assertThat(FileManager.default.fileExists(atPath: flightLogC.path), `is`(true))
    }

    func testDropReportWithAccountToNone() {
        let flightLogA = engine.engineDir.appendingPathComponent("A.bin")
        let flightLogB = engine.engineDir.appendingPathComponent("B.bin")
        let flightLogC = engine.engineDir.appendingPathComponent("C.bin")

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(flightLogReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))

        // mock collect finishes
        engine.completeCollection(result: [flightLogA, flightLogB, flightLogC])

        userAccountUtility.update(userAccountInfo: UserAccountInfoCore(account: nil,
                                            anonymousDataPolicy: AnonymousDataPolicy.deny,
                                            accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload))

        assertThat(engine.latestDeletedFlightLogUrl, presentAnd(`is`(flightLogC)))
    }

    func testDropReportWithDifferentAccount() {
        let flightLogA = engine.engineDir.appendingPathComponent("A.bin")
        let flightLogB = engine.engineDir.appendingPathComponent("B.bin")
        let flightLogC = engine.engineDir.appendingPathComponent("C.bin")

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(flightLogReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))

        // mock collect finishes
        engine.completeCollection(result: [flightLogA, flightLogB, flightLogC])

        userAccountUtility.update(userAccountInfo: UserAccountInfoCore(account: "mockUser2",
                                            anonymousDataPolicy: AnonymousDataPolicy.deny,
                                            accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload))

        assertThat(engine.latestDeletedFlightLogUrl, presentAnd(`is`(flightLogC)))
    }

    func testDoNotDropReportFromNoAccountToAcount() {
        userAccountUtility.update(userAccountInfo: UserAccountInfoCore(account: nil,
                                            anonymousDataPolicy: AnonymousDataPolicy.deny,
                                            accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload))

        let flightLogA = engine.engineDir.appendingPathComponent("A.bin")
        let flightLogB = engine.engineDir.appendingPathComponent("B.bin")
        let flightLogC = engine.engineDir.appendingPathComponent("C.bin")

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(flightLogReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))

        // mock collect finishes
        engine.completeCollection(result: [flightLogA, flightLogB, flightLogC])
        userAccountUtility.update(userAccountInfo: UserAccountInfoCore(account: "mockUser",
                                            anonymousDataPolicy: AnonymousDataPolicy.deny,
                                            accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload))
        assertThat(engine.latestDeletedFlightLogUrl, nilValue())
    }
}
