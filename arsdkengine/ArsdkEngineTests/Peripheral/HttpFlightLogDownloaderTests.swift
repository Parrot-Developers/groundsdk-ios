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
import XCTest

@testable import ArsdkEngine
@testable import GroundSdk
import SdkCoreTesting

class HttpFlightLogDownloaderTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var droneFlightLogDownloader: FlightLogDownloader?
    var droneFlightLogDownloaderRef: Ref<FlightLogDownloader>?
    var changeCnt = 0

    override func setGroundSdkConfig() {
        super.setGroundSdkConfig()
        GroundSdkConfig.sharedInstance.enableFlightLog = true
    }

    override func setUp() {
        super.setUp()

        mockArsdkCore.addDevice(
            "123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1", handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        droneFlightLogDownloaderRef =
            drone.getPeripheral(Peripherals.flightLogDownloader) { [unowned self] flightLogDownloader in
                self.droneFlightLogDownloader = flightLogDownloader
                self.changeCnt += 1
        }
        changeCnt = 0
    }

    override func tearDown() {
        GroundSdkConfig.sharedInstance.enableFlightLog = false
    }

    func testDownloadErrorWhileListing() {
        connect(drone: drone, handle: 1)

        assertThat(changeCnt, `is`(1))

        assertThat(droneFlightLogDownloader!, isIdle())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(changeCnt, `is`(2))
        assertThat(droneFlightLogDownloader!, isDownloading(downloadedCount: 0))
        let task = httpSession.popLastTask() as! MockDataTask

        // mock answer from low-level
        task.mockCompletionFail(statusCode: 500)
        assertThat(changeCnt, `is`(3))
        assertThat(droneFlightLogDownloader!, hasFailedToDownload(downloadedCount: 0))
    }

    func testDownloadErrorDownloading() {

        let dateUserString = "20180101T101112+0000"
        let dateUser = DateFormatter.iso8601Base.date(from: dateUserString)

        let userAccountInfo = UserAccountInfoCore(account: "user1",
                                                changeDate: dateUser!, anonymousDataPolicy: AnonymousDataPolicy.allow,
                                                accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload)
        userAccountUtility.userAccountInfo = userAccountInfo

        connect(drone: drone, handle: 1)

        assertThat(changeCnt, `is`(1))

        assertThat(droneFlightLogDownloader!, isIdle())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(changeCnt, `is`(2))
        assertThat(droneFlightLogDownloader!, isDownloading(downloadedCount: 0))
        let task = httpSession.popLastTask() as! MockDataTask

        // mock answer from low-level
        let serverAnswer = "[{" +
            "\"name\": \"logA.bin\"," +
            "\"date\": \"20180201T101112+0100\"," +
        "\"url\": \"logA.bin\"}]"
        task.mockCompletionSuccess(data: serverAnswer.data(using: .utf8))

        // nothing should change yet
        assertThat(changeCnt, `is`(2))
        // a download task should be issued
        let dlTask = httpSession.popLastTask() as! MockDownloadTask

        // mock failure during the download
        dlTask.mockCompletionFail(statusCode: 500)

        // after a download fail, no deletion should be done, but the overall task should continue. Since there was only
        // one report to download, the peripheral should declare that it has successfully downloaded 0 report.
        assertThat(changeCnt, `is`(3))
        assertThat(droneFlightLogDownloader!, hasDownloaded(downloadedCount: 0))
        assertThat(httpSession.tasks, empty())
    }

    func testDownloadErrorDeleting() {
        let dateUserString = "20180101T101112+0000"
        let dateUser = DateFormatter.iso8601Base.date(from: dateUserString)

        let userAccountInfo = UserAccountInfoCore(account: "user1",
                                            changeDate: dateUser!, anonymousDataPolicy: AnonymousDataPolicy.allow,
                                            accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload)
        userAccountUtility.userAccountInfo = userAccountInfo

        connect(drone: drone, handle: 1)

        assertThat(changeCnt, `is`(1))

        assertThat(droneFlightLogDownloader!, isIdle())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(changeCnt, `is`(2))
        assertThat(droneFlightLogDownloader!, isDownloading(downloadedCount: 0))
        let task = httpSession.popLastTask() as! MockDataTask

        // mock answer from low-level
        let serverAnswer = "[{" +
            "\"name\": \"log1.bin\"," +
            "\"date\": \"20180201T101112+0100\"," +
        "\"url\": \"log1.bin\"}]"
        task.mockCompletionSuccess(data: serverAnswer.data(using: .utf8))

        // nothing should change yet
        assertThat(changeCnt, `is`(2))
        // a download task should be issued
        let dlTask = httpSession.popLastTask() as! MockDownloadTask

        // mock download completion during the download
        dlTask.mockCompletionSuccess(localFileUrl: URL(fileURLWithPath: "/log1.bin"))

        // we don't wait the delete to be done to update the peripheral
        assertThat(changeCnt, `is`(3))
        assertThat(droneFlightLogDownloader!, isDownloading(downloadedCount: 1))

        // a delete task should be issued
        let deleteTask = httpSession.popLastTask() as! MockDataTask

        // mock failure
        deleteTask.mockCompletionFail(statusCode: 500)

        // after a delete fail, the overall task should continue. Since there was only
        // one report to download and it has already been notified, no other task should be issued.
        assertThat(httpSession.tasks, empty())
        assertThat(changeCnt, `is`(4))
        assertThat(droneFlightLogDownloader!, hasDownloaded(downloadedCount: 1))
    }

    func testDownloadCancelDuringListing() {

        connect(drone: drone, handle: 1)

        assertThat(changeCnt, `is`(1))

        assertThat(droneFlightLogDownloader!, isIdle())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(changeCnt, `is`(2))
        assertThat(droneFlightLogDownloader!, isDownloading(downloadedCount: 0))
        let task = httpSession.popLastTask() as! MockDataTask
        assertThat(task.cancelCalls, `is`(0))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        assertThat(task.cancelCalls, `is`(1))

        // mock answer from low-level
        task.mock(error: NSError(domain: "mockError", code: URLError.cancelled.rawValue))
        assertThat(changeCnt, `is`(3))
        assertThat(droneFlightLogDownloader!, hasFailedToDownload(downloadedCount: 0))
    }

    func testDownloadCancelDownloading() {

        let dateUserString = "20180101T101112+0000"
        let dateUser = DateFormatter.iso8601Base.date(from: dateUserString)

        let userAccountInfo = UserAccountInfoCore(account: "user1",
                                            changeDate: dateUser!, anonymousDataPolicy: AnonymousDataPolicy.allow,
                                            accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload)
        userAccountUtility.userAccountInfo = userAccountInfo

        connect(drone: drone, handle: 1)
        assertThat(changeCnt, `is`(1))
        assertThat(droneFlightLogDownloader!, isIdle())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(changeCnt, `is`(2))
        assertThat(droneFlightLogDownloader!, isDownloading(downloadedCount: 0))
        let task = httpSession.popLastTask() as! MockDataTask
        // mock answer from low-level
        let serverAnswer = "[{" +
            "\"name\": \"log1.bin\"," +
            "\"date\": \"20180201T121355+0100\"," +
            "\"url\": \"log1.bin\"}," +
            "{" +
            "\"name\": \"log2.bin\"," +
            "\"date\": \"20180301T101357+0100\"," +
        "\"url\": \"log2.bin\"}]"
        task.mockCompletionSuccess(data: serverAnswer.data(using: .utf8))

        // nothing should change yet
        assertThat(changeCnt, `is`(2))
        // a download task should be issued
        let dlTask = httpSession.popLastTask() as! MockDownloadTask
        assertThat(dlTask.cancelCalls, `is`(0))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        assertThat(dlTask.cancelCalls, `is`(1))

        // mock failure during the download
        dlTask.mock(error: NSError(domain: "mockError", code: URLError.cancelled.rawValue))

        // after a download cancel, no deletion should be done, and the list of pending download should be cleared.
        // Hence, the peripheral should declare that it has successfully downloaded 0 report.
        assertThat(changeCnt, `is`(3))
        assertThat(droneFlightLogDownloader!, hasFailedToDownload(downloadedCount: 0))
        assertThat(httpSession.tasks, empty())
    }

    /// Test the case where the cancel is called by the task finishes normally.
    func testDownloadCancelDownloadingButTaskSucceed() {

        let dateUserString = "20180101T101112+0000"
        let dateUser = DateFormatter.iso8601Base.date(from: dateUserString)

        let userAccountInfo = UserAccountInfoCore(account: "user1",
                                            changeDate: dateUser!, anonymousDataPolicy: AnonymousDataPolicy.allow,
                                            accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload)
        userAccountUtility.userAccountInfo = userAccountInfo

        connect(drone: drone, handle: 1)

        assertThat(changeCnt, `is`(1))

        assertThat(droneFlightLogDownloader!, isIdle())

        mockArsdkCore.onCommandReceived(1,
            encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(changeCnt, `is`(2))
        assertThat(droneFlightLogDownloader!, isDownloading(downloadedCount: 0))
        let task = httpSession.popLastTask() as! MockDataTask

        // mock answer from low-level
        let serverAnswer = "[{" +
            "\"name\": \"log1.bin\"," +
            "\"date\": \"20180201T121355+0100\"," +
            "\"url\": \"rlog1.bin\"}," +
            "{" +
            "\"name\": \"log2.bin\"," +
            "\"date\": \"20180301T121355+0100\"," +
        "\"url\": \"log2.bin\"}]"
        task.mockCompletionSuccess(data: serverAnswer.data(using: .utf8))

        // nothing should change yet
        assertThat(changeCnt, `is`(2))
        // a download task should be issued
        let dlTask = httpSession.popLastTask() as! MockDownloadTask
        assertThat(dlTask.cancelCalls, `is`(0))

        // mock flying state changes, this will cancel the download
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        assertThat(dlTask.cancelCalls, `is`(1))

        // mock download completion during the download, even if the cancel has been issued
        dlTask.mockCompletionSuccess(localFileUrl: URL(fileURLWithPath: "/logA.bin"))

        // we don't wait the delete to be done to update the peripheral
        assertThat(changeCnt, `is`(3))
        assertThat(droneFlightLogDownloader!, isDownloading(downloadedCount: 1))

        // a delete task should be issued even if the cancel has been asked
        let deleteTask = httpSession.popLastTask() as! MockDataTask
        assertThat(deleteTask.cancelCalls, `is`(0))

        // mock deletion success
        deleteTask.mockCompletionSuccess(data: nil) // data not needed in case of a deletion

        // after a download cancel, the list of pending download should be cleared. Hence,
        // the peripheral should declare that it has successfully downloaded 1 report.
        assertThat(changeCnt, `is`(4))
        assertThat(droneFlightLogDownloader!, hasFailedToDownload(downloadedCount: 1))
        assertThat(httpSession.tasks, empty())
    }

    func testDownloadCancelDeleting() {
        let dateUserString = "20180101T101112+0000"
        let dateUser = DateFormatter.iso8601Base.date(from: dateUserString)

        let userAccountInfo = UserAccountInfoCore(account: "user1",
                                            changeDate: dateUser!, anonymousDataPolicy: AnonymousDataPolicy.allow,
                                            accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload)
        userAccountUtility.userAccountInfo = userAccountInfo

        connect(drone: drone, handle: 1)

        assertThat(changeCnt, `is`(1))

        assertThat(droneFlightLogDownloader!, isIdle())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))

        assertThat(changeCnt, `is`(2))
        assertThat(droneFlightLogDownloader!, isDownloading(downloadedCount: 0))
        let task = httpSession.popLastTask() as! MockDataTask

        // mock answer from low-level
        let serverAnswer = "[{" +
            "\"name\": \"log1.bin\"," +
            "\"date\": \"20180201T121355+0100\"," +
            "\"url\": \"log1.bin\"}," +
            "{" +
            "\"name\": \"log2.bin\"," +
            "\"date\": \"20180301T101357+0100\"," +
        "\"url\": \"log2.bin\"}]"
        task.mockCompletionSuccess(data: serverAnswer.data(using: .utf8))

        // nothing should change yet
        assertThat(changeCnt, `is`(2))
        // a download task should be issued

        let dlTask = httpSession.popLastTask() as! MockDownloadTask

        // mock download completion during the download
        dlTask.mockCompletionSuccess(localFileUrl: URL(fileURLWithPath: "/log1.bin"))

        // we don't wait the delete to be done to update the peripheral
        assertThat(changeCnt, `is`(3))
        assertThat(droneFlightLogDownloader!, isDownloading(downloadedCount: 1))

        // a delete task should be issued
        let deleteTask = httpSession.popLastTask() as! MockDataTask
        assertThat(deleteTask.cancelCalls, `is`(0))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        assertThat(deleteTask.cancelCalls, `is`(1))

        // mock failure
        deleteTask.mock(error: NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled))

        // after a download cancel, the list of pending download should be cleared. Hence,
        // the peripheral should declare that it has successfully downloaded 1 report.
        assertThat(changeCnt, `is`(4))
        assertThat(droneFlightLogDownloader!, hasFailedToDownload(downloadedCount: 1))
        assertThat(httpSession.tasks, empty())
    }

    func testDownloadFromDrone() {
        let dateUserString = "20180101T101112+0000"
        let dateUser = DateFormatter.iso8601Base.date(from: dateUserString)

        let userAccountInfo = UserAccountInfoCore(account: "user1",
                                                changeDate: dateUser!, anonymousDataPolicy: AnonymousDataPolicy.allow,
                                                accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload)
        userAccountUtility.userAccountInfo = userAccountInfo

        connect(drone: drone, handle: 1)

        assertThat(changeCnt, `is`(1))

        assertThat(droneFlightLogDownloader!, isIdle())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(changeCnt, `is`(2))
        assertThat(droneFlightLogDownloader!, isDownloading(downloadedCount: 0))
        let listingTask = httpSession.popLastTask() as! MockDataTask

        let serverAnswer = "[{" +
            "\"name\": \"log1.bin\"," +
            "\"date\": \"20180201T101112+0100\"," +
            "\"url\": \"log1.bin\"}," +
            "{" +
            "\"name\": \"log2.bin\"," +
            "\"date\": \"20180301T101112+0100\"," +
        "\"url\": \"log2.bin\"}]"
        listingTask.mockCompletionSuccess(data: serverAnswer.data(using: .utf8))

        // nothing should change yet
        assertThat(changeCnt, `is`(2))
        // a download task should be issued
        let dlTask = httpSession.popLastTask() as! MockDownloadTask

        // download progress should be ignored
        dlTask.mock(progress: 50)
        assertThat(changeCnt, `is`(2))

        // mock download completion during the download
        dlTask.mockCompletionSuccess(localFileUrl: URL(fileURLWithPath: "/logA.bin"))

        // we don't wait the delete to be done to update the peripheral
        assertThat(changeCnt, `is`(3))
        assertThat(droneFlightLogDownloader!, isDownloading(downloadedCount: 1))

        // a delete task should be issued
        let deleteTask = httpSession.popLastTask() as! MockDataTask

        // mock delete success
        deleteTask.mockCompletionSuccess(data: nil) // data not needed in case of a deletion

        // a new download task should be issued
        // a download task should be issued
        let dlTask2 = httpSession.popLastTask() as! MockDownloadTask

        // mock download completion during the download
        dlTask2.mockCompletionSuccess(localFileUrl: URL(fileURLWithPath: "/logA.bin"))

        // we don't wait the delete to be done to update the peripheral
        assertThat(changeCnt, `is`(4))
        assertThat(droneFlightLogDownloader!, isDownloading(downloadedCount: 2))

        // a delete task should be issued
        let deleteTask2 = httpSession.popLastTask() as! MockDataTask

        // mock delete success
        deleteTask2.mockCompletionSuccess(data: nil) // data not needed in case of a deletion

        // after a delete fail, the overall task should continue. Since there was only
        // one report to download and it has already been notified, no other task should be issued.
        assertThat(httpSession.tasks, empty())
        assertThat(changeCnt, `is`(5))
        assertThat(droneFlightLogDownloader!, hasDownloaded(downloadedCount: 2))
    }

    func testDeleteFileIfNoUser() {
        connect(drone: drone, handle: 1)

        assertThat(changeCnt, `is`(1))

        assertThat(droneFlightLogDownloader!, isIdle())

        let serverAnswer = "[{" +
            "\"name\": \"logbefore.bin\"," +
            "\"date\": \"19700103T182145+0100\"," + // the date is before dateUser
            "\"url\": \"logbefore.bin\"}," +
            "{" +
            "\"name\": \"logafter.bin\"," +
            "\"date\": \"20190101T101112+0000\"," +    // the date is after dateUser
        "\"url\": \"logafter.bin\"}]"

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        assertThat(changeCnt, `is`(2))
        assertThat(droneFlightLogDownloader!, isDownloading(downloadedCount: 0))
        let listingTask = httpSession.popLastTask() as! MockDataTask
        listingTask.mockCompletionSuccess(data: serverAnswer.data(using: .utf8))

        // nothing should change yet
        assertThat(changeCnt, `is`(2))
        // last task is a donwload task
        let downloadTask = httpSession.popLastTask() as! MockDownloadTask
        assertThat(downloadTask, present())

    }
}
