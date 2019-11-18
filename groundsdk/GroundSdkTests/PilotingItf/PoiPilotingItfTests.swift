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

/// Test Poi piloting interface
class PoiPilotingItfTest: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: PoiPilotingItfCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = PoiPilotingItfCore(store: store, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store.get(PilotingItfs.pointOfInterest), present())
        impl.unpublish()
        assertThat(store.get(PilotingItfs.pointOfInterest), nilValue())
    }

    func testPoiPiloting() {
        impl.publish()
        var cnt = 0
        let poiItf = store.get(PilotingItfs.pointOfInterest)!
        _ = store.register(desc: PilotingItfs.pointOfInterest) {
            cnt += 1
        }
        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(poiItf.currentPointOfInterest, nilValue())

        // update from low level the same value -- no notification expected
        impl.update(currentPointOfInterest: nil)
        assertThat(cnt, `is`(0))
        assertThat(poiItf.currentPointOfInterest, nilValue())

        // update from low level
        let pointOfInterest = PointOfInterestCore(latitude: 1.1, longitude: 2.2, altitude: 3.3, mode: .freeGimbal)
        impl.update(currentPointOfInterest: pointOfInterest).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(poiItf.currentPointOfInterest, presentAnd(`is`(latitude: 1.1, longitude: 2.2, altitude: 3.3,
                                                                  mode: .freeGimbal)))
    }

    func testCallingBackendThroughInterface() {
        impl.publish()
        let poiInterface = store.get(PilotingItfs.pointOfInterest)!

        // set the pitf as idle
        impl.update(activeState: .idle)

        poiInterface.start(latitude: 1.1, longitude: 2.2, altitude: 3.3)
        assertThat(backend.currentPointOfInterest, presentAnd(`is`(latitude: 1.1, longitude: 2.2, altitude: 3.3,
                                                                   mode: .lockedGimbal)))
        poiInterface.start(latitude: 4.4, longitude: 5.5, altitude: 6.6, mode: .freeGimbal)
        assertThat(backend.currentPointOfInterest, presentAnd(`is`(latitude: 4.4, longitude: 5.5, altitude: 6.6,
                                                                   mode: .freeGimbal)))
        poiInterface.set(roll: 1)
        assertThat(backend.roll, `is`(1))
        poiInterface.set(pitch: 2)
        assertThat(backend.pitch, `is`(2))
        poiInterface.set(verticalSpeed: 3)
        assertThat(backend.verticalSpeed, `is`(3))
    }
}

private class Backend: PoiPilotingItfBackend {

    var currentPointOfInterest: PointOfInterestCore?
    var roll = 0
    var pitch = 0
    var verticalSpeed = 0

    func activate() -> Bool {
        return true
    }

    func deactivate() -> Bool {
        return true
    }

    func start(latitude: Double, longitude: Double, altitude: Double, mode: PointOfInterestMode) {
        // mock update a nex point of interest
        currentPointOfInterest = PointOfInterestCore(latitude: latitude, longitude: longitude, altitude: altitude,
                                                     mode: mode)
    }

    func set(roll: Int) {
        self.roll = roll
    }

    func set(pitch: Int) {
        self.pitch = pitch
    }

    func set(verticalSpeed: Int) {
        self.verticalSpeed = verticalSpeed
    }
}
