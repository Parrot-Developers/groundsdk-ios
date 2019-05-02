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

class DeviceStoreUtilityCoreTests: XCTestCase {

    let droneStore = DroneStoreUtilityCore()
    let rcStore = RemoteControlStoreUtilityCore()

    override func setUp() {
        super.setUp()
    }

    func testDroneStore() {
        var didAddDeviceCnt = 0
        var droneAdded: DroneCore?
        var deviceInfoDidChangeCnt = 0
        var droneChanged: DroneCore?
        var didRemoveDeviceCnt = 0
        var droneRemoved: DroneCore?
        var storeDidChangeCnt = 0
        let monitor = droneStore.startMonitoring(
            didAddDevice: { drone in
                didAddDeviceCnt += 1
                droneAdded = drone
        },
            deviceInfoDidChange: { drone in
                deviceInfoDidChangeCnt += 1
                droneChanged = drone
        },
            didRemoveDevice: { drone in
                didRemoveDeviceCnt += 1
                droneRemoved = drone
        },
            storeDidChange: { storeDidChangeCnt += 1 })

        // add drone 1
        let drone1 = MockDrone(uid: "1")
        droneStore.add(drone1)
        assertThat(deviceInfoDidChangeCnt, `is`(0))
        assertThat(didRemoveDeviceCnt, `is`(0))
        assertThat(storeDidChangeCnt, `is`(1))
        assertThat(didAddDeviceCnt, `is`(1))
        assertThat(droneAdded, presentAnd(`is`(drone1)))
        assertThat(droneStore.getDevices(), containsInAnyOrder(drone1))
        assertThat(droneStore.getDevice(uid: "1"), presentAnd(`is`(drone1)))

        // change info on drone 1
        drone1.nameHolder.update(name: "newName")
        assertThat(didRemoveDeviceCnt, `is`(0))
        assertThat(didAddDeviceCnt, `is`(1))
        assertThat(storeDidChangeCnt, `is`(2))
        assertThat(deviceInfoDidChangeCnt, `is`(1))
        assertThat(droneChanged, presentAnd(`is`(drone1)))
        assertThat(droneStore.getDevices(), containsInAnyOrder(drone1))
        assertThat(droneStore.getDevice(uid: "1"), presentAnd(`is`(drone1)))

        // add drone 2
        let drone2 = MockDrone(uid: "2")
        droneStore.add(drone2)
        assertThat(deviceInfoDidChangeCnt, `is`(1))
        assertThat(didRemoveDeviceCnt, `is`(0))
        assertThat(storeDidChangeCnt, `is`(3))
        assertThat(didAddDeviceCnt, `is`(2))
        assertThat(droneAdded, presentAnd(`is`(drone2)))
        assertThat(droneStore.getDevices(), containsInAnyOrder(drone1, drone2))
        assertThat(droneStore.getDevice(uid: "2"), presentAnd(`is`(drone2)))

        // remove drone 1
        droneStore.remove(drone1)
        assertThat(deviceInfoDidChangeCnt, `is`(1))
        assertThat(didAddDeviceCnt, `is`(2))
        assertThat(storeDidChangeCnt, `is`(4))
        assertThat(didRemoveDeviceCnt, `is`(1))
        assertThat(droneRemoved, presentAnd(`is`(drone1)))
        assertThat(droneStore.getDevices(), containsInAnyOrder(drone2))
        assertThat(droneStore.getDevice(uid: "1"), nilValue())

        // check that after having stopped the monitor, it is not notified anymore but the changes are still effectiv
        monitor.stop()

        // add drone 3
        let drone3 = MockDrone(uid: "3")
        droneStore.add(drone3)
        assertThat(deviceInfoDidChangeCnt, `is`(1)) // same result as before
        assertThat(didAddDeviceCnt, `is`(2))        // same result as before
        assertThat(storeDidChangeCnt, `is`(4))      // same result as before
        assertThat(didRemoveDeviceCnt, `is`(1))     // same result as before
        assertThat(droneStore.getDevices(), containsInAnyOrder(drone3, drone2))
        assertThat(droneStore.getDevice(uid: "3"), presentAnd(`is`(drone3)))

        // remove drone 3
        droneStore.remove(drone3)
        assertThat(deviceInfoDidChangeCnt, `is`(1)) // same result as before
        assertThat(didAddDeviceCnt, `is`(2))        // same result as before
        assertThat(storeDidChangeCnt, `is`(4))      // same result as before
        assertThat(didRemoveDeviceCnt, `is`(1))     // same result as before
        assertThat(droneStore.getDevices(), containsInAnyOrder(drone2))
        assertThat(droneStore.getDevice(uid: "3"), nilValue())
    }

    func testRemoteControlStore() {
        var didAddDeviceCnt = 0
        var rcAdded: RemoteControlCore?
        var deviceInfoDidChangeCnt = 0
        var rcChanged: RemoteControlCore?
        var didRemoveDeviceCnt = 0
        var rcRemoved: RemoteControlCore?
        var storeDidChangeCnt = 0
        let monitor = rcStore.startMonitoring(
            didAddDevice: { rc in
                didAddDeviceCnt += 1
                rcAdded = rc
        },
            deviceInfoDidChange: { rc in
                deviceInfoDidChangeCnt += 1
                rcChanged = rc
        },
            didRemoveDevice: { rc in
                didRemoveDeviceCnt += 1
                rcRemoved = rc
        },
            storeDidChange: { storeDidChangeCnt += 1 })

        // add rc 1
        let rc1 = MockRemoteControl(uid: "1")
        rcStore.add(rc1)
        assertThat(deviceInfoDidChangeCnt, `is`(0))
        assertThat(didRemoveDeviceCnt, `is`(0))
        assertThat(storeDidChangeCnt, `is`(1))
        assertThat(didAddDeviceCnt, `is`(1))
        assertThat(rcAdded, presentAnd(`is`(rc1)))
        assertThat(rcStore.getDevices(), containsInAnyOrder(rc1))
        assertThat(rcStore.getDevice(uid: "1"), presentAnd(`is`(rc1)))

        // change info on rc 1
        rc1.nameHolder.update(name: "newName")
        assertThat(didRemoveDeviceCnt, `is`(0))
        assertThat(didAddDeviceCnt, `is`(1))
        assertThat(storeDidChangeCnt, `is`(2))
        assertThat(deviceInfoDidChangeCnt, `is`(1))
        assertThat(rcChanged, presentAnd(`is`(rc1)))
        assertThat(rcStore.getDevices(), containsInAnyOrder(rc1))
        assertThat(rcStore.getDevice(uid: "1"), presentAnd(`is`(rc1)))

        // add rc 2
        let rc2 = MockRemoteControl(uid: "2")
        rcStore.add(rc2)
        assertThat(deviceInfoDidChangeCnt, `is`(1))
        assertThat(didRemoveDeviceCnt, `is`(0))
        assertThat(storeDidChangeCnt, `is`(3))
        assertThat(didAddDeviceCnt, `is`(2))
        assertThat(rcAdded, presentAnd(`is`(rc2)))
        assertThat(rcStore.getDevices(), containsInAnyOrder(rc1, rc2))
        assertThat(rcStore.getDevice(uid: "2"), presentAnd(`is`(rc2)))

        // remove drone 1
        rcStore.remove(rc1)
        assertThat(deviceInfoDidChangeCnt, `is`(1))
        assertThat(didAddDeviceCnt, `is`(2))
        assertThat(storeDidChangeCnt, `is`(4))
        assertThat(didRemoveDeviceCnt, `is`(1))
        assertThat(rcRemoved, presentAnd(`is`(rc1)))
        assertThat(rcStore.getDevices(), containsInAnyOrder(rc2))
        assertThat(rcStore.getDevice(uid: "1"), nilValue())

        // check that after having stopped the monitor, it is not notified anymore but the changes are still effectiv
        monitor.stop()

        // add rc 3
        let rc3 = MockRemoteControl(uid: "3")
        rcStore.add(rc3)
        assertThat(deviceInfoDidChangeCnt, `is`(1)) // same result as before
        assertThat(didAddDeviceCnt, `is`(2))        // same result as before
        assertThat(storeDidChangeCnt, `is`(4))      // same result as before
        assertThat(didRemoveDeviceCnt, `is`(1))     // same result as before
        assertThat(rcStore.getDevices(), containsInAnyOrder(rc3, rc2))
        assertThat(rcStore.getDevice(uid: "3"), presentAnd(`is`(rc3)))

        // remove rc 3
        rcStore.remove(rc3)
        assertThat(deviceInfoDidChangeCnt, `is`(1)) // same result as before
        assertThat(didAddDeviceCnt, `is`(2))        // same result as before
        assertThat(storeDidChangeCnt, `is`(4))      // same result as before
        assertThat(didRemoveDeviceCnt, `is`(1))     // same result as before
        assertThat(rcStore.getDevices(), containsInAnyOrder(rc2))
        assertThat(rcStore.getDevice(uid: "3"), nilValue())
    }

}
