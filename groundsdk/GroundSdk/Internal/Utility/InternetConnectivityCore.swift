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

/// Utility interface for allowing to monitor the operating system connectivity and be notified of internet
/// availability changes.
///
/// This utility is always available after that the engine has started. So when get from
/// `UtilityCoreRegistry.getUtility(desc:)` it can be forced unwrapped.
public protocol InternetConnectivityCore: UtilityCore {

    /// Whether or not internet is available.
    var internetAvailable: Bool { get }

    /// Start monitoring this utility and be informed when internet connectivity changes
    ///
    /// - Note:
    ///   - When the monitoring is not needed anymore, you should call `stop()` on the monitor or the monitor **and**
    ///     this utility will be leaked.
    ///   - If internet is available, the monitor will immediately be called.
    ///
    /// - Parameters:
    ///   - internetAvailabilityDidChange: closure that will be called when internet connectivity changes.
    ///   - internetAvailable: `true` if Internet is available, `false` otherwise.
    /// - Returns: a monitor
    func startMonitoring(with internetAvailabilityDidChange: @escaping (_ internetAvailable: Bool) -> Void)
        -> MonitorCore
}

/// Implementation of InternetConnectivity utility.
class InternetConnectivityCoreImpl: InternetConnectivityCore {

    let desc: UtilityCoreDescriptor = Utilities.internetConnectivity

    /// Monitor that calls back a closure when Internet connectivity changes.
    private class Monitor: NSObject, MonitorCore {

        /// Called back when Internet availability changes.
        ///
        /// - Parameter internetAvailable: `true` if Internet connectivity became available, `false` otherwise.
        /// - Note: If Internet is available when this monitor is added, this callback is directly called.
        fileprivate let internetAvailabilityDidChange: (Bool) -> Void

        /// the monitorable Internet connectivity utility
        private let monitorable: InternetConnectivityCoreImpl

        /// Constructor
        ///
        /// - Parameters:
        ///   - monitorable: the Internet connectivity utility
        ///   - internetAvailabilityDidChange: closure that will be called when internet connectivity changes.
        ///   - internetAvailable: `true` if Internet is available, `false` otherwise.
        fileprivate init(monitorable: InternetConnectivityCoreImpl,
                         internetAvailabilityDidChange: @escaping (_ internetAvailable: Bool) -> Void) {
            self.monitorable = monitorable
            self.internetAvailabilityDidChange = internetAvailabilityDidChange
        }

        public func stop() {
            monitorable.stopMonitoring(with: self)
        }
    }

    /// List of registered monitors
    private var monitors: Set<Monitor> = []

    private(set) var internetAvailable = false

    /// Whether the utility is currently listening for Internet reachability changes
    ///
    /// - Note: Access is granted internally for testing purposes.
    var running: Bool {
        return internetReachabilityListener.running
    }

    /// Internet reachability listener
    private var internetReachabilityListener: InternetReachabilityListener!

    /// Constructor
    init() {
        internetReachabilityListener = createInternetReachabilityListener { [unowned self] internetAvailable in
            if internetAvailable != self.internetAvailable {
                self.internetAvailable = internetAvailable
                self.notifyAll()
            }
        }
    }

    /// Destructor
    deinit {
        stop()
    }

    /// Creates an Internet reachability listener
    ///
    /// - Note: this function is only here for testing purposes
    ///
    /// - Parameter callback: the callback that should be called when Internet reachability changes
    /// - Returns: an instance of `InternetReachabilityListener`
    func createInternetReachabilityListener(callback: @escaping (_ internetAvailable: Bool) -> Void)
        -> InternetReachabilityListener {
            return InternetReachabilityListenerImpl(callback: callback)
    }

    /// Start monitoring the Internet connectivity changes
    ///
    /// - Note: To avoid memory leaks, you should keep the returned monitor. When not needed anymore, you should call
    ///   `stop()` on it before releasing it.
    ///
    /// If the monitor is the first one, start listening for connectivity changes.
    /// If it is not the first one **and** internet is available, then the monitor will immediately be called.
    ///
    /// - Parameters:
    ///   - internetAvailabilityDidChange: closure that will be called when internet connectivity changes.
    ///   - internetAvailable: `true` if Internet is available, `false` otherwise.
    /// - Returns: a monitor. This monitor should be kept until calling `stop()` on it.
    func startMonitoring(
        with internetAvailabilityDidChange: @escaping (_ internetAvailable: Bool) -> Void) -> MonitorCore {

        let monitor = Monitor(monitorable: self, internetAvailabilityDidChange: internetAvailabilityDidChange)
        monitors.insert(monitor)
        // if it was the first monitor
        // (no need to check the insert returned value since we are creating a new instance each time).
        if monitors.count == 1 {
            start()
        } else if internetAvailable {
            monitor.internetAvailabilityDidChange(true)
        }
        return monitor
    }

    /// Stops monitoring with a given monitor.
    ///
    /// After removing the monitor, if the list of monitors is empty, stop listening for connectivity changes.
    ///
    /// - Parameter monitor: the monitor to stop.
    private func stopMonitoring(with monitor: Monitor) {
        if monitors.remove(monitor) != nil {
            if monitors.count == 0 {
                stop()
            }
        }
    }

    /// Notify all monitors that the Internet connectivity has changed.
    ///
    /// - Note: This function should not be called outside this class. **Visible internally only for testing purposes.**
    func notifyAll() {
        monitors.forEach {
            $0.internetAvailabilityDidChange(internetAvailable)
        }
    }

    /// Starts to listen internet reachability
    private func start() {
        internetReachabilityListener.start()
    }

    /// Stops to listen internet reachability
    private func stop() {
        internetReachabilityListener.stop()
    }
}

/// Description of the Internet connectivity utility
public class InternetConnectivityCoreDesc: NSObject, UtilityCoreApiDescriptor {
    public typealias ApiProtocol = InternetConnectivityCore
    public let uid = UtilityUid.internetConnectivity.rawValue
}
