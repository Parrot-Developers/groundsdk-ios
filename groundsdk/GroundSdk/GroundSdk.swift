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

/// Ground SDK access class.
@objcMembers
public class GroundSdk: NSObject {
    /// Session used as an interface to access the GroundSdkCore.
    private var session: GroundSdkCore.Session!

    /// Completion handlers indexed by URLSession identifiers.
    static private(set) var backgroundTaskCompletionHandlers: [String: () -> Void] = [:]

    /// Creates a GroundSdk instance.
    public override init() {
        super.init()
        // bind to the GroundSdkCore
        session = GroundSdkCore.getInstance().bind(self)
    }

    deinit {
        // unbind from the GroundSdkCore
        session.unbind()
    }

    /// Gets a list of known drones and register an observer notified each time this list changes.
    ///
    /// - Parameters:
    ///    - observer: observer notified each time this list changes
    ///    - filter: drone filter to select drones to include into the returned list. The filter criteria must
    ///              not change during the list reference lifecycle.
    ///              By default, the filter accepts all drones.
    /// - Returns: a reference to the requested list
    public func getDroneList(
        observer: @escaping Ref<[DroneListEntry]>.Observer,
        filter: @escaping (DroneListEntry) -> Bool = { _ in return true }) -> Ref<[DroneListEntry]> {

        return session.getDroneList(observer: observer, filter: filter)
    }

    /// Gets a drone by uid.
    ///
    /// - Parameter uid: uid of the desired drone
    /// - Returns: a drone if found, `nil` otherwise
    public func getDrone(uid: String) -> Drone? {
        return session.getDrone(uid: uid)
    }

    /// Gets a drone by uid and register a callback called when the drone has disappeared.
    ///
    /// - Parameters:
    ///    - uid: uid of the desired drone
    ///    - removedCallback: closure called when the drone is removed. Never called if the requested drone
    ///                       doesn't exists (i.e. when this function returns `nil`).
    /// - Returns: a drone if found, `nil` otherwise
    ///
    /// - Warning: removedCallback is called as long as the returned Drone instance is referenced.
    ///            When the drone instance is deinit, the callback is unregistered and is never called.
    public func getDrone(uid: String, removedCallback: @escaping (String) -> Void) -> Drone? {
        return session.getDrone(uid: uid, removedCallback: removedCallback)
    }

    /// Forgets a drone identified by it's uid.
    ///
    /// Persisted drone data are deleted and the drone is removed from the list of drones if it's not visible.
    ///
    /// - Parameter uid: uid of the drone to forget
    /// - Returns: `true` if the drone has been forgotten, `false` otherwise
    public func forgetDrone(uid: String) -> Bool {
        if let drone = session.getDrone(uid: uid) {
            return drone.forget()
        }
        return false
    }

    /// Connects a drone identified by it's uid using a connector.
    ///
    /// - Parameters:
    ///    - uid: uid of the drone to connect
    ///    - connector: connector to use to connect the drone
    /// - Returns: `true` if the connection process has started,
    ///            `false` otherwise, for example if the drone is no more visible.
    public func connectDrone(uid: String, connector: DeviceConnector) -> Bool {
        if let drone = session.getDrone(uid: uid) {
            return drone.connect(connector: connector)
        }
        return false
    }

    /// Connects a drone identified by it's uid using a connector, with a password.
    ///
    /// - Parameters:
    ///    - uid: uid of the drone to connect
    ///    - connector: connector to use to connect the drone
    ///    - password: password to connect the drone.
    /// - Returns: `true` if the connection process has started,
    ///            `false` otherwise, for example if the drone is no more visible.
    public func connectDrone(uid: String, connector: DeviceConnector, password: String) -> Bool {
        if let drone = session.getDrone(uid: uid) {
            return drone.connect(connector: connector, password: password)
        }
        return false
    }

    /// Connects a drone identified by it's uid using the local connector.
    ///
    /// - Parameter uid: uid of the drone to connect
    /// - Returns: `true` if the connection process has started,
    ///            `false` otherwise, for example if the drone is no more visible.
    public func connectDrone(uid: String) -> Bool {
        if let drone = session.getDrone(uid: uid) {
            return drone.connect()
        }
        return false
    }

    /// Disconnects a drone identified by it's uid.
    ///
    /// - Parameter uid: uid of the drone to disconnect
    /// - Returns: `true` if the disconnection process has started, `false` otherwise.
    public func disconnectDrone(uid: String) -> Bool {
        if let drone = session.getDrone(uid: uid) {
            return drone.disconnect()
        }
        return false
    }

    /// Gets a list of known remote control and register an observer notified each time this list changes.
    ///
    /// - Parameters:
    ///    - observer: observer notified each time this list changes
    ///    - filter: drone filter to select remote control to include into the returned list. The filter criteria
    ///              must not change during the list reference lifecycle.
    ///              By default, the filter accepts all remote controls.
    /// - Returns: a reference to the requested list.
    public func getRemoteControlList(
        observer: @escaping Ref<[RemoteControlListEntry]>.Observer,
        filter: @escaping (RemoteControlListEntry) -> Bool = { _ in return true }) -> Ref<[RemoteControlListEntry]> {

        return session.getRemoteControlList(observer: observer, filter: filter)
    }

    /// Gets a remote control by uid.
    ///
    /// - Parameter uid: uid of the desired remote control
    /// - Returns: a remote control if found, `nil` otherwise
    public func getRemoteControl(uid: String) -> RemoteControl? {
        return session.getRemoteControl(uid: uid)
    }

    /// Gets a remote control by uid and register a callback called when the remote control has disappear.
    ///
    /// - Parameters:
    ///    - uid: uid of the desired remote control
    ///    - removedCallback: closure called when the remote control is removed. Never called if the requested
    ///                       remote control doesn't exists (i.e. when this function returns `nil`).
    /// - Returns: a remote control if found, `nil` otherwise
    ///
    /// - Warning: removedCallback is called as long as the returned remote control instance is referenced.
    ///            When the drone instance is deinit, the callback is unregistered and is never called.
    public func getRemoteControl(uid: String, removedCallback: @escaping (String) -> Void) -> RemoteControl? {
        return session.getRemoteControl(uid: uid, removedCallback: removedCallback)
    }

    /// Forgets a remote control identified by it's uid.
    ///
    /// Persisted remote control data are deleted and the remote control is removed from the list of
    /// remote control if it's not visible.
    ///
    /// - Parameter uid: uid of the remote control to forget
    /// - Returns: `true` if the remote control has been forgotten, `false` otherwise.
    public func forgetRemoteControl(uid: String) -> Bool {
        if let remoteControl = session.getRemoteControl(uid: uid) {
            return remoteControl.forget()
        }
        return false
    }

    /// Connects a remote control identified by it's uid.
    ///
    /// - Parameter uid: uid of the remote control to connect.
    /// - Returns: `true` if the connection process has started,
    ///            `false` otherwise, for example if the remote control is no more visible.
    public func connectRemoteControl(uid: String) -> Bool {
        if let remoteControl = session.getRemoteControl(uid: uid) {
            return remoteControl.connect()
        }
        return false
    }

    /// Disconnects a remote control identified by it's uid.
    ///
    /// - Parameter uid: uid of the remote control to disconnect.
    /// - Returns: `true` if the disconnection process has started, `false` otherwise.
    public func disconnectRemoteControl(uid: String) -> Bool {
        if let remoteControl = session.getRemoteControl(uid: uid) {
            return remoteControl.disconnect()
        }
        return false
    }

    /// Gets a facility.
    ///
    /// - Parameter desc: requested facility. See `Facilities` API for available descriptors instances
    /// - Returns: the requested facility or `nil` if the facility is not yet available.
    public func getFacility<Desc: FacilityClassDesc>(_ desc: Desc) -> Desc.ApiProtocol? {
        return session.getFacility(desc)
    }

    /// Gets a facility and registers an observer notified each time it changes.
    ///
    /// If the facility is present, the observer will be called immediately with. If the facility is not present,
    /// the observer won't be called until the facility is added.
    /// If the facility is removed, the observer will be notified and referenced value is set to `nil`.
    ///
    /// - Parameters:
    ///    - desc: requested facility. See `Facilities` API for available descriptors instances.
    ///    - observer: observer to notify when the facility changes
    /// - Returns: reference to the requested facility
    public func getFacility<Desc: FacilityClassDesc>(
        _ desc: Desc, observer: @escaping Ref<Desc.ApiProtocol>.Observer) -> Ref<Desc.ApiProtocol> {
        return session.getFacility(desc, observer: observer)
    }

    /// Sets completion handler given by the AppDelegate
    /// `application(:handleEventsForBackgroundURLSession:completionHandler:)` function.
    ///
    /// This will ensure background URLSession task completion handlers are called.
    ///
    /// - Parameters:
    ///   - completionHandler: the completion handler
    ///   - identifier: the session identifier
    public static func setBackgroundUrlSessionCompletionHandler(
        _ completionHandler: @escaping () -> Void, forSessionIdentifier identifier: String) {

        backgroundTaskCompletionHandlers[identifier] = completionHandler
    }

    /// Creates a new replay stream for a local file.
    ///
    /// Every successful call to this method creates a new replay stream instance for the given file,
    /// that must be disposed by dereferencing the returned reference once that stream is not needed.
    /// Dereferencing the returned reference automatically stops the referenced media replay stream.
    ///
    /// - Parameters:
    ///    - source: source to stream
    ///    - observer: notified when the stream state changes
    /// - Returns: a reference to the replay stream interface,
    ///            or `nil` in case the provided file cannot be streamed
    public func replay(source: FileReplaySource,
                       observer: @escaping (_ stream: FileReplay?) -> Void) -> Ref<FileReplay>? {
        return session.newFileReplay(source: source, observer: observer)
    }
}

/// Objective-C extension adding GroundSdk swift methods that can't be automatically converted.
/// Those methods should no be used from swift.
public extension GroundSdk {
    /// Get a list of known drones and register an observer notified each time this list changes.
    ///
    /// - Parameter observer: observer notified each time this list changes
    /// - Returns: a reference to the requested list
    ///
    /// - Note: this method is for Objective-C only. Swift must use `getDroneList(observer)`
    @objc(getDroneList:)
    func getDroneListRef(_ observer: @escaping ([DroneListEntry]?) -> Void) -> GSDroneListRef {
        return GSDroneListRef(ref: getDroneList(observer: observer))
    }

    /// Gets a list of known drones and register an observer notified each time this list changes.
    ///
    /// - Parameters:
    ///    - observer: observer notified each time this list changes
    ///    - filter: drone filter to select drones to include into the returned list. The filter criteria must
    ///              not change during the list reference lifecycle.
    /// - Returns: a reference to the requested list
    ///
    /// - Note: this method is for Objective-C only. Swift must use `getDroneList(observer, filter)`
    @objc(getDroneList:filter:)
    func getDroneListRef(_ observer: @escaping ([DroneListEntry]?) -> Void,
                         filter: @escaping (DroneListEntry) -> Bool) -> GSDroneListRef {
        return GSDroneListRef(ref: getDroneList(observer: observer, filter: filter))
    }

    /// Gets a list of known remote controls and register an observer notified each time this list changes.
    ///
    /// - Parameter observer: observer notified each time this list changes
    /// - Returns: a reference to the requested list
    ///
    /// - Note: this method is for Objective-C only. Swift must use `getRemoteControlList(observer)`
    @objc(getRemoteControlList:)
    func getRemoteControlListRef(observer: @escaping ([RemoteControlListEntry]?) -> Void)
        -> GSRemoteControlListRef {
            return GSRemoteControlListRef(ref: getRemoteControlList(observer: observer))
    }

    /// Gets a list of known remote controls and register an observer notified each time this list changes.
    ///
    /// - Parameters:
    ///    - observer: observer notified each time this list changes
    ///    - filter: remote control filter to select remote controls to include into the returned list. The
    ///              filter criteria must not change during the list reference lifecycle.
    /// - Returns: a reference to the requested list
    ///
    /// - Note: this method is for Objective-C only. Swift must use `getRemoteControlList(observer, filter)`
    @objc(getRemoteControlList:filter:)
    func getRemoteControlListRef(observer: @escaping ([RemoteControlListEntry]?) -> Void,
                                 filter: @escaping (RemoteControlListEntry) -> Bool) -> GSRemoteControlListRef {
        return GSRemoteControlListRef(ref: getRemoteControlList(observer: observer, filter: filter))
    }

    /// Gets a facility.
    ///
    /// - Parameter desc: requested facility. See `Facilities` api for available descriptors instances
    /// - Returns: requested facility
    /// - Note: this method is for Objective-C only. Swift must use `func getFacility(:)`
    @objc(getFacility:)
    func getFacility(desc: ComponentDescriptor) -> Facility? {
        return session.getFacility(uid: desc.uid)
    }

    /// Gets a facility and register an observer notified each time it changes.
    ///
    /// If the facility is present, the observer will be called immediately with. If the facility is not present,
    /// the observer won't be called until the facility is added.
    /// If the facility is removed, the observer will be notified and referenced value is set to `nil`.
    ///
    /// - Parameters:
    ///    - desc: requested facility. See `Facilities` api for available descriptors instances
    ///    - observer: observer to notify when the facility changes
    /// - Returns: reference to the requested instrument
    /// - Note: this method is for Objective-C only. Swift must use `func getFacility(:observer:)`
    @objc(getFacility:observer:)
    func getFacilityRef(desc: ComponentDescriptor, observer: @escaping (Facility?) -> Void) -> GSFacilityRef {
        return GSFacilityRef(ref: session.getFacility(uid: desc.uid, observer: observer))
    }

    /// Creates a new replay stream for a local file.
    ///
    /// Every successful call to this method creates a new replay stream instance for the given file,
    /// that must be disposed by dereferencing the returned reference once that stream is not needed.
    /// Dereferencing the returned reference automatically stops the referenced media replay stream.
    ///
    /// - Parameters:
    ///    - source: source to stream
    ///    - observer: notified when the stream state changes
    /// - Returns: a reference to the replay stream interface,
    ///            or `nil` in case the provided file cannot be streamed
    @objc(replay:observer:)
    func replayRef(source: FileReplaySource,
                   observer: @escaping (_ stream: FileReplay?) -> Void) -> GSFileReplayRef? {
        let ref: Ref<FileReplay>? = session.newFileReplay(source: source, observer: observer)
        return ref != nil ? GSFileReplayRef(ref: ref!) : nil
    }
}

/// Objective-C wrapper of Ref<[DroneListEntry]>. Required because swift generics can't be used from Objective-C.
/// - Note: this class is for Objective-C only and must not be used in Swift.
@objcMembers
public class GSDroneListRef: NSObject {
    private let ref: Ref<[DroneListEntry]>

    /// Referenced DroneListEntry array.
    public var value: [DroneListEntry]? {
        return ref.value
    }

    fileprivate init(ref: Ref<[DroneListEntry]>) {
        self.ref = ref
    }
}

/// Objective-C wrapper of Ref<[RemoteControlListEntry]>.
/// Required because swift generics can't be used from Objective-C.
/// - Note: this class is for Objective-C only and must not be used in Swift.
@objcMembers
public class GSRemoteControlListRef: NSObject {
    private let ref: Ref<[RemoteControlListEntry]>

    /// Referenced DroneListEntry array.
    public var value: [RemoteControlListEntry]? {
        return ref.value
    }

    fileprivate init(ref: Ref<[RemoteControlListEntry]>) {
        self.ref = ref
    }
}
