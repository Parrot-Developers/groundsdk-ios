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

class CameraFeatureExposureValuesTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var cameraExposureValues: CameraExposureValues?
    var cameraExposureValuesRef: Ref<CameraExposureValues>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice(
            "123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1", handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        cameraExposureValuesRef = drone.getInstrument(Instruments.cameraExposureValues) { [unowned self] expoValues in
            self.cameraExposureValues = expoValues
            self.changeCnt += 1
        }
        changeCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(cameraExposureValues, `is`(nilValue()))

        // values should be received during the connection for the component to be published
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraExposureEncoder(
                    camId: 0, shutterSpeed: .shutter1Over100, isoSensitivity: .iso125, lock: .active, lockRoiX: 0,
                    lockRoiY: 0, lockRoiWidth: 0, lockRoiHeight: 0))
        }

        assertThat(cameraExposureValues, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(cameraExposureValues, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))

        // if values are not received during connection, component should remain unpublished
        connect(drone: drone, handle: 1)
        assertThat(cameraExposureValues, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))

        // as soon as the first event is received, component should be published
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraExposureEncoder(
                camId: 0, shutterSpeed: .shutter1Over100, isoSensitivity: .iso125, lock: .active, lockRoiX: 0,
                lockRoiY: 0, lockRoiWidth: 0, lockRoiHeight: 0))
        assertThat(cameraExposureValues, `is`(present()))
        assertThat(changeCnt, `is`(3))

        disconnect(drone: drone, handle: 1)
        assertThat(cameraExposureValues, `is`(nilValue()))
        assertThat(changeCnt, `is`(4))
    }

    func testShutterSpeedValue() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraExposureEncoder(
                    camId: 0, shutterSpeed: .shutter1Over100, isoSensitivity: .iso125, lock: .active, lockRoiX: 0,
                    lockRoiY: 0, lockRoiWidth: 0, lockRoiHeight: 0))
        }

        assertThat(cameraExposureValues!.shutterSpeed, `is`(.oneOver100))
        assertThat(changeCnt, `is`(1))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraExposureEncoder(
                camId: 0, shutterSpeed: .shutter1Over10000, isoSensitivity: .iso125, lock: .active, lockRoiX: 0,
                lockRoiY: 0, lockRoiWidth: 0, lockRoiHeight: 0))
        assertThat(cameraExposureValues!.shutterSpeed, `is`(.oneOver10000))
        assertThat(changeCnt, `is`(2))
    }

    func testIsoSensitivityValue() {
        connect(drone: drone, handle: 1) {
            self.mockArsdkCore.onCommandReceived(
                1, encoder: CmdEncoder.cameraExposureEncoder(
                    camId: 0, shutterSpeed: .shutter1Over100, isoSensitivity: .iso125, lock: .active, lockRoiX: 0,
                    lockRoiY: 0, lockRoiWidth: 0, lockRoiHeight: 0))
        }

        assertThat(cameraExposureValues!.isoSensitivity, `is`(.iso125))
        assertThat(changeCnt, `is`(1))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.cameraExposureEncoder(
                camId: 0, shutterSpeed: .shutter1Over10000, isoSensitivity: .iso1600, lock: .active, lockRoiX: 0,
                lockRoiY: 0, lockRoiWidth: 0, lockRoiHeight: 0))
        assertThat(cameraExposureValues!.isoSensitivity, `is`(.iso1600))
        assertThat(changeCnt, `is`(2))
    }
}
