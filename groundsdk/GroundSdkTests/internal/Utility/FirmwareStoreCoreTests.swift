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
@testable import GroundSdkMock
@testable import GroundSdk

class FirmwareStoreCoreTests: XCTestCase {

    let store = FirmwareStoreCoreImpl(gsdkUserdefaults: MockGroundSdkUserDefaults("mockFirmwareStore"))

    var monitor: MonitorCore!
    var changeCnt = 0

    let localUrl = URL(fileURLWithPath: NSHomeDirectory().appending("/fwFile"), isDirectory: false)

    let fwId1 = FirmwareIdentifier(deviceModel: .drone(.anafi4k), version: FirmwareVersion.parse(versionStr: "1.0.0")!)
    let fwId2 = FirmwareIdentifier(deviceModel: .drone(.anafi4k), version: FirmwareVersion.parse(versionStr: "2.0.0")!)
    let fwId3 = FirmwareIdentifier(deviceModel: .drone(.anafi4k), version: FirmwareVersion.parse(versionStr: "3.0.0")!)
    let fwId4 = FirmwareIdentifier(deviceModel: .drone(.anafi4k), version: FirmwareVersion.parse(versionStr: "4.0.0")!)
    let fwId5 = FirmwareIdentifier(deviceModel: .drone(.anafi4k), version: FirmwareVersion.parse(versionStr: "5.0.0")!)

    var fwIdTrampoline: FirmwareIdentifier! // alias of fwId3
    var fwIdIntermediate: FirmwareIdentifier! // alias of fwId4
    var fwIdLatest: FirmwareIdentifier! // alias of fwId5

    var fwInfo1: FirmwareInfoCore!
    var fwInfo2: FirmwareInfoCore!
    var fwInfoTrampoline: FirmwareInfoCore!
    var fwInfoIntermediate: FirmwareInfoCore!
    var fwInfoLatest: FirmwareInfoCore!

    var trampoline: FirmwareStoreEntry!
    var intermediate: FirmwareStoreEntry!
    var latest: FirmwareStoreEntry!

    override func setUp() {
        super.setUp()

        monitor = store.startMonitoring { [unowned self] in
            self.changeCnt += 1
        }

        fwIdTrampoline = fwId3
        fwIdIntermediate = fwId4
        fwIdLatest = fwId5

        // populate the firmware store
        fwInfo1 = FirmwareInfoCore(firmwareIdentifier: fwId1, attributes: [], size: 20, checksum: "")
        fwInfo2 = FirmwareInfoCore(firmwareIdentifier: fwId2, attributes: [], size: 20, checksum: "")
        fwInfoTrampoline = FirmwareInfoCore(
            firmwareIdentifier: fwIdTrampoline, attributes: [], size: 20, checksum: "")
        fwInfoIntermediate = FirmwareInfoCore(
            firmwareIdentifier: fwIdIntermediate, attributes: [], size: 20, checksum: "")
        fwInfoLatest = FirmwareInfoCore(firmwareIdentifier: fwIdLatest, attributes: [], size: 20, checksum: "")

        // trampoline can only be applied on a v1 firmware
        trampoline = FirmwareStoreEntry(firmware: fwInfoTrampoline, remoteUrl: URL(string: "http://remote"),
                                        requiredVersion: fwId1.version, maxVersion: fwId1.version, embedded: false)
        // intermediate can be applied on a firmware >= than v2
        intermediate = FirmwareStoreEntry(firmware: fwInfoIntermediate, remoteUrl: URL(string: "http://remote"),
                                          requiredVersion: fwId2.version, embedded: false)
        // latest can be applied on a firmware >= than v2
        latest = FirmwareStoreEntry(firmware: fwInfoLatest, remoteUrl: URL(string: "http://remote"),
                                      requiredVersion: fwId2.version, embedded: false)
    }

    func testLocalFirmwaresWithLocalTrampoline() {
        // make trampoline and latest local
        trampoline.localUrl = localUrl
        latest.localUrl = localUrl
        store.resetFirmwares([fwIdIntermediate: trampoline,
                              fwIdLatest: latest])

        assertThat(store.getLatestFirmwareEntries(from: fwId1).toIdentifiers(), contains(fwIdTrampoline, fwIdLatest))
        assertThat(store.getLatestFirmwareEntries(from: fwId2).toIdentifiers(), contains(fwIdLatest))
        assertThat(store.getLatestFirmwareEntries(from: fwId3).toIdentifiers(), contains(fwIdLatest))
        assertThat(store.getLatestFirmwareEntries(from: fwId4).toIdentifiers(), contains(fwIdLatest))
        assertThat(store.getLatestFirmwareEntries(from: fwId5).toIdentifiers(), empty())

        assertThat(store.getApplicableFirmwares(on: fwId1), contains(fwInfoTrampoline, fwInfoLatest))
        assertThat(store.getApplicableFirmwares(on: fwId2), contains(fwInfoLatest))
        assertThat(store.getApplicableFirmwares(on: fwId3), contains(fwInfoLatest))
        assertThat(store.getApplicableFirmwares(on: fwId4), contains(fwInfoLatest))
        assertThat(store.getApplicableFirmwares(on: fwId5), empty())

        assertThat(store.getDownloadableFirmwares(for: fwId1), empty())
        assertThat(store.getDownloadableFirmwares(for: fwId2), empty())
        assertThat(store.getDownloadableFirmwares(for: fwId3), empty())
        assertThat(store.getDownloadableFirmwares(for: fwId4), empty())
        assertThat(store.getDownloadableFirmwares(for: fwId5), empty())

        assertThat(store.getIdealFirmware(for: fwId1), `is`(fwInfoLatest))
        assertThat(store.getIdealFirmware(for: fwId2), `is`(fwInfoLatest))
        assertThat(store.getIdealFirmware(for: fwId3), `is`(fwInfoLatest))
        assertThat(store.getIdealFirmware(for: fwId4), `is`(fwInfoLatest))
        assertThat(store.getIdealFirmware(for: fwId5), nilValue())
    }

    func testLocalFirmwaresWithRemoteTrampoline() {
        // make latest local
        latest.localUrl = localUrl
        store.resetFirmwares([fwIdIntermediate: trampoline,
                              fwIdLatest: latest])

        assertThat(store.getLatestFirmwareEntries(from: fwId1).toIdentifiers(), contains(fwIdTrampoline, fwIdLatest))
        assertThat(store.getLatestFirmwareEntries(from: fwId2).toIdentifiers(), contains(fwIdLatest))
        assertThat(store.getLatestFirmwareEntries(from: fwId3).toIdentifiers(), contains(fwIdLatest))
        assertThat(store.getLatestFirmwareEntries(from: fwId4).toIdentifiers(), contains(fwIdLatest))
        assertThat(store.getLatestFirmwareEntries(from: fwId5).toIdentifiers(), empty())

        assertThat(store.getApplicableFirmwares(on: fwId1), empty())
        assertThat(store.getApplicableFirmwares(on: fwId2), contains(fwInfoLatest))
        assertThat(store.getApplicableFirmwares(on: fwId3), contains(fwInfoLatest))
        assertThat(store.getApplicableFirmwares(on: fwId4), contains(fwInfoLatest))
        assertThat(store.getApplicableFirmwares(on: fwId5), empty())

        assertThat(store.getDownloadableFirmwares(for: fwId1), contains(fwInfoTrampoline))
        assertThat(store.getDownloadableFirmwares(for: fwId2), empty())
        assertThat(store.getDownloadableFirmwares(for: fwId3), empty())
        assertThat(store.getDownloadableFirmwares(for: fwId4), empty())
        assertThat(store.getDownloadableFirmwares(for: fwId5), empty())

        assertThat(store.getIdealFirmware(for: fwId1), `is`(fwInfoLatest))
        assertThat(store.getIdealFirmware(for: fwId2), `is`(fwInfoLatest))
        assertThat(store.getIdealFirmware(for: fwId3), `is`(fwInfoLatest))
        assertThat(store.getIdealFirmware(for: fwId4), `is`(fwInfoLatest))
        assertThat(store.getIdealFirmware(for: fwId5), nilValue())
    }

    func testRemoveUnnecessaryFirmwaresAfterDownload() {
        // add to the store the drone that we want to update
        let droneStore = DroneStoreUtilityCore()
        let existingDrone = MockDrone(uid: "drone1", model: .anafi4k)
        existingDrone.mockFirmwareVersion(fwId1.version)
        droneStore.add(existingDrone)
        store.droneStore = droneStore

        // attributes contains a modification date set in 2001 to avoid keeping the firmware because it has just been
        // created
        let attributes = [FileAttributeKey.modificationDate: NSDate(timeIntervalSinceReferenceDate: 0)]

        // check initial state
        assertThat(changeCnt, `is`(1)) // 1 because start monitoring directly calls the monitor
        assertThat(store.firmwares, empty())

        store.resetFirmwares([fwIdTrampoline: trampoline,
                              fwIdIntermediate: intermediate])

        assertThat(store.getLatestFirmwareEntries(from: fwId1).toIdentifiers(),
                   `is`([fwIdTrampoline, fwIdIntermediate]))
        assertThat(store.firmwares.map { $0.value }, containsInAnyOrder(
            allOf(`is`(version: "3.0.0"), `is`(forModel: .drone(.anafi4k)), isDistantOnly()),
            allOf(`is`(version: "4.0.0"), `is`(forModel: .drone(.anafi4k)), isDistantOnly())))

        // mock trampoline downloaded
        let fwTrampolineLocalUrl = localUrl.appendingPathExtension("3.0.0.puf")
        try? FileManager.default.createDirectory(
            at: fwTrampolineLocalUrl.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        FileManager.default.createFile(atPath: fwTrampolineLocalUrl.path, contents: nil, attributes: attributes)
        store.changeRemoteFirmwareToLocal(identifier: fwIdTrampoline, localUrl: fwTrampolineLocalUrl)
        assertThat(store.getLatestFirmwareEntries(from: fwId1).toIdentifiers(),
                   `is`([fwIdTrampoline, fwIdIntermediate]))
        assertThat(store.firmwares.map { $0.value }, containsInAnyOrder(
            allOf(`is`(version: "3.0.0"), `is`(forModel: .drone(.anafi4k)), isLocal()),
            allOf(`is`(version: "4.0.0"), `is`(forModel: .drone(.anafi4k)), isDistantOnly())))

        // mock intermediary downloaded
        let fwIntermediateLocalUrl = localUrl.appendingPathExtension("4.0.0.puf")
        try? FileManager.default.createDirectory(
            at: fwIntermediateLocalUrl.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        FileManager.default.createFile(atPath: fwIntermediateLocalUrl.path, contents: nil, attributes: attributes)
        store.changeRemoteFirmwareToLocal(identifier: fwId4, localUrl: fwIntermediateLocalUrl)
        assertThat(store.getLatestFirmwareEntries(from: fwId1).toIdentifiers(),
                   `is`([fwIdTrampoline, fwIdIntermediate]))
        assertThat(store.firmwares.map { $0.value }, containsInAnyOrder(
            allOf(`is`(version: "3.0.0"), `is`(forModel: .drone(.anafi4k)), isLocal()),
            allOf(`is`(version: "4.0.0"), `is`(forModel: .drone(.anafi4k)), isLocal())))

        // mock drone has been updated to 3.0.0 (trampoline is no longer required)
        existingDrone.mockFirmwareVersion(fwId3.version)
        // explicitely call removeUnnecessaryFirmwares to simulate an app reboot
        store.removeAllUnnecessaryFirmwares()
        assertThat(store.getLatestFirmwareEntries(from: fwId3).toIdentifiers(), `is`([fwIdIntermediate]))
        assertThat(store.firmwares.map { $0.value }, containsInAnyOrder(
            allOf(`is`(version: "3.0.0"), `is`(forModel: .drone(.anafi4k)), isDistantOnly()),
            allOf(`is`(version: "4.0.0"), `is`(forModel: .drone(.anafi4k)), isLocal())))

        // mock new distant firmware added
        store.mergeRemoteFirmwares([fwIdTrampoline: trampoline,
                                    fwIdIntermediate: intermediate,
                                    fwIdLatest: latest])
        assertThat(store.getLatestFirmwareEntries(from: fwId3).toIdentifiers(), `is`([fwIdLatest]))
        assertThat(store.firmwares.map { $0.value }, containsInAnyOrder(
            allOf(`is`(version: "3.0.0"), `is`(forModel: .drone(.anafi4k)), isDistantOnly()),
            allOf(`is`(version: "4.0.0"), `is`(forModel: .drone(.anafi4k)), isLocal()),
            allOf(`is`(version: "5.0.0"), `is`(forModel: .drone(.anafi4k)), isDistantOnly())))

        // check that removing unnecessary firmwares here does not remove the latest local firmware
        store.removeAllUnnecessaryFirmwares()
        assertThat(store.getLatestFirmwareEntries(from: fwId3).toIdentifiers(), `is`([fwIdLatest]))
        assertThat(store.firmwares.map { $0.value }, containsInAnyOrder(
            allOf(`is`(version: "3.0.0"), `is`(forModel: .drone(.anafi4k)), isDistantOnly()),
            allOf(`is`(version: "4.0.0"), `is`(forModel: .drone(.anafi4k)), isLocal()),
            allOf(`is`(version: "5.0.0"), `is`(forModel: .drone(.anafi4k)), isDistantOnly())))

        // mock latest downloaded
        let fwLatestLocalUrl = localUrl.appendingPathExtension("5.0.0.puf")
        try? FileManager.default.createDirectory(
            at: fwLatestLocalUrl.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        FileManager.default.createFile(atPath: fwLatestLocalUrl.path, contents: nil, attributes: attributes)
        store.changeRemoteFirmwareToLocal(identifier: fwId5, localUrl: fwLatestLocalUrl)
        assertThat(store.getLatestFirmwareEntries(from: fwId3).toIdentifiers(), `is`([fwIdLatest]))
        assertThat(store.firmwares.map { $0.value }, containsInAnyOrder(
            allOf(`is`(version: "3.0.0"), `is`(forModel: .drone(.anafi4k)), isDistantOnly()),
            allOf(`is`(version: "4.0.0"), `is`(forModel: .drone(.anafi4k)), isDistantOnly()),
            allOf(`is`(version: "5.0.0"), `is`(forModel: .drone(.anafi4k)), isLocal())))

        // mock drone back to a version below the trampoline
        existingDrone.mockFirmwareVersion(fwId1.version)
        // explicitely call removeUnnecessaryFirmwares to simulate an app reboot
        store.removeAllUnnecessaryFirmwares()
        assertThat(store.getLatestFirmwareEntries(from: fwId1).toIdentifiers(), `is`([fwIdTrampoline, fwId5]))
        // firmware 5 should be deleted because the drone cannot be updated to firmware 5 directly (i.e. with local
        // firmwares only).
        // This can be fixed later by improving the way we chose unnecessary firmwares
        assertThat(store.firmwares.map { $0.value }, containsInAnyOrder(
            allOf(`is`(version: "3.0.0"), `is`(forModel: .drone(.anafi4k)), isDistantOnly()),
            allOf(`is`(version: "4.0.0"), `is`(forModel: .drone(.anafi4k)), isDistantOnly()),
            allOf(`is`(version: "5.0.0"), `is`(forModel: .drone(.anafi4k)), isDistantOnly())))

        // make same test with a firmware that has just been downloaded (i.e. do not override modification date)
        try? FileManager.default.createDirectory(
            at: fwLatestLocalUrl.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        FileManager.default.createFile(atPath: fwLatestLocalUrl.path, contents: nil, attributes: nil)

        store.changeRemoteFirmwareToLocal(identifier: fwId5, localUrl: fwLatestLocalUrl)
        assertThat(store.getLatestFirmwareEntries(from: fwId1).toIdentifiers(), `is`([fwIdTrampoline, fwId5]))
        // firmware 5 should not deleted because it has been downloaded less than a day ago
        assertThat(store.firmwares.map { $0.value }, containsInAnyOrder(
            allOf(`is`(version: "3.0.0"), `is`(forModel: .drone(.anafi4k)), isDistantOnly()),
            allOf(`is`(version: "4.0.0"), `is`(forModel: .drone(.anafi4k)), isDistantOnly()),
            allOf(`is`(version: "5.0.0"), `is`(forModel: .drone(.anafi4k)), isLocal())))
    }
}

extension Sequence where Iterator.Element == FirmwareStoreEntry {
    func toIdentifiers() -> [FirmwareIdentifier] {
        return self.map { $0.firmware.firmwareIdentifier }
    }
}
