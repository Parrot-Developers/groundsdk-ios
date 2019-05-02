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
import GroundSdk
@testable import ArsdkEngine
import SdkCoreTesting

class EphemerisUploaderTests: ArsdkEngineTestBase {

    var drone: DroneCore!

    var ephemerisUploader: EphemerisUploader?

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!
    }

    func testUploadWhenEphemerisIsPresent() {
        ephemerisUtility.mockLatestEphemerisUrl = URL(
            fileURLWithPath: NSHomeDirectory().appending("ephemerisFile"), isDirectory: false)

        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        }
        var task = httpSession.popLastTask() as? MockUploadTask

        // mock upload success
        assertThat(task, presentAnd(isUploading(fileUrl: ephemerisUtility.mockLatestEphemerisUrl!)))
        task?.mock(progress: 100)
        task?.mockCompletion(statusCode: 200)
        // nothing changes since we don't do anything upon success

        // Check that even if the latest success just happened, a new upload request is issued
        // mock upload failed
        assertThat(task, presentAnd(isUploading(fileUrl: ephemerisUtility.mockLatestEphemerisUrl!)))
        task?.mock(progress: 100)
        task?.mockCompletion(statusCode: 404)
        // nothing changes since we don't do anything upon success

        disconnect(drone: drone, handle: 1)
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        }
        task = httpSession.popLastTask() as? MockUploadTask

        // mock upload success
        assertThat(task, presentAnd(isUploading(fileUrl: ephemerisUtility.mockLatestEphemerisUrl!)))
        // check that there is no more requests sent
        assertThat(httpSession.popLastTask(), nilValue())
    }

    // test uploaad if there is no Ephemeris File
    func testUploadWhenEphemerisIsNotPresent() {
        ephemerisUtility.mockLatestEphemerisUrl = nil
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .landed))
        }
        assertThat(httpSession.popLastTask(), nilValue())
    }

    // test if upload is not done when drone is flying
    func testUploadEphemerisWhenDroneIsFlying() {
        ephemerisUtility.mockLatestEphemerisUrl = URL(
            fileURLWithPath: NSHomeDirectory().appending("ephemerisFile"), isDirectory: false)

        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.ardrone3PilotingstateFlyingstatechangedEncoder(state: .flying))
        }
        assertThat(httpSession.popLastTask(), nilValue())
    }
}
