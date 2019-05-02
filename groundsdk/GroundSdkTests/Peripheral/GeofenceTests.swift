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
import CoreLocation
@testable import GroundSdk

/// Test Geofence peripheral
class GeofenceTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: GeofenceCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = GeofenceCore(store: store!, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.geofence), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.geofence), nilValue())
    }

    func testMaxAltitude() {
        impl.publish()
        var cnt = 0
        let geofence = store.get(Peripherals.geofence)!
        _ = store.register(desc: Peripherals.geofence) {
            cnt += 1
        }

        // test initial value
        assertThat(geofence.maxAltitude, allOf(`is`(0.0, 0.0, 0.0), isUpToDate()))

        // notify new backend values
        impl.update(maxAltitude: (5, 30, 50)).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(geofence.maxAltitude, allOf(`is`(5, 30, 50), isUpToDate()))

        // change setting
        geofence.maxAltitude.value = 66 // max is 50
        assertThat(cnt, `is`(2))

        assertThat(backend!.maxAltitude, `is`(50))
        assertThat(geofence.maxAltitude, allOf(`is`(5, 50, 50), isUpdating()))

        // notify from backend
        impl.update(maxAltitude: (nil, 50, nil)).notifyUpdated()
        assertThat(geofence.maxAltitude, allOf(`is`(5, 50, 50), isUpToDate()))
        assertThat(cnt, `is`(3))

        // change setting (same value)
        geofence.maxAltitude.value = 50
        assertThat(cnt, `is`(3))
        assertThat(geofence.maxAltitude, allOf(`is`(5, 50, 50), isUpToDate()))

        // notify from backend same value
        impl.update(maxAltitude: (5, 50, 50)).notifyUpdated()
        assertThat(geofence.maxAltitude, allOf(`is`(5, 50, 50), isUpToDate()))
        assertThat(cnt, `is`(3))

        // change max altitude
        geofence.maxAltitude.value = 40
        assertThat(cnt, `is`(4))
        assertThat(geofence.maxAltitude, allOf(`is`(5, 40, 50), isUpdating()))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(5))
        assertThat(geofence.maxAltitude, allOf(`is`(5, 40, 50), isUpToDate()))

        // timeout should not be triggered since it has been canceled
        (geofence.maxDistance as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(geofence.maxAltitude, allOf(`is`(5, 40, 50), isUpToDate()))
    }

    func testMaxDistance() {
        impl.publish()
        var cnt = 0
        let geofence = store.get(Peripherals.geofence)!
        _ = store.register(desc: Peripherals.geofence) {
            cnt += 1
        }

        // test initial value
        assertThat(geofence.maxDistance, allOf(`is`(0.0, 0.0, 0.0), isUpToDate()))

        // notify new backend values
        impl.update(maxDistance: (1.1, 66.1, 90.5)).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(geofence.maxDistance, allOf(`is`(1.1, 66.1, 90.5), isUpToDate()))

        // change setting
        geofence.maxDistance.value = 76.67
        assertThat(cnt, `is`(2))

        assertThat(backend!.maxDistance, `is`(76.67))
        assertThat(geofence.maxDistance, allOf(`is`(1.1, 76.67, 90.5), isUpdating()))

        // notify from backend
        impl.update(maxDistance: (nil, 76.67, nil)).notifyUpdated()
        assertThat(geofence.maxDistance, allOf(`is`(1.1, 76.67, 90.5), isUpToDate()))
        assertThat(cnt, `is`(3))

        // change setting (same value)
        geofence.maxDistance.value = 76.67
        assertThat(cnt, `is`(3))
        assertThat(geofence.maxDistance, allOf(`is`(1.1, 76.67, 90.5), isUpToDate()))

        // notify from backend same value
        impl.update(maxDistance: (1.1, 76.67, 90.5)).notifyUpdated()
        assertThat(geofence.maxDistance, allOf(`is`(1.1, 76.67, 90.5), isUpToDate()))
        assertThat(cnt, `is`(3))

        // change max distance
        geofence.maxDistance.value = 50
        assertThat(cnt, `is`(4))
        assertThat(geofence.maxDistance, allOf(`is`(1.1, 50, 90.5), isUpdating()))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(5))
        assertThat(geofence.maxDistance, allOf(`is`(1.1, 50, 90.5), isUpToDate()))

        // timeout should not be triggered since it has been canceled
        (geofence.maxDistance as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(geofence.maxDistance, allOf(`is`(1.1, 50, 90.5), isUpToDate()))
    }

    func testMode() {
        impl.publish()
        var cnt = 0
        let geofence = store.get(Peripherals.geofence)!
        _ = store.register(desc: Peripherals.geofence) {
            cnt += 1
        }

        // test initial value
        assertThat(geofence.mode, allOf(`is`(GeofenceMode.altitude), isUpToDate()))

        // notify new backend values
        impl.update(mode: .cylinder).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(geofence.mode, allOf(`is`(GeofenceMode.cylinder), isUpToDate()))

        // change setting
        geofence.mode.value = .altitude
        assertThat(cnt, `is`(2))
        assertThat(backend!.mode, `is`(.altitude))
        assertThat(geofence.mode, allOf(`is`(GeofenceMode.altitude), isUpdating()))

        // notify from backend
        impl.update(mode: .altitude).notifyUpdated()
        assertThat(geofence.mode, allOf(`is`(GeofenceMode.altitude), isUpToDate()))
        assertThat(cnt, `is`(3))

        // timeout should not do anything
        (geofence.mode as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(3))
        assertThat(geofence.mode, allOf(`is`(GeofenceMode.altitude), isUpToDate()))

        // change setting (same value)
        geofence.mode.value = .altitude
        assertThat(cnt, `is`(3))
        assertThat(backend!.mode, `is`(.altitude))
        assertThat(geofence.mode, allOf(`is`(GeofenceMode.altitude), isUpToDate()))

        // notify from backend same value
        impl.update(mode: .altitude).notifyUpdated()
        assertThat(geofence.mode, allOf(`is`(GeofenceMode.altitude), isUpToDate()))
        assertThat(cnt, `is`(3))

        // change setting
        geofence.mode.value = .cylinder
        assertThat(cnt, `is`(4))
        assertThat(geofence.mode, allOf(`is`(GeofenceMode.cylinder), isUpdating()))

        // mock timeout
        (geofence.mode as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(5))
        assertThat(geofence.mode, allOf(`is`(GeofenceMode.altitude), isUpToDate()))

        // change mode
        geofence.mode.value = .cylinder
        assertThat(cnt, `is`(6))
        assertThat(geofence.mode, allOf(`is`(GeofenceMode.cylinder), isUpdating()))

        // mock cancel rollbacks
        impl.cancelSettingsRollback().notifyUpdated()
        assertThat(cnt, `is`(7))
        assertThat(geofence.mode, allOf(`is`(GeofenceMode.cylinder), isUpToDate()))

        // timeout should not be triggered since it has been canceled
        (geofence.mode as? TimeoutableSetting)?.mockTimeout()
        assertThat(cnt, `is`(7))
        assertThat(geofence.mode, allOf(`is`(GeofenceMode.cylinder), isUpToDate()))
    }

    func testCenter() {
        impl.publish()
        var cnt = 0
        let geofence = store.get(Peripherals.geofence)!
        _ = store.register(desc: Peripherals.geofence) {
            cnt += 1
        }

        // test initial value
        assertThat(geofence.center, nilValue())

        // mock value change from low-level
        let coord2D = CLLocationCoordinate2D(latitude: 1.1, longitude: 2.2)
        let timeStampDate = Date()
        let testLocation = CLLocation(coordinate: coord2D, altitude: 3.3, horizontalAccuracy: 4.4,
                                      verticalAccuracy: 5.5, course: 0, speed: 6.6, timestamp: timeStampDate)
        impl.update(center: testLocation).notifyUpdated()
        assertThat(geofence.center, presentAnd(
            `is`(latitude: 1.1, longitude: 2.2, altitude: 3.3, hAcc: 4.4, vAcc: 5.5, date: timeStampDate)))
        assertThat(cnt, `is`(1))

        // mock value change from low-level - same value
        impl.update(center: testLocation).notifyUpdated()
        assertThat(geofence.center, presentAnd(
            `is`(latitude: 1.1, longitude: 2.2, altitude: 3.3, hAcc: 4.4, vAcc: 5.5, date: timeStampDate)))
        assertThat(cnt, `is`(1))
    }
}

private class Backend: GeofenceBackend {

    var maxAltitude = 0.0
    var maxDistance = 0.0
    var mode = GeofenceMode.altitude

    func set(maxAltitude value: Double) -> Bool {
        maxAltitude = value
        return true
    }

    func set(maxDistance value: Double) -> Bool {
        maxDistance = value
        return true
    }

    func set(mode: GeofenceMode) -> Bool {
        self.mode = mode
        return true
    }
}
