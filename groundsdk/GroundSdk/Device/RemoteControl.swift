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

/// Remote control.
@objcMembers
@objc(GSRemoteControl)
public class RemoteControl: NSObject, InstrumentProvider, PeripheralProvider {

    /// Model of remote control.
    @objc(GSRemoteControlModel)
    public enum Model: Int, CustomStringConvertible {
        /// Sky Controller 3 remote control.
        case skyCtrl3

        /// Sky Controller UA remote control.
        case skyCtrlUA

        /// Internal unique identifier.
        public var internalId: Int {
            switch self {
            case .skyCtrl3:     return 0x0918
            case .skyCtrlUA:    return 0x091c
            }
        }

        /// Debug description.
        public var description: String {
            switch self {
            case .skyCtrl3:     return "skyCtrl3"
            case .skyCtrlUA:    return "skyCtrlUA"
            }
        }

        /// Set containing all possible models of remote controls.
        static let allCases: Set<Model> = [.skyCtrl3, .skyCtrlUA]
    }

    /// Remote control unique identifier, persistant between sessions.
    public var uid: String {
        return remoteControlCore.uid
    }

    /// Remote control mode.
    public var model: Model {
        return remoteControlCore.model
    }

    /// Remote control name.
    public var name: String {
        return remoteControlCore.nameHolder.name
    }

    /// Remote control state.
    public var state: DeviceState {
        return remoteControlCore.stateHolder.state
    }

    /// Equatable (override the isEqual function because RemoteControl inherits from NSObject).
    override public func isEqual(_ object: Any?) -> Bool {
        if let otherRemote = object as? RemoteControl {
            return self.uid == otherRemote.uid
        } else {
            return false
        }
    }

    /// Debug description.
    override public var description: String {
        return "Remote Control \(uid): name = \(name); model = \(model)"
    }

    /// RemoteControlCore instance backing this Remote control.
    private let remoteControlCore: RemoteControlCore

    /// Optional callback to call when this remote control is deinit.
    private let willBeDestroyedCallback: ((RemoteControlCore) -> Void)?

    /// Creates a remote control with a given remote control core.
    ///
    /// - Parameters:
    ///    - remoteControlCore: remote control core referenced by this remote control
    ///    - willBeDestroyedCallback: optional callback called when the remote control is deinit
    internal init(remoteControlCore: RemoteControlCore,
                  willBeDestroyedCallback: ((RemoteControlCore) -> Void)? = nil) {
        self.remoteControlCore = remoteControlCore
        self.willBeDestroyedCallback = willBeDestroyedCallback
    }

    /// Destructor.
    deinit {
        willBeDestroyedCallback?(self.remoteControlCore)
    }

    /// Gets the remote control name and registers an observer notified each time it changes.
    ///
    /// The observer is called immediately with the current remote control name name and will be called each time it
    /// changes.
    ///
    /// - Parameter observer: observer to notify when the remote control name changes
    /// - Returns: reference to remote control name
    ///
    /// - Seealso: property `name` to get current name without registering an observer
    public func getName(observer: @escaping Ref<String>.Observer) -> Ref<String> {
        return remoteControlCore.getName(observer: observer)
    }

    /// Gets the remote control state and registers an observer notified each time it changes.
    ///
    /// The observer is called immediately with the current remote control state and will be called each time it
    /// changes.
    ///
    /// - Parameter observer: observer to notify when the remote control state changes
    /// - Returns: reference to remote control state
    ///
    /// - Seealso: property state to get current state without registering an observer
    public func getState(observer: @escaping Ref<DeviceState>.Observer) -> Ref<DeviceState> {
        return remoteControlCore.getState(observer: observer)
    }

    /// Forgets the remote control.
    ///
    /// Persisted remote control data are deleted and the remote control is removed from the list of remote control
    /// if it's no more available.
    ///
    /// - Returns: `true` if the remote control has been forgotten, `false` otherwise
    public func forget() -> Bool {
        return remoteControlCore.forget()
    }

    /// Connects the remote control using the best connector.
    ///
    /// - Returns: `true` if the connection process has started
    public func connect() -> Bool {
        return remoteControlCore.connect(connector: nil, password: nil)
    }

    /// Connects the remote control with a specific connector.
    ///
    /// - Parameter connector: connector to use to connect the remote control
    /// - Returns: `true` if the connection process has started
    public func connect(connector: DeviceConnector) -> Bool {
        return remoteControlCore.connect(connector: connector, password: nil)
    }

    /// Connects the remote control with a specific connector, using a password.
    ///
    /// - Parameters:
    ///    - connector: connector to use to connect the remote control
    ///    - password: password to use to connect the remote control
    /// - returns: `true` if the connection process has started
    public func connect(connector: DeviceConnector, password: String) -> Bool {
        return remoteControlCore.connect(connector: connector, password: password)
    }

    /// Disconnects the remote control.
    ///
    /// This method can be use to disconnect the remote control when connected or to cancel the connection process if
    /// the remote control is connecting.
    ///
    /// - Returns: `true` if the disconnection process has started, `false` otherwise
    public func disconnect() -> Bool {
        return remoteControlCore.disconnect()
    }
}

/// Extension that implements the InstrumentProvider protocol.
extension RemoteControl {
    /// Gets an instrument.
    ///
    /// Returns the requested instrument or `nil` if the remote control doesn't have the requested instrument
    /// or if the instrument is not available in the current connection state.
    ///
    /// - Parameter desc: requested instrument. See `Instruments` api for available descriptors instances.
    /// - Returns: requested instrument
    public func getInstrument<Desc: InstrumentClassDesc>(_ desc: Desc) -> Desc.ApiProtocol? {
        return remoteControlCore.getInstrument(desc)
    }

    /// Get san instrument and registers an observer notified each time it changes.
    ///
    /// If the instrument is present, the observer will be called immediately with. If the instrument is not present,
    /// the observer won't be called until the instrument is added to the remote control.
    /// If the instrument or the remote control are removed, the observer will be notified and referenced value is set
    /// to `nil`.
    ///
    /// - Parameters:
    ///    - desc: requested instrument. See `Instruments` api for available descriptors instances
    ///    - observer: observer to notify when the instrument changes
    /// - Returns: reference to the requested instrument
    public func getInstrument<Desc: InstrumentClassDesc>(_ desc: Desc,
                              observer: @escaping Ref<Desc.ApiProtocol>.Observer) -> Ref<Desc.ApiProtocol> {
        return remoteControlCore.getInstrument(desc, observer: observer)
    }
}

/// Extension that implements the PeripheralProvider protocol.
extension RemoteControl {
    /// Gets a peripheral.
    ///
    /// Returns the requested peripheral or `nil` if the remote control doesn't have the requested peripheral
    /// or if the peripheral is not available in the current connection state.
    ///
    /// - Parameter desc: requested peripheral. See `Peripherals` api for available descriptors instances.
    /// - Returns: requested peripheral
    public func getPeripheral<Desc: PeripheralClassDesc>(_ desc: Desc) -> Desc.ApiProtocol? {
        return remoteControlCore.getPeripheral(desc)
    }

    /// Gets a peripheral and registers an observer notified each time it changes.
    ///
    /// If the peripheral is present, the observer will be called immediately with. If the peripheral is not present,
    /// the observer won't be called until the peripheral is added to the remote control.
    /// If the peripheral or the remote control are removed, the observer will be notified and referenced value is set
    /// to `nil`.
    ///
    /// - Parameters:
    ///    - desc: requested peripheral. See `Peripherals` api for available descriptors instances.
    ///    - observer: observer to notify when the peripheral changes
    /// - Returns: reference to the requested peripheral
    public func getPeripheral<Desc: PeripheralClassDesc>(_ desc: Desc,
                              observer: @escaping Ref<Desc.ApiProtocol>.Observer) -> Ref<Desc.ApiProtocol> {
        return remoteControlCore.getPeripheral(desc, observer: observer)
    }
}

/// Extension that add components getter from id, returning the basic type.
/// This is used by Objective-C extension for components accessors.
extension RemoteControl {

    /// Gets an instrument.
    ///
    /// - Parameter uid: requested instrument uid
    /// - Returns: requested instrument
    func getInstrument(uid: Int) -> Instrument? {
        return remoteControlCore.getInstrument(uid: uid)
    }

    /// Gets an instrument and registers an observer notified each time it changes.
    ///
    /// - Parameters:
    ///    - uid: requested instrument uid
    ///    - observer: observer to notify when the instrument changes
    /// - Returns: reference to the requested instrument
    func getInstrument(uid: Int, observer: @escaping (Instrument?) -> Void) -> Ref<Instrument> {
        return remoteControlCore.getInstrument(uid: uid, observer: observer)
    }

    /// Gets a peripheral.
    ///
    /// Returns the requested peripheral or `nil` if the remote control doesn't have the requested peripheral, or if the
    /// peripheral is not available in the current connection state.
    ///
    /// - Parameter uid: requested peripheral uid
    /// - Returns: requested peripheral
    func getPeripheral(uid: Int) -> Peripheral? {
        return remoteControlCore.getPeripheral(uid: uid)
    }

    /// Gets a peripheral and registers an observer notified each time it changes.
    ///
    /// If the peripheral is present, the observer will be called immediately with. If the peripheral is not present,
    /// the observer won't be called until the peripheral is added to the remote control.
    /// If the peripheral or the remote control are removed, the observer will be notified and referenced value is set
    /// to `nil`.
    ///
    /// - Parameters:
    ///    - uid: requested peripheral uid
    ///    - observer: observer to notify when the peripheral changes
    /// - Returns: reference to the requested peripheral
    func getPeripheral(uid: Int, observer: @escaping (Peripheral?) -> Void) -> Ref<Peripheral> {
        return remoteControlCore.getPeripheral(uid: uid, observer: observer)
    }
}

/// Objective-C extension adding GroundSdk swift methods that can't be automatically converted.
/// Those methods should no be used from swift.
public extension RemoteControl {

    /// Gets the remote control name and registers an observer notified each time it changes.
    ///
    /// If the remote control is removed, the observer will be notified and the referenced value is set to `nil`.
    ///
    /// - Parameter observer: observer to notify when the remote control name changes
    /// - Returns: reference to remote control name
    ///
    /// - Note: This method is for Objective-C only. Swift must use `func getName:observer`.
    /// - Seealso: property `name` to get current name without registering an observer
    @objc(getNameRef:)
    func getNameRef(observer: @escaping (String?) -> Void) -> GSNameRef {
        return GSNameRef(ref: getName(observer: observer))
    }

    /// Gets the remote control state and registers an observer notified each time it changes.
    ///
    /// If the remote control is removed, the observer will be notified and the referenced value is set to `nil`.
    ///
    /// - Parameter observer: observer to notify when the remote control state changes
    /// - Returns: reference to remote control state
    ///
    /// - Note: This method is for Objective-C only. Swift must use `func getState:observer`.
    /// - Seealso: property state to get current state without registering an observer
    @objc(getStateRef:)
    func getStateRef(observer: @escaping (DeviceState?) -> Void) -> GSDeviceStateRef {
        return GSDeviceStateRef(ref: getState(observer: observer))
    }

    /// Gets an instrument.
    ///
    /// - Parameter desc: requested instrument. See `Instruments` api for available descriptors instances.
    /// - Returns: requested instrument
    /// - Note: This method is for Objective-C only. Swift must use `func getInstrument:`.
    @objc(getInstrument:)
    func getInstrument(desc: ComponentDescriptor) -> Instrument? {
        return getInstrument(uid: desc.uid)
    }

    /// Gets a instrument and registers an observer notified each time it changes.
    ///
    /// - Parameters:
    ///    - desc: requested instrument. See `Instruments` api for available descriptors instances.
    ///    - observer: observer to notify when the instrument changes
    /// - Returns: reference to the requested instrument
    /// - Note: this method is for Objective-C only. Swift must use `func getInstrument:desc:observer`.
    @objc(getInstrument:observer:)
    func getInstrumentRef(desc: ComponentDescriptor, observer: @escaping (Instrument?) -> Void)
        -> GSInstrumentRef {
            return GSInstrumentRef(ref: getInstrument(uid: desc.uid, observer: observer))
    }

    /// Gets a peripheral.
    ///
    /// - Parameter desc: requested peripheral. See `Peripherals` api for available descriptors instances.
    /// - Returns: requested peripheral
    /// - Note: This method is for Objective-C only. Swift must use `func getPeripheral:`.
    @objc(getPeripheral:)
    func getPeripheral(desc: ComponentDescriptor) -> Peripheral? {
        return getPeripheral(uid: desc.uid)
    }

    /// Gets a peripheral and registers an observer notified each time it changes.
    ///
    /// - Parameters:
    ///    - desc: requested peripheral. See `Peripherals` api for available descriptors instances.
    ///    - observer: observer to notify when the peripheral changes
    /// - Returns: reference to the requested peripheral
    /// - Note: This method is for Objective-C only. Swift must use `func getPeripheral:desc:observer`.
    @objc(getPeripheral:observer:)
    func getPeripheralRef(desc: ComponentDescriptor, observer: @escaping (Peripheral?) -> Void)
        -> GSPeripheralRef {
            return GSPeripheralRef(ref: getPeripheral(uid: desc.uid, observer: observer))
    }
}
