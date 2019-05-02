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

protocol MockDevice {
    associatedtype Device

    @discardableResult func addConnectors(_ connectors: [DeviceConnectorCore]) -> Device

    func removeConnectors(_ connectors: [DeviceConnectorCore])

    func mockConnecting(through connector: DeviceConnectorCore)

    func mockConnected()

    func mockDisconnecting()

    func mockDisconnected()

    func expectConnect(through connector: DeviceConnectorCore, thenDo: (() -> Void)?)

    func expectDisconnect(thenDo: (() -> Void)?)

    func revokeLastExpectation()

    func assertNoExpectation()
}

protocol MockDeviceExpectation {
}

class MockDeviceConnectExpectation<D: MockDevice>: MockDeviceExpectation {
    typealias Device = D

    private let device: Device
    private let connector: DeviceConnectorCore
    private var afterBlock: (() -> Void)?

    init(device: Device, connector: DeviceConnectorCore, thenDo: (() -> Void)? = nil) {
        self.device = device
        self.connector = connector
        self.afterBlock = thenDo
    }

    func process(connector: DeviceConnectorCore) -> Bool {
        assertThat(connector, `is`(self.connector))
        device.mockConnecting(through: connector)
        afterBlock?()
        return true
    }
}

class MockDeviceDisconnectExpectation<D: MockDevice>: MockDeviceExpectation {
    typealias Device = D

    private let device: Device
    private var afterBlock: (() -> Void)?

    init(device: Device, thenDo: (() -> Void)? = nil) {
        self.device = device
        self.afterBlock = thenDo
    }

    func process() -> Bool {
        device.mockDisconnecting()
        afterBlock?()
        return true
    }
}

final class MockDeviceImpl<D: DeviceCore & MockDevice>: MockDevice {
    typealias Device = D

    let device: Device

    // swiftlint:disable:next weak_delegate
    private let delegate: MockDeviceDelegate<Device>

    init(device: Device, delegate: MockDeviceDelegate<Device>) {
        self.device = device
        self.delegate = delegate
    }

    @discardableResult func addConnectors(_ connectors: [DeviceConnectorCore]) -> Device {
        var newConnectors = device.stateHolder.state._connectors
        newConnectors.append(contentsOf: connectors)
        device.stateHolder.state.update(connectors: newConnectors).notifyUpdated()
        return device
    }

    func removeConnectors(_ connectors: [DeviceConnectorCore]) {
        var newConnectors = device.stateHolder.state._connectors
        connectors.forEach { connector in
            if let index = newConnectors.index(of: connector) {
                newConnectors.remove(at: index)
            }
        }
        device.stateHolder.state.update(connectors: newConnectors).notifyUpdated()
    }

    func mockPersisted(_ persisted: Bool) {
        device.stateHolder.state.update(persisted: persisted).notifyUpdated()
    }

    func mockFirmwareVersion(_ firmware: FirmwareVersion) {
        device.firmwareVersionHolder.update(version: firmware)
    }

    func mockConnecting(through connector: DeviceConnectorCore) {
        device.stateHolder.state.update(connectionState: .connecting).update(activeConnector: connector).notifyUpdated()
    }

    func mockConnected() {
        device.stateHolder.state.update(connectionState: .connected).notifyUpdated()
    }

    func mockDisconnecting() {
        device.stateHolder.state.update(connectionState: .disconnecting).notifyUpdated()
    }

    func mockDisconnected() {
        device.stateHolder.state.update(connectionState: .disconnected).update(activeConnector: nil).notifyUpdated()
    }

    func expectConnect(through connector: DeviceConnectorCore, thenDo: (() -> Void)? = nil) {
        delegate.queue(expectation: MockDeviceConnectExpectation(
            device: device, connector: connector, thenDo: thenDo))
    }

    func expectDisconnect(thenDo: (() -> Void)? = nil) {
        delegate.queue(expectation: MockDeviceDisconnectExpectation(device: device, thenDo: thenDo))
    }

    func revokeLastExpectation() {
        delegate.poll()
    }

    func assertNoExpectation() {
        assertThat(delegate.expectations, empty())
    }
}

final class MockDeviceDelegate<D: MockDevice>: DeviceCoreDelegate {
    typealias Device = D
    fileprivate var expectations: [MockDeviceExpectation] = []

    func forget() -> Bool {
        return false
    }

    func connect(connector: DeviceConnector, password: String?) -> Bool {
        return poll(type: MockDeviceConnectExpectation<Device>.self)?
            .process(connector: connector as! DeviceConnectorCore) ?? false
    }

    func disconnect() -> Bool {
        return poll(type: MockDeviceDisconnectExpectation<Device>.self)?
            .process() ?? false
    }

    func poll<E: MockDeviceExpectation>(type: E.Type) -> E? {
        guard !expectations.isEmpty else {
            assert(false)
            return nil
        }
        let expectation = expectations.removeLast() as? E
        assertThat(expectation, present())
        return expectation
    }

    func poll() {
        expectations.removeLast()
    }

    @discardableResult func queue<E: MockDeviceExpectation>(expectation: E) -> E {
        expectations.append(expectation)
        return expectation
    }
}

class MockDrone: DroneCore, MockDevice {
    typealias Device = MockDrone

    var impl: MockDeviceImpl<MockDrone>!

    required init(uid: String, model: Drone.Model? = nil, name: String? = nil) {
        let delegate = MockDeviceDelegate<MockDrone>()
        super.init(uid: uid,
                   model: model ?? .anafi4k,
                   name: name ?? "drone-\(uid)",
            delegate: delegate)
        impl = MockDeviceImpl(device: self, delegate: delegate)
    }

    @discardableResult func addConnectors(_ connectors: [DeviceConnectorCore]) -> Device {
        return impl.addConnectors(connectors)
    }

    func removeConnectors(_ connectors: [DeviceConnectorCore]) {
        impl.removeConnectors(connectors)
    }

    func mockPersisted(_ persisted: Bool) {
        impl.mockPersisted(persisted)
    }

    func mockFirmwareVersion(_ firmware: FirmwareVersion) {
        impl.mockFirmwareVersion(firmware)
    }

    func mockConnecting(through connector: DeviceConnectorCore) {
        impl.mockConnecting(through: connector)
    }

    func mockConnected() {
        impl.mockConnected()
    }

    func mockDisconnecting() {
        impl.mockDisconnecting()
    }

    func mockDisconnected() {
        impl.mockDisconnected()
    }

    func expectConnect(through connector: DeviceConnectorCore, thenDo: (() -> Void)? = nil) {
        impl.expectConnect(through: connector, thenDo: thenDo)
    }

    func expectDisconnect(thenDo: (() -> Void)? = nil) {
        impl.expectDisconnect()
    }

    func revokeLastExpectation() {
        impl.revokeLastExpectation()
    }

    func assertNoExpectation() {
        impl.assertNoExpectation()
    }
}

class MockRemoteControl: RemoteControlCore, MockDevice {
    typealias Device = MockRemoteControl

    var impl: MockDeviceImpl<MockRemoteControl>!

    required init(uid: String, model: RemoteControl.Model? = nil, name: String? = nil) {
        let delegate = MockDeviceDelegate<MockRemoteControl>()
        super.init(uid: uid,
                   model: model ?? .skyCtrl3,
                   name: name ?? "rc-\(uid)",
            delegate: delegate)
        impl = MockDeviceImpl(device: self, delegate: delegate)
    }

    @discardableResult func addConnectors(_ connectors: [DeviceConnectorCore]) -> Device {
        return impl.addConnectors(connectors)
    }

    func removeConnectors(_ connectors: [DeviceConnectorCore]) {
        impl.removeConnectors(connectors)
    }

    func mockPersisted(_ persisted: Bool) {
        impl.mockPersisted(persisted)
    }

    func mockFirmwareVersion(_ firmware: FirmwareVersion) {
        impl.mockFirmwareVersion(firmware)
    }

    func mockConnecting(through connector: DeviceConnectorCore) {
        impl.mockConnecting(through: connector)
    }

    func mockConnected() {
        impl.mockConnected()
    }

    func mockDisconnecting() {
        impl.mockDisconnecting()
    }

    func mockDisconnected() {
        impl.mockDisconnected()
    }

    func expectConnect(through connector: DeviceConnectorCore, thenDo: (() -> Void)? = nil) {
        impl.expectConnect(through: connector, thenDo: thenDo)
    }

    func expectDisconnect(thenDo: (() -> Void)? = nil) {
        impl.expectDisconnect()
    }

    func revokeLastExpectation() {
        impl.revokeLastExpectation()
    }

    func assertNoExpectation() {
        impl.assertNoExpectation()
    }
}
