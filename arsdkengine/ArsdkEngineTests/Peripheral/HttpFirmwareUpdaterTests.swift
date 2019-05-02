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

class HttpFirmwareUpdaterTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var firmwareUpdater: Updater?
    var firmwareUpdaterRef: Ref<Updater>?
    var changeCnt = 0

    var localUrl = URL(fileURLWithPath: "fwFile", isDirectory: false)
    let fwId1 = FirmwareIdentifier(deviceModel: .drone(.anafi4k), version: FirmwareVersion.parse(versionStr: "1.0.0")!)
    var fwInfo1: FirmwareInfoCore!
    var fwEntry1: FirmwareStoreEntry!

    var transientStateTester: (() -> Void)?

    override func setUp() {
        super.setUp()

        // create a fake local firmware
        fwInfo1 = FirmwareInfoCore(firmwareIdentifier: fwId1, attributes: [], size: 20, checksum: "")
        fwEntry1 = FirmwareStoreEntry(firmware: fwInfo1, localUrl: localUrl, embedded: false)

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

        // mock applicable firmwares in store
        firmwareStore.resetFirmwares([fwId1: fwEntry1])

        // drone with a fw version of 0.0.1 is connected
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.commonSettingsstateProductversionchangedEncoder(software: "0.0.1", hardware: ""))
        }

        // request an update
        _ = firmwareUpdater?.updateToNextFirmware()

        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo1, currentProgress: 0, currentIndex: 1,
                 totalCount: 1, totalProgress: 0)))

        changeCnt = 0
    }

    func testUpdateProgress() {
        let task = httpSession.popLastTask() as? MockUploadTask

        // mock progress
        task?.mock(progress: 50)

        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .uploading, currentFirmware: fwInfo1, currentProgress: 50, currentIndex: 1,
                 totalCount: 1, totalProgress: 50)))
        assertThat(changeCnt, `is`(1))
    }

    func testUpdateSuccess() {
        let task = httpSession.popLastTask() as? MockUploadTask

        // mock processing
        task?.mock(progress: 100)

        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .processing, currentFirmware: fwInfo1, currentProgress: 100, currentIndex: 1,
                 totalCount: 1, totalProgress: 100)))
        assertThat(changeCnt, `is`(1))

        // mock success
        task?.mockCompletion(statusCode: 200)

        // nothing should change until disconnect
        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .processing, currentFirmware: fwInfo1, currentProgress: 100, currentIndex: 1,
                 totalCount: 1, totalProgress: 100)))
        assertThat(changeCnt, `is`(1))

        // disconnect drone
        disconnect(drone: drone, handle: 1)

        assertThat(firmwareUpdater?.currentUpdate, presentAnd(
            `is`(state: .waitingForReboot, currentFirmware: fwInfo1, currentProgress: 100, currentIndex: 1,
                 totalCount: 1, totalProgress: 100)))
        assertThat(changeCnt, `is`(2))
    }

    func testUpdateFailure() {
        let task = httpSession.popLastTask() as? MockUploadTask

        transientStateTester = {
            assertThat(self.firmwareUpdater?.currentUpdate, presentAnd(
                `is`(state: .failed, currentFirmware: self.fwInfo1, currentProgress: 0, currentIndex: 1,
                     totalCount: 1, totalProgress: 0)))
            assertThat(self.changeCnt, `is`(1))
        }

        // mock progress
        task?.mockCompletion(statusCode: 500)

        assertThat(firmwareUpdater?.currentUpdate, nilValue())
        assertThat(changeCnt, `is`(2))
    }

    func testUpdateCancel() {
        let task = httpSession.popLastTask() as? MockUploadTask

        transientStateTester = {
            assertThat(self.firmwareUpdater?.currentUpdate, presentAnd(
                `is`(state: .canceled, currentFirmware: self.fwInfo1, currentProgress: 0, currentIndex: 1,
                     totalCount: 1, totalProgress: 0)))
            assertThat(self.changeCnt, `is`(1))
        }

        // mock progress
        task?.mock(error: NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled))

        assertThat(firmwareUpdater?.currentUpdate, nilValue())
        assertThat(changeCnt, `is`(2))
    }
}
