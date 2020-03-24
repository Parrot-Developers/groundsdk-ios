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
@testable import ArsdkEngine
@testable import GroundSdk
import SdkCoreTesting

/// Base class for Arsdk Engine testing
class ArsdkEngineTestBase: XCTestCase {

    let droneStore = DroneStoreUtilityCore()
    let rcStore = RemoteControlStoreUtilityCore()
    var enginesController: MockEnginesController!
    var arsdkEngine: MockArsdkEngine!
    var mockArsdkCore: MockArsdkCore!
    var mockPersistentStore: MockPersistentStore!
    var firmwareStore: FirmwareStoreCoreImpl!
    let firmwareDownloader = MockFirmwareDownloader()
    var blacklistStore: BlacklistedVersionStoreCoreImpl!
    let userAccountUtility = MockUserAccountUtilityCore()
    let ephemerisUtility = MockEphemerisUtility()
    let httpSession = MockHttpSession()
    let webSocket = MockWebSocket()
    let reverseGeocoder = MockReverseGeocoder()
    let mockSystemLocation = MockSystemLocation()
    var systemePosition: SystemPositionCoreImpl!
    var systemeBarometer: SystemBarometerCoreImpl!
    let internetConnectivity = MockInternetConnectivity()

    func setGroundSdkConfig() {
        GroundSdkConfig.sharedInstance.enableCrashReport = false
        GroundSdkConfig.sharedInstance.enableFlightData = false
        GroundSdkConfig.sharedInstance.enableFlightLog = false
        GroundSdkConfig.sharedInstance.autoSelectWifiCountry = false
    }

    override func setUp() {
        super.setUp()
        setGroundSdkConfig()

        let utilities = UtilityCoreRegistry()
        utilities.publish(utility: droneStore)
        utilities.publish(utility: rcStore)
        if GroundSdkConfig.sharedInstance.enableCrashReport {
            utilities.publish(utility: MockCrashReportStorage())
        }

        if GroundSdkConfig.sharedInstance.enableFlightData {
            utilities.publish(utility: MockFlightDataStorage())
        }

        if GroundSdkConfig.sharedInstance.enableFlightLog {
            utilities.publish(utility: MockFlightLogStorage())
        }

        if GroundSdkConfig.sharedInstance.enableGutmaLog {
            utilities.publish(utility: MockGutmaLogStorage())
        }

        firmwareStore = FirmwareStoreCoreImpl()
        if GroundSdkConfig.sharedInstance.enableFirmwareSynchronization {
            firmwareStore.droneStore = droneStore
            firmwareStore.rcStore = rcStore
            utilities.publish(utility: firmwareStore)
        }
        utilities.publish(utility: firmwareDownloader)

        blacklistStore = BlacklistedVersionStoreCoreImpl()
        if GroundSdkConfig.sharedInstance.enableFirmwareSynchronization {
            utilities.publish(utility: blacklistStore)
        }

        if GroundSdkConfig.sharedInstance.enableEphemeris {
            utilities.publish(utility: ephemerisUtility)
        }

        utilities.publish(utility: reverseGeocoder)

        utilities.publish(utility: userAccountUtility)

        systemePosition = SystemPositionCoreImpl(withCustomSystemLocationObserver: mockSystemLocation)
        utilities.publish(utility: systemePosition)

        systemeBarometer = SystemBarometerCoreImpl(mockVersion: "MOCK BAROMETER")
        utilities.publish(utility: systemeBarometer)
        utilities.publish(utility: internetConnectivity)

        enginesController = MockEnginesController(
            utilityRegistry: utilities,
            facilityStore: ComponentStoreCore(),
            initEngineClosure: { engine in
                self.arsdkEngine = MockArsdkEngine(enginesController: engine)
                return [self.arsdkEngine]
        })

        mockArsdkCore = arsdkEngine.mockArsdkCore
        mockArsdkCore.testCase = self
        mockPersistentStore = arsdkEngine.mockPersistentStore

        enginesController.start()

        assertNoExpectation()
    }

    func resetArsdkEngine() {
        enginesController.stop()
        enginesController.start()
    }

    override func tearDown() {
        enginesController.stop()
    }

    func expectDateAccordingToDrone(drone: DroneCore, handle: Int16, file: String = #file, line: UInt = #line) {
        expectCommand(handle: handle, expectedCmd: ExpectedCmd.commonCommonCurrentdatetime(datetime: ""),
                      checkParams: false, file: file, line: line)
    }

    func expectCommand(handle: Int16, expectedCmd: ExpectedCmd, checkParams: Bool = true,
                       file: String = #file, line: UInt = #line) {
        mockArsdkCore.expect(CommandExpectation(
            handle: handle, expectedCmds: [expectedCmd], checkParams: checkParams, inFile: file, atLine: line))
    }

    func expectCommands(handle: Int16, expectedCmds: Set<ExpectedCmd>, checkParams: Bool = true,
                        file: String = #file, line: UInt = #line) {
        mockArsdkCore.expect(CommandExpectation(
            handle: handle, expectedCmds: expectedCmds, checkParams: checkParams, inFile: file, atLine: line))
    }

    func expectMediaList(handle: Int16, file: String = #file, line: UInt = #line) -> MediaListExpectation {
        let mediaListExpectation = MediaListExpectation(handle: handle, inFile: file, atLine: line)
        mockArsdkCore.expect(mediaListExpectation)
        return mediaListExpectation
    }

    func expectMediaDownloadThumbnail(handle: Int16, media: ArsdkMedia, file: String = #file,
                                      line: UInt = #line) -> MediaDownloadThumbnailExpectation {
        let mediaDownloadThumbnailExpectation = MediaDownloadThumbnailExpectation(
            handle: handle, andMedia: media, inFile: file, atLine: line)
        mockArsdkCore.expect(mediaDownloadThumbnailExpectation)
        return mediaDownloadThumbnailExpectation
    }

    func expectMediaDownload(handle: Int16, media: ArsdkMedia, format: ArsdkMediaResourceFormat,
                             file: String = #file, line: UInt = #line)
        -> MediaDownloadExpectation {
            let mediaDownloadExpectation = MediaDownloadExpectation(handle: handle, andMedia: media, andFormat: format,
                                                                    inFile: file, atLine: line)
            mockArsdkCore.expect(mediaDownloadExpectation)
            return mediaDownloadExpectation
    }

    func expectUpdate(handle: Int16, firmware: String, file: String = #file, line: UInt = #line) -> UpdateExpectation {
        let updateExpectation = UpdateExpectation(handle: handle, andFirmware: firmware, inFile: file, atLine: line)
        mockArsdkCore.expect(updateExpectation)
        return updateExpectation
    }

    func expectMediaDelete(handle: Int16, media: ArsdkMedia, file: String = #file, line: UInt = #line)
        -> MediaDeleteExpectation {
            let mediaDeleteExpectation = MediaDeleteExpectation(
                handle: handle, andMedia: media, inFile: file, atLine: line)
            mockArsdkCore.expect(mediaDeleteExpectation)
            return mediaDeleteExpectation
    }

    func expectFtpUpload(handle: Int16, srcPath: String, dstPath: String? = nil,
                         file: String = #file, line: UInt = #line) -> FtpUploadExpectation {
        let ftpUploadExpectation = FtpUploadExpectation(
            handle: handle, srcPath: srcPath, dstPath: dstPath, inFile: file, atLine: line)
        mockArsdkCore.expect(ftpUploadExpectation)
        return ftpUploadExpectation
    }

    func expectCrashmlDownload(handle: Int16, file: String = #file, line: UInt = #line) -> CrashmlDownloadExpectation {
        let crashmlDownloadExpectation = CrashmlDownloadExpectation(handle: handle, inFile: file, atLine: line)
        mockArsdkCore.expect(crashmlDownloadExpectation)
        return crashmlDownloadExpectation
    }

    func expectFlightLogDownload(handle: Int16, file: String = #file,
                                 line: UInt = #line) -> FlightLogDownloadExpectation {
        let flightLogDownloadExpectation = FlightLogDownloadExpectation(handle: handle, inFile: file, atLine: line)
        mockArsdkCore.expect(flightLogDownloadExpectation)
        return flightLogDownloadExpectation
    }

    func expectStreamCreate(handle: Int16, file: String = #file,
                            line: UInt = #line) -> StreamCreateExpectation {
        let streamCreateExpectation = StreamCreateExpectation(handle: handle, inFile: file, atLine: line)
        mockArsdkCore.expect(streamCreateExpectation)
        return streamCreateExpectation
    }

    func assertNoExpectation(file: String = #file, line: UInt = #line) {
        mockArsdkCore.assertNoExpectation(inFile: file, atLine: line)
    }

    func mockNonAckLoop(handle: Int16, noAckType: ArsdkNoAckCmdType, file: String = #file, line: UInt = #line) {
        mockArsdkCore.mockNonAckLoop(handle, noAckType: noAckType, inFile: file, atLine: line)
    }

    func connect(drone: DroneCore, handle: Int16, connectBlock: (() -> Void)? = nil) {
        mockArsdkCore.expect(ConnectExpectation(handle: handle, inFile: #file, atLine: #line))
        _ = drone.connect(connector: nil, password: nil)
        mockArsdkCore.deviceConnecting(handle)
        // after that the sdk is connect, we expect to send a date, time and get all settings
        expectDateAccordingToDrone(drone: drone, handle: handle)
        expectCommand(handle: handle, expectedCmd: ExpectedCmd.commonSettingsAllsettings())
        mockArsdkCore.deviceConnected(handle)
        // after connected received, re-write the http session to inject our mock http session
        if drone.model == .anafi4k {
            arsdkEngine.deviceControllers[drone.uid]!.droneServer = DroneServer(
                address: "mockAddress", port: 80, httpSession: httpSession, webSocket: webSocket)
        } else {
            arsdkEngine.deviceControllers[drone.uid]!.droneServer = nil
        }
        // after receiving the all settings ended, we expect to send the get all states
        expectCommand(handle: handle, expectedCmd: ExpectedCmd.commonCommonAllstates())
        mockArsdkCore.onCommandReceived(handle, encoder: CmdEncoder.commonSettingsstateAllsettingschangedEncoder())
        // run the bloc provided by the test that expect to be run before moving to connected state
        connectBlock?()
        // after receiving the all states ended, we expect the state to be connected
        mockArsdkCore.onCommandReceived(handle, encoder: CmdEncoder.commonCommonstateAllstateschangedEncoder())
    }

    func disconnect(drone: DroneCore, handle: Int16) {
        mockArsdkCore.expect(DisconnectExpectation(handle: handle, inFile: #file, atLine: #line))
        _ = drone.disconnect()
        mockArsdkCore.deviceDisconnected(handle, removing: false)
    }

    func connect(remoteControl: RemoteControlCore, handle: Int16, connectBlock: (() -> Void)? = nil) {
        mockArsdkCore.expect(ConnectExpectation(handle: handle, inFile: #file, atLine: #line))
        _ = remoteControl.connect(connector: nil, password: nil)
        mockArsdkCore.deviceConnecting(handle)
        // after that the sdk is connect, we expect to send a date, time and get all settings
        expectCommand(handle: handle, expectedCmd: ExpectedCmd.skyctrlCommonCurrentdatetime(datetime: ""),
                      checkParams: false)
        expectCommand(handle: handle, expectedCmd: ExpectedCmd.skyctrlSettingsAllsettings())
        mockArsdkCore.deviceConnected(handle)
        // after connected received, re-write the http session to inject our mock http session
        arsdkEngine.deviceControllers[remoteControl.uid]?.droneServer = DroneServer(
            address: "mockAddress", port: 80, httpSession: httpSession)
        // after receiving the all settings ended, we expect to send the get all states
        expectCommand(handle: handle, expectedCmd: ExpectedCmd.skyctrlCommonAllstates())
        mockArsdkCore.onCommandReceived(handle, encoder: CmdEncoder.skyctrlSettingsstateAllsettingschangedEncoder())
        // run the block provided by the test that expect to be run before moving to connected state
        connectBlock?()
        // after receiving the all states ended, we expect the state to be connected
        mockArsdkCore.onCommandReceived(handle, encoder: CmdEncoder.skyctrlCommonstateAllstateschangedEncoder())
    }

    func disconnect(remoteControl: RemoteControlCore, handle: Int16) {
        mockArsdkCore.expect(DisconnectExpectation(handle: handle, inFile: #file, atLine: #line))
        _ = remoteControl.disconnect()
        mockArsdkCore.deviceDisconnected(handle, removing: false)
    }

    func expectRemoteDroneConnection(handle: Int16, connectBlock: (() -> Void)? = nil) {
        expectCommand(handle: handle, expectedCmd: ExpectedCmd.commonSettingsAllsettings())
        // after receiving the all settings ended, we expect to send the get all states
        expectCommand(handle: handle, expectedCmd: ExpectedCmd.commonCommonAllstates())
        mockArsdkCore.onCommandReceived(handle, encoder: CmdEncoder.commonSettingsstateAllsettingschangedEncoder())
        // run the bloc provided by the test that expect to be run before moving to connected state
        connectBlock?()
        // after receiving the all states ended, we expect the state to be connected
        mockArsdkCore.onCommandReceived(handle, encoder: CmdEncoder.commonCommonstateAllstateschangedEncoder())
    }
}
