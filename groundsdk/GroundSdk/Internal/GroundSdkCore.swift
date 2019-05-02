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

/// SDK internal entry point. This class is a singleton.
public class GroundSdkCore: NSObject {

    /// GroundSdk client connection
    class Session: NSObject {

        /// Client ref
        /// This is a weak reference to detect if a client forget to unbind a GroundSdk instance
        /// This might not happen as unbind call is in the deinit function of GroundSdk
        private weak var clientRef: NSObject?

        /// Init a session with a client ref
        ///
        /// - Parameter clientRef: The reference to the client. The ref should call unbind before destroying itself
        init(clientRef: NSObject) {
            self.clientRef = clientRef
        }

        /// Unbind the session from the GroundSdkCore
        /// Should be called before the clientRef destroys itself
        func unbind() {
            // unbind from ground sdk
            GroundSdkCore.getInstance().unbind(session: self)
        }

        /// Get a list of known drones and register an observer notified each time this list changes
        ///
        /// - Parameters:
        ///    - observer: observer notified each time this list changes
        ///    - filter: drone filter to select drones to include into the returned list
        /// - Returns: A reference to the requested list.
        func getDroneList(observer: @escaping Ref<[DroneListEntry]>.Observer,
                          filter: @escaping (DroneListEntry) -> Bool) -> Ref<[DroneListEntry]> {
            return DroneListRefCore(store: GroundSdkCore.getInstance().droneStore, filter: filter,
                                    observer: observer)
        }

        /// Gets a drone by uid
        ///
        /// - Parameter uid: requested drone uid
        /// - Returns: a drone with the requested uid, or null if not found
        func getDrone(uid: String) -> Drone? {
            if let droneCore = GroundSdkCore.getInstance().droneStore.getDevice(uid: uid) {
                return Drone(droneCore: droneCore)
            }
            return nil
        }

        /// Gets a drone by uid
        ///
        /// - Parameters:
        ///    - uid: requested drone uid
        ///    - removedCallback: closure called when the drone is removed from the store
        /// - Returns: a drone with the requested uid, or null if not found
        func getDrone(uid: String, removedCallback: @escaping (String) -> Void) -> Drone? {
            let droneStore = GroundSdkCore.getInstance().droneStore
            if let droneCore = droneStore.getDevice(uid: uid) {
                let monitor = droneStore.startMonitoring(didRemoveDevice: { drone in
                    if drone.uid == uid {
                        removedCallback(uid)
                    }
                })
                return Drone(droneCore: droneCore) { _ in
                    monitor.stop()
                }
            }
            return nil
        }

        /// Get a list of known drones and register an observer notified each time this list changes
        ///
        /// - Parameters:
        ///    - observer: observer notified each time this list changes
        ///    - filter: drone filter to select drones to include into the returned list
        /// - Returns: A reference to the requested list.
        func getRemoteControlList(observer: @escaping Ref<[RemoteControlListEntry]>.Observer,
                                  filter: @escaping (RemoteControlListEntry) -> Bool) -> Ref<[RemoteControlListEntry]> {
            return RemoteControlListRefCore(store: GroundSdkCore.getInstance().rcStore, filter: filter,
                                            observer: observer)
        }

        /// Gets a remote control by uid
        ///
        /// - Parameter uid: requested remote control uid
        /// - Returns: a remote control with the requested uid, or null if not found
        func getRemoteControl(uid: String) -> RemoteControl? {
            if let remoteControlCore = GroundSdkCore.getInstance().rcStore.getDevice(uid: uid) {
                return RemoteControl(remoteControlCore: remoteControlCore)
            }
            return nil
        }

        /// Gets a remote control by uid
        ///
        /// - Parameters:
        ///    - uid: requested remote control uid
        ///    - removedCallback: closure called when the remote control is removed from the store
        /// - Returns: a remote control with the requested uid, or null if not found
        func getRemoteControl(uid: String, removedCallback: @escaping (String) -> Void) -> RemoteControl? {
            let rcStore = GroundSdkCore.getInstance().rcStore
            if let remoteControlCore = rcStore.getDevice(uid: uid) {
                let monitor = rcStore.startMonitoring(didRemoveDevice: { remoteControl in
                    if remoteControl.uid == uid {
                        removedCallback(uid)
                    }
                })
                return RemoteControl(remoteControlCore: remoteControlCore) {  _ in
                    monitor.stop()
                }
            }
            return nil
        }

        /// Gets a facility.
        ///
        /// Return the requested facility or nil if the facility is not available yet.
        ///
        /// - Parameter desc: requested facility. See `Facilities` api for available descriptors instances
        /// - Returns: requested facility
        func getFacility<Desc: FacilityClassDesc>(_ desc: Desc) -> Desc.ApiProtocol? {
            return GroundSdkCore.getInstance().facilityStore.get(desc)
        }

        /// Gets a facility and register an observer notified each time it changes.
        ///
        /// If the facility is present, the observer will be called immediately with. If the facility is not present,
        /// the observer won't be called until the facility is added.
        /// If the facility is removed, the observer will be notified and referenced value is set to nil.
        ///
        /// - Parameters:
        ///    - desc: requested facility. See `Facilities` api for available descriptors instances
        ///    - observer: observer to notify when the facility changes
        /// - Returns: reference to the requested facility
        func getFacility<Desc: FacilityClassDesc>(
            _ desc: Desc, observer: @escaping Ref<Desc.ApiProtocol>.Observer) -> Ref<Desc.ApiProtocol> {
            return ComponentRefCore(store: GroundSdkCore.getInstance().facilityStore, desc: desc, observer: observer)
        }

        /// Gets a facility.
        ///
        /// - Parameter uid: requested facility uid
        /// - Returns: reference to the requested facility
        func getFacility(uid: Int) -> Facility? {
            return GroundSdkCore.getInstance().facilityStore.get(uid: uid)
        }

        /// Gets a facility and register an observer notified each time it changes.
        ///
        /// - Parameters:
        ///    - uid: requested facility uid
        ///    - observer: observer to notify when the facility changes
        /// - Returns: reference to the requested facility
        func getFacility(uid: Int, observer: @escaping (Facility?) -> Void) -> Ref<Facility> {
            return ComponentUidRefCore<Facility>(store: GroundSdkCore.getInstance().facilityStore,
                                                 uid: uid, observer: observer)
        }

        /// Create a new replay stream for a local file.
        ///
        /// - Parameters:
        ///    - source: source to stream
        ///    - observer: notified when the stream state changes
        /// - Returns: a reference to the replay stream interface,
        ///            or 'nil' in case the provided file cannot be streamed
        func newFileReplay(source: FileReplaySource,
                           observer: @escaping (_ stream: FileReplay?) -> Void) -> Ref<FileReplay>? {
            let fileReplayCore = FileReplayCore(source: source)
            return FileReplayRefCore(stream: fileReplayCore, observer: observer)
        }
    }

    /// Singleton instance
    static private var sharedInstance: GroundSdkCore?

    /// List of all existing sessions
    /// If empty, all engines should be stopped
    private var sessions: Set<Session> = []

    /// Drone store
    private let droneStore = DroneStoreUtilityCore()

    /// Remote control store
    private let rcStore = RemoteControlStoreUtilityCore()

    /// Utility registry
    let utilities = UtilityCoreRegistry()

    /// Facility store
    let facilityStore = ComponentStoreCore()

    /// Engine controller managing all implementation of engines
    private var enginesController: EnginesControllerCore!

    /// Get the current instance of the GroundSdkCore
    /// If no instance is available, create one
    ///
    /// - Returns: an instance of GroundSdkCore
    static func getInstance() -> GroundSdkCore {
        // TODO: synchronize
        if sharedInstance == nil {
            sharedInstance = GroundSdkCore()
        }
        return sharedInstance!
    }

    /// Constructor
    override init() {
        GroundSdkConfig.sharedInstance.lock()
        super.init()

        // register utilities
        utilities.publish(utility: droneStore)
        utilities.publish(utility: rcStore)

        enginesController = makeEnginesController(utilityRegistry: utilities, facilityStore: facilityStore)
    }

    /// Bind a GroundSdk object
    ///
    /// If it is the first session to be created, start all engines
    ///
    /// Unbind should be called when the session is not used anymore
    ///
    /// - Parameter groundSdk: The GroundSdk object that will use the GroundSdkCore
    /// - Returns: the session which is stored and which has to be unbinded
    func bind(_ groundSdk: GroundSdk) -> Session {
        if sessions.isEmpty {
            enginesController.start()
        }
        let session = Session(clientRef: groundSdk)
        sessions.insert(session)
        return session
    }

    /// Factory function to create the EnginesControllerCore
    /// This is to allow mocking engine controller for unit tests
    ///
    /// - Parameters:
    ///   - utilityRegistry: utility registry
    ///   - facilityStore: facility store
    /// - Returns: the newly created EnginesControllerCore
    func makeEnginesController(utilityRegistry: UtilityCoreRegistry,
                               facilityStore: ComponentStoreCore) -> EnginesControllerCore {
        return EnginesControllerCore(utilityRegistry: utilityRegistry, facilityStore: facilityStore)
    }

    /// Unbind a binded session
    ///
    /// If the given session is the last session binded, stop all engines
    ///
    /// - Parameter session: the session to unbind
    private func unbind(session: Session) {
        while sessions.contains(session) {
            sessions.remove(session)
        }
        if sessions.isEmpty {
            enginesController.stop()
        }
    }
}

// Extension that brings useful functions for tests
extension GroundSdkCore {
    /// Set itself as the shared instance
    /// Should only be used by tests
    func setAsInstance() {
        GroundSdkCore.sharedInstance = self
    }

    /// Close GroundSdkCore
    /// Should only be used by tests
    func close() {
        GroundSdkCore.sharedInstance = nil
    }
}
