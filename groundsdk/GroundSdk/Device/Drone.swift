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

/// Generic drone.
@objcMembers
@objc(GSDrone)
public class Drone: NSObject, PilotingItfProvider, InstrumentProvider, PeripheralProvider {

    /// Drone model.
    @objc(GSDroneModel)
    public enum Model: Int, CustomStringConvertible {
        // Anafi family
        /// Anafi 4K drone.
        case anafi4k
        /// Anafi Thermal.
        case anafiThermal
        /// Anafi UA.
        case anafiUa
        /// Anafi USA.
        case anafiUsa

        /// Internal unique identifier.
        public var internalId: Int {
            switch self {
            case .anafi4k:      return 0x0914
            case .anafiThermal: return 0x0919
            case .anafiUa:      return 0x091b
            case .anafiUsa:     return 0x091e
            }
        }

        /// Debug description.
        public var description: String {
            switch self {
            case .anafi4k:      return "anafi4k"
            case .anafiThermal: return "anafiThermal"
            case .anafiUa:      return "anafiUa"
            case .anafiUsa:     return "anafiUsa"
            }
        }

        /// Set containing all possible values of drone model.
        static let allCases: Set<Model> = [.anafi4k, .anafiThermal, .anafiUa, .anafiUsa]
    }

    /// Drone unique identifier, persistant between sessions.
    public var uid: String {
        return droneCore.uid
    }

    /// Drone model.
    public var model: Model {
        return droneCore.model
    }

    /// Drone name.
    public var name: String {
        return droneCore.nameHolder.name
    }

    /// Drone state.
    public var state: DeviceState {
        return droneCore.stateHolder.state
    }

    /// Debug description.
    override public var description: String {
        return "Drone \(uid): name = \(name); model = \(model)"
    }

    /// Equatable (override the isEqual function because Drone inherits from NSObject)
    override public func isEqual(_ object: Any?) -> Bool {
        if let otherDrone = object as? Drone {
            return self.uid == otherDrone.uid
        } else {
            return false
        }
    }

    /// DroneCore instance backing this Drone.
    private let droneCore: DroneCore

    /// Optional callback to call when this drone is deinit.
    private let willBeDestroyedCallback: ((DroneCore) -> Void)?

    /// Creates a drone with a given drone core.
    ///
    /// - Parameters:
    ///    - droneCore: drone core referenced by this drone
    ///    - willBeDestroyedCallback: optional callback called when the drone is deinit
    internal init(droneCore: DroneCore, willBeDestroyedCallback: ((DroneCore) -> Void)? = nil) {
        self.droneCore = droneCore
        self.willBeDestroyedCallback = willBeDestroyedCallback
    }

    /// Destructor.
    deinit {
        willBeDestroyedCallback?(self.droneCore)
    }

    /// Gets the drone name and registers an observer notified each time it changes.
    ///
    /// The observer is called immediately with the current drone name and will be called each time it changes.
    ///
    /// - Parameter observer: observer to notify when the drone name changes
    /// - Returns: reference to drone name
    ///
    /// - Seealso: property `name` to get current name without registering an observer
    public func getName(observer: @escaping Ref<String>.Observer) -> Ref<String> {
        return droneCore.getName(observer: observer)
    }

    /// Gets the drone state and registers an observer notified each time it changes.
    ///
    /// The observer is called immediately with the current drone state and will be called each time it changes.
    ///
    /// - Parameter observer: observer to notify when the drone state changes
    /// - Returns: reference to drone state
    ///
    /// - Seealso: property state to get current state without registering an observer
    public func getState(observer: @escaping Ref<DeviceState>.Observer) -> Ref<DeviceState> {
        return droneCore.getState(observer: observer)
    }

    /// Forgets the drone.
    ///
    /// Persisted drone data are deleted and the drone is removed from the list of drones if it's no more available.
    ///
    /// - Returns: `true` if the drone has been forgotten, `false` otherwise
    public func forget() -> Bool {
        return droneCore.forget()
    }

    /// Connects the drone.
    ///
    /// - Parameter connector: connector to use to connect the drone
    /// - Returns: `true` if the connection process has started
    public func connect(connector: DeviceConnector) -> Bool {
        return droneCore.connect(connector: connector, password: nil)
    }

    /// Connects the drone with a password.
    ///
    /// - Parameters:
    ///    - connector: connector to use to connect the drone
    ///    - password: password to connect the drone
    /// - Returns: `true` if the connection process has started
    public func connect(connector: DeviceConnector, password: String) -> Bool {
        return droneCore.connect(connector: connector, password: password)
    }

    /// Connects the drone using the best connector.
    ///
    /// - Returns: `true` if the connection process has started, `false` otherwise.
    public func connect() -> Bool {
        return droneCore.connect(connector: nil, password: nil)
    }

    /// Disconnects the drone.
    ///
    /// This method can be use to disconnect the drone when connected or to cancel the connection process if the drone
    /// is connecting.
    ///
    /// - Returns: `true` if the disconnection process has started, `false` otherwise.
    public func disconnect() -> Bool {
        return droneCore.disconnect()
    }
}

/// Extension that implements the PilotingItfProvider protocol.
extension Drone {
    /// Gets a piloting interface.
    ///
    /// Return the requested piloting interface or `nil` if the drone doesn't have the requested piloting interface,
    /// or if the piloting interface is not available in the current connection state.
    ///
    /// - Parameter desc: requested piloting interface. See `PilotingItfs` api for available descriptors instances.
    /// - Returns: requested piloting interface
    public func getPilotingItf<Desc: PilotingItfClassDesc>(_ desc: Desc) -> Desc.ApiProtocol? {
        return droneCore.getPilotingItf(desc)
    }

    /// Gets a piloting interface and registers an observer notified each time it changes.
    ///
    /// If the piloting interface is present, the observer will be called immediately with. If the piloting interface is
    /// not present, the observer won't be called until the piloting interface is added to the drone.
    /// If the piloting interface or the drone are removed, the observer will be notified and referenced value is set to
    /// `nil`.
    ///
    /// - Parameters:
    ///    - desc: requested piloting interface. See `PilotingItfs` api for available descriptors instances.
    ///    - observer: observer to notify when the piloting interface changes
    /// - Returns: reference to the requested piloting interface
    public func getPilotingItf<Desc: PilotingItfClassDesc>(_ desc: Desc,
                               observer: @escaping Ref<Desc.ApiProtocol>.Observer) -> Ref<Desc.ApiProtocol> {
        return droneCore.getPilotingItf(desc, observer: observer)
    }
}

/// Extension that implements the InstrumentProvider protocol.
extension Drone {
    /// Gets an instrument.
    ///
    /// Returns the requested instrument or `nil` if the drone doesn't have the requested instrument
    /// or if the instrument is not available in the current connection state.
    ///
    /// - Parameter desc: requested instrument. See `Instruments` api for available descriptors instances.
    /// - Returns: requested instrument
    public func getInstrument<Desc: InstrumentClassDesc>(_ desc: Desc) -> Desc.ApiProtocol? {
        return droneCore.getInstrument(desc)
    }

    /// Gets an instrument and registers an observer notified each time it changes.
    ///
    /// If the instrument is present, the observer will be called immediately with. If the instrument is not present,
    /// the observer won't be called until the instrument is added to the drone.
    /// If the instrument or the drone are removed, the observer will be notified and referenced value is set to `nil`.
    ///
    /// - Parameters:
    ///    - desc: requested instrument. See `Instruments` api for available descriptors instances.
    ///    - observer: observer to notify when the instrument changes
    /// - Returns: reference to the requested instrument
    public func getInstrument<Desc: InstrumentClassDesc>(_ desc: Desc,
                              observer: @escaping Ref<Desc.ApiProtocol>.Observer) -> Ref<Desc.ApiProtocol> {
        return droneCore.getInstrument(desc, observer: observer)
    }
}

/// Extension that implements the PeripheralProvider protocol.
extension Drone {
    /// Gets a peripheral.
    ///
    /// Returns the requested peripheral or `nil` if the drone doesn't have the requested peripheral
    /// or if the peripheral is not available in the current connection state.
    ///
    /// - Parameter desc: requested peripheral. See `Peripherals` api for available descriptors instances.
    /// - Returns: requested peripheral
    public func getPeripheral<Desc: PeripheralClassDesc>(_ desc: Desc) -> Desc.ApiProtocol? {
        return droneCore.getPeripheral(desc)
    }

    /// Gets a peripheral and registers an observer notified each time it changes.
    ///
    /// If the peripheral is present, the observer will be called immediately with. If the peripheral is not present,
    /// the observer won't be called until the peripheral is added to the drone.
    /// If the peripheral or the drone are removed, the observer will be notified and referenced value is set to `nil`.
    ///
    /// - Parameters:
    ///    - desc: requested peripheral. See `Peripherals` api for available descriptors instances.
    ///    - observer: observer to notify when the peripheral changes
    /// - Returns: reference to the requested peripheral
    public func getPeripheral<Desc: PeripheralClassDesc>(_ desc: Desc,
                              observer: @escaping Ref<Desc.ApiProtocol>.Observer) -> Ref<Desc.ApiProtocol> {
        return droneCore.getPeripheral(desc, observer: observer)
    }
}

/// Extension that add components getter from id, returning the basic type.
/// This is used by Objective-C extension for components accessors.
extension Drone {
    /// Gets an instrument.
    ///
    /// - Parameter uid: requested instrument uid
    /// - Returns: requested instrument
    func getInstrument(uid: Int) -> Instrument? {
        return droneCore.getInstrument(uid: uid)
    }

    /// Gets an instrument and registers an observer notified each time it changes.
    ///
    /// - Parameters:
    ///    - uid: requested instrument uid
    ///    - observer: observer to notify when the instrument changes
    /// - Returns: reference to the requested instrument
    func getInstrument(uid: Int, observer: @escaping (Instrument?) -> Void) -> Ref<Instrument> {
        return droneCore.getInstrument(uid: uid, observer: observer)
    }

    /// Gets a piloting interface.
    ///
    /// Return sthe requested piloting interface or `nil` if the drone doesn't have the requested piloting interface,
    /// or if the piloting interface is not available in the current connection state.
    ///
    /// - Parameter uid: requested piloting interface uid
    /// - Returns: requested piloting interface
    func getPilotingItf(uid: Int) -> PilotingItf? {
        return droneCore.getPilotingItf(uid: uid)
    }

    /// Gets a piloting interface and registers an observer notified each time it changes.
    ///
    /// If the piloting interface is present, the observer will be called immediately with. If the piloting interface is
    /// not present, the observer won't be called until the piloting interface is added to the drone.
    /// If the piloting interface or the drone are removed, the observer will be notified and referenced value is set to
    /// `nil`.
    ///
    /// - Parameters:
    ///    - uid: requested piloting interface uid
    ///    - observer: observer to notify when the piloting interface changes
    /// - Returns: reference to the requested piloting interface
    func getPilotingItf(uid: Int, observer: @escaping (PilotingItf?) -> Void) -> Ref<PilotingItf> {
        return droneCore.getPilotingItf(uid: uid, observer: observer)
    }

    /// Gets a peripheral.
    ///
    /// Return the requested peripheral or `nil` if the drone doesn't have the requested peripheral
    /// or if the peripheral is not available in the current connection state.
    ///
    /// - Parameter uid: requested peripheral uid
    /// - Returns: requested peripheral
    func getPeripheral(uid: Int) -> Peripheral? {
        return droneCore.getPeripheral(uid: uid)
    }

    /// Gets a peripheral and registers an observer notified each time it changes.
    ///
    /// If the peripheral is present, the observer will be called immediately with. If the peripheral is not present,
    /// the observer won't be called until the peripheral is added to the drone.
    /// If the peripheral or the drone are removed, the observer will be notified and referenced value is set to `nil`.
    ///
    /// - Parameters:
    ///    - uid: requested peripheral uid
    ///    - observer: observer to notify when the peripheral changes
    /// - Returns: reference to the requested peripheral
    func getPeripheral(uid: Int, observer: @escaping (Peripheral?) -> Void) -> Ref<Peripheral> {
        return droneCore.getPeripheral(uid: uid, observer: observer)
    }
}

/// Objective-C extension adding GroundSdk swift methods that can't be automatically converted.
/// Those methods should no be used from swift.
public extension Drone {

    /// Gets the drone name and registers an observer notified each time it changes.
    ///
    /// If the drone is removed, the observer will be notified and the referenced value is set to `nil`.
    ///
    /// - Parameter observer: observer to notify when the drone name changes
    /// - Returns: reference to drone name
    ///
    /// - Note: This method is for Objective-C only. Swift must use `func getName:observer`.
    /// - Seealso: property `name` to get current name without registering an observer
    @objc(getNameRef:)
    func getNameRef(observer: @escaping (String?) -> Void) -> GSNameRef {
        return GSNameRef(ref: getName(observer: observer))
    }

    /// Gets the drone state and registers an observer notified each time it changes
    ///
    /// If the drone is removed, the observer will be notified and the referenced value is set to `nil`.
    ///
    /// - Parameter observer: observer to notify when the drone state changes
    /// - Returns: reference to drone state
    ///
    /// - Note: This method is for Objective-C only. Swift must use `func getState:observer`.
    /// - Seealso: property state to get current state without registering an observer
    @objc(getStateRef:)
    func getStateRef(observer: @escaping (DeviceState?) -> Void) -> GSDeviceStateRef {
        return GSDeviceStateRef(ref: getState(observer: observer))
    }

    /// Wrapper around a Set of `GSDroneModel`.
    /// This is only for Objective-C use.
    @objc
    class GSDroneModelSet: NSObject {
        // Backing set that contains the drone models.
        private let set: Set<Drone.Model>

        /// Constructor.
        ///
        /// - Parameter models: list of all drone models
        init(models: Drone.Model...) {
            set = Set(models)
        }

        /// Swift constructor.
        ///
        /// - Parameter modelSet: set of all drone models
        init(modelSet: Set<Drone.Model>) {
            set = modelSet
        }

        /// Tells whether a given drone model is contained in the set.
        ///
        /// - Parameter model: drone model
        /// - Returns: `true` if the set contains the drone model
        public func contains(_ model: Drone.Model) -> Bool {
            return set.contains(model)
        }
    }
}

/// Extension that implements the InstrumentProvider protocol for the Objective-C API.
extension Drone: GSInstrumentProvider {
    /// Gets an instrument.
    ///
    /// - Parameter desc: requested instrument. See `Instruments` api for available descriptors instances.
    /// - Returns: requested instrument
    /// - Note: This method is for Objective-C only. Swift must use `func getInstrument:`.
    public func getInstrument(desc: ComponentDescriptor) -> Instrument? {
        return getInstrument(uid: desc.uid)
    }

    /// Gets an instrument and registers an observer notified each time it changes.
    ///
    /// - Parameters:
    ///    - desc: requested instrument. See `Instruments` api for available descriptors instances
    ///    - observer: observer to notify when the instrument changes
    /// - Returns: reference to the requested instrument
    /// - Note: This method is for Objective-C only. Swift must use `func getInstrument:desc:observer`.
    public func getInstrumentRef(desc: ComponentDescriptor, observer: @escaping (Instrument?) -> Void)
        -> GSInstrumentRef {
            return GSInstrumentRef(ref: getInstrument(uid: desc.uid, observer: observer))
    }
}

/// Extension that implements the PeripheralProvider protocol for the Objective-C API.
extension Drone: GSPeripheralProvider {
    /// Gets a peripheral.
    ///
    /// - Parameter desc: requested peripheral. See `Peripherals` api for available descriptors instances
    /// - Returns: requested peripheral
    /// - Note: This method is for Objective-C only. Swift must use `func getPeripheral:`.
    public func getPeripheral(desc: ComponentDescriptor) -> Peripheral? {
        return getPeripheral(uid: desc.uid)
    }

    /// Gets a peripheral and registers an observer notified each time it changes.
    ///
    /// - Parameters:
    ///    - desc: requested peripheral. See `Peripherals` api for available descriptors instances.
    ///    - observer: observer to notify when the peripheral changes
    /// - Returns: reference to the requested peripheral
    /// - Note: This method is for Objective-C only. Swift must use `func getPeripheral:desc:observer`.
    public func getPeripheralRef(desc: ComponentDescriptor, observer: @escaping (Peripheral?) -> Void)
        -> GSPeripheralRef {
            return GSPeripheralRef(ref: getPeripheral(uid: desc.uid, observer: observer))
    }
}

/// Extension that implements the PilotingItfProvider protocol for the Objective-C API.
extension Drone: GSPilotingItfProvider {
    /// Gets a piloting interface.
    ///
    /// - Parameter desc: requested piloting interface. See `PilotingItfs` api for available descriptors instances.
    /// - Returns: requested piloting interface
    /// - Note: This method is for Objective-C only. Swift must use `func getPilotingItf:`.
    @objc(getPilotingItf:)
    public func getPilotingItf(desc: ComponentDescriptor) -> PilotingItf? {
        return getPilotingItf(uid: desc.uid)
    }

    /// Gets a piloting interface and registers an observer notified each time it changes.
    ///
    /// - Parameters:
    ///    - desc: requested piloting interface. See `PilotingItfs` api for available descriptors instances.
    ///    - observer: observer to notify when the piloting interface changes
    /// - Returns: reference to the requested piloting interface
    /// - Note: this method is for Objective-C only. Swift must use `func getPilotingItf:desc:observer`.
    @objc(getPilotingItf:observer:)
    public func getPilotingItfRef(desc: ComponentDescriptor, observer: @escaping (PilotingItf?) -> Void)
        -> GSPilotingItfRef {
            return GSPilotingItfRef(ref: getPilotingItf(uid: desc.uid, observer: observer))
    }
}
