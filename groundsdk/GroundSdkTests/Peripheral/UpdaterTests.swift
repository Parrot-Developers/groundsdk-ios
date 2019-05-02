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

import XCTest
@testable import GroundSdk

/// Test Updater peripheral
class UpdaterTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: UpdaterCore!
    private var backend: Backend!

    private let fwInfo1 = FirmwareInfoCore(
        firmwareIdentifier: FirmwareIdentifier(
            deviceModel: .drone(.anafi4k), version: FirmwareVersion.parse(versionStr: "1.0.0")!),
        attributes: [], size: 100, checksum: "")
    private let fwInfo2 = FirmwareInfoCore(
        firmwareIdentifier: FirmwareIdentifier(
            deviceModel: .drone(.anafi4k), version: FirmwareVersion.parse(versionStr: "2.0.0")!),
        attributes: [], size: 300, checksum: "")

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = UpdaterCore(store: store!, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.updater), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.updater), nilValue())
    }

    func testDownloadableFirmwares() {
        impl.publish()

        var cnt = 0
        let firmwareUpdater = store.get(Peripherals.updater)!
        _ = store.register(desc: Peripherals.updater) {
            cnt += 1
        }

        // check initial value
        assertThat(cnt, `is`(0))
        assertThat(firmwareUpdater.downloadableFirmwares, empty())

        // mock update from low level (values should update)
        impl.update(downloadableFirmwares: [fwInfo1]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(firmwareUpdater.downloadableFirmwares, contains(`is`(fwInfo1)))

        // mock same update from low level (nothing should change)
        impl.update(downloadableFirmwares: [fwInfo1]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(firmwareUpdater.downloadableFirmwares, contains(`is`(fwInfo1)))

        // mock update from low level
        impl.update(downloadableFirmwares: [fwInfo1, fwInfo2])
        // check no changes are published before notification
        assertThat(cnt, `is`(1))

        // mock second update from low-level
        impl.update(downloadableFirmwares: [fwInfo2, fwInfo1]).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(firmwareUpdater.downloadableFirmwares, contains(`is`(fwInfo2), `is`(fwInfo1)))
    }

    func testApplicableFirmwares() {
        impl.publish()

        var cnt = 0
        let firmwareUpdater = store.get(Peripherals.updater)!
        _ = store.register(desc: Peripherals.updater) {
            cnt += 1
        }

        // check initial value
        assertThat(cnt, `is`(0))
        assertThat(firmwareUpdater.applicableFirmwares, empty())

        // mock update from low level (values should update)
        impl.update(applicableFirmwares: [fwInfo1]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(firmwareUpdater.applicableFirmwares, contains(`is`(fwInfo1)))

        // mock same update from low level (nothing should change)
        impl.update(applicableFirmwares: [fwInfo1]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(firmwareUpdater.applicableFirmwares, contains(`is`(fwInfo1)))

        // mock update from low level
        impl.update(applicableFirmwares: [fwInfo1, fwInfo2])
        // check no changes are published before notification
        assertThat(cnt, `is`(1))

        // mock second update from low-level
        impl.update(applicableFirmwares: [fwInfo2, fwInfo1]).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(firmwareUpdater.applicableFirmwares, contains(`is`(fwInfo2), `is`(fwInfo1)))
    }

    func testDownloadUnavailabilityReasons() {
        impl.publish()

        var cnt = 0
        let firmwareUpdater = store.get(Peripherals.updater)!
        _ = store.register(desc: Peripherals.updater) {
            cnt += 1
        }

        // check initial value
        assertThat(cnt, `is`(0))
        assertThat(firmwareUpdater.downloadUnavailabilityReasons, empty())

        // mock update from low level (values should update)
        impl.update(downloadUnavailabilityReasons: [.internetUnavailable]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(firmwareUpdater.downloadUnavailabilityReasons, contains(.internetUnavailable))

        // mock same update from low level (nothing should change)
        impl.update(downloadUnavailabilityReasons: [.internetUnavailable]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(firmwareUpdater.downloadUnavailabilityReasons, contains(.internetUnavailable))
    }

    func testUpdateUnavailabilityReasons() {
        impl.publish()

        var cnt = 0
        let firmwareUpdater = store.get(Peripherals.updater)!
        _ = store.register(desc: Peripherals.updater) {
            cnt += 1
        }

        // check initial value
        assertThat(cnt, `is`(0))
        assertThat(firmwareUpdater.updateUnavailabilityReasons, empty())

        // mock update from low level (values should update)
        impl.update(updateUnavailabilityReasons: [.notConnected]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(firmwareUpdater.updateUnavailabilityReasons, contains(.notConnected))

        // mock same update from low level (nothing should change)
        impl.update(updateUnavailabilityReasons: [.notConnected]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(firmwareUpdater.updateUnavailabilityReasons, contains(.notConnected))

        // mock update from low level
        impl.update(updateUnavailabilityReasons: [.notConnected, .notEnoughBattery])
        // check no changes are published before notification
        assertThat(cnt, `is`(1))

        // mock second update from low-level
        impl.update(updateUnavailabilityReasons: []).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(firmwareUpdater.updateUnavailabilityReasons, empty())
    }

    func testIsUpToDate() {
        impl.publish()

        var cnt = 0
        let firmwareUpdater = store.get(Peripherals.updater)!
        _ = store.register(desc: Peripherals.updater) {
            cnt += 1
        }

        // check initial value
        assertThat(cnt, `is`(0))
        assertThat(firmwareUpdater.isUpToDate, `is`(true))
        assertThat(firmwareUpdater.downloadableFirmwares, empty())
        assertThat(firmwareUpdater.applicableFirmwares, empty())

        // mock downloadable firmwares from low-level (should not be up to date anymore)
        impl.update(downloadableFirmwares: [fwInfo1]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(firmwareUpdater.isUpToDate, `is`(false))
        assertThat(firmwareUpdater.downloadableFirmwares, contains(`is`(fwInfo1)))
        assertThat(firmwareUpdater.applicableFirmwares, empty())

        // mock applicable firmwares from low-level (should still not be up to date)
        impl.update(applicableFirmwares: [fwInfo1]).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(firmwareUpdater.isUpToDate, `is`(false))
        assertThat(firmwareUpdater.downloadableFirmwares, contains(`is`(fwInfo1)))
        assertThat(firmwareUpdater.applicableFirmwares, contains(`is`(fwInfo1)))

        // mock all firmwares downloaded from low-level
        impl.update(downloadableFirmwares: []).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(firmwareUpdater.isUpToDate, `is`(false))
        assertThat(firmwareUpdater.downloadableFirmwares, empty())
        assertThat(firmwareUpdater.applicableFirmwares, contains(`is`(fwInfo1)))

        // mock all firmwares applied from low-level (should be up to date after that)
        impl.update(applicableFirmwares: []).notifyUpdated()
        assertThat(cnt, `is`(4))
        assertThat(firmwareUpdater.isUpToDate, `is`(true))
        assertThat(firmwareUpdater.downloadableFirmwares, empty())
        assertThat(firmwareUpdater.applicableFirmwares, empty())
    }

    func testIdealVersion() {
        impl.publish()

        var cnt = 0
        let firmwareUpdater = store.get(Peripherals.updater)!
        _ = store.register(desc: Peripherals.updater) {
            cnt += 1
        }

        let version = FirmwareVersion.parse(versionStr: "1.0.0")!

        // check initial value
        assertThat(cnt, `is`(0))
        assertThat(firmwareUpdater.idealVersion, nilValue())

        // mock update from low level (values should update)
        impl.update(idealVersion: version).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(firmwareUpdater.idealVersion, presentAnd(`is`(version)))

        // mock same update from low level (nothing should change)
        impl.update(idealVersion: version).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(firmwareUpdater.idealVersion, presentAnd(`is`(version)))

        // mock second update from low-level
        impl.update(idealVersion: nil).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(firmwareUpdater.idealVersion, nilValue())
    }

    func testDownloadNextFirmware() {
        impl.publish()

        var transientStateTester: (() -> Void)?

        var cnt = 0
        let firmwareUpdater = store.get(Peripherals.updater)!
        _ = store.register(desc: Peripherals.updater) {
            cnt += 1
            if let tester = transientStateTester {
                tester()
                transientStateTester = nil
            }
        }

        // check initial value
        assertThat(cnt, `is`(0))
        assertThat(firmwareUpdater.downloadableFirmwares, empty())
        assertThat(firmwareUpdater.currentDownload, nilValue())

        // test cannot cancel since there is no ongoing download
        assertThat(firmwareUpdater.cancelDownload(), `is`(false))

        // test cannot download since there are no downloadable firmwares
        assertThat(firmwareUpdater.downloadNextFirmware(), `is`(false))
        assertThat(backend.downloadCnt, `is`(0))

        // mock some downloadable firmwares
        impl.update(downloadableFirmwares: [fwInfo1, fwInfo2]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(firmwareUpdater.downloadableFirmwares, contains(`is`(fwInfo1), `is`(fwInfo2)))
        assertThat(firmwareUpdater.currentDownload, nilValue())

        // request download
        assertThat(firmwareUpdater.downloadNextFirmware(), `is`(true))
        assertThat(backend.downloadCnt, `is`(1))
        assertThat(backend.firmwaresToDownload, presentAnd(containsInAnyOrder(fwInfo1)))
        // current download should remain null until the task callbacks
        assertThat(firmwareUpdater.currentDownload, nilValue())

        // mock the task
        backend.downloadTask?.state = .downloading
        backend.downloadTask?.requested = [fwInfo1]
        backend.downloadTask?.remaining = [fwInfo1]
        backend.downloadTask?.currentProgress = 0
        backend.downloadObserver?(backend.downloadTask!)

        assertThat(cnt, `is`(2))
        assertThat(firmwareUpdater.currentDownload, presentAnd(
            `is`(state: .downloading, currentFirmware: fwInfo1, currentProgress: 0, currentIndex: 1,
                 totalCount: 1, totalProgress: 0)))

        // test another download request is rejected since a download is ongoing
        assertThat(firmwareUpdater.downloadNextFirmware(), `is`(false))
        assertThat(firmwareUpdater.downloadAllFirmwares(), `is`(false))
        assertThat(backend.downloadCnt, `is`(1))

        // mock task progress
        backend.downloadTask?.currentProgress = 50
        backend.downloadObserver?(backend.downloadTask!)

        assertThat(cnt, `is`(3))
        assertThat(firmwareUpdater.currentDownload, presentAnd(
            `is`(state: .downloading, currentFirmware: fwInfo1, currentProgress: 50, currentIndex: 1,
                 totalCount: 1, totalProgress: 50)))

        // mock task success
        backend.downloadTask?.state = .success
        backend.downloadTask?.remaining = []
        backend.downloadTask?.currentProgress = 100
        backend.downloadObserver?(backend.downloadTask!)

        transientStateTester = {
            assertThat(cnt, `is`(4))
            assertThat(firmwareUpdater.currentDownload, presentAnd(
                `is`(state: .success, currentFirmware: self.fwInfo1, currentProgress: 100, currentIndex: 1,
                     totalCount: 1, totalProgress: 100)))
        }

        assertThat(cnt, `is`(5))
        assertThat(firmwareUpdater.currentDownload, nilValue())
    }

    func testDownloadAllFirmwares() {
        impl.publish()

        var transientStateTester: (() -> Void)?

        var cnt = 0
        let firmwareUpdater = store.get(Peripherals.updater)!
        _ = store.register(desc: Peripherals.updater) {
            cnt += 1
            if let tester = transientStateTester {
                tester()
                transientStateTester = nil
            }
        }

        // check initial value
        assertThat(cnt, `is`(0))
        assertThat(firmwareUpdater.downloadableFirmwares, empty())
        assertThat(firmwareUpdater.currentDownload, nilValue())

        // test cannot cancel since there is no ongoing download
        assertThat(firmwareUpdater.cancelDownload(), `is`(false))

        // test cannot download since there are no downloadable firmwares
        assertThat(firmwareUpdater.downloadAllFirmwares(), `is`(false))
        assertThat(backend.downloadCnt, `is`(0))

        // mock some downloadable firmwares
        impl.update(downloadableFirmwares: [fwInfo1, fwInfo2]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(firmwareUpdater.downloadableFirmwares, contains(`is`(fwInfo1), `is`(fwInfo2)))
        assertThat(firmwareUpdater.currentDownload, nilValue())

        // request download
        assertThat(firmwareUpdater.downloadAllFirmwares(), `is`(true))
        assertThat(backend.downloadCnt, `is`(1))
        assertThat(backend.firmwaresToDownload, presentAnd(containsInAnyOrder(fwInfo1, fwInfo2)))
        // current download should remain null until the task callbacks
        assertThat(firmwareUpdater.currentDownload, nilValue())

        // mock the task
        backend.downloadTask?.state = .downloading
        backend.downloadTask?.requested = [fwInfo1, fwInfo2]
        backend.downloadTask?.remaining = [fwInfo1, fwInfo2]
        backend.downloadTask?.currentProgress = 0
        backend.downloadObserver?(backend.downloadTask!)

        assertThat(cnt, `is`(2))
        assertThat(firmwareUpdater.currentDownload, presentAnd(
            `is`(state: .downloading, currentFirmware: fwInfo1, currentProgress: 0, currentIndex: 1,
                 totalCount: 2, totalProgress: 0)))

        // test another download request is rejected since a download is ongoing
        assertThat(firmwareUpdater.downloadNextFirmware(), `is`(false))
        assertThat(firmwareUpdater.downloadAllFirmwares(), `is`(false))
        assertThat(backend.downloadCnt, `is`(1))

        // mock task progress
        backend.downloadTask?.currentProgress = 50
        backend.downloadObserver?(backend.downloadTask!)

        assertThat(cnt, `is`(3))
        assertThat(firmwareUpdater.currentDownload, presentAnd(
            `is`(state: .downloading, currentFirmware: fwInfo1, currentProgress: 50, currentIndex: 1,
                 totalCount: 2, totalProgress: 13))) // 13 is 12.5 rounded

        // mock download succeed, next firmware download has started
        backend.downloadTask?.remaining = [fwInfo2]
        backend.downloadTask?.currentProgress = 0
        backend.downloadObserver?(backend.downloadTask!)

        assertThat(cnt, `is`(4))
        assertThat(firmwareUpdater.currentDownload, presentAnd(
            `is`(state: .downloading, currentFirmware: fwInfo2, currentProgress: 0, currentIndex: 2,
                 totalCount: 2, totalProgress: 25)))

        // mock task progress
        backend.downloadTask?.currentProgress = 50
        backend.downloadObserver?(backend.downloadTask!)

        assertThat(cnt, `is`(5))
        assertThat(firmwareUpdater.currentDownload, presentAnd(
            `is`(state: .downloading, currentFirmware: fwInfo2, currentProgress: 50, currentIndex: 2,
                 totalCount: 2, totalProgress: 63))) // 63 is 62.5 rounded (100 + 300 / 2) / 400

        // prepare the transient state tester
        transientStateTester = {
            assertThat(cnt, `is`(6))
            assertThat(firmwareUpdater.currentDownload, presentAnd(
                `is`(state: .success, currentFirmware: self.fwInfo2, currentProgress: 100, currentIndex: 2,
                     totalCount: 2, totalProgress: 100)))
        }

        // mock task success
        backend.downloadTask?.state = .success
        backend.downloadTask?.remaining = []
        backend.downloadTask?.currentProgress = 100
        backend.downloadObserver?(backend.downloadTask!)

        assertThat(cnt, `is`(7))
        assertThat(firmwareUpdater.currentDownload, nilValue())
        assertThat(transientStateTester, nilValue())
    }

    func testDownloadFailure() {
        // mock some downloadable firmwares
        impl.update(downloadableFirmwares: [fwInfo1, fwInfo2]).notifyUpdated()
        impl.publish()

        var transientStateTester: (() -> Void)?

        var cnt = 0
        let firmwareUpdater = store.get(Peripherals.updater)!
        _ = store.register(desc: Peripherals.updater) {
            cnt += 1
            if let tester = transientStateTester {
                tester()
                transientStateTester = nil
            }
        }

        // check initial value
        assertThat(cnt, `is`(0))
        assertThat(firmwareUpdater.downloadableFirmwares, contains(`is`(fwInfo1), `is`(fwInfo2)))
        assertThat(firmwareUpdater.currentDownload, nilValue())

        // request download
        assertThat(firmwareUpdater.downloadNextFirmware(), `is`(true))
        assertThat(backend.downloadCnt, `is`(1))
        assertThat(backend.firmwaresToDownload, presentAnd(containsInAnyOrder(fwInfo1)))
        // current download should remain null until the task callbacks
        assertThat(firmwareUpdater.currentDownload, nilValue())
        assertThat(cnt, `is`(0))

        // mock the task
        backend.downloadTask?.state = .downloading
        backend.downloadTask?.requested = [fwInfo1]
        backend.downloadTask?.remaining = [fwInfo1]
        backend.downloadTask?.currentProgress = 0
        backend.downloadObserver?(backend.downloadTask!)

        assertThat(cnt, `is`(1))
        assertThat(firmwareUpdater.currentDownload, presentAnd(
            `is`(state: .downloading, currentFirmware: fwInfo1, currentProgress: 0, currentIndex: 1,
                 totalCount: 1, totalProgress: 0)))

        // mock task progress
        backend.downloadTask?.currentProgress = 50
        backend.downloadObserver?(backend.downloadTask!)

        assertThat(cnt, `is`(2))
        assertThat(firmwareUpdater.currentDownload, presentAnd(
            `is`(state: .downloading, currentFirmware: fwInfo1, currentProgress: 50, currentIndex: 1,
                 totalCount: 1, totalProgress: 50)))

        // prepare the transient state tester
        transientStateTester = {
            assertThat(cnt, `is`(3))
            assertThat(firmwareUpdater.currentDownload, presentAnd(
                `is`(state: .failed, currentFirmware: self.fwInfo1, currentProgress: 0, currentIndex: 1,
                     totalCount: 1, totalProgress: 0)))
        }

        // mock failure
        backend.downloadTask?.state = .failed
        backend.downloadTask?.currentProgress = 0
        backend.downloadObserver?(backend.downloadTask!)

        assertThat(cnt, `is`(4))
        assertThat(firmwareUpdater.currentDownload, nilValue())
        assertThat(transientStateTester, nilValue())
    }

    func testDownloadCancel() {
        // mock some downloadable firmwares
        impl.update(downloadableFirmwares: [fwInfo1, fwInfo2]).notifyUpdated()
        impl.publish()

        var transientStateTester: (() -> Void)?

        var cnt = 0
        let firmwareUpdater = store.get(Peripherals.updater)!
        _ = store.register(desc: Peripherals.updater) {
            cnt += 1
            if let tester = transientStateTester {
                tester()
                transientStateTester = nil
            }
        }

        // check initial value
        assertThat(cnt, `is`(0))
        assertThat(firmwareUpdater.downloadableFirmwares, contains(`is`(fwInfo1), `is`(fwInfo2)))
        assertThat(firmwareUpdater.currentDownload, nilValue())

        // request download
        assertThat(firmwareUpdater.downloadNextFirmware(), `is`(true))
        assertThat(backend.downloadCnt, `is`(1))
        assertThat(backend.firmwaresToDownload, presentAnd(containsInAnyOrder(fwInfo1)))
        // current download should remain null until the task callbacks
        assertThat(firmwareUpdater.currentDownload, nilValue())
        assertThat(cnt, `is`(0))

        // mock the task
        backend.downloadTask?.state = .downloading
        backend.downloadTask?.requested = [fwInfo1]
        backend.downloadTask?.remaining = [fwInfo1]
        backend.downloadTask?.currentProgress = 0
        backend.downloadObserver?(backend.downloadTask!)

        assertThat(cnt, `is`(1))
        assertThat(firmwareUpdater.currentDownload, presentAnd(
            `is`(state: .downloading, currentFirmware: fwInfo1, currentProgress: 0, currentIndex: 1,
                 totalCount: 1, totalProgress: 0)))

        // mock task progress
        backend.downloadTask?.currentProgress = 50
        backend.downloadObserver?(backend.downloadTask!)

        assertThat(cnt, `is`(2))
        assertThat(firmwareUpdater.currentDownload, presentAnd(
            `is`(state: .downloading, currentFirmware: fwInfo1, currentProgress: 50, currentIndex: 1,
                 totalCount: 1, totalProgress: 50)))

        assertThat(firmwareUpdater.cancelDownload(), `is`(true))
        assertThat(backend.downloadTask!.cancelCnt, `is`(1))
        assertThat(cnt, `is`(2)) // nothing should change for the moment

        // prepare the transient state tester
        transientStateTester = {
            assertThat(cnt, `is`(3))
            assertThat(firmwareUpdater.currentDownload, presentAnd(
                `is`(state: .canceled, currentFirmware: self.fwInfo1, currentProgress: 0, currentIndex: 1,
                     totalCount: 1, totalProgress: 0)))
        }

        // mock failure
        backend.downloadTask?.state = .canceled
        backend.downloadTask?.currentProgress = 0
        backend.downloadObserver?(backend.downloadTask!)

        assertThat(cnt, `is`(4))
        assertThat(firmwareUpdater.currentDownload, nilValue())
        assertThat(transientStateTester, nilValue())
    }

    func testUpdateToNextFirmware() {
        impl.publish()

        var cnt = 0
        let firmwareUpdater = store.get(Peripherals.updater)!
        _ = store.register(desc: Peripherals.updater) {
            cnt += 1
        }

        // check initial value
        assertThat(cnt, `is`(0))
        assertThat(firmwareUpdater.applicableFirmwares, empty())
        assertThat(firmwareUpdater.currentUpdate, nilValue())

        // test cannot cancel since there is no ongoing update
        assertThat(firmwareUpdater.cancelUpdate(), `is`(false))

        // test cannot update since there are no applicable firmwares
        assertThat(firmwareUpdater.updateToNextFirmware(), `is`(false))
        assertThat(backend.updateCnt, `is`(0))

        // mock some applicable firmwares
        impl.update(applicableFirmwares: [fwInfo1, fwInfo2]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(firmwareUpdater.applicableFirmwares, contains(`is`(fwInfo1), `is`(fwInfo2)))
        assertThat(firmwareUpdater.currentUpdate, nilValue())

        // request update
        assertThat(firmwareUpdater.updateToNextFirmware(), `is`(true))
        assertThat(backend.updateCnt, `is`(1))
        assertThat(backend.firmwaresToUpdateWith, presentAnd(containsInAnyOrder(fwInfo1)))
        // current update should remain null until the task callbacks
        assertThat(firmwareUpdater.currentUpdate, nilValue())

        // mock update begin
        impl.beginUpdate(withFirmwares: [fwInfo1]).notifyUpdated()

        assertThat(cnt, `is`(2))
        assertThat(firmwareUpdater.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo1, currentProgress: 0, currentIndex: 1,
                 totalCount: 1, totalProgress: 0)))

        // test another download request is rejected since a download is ongoing
        assertThat(firmwareUpdater.updateToNextFirmware(), `is`(false))
        assertThat(firmwareUpdater.updateToLatestFirmware(), `is`(false))
        assertThat(backend.updateCnt, `is`(1))

        // mock task progress
        impl.update(uploadProgress: 50).notifyUpdated()

        assertThat(cnt, `is`(3))
        assertThat(firmwareUpdater.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo1, currentProgress: 50, currentIndex: 1,
                 totalCount: 1, totalProgress: 50)))

        // mock processing firmware
        impl.update(uploadProgress: 100).update(updateState: .processing).notifyUpdated()

        assertThat(cnt, `is`(4))
        assertThat(firmwareUpdater.currentUpdate, presentAnd(
            `is`(state: .processing, currentFirmware: fwInfo1, currentProgress: 100, currentIndex: 1,
                 totalCount: 1, totalProgress: 100)))

        // mock waiting for reboot
        impl.update(updateState: .waitingForReboot).notifyUpdated()
        assertThat(cnt, `is`(5))
        assertThat(firmwareUpdater.currentUpdate, presentAnd(
            `is`(state: .waitingForReboot, currentFirmware: fwInfo1, currentProgress: 100, currentIndex: 1,
                 totalCount: 1, totalProgress: 100)))

        // mock task success
        impl.update(updateState: .success).notifyUpdated()
        assertThat(cnt, `is`(6))
        assertThat(firmwareUpdater.currentUpdate, presentAnd(
            `is`(state: .success, currentFirmware: fwInfo1, currentProgress: 100, currentIndex: 1,
                 totalCount: 1, totalProgress: 100)))

        // mock task end
        impl.endUpdate().notifyUpdated()
        assertThat(cnt, `is`(7))
        assertThat(firmwareUpdater.currentUpdate, nilValue())
    }

    func testUpdateToLatestFirmware() {
        impl.publish()

        var cnt = 0
        let firmwareUpdater = store.get(Peripherals.updater)!
        _ = store.register(desc: Peripherals.updater) {
            cnt += 1
        }

        // check initial value
        assertThat(cnt, `is`(0))
        assertThat(firmwareUpdater.applicableFirmwares, empty())
        assertThat(firmwareUpdater.currentUpdate, nilValue())

        // test cannot cancel since there is no ongoing update
        assertThat(firmwareUpdater.cancelUpdate(), `is`(false))

        // test cannot update since there are no applicable firmwares
        assertThat(firmwareUpdater.updateToLatestFirmware(), `is`(false))
        assertThat(backend.updateCnt, `is`(0))

        // mock some applicable firmwares
        impl.update(applicableFirmwares: [fwInfo1, fwInfo2]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(firmwareUpdater.applicableFirmwares, contains(`is`(fwInfo1), `is`(fwInfo2)))
        assertThat(firmwareUpdater.currentUpdate, nilValue())

        // request update
        assertThat(firmwareUpdater.updateToLatestFirmware(), `is`(true))
        assertThat(backend.updateCnt, `is`(1))
        assertThat(backend.firmwaresToUpdateWith, presentAnd(containsInAnyOrder(fwInfo1, fwInfo2)))
        // current update should remain null until the task callbacks
        assertThat(firmwareUpdater.currentUpdate, nilValue())

        // mock update begin
        impl.beginUpdate(withFirmwares: [fwInfo1, fwInfo2]).notifyUpdated()

        assertThat(cnt, `is`(2))
        assertThat(firmwareUpdater.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo1, currentProgress: 0, currentIndex: 1,
                 totalCount: 2, totalProgress: 0)))

        // test another download request is rejected since a download is ongoing
        assertThat(firmwareUpdater.updateToNextFirmware(), `is`(false))
        assertThat(firmwareUpdater.updateToLatestFirmware(), `is`(false))
        assertThat(backend.updateCnt, `is`(1))

        // mock task progress
        impl.update(uploadProgress: 50).notifyUpdated()

        assertThat(cnt, `is`(3))
        assertThat(firmwareUpdater.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo1, currentProgress: 50, currentIndex: 1,
                 totalCount: 2, totalProgress: 13)))

        // mock processing firmware
        impl.update(uploadProgress: 100).update(updateState: .processing).notifyUpdated()

        assertThat(cnt, `is`(4))
        assertThat(firmwareUpdater.currentUpdate, presentAnd(
            `is`(state: .processing, currentFirmware: fwInfo1, currentProgress: 100, currentIndex: 1,
                 totalCount: 2, totalProgress: 25)))

        // mock waiting for reboot
        impl.update(updateState: .waitingForReboot).notifyUpdated()
        assertThat(cnt, `is`(5))
        assertThat(firmwareUpdater.currentUpdate, presentAnd(
            `is`(state: .waitingForReboot, currentFirmware: fwInfo1, currentProgress: 100, currentIndex: 1,
                 totalCount: 2, totalProgress: 25)))

        // mock next firmware update begins
        impl.continueUpdate().notifyUpdated()
        assertThat(cnt, `is`(6))
        assertThat(firmwareUpdater.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo2, currentProgress: 0, currentIndex: 2,
                 totalCount: 2, totalProgress: 25)))

        // mock processing firmware
        impl.update(uploadProgress: 50).notifyUpdated()
        assertThat(cnt, `is`(7))
        assertThat(firmwareUpdater.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo2, currentProgress: 50, currentIndex: 2,
                 totalCount: 2, totalProgress: 63)))

        // mock task success
        impl.update(updateState: .success).update(uploadProgress: 100).notifyUpdated()
        assertThat(cnt, `is`(8))
        assertThat(firmwareUpdater.currentUpdate, presentAnd(
            `is`(state: .success, currentFirmware: fwInfo2, currentProgress: 100, currentIndex: 2,
                 totalCount: 2, totalProgress: 100)))

        // mock task end
        impl.endUpdate().notifyUpdated()
        assertThat(cnt, `is`(9))
        assertThat(firmwareUpdater.currentUpdate, nilValue())
    }

    func testUpdateFailure() {
        impl.update(applicableFirmwares: [fwInfo1])
        impl.publish()

        var cnt = 0
        let firmwareUpdater = store.get(Peripherals.updater)!
        _ = store.register(desc: Peripherals.updater) {
            cnt += 1
        }

        // check initial value
        assertThat(cnt, `is`(0))
        assertThat(firmwareUpdater.applicableFirmwares, contains(`is`(fwInfo1)))
        assertThat(firmwareUpdater.currentUpdate, nilValue())

        // request update
        assertThat(firmwareUpdater.updateToLatestFirmware(), `is`(true))
        assertThat(backend.updateCnt, `is`(1))
        assertThat(backend.firmwaresToUpdateWith, presentAnd(containsInAnyOrder(fwInfo1)))
        // current update should remain null until the task callbacks
        assertThat(firmwareUpdater.currentUpdate, nilValue())

        // mock update begin
        impl.beginUpdate(withFirmwares: [fwInfo1]).notifyUpdated()

        assertThat(cnt, `is`(1))
        assertThat(firmwareUpdater.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo1, currentProgress: 0, currentIndex: 1,
                 totalCount: 1, totalProgress: 0)))

        // mock task progress
        impl.update(uploadProgress: 50).notifyUpdated()

        assertThat(cnt, `is`(2))
        assertThat(firmwareUpdater.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo1, currentProgress: 50, currentIndex: 1,
                 totalCount: 1, totalProgress: 50)))

        // mock task failed
        impl.update(updateState: .failed).update(uploadProgress: 0).notifyUpdated()

        assertThat(cnt, `is`(3))
        assertThat(firmwareUpdater.currentUpdate, presentAnd(
            `is`(state: .failed, currentFirmware: fwInfo1, currentProgress: 0, currentIndex: 1,
                 totalCount: 1, totalProgress: 0)))

        // mock task end
        impl.endUpdate().notifyUpdated()

        assertThat(cnt, `is`(4))
        assertThat(firmwareUpdater.currentUpdate, nilValue())
    }

    func testUpdateCancel() {
        impl.update(applicableFirmwares: [fwInfo1])
        impl.publish()

        var cnt = 0
        let firmwareUpdater = store.get(Peripherals.updater)!
        _ = store.register(desc: Peripherals.updater) {
            cnt += 1
        }

        // check initial value
        assertThat(cnt, `is`(0))
        assertThat(firmwareUpdater.applicableFirmwares, contains(`is`(fwInfo1)))
        assertThat(firmwareUpdater.currentUpdate, nilValue())

        // request update
        assertThat(firmwareUpdater.updateToLatestFirmware(), `is`(true))
        assertThat(backend.updateCnt, `is`(1))
        assertThat(backend.firmwaresToUpdateWith, presentAnd(containsInAnyOrder(fwInfo1)))
        // current update should remain null until the task callbacks
        assertThat(firmwareUpdater.currentUpdate, nilValue())

        // mock update begin
        impl.beginUpdate(withFirmwares: [fwInfo1]).notifyUpdated()

        assertThat(cnt, `is`(1))
        assertThat(firmwareUpdater.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo1, currentProgress: 0, currentIndex: 1,
                 totalCount: 1, totalProgress: 0)))

        // mock task progress
        impl.update(uploadProgress: 50).notifyUpdated()

        assertThat(cnt, `is`(2))
        assertThat(firmwareUpdater.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo1, currentProgress: 50, currentIndex: 1,
                 totalCount: 1, totalProgress: 50)))

        // cancel task
        assertThat(firmwareUpdater.cancelUpdate(), `is`(true))
        assertThat(backend.cancelUpdateCount, `is`(1))
        assertThat(cnt, `is`(2)) // nothing should change for the moment

        // mock task canceled
        impl.update(updateState: .canceled).update(uploadProgress: 0).notifyUpdated()

        assertThat(cnt, `is`(3))
        assertThat(firmwareUpdater.currentUpdate, presentAnd(
            `is`(state: .canceled, currentFirmware: fwInfo1, currentProgress: 0, currentIndex: 1,
                 totalCount: 1, totalProgress: 0)))

        // mock task end
        impl.endUpdate().notifyUpdated()

        assertThat(cnt, `is`(4))
        assertThat(firmwareUpdater.currentUpdate, nilValue())
    }
}

private class Backend: UpdaterBackend {
    private(set) var downloadCnt = 0
    private(set) var firmwaresToDownload: [FirmwareInfoCore]?
    private(set) var firmwaresToUpdateWith: [FirmwareInfoCore]?
    private(set) var downloadTask: MockFirmwareDownloaderCoreTask?
    private(set) var downloadObserver: ((FirmwareDownloaderCoreTask) -> Void)?
    private(set) var updateCnt = 0
    private(set) var cancelUpdateCount = 0

    func download(firmwares: [FirmwareInfoCore], observer: @escaping (FirmwareDownloaderCoreTask) -> Void) {
        downloadCnt += 1
        firmwaresToDownload = firmwares
        downloadTask = MockFirmwareDownloaderCoreTask(requested: firmwares)
        downloadObserver = observer
    }

    func update(withFirmwares firmwares: [FirmwareInfoCore]) {
        updateCnt += 1
        firmwaresToUpdateWith = firmwares
    }

    func cancelUpdate() {
        cancelUpdateCount += 1
    }
}
