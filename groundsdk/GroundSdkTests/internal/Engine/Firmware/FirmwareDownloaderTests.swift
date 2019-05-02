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

class FirmwareDownloaderTests: XCTestCase {

    /*var updateManagerRef: Ref<UpdateManager>!
    var updateManager: UpdateManager?
    var changeCnt = 0

    let httpSession = MockHttpSession()
    let droneStore = DroneStoreUtilityCore()
    let rcStore = RemoteControlStoreUtilityCore()*/
    let firmwareStore = FirmwareStoreCoreImpl(gsdkUserdefaults: MockGroundSdkUserDefaults("tests"))

    private let fwId1 = FirmwareIdentifier(
        deviceModel: .drone(.anafi4k), version: FirmwareVersion.parse(versionStr: "1.0.0")!)

    private var fwInfo1: FirmwareInfoCore!
    private let fwInfo2 = FirmwareInfoCore(
        firmwareIdentifier: FirmwareIdentifier(
            deviceModel: .drone(.anafi4k), version: FirmwareVersion.parse(versionStr: "2.0.0")!),
        attributes: [], size: 300, checksum: "")

    private var fwEntry1: FirmwareStoreEntry!

    //private var impl = FirmwareDownloaderCoreImpl!
    private var downloader: FirmwareDownloaderCore!

    // need to be retained (normally retained by the EnginesController)
    private let utilityRegistry = UtilityCoreRegistry()
    private let facilityStore = ComponentStoreCore()
    private var enginesController: MockEnginesController!

    private var engine: FirmwareEngine!

    override func setUp() {
        super.setUp()

        //utilityRegistry.publish(utility: firmwareStore)

        enginesController = MockEnginesController(
            utilityRegistry: utilityRegistry,
            facilityStore: facilityStore,
            initEngineClosure: {
                self.engine = FirmwareEngine(enginesController: $0)
                return [self.engine]

        })

        /*updateManagerRef = ComponentRefCore(
            store: facilityStore,
            desc: Facilities.updateManager) { [unowned self] updateManager in
                self.updateManager = updateManager
                self.changeCnt += 1
        }*/
        fwInfo1 = FirmwareInfoCore(firmwareIdentifier: fwId1, attributes: [], size: 100, checksum: "")
        fwEntry1 = FirmwareStoreEntry(firmware: fwInfo1, remoteUrl: URL(string: "http://remote"), embedded: false)
    }

    func testTaskIsNilIfAnyUnknownFirmware() {
        // mock store only knows fwEntry1
        firmwareStore.resetFirmwares([fwId1: fwEntry1])

        // should fail since FIRMWARES[1] is unknown
        //downloader.download(firmwares: [fwInfo1, fwInfo2]) { _ in }
        //assertThat(, )

    }

    // TODO: test the engine
}
