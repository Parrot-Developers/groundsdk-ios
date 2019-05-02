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

class CrashReportEngineTests: XCTestCase {

    var crashReporterRef: Ref<CrashReporter>!
    var crashReporter: CrashReporter?
    var changeCnt = 0

    let internetConnectivity = MockInternetConnectivity()
    let userAccountUtility = UserAccountUtilityCoreImpl()

    let httpSession = MockHttpSession()

    // need to be retained (normally retained by the EnginesController)
    private let utilityRegistry = UtilityCoreRegistry()
    private let facilityStore = ComponentStoreCore()
    private var enginesController: MockEnginesController!

    private var engine: MockCrashReportEngine!

    override func setUp() {
        super.setUp()
        GroundSdkConfig.sharedInstance.crashReportQuotaMb = 2
        enginesController = MockEnginesController(
            utilityRegistry: utilityRegistry,
            facilityStore: facilityStore,
            initEngineClosure: {
                self.engine = MockCrashReportEngine(enginesController: $0)
                return [self.engine]
        })

        utilityRegistry.publish(utility: internetConnectivity)
        utilityRegistry.publish(utility: userAccountUtility)
        utilityRegistry.publish(utility: CloudServerCore(utilityRegistry: utilityRegistry, httpSession: httpSession))

        // add a user, otherwise the crashReport process is inactive
        // (the default is "no user" and "anonymous data not allowed")
        userAccountUtility.update(userAccountInfo: UserAccountInfoCore(account: "mockUserForReport",
                                            accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.allowUpload))

        crashReporterRef = ComponentRefCore(
            store: facilityStore,
            desc: Facilities.crashReporter) { [unowned self] crashReporter in
                self.crashReporter = crashReporter
                self.changeCnt += 1
        }
    }

    override func tearDown() {
        GroundSdkConfig.sharedInstance.crashReportQuotaMb = nil
    }

    func testPublishUnpublish() {
        // should be unavailable when the engine is not started
        assertThat(crashReporter, nilValue())

        enginesController.start()
        assertThat(crashReporter, present())
        assertThat(changeCnt, `is`(1))

        enginesController.stop()
        assertThat(crashReporter, nilValue())
        assertThat(changeCnt, `is`(2))
    }

    func testDirectories() {
        // test the location of engineDir (should be in the cache folder, named CrashReports)
        let engineDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CrashReports", isDirectory: true)
        assertThat(engine.engineDir, `is`(engineDir))
        assertThat(engine.workDir.deletingLastPathComponent(), `is`(engine.engineDir))
    }

    /// No crash report if the user is nil and if anonymous data are not allowed
    func testAnonymousDataNotAllowed() {
        // create fake reports
        let crashA = engine.engineDir.appendingPathComponent("A.tar.gz")
        let crashB = engine.engineDir.appendingPathComponent("B.tar.gz")
        let crashC = engine.workDir.appendingPathComponent("C.tar.gz")
        let crashD = engine.workDir.appendingPathComponent("D.tar.gz.anon")
        // internet is available
        internetConnectivity.mockInternetAvailable = true

        enginesController.start()

        userAccountUtility.update(userAccountInfo: UserAccountInfoCore(account: nil,
                                            anonymousDataPolicy: AnonymousDataPolicy.deny,
                                            accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload))

        assertThat(changeCnt, `is`(1))
        assertThat(crashReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))

        // mock collect finishes
        engine.completeCollection(result: [crashA, crashB])

        var task = httpSession.popLastTask() as? MockUploadTask
        assertThat(task, nilValue())
        assertThat(crashReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 2))))
        assertThat(engine.collectCnt, `is`(1))

        assertThat(engine.latestDeletedCrashUrl, nilValue())
        // Anonymous Allowed
        userAccountUtility.update(userAccountInfo: UserAccountInfoCore(account: nil,
                                        anonymousDataPolicy: AnonymousDataPolicy.allow,
                                        accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload))
        // delete old reporrts since
        utilityRegistry.getUtility(Utilities.crashReportStorage)!
            .notifyReportReady(reportUrlCollection: [crashC])
        assertThat(changeCnt, `is`(3))
        task = httpSession.popLastTask() as? MockUploadTask
        assertThat(task, nilValue())

        utilityRegistry.getUtility(Utilities.crashReportStorage)!
            .notifyReportReady(reportUrlCollection: [crashD])
        assertThat(changeCnt, `is`(4))
        task = httpSession.popLastTask() as? MockUploadTask
        assertThat(task?.fileUrl, `is`(crashD))
        // after completion, upload should be triggered and facility updated accordingly
        assertThat(crashReporter, presentAnd(allOf(isUploading(), has(pendingCount: 1))))

        enginesController.stop()
    }

    /// Test that the upload is triggered when there is internet and the collect finishes
    func testUploadTriggeredWhenCollectFinishesBeforeReportAddedAndInternet() {
        // create fake reports
        let crashA = engine.engineDir.appendingPathComponent("A.tar.gz")
        let crashB = engine.engineDir.appendingPathComponent("B.tar.gz")
        let crashC = engine.workDir.appendingPathComponent("C.tar.gz")
        // internet is available
        internetConnectivity.mockInternetAvailable = true

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(crashReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))

        // mock collect finishes
        engine.completeCollection(result: [crashA, crashB])

        let task = httpSession.popLastTask() as! MockUploadTask

        // after completion, upload should be triggered and facility updated accordingly
        assertThat(changeCnt, `is`(2))
        assertThat(crashReporter, presentAnd(allOf(isUploading(), has(pendingCount: 2))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(task.fileUrl, `is`(crashA))
        assertThat(task.request.allHTTPHeaderFields?["x-account"], presentAnd(`is`("mockUserForReport")))
        assertThat(engine.pendingReportUrls, contains(crashA, crashB))

        // check that when a report is added, it is added at the end of the list
        // should not trigger a change count since crashReporter is Uploading already
        // file has been added to pending list url.
        utilityRegistry.getUtility(Utilities.crashReportStorage)!.notifyReportReady(reportUrlCollection: [crashC])
        assertThat(changeCnt, `is`(2))
        assertThat(crashReporter, presentAnd(allOf(isUploading(), has(pendingCount: 3))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(engine.pendingReportUrls, contains(crashA, crashB, crashC))

        enginesController.stop()
    }

    /// Test that the upload is triggered when there is internet and the collect finishes
    func testUploadTriggeredWhenReportAddedBeforeCollectFinishesAndInternet() {
        // create fake reports
        let crashA = engine.engineDir.appendingPathComponent("A.tar.gz")
        let crashB = engine.engineDir.appendingPathComponent("B.tar.gz")
        let crashC = engine.workDir.appendingPathComponent("C.tar.gz")
        // internet is available
        internetConnectivity.mockInternetAvailable = true

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(crashReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))

        // mock report added, after that, upload should be triggered and facility updated accordingly
        utilityRegistry.getUtility(Utilities.crashReportStorage)!.notifyReportReady(reportUrlCollection: [crashC])
        let task = httpSession.popLastTask() as! MockUploadTask

        assertThat(changeCnt, `is`(2))
        assertThat(crashReporter, presentAnd(allOf(isUploading(), has(pendingCount: 1))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(task.fileUrl, `is`(crashC))
        assertThat(engine.pendingReportUrls, contains(crashC))

        // mock collect finishes
        engine.completeCollection(result: [crashA, crashB])

        // check that when reports are added, they are added at the end of the list
        // should not trigger a change count since crashReporter is Uploading already
        // files have been added to pending list url.
        assertThat(changeCnt, `is`(2))
        assertThat(crashReporter, presentAnd(allOf(isUploading(), has(pendingCount: 3))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(engine.pendingReportUrls, contains(crashC, crashA, crashB))

        enginesController.stop()
    }

    // check that download does not try to start if there is no internet connectivity
    func testStartWithoutInternet() {
         // create fake reports
        let crashA = engine.engineDir.appendingPathComponent("A.tar.gz")
        let crashB = engine.engineDir.appendingPathComponent("B.tar.gz")
        let crashC = engine.workDir.appendingPathComponent("C.tar.gz")

        // internet is not available
        internetConnectivity.mockInternetAvailable = false

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(crashReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))

        // mock report added, since no internet, upload should not begin
        utilityRegistry.getUtility(Utilities.crashReportStorage)!.notifyReportReady(reportUrlCollection: [crashC])

        assertThat(changeCnt, `is`(2))
        assertThat(crashReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 1))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(engine.pendingReportUrls, contains(crashC))

        // mock collect finishes
        engine.completeCollection(result: [crashA, crashB])

        assertThat(changeCnt, `is`(3))
        assertThat(crashReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 3))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(engine.pendingReportUrls, contains(crashC, crashA, crashB))

        // change internet connectivity, upload should start
        internetConnectivity.mockInternetAvailable = true
        let task = httpSession.popLastTask() as! MockUploadTask

        assertThat(changeCnt, `is`(4))
        assertThat(crashReporter, presentAnd(allOf(isUploading(), has(pendingCount: 3))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(task.fileUrl, `is`(crashC))
        assertThat(engine.pendingReportUrls, contains(crashC, crashA, crashB))

        enginesController.stop()
    }

    func testStopWhenUploading() {
        // create fake reports
        let crashA = engine.engineDir.appendingPathComponent("A.tar.gz")
        let crashB = engine.engineDir.appendingPathComponent("B.tar.gz")
        // internet is available
        internetConnectivity.mockInternetAvailable = true

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(crashReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))

        // mock collect finishes
        engine.completeCollection(result: [crashA, crashB])
        let task = httpSession.popLastTask() as! MockUploadTask

        // after completion, upload should be triggered and facility updated accordingly
        assertThat(changeCnt, `is`(2))
        assertThat(crashReporter, presentAnd(allOf(isUploading(), has(pendingCount: 2))))
        assertThat(engine.collectCnt, `is`(1))
        assertThat(task.fileUrl, `is`(crashA))
        assertThat(task.request.allHTTPHeaderFields?["x-account"], presentAnd(`is`("mockUserForReport")))
        assertThat(engine.pendingReportUrls, contains(crashA, crashB))

        enginesController.stop()
        assertThat(engine.pendingReportUrls, contains(crashA, crashB))
    }

    func testInternetLostAndRegained() {
        // create fake reports
        let crashA = engine.engineDir.appendingPathComponent("A.tar.gz")
        let crashB = engine.engineDir.appendingPathComponent("B.tar.gz")
        // internet is available
        internetConnectivity.mockInternetAvailable = true

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(crashReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))

        // mock collect finishes
        engine.completeCollection(result: [crashA, crashB])
        var task = httpSession.popLastTask() as! MockUploadTask

        // after completion, upload should be triggered and facility updated accordingly
        assertThat(changeCnt, `is`(2))
        assertThat(crashReporter, presentAnd(allOf(isUploading(), has(pendingCount: 2))))
        assertThat(task.fileUrl, `is`(crashA))
        assertThat(task.request.allHTTPHeaderFields?["x-account"], presentAnd(`is`("mockUserForReport")))
        assertThat(engine.pendingReportUrls, contains(crashA, crashB))

        // mock internet lost
        internetConnectivity.mockInternetAvailable = false

        // check that the task has been canceled (for the moment, the api should not change)
        assertThat(task.cancelCalls, `is`(1))
        assertThat(changeCnt, `is`(2))

        // mock cancelation
        task.mock(error: NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled))
        assertThat(changeCnt, `is`(3))
        assertThat(crashReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 2))))
        assertThat(httpSession.tasks, empty())
        assertThat(engine.pendingReportUrls, contains(crashA, crashB))

        // mock internet regained
        internetConnectivity.mockInternetAvailable = true
        task = httpSession.popLastTask() as! MockUploadTask

        assertThat(changeCnt, `is`(4))
        assertThat(crashReporter, presentAnd(allOf(isUploading(), has(pendingCount: 2))))
        assertThat(task.fileUrl, `is`(crashA))
        assertThat(task.request.allHTTPHeaderFields?["x-account"], presentAnd(`is`("mockUserForReport")))
        assertThat(engine.pendingReportUrls, contains(crashA, crashB))
    }

    func testUploadSuccess() {
        // create fake reports
        let crashA = engine.engineDir.appendingPathComponent("A.tar.gz")
        let crashB = engine.engineDir.appendingPathComponent("B.tar.gz")
        // internet is available
        internetConnectivity.mockInternetAvailable = true

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(crashReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))

        // mock collect finishes
        engine.completeCollection(result: [crashA, crashB])

        // after completion, upload should be triggered and facility updated accordingly
        var task = httpSession.popLastTask() as! MockUploadTask
        assertThat(changeCnt, `is`(2))
        assertThat(crashReporter, presentAnd(allOf(isUploading(), has(pendingCount: 2))))
        assertThat(task.fileUrl, `is`(crashA))
        assertThat(task.request.allHTTPHeaderFields?["x-account"], presentAnd(`is`("mockUserForReport")))
        assertThat(engine.pendingReportUrls, contains(crashA, crashB))

        // mock upload succeed
        task.mockCompletion(statusCode: 200)

        // after success, crash report should be deleted from the file system and from the list of pending crashes,
        // and a new upload should start
        task = httpSession.popLastTask() as! MockUploadTask
        assertThat(changeCnt, `is`(3))
        assertThat(crashReporter, presentAnd(allOf(isUploading(), has(pendingCount: 1))))
        assertThat(task.fileUrl, `is`(crashB))
        assertThat(engine.pendingReportUrls, contains(crashB))
        assertThat(engine.latestDeletedCrashUrl, presentAnd(`is`(crashA)))

        // mock last upload succeed
        task.mockCompletion(statusCode: 200)

        assertThat(changeCnt, `is`(4))
        assertThat(crashReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(httpSession.tasks, empty())
        assertThat(engine.pendingReportUrls, empty())
        assertThat(engine.latestDeletedCrashUrl, presentAnd(`is`(crashB)))
    }

    func testUploadFailure() {
        // create fake reports
        let badReport = engine.engineDir.appendingPathComponent("A.tar.gz")
        let badServer = engine.engineDir.appendingPathComponent("B.tar.gz")
        let connectionError = engine.engineDir.appendingPathComponent("C.tar.gz")
        let goodCrash = engine.engineDir.appendingPathComponent("D.tar.gz")
        // internet is available
        internetConnectivity.mockInternetAvailable = true

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(crashReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))

        // mock collect finishes
        engine.completeCollection(result: [badReport, badServer, connectionError, goodCrash])

        // after completion, upload should be triggered and facility updated accordingly
        var task = httpSession.popLastTask() as! MockUploadTask
        assertThat(changeCnt, `is`(2))
        assertThat(crashReporter, presentAnd(allOf(isUploading(), has(pendingCount: 4))))
        assertThat(task.fileUrl, `is`(badReport))
        assertThat(engine.pendingReportUrls, contains(badReport, badServer, connectionError, goodCrash))

        // mock upload failed with error badReport
        task.mock(error: NSError(domain: NSPOSIXErrorDomain, code: Int(EISDIR)))

        // receiving a bad report error should delete the report and upload the next one
        task = httpSession.popLastTask() as! MockUploadTask
        assertThat(changeCnt, `is`(3))
        assertThat(crashReporter, presentAnd(allOf(isUploading(), has(pendingCount: 3))))
        assertThat(task.fileUrl, `is`(badServer))
        assertThat(engine.pendingReportUrls, contains(badServer, connectionError, goodCrash))
        assertThat(engine.latestDeletedCrashUrl, presentAnd(`is`(badReport)))

        // mock upload failed with error serverError
        task.mockCompletion(statusCode: 415)

        // receiving a bad server error should delete the report and upload the next one
        task = httpSession.popLastTask() as! MockUploadTask
        assertThat(changeCnt, `is`(4))
        assertThat(crashReporter, presentAnd(allOf(isUploading(), has(pendingCount: 2))))
        assertThat(task.fileUrl, `is`(connectionError))
        assertThat(engine.pendingReportUrls, contains(connectionError, goodCrash))
        assertThat(engine.latestDeletedCrashUrl, presentAnd(`is`(badServer)))

        // mock upload failed with error connectionError
        task.mock(error: NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut))

        // receiving a connection error should stop the upload but not delete the crash nor remove it from the upload
        // queue
        assertThat(changeCnt, `is`(5))
        assertThat(crashReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 2))))
        assertThat(httpSession.tasks, empty())
        assertThat(engine.pendingReportUrls, contains(connectionError, goodCrash))
        // should not have changed
        assertThat(engine.latestDeletedCrashUrl, presentAnd(`is`(badServer)))
    }

    func testUploadFullCrashReportWithAccountAndDeleteFullAndLight() {
        // create fake reports
        let reportFull = engine.engineDir.appendingPathComponent("A.tar.gz")
        let reportLight = engine.engineDir.appendingPathComponent("A.tar.gz.anon")

        // internet is available
        internetConnectivity.mockInternetAvailable = false

        enginesController.start()
        engine.completeCollection(result: [reportFull, reportLight])

        internetConnectivity.mockInternetAvailable = true

        let task = httpSession.popLastTask() as! MockUploadTask
        assertThat(task.fileUrl, `is`(reportFull))

        task.mockCompletion(statusCode: 200)

        assertThat(engine.latestDeletedCrashUrl, presentAnd(`is`(reportLight)))
    }

    func testCrashReportQuota() {
        let crashReportA = engine.engineDir.appendingPathComponent("A.tar.gz")
        let crashReportB = engine.engineDir.appendingPathComponent("B.tar.gz")
        let crashReportC = engine.engineDir.appendingPathComponent("C.tar.gz")
        let dataA = String.randomString(length: 4 * 1024 * 1024)
        var someDateTime = Date(timeIntervalSinceReferenceDate: 15)
        FileManager.default.createFile(atPath: crashReportA.path,
                                       contents: dataA.data(using: .utf8),
                                       attributes: [FileAttributeKey.creationDate: someDateTime])
        let dataB = String.randomString(length: 2 * 1024 * 1024)
        someDateTime = Date(timeIntervalSinceReferenceDate: 30)
        FileManager.default.createFile(atPath: crashReportB.path,
                                       contents: dataB.data(using: .utf8),
                                       attributes: [FileAttributeKey.creationDate: someDateTime])
        let dataC = String.randomString(length: 1 * 1024 * 1024)
        someDateTime = Date(timeIntervalSinceReferenceDate: 60)
        FileManager.default.createFile(atPath: crashReportC.path,
                                       contents: dataC.data(using: .utf8),
                                       attributes: [FileAttributeKey.creationDate: someDateTime])

        enginesController.start()
        assertThat(FileManager.default.fileExists(atPath: crashReportA.path), `is`(false))
        assertThat(FileManager.default.fileExists(atPath: crashReportB.path), `is`(false))
        assertThat(FileManager.default.fileExists(atPath: crashReportC.path), `is`(true))
    }

    func testDropReport() {
        let crashReportA = engine.engineDir.appendingPathComponent("A.tar.gz")
        let crashReportB = engine.engineDir.appendingPathComponent("B.tar.gz")
        let crashReportC = engine.engineDir.appendingPathComponent("C.tar.gz")

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(crashReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))

        // mock collect finishes
        engine.completeCollection(result: [crashReportA, crashReportB, crashReportC])

        userAccountUtility.update(userAccountInfo: UserAccountInfoCore(account: nil,
                                        anonymousDataPolicy: AnonymousDataPolicy.deny,
                                        accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload))

        assertThat(engine.latestDeletedCrashUrl, presentAnd(`is`(crashReportC)))
    }

    func testDropReportWithDifferentAccount() {
        let crashReportA = engine.engineDir.appendingPathComponent("A.tar.gz")
        let crashReportB = engine.engineDir.appendingPathComponent("B.tar.gz")
        let crashReportC = engine.engineDir.appendingPathComponent("C.tar.gz")

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(crashReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))

        // mock collect finishes
        engine.completeCollection(result: [crashReportA, crashReportB, crashReportC])

        userAccountUtility.update(userAccountInfo: UserAccountInfoCore(account: "mockUser2",
                                            anonymousDataPolicy: AnonymousDataPolicy.deny,
                                            accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload))

        assertThat(engine.latestDeletedCrashUrl, presentAnd(`is`(crashReportC)))
    }

    func testDoNotDropReportFromNoAccountToAcount() {
        userAccountUtility.update(userAccountInfo: UserAccountInfoCore(account: nil,
                                            anonymousDataPolicy: AnonymousDataPolicy.deny,
                                            accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload))

        let crashReportA = engine.engineDir.appendingPathComponent("A.tar.gz")
        let crashReportB = engine.engineDir.appendingPathComponent("B.tar.gz")
        let crashReportC = engine.engineDir.appendingPathComponent("C.tar.gz")

        enginesController.start()

        assertThat(changeCnt, `is`(1))
        assertThat(crashReporter, presentAnd(allOf(isNotUploading(), has(pendingCount: 0))))
        assertThat(engine.collectCnt, `is`(1))

        // mock collect finishes
        engine.completeCollection(result: [crashReportA, crashReportB, crashReportC])
        userAccountUtility.update(userAccountInfo: UserAccountInfoCore(account: "mockUser",
                                            anonymousDataPolicy: AnonymousDataPolicy.deny,
                                            accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload))
        assertThat(engine.latestDeletedCrashUrl, nilValue())
    }
}
