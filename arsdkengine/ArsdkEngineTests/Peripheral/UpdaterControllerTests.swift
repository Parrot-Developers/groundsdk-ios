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

class UpdaterControllerTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var remoteControl: RemoteControlCore!
    var firmwareUpdater: Updater?
    var firmwareUpdaterRef: Ref<Updater>?
    var changeCnt = 0

    let localUrl = URL(fileURLWithPath: NSHomeDirectory().appending("fwFile"), isDirectory: false)

    let fwId1 = FirmwareIdentifier(deviceModel: .drone(.anafi4k), version: FirmwareVersion.parse(versionStr: "1.0.0")!)
    let fwId2 = FirmwareIdentifier(deviceModel: .drone(.anafi4k), version: FirmwareVersion.parse(versionStr: "2.0.0")!)
    let fwId3 = FirmwareIdentifier(deviceModel: .drone(.anafi4k), version: FirmwareVersion.parse(versionStr: "3.0.0")!)
    let fwId4 = FirmwareIdentifier(deviceModel: .drone(.anafi4k), version: FirmwareVersion.parse(versionStr: "4.0.0")!)

    var fwInfo1: FirmwareInfoCore!
    var fwInfo2: FirmwareInfoCore!
    var fwInfo3: FirmwareInfoCore!
    var fwInfo4: FirmwareInfoCore!

    var fwEntry1: FirmwareStoreEntry!
    var fwEntry2: FirmwareStoreEntry!
    var fwEntry3: FirmwareStoreEntry!
    var fwEntry4: FirmwareStoreEntry!

    var transientStateTester: (() -> Void)?

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        firmwareUpdaterRef = drone.getPeripheral(Peripherals.updater) { [unowned self] firmwareUpdater in
            self.firmwareUpdater = firmwareUpdater
            self.changeCnt += 1
            if let transientStateTester = self.transientStateTester {
                transientStateTester()
                self.transientStateTester = nil
            }
        }

        changeCnt = 0

        fwInfo1 = FirmwareInfoCore(firmwareIdentifier: fwId1, attributes: [], size: 20, checksum: "")
        fwInfo2 = FirmwareInfoCore(firmwareIdentifier: fwId2, attributes: [], size: 20, checksum: "")
        fwInfo3 = FirmwareInfoCore(firmwareIdentifier: fwId3, attributes: [], size: 20, checksum: "")
        fwInfo4 = FirmwareInfoCore(firmwareIdentifier: fwId4, attributes: [], size: 20, checksum: "")

        fwEntry1 = FirmwareStoreEntry(firmware: fwInfo1, remoteUrl: URL(string: "http://remote"), embedded: false)
        fwEntry2 = FirmwareStoreEntry(firmware: fwInfo2, remoteUrl: URL(string: "http://remote"), embedded: false)
        fwEntry3 = FirmwareStoreEntry(firmware: fwInfo3, remoteUrl: URL(string: "http://remote"),
                                      requiredVersion: fwId2.version, embedded: false)
        fwEntry4 = FirmwareStoreEntry(firmware: fwInfo4, remoteUrl: URL(string: "http://remote"), embedded: false)
    }

    func testPublishUnpublish() {
        // Since device is not known yet, peripheral should be unpublished
        assertThat(firmwareUpdater, `is`(nilValue()))

        connect(drone: drone, handle: 1)
        assertThat(firmwareUpdater, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // since device is known, peripheral should stay published
        disconnect(drone: drone, handle: 1)
        assertThat(firmwareUpdater, `is`(present()))
        assertThat(changeCnt, `is`(2))

        _ = drone.forget()
        assertThat(changeCnt, `is`(3))
        assertThat(firmwareUpdater, `is`(nilValue()))
    }

    func testDownloadUnavailabilityReasons() {
        internetConnectivity.mockInternetAvailable = false

        connect(drone: drone, handle: 1)

        // check default values
        assertThat(changeCnt, `is`(1))
        assertThat(firmwareUpdater!.downloadUnavailabilityReasons, containsInAnyOrder(.internetUnavailable))

        // mock internet becomes available
        internetConnectivity.mockInternetAvailable = true

        assertThat(changeCnt, `is`(2))
        assertThat(firmwareUpdater!.downloadUnavailabilityReasons, empty())

        // mock internet becomes unavailable
        internetConnectivity.mockInternetAvailable = false

        assertThat(changeCnt, `is`(3))
        assertThat(firmwareUpdater!.downloadUnavailabilityReasons, containsInAnyOrder(.internetUnavailable))
    }

    func testUploadUnavailabilityReasons() {
        // Only test common reasons.
        // Specific reasons will be tested in specific tests

        connect(drone: drone, handle: 1)

        // check default values
        assertThat(changeCnt, `is`(1))
        assertThat(firmwareUpdater!.updateUnavailabilityReasons, empty())

        disconnect(drone: drone, handle: 1)

        assertThat(changeCnt, `is`(2))
        assertThat(firmwareUpdater!.updateUnavailabilityReasons, containsInAnyOrder(.notConnected))
    }

    func testDeviceFirmwareAndStoreUpdates() {
        // firmware store is empty
        firmwareStore.resetFirmwares([:])

        // drone with a fw version of 0.0.1 is connected
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(software: "0.0.1", hardware: ""))
        }

        // everything should be empty since the firmware store is empty
        assertThat(changeCnt, `is`(1))
        assertThat(firmwareUpdater!.downloadableFirmwares, empty())
        assertThat(firmwareUpdater!.applicableFirmwares, empty())
        assertThat(firmwareUpdater!.idealVersion, nilValue())

        // mock downloadable firmwares in store
        firmwareStore.resetFirmwares([fwId1: fwEntry1,
                                      fwId2: fwEntry2,
                                      fwId3: fwEntry3])

        assertThat(changeCnt, `is`(2))
        assertThat(firmwareUpdater!.downloadableFirmwares, contains(`is`(fwInfo2), `is`(fwInfo3)))
        assertThat(firmwareUpdater!.applicableFirmwares, empty())
        assertThat(firmwareUpdater!.idealVersion, presentAnd(`is`(fwInfo3.firmwareIdentifier.version)))

        // mock fwEntry1 has been downloaded
        firmwareStore.changeRemoteFirmwareToLocal(identifier: fwId1, localUrl: URL(fileURLWithPath: "/localFile"))
        assertThat(changeCnt, `is`(3))
        assertThat(firmwareUpdater!.downloadableFirmwares, contains(`is`(fwInfo2), `is`(fwInfo3)))
        assertThat(firmwareUpdater!.applicableFirmwares, contains(`is`(fwInfo1)))
        assertThat(firmwareUpdater!.idealVersion, presentAnd(`is`(fwInfo3.firmwareIdentifier.version)))

        // mock fwEntry2 has been downloaded
        firmwareStore.changeRemoteFirmwareToLocal(identifier: fwId2, localUrl: URL(fileURLWithPath: "/localFile"))
        assertThat(changeCnt, `is`(4))
        assertThat(firmwareUpdater!.downloadableFirmwares, contains(`is`(fwInfo3)))
        assertThat(firmwareUpdater!.applicableFirmwares, contains(`is`(fwInfo2)))
        assertThat(firmwareUpdater!.idealVersion, presentAnd(`is`(fwInfo3.firmwareIdentifier.version)))

        // disconnect drone
        disconnect(drone: drone, handle: 1)

        assertThat(changeCnt, `is`(5)) // +1 because updateUnavailabilityReasons has changed
        assertThat(firmwareUpdater!.downloadableFirmwares, contains(`is`(fwInfo3)))
        assertThat(firmwareUpdater!.applicableFirmwares, contains(`is`(fwInfo2)))
        assertThat(firmwareUpdater!.idealVersion, presentAnd(`is`(fwInfo3.firmwareIdentifier.version)))

        // mock new distant firmware added
        firmwareStore.mergeRemoteFirmwares([fwId4: fwEntry4])

        assertThat(changeCnt, `is`(6))
        assertThat(firmwareUpdater!.downloadableFirmwares, contains(`is`(fwInfo4)))
        assertThat(firmwareUpdater!.applicableFirmwares, contains(`is`(fwInfo2)))
        assertThat(firmwareUpdater!.idealVersion, presentAnd(`is`(fwInfo4.firmwareIdentifier.version)))

        // mock drone updated to latest known version
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(software: "4.0.0", hardware: ""))
        }

        assertThat(changeCnt, `is`(7))
        assertThat(firmwareUpdater!.downloadableFirmwares, empty())
        assertThat(firmwareUpdater!.applicableFirmwares, empty())
        assertThat(firmwareUpdater!.idealVersion, nilValue())

    }

    func testDownload() {
        // mock downloadable firmwares in store
        firmwareStore.resetFirmwares([fwId2: fwEntry2,
                                      fwId3: fwEntry3])
        // mock internet not available
        internetConnectivity.mockInternetAvailable = false

        // drone with a fw version of 0.0.1 is connected
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(software: "0.0.1", hardware: ""))
        }

        assertThat(changeCnt, `is`(1))
        assertThat(firmwareUpdater!.downloadableFirmwares, contains(`is`(fwInfo2), `is`(fwInfo3)))
        assertThat(firmwareUpdater!.applicableFirmwares, empty())

        // test that cannot download since no internet
        assertThat(firmwareUpdater?.downloadAllFirmwares(), `is`(false))
        assertThat(changeCnt, `is`(1))

        // mock internet not available
        internetConnectivity.mockInternetAvailable = true
        assertThat(changeCnt, `is`(2)) // +1 since download unavailability reasons has changed

        assertThat(firmwareUpdater?.downloadAllFirmwares(), `is`(true))
        assertThat(firmwareDownloader.firmwares, contains(fwInfo2, fwInfo3))
        // firmware downloader has its own test cases.
        // firmware download task state/updates is tested in groundsdk tests
    }

    func testStartUpdate() {
        firmwareStore.resetFirmwares([fwId1: fwEntry1])

        // drone with a fw version of 0.0.1 is connected
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(software: "0.0.1", hardware: ""))
        }

        // mock downloadable firmwares in store
        firmwareStore.resetFirmwares([fwId1: fwEntry1])

        assertThat(changeCnt, `is`(1))
        assertThat(firmwareUpdater!.downloadableFirmwares, contains(`is`(fwInfo1)))
        assertThat(firmwareUpdater!.applicableFirmwares, empty())

        assertThat(firmwareUpdater?.updateToNextFirmware(), `is`(false))

        // mock fwEntry1 has been downloaded
        firmwareStore.changeRemoteFirmwareToLocal(identifier: fwId1, localUrl: URL(fileURLWithPath: "/localFile"))
        assertThat(changeCnt, `is`(2))
        assertThat(firmwareUpdater!.downloadableFirmwares, empty())
        assertThat(firmwareUpdater!.applicableFirmwares, contains(`is`(fwInfo1)))

        assertThat(firmwareUpdater?.updateToNextFirmware(), `is`(true))
        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo1, currentProgress: 0, currentIndex: 1,
                 totalCount: 1, totalProgress: 0)))
        assertThat(changeCnt, `is`(3))
    }

    func testOngoingUpdateCancel() {
        firmwareStore.resetFirmwares([fwId1: fwEntry1])

        // drone with a fw version of 0.0.1 is connected
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(software: "0.0.1", hardware: ""))
        }

        assertThat(changeCnt, `is`(1))
        assertThat(firmwareUpdater!.downloadableFirmwares, contains(`is`(fwInfo1)))
        assertThat(firmwareUpdater!.applicableFirmwares, empty())

        // mock fwEntry1 has been downloaded
        firmwareStore.changeRemoteFirmwareToLocal(identifier: fwId1, localUrl: URL(fileURLWithPath: "/localFile"))
        assertThat(changeCnt, `is`(2))
        assertThat(firmwareUpdater!.downloadableFirmwares, empty())
        assertThat(firmwareUpdater!.applicableFirmwares, contains(`is`(fwInfo1)))

        assertThat(firmwareUpdater?.updateToLatestFirmware(), `is`(true))
        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo1, currentProgress: 0, currentIndex: 1,
                 totalCount: 1, totalProgress: 0)))
        assertThat(changeCnt, `is`(3))

        assertThat(firmwareUpdater?.cancelUpdate(), `is`(true))

        let task = httpSession.popLastTask() as? MockUploadTask
        assertThat(task?.cancelCalls, presentAnd(`is`(1)))

        transientStateTester = {
            assertThat(self.firmwareUpdater?.currentUpdate, presentAnd(
                `is`(state: .canceled, currentFirmware: self.fwInfo1, currentProgress: 0, currentIndex: 1,
                     totalCount: 1, totalProgress: 0)))
            assertThat(self.changeCnt, `is`(4))
        }

        task?.mock(error: NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled))

        assertThat(self.firmwareUpdater?.currentUpdate, presentAnd(nilValue()))
        assertThat(self.changeCnt, `is`(5))
    }

    func testWaitingUpdateCancel() {
        firmwareStore.resetFirmwares([fwId2: fwEntry2, fwId3: fwEntry3])

        // drone with a fw version of 0.0.1 is connected
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(software: "0.0.1", hardware: ""))
        }

        assertThat(changeCnt, `is`(1))
        assertThat(firmwareUpdater!.downloadableFirmwares, contains(`is`(fwInfo2), `is`(fwInfo3)))
        assertThat(firmwareUpdater!.applicableFirmwares, empty())

        // mock fwEntry2 and fwEntry3 have been downloaded
        firmwareStore.changeRemoteFirmwareToLocal(identifier: fwId2, localUrl: URL(fileURLWithPath: "/localFile"))
        firmwareStore.changeRemoteFirmwareToLocal(identifier: fwId3, localUrl: URL(fileURLWithPath: "/localFile"))
        assertThat(changeCnt, `is`(3)) // +2 because 2 changes
        assertThat(firmwareUpdater!.downloadableFirmwares, empty())
        assertThat(firmwareUpdater!.applicableFirmwares, contains(`is`(fwInfo2), `is`(fwInfo3)))

        assertThat(firmwareUpdater?.updateToLatestFirmware(), `is`(true))
        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo2, currentProgress: 0, currentIndex: 1,
                 totalCount: 2, totalProgress: 0)))
        assertThat(changeCnt, `is`(4))

        let task = httpSession.popLastTask() as? MockUploadTask
        task?.mockCompletion(statusCode: 200)

        // nothing should change, state .waitingForReboot happens at disconnection
        assertThat(self.firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo2, currentProgress: 0, currentIndex: 1,
                 totalCount: 2, totalProgress: 0)))
        assertThat(self.changeCnt, `is`(4))

        transientStateTester = {
            assertThat(self.firmwareUpdater?.currentUpdate, presentAnd(
                `is`(state: .canceled, currentFirmware: self.fwInfo2, currentProgress: 0, currentIndex: 1,
                     totalCount: 2, totalProgress: 0)))
            assertThat(self.changeCnt, `is`(5))
        }

        // cancel the update
        assertThat(firmwareUpdater?.cancelUpdate(), `is`(true))

        assertThat(task?.cancelCalls, `is`(0))  // since task was already finished, cancel should not be called
        assertThat(self.firmwareUpdater?.currentUpdate, nilValue())
        assertThat(self.changeCnt, `is`(6))

        // check that after a reconnection, no update is automatically done
        disconnect(drone: drone, handle: 1)
        connect(drone: drone, handle: 1)

        let newTask = httpSession.popLastTask() as? MockUploadTask
        assertThat(newTask, nilValue())
    }

    func testWaitingUpdateSuccessAtReconnection() {
        firmwareStore.resetFirmwares([fwId1: fwEntry1])

        // drone with a fw version of 0.0.1 is connected
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(software: "0.0.1", hardware: ""))
        }

        assertThat(changeCnt, `is`(1))
        assertThat(firmwareUpdater!.downloadableFirmwares, contains(`is`(fwInfo1)))
        assertThat(firmwareUpdater!.applicableFirmwares, empty())

        // mock fwEntry1 has been downloaded
        firmwareStore.changeRemoteFirmwareToLocal(identifier: fwId1, localUrl: URL(fileURLWithPath: "/localFile"))
        assertThat(changeCnt, `is`(2))
        assertThat(firmwareUpdater!.downloadableFirmwares, empty())
        assertThat(firmwareUpdater!.applicableFirmwares, contains(`is`(fwInfo1)))

        assertThat(firmwareUpdater?.updateToLatestFirmware(), `is`(true))
        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo1, currentProgress: 0, currentIndex: 1,
                 totalCount: 1, totalProgress: 0)))
        assertThat(changeCnt, `is`(3))

        let task = httpSession.popLastTask() as? MockUploadTask

        // mock upload completed
        task?.mock(progress: 100)
        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .processing, currentFirmware: fwInfo1, currentProgress: 100, currentIndex: 1,
                 totalCount: 1, totalProgress: 100)))
        assertThat(changeCnt, `is`(4))

        // mock completion
        task?.mockCompletion(statusCode: 200)
        assertThat(changeCnt, `is`(4)) // nothing should change, state .waitingForReboot happens at disconnection

        // mock disconnection
        disconnect(drone: drone, handle: 1)

        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .waitingForReboot, currentFirmware: fwInfo1, currentProgress: 100, currentIndex: 1,
                 totalCount: 1, totalProgress: 100)))
        assertThat(changeCnt, `is`(5))

        transientStateTester = {
            assertThat(self.firmwareUpdater?.currentUpdate, presentAnd(
                `is`(state: .success, currentFirmware: self.fwInfo1, currentProgress: 100, currentIndex: 1,
                     totalCount: 1, totalProgress: 100)))
            assertThat(self.changeCnt, `is`(6))
        }

        // mock reconnection with current version is the version of fwInfo1
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(software: "1.0.0", hardware: ""))
        }

        assertThat(self.firmwareUpdater?.currentUpdate, nilValue())
        assertThat(self.changeCnt, `is`(7))
        assertThat(transientStateTester, nilValue())
    }

    func testWaitingUpdateFirmwareMismatchAtReconnection() {
        firmwareStore.resetFirmwares([fwId1: fwEntry1])

        // drone with a fw version of 0.0.1 is connected
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(software: "0.0.1", hardware: ""))
        }

        assertThat(changeCnt, `is`(1))
        assertThat(firmwareUpdater!.downloadableFirmwares, contains(`is`(fwInfo1)))
        assertThat(firmwareUpdater!.applicableFirmwares, empty())

        // mock fwEntry1 has been downloaded
        firmwareStore.changeRemoteFirmwareToLocal(identifier: fwId1, localUrl: URL(fileURLWithPath: "/localFile"))
        assertThat(changeCnt, `is`(2))
        assertThat(firmwareUpdater!.downloadableFirmwares, empty())
        assertThat(firmwareUpdater!.applicableFirmwares, contains(`is`(fwInfo1)))

        assertThat(firmwareUpdater?.updateToLatestFirmware(), `is`(true))
        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo1, currentProgress: 0, currentIndex: 1,
                 totalCount: 1, totalProgress: 0)))
        assertThat(changeCnt, `is`(3))

        let task = httpSession.popLastTask() as? MockUploadTask

        // mock upload completed
        task?.mock(progress: 100)
        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .processing, currentFirmware: fwInfo1, currentProgress: 100, currentIndex: 1,
                 totalCount: 1, totalProgress: 100)))
        assertThat(changeCnt, `is`(4))

        // mock completion
        task?.mockCompletion(statusCode: 200)
        assertThat(changeCnt, `is`(4)) // nothing should change, state .waitingForReboot happens at disconnection

        // mock disconnection
        disconnect(drone: drone, handle: 1)

        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .waitingForReboot, currentFirmware: fwInfo1, currentProgress: 100, currentIndex: 1,
                 totalCount: 1, totalProgress: 100)))
        assertThat(changeCnt, `is`(5))

        transientStateTester = {
            assertThat(self.firmwareUpdater?.currentUpdate, presentAnd(
                `is`(state: .failed, currentFirmware: self.fwInfo1, currentProgress: 100, currentIndex: 1,
                     totalCount: 1, totalProgress: 100)))
            assertThat(self.changeCnt, `is`(6))
        }

        // mock reconnection with current version is not the version of fwInfo1
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(software: "0.0.1", hardware: ""))
        }

        assertThat(self.firmwareUpdater?.currentUpdate, nilValue())
        assertThat(self.changeCnt, `is`(7))
        assertThat(transientStateTester, nilValue())
    }

    func testWaitingUpdateContinuesAtReconnection() {
        firmwareStore.resetFirmwares([fwId2: fwEntry2, fwId3: fwEntry3])

        // drone with a fw version of 0.0.1 is connected
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(software: "0.0.1", hardware: ""))
        }

        assertThat(changeCnt, `is`(1))
        assertThat(firmwareUpdater!.downloadableFirmwares, contains(`is`(fwInfo2), `is`(fwInfo3)))
        assertThat(firmwareUpdater!.applicableFirmwares, empty())

        // mock fwEntry2 and fwEntry3 have been downloaded
        firmwareStore.changeRemoteFirmwareToLocal(identifier: fwId2, localUrl: URL(fileURLWithPath: "/localFile"))
        firmwareStore.changeRemoteFirmwareToLocal(identifier: fwId3, localUrl: URL(fileURLWithPath: "/localFile"))
        assertThat(changeCnt, `is`(3)) // +2 because 2 changes
        assertThat(firmwareUpdater!.downloadableFirmwares, empty())
        assertThat(firmwareUpdater!.applicableFirmwares, contains(`is`(fwInfo2), `is`(fwInfo3)))

        assertThat(firmwareUpdater?.updateToLatestFirmware(), `is`(true))
        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo2, currentProgress: 0, currentIndex: 1,
                 totalCount: 2, totalProgress: 0)))
        assertThat(changeCnt, `is`(4))

        let task = httpSession.popLastTask() as? MockUploadTask
        // mock upload completed
        task?.mock(progress: 100)
        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .processing, currentFirmware: fwInfo2, currentProgress: 100, currentIndex: 1,
                 totalCount: 2, totalProgress: 50)))
        assertThat(changeCnt, `is`(5))

        // mock completion
        task?.mockCompletion(statusCode: 200)
        // nothing should change, state .waitingForReboot happens at disconnection
        assertThat(self.firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .processing, currentFirmware: fwInfo2, currentProgress: 100, currentIndex: 1,
                 totalCount: 2, totalProgress: 50)))
        assertThat(self.changeCnt, `is`(5))

        // disconnect drone
        disconnect(drone: drone, handle: 1)

        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .waitingForReboot, currentFirmware: fwInfo2, currentProgress: 100, currentIndex: 1,
                 totalCount: 2, totalProgress: 50)))
        assertThat(changeCnt, `is`(6))

        // mock reconnection with current version is the version of fwInfo2
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(software: "2.0.0", hardware: ""))
        }

        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo3, currentProgress: 0, currentIndex: 2,
                 totalCount: 2, totalProgress: 50)))
        assertThat(changeCnt, `is`(7))

        let newTask = httpSession.popLastTask() as? MockUploadTask
        assertThat(newTask, present())
    }

    func testOngoingUpdateIsCancelOnDisconnect() {
        firmwareStore.resetFirmwares([fwId2: fwEntry2, fwId3: fwEntry3])

        // drone with a fw version of 0.0.1 is connected
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(software: "0.0.1", hardware: ""))
        }

        assertThat(changeCnt, `is`(1))
        assertThat(firmwareUpdater!.downloadableFirmwares, contains(`is`(fwInfo2), `is`(fwInfo3)))
        assertThat(firmwareUpdater!.applicableFirmwares, empty())

        // mock fwEntry2 and fwEntry3 have been downloaded
        firmwareStore.changeRemoteFirmwareToLocal(identifier: fwId2, localUrl: URL(fileURLWithPath: "/localFile"))
        firmwareStore.changeRemoteFirmwareToLocal(identifier: fwId3, localUrl: URL(fileURLWithPath: "/localFile"))
        assertThat(changeCnt, `is`(3)) // +2 because 2 changes
        assertThat(firmwareUpdater!.downloadableFirmwares, empty())
        assertThat(firmwareUpdater!.applicableFirmwares, contains(`is`(fwInfo2), `is`(fwInfo3)))

        assertThat(firmwareUpdater?.updateToLatestFirmware(), `is`(true))
        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo2, currentProgress: 0, currentIndex: 1,
                 totalCount: 2, totalProgress: 0)))
        assertThat(changeCnt, `is`(4))

        let task = httpSession.popLastTask() as? MockUploadTask

        // mock disconnection
        disconnect(drone: drone, handle: 1)

        // update should have been canceled
        assertThat(task?.cancelCalls, `is`(1))
    }

    func testOngoingUpdateFailure() {
        firmwareStore.resetFirmwares([fwId2: fwEntry2, fwId3: fwEntry3])

        // drone with a fw version of 0.0.1 is connected
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(software: "0.0.1", hardware: ""))
        }

        assertThat(changeCnt, `is`(1))
        assertThat(firmwareUpdater!.downloadableFirmwares, contains(`is`(fwInfo2), `is`(fwInfo3)))
        assertThat(firmwareUpdater!.applicableFirmwares, empty())

        // mock fwEntry2 and fwEntry3 have been downloaded
        firmwareStore.changeRemoteFirmwareToLocal(identifier: fwId2, localUrl: URL(fileURLWithPath: "/localFile"))
        firmwareStore.changeRemoteFirmwareToLocal(identifier: fwId3, localUrl: URL(fileURLWithPath: "/localFile"))
        assertThat(changeCnt, `is`(3)) // +2 because 2 changes
        assertThat(firmwareUpdater!.downloadableFirmwares, empty())
        assertThat(firmwareUpdater!.applicableFirmwares, contains(`is`(fwInfo2), `is`(fwInfo3)))

        assertThat(firmwareUpdater?.updateToLatestFirmware(), `is`(true))
        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo2, currentProgress: 0, currentIndex: 1,
                 totalCount: 2, totalProgress: 0)))
        assertThat(changeCnt, `is`(4))

        transientStateTester = {
            assertThat(self.firmwareUpdater?.currentUpdate, presentAnd(
                `is`(state: .failed, currentFirmware: self.fwInfo2, currentProgress: 0, currentIndex: 1,
                     totalCount: 2, totalProgress: 0)))
            assertThat(self.changeCnt, `is`(5))
        }

        // mock update failure
        let task = httpSession.popLastTask() as? MockUploadTask
        task?.mockCompletion(statusCode: 500)

        assertThat(self.firmwareUpdater?.currentUpdate, nilValue())
        assertThat(self.changeCnt, `is`(6))
        assertThat(transientStateTester, nilValue())
    }

    func testDroneSwitchedOffWhileUpdating() {
        firmwareStore.resetFirmwares([fwId1: fwEntry1])

        // drone with a fw version of 0.0.1 is connected
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(software: "0.0.1", hardware: ""))
        }

        assertThat(changeCnt, `is`(1))
        assertThat(firmwareUpdater!.downloadableFirmwares, contains(`is`(fwInfo1)))
        assertThat(firmwareUpdater!.applicableFirmwares, empty())

        // mock fwEntry1 has been downloaded
        firmwareStore.changeRemoteFirmwareToLocal(identifier: fwId1, localUrl: URL(fileURLWithPath: "/localFile"))
        assertThat(changeCnt, `is`(2))
        assertThat(firmwareUpdater!.downloadableFirmwares, empty())
        assertThat(firmwareUpdater!.applicableFirmwares, contains(`is`(fwInfo1)))

        assertThat(firmwareUpdater?.updateToLatestFirmware(), `is`(true))
        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo1, currentProgress: 0, currentIndex: 1,
                 totalCount: 1, totalProgress: 0)))
        assertThat(changeCnt, `is`(3))

        assertThat(firmwareUpdater?.cancelUpdate(), `is`(true))

        let task = httpSession.popLastTask() as? MockUploadTask
        task?.mock(progress: 50)

        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo1, currentProgress: 50, currentIndex: 1,
                 totalCount: 1, totalProgress: 50)))
        assertThat(changeCnt, `is`(4))

        transientStateTester = {
            assertThat(self.firmwareUpdater?.currentUpdate, presentAnd(
                `is`(state: .failed, currentFirmware: self.fwInfo1, currentProgress: 50, currentIndex: 1,
                     totalCount: 1, totalProgress: 50)))
            assertThat(self.changeCnt, `is`(5))
        }

        // mock disconnection
        disconnect(drone: drone, handle: 1)

        assertThat(self.firmwareUpdater?.currentUpdate, presentAnd(nilValue()))
        assertThat(self.changeCnt, `is`(6))
    }

    func testUnavailabilityReasonCancelsOngoingUpdate() {
        firmwareStore.resetFirmwares([fwId2: fwEntry2, fwId3: fwEntry3])

        // drone with a fw version of 0.0.1 is connected
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(software: "0.0.1", hardware: ""))
        }

        assertThat(changeCnt, `is`(1))
        assertThat(firmwareUpdater!.downloadableFirmwares, contains(`is`(fwInfo2), `is`(fwInfo3)))
        assertThat(firmwareUpdater!.applicableFirmwares, empty())

        // mock fwEntry2 and fwEntry3 have been downloaded
        firmwareStore.changeRemoteFirmwareToLocal(identifier: fwId2, localUrl: URL(fileURLWithPath: "/localFile"))
        firmwareStore.changeRemoteFirmwareToLocal(identifier: fwId3, localUrl: URL(fileURLWithPath: "/localFile"))
        assertThat(changeCnt, `is`(3)) // +2 because 2 changes
        assertThat(firmwareUpdater!.downloadableFirmwares, empty())
        assertThat(firmwareUpdater!.applicableFirmwares, contains(`is`(fwInfo2), `is`(fwInfo3)))

        assertThat(firmwareUpdater?.updateToLatestFirmware(), `is`(true))
        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo2, currentProgress: 0, currentIndex: 1,
                 totalCount: 2, totalProgress: 0)))
        assertThat(changeCnt, `is`(4))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.commonCommonstateBatterystatechangedEncoder(percent: 25))
        assertThat(changeCnt, `is`(5)) // +1 because update unavailability reasons have changed

        let task = httpSession.popLastTask() as? MockUploadTask
        assertThat(task?.cancelCalls, presentAnd(`is`(1)))

        transientStateTester = {
            assertThat(self.firmwareUpdater?.currentUpdate, presentAnd(
                `is`(state: .canceled, currentFirmware: self.fwInfo2, currentProgress: 0, currentIndex: 1,
                     totalCount: 2, totalProgress: 0)))
            assertThat(self.changeCnt, `is`(6))
        }

        task?.mock(error: NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled))

        assertThat(self.firmwareUpdater?.currentUpdate, nilValue())
        assertThat(self.changeCnt, `is`(7))
        assertThat(transientStateTester, nilValue())
    }

    func testWaitingUpdateFailsIfUnavailabilityReasonsAtConnection() {
        firmwareStore.resetFirmwares([fwId2: fwEntry2, fwId3: fwEntry3])

        // drone with a fw version of 0.0.1 is connected
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(software: "0.0.1", hardware: ""))
        }

        assertThat(changeCnt, `is`(1))
        assertThat(firmwareUpdater!.downloadableFirmwares, contains(`is`(fwInfo2), `is`(fwInfo3)))
        assertThat(firmwareUpdater!.applicableFirmwares, empty())

        // mock fwEntry2 and fwEntry3 have been downloaded
        firmwareStore.changeRemoteFirmwareToLocal(identifier: fwId2, localUrl: URL(fileURLWithPath: "/localFile"))
        firmwareStore.changeRemoteFirmwareToLocal(identifier: fwId3, localUrl: URL(fileURLWithPath: "/localFile"))
        assertThat(changeCnt, `is`(3)) // +2 because 2 changes
        assertThat(firmwareUpdater!.downloadableFirmwares, empty())
        assertThat(firmwareUpdater!.applicableFirmwares, contains(`is`(fwInfo2), `is`(fwInfo3)))

        assertThat(firmwareUpdater?.updateToLatestFirmware(), `is`(true))
        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo2, currentProgress: 0, currentIndex: 1,
                 totalCount: 2, totalProgress: 0)))
        assertThat(changeCnt, `is`(4))

        let task = httpSession.popLastTask() as? MockUploadTask
        // mock upload completed
        task?.mock(progress: 100)
        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .processing, currentFirmware: fwInfo2, currentProgress: 100, currentIndex: 1,
                 totalCount: 2, totalProgress: 50)))
        assertThat(changeCnt, `is`(5))

        // mock completion
        task?.mockCompletion(statusCode: 200)
        // nothing should change, state .waitingForReboot happens at disconnection
        assertThat(self.firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .processing, currentFirmware: fwInfo2, currentProgress: 100, currentIndex: 1,
                 totalCount: 2, totalProgress: 50)))
        assertThat(self.changeCnt, `is`(5))

        // disconnect drone
        disconnect(drone: drone, handle: 1)

        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .waitingForReboot, currentFirmware: fwInfo2, currentProgress: 100, currentIndex: 1,
                 totalCount: 2, totalProgress: 50)))
        assertThat(changeCnt, `is`(6))

        transientStateTester = {
            assertThat(self.firmwareUpdater?.currentUpdate, presentAnd(
                `is`(state: .failed, currentFirmware: self.fwInfo2, currentProgress: 100, currentIndex: 1,
                     totalCount: 2, totalProgress: 50)))
            assertThat(self.changeCnt, `is`(7))
        }

        // mock reconnection with current version is the version of fwInfo2, but battery is lower than 40%
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(software: "2.0.0", hardware: ""))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonCommonstateBatterystatechangedEncoder(percent: 25))
        }

        assertThat(firmwareUpdater?.currentUpdate, nilValue())
        assertThat(changeCnt, `is`(8))
    }

    func testFinishedUpdateSucceedsEvenIfUnavailabilityReasonsAtConnection() {
        firmwareStore.resetFirmwares([fwId1: fwEntry1])

        // drone with a fw version of 0.0.1 is connected
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(software: "0.0.1", hardware: ""))
        }

        assertThat(changeCnt, `is`(1))
        assertThat(firmwareUpdater!.downloadableFirmwares, contains(`is`(fwInfo1)))
        assertThat(firmwareUpdater!.applicableFirmwares, empty())

        // mock fwEntry1 has been downloaded
        firmwareStore.changeRemoteFirmwareToLocal(identifier: fwId1, localUrl: URL(fileURLWithPath: "/localFile"))
        assertThat(changeCnt, `is`(2))
        assertThat(firmwareUpdater!.downloadableFirmwares, empty())
        assertThat(firmwareUpdater!.applicableFirmwares, contains(`is`(fwInfo1)))

        assertThat(firmwareUpdater?.updateToLatestFirmware(), `is`(true))
        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo1, currentProgress: 0, currentIndex: 1,
                 totalCount: 1, totalProgress: 0)))
        assertThat(changeCnt, `is`(3))

        let task = httpSession.popLastTask() as? MockUploadTask

        // mock upload completed
        task?.mock(progress: 100)
        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .processing, currentFirmware: fwInfo1, currentProgress: 100, currentIndex: 1,
                 totalCount: 1, totalProgress: 100)))
        assertThat(changeCnt, `is`(4))

        // mock completion
        task?.mockCompletion(statusCode: 200)

        // nothing should change, state .waitingForReboot happens at disconnection
        assertThat(self.firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .processing, currentFirmware: fwInfo1, currentProgress: 100, currentIndex: 1,
                 totalCount: 1, totalProgress: 100)))
        assertThat(self.changeCnt, `is`(4))

        // disconnect drone
        disconnect(drone: drone, handle: 1)

        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .waitingForReboot, currentFirmware: fwInfo1, currentProgress: 100, currentIndex: 1,
                 totalCount: 1, totalProgress: 100)))
        assertThat(changeCnt, `is`(5))

        transientStateTester = {
            assertThat(self.firmwareUpdater?.currentUpdate, presentAnd(
                `is`(state: .success, currentFirmware: self.fwInfo1, currentProgress: 100, currentIndex: 1,
                     totalCount: 1, totalProgress: 100)))
            assertThat(self.changeCnt, `is`(6))
        }

        // mock reconnection with current version is the version of fwInfo1, but battery is lower than 40%
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(software: "1.0.0", hardware: ""))
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonCommonstateBatterystatechangedEncoder(percent: 25))
        }

        assertThat(firmwareUpdater?.currentUpdate, nilValue())
        assertThat(changeCnt, `is`(7))
    }
}
