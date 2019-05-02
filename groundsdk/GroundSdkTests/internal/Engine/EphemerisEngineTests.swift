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

class EphemerisEngineTests: XCTestCase {
    let internetConnectivity = MockInternetConnectivity()

    let httpSession = MockHttpSession()
    let gsdkUserDefaults = MockGroundSdkUserDefaults("mockEphemeris")

    // need to be retained (normally retained by the EnginesController)
    private var utilityRegistry = UtilityCoreRegistry()
    private var enginesController: MockEnginesController!

    private var engine: MockEphemerisEngine!

    override func setUp() {
        super.setUp()

        enginesController = MockEnginesController(
            utilityRegistry: utilityRegistry,
            facilityStore: ComponentStoreCore(),
            initEngineClosure: {
                self.engine = MockEphemerisEngine(
                    enginesController: $0, httpSession: self.httpSession, gsdkUserDefaults: self.gsdkUserDefaults)
                return [self.engine]
        })

        utilityRegistry.publish(utility: internetConnectivity)
    }

    override func tearDown() {
        GroundSdkConfig.sharedInstance.enableEphemeris = true
    }

    // test if ephemeris download works
    func testEphemerisDownloadSucceed() {
        internetConnectivity.mockInternetAvailable = false

        enginesController.start()

        // No request should be issued yet since there is no internet
        assertThat(httpSession.popLastTask(), nilValue())

        // mock internet available (a download request for the ublox ephemeris should be issued)
        internetConnectivity.mockInternetAvailable = true

        let task = httpSession.popLastTask() as? MockDownloadTask
        assertThat(task, present())

        // mock task is completed with success (mock file is created)
        try? FileManager.default.createDirectory(at: task!.destination.deletingPathExtension(),
                                                 withIntermediateDirectories: true, attributes: nil)
        FileManager.default.createFile(atPath: task!.destination.path, contents: nil, attributes: nil)
        task?.mockCompletionSuccess(localFileUrl: task!.destination)

        // check that the file at the temp place has been moved to its final destination
        let fileUrl = engine.rootFolder.appendingPathComponent("ublox")
        assertThat(FileManager.default.fileExists(atPath: fileUrl.path), `is`(true))

        // check that the ephemeris file url is correct
        assertThat(engine.getLatestEphemeris(forType: .ublox), `is`(fileUrl))

        // mock internet is not available then available again
        internetConnectivity.mockInternetAvailable = false
        internetConnectivity.mockInternetAvailable = true

        // check that no new request is issued since the last one has been done less than 48hours ago
        assertThat(httpSession.popLastTask(), nilValue())
        assertThat(utilityRegistry.getUtility(Utilities.ephemeris), present())

    }

    // test if ephemeris are downloaded when ephemeris config is disabled
    func testEphemerisDownloadIfEphemerisDisable() {

        GroundSdkConfig.sharedInstance.enableEphemeris = false

        // Override default setup to take in account the config
        utilityRegistry = UtilityCoreRegistry()
        enginesController = MockEnginesController(
            utilityRegistry: utilityRegistry,
            facilityStore: ComponentStoreCore(),
            initEngineClosure: {
                self.engine = MockEphemerisEngine(
                    enginesController: $0, httpSession: self.httpSession, gsdkUserDefaults: self.gsdkUserDefaults)
                return [self.engine]
        })
        utilityRegistry.publish(utility: internetConnectivity)

        internetConnectivity.mockInternetAvailable = false

        enginesController.start()
        // No request should be issued yet since there is no internet
        assertThat(httpSession.popLastTask(), nilValue())

        // mock internet available (a download request for the ublox ephemeris should be issued)
        internetConnectivity.mockInternetAvailable = true

        let task = httpSession.popLastTask() as? MockDownloadTask
        assertThat(task, nilValue())

        // check if utility Ephemeris is nil
        assertThat(utilityRegistry.getUtility(Utilities.ephemeris), nilValue())
    }
}
