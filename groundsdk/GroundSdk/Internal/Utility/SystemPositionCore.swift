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
import CoreLocation

/// Utility protocol allowing to device's location services.
public protocol SystemPositionCore: UtilityCore {

    /// Latest phone location.
    var userLocation: CLLocation? { get }

    /// `true` if the update of the CLLocation was suspended by the application (the `userLocation` may be out of date).
    var suspended: Bool { get }

    /// `true` if updates of the CLLocation are forced (see `forceUpdating()`).
    var forcedUpdates: Bool { get }

    /// `true` if location services are Authorized. Location services may or may not be authorized for the application.
    /// Furthermore, the user can enable or disable location services from the Settings app by toggling the Location
    /// services switch in General.
    var authorized: Bool { get }

    /// Latest heading information.
    var heading: CLHeading? { get }

    /// Force continuous location updates
    ///
    /// - Note: This function asks continuous updates of the location and bypasses other start / stop rules
    ///   for location services
    ///
    /// - Important: The caller must call `stopForceUpdating()`
    func forceUpdating()

    /// Stop "Force" after a forceUpdating. (the caller does not need to force continuous location updates anymore)
    ///
    /// - Note: This function must be called if a `forceUpdating()` was called before
    func stopForceUpdating()

    /// Request to suspend the location updates
    ///
    /// - Note: The suspended state is ignored if a `forceUpdating()` request is active
    ///
    /// - Important: The caller must call `unrequestSuspendUpdating()`
    func requestSuspendUpdating()

    /// End the "suspend request" for the location updates
    ///
    /// - Note: This function must be called if a `requestSuspendUpdating()` was called before
    func unrequestSuspendUpdating()

    /// Start monitoring and be informed when `userLocation`, `stopped` or 'authorized` change
    ///
    /// - Note: When the monitoring is not needed anymore, you should call `stop()` on the monitor otherwise
    ///   the monitor **and** this utility will be leaked. 'startLocationMonitoring()` requests continuous location
    ///   updates if possible an if `passive` is false. The updating is not guaranteed (See stopped,
    ///   authorized)
    ///
    /// - Parameters:
    ///   - passive: if `true`, the monitor does not enable continuous GPS updates. If false, continuous GPS
    ///  update requests are started. (See `forceUpdating()` and `requestSuspendUpdating()`)
    ///   - userLocationDidChange: closure called when userLocation, stopped,  changes.
    ///   - stoppedDidChange: closure called when stopped changes.
    ///   - authorizedDidChange: closure called when laocation services authorization changes.
    /// - Returns: a monitor
    func startLocationMonitoring(passive: Bool, userLocationDidChange: @escaping (CLLocation?) -> Void,
                                 stoppedDidChange: @escaping (Bool) -> Void,
                                 authorizedDidChange: @escaping (Bool) -> Void) -> MonitorCore

    /// Start monitoring and be informed when `userHeading` changes
    ///
    /// - Note: When the monitoring is not needed anymore, you should call `stop()` on the monitor otherwise
    ///   the monitor **and** this utility will be leaked. 'startHeadingMonitoring()` requests continuous heading
    ///   updates.
    ///
    /// - Parameters:
    ///   - headingDidChange: closure called when user's heading changes.
    /// - Returns: a monitor
    func startHeadingMonitoring(headingDidChange: @escaping (CLHeading?) -> Void) -> MonitorCore

    /// Calling it causes the location manager to obtain a location fix (which may take several seconds).
    /// The `userLocation` will be updated if the location fix is obtained.
    /// Use this method when you want the user’s current location but do not need to leave location services running.
    ///
    /// - Note: this function checks and respect the `suspended` status (do nothing if GPS services are suspended).
    ///  Furthermore, if GPS request are already started (continuous updates), this function do nothing
    func requestOneLocation()
}

/// Implementation of the `UserLocationCore` utility.
class SystemPositionCoreImpl: SystemPositionCore {

    let desc: UtilityCoreDescriptor = Utilities.systemPosition

    /// Monitor that calls back a closure when UserLocation, locationAuthorization or stopped change.
    private class LocationMonitor: NSObject, MonitorCore {
        /// If true, the monitor does not enable continuous GPS updates.
        fileprivate let passive: Bool
        /// Called back when UserLocation changes.
        fileprivate var userLocationDidChange: ((CLLocation?) -> Void)?
        /// Called back when stopped changes.
        fileprivate var stoppedDidChange: ((Bool) -> Void)?
        /// Called back when authorized changes.
        fileprivate var authorizedDidChange: ((Bool) -> Void)?

        /// the monitorable User Location utility
        private let monitorable: SystemPositionCoreImpl

        /// Constructor
        ///
        /// - Parameters:
        ///    - monitorable: the User Location utility
        ///    - passive: if `true`, the monitor does not enable continuous GPS updates. If false, continuous
        ///      GPS update requests are started. (See `forceUpdating()` and `requestSuspendUpdating()`)
        ///   - userLocationDidChange: closure called when UserLocation changes.
        ///   - stoppedDidChange: closure called when stopped changes.
        ///   - authorizedDidChange: closure called when authorized changes.
        fileprivate init(monitorable: SystemPositionCoreImpl, passive: Bool,
                         userLocationDidChange: @escaping (CLLocation?) -> Void,
                         stoppedDidChange: @escaping (Bool) -> Void,
                         authorizedDidChange: @escaping (Bool) -> Void) {
            self.monitorable = monitorable
            self.passive = passive
            self.userLocationDidChange = userLocationDidChange
            self.stoppedDidChange = stoppedDidChange
            self.authorizedDidChange = authorizedDidChange
        }

        public func stop() {
            userLocationDidChange = nil
            stoppedDidChange = nil
            authorizedDidChange = nil
            monitorable.stopLocationMonitoring(with: self)
        }
    }

    var forcedUpdates: Bool {
        return forceUpdatingCount > 0
    }

    /// Monitor that calls back a closure when heading changes.
    private class HeadingMonitor: NSObject, MonitorCore {
        /// Called back when User's Heading changes.
        fileprivate var headingDidChange: ((CLHeading?) -> Void)?

        /// The monitorable User Location utility
        private let monitorable: SystemPositionCoreImpl

        /// Constructor
        ///
        /// - Parameters:
        ///   - monitorable: the User Location utility
        ///   - headingDidChange: closure called when user's heading changes.
        fileprivate init(monitorable: SystemPositionCoreImpl, headingDidChange: @escaping (CLHeading?) -> Void) {
            self.monitorable = monitorable
            self.headingDidChange = headingDidChange
        }

        public func stop() {
            headingDidChange = nil
            monitorable.stopHeadingMonitoring(with: self)
        }
    }

    /// The systemLocationObserver supports the use of core Location Service (`CLLocation`)
    private var systemLocationObserver: SystemLocationObserver!

    /// Count all listeners calling `forceRequestUpdating()`
    private var forceUpdatingCount = 0 {
        didSet {
            checkStartStopServices()
        }
    }

    /// Count all listeners calling `requestSuspendUpdating()`
    private var suspendUpdatingCount = 0 {
        didSet {
            checkStartStopServices()
        }
    }

    /// List of registered monitors for Location
    private var locationMonitors: Set<LocationMonitor> = []

    /// List of registered monitors for Heading
    private var headingMonitors: Set<HeadingMonitor> = []

    private (set) var userLocation: CLLocation? {
        didSet {
            if userLocation != oldValue {
                // notifies all monitors that a location was updated
                locationMonitors.forEach { monitor in monitor.userLocationDidChange?(userLocation) }
            }
        }
    }

    private (set) var authorized = false {
        didSet {
            if authorized != oldValue {
                // notifies all monitors that authorization was updated (location and heading monitors)
                locationMonitors.forEach { monitor in monitor.authorizedDidChange?(authorized) }
                // if the device is not authorized, clean any previuous location
                if !authorized {
                    userLocation = nil
                    // note: don't clear the heading because another source can be used
                }
            }
        }
    }

    private (set) var suspended = false {
        didSet {
            if suspended != oldValue {
                // Notifies all monitors that location services are stopped
                locationMonitors.forEach { monitor in monitor.stoppedDidChange?(suspended) }
            }
        }
    }

    private (set) var heading: CLHeading? {
        didSet {
            if heading != oldValue {
                // notifies all monitors that a location was updated
                headingMonitors.forEach { monitor in monitor.headingDidChange?(heading) }
            }
        }
    }

    /// Constructor
    init() {
        // init a private SystemLocationObserver and set the CallBacks
        self.systemLocationObserver = SystemLocationObserverCore(
            locationDidChange: { [unowned self] (newLocation) in
                if newLocation != self.userLocation {
                    // the didSet of self.userLocation will notify
                    self.userLocation = newLocation
                }
            },
            authorizedDidChange: { [unowned self] (newAuthorized) in
                if newAuthorized != self.authorized {
                    // the didSet of self.userLocation will notify
                    self.authorized = newAuthorized
                }
            },
            headingDidChange: { [unowned self] (newHeading) in
                if newHeading != self.heading {
                    // the didSet of self.heading will notify
                    self.heading = newHeading
                }
        })
    }

    /// Constructor
    ///
    /// Init with a specific systemObserver. Thus initializer is used or testing and allows to replace
    /// the SystemLocationObserver System (using Core Location) with a Mock object.
    /// - Parameter systemObserver: the custom SystemLocationObserver
    ///
    /// - Note: Callbacks of the systemObserver will be set inside the init (`callBackLocation`, `callBackHeading`,
    ///         `callBackHeading`)
    init(withCustomSystemLocationObserver systemObserver: SystemLocationObserver) {

        self.systemLocationObserver = systemObserver
        // set CallBacks in systemObsesver
        self.systemLocationObserver.locationDidChange = {
            [unowned self] (newLocation) in
            if newLocation != self.userLocation {
                // the didSet of self.userLocation will notify
                self.userLocation = newLocation
            }
        }

        self.systemLocationObserver.authorizedDidChange  = {
            [unowned self] (newAuthorized) in
            if newAuthorized != self.authorized {
                // the didSet of authorized will notify
                self.authorized = newAuthorized
            }
        }
        self.systemLocationObserver.headingDidChange = {
            [unowned self] (newHeading) in
            if newHeading != self.heading {
                // the didSet of self.heading will notify
                self.heading = newHeading
            }
        }
    }

    // (utility interface) Force Location continuous updates
    func forceUpdating() {
        forceUpdatingCount += 1
    }

    // (utility interface) stop to force Location continuous updates
    func stopForceUpdating() {
        forceUpdatingCount -= 1
    }

    // Request to suspend the location updates
    func requestSuspendUpdating() {
        suspendUpdatingCount += 1
    }
    // unrequest the suspended state  updates (end of the "requestSuspendUpdating()")
    func unrequestSuspendUpdating() {
        suspendUpdatingCount -= 1
    }

    /// Auto check the start/stop Location Services
    ///
    /// This function starts or stop the system continuous update according to according to existing subscribers
    /// and the the "suspended" rules.
    private func checkStartStopServices() {
        var needsLocationUpdates = false
        var needsHeadingUpdates = false

        // --- Check for location updates
        // Check for a "force location update request", or existing subscribers for updates
        if forceUpdatingCount > 0 {
            needsLocationUpdates = true
            // resume if needed (set false in the suspended indicator)
            suspended = false
        } else {
            // check if the suspend sate is requested (set true or false in the stopped indicator)
            suspended = (suspendUpdatingCount > 0)
            // if the location is not suspended and existing subscribers for updates, we need continuous updates
            let subscribersForUpdatesCount = locationMonitors.filter { $0.passive == false }.count
            needsLocationUpdates = !suspended && subscribersForUpdatesCount > 0
        }

        if needsLocationUpdates {
            systemLocationObserver.startLocationObserver()
        } else {
            systemLocationObserver.stopLocationObserver()
        }

        // --- Check for heading updates
        // if existing subscribers for heading
        needsHeadingUpdates = headingMonitors.count > 0

        // Check consistency of need with service status
        if needsHeadingUpdates {
            systemLocationObserver.startHeadingObserver()
        } else {
            systemLocationObserver.stopHeadingObserver()
        }
    }

    // MARK: - Monitoring Location
    // Start monitoring for the location (Utility interface)
    func startLocationMonitoring(passive: Bool, userLocationDidChange: @escaping (_: CLLocation?) -> Void,
                                 stoppedDidChange: @escaping (_: Bool) -> Void,
                                 authorizedDidChange: @escaping (_: Bool) -> Void) -> MonitorCore {
        let monitor = LocationMonitor(
            monitorable: self, passive: passive, userLocationDidChange: userLocationDidChange,
            stoppedDidChange: stoppedDidChange,
            authorizedDidChange: authorizedDidChange)
        locationMonitors.insert(monitor)
        // call callBacks for initializing values
        monitor.userLocationDidChange?(userLocation)
        monitor.stoppedDidChange?(suspended)
        monitor.authorizedDidChange?(authorized)
        checkStartStopServices()
        return monitor
    }

    /// Stops monitoring with a given monitor.
    ///
    /// - Parameter monitor: the monitor to stop.
    private func stopLocationMonitoring(with monitor: LocationMonitor) {
        locationMonitors.remove(monitor)
        checkStartStopServices()
    }

    // MARK: - Monitoring Heading
    // Start monitoring for Heading (Utility interface)
    func startHeadingMonitoring(headingDidChange: @escaping (CLHeading?) -> Void) -> MonitorCore {

        let monitor = HeadingMonitor(monitorable: self, headingDidChange: headingDidChange)

        headingMonitors.insert(monitor)
        // call callBacks for initializing values
        monitor.headingDidChange?(heading)
        checkStartStopServices()
        return monitor
    }

    /// Stops monitoring with a given monitor.
    ///
    /// - Parameter monitor: the monitor to stop.
    private func stopHeadingMonitoring(with monitor: HeadingMonitor) {
        headingMonitors.remove(monitor)
        checkStartStopServices()
    }

    func requestOneLocation() {
        if !suspended {
            systemLocationObserver.requestLocation()
        }
    }
}

/// System Position utility description
public class SystemPositionCoreDesc: NSObject, UtilityCoreApiDescriptor {
    public typealias ApiProtocol = SystemPositionCore
    public let uid = UtilityUid.systemPosition.rawValue
}
