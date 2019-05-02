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

class BlackBoxEngineTests: XCTestCase {

    var blackBoxReporterRef: Ref<BlackBoxReporter>!
    var blackBoxReporter: BlackBoxReporter?
    var changeCnt = 0

    let internetConnectivity = MockInternetConnectivity()
    let userAccountUtility = UserAccountUtilityCoreImpl()

    let httpSession = MockHttpSession()

    // need to be retained (normally retained by the EnginesController)
    private let utilityRegistry = UtilityCoreRegistry()
    private let facilityStore = ComponentStoreCore()
    private var enginesController: MockEnginesController!

    private var engine: MockBlackBoxEngine!

    override func setUp() {
        super.setUp()
        GroundSdkConfig.sharedInstance.blackBoxQuotaMb = 2
        enginesController = MockEnginesController(
            utilityRegistry: utilityRegistry,
            facilityStore: facilityStore,
            initEngineClosure: {
                self.engine = MockBlackBoxEngine(enginesController: $0)
                return [self.engine]
        })

        utilityRegistry.publish(utility: internetConnectivity)
        utilityRegistry.publish(utility: userAccountUtility)
        utilityRegistry.publish(utility: CloudServerCore(utilityRegistry: utilityRegistry, httpSession: httpSession ))

        // add a user, otherwise the blackBox process is inactive
        userAccountUtility.update(userAccountInfo: UserAccountInfoCore(account: "mockUserForBlackBox",
                                            accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.allowUpload))

        blackBoxReporterRef = ComponentRefCore(
            store: facilityStore,
            desc: Facilities.blackBoxReporter) { [unowned self] blackBoxReporter in
                self.blackBoxReporter = blackBoxReporter
                self.changeCnt += 1
        }
    }

    override func tearDown() {
        GroundSdkConfig.sharedInstance.blackBoxQuotaMb = nil
    }

    func testPublishUnpublish() {
        // should be unavailable when the engine is not started
        assertThat(blackBoxReporter, nilValue())

        enginesController.start()
        assertThat(blackBoxReporter, present())
        assertThat(changeCnt, `is`(1))

        enginesController.stop()
        assertThat(blackBoxReporter, nilValue())
        assertThat(changeCnt, `is`(2))
    }

    func testDirectories() {
        // test the location of engineDir (should be in the cache folder, named BlackBoxes)
        let engineDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("BlackBoxes", isDirectory: true)
        assertThat(engine.engineDir, `is`(engineDir))
        assertThat(engine.workDir.deletingLastPathComponent(), `is`(engine.engineDir))
    }

    /// Test that the upload is triggered when there is internet and the collect finishes
    func testUploadTriggeredWhenCollectFinishesBeforeReportAddedAndInternet() {
        // create fake reports
        let blackBox1 = BlackBox(url: engine.engineDir.appendingPathComponent("A.gz"))
        let blackBox2 = BlackBox(url: engine.engineDir.appendingPathComponent("B.gz"))
        let blackBox3 = BlackBox(url: engine.workDir.appendingPathComponent("C.gz"))
        // internet is available
        internetConnectivity.mockInternetAvailable = true

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(blackBoxReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(engine.archiveCnt, `is`(0))

        // mock collect finishes
        engine.completeCollection(result: [blackBox1, blackBox2])

        let task = httpSession.popLastTask() as! MockUploadTask

        // after completion, upload should be triggered and facility updated accordingly
        assertThat(changeCnt, `is`(2))
        assertThat(blackBoxReporter, presentAnd(allOf(isUploading(), has(pendingCount: 2))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(engine.archiveCnt, `is`(0))
        assertThat(task.fileUrl, `is`(blackBox1.url))
        assertThat(task.request.allHTTPHeaderFields?["x-account"], presentAnd(`is`("mockUserForBlackBox")))
        assertThat(engine.pendingReports, contains(blackBox1, blackBox2))

        // check that when a blackbox is added, it is added at the end of the list
        let blackBoxData = 1    // Int is Encodable
        utilityRegistry.getUtility(Utilities.blackBoxStorage)!.notifyBlackBoxDataReady(blackBoxData: blackBoxData)
        assertThat(changeCnt, `is`(2))
        assertThat(blackBoxReporter, presentAnd(allOf(isUploading(), has(pendingCount: 2))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(engine.archiveCnt, `is`(1))
        assertThat(task.fileUrl, `is`(blackBox1.url))
        assertThat(task.request.allHTTPHeaderFields?["x-account"], presentAnd(`is`("mockUserForBlackBox")))
        assertThat(engine.pendingReports, contains(blackBox1, blackBox2))

        // mock archive finished
        engine.completeArchive(result: blackBox3)

        // check that when reports are added, they are added at the end of the list
        // should not trigger a change count since blackBoxReporter is Uploading already
        // files have been added to pending list url.
        assertThat(changeCnt, `is`(2))
        assertThat(blackBoxReporter, presentAnd(allOf(isUploading(), has(pendingCount: 3))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(engine.archiveCnt, `is`(1))
        assertThat(task.fileUrl, `is`(blackBox1.url))
        assertThat(task.request.allHTTPHeaderFields?["x-account"], presentAnd(`is`("mockUserForBlackBox")))
        assertThat(engine.pendingReports, contains(blackBox1, blackBox2, blackBox3))

        enginesController.stop()
    }

    /// Test that the upload is triggered when there is internet and the collect finishes
    func testUploadTriggeredWhenReportAddedBeforeCollectFinishesAndInternet() {
        // create fake reports
        let blackBox1 = BlackBox(url: engine.engineDir.appendingPathComponent("A.gz"))
        let blackBox2 = BlackBox(url: engine.engineDir.appendingPathComponent("B.gz"))
        let blackBox3 = BlackBox(url: engine.workDir.appendingPathComponent("C.gz"))
        // internet is available
        internetConnectivity.mockInternetAvailable = true

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(blackBoxReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(engine.archiveCnt, `is`(0))

        // mock black box data added
        let blackBoxData = 1    // Int is Encodable
        utilityRegistry.getUtility(Utilities.blackBoxStorage)!.notifyBlackBoxDataReady(blackBoxData: blackBoxData)

        assertThat(changeCnt, `is`(1))
        assertThat(blackBoxReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(engine.archiveCnt, `is`(1))
        assertThat(engine.pendingReports, empty())

        // mock archive finished, upload should start
        engine.completeArchive(result: blackBox3)
        let task = httpSession.popLastTask() as! MockUploadTask

        assertThat(changeCnt, `is`(2))
        assertThat(blackBoxReporter, presentAnd(allOf(isUploading(), has(pendingCount: 1))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(engine.archiveCnt, `is`(1))
        assertThat(task.fileUrl, `is`(blackBox3.url))
        assertThat(task.request.allHTTPHeaderFields?["x-account"], presentAnd(`is`("mockUserForBlackBox")))
        assertThat(engine.pendingReports, contains(blackBox3))

        // mock collect finishes
        engine.completeCollection(result: [blackBox1, blackBox2])

        // check that when reports are added, they are added at the end of the list
        // should not trigger a change count since blackBoxReporter is Uploading already
        // files have been added to pending list url.
        assertThat(changeCnt, `is`(2))
        assertThat(blackBoxReporter, presentAnd(allOf(isUploading(), has(pendingCount: 3))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(engine.archiveCnt, `is`(1))
        assertThat(engine.pendingReports, contains(blackBox3, blackBox1, blackBox2))
        enginesController.stop()
    }

    // check that download does not try to start if there is no internet connectivity
    func testStartWithoutInternet() {
        // create fake reports
        let blackBox1 = BlackBox(url: engine.engineDir.appendingPathComponent("A.gz"))
        let blackBox2 = BlackBox(url: engine.engineDir.appendingPathComponent("B.gz"))
        let blackBox3 = BlackBox(url: engine.workDir.appendingPathComponent("C.gz"))

        // internet is not available
        internetConnectivity.mockInternetAvailable = false

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(blackBoxReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(engine.archiveCnt, `is`(0))
        assertThat(engine.pendingReports, empty())

        // mock black box data added, since no internet, upload should not begin
        let blackBoxData = 1    // Int is Encodable
        utilityRegistry.getUtility(Utilities.blackBoxStorage)!.notifyBlackBoxDataReady(blackBoxData: blackBoxData)

        assertThat(httpSession.popLastTask(), nilValue())
        assertThat(changeCnt, `is`(1))
        assertThat(blackBoxReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(engine.archiveCnt, `is`(1))
        assertThat(engine.pendingReports, empty())

        // mock archive complete, since there is no internet, upload should not start
        engine.completeArchive(result: blackBox3)

        assertThat(changeCnt, `is`(2))
        assertThat(blackBoxReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 1))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(engine.archiveCnt, `is`(1))
        assertThat(engine.pendingReports, contains(blackBox3))

        // mock collect finishes
        engine.completeCollection(result: [blackBox1, blackBox2])

        assertThat(changeCnt, `is`(3))
        assertThat(blackBoxReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 3))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(engine.archiveCnt, `is`(1))
        assertThat(engine.pendingReports, contains(blackBox3, blackBox1, blackBox2))

        // change internet connectivity, upload should start
        internetConnectivity.mockInternetAvailable = true
        let task = httpSession.popLastTask() as! MockUploadTask

        assertThat(changeCnt, `is`(4))
        assertThat(blackBoxReporter, presentAnd(allOf(isUploading(), has(pendingCount: 3))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(engine.archiveCnt, `is`(1))
        assertThat(task.fileUrl, `is`(blackBox3.url))
        assertThat(task.request.allHTTPHeaderFields?["x-account"], presentAnd(`is`("mockUserForBlackBox")))
        assertThat(engine.pendingReports, contains(blackBox3, blackBox1, blackBox2))

        enginesController.stop()
    }

    func testStopWhenUploading() {
        // create fake reports
        let blackBox1 = BlackBox(url: engine.engineDir.appendingPathComponent("A.gz"))
        let blackBox2 = BlackBox(url: engine.engineDir.appendingPathComponent("B.gz"))
        // internet is available
        internetConnectivity.mockInternetAvailable = true

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(blackBoxReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))

        // mock collect finishes
        engine.completeCollection(result: [blackBox1, blackBox2])
        let task = httpSession.popLastTask() as! MockUploadTask

        // after completion, upload should be triggered and facility updated accordingly
        assertThat(changeCnt, `is`(2))
        assertThat(blackBoxReporter, presentAnd(allOf(isUploading(), has(pendingCount: 2))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(task.fileUrl, `is`(blackBox1.url))
        assertThat(task.request.allHTTPHeaderFields?["x-account"], presentAnd(`is`("mockUserForBlackBox")))
        assertThat(engine.pendingReports, contains(blackBox1, blackBox2))

        enginesController.stop()
        assertThat(engine.pendingReports, contains(blackBox1, blackBox2))
    }

    func testInternetLostAndRegained() {
        // create fake reports
        let blackBox1 = BlackBox(url: engine.engineDir.appendingPathComponent("A.gz"))
        let blackBox2 = BlackBox(url: engine.engineDir.appendingPathComponent("B.gz"))
        // internet is available
        internetConnectivity.mockInternetAvailable = true

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(blackBoxReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))

        // mock collect finishes
        engine.completeCollection(result: [blackBox1, blackBox2])
        var task = httpSession.popLastTask() as! MockUploadTask

        // after completion, upload should be triggered and facility updated accordingly
        assertThat(changeCnt, `is`(2))
        assertThat(blackBoxReporter, presentAnd(allOf(isUploading(), has(pendingCount: 2))))
        assertThat(task.fileUrl, `is`(blackBox1.url))
        assertThat(task.request.allHTTPHeaderFields?["x-account"], presentAnd(`is`("mockUserForBlackBox")))
        assertThat(engine.pendingReports, contains(blackBox1, blackBox2))

        // mock internet lost
        internetConnectivity.mockInternetAvailable = false

        // check that the task has been canceled (for the moment, the api should not change)
        assertThat(task.cancelCalls, `is`(1))
        assertThat(changeCnt, `is`(2))

        // mock cancelation
        task.mock(error: NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled))
        assertThat(changeCnt, `is`(3))
        assertThat(blackBoxReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 2))))
        assertThat(httpSession.tasks, empty())
        assertThat(engine.pendingReports, contains(blackBox1, blackBox2))

        // mock internet regained
        internetConnectivity.mockInternetAvailable = true
        task = httpSession.popLastTask() as! MockUploadTask

        assertThat(changeCnt, `is`(4))
        assertThat(blackBoxReporter, presentAnd(allOf(isUploading(), has(pendingCount: 2))))
        assertThat(task.fileUrl, `is`(blackBox1.url))
        assertThat(task.request.allHTTPHeaderFields?["x-account"], presentAnd(`is`("mockUserForBlackBox")))
        assertThat(engine.pendingReports, contains(blackBox1, blackBox2))
    }

    func testUploadSuccess() {
        // create fake reports
        let blackBox1 = BlackBox(url: engine.engineDir.appendingPathComponent("A.gz"))
        let blackBox2 = BlackBox(url: engine.engineDir.appendingPathComponent("B.gz"))
        // internet is available
        internetConnectivity.mockInternetAvailable = true

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(blackBoxReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))

        // mock collect finishes
        engine.completeCollection(result: [blackBox1, blackBox2])

        // after completion, upload should be triggered and facility updated accordingly
        var task = httpSession.popLastTask() as! MockUploadTask
        assertThat(changeCnt, `is`(2))
        assertThat(blackBoxReporter, presentAnd(allOf(isUploading(), has(pendingCount: 2))))
        assertThat(task.fileUrl, `is`(blackBox1.url))
        assertThat(task.request.allHTTPHeaderFields?["x-account"], presentAnd(`is`("mockUserForBlackBox")))
        assertThat(engine.pendingReports, contains(blackBox1, blackBox2))

        // mock upload succeed
        task.mockCompletion(statusCode: 200)

        // after success, blackbox should be deleted from the file system and from the list of pending blackboxes,
        // and a new upload should start
        task = httpSession.popLastTask() as! MockUploadTask
        assertThat(changeCnt, `is`(3))
        assertThat(blackBoxReporter, presentAnd(allOf(isUploading(), has(pendingCount: 1))))
        assertThat(task.fileUrl, `is`(blackBox2.url))
        assertThat(task.request.allHTTPHeaderFields?["x-account"], presentAnd(`is`("mockUserForBlackBox")))
        assertThat(engine.pendingReports, contains(blackBox2))
        assertThat(engine.latestDeletedBlackBoxUrl, presentAnd(`is`(blackBox1.url)))

        // mock last upload succeed
        task.mockCompletion(statusCode: 200)

        assertThat(changeCnt, `is`(4))
        assertThat(blackBoxReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(httpSession.tasks, empty())
        assertThat(engine.pendingReports, empty())
        assertThat(engine.latestDeletedBlackBoxUrl, presentAnd(`is`(blackBox2.url)))
    }

    func testNoUser() {
        // create fake reports
        let blackBox1 = BlackBox(url: engine.engineDir.appendingPathComponent("A.gz"))
        let blackBox2 = BlackBox(url: engine.engineDir.appendingPathComponent("B.gz"))
        // internet is available

        enginesController.start()

        // No user
        userAccountUtility.update(userAccountInfo: UserAccountInfoCore(account: nil))

        internetConnectivity.mockInternetAvailable = true

        assertThat(changeCnt, `is`(1))
        assertThat(blackBoxReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))

        // mock collect finishes
        engine.completeCollection(result: [blackBox1, blackBox2])
        let task = httpSession.popLastTask() as? MockUploadTask
        assertThat(task, nilValue())
        assertThat(changeCnt, `is`(2))

        assertThat(blackBoxReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 2))))
        assertThat(httpSession.tasks, empty())
        assertThat(engine.pendingReports, hasCount(2))
        // there should be no deleted black box
        assertThat(engine.latestDeletedBlackBoxUrl, nilValue())
    }

    func testDenyUploadWithUser() {
        // create fake reports
        let blackBox1 = BlackBox(url: engine.engineDir.appendingPathComponent("A.gz"))
        let blackBox2 = BlackBox(url: engine.engineDir.appendingPathComponent("B.gz"))
        // internet is available

        enginesController.start()

        userAccountUtility.update(userAccountInfo: UserAccountInfoCore(account: "mockUserForBlackBox"))
        internetConnectivity.mockInternetAvailable = true

        assertThat(changeCnt, `is`(1))
        assertThat(blackBoxReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))

        // mock collect finishes
        engine.completeCollection(result: [blackBox1, blackBox2])
        let task = httpSession.popLastTask() as? MockUploadTask
        assertThat(task, nilValue())
        assertThat(changeCnt, `is`(2))

        assertThat(blackBoxReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(httpSession.tasks, empty())
        assertThat(engine.pendingReports, hasCount(0))
        // there should be no deleted black box
        assertThat(engine.latestDeletedBlackBoxUrl, `is`(blackBox2.url))
    }

    func testUploadFailure() {
        // create fake reports
        let badReport = BlackBox(url: engine.engineDir.appendingPathComponent("A.gz"))
        let badServer = BlackBox(url: engine.engineDir.appendingPathComponent("B.gz"))
        let connectionError = BlackBox(url: engine.engineDir.appendingPathComponent("C.gz"))
        let goodReport = BlackBox(url: engine.engineDir.appendingPathComponent("D.gz"))
        // internet is available
        internetConnectivity.mockInternetAvailable = true

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(blackBoxReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))

        // mock collect finishes
        engine.completeCollection(result: [badReport, badServer, connectionError, goodReport])

        // after completion, upload should be triggered and facility updated accordingly
        var task = httpSession.popLastTask() as! MockUploadTask
        assertThat(changeCnt, `is`(2))
        assertThat(blackBoxReporter, presentAnd(allOf(isUploading(), has(pendingCount: 4))))
        assertThat(task.fileUrl, `is`(badReport.url))
        assertThat(task.request.allHTTPHeaderFields?["x-account"], presentAnd(`is`("mockUserForBlackBox")))
        assertThat(engine.pendingReports, contains(badReport, badServer, connectionError, goodReport))

        // mock upload failed with error badReport
        task.mock(error: NSError(domain: NSPOSIXErrorDomain, code: Int(EISDIR)))

        // receiving a bad report error should delete the report and upload the next one
        task = httpSession.popLastTask() as! MockUploadTask
        assertThat(changeCnt, `is`(3))
        assertThat(blackBoxReporter, presentAnd(allOf(isUploading(), has(pendingCount: 3))))
        assertThat(task.fileUrl, `is`(badServer.url))
        assertThat(engine.pendingReports, contains(badServer, connectionError, goodReport))
        assertThat(engine.latestDeletedBlackBoxUrl, presentAnd(`is`(badReport.url)))

        // mock upload failed with error serverError
        task.mockCompletion(statusCode: 415)

        // receiving a bad server error should delete the report and upload the next one
        task = httpSession.popLastTask() as! MockUploadTask
        assertThat(changeCnt, `is`(4))
        assertThat(blackBoxReporter, presentAnd(allOf(isUploading(), has(pendingCount: 2))))
        assertThat(task.fileUrl, `is`(connectionError.url))
        assertThat(engine.pendingReports, contains(connectionError, goodReport))
        assertThat(engine.latestDeletedBlackBoxUrl, presentAnd(`is`(badServer.url)))

        // mock upload failed with error connectionError
        task.mock(error: NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut))

        // receiving a connection error should stop the upload but not delete the report nor remove it from the upload
        // queue
        assertThat(changeCnt, `is`(5))
        assertThat(blackBoxReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 2))))
        assertThat(httpSession.tasks, empty())
        assertThat(engine.pendingReports, contains(connectionError, goodReport))
        // should not have changed
        assertThat(engine.latestDeletedBlackBoxUrl, presentAnd(`is`(badServer.url)))
    }

    func testBlackBoxQuota() {
        let blackBoxA = engine.engineDir.appendingPathComponent("A.gz")
        let blackBoxB = engine.engineDir.appendingPathComponent("B.gz")
        let blackBoxC = engine.engineDir.appendingPathComponent("C.gz")
        let dataA = String.randomString(length: 4 * 1024 * 1024)
        var someDateTime = Date(timeIntervalSinceReferenceDate: 15)
        FileManager.default.createFile(atPath: blackBoxA.path,
                                       contents: dataA.data(using: .utf8),
                                       attributes: [FileAttributeKey.creationDate: someDateTime])
        let dataB = String.randomString(length: 2 * 1024 * 1024)
        someDateTime = Date(timeIntervalSinceReferenceDate: 30)
        FileManager.default.createFile(atPath: blackBoxB.path,
                                       contents: dataB.data(using: .utf8),
                                       attributes: [FileAttributeKey.creationDate: someDateTime])
        let dataC = String.randomString(length: 1 * 1024 * 1024)
        someDateTime = Date(timeIntervalSinceReferenceDate: 60)
        FileManager.default.createFile(atPath: blackBoxC.path,
                                       contents: dataC.data(using: .utf8),
                                       attributes: [FileAttributeKey.creationDate: someDateTime])

        enginesController.start()
        assertThat(FileManager.default.fileExists(atPath: blackBoxA.path), `is`(false))
        assertThat(FileManager.default.fileExists(atPath: blackBoxB.path), `is`(false))
        assertThat(FileManager.default.fileExists(atPath: blackBoxC.path), `is`(true))
    }

    func testDropReport() {
        let blackBoxA = BlackBox(url: engine.engineDir.appendingPathComponent("A.gz"))
        let blackBoxB = BlackBox(url: engine.engineDir.appendingPathComponent("B.gz"))
        let blackBoxC = BlackBox(url: engine.workDir.appendingPathComponent("C.gz"))

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(blackBoxReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))

        // mock collect finishes
        engine.completeCollection(result: [blackBoxA, blackBoxB, blackBoxC])

        userAccountUtility.update(userAccountInfo: UserAccountInfoCore(account: nil,
                                            anonymousDataPolicy: AnonymousDataPolicy.deny,
                                            accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload))

        assertThat(engine.latestDeletedBlackBoxUrl, presentAnd(`is`(blackBoxC.url)))
    }

    func testDropReportWithDifferentAccount() {
        let blackBoxA = BlackBox(url: engine.engineDir.appendingPathComponent("A.gz"))
        let blackBoxB = BlackBox(url: engine.engineDir.appendingPathComponent("B.gz"))
        let blackBoxC = BlackBox(url: engine.workDir.appendingPathComponent("C.gz"))

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(blackBoxReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))

        // mock collect finishes
        engine.completeCollection(result: [blackBoxA, blackBoxB, blackBoxC])

        userAccountUtility.update(userAccountInfo: UserAccountInfoCore(account: "mockUser2",
                                            anonymousDataPolicy: AnonymousDataPolicy.deny,
                                            accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload))

        assertThat(engine.latestDeletedBlackBoxUrl, presentAnd(`is`(blackBoxC.url)))
    }

    func testDoNotDropReportFromNoAccountToAcount() {
        userAccountUtility.update(userAccountInfo: UserAccountInfoCore(account: nil,
                                            anonymousDataPolicy: AnonymousDataPolicy.deny,
                                            accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload))

        let blackBoxA = BlackBox(url: engine.engineDir.appendingPathComponent("A.gz"))
        let blackBoxB = BlackBox(url: engine.engineDir.appendingPathComponent("B.gz"))
        let blackBoxC = BlackBox(url: engine.workDir.appendingPathComponent("C.gz"))

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(blackBoxReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))

        // mock collect finishes
        engine.completeCollection(result: [blackBoxA, blackBoxB, blackBoxC])
        userAccountUtility.update(userAccountInfo: UserAccountInfoCore(account: "mockUser",
                                            anonymousDataPolicy: AnonymousDataPolicy.deny,
                                            accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload))
        assertThat(engine.latestDeletedBlackBoxUrl, nilValue())
    }
}
