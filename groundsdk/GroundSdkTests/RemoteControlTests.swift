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
@testable import GroundSdkMock

/// Test drone functions
class RemoteControlTests: XCTestCase {
    /// Check that drone name can be get and is correctly notified when changed
    func testDroneName() {
        var cnt = 0
        var name: String?
        let rcCore = RemoteControlCore(uid: "rc1", model: RemoteControl.Model.skyCtrl3,
                                       name: "name", delegate: DeviceDelegate())
        let rc = RemoteControl(remoteControlCore: rcCore)
        var nameRef: Ref<String>? = rc.getName { newName in
            name = newName
            cnt += 1
        }
        // remove unused variable warning
        _ = nameRef
        // check that the inital value has been notified
        assertThat(cnt, equalTo(1))
        assertThat(name, presentAnd(`is`("name")))

        rcCore.nameHolder.update(name: "newName")
        assertThat(cnt, equalTo(2))
        assertThat(name, presentAnd(`is`("newName")))
        assertThat(rc.name, `is`("newName"))

        nameRef = nil
        rcCore.nameHolder.update(name: "otherName")
        assertThat(cnt, equalTo(2))
        assertThat(name, presentAnd(`is`("newName")))
        assertThat(rc.name, `is`("otherName"))
    }

    func testRemoteControlEquatableOnUid() {
        let rcCore1 = RemoteControlCore(uid: "sameUID", model: RemoteControl.Model.skyCtrl3,
                                        name: "name", delegate: DeviceDelegate())
        let rc1 = RemoteControl(remoteControlCore: rcCore1)
        let rcCore2 = RemoteControlCore(uid: "sameUID", model: RemoteControl.Model.skyCtrl3,
                                        name: "name", delegate: DeviceDelegate())
        let rc2 = RemoteControl(remoteControlCore: rcCore2)
        let rcCore3 = RemoteControlCore(uid: "otherUID", model: RemoteControl.Model.skyCtrl3,
                                        name: "name", delegate: DeviceDelegate())
        let rc3 = RemoteControl(remoteControlCore: rcCore3)
        assertThat(rc1 == rc2, `is`(true))
        assertThat(rc1 == rc3, `is`(false))
    }

    /// Check that drone name can be get and is correctly notified when changed
    func testDroneState() {
        var cnt = 0
        var state: DeviceState?
        let rcCore = RemoteControlCore(uid: "rc1", model: RemoteControl.Model.skyCtrl3,
                                       name: "name", delegate: DeviceDelegate())
        let rc = RemoteControl(remoteControlCore: rcCore)
        var stateRef: Ref<DeviceState>? = rc.getState { newState in
            state = newState
            cnt += 1
        }
        // remove unused variable warning
        _ = stateRef

        // check that the callback has not been called when no value is set
        assertThat(cnt, equalTo(1))
        assertThat(state, presentAnd(allOf(
            `is`(DeviceState.ConnectionState.disconnected),
            `is`(DeviceState.ConnectionStateCause.none))))

        rcCore.stateHolder.state?.update(connectionState: .disconnecting, withCause: .failure).notifyUpdated()
        assertThat(cnt, equalTo(2))
        assertThat(state, presentAnd(allOf(
            `is`(DeviceState.ConnectionState.disconnecting),
            `is`(DeviceState.ConnectionStateCause.failure))))

        stateRef = nil
    }

    func testGetInstrument() {
        let rcCore = RemoteControlCore(uid: "rc1", model: RemoteControl.Model.skyCtrl3,
                                       name: "name", delegate: DeviceDelegate())
        let rc = RemoteControl(remoteControlCore: rcCore)

        var instr: TestInstrument?
        var cnt = 0

        // check getting an unknown Instrument
        let instrRef: Ref<TestInstrument> = rc.getInstrument(testInstruments) { instrument in
            cnt += 1
            instr = instrument
        }
        // remove unused variable warning
        _ = instrRef

        // check instrument is not found
        assertThat(rc.getInstrument(testInstruments), `is`(nilValue()))
        // callback should not be called if the Instrument doesn't exists
        assertThat(cnt, `is`(0))

        // add an Instrument
        rcCore.instrumentStore.add(TestInstrumentCore())

        // check instrument present and notified
        assertThat(rc.getInstrument(TestInstruments()), present())
        assertThat(cnt, `is`(1))
        assertThat(instr, present())

        // get a ref on an existing document
        _ = rc.getInstrument(testInstruments) { instrument in
            cnt += 1
            assertThat(instrument, present())
        }
        // check the callback is called immediately
        assertThat(cnt, `is`(2))

        // remove Instrument
        rcCore.instrumentStore.remove(TestInstrumentCore())

        // check instrument is not found and remove has been notified
        assertThat(rc.getInstrument(testInstruments), `is`(nilValue()))
        assertThat(instr, nilValue())
        assertThat(cnt, `is`(3))
    }

    func testGetPeripheral() {
        let rcCore = RemoteControlCore(uid: "rc1", model: RemoteControl.Model.skyCtrl3,
                                       name: "name", delegate: DeviceDelegate())
        let rc = RemoteControl(remoteControlCore: rcCore)

        var periph: TestPeripheral?
        var cnt = 0

        // check getting an unknown Peripheral
        let periphRef: Ref<TestPeripheral> = rc.getPeripheral(testPeripherals) { peripheral in
            cnt += 1
            periph = peripheral
        }
        // remove unused variable warning
        _ = periphRef

        // check peripheral is not found
        assertThat(rc.getPeripheral(testPeripherals), `is`(nilValue()))
        // callback should not be called if the Peripheral doesn't exists
        assertThat(cnt, `is`(0))

        // add an Peripheral
        rcCore.peripheralStore.add(TestPeripheralCore())

        // check peripheral present and notified
        assertThat(rc.getPeripheral(TestPeripherals()), present())
        assertThat(cnt, `is`(1))
        assertThat(periph, present())

        // get a ref on an existing document
        _ = rc.getPeripheral(testPeripherals) { peripheral in
            cnt += 1
            assertThat(peripheral, present())
        }
        // check the callback is called immediately
        assertThat(cnt, `is`(2))

        // remove Peripheral
        rcCore.peripheralStore.remove(TestPeripheralCore())

        // check peripheral is not found and remove has been notified
        assertThat(rc.getPeripheral(testPeripherals), `is`(nilValue()))
        assertThat(periph, nilValue())
        assertThat(cnt, `is`(3))
    }

    func testForget() {
        let delegate = DeviceDelegate()
        let rcCore = RemoteControlCore(uid: "rc1", model: RemoteControl.Model.skyCtrl3,
                                       name: "name", delegate: delegate)
        let rc = RemoteControl(remoteControlCore: rcCore)
        assertThat(rc.forget(), `is`(true))
        assertThat(delegate.forgetCnt, `is`(1))
    }

    func testConnect() {
        let delegate = DeviceDelegate()
        let rcCore = RemoteControlCore(uid: "rc1", model: RemoteControl.Model.skyCtrl3,
                                       name: "name", delegate: delegate)
        let rc = RemoteControl(remoteControlCore: rcCore)
        assertThat(rc.connect(connector: LocalDeviceConnectorCore.usb), `is`(true))
        assertThat(delegate.connectCnt, `is`(1))
    }

    func testConnectNoConnectors() {
        let delegate = DeviceDelegate()
        let rcCore = RemoteControlCore(uid: "rc1", model: RemoteControl.Model.skyCtrl3,
                                       name: "name", delegate: delegate)
        let rc = RemoteControl(remoteControlCore: rcCore)
        assertThat(rc.connect(), `is`(false))
        assertThat(delegate.connectCnt, `is`(0))
    }

    func testConnectSingleLocalConnector() {
        let delegate = DeviceDelegate()
        let rcCore = RemoteControlCore(uid: "rc1", model: RemoteControl.Model.skyCtrl3,
                                       name: "name", delegate: delegate)
        rcCore.stateHolder.state.update(connectors: [LocalDeviceConnectorCore.wifi])
        let rc = RemoteControl(remoteControlCore: rcCore)
        assertThat(rc.connect(), `is`(true))
        assertThat(delegate.connectCnt, `is`(1))
    }

    func testConnectWifiAndUsbLocalConnector() {
        let delegate = DeviceDelegate()
        let rcCore = RemoteControlCore(uid: "rc1", model: RemoteControl.Model.skyCtrl3,
                                       name: "name", delegate: delegate)
        rcCore.stateHolder.state.update(connectors: [LocalDeviceConnectorCore.wifi,
                                                  LocalDeviceConnectorCore.usb])
        let rc = RemoteControl(remoteControlCore: rcCore)
        assertThat(rc.connect(), `is`(true))
        assertThat(delegate.connectCnt, `is`(1))
        assertThat(delegate.connectConnectorUid, presentAnd(`is`(LocalDeviceConnectorCore.usb.uid)))
    }

    func testDisconnect() {
        let delegate = DeviceDelegate()
        let rcCore = RemoteControlCore(uid: "rc1", model: RemoteControl.Model.skyCtrl3,
                                       name: "name", delegate: delegate)
        let rc = RemoteControl(remoteControlCore: rcCore)
        assertThat(rc.disconnect(), `is`(true))
        assertThat(delegate.disconnectCnt, `is`(1))
    }
}
