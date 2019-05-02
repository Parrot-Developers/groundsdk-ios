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

class HttpFlightDataDownloaderTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var droneFlightDataDownloader: FlightDataDownloader?
    var droneFlightDataDownloaderRef: Ref<FlightDataDownloader>?
    var changeCnt = 0

    override func setGroundSdkConfig() {
        // be sure to deactivate the crashMl reporter, in order to avoid unwanted Mock Tasks requests
        super.setGroundSdkConfig()
        GroundSdkConfig.sharedInstance.enableFlightData = true
    }

    override func setUp() {
        super.setUp()

        mockArsdkCore.addDevice(
            "123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1", handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        droneFlightDataDownloaderRef =
            drone.getPeripheral(Peripherals.flightDataDownloader) { [unowned self] flightDataDownloader in
                self.droneFlightDataDownloader = flightDataDownloader
                self.changeCnt += 1
        }

        changeCnt = 0
    }

    override func tearDown() {
        GroundSdkConfig.sharedInstance.enableFlightData = false
    }

    func testDownloadErrorWhileListing() {
        connect(drone: drone, handle: 1)

        assertThat(changeCnt, `is`(1))

        assertThat(droneFlightDataDownloader!, isIdle())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        let task = httpSession.popLastTask() as! MockDataTask

        // mock answer from low-level
        task.mockCompletionFail(statusCode: 500)
        assertThat(changeCnt, `is`(2))
        assertThat(droneFlightDataDownloader!, hasFailedToDownload(latestDownloadCount: 0))
    }

    func testDownloadErrorDownloading() {
        connect(drone: drone, handle: 1)

        assertThat(changeCnt, `is`(1))

        assertThat(droneFlightDataDownloader!, isIdle())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        let task = httpSession.popLastTask() as! MockDataTask

        // mock answer from low-level
        let serverAnswer = "[{" +
            "\"name\": \"flight1.pud\"," +
            "\"date\": \"19700101T041608+0200\"," +
        "\"url\": \"/data/pud/flight1.pud\"}]"
        task.mockCompletionSuccess(data: serverAnswer.data(using: .utf8))

        assertThat(changeCnt, `is`(2))
        assertThat(droneFlightDataDownloader!, isDownloading(latestDownloadCount: 0))

        // a download task should be issued
        let dlTask = httpSession.popLastTask() as! MockStreamDownloadTask

        // mock failure during the download
        dlTask.mockCompletionFail(statusCode: 500)

        // after a download fail, no deletion should be done, but the overall task should continue. Since there was only
        // one report to download, the peripheral should declare that it has successfully downloaded 0 report.
        assertThat(changeCnt, `is`(3))
        assertThat(droneFlightDataDownloader!, hasDownloaded(latestDownloadCount: 0))
        assertThat(httpSession.tasks, empty())
    }

    func testDownloadErrorDeleting() {
        connect(drone: drone, handle: 1)

        assertThat(changeCnt, `is`(1))

        assertThat(droneFlightDataDownloader!, isIdle())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        let task = httpSession.popLastTask() as! MockDataTask

        // mock answer from low-level
        let serverAnswer = "[{" +
            "\"name\": \"flight1.pud\"," +
            "\"date\": \"19700101T049999+0200\"," +
        "\"url\": \"/data/pud/flight2.pud\"}]"
        task.mockCompletionSuccess(data: serverAnswer.data(using: .utf8))

        assertThat(changeCnt, `is`(2))
        assertThat(droneFlightDataDownloader!, isDownloading(latestDownloadCount: 0))

        // a download task should be issued
        let dlTask = httpSession.popLastTask() as! MockStreamDownloadTask

        // mock download completion during the download
        dlTask.mockCompletionSuccess(localFileUrl: URL(fileURLWithPath: "/flight1.pud"))

        // we don't wait the delete to be done to update the peripheral
        assertThat(changeCnt, `is`(3))
        assertThat(droneFlightDataDownloader!, isDownloading(latestDownloadCount: 1))

        // a delete task should be issued
        let deleteTask = httpSession.popLastTask() as! MockDataTask

        // mock failure
        deleteTask.mockCompletionFail(statusCode: 500)

        // after a delete fail, the overall task should continue. Since there was only
        // one report to download and it has already been notified, no other task should be issued.
        assertThat(httpSession.tasks, empty())
        assertThat(changeCnt, `is`(4))
        assertThat(droneFlightDataDownloader!, hasDownloaded(latestDownloadCount: 1))
    }

    func testDownloadCancelDuringListing() {

        connect(drone: drone, handle: 1)

        assertThat(changeCnt, `is`(1))

        assertThat(droneFlightDataDownloader!, isIdle())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))

        let task = httpSession.popLastTask() as! MockDataTask
        assertThat(task.cancelCalls, `is`(0))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        assertThat(task.cancelCalls, `is`(1))

        // mock answer from low-level
        task.mock(error: NSError(domain: "mockError", code: URLError.cancelled.rawValue))
        assertThat(changeCnt, `is`(2))
        assertThat(droneFlightDataDownloader!, hasFailedToDownload(latestDownloadCount: 0))
    }

    func testDownloadCancelDownloading() {
        connect(drone: drone, handle: 1)

        assertThat(changeCnt, `is`(1))

        assertThat(droneFlightDataDownloader!, isIdle())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        let task = httpSession.popLastTask() as! MockDataTask

        // mock answer from low-level
        let serverAnswer = "[{" +
            "\"name\": \"flight1.pud\"," +
            "\"date\": \"19700101T041608+0200\"," +
            "\"url\": \"/data/pud/flight1.pud\"}," +
            "{" +
            "\"name\": \"flight2.pud\"," +
            "\"date\": \"19700101T049999+0200\"," +
        "\"url\": \"/data/pud/flight2.pud\"}]"
        task.mockCompletionSuccess(data: serverAnswer.data(using: .utf8))
        assertThat(changeCnt, `is`(2))
        assertThat(droneFlightDataDownloader!, isDownloading(latestDownloadCount: 0))

        // a download task should be issued
        let dlTask = httpSession.popLastTask() as! MockStreamDownloadTask
        assertThat(dlTask.cancelCalls, `is`(0))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        assertThat(dlTask.cancelCalls, `is`(1))

        // mock failure during the download
        dlTask.mock(error: NSError(domain: "mockError", code: URLError.cancelled.rawValue))

        // after a download cancel, no deletion should be done, and the list of pending download should be cleared.
        // Hence, the peripheral should declare that it has successfully downloaded 0 report.
        assertThat(changeCnt, `is`(3))
        assertThat(droneFlightDataDownloader!, hasFailedToDownload(latestDownloadCount: 0))
        assertThat(httpSession.tasks, empty())
    }

    /// Test the case where the cancel is called by the task finishes normally.
    func testDownloadCancelDownloadingButTaskSucceed() {
        connect(drone: drone, handle: 1)

        assertThat(changeCnt, `is`(1))

        assertThat(droneFlightDataDownloader!, isIdle())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        let task = httpSession.popLastTask() as! MockDataTask

        // mock answer from low-level
        let serverAnswer = "[{" +
            "\"name\": \"flight1.pud\"," +
            "\"date\": \"19700101T041608+0200\"," +
            "\"url\": \"/data/pud/flight1.pud\"}," +
            "{" +
            "\"name\": \"flight2.pud\"," +
            "\"date\": \"19700101T049999+0200\"," +
        "\"url\": \"/data/pud/flight2.pud\"}]"
        task.mockCompletionSuccess(data: serverAnswer.data(using: .utf8))

        assertThat(changeCnt, `is`(2))
        assertThat(droneFlightDataDownloader!, isDownloading(latestDownloadCount: 0))
        // a download task should be issued
        let dlTask = httpSession.popLastTask() as! MockStreamDownloadTask
        assertThat(dlTask.cancelCalls, `is`(0))

        // mock flying state changes, this will cancel the download
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        assertThat(dlTask.cancelCalls, `is`(1))

        // mock download completion during the download, even if the cancel has been issued
        dlTask.mockCompletionSuccess(localFileUrl: URL(fileURLWithPath: "/report.tar.gz"))

        // we don't wait the delete to be done to update the peripheral
        assertThat(changeCnt, `is`(3))
        assertThat(droneFlightDataDownloader!, isDownloading(latestDownloadCount: 1))

        // a delete task should be issued even if the cancel has been asked
        let deleteTask = httpSession.popLastTask() as! MockDataTask
        assertThat(deleteTask.cancelCalls, `is`(0))

        // mock deletion success
        deleteTask.mockCompletionSuccess(data: nil) // data not needed in case of a deletion

        // after a download cancel, the list of pending download should be cleared. Hence,
        // the peripheral should declare that it has successfully downloaded 1 report.
        assertThat(changeCnt, `is`(4))
        assertThat(droneFlightDataDownloader!, hasFailedToDownload(latestDownloadCount: 1))
        assertThat(httpSession.tasks, empty())
    }

    func testDownloadCancelDeleting() {
        connect(drone: drone, handle: 1)

        assertThat(changeCnt, `is`(1))

        assertThat(droneFlightDataDownloader!, isIdle())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        let task = httpSession.popLastTask() as! MockDataTask

        // mock answer from low-level
        let serverAnswer = "[{" +
            "\"name\": \"flight1.pud\"," +
            "\"date\": \"19700101T041608+0200\"," +
            "\"url\": \"/data/pud/flight1.pud\"}," +
            "{" +
            "\"name\": \"flight2.pud\"," +
            "\"date\": \"19700101T049999+0200\"," +
        "\"url\": \"/data/pud/flight2.pud\"}]"
        task.mockCompletionSuccess(data: serverAnswer.data(using: .utf8))

        assertThat(changeCnt, `is`(2))
        assertThat(droneFlightDataDownloader!, isDownloading(latestDownloadCount: 0))
        // a download task should be issued
        let dlTask = httpSession.popLastTask() as! MockStreamDownloadTask

        // mock download completion during the download
        dlTask.mockCompletionSuccess(localFileUrl: URL(fileURLWithPath: "/report.tar.gz"))

        // we don't wait the delete to be done to update the peripheral
        assertThat(changeCnt, `is`(3))
        assertThat(droneFlightDataDownloader!, isDownloading(latestDownloadCount: 1))

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
        assertThat(droneFlightDataDownloader!, hasFailedToDownload(latestDownloadCount: 1))
        assertThat(httpSession.tasks, empty())
    }

    func testDownloadFromDrone() {
        connect(drone: drone, handle: 1)

        assertThat(changeCnt, `is`(1))

        assertThat(droneFlightDataDownloader!, isIdle())

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        let listingTask = httpSession.popLastTask() as! MockDataTask

        // mock answer from low-level
        let serverAnswer = "[{" +
            "\"name\": \"flight1.pud\"," +
            "\"date\": \"19700101T041608+0200\"," +
            "\"url\": \"/data/pud/flight1.pud\"}," +
            "{" +
            "\"name\": \"flight2.pud\"," +
            "\"date\": \"19700101T049999+0200\"," +
        "\"url\": \"/data/pud/flight2.pud\"}]"
        listingTask.mockCompletionSuccess(data: serverAnswer.data(using: .utf8))

        assertThat(changeCnt, `is`(2))
        assertThat(droneFlightDataDownloader!, isDownloading(latestDownloadCount: 0))
        // a download task should be issued
        let dlTask = httpSession.popLastTask() as! MockStreamDownloadTask

        // mock download completion during the download
        dlTask.mockCompletionSuccess(localFileUrl: URL(fileURLWithPath: "/data/pud/flight1.pud"))

        // we don't wait the delete to be done to update the peripheral
        assertThat(changeCnt, `is`(3))
        assertThat(droneFlightDataDownloader!, isDownloading(latestDownloadCount: 1))

        // a delete task should be issued
        let deleteTask = httpSession.popLastTask() as! MockDataTask

        // mock delete success
        deleteTask.mockCompletionSuccess(data: nil) // data not needed in case of a deletion

        // a new download task should be issued
        // a download task should be issued
        let dlTask2 = httpSession.popLastTask() as! MockStreamDownloadTask

        // mock download completion during the download
        dlTask2.mockCompletionSuccess(localFileUrl: URL(fileURLWithPath: "/report.tar.gz"))

        // we don't wait the delete to be done to update the peripheral
        assertThat(changeCnt, `is`(4))
        assertThat(droneFlightDataDownloader!, isDownloading(latestDownloadCount: 2))

        // a delete task should be issued
        let deleteTask2 = httpSession.popLastTask() as! MockDataTask

        // mock delete success
        deleteTask2.mockCompletionSuccess(data: nil) // data not needed in case of a deletion

        // after a delete fail, the overall task should continue. Since there was only
        // one report to download and it has already been notified, no other task should be issued.
        assertThat(httpSession.tasks, empty())
        assertThat(changeCnt, `is`(5))
        assertThat(droneFlightDataDownloader!, hasDownloaded(latestDownloadCount: 2))
    }
}
