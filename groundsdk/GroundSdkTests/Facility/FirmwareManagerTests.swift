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

/// Test FirmwareManager facility
class FirmwareManagerTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: FirmwareManagerCore!
    private let backend = Backend()

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        impl = FirmwareManagerCore(store: store, backend: backend)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Facilities.firmwareManager), present())
        impl.unpublish()
        assertThat(store!.get(Facilities.firmwareManager), nilValue())
    }

    func testQueryRemoteUpdates() {
        impl.publish()
        var cnt = 0
        let firmwareManager = store.get(Facilities.firmwareManager)!
        _ = store.register(desc: Facilities.firmwareManager) {
            cnt += 1
        }

        // test initial value
        assertThat(firmwareManager.isQueryingRemoteUpdates, `is`(false))
        assertThat(cnt, `is`(0))

        // test querying from API (value should not change yet)
        assertThat(firmwareManager.queryRemoteUpdates(), `is`(true))
        assertThat(firmwareManager.isQueryingRemoteUpdates, `is`(false))
        assertThat(backend.queryCnt, `is`(1))

        // Mock value change from low-level
        impl.update(remoteQueryFlag: true).notifyUpdated()
        assertThat(firmwareManager.isQueryingRemoteUpdates, `is`(true))
        assertThat(cnt, `is`(1))

        // check that calling queryRemoteUpdates while querying, returns false without calling the backend
        assertThat(firmwareManager.queryRemoteUpdates(), `is`(false))
        assertThat(firmwareManager.isQueryingRemoteUpdates, `is`(true))
        assertThat(backend.queryCnt, `is`(1))

        // Mock same value change from low-level
        impl.update(remoteQueryFlag: true).notifyUpdated()
        assertThat(firmwareManager.isQueryingRemoteUpdates, `is`(true))
        assertThat(cnt, `is`(1))

        // Mock value change from low-level
        impl.update(remoteQueryFlag: false).notifyUpdated()
        assertThat(firmwareManager.isQueryingRemoteUpdates, `is`(false))
        assertThat(cnt, `is`(2))
    }

    func testFirmwares() {
        let localUrl = URL(fileURLWithPath: NSHomeDirectory().appending("fwFile"), isDirectory: false)
        let anafi = DeviceModel.drone(.anafi4k)

        let fwId1 = FirmwareIdentifier(deviceModel: anafi, version: FirmwareVersion.parse(versionStr: "1.0.0")!)
        let fwId2 = FirmwareIdentifier(deviceModel: anafi, version: FirmwareVersion.parse(versionStr: "2.0.0")!)
        let fwId3 = FirmwareIdentifier(deviceModel: anafi, version: FirmwareVersion.parse(versionStr: "3.0.0")!)

        let fwInfo1 = FirmwareInfoCore(firmwareIdentifier: fwId1, attributes: [], size: 20, checksum: "")
        let fwInfo2 = FirmwareInfoCore(firmwareIdentifier: fwId2, attributes: [], size: 20, checksum: "")
        let fwInfo3 = FirmwareInfoCore(firmwareIdentifier: fwId3, attributes: [.deletesUserData], size: 20,
                                       checksum: "")

        let fwEntry1 = FirmwareStoreEntry(firmware: fwInfo1, localUrl: localUrl, embedded: true)
        let fwEntry2 = FirmwareStoreEntry(firmware: fwInfo2, localUrl: localUrl, embedded: false)
        let fwEntry3 = FirmwareStoreEntry(firmware: fwInfo3, remoteUrl: URL(string: "http://remote"),
                                          requiredVersion: fwId2.version, embedded: false)

        impl.publish()
        var cnt = 0
        let firmwareManager = store.get(Facilities.firmwareManager)!
        _ = store.register(desc: Facilities.firmwareManager) {
            cnt += 1
        }

        // test initial value
        assertThat(firmwareManager.firmwares, empty())
        assertThat(cnt, `is`(0))

        // mock new firmware list from low-level
        impl.update(entries: [fwEntry2, fwEntry3]).notifyUpdated()

        assertThat(firmwareManager.firmwares, containsInAnyOrder(
            `is`(firmwareInfo: fwInfo2, state: .downloaded, progress: 0, canDelete: true),
            `is`(firmwareInfo: fwInfo3, state: .notDownloaded, progress: 0, canDelete: false)))
        assertThat(cnt, `is`(1))

        // mock firmware list changed from low-level
        impl.update(entries: [fwEntry1, fwEntry2, fwEntry3]).notifyUpdated()
        assertThat(firmwareManager.firmwares, containsInAnyOrder(
            `is`(firmwareInfo: fwInfo1, state: .downloaded, progress: 0, canDelete: false),
            `is`(firmwareInfo: fwInfo2, state: .downloaded, progress: 0, canDelete: true),
            `is`(firmwareInfo: fwInfo3, state: .notDownloaded, progress: 0, canDelete: false)))
        assertThat(cnt, `is`(2))

        // mock update with same values
        impl.update(entries: [fwEntry1, fwEntry2, fwEntry3]).notifyUpdated()
        assertThat(firmwareManager.firmwares, containsInAnyOrder(
            `is`(firmwareInfo: fwInfo1, state: .downloaded, progress: 0, canDelete: false),
            `is`(firmwareInfo: fwInfo2, state: .downloaded, progress: 0, canDelete: true),
            `is`(firmwareInfo: fwInfo3, state: .notDownloaded, progress: 0, canDelete: false)))
        assertThat(cnt, `is`(2))
    }

    func testDownloadEntry() {
        let anafi = DeviceModel.drone(.anafi4k)
        let fwId1 = FirmwareIdentifier(deviceModel: anafi, version: FirmwareVersion.parse(versionStr: "1.0.0")!)
        let fwInfo1 = FirmwareInfoCore(firmwareIdentifier: fwId1, attributes: [], size: 20, checksum: "")
        let fwEntry1 = FirmwareStoreEntry(firmware: fwInfo1, remoteUrl: URL(string: "http://remote"), embedded: false)

        impl.update(entries: [fwEntry1])
        impl.publish()
        var cnt = 0
        let firmwareManager = store.get(Facilities.firmwareManager)!
        _ = store.register(desc: Facilities.firmwareManager) {
            cnt += 1
        }

        // test initial value
        assertThat(firmwareManager.firmwares, contains(
            `is`(firmwareInfo: fwInfo1, state: .notDownloaded, progress: 0, canDelete: false)))
        assertThat(cnt, `is`(0))

        // download entry
        assertThat(firmwareManager.firmwares.first?.download(), `is`(true))
        assertThat(backend.downloadCnt, `is`(1))

        // mock download started
        backend.downloadTask?.state = .downloading
        backend.downloadTask?.requested = [fwInfo1]
        backend.downloadTask?.remaining = [fwInfo1]
        backend.downloadTask?.currentProgress = 0
        backend.downloadObserver?(backend.downloadTask!)

        assertThat(firmwareManager.firmwares, contains(
            `is`(firmwareInfo: fwInfo1, state: .downloading, progress: 0, canDelete: false)))
        assertThat(cnt, `is`(1))

        // mock download progress
        backend.downloadTask?.currentProgress = 50
        backend.downloadObserver?(backend.downloadTask!)

        assertThat(firmwareManager.firmwares, contains(
            `is`(firmwareInfo: fwInfo1, state: .downloading, progress: 50, canDelete: false)))
        assertThat(cnt, `is`(2))

        // mock download succeed
        backend.downloadTask?.state = .success
        backend.downloadTask?.remaining = []
        backend.downloadTask?.currentProgress = 100
        backend.downloadObserver?(backend.downloadTask!)

        // firmware will be erased, an update of the firmware store will update its state.
        // TODO: see in which order it will be done.
        assertThat(firmwareManager.firmwares, contains(
            `is`(firmwareInfo: fwInfo1, state: .notDownloaded, progress: 0, canDelete: false)))
        assertThat(cnt, `is`(3))

        let localFwEntry1 = FirmwareStoreEntry(
            firmware: fwInfo1,
            localUrl: URL(fileURLWithPath: NSHomeDirectory().appending("fwFile"), isDirectory: false),
            embedded: false)
        // mock update of firmware downloaded from low level
        impl.update(entries: [localFwEntry1]).notifyUpdated()
        assertThat(firmwareManager.firmwares, contains(
            `is`(firmwareInfo: fwInfo1, state: .downloaded, progress: 0, canDelete: true)))
        assertThat(cnt, `is`(4))

        // try to download a local firmware should fail (backend should not be called)
        assertThat(firmwareManager.firmwares.first?.download(), `is`(false))
        assertThat(backend.downloadCnt, `is`(1))
    }

    func testDelete() {
        let localUrl = URL(fileURLWithPath: NSHomeDirectory().appending("fwFile"), isDirectory: false)
        let anafi = DeviceModel.drone(.anafi4k)

        let fwId1 = FirmwareIdentifier(deviceModel: anafi, version: FirmwareVersion.parse(versionStr: "1.0.0")!)
        let fwId2 = FirmwareIdentifier(deviceModel: anafi, version: FirmwareVersion.parse(versionStr: "2.0.0")!)
        let fwId3 = FirmwareIdentifier(deviceModel: anafi, version: FirmwareVersion.parse(versionStr: "3.0.0")!)

        let fwInfo1 = FirmwareInfoCore(firmwareIdentifier: fwId1, attributes: [], size: 20, checksum: "")
        let fwInfo2 = FirmwareInfoCore(firmwareIdentifier: fwId2, attributes: [], size: 20, checksum: "")
        let fwInfo3 = FirmwareInfoCore(firmwareIdentifier: fwId3, attributes: [.deletesUserData], size: 20,
                                       checksum: "")

        let fwEntry1 = FirmwareStoreEntry(firmware: fwInfo1, localUrl: localUrl, embedded: false)
        let fwEntry2 = FirmwareStoreEntry(firmware: fwInfo2, localUrl: localUrl, embedded: true)
        let fwEntry3 = FirmwareStoreEntry(firmware: fwInfo3, remoteUrl: URL(string: "http://remote"),
                                          requiredVersion: fwId2.version, embedded: false)

        impl.update(entries: [fwEntry3])
        impl.publish()
        var cnt = 0
        let firmwareManager = store.get(Facilities.firmwareManager)!
        _ = store.register(desc: Facilities.firmwareManager) {
            cnt += 1
        }

        // test initial value
        assertThat(firmwareManager.firmwares, containsInAnyOrder(
            `is`(firmwareInfo: fwInfo3, state: .notDownloaded, progress: 0, canDelete: false)))
        assertThat(cnt, `is`(0))

        // trying to delete a non-local firmware should fail (backend should not be called)
        assertThat(firmwareManager.firmwares.first?.delete(), `is`(false))
        assertThat(backend.deleteCnt, `is`(0))

        // change firmware entries
        impl.update(entries: [fwEntry2]).notifyUpdated()
        assertThat(firmwareManager.firmwares, containsInAnyOrder(
            `is`(firmwareInfo: fwInfo2, state: .downloaded, progress: 0, canDelete: false)))
        assertThat(cnt, `is`(1))

        // trying to delete a embedded firmware should fail (backend should not be called)
        assertThat(firmwareManager.firmwares.first?.delete(), `is`(false))
        assertThat(backend.deleteCnt, `is`(0))

        // change firmware entries
        impl.update(entries: [fwEntry1]).notifyUpdated()
        assertThat(firmwareManager.firmwares, containsInAnyOrder(
            `is`(firmwareInfo: fwInfo1, state: .downloaded, progress: 0, canDelete: true)))
        assertThat(cnt, `is`(2))

        // Delete firmware
        assertThat(firmwareManager.firmwares.first?.delete(), `is`(true))
        assertThat(backend.deleteCnt, `is`(1))
    }
}

private class Backend: FirmwareManagerBackend {
    private(set) var queryCnt = 0
    private(set) var downloadCnt = 0
    private(set) var downloadTask: MockFirmwareDownloaderCoreTask?
    private(set) var downloadObserver: ((FirmwareDownloaderCoreTask) -> Void)?
    private(set) var deleteCnt = 0

    func queryRemoteUpdateInfos() -> Bool {
        queryCnt += 1
        return true
    }

    func download(firmware: FirmwareInfoCore, observer: @escaping (FirmwareDownloaderCoreTask) -> Void) {
        downloadCnt += 1
        downloadTask = MockFirmwareDownloaderCoreTask(requested: [firmware])
        downloadObserver = observer
    }

    func delete(firmware: FirmwareInfoCore) -> Bool {
        deleteCnt += 1
        return true
    }
}
