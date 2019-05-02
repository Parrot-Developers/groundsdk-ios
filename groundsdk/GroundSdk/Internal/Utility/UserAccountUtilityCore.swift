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

/// Utility protocol providing access to user account information
public protocol UserAccountUtilityCore: UtilityCore {

    /// Latest userAccountInfo known
    var userAccountInfo: UserAccountInfoCore? { get }

    /// Start monitoring and be informed when `userAccountInfo` change
    ///
    /// - Note: When the monitoring is not needed anymore, you should call `stop()` on the monitor otherwise
    ///   the monitor **and** this utility will be leaked.
    ///
    /// - Parameter accountDidChange: closure called when userInfoAccount changes.
    /// - Returns: a monitor
    func startMonitoring(accountDidChange: @escaping (UserAccountInfoCore?) -> Void) -> MonitorCore
}

/// Implementation of the `UserAccountUtilityCore` utility.
class UserAccountUtilityCoreImpl: UserAccountUtilityCore {

    let desc: UtilityCoreDescriptor = Utilities.userAccount

    /// Monitor that calls back a closure when the UserAccount changes.
    private class UserAccountMonitor: NSObject, MonitorCore {
        /// Called back when placemark changes.
        fileprivate var accountDidChange: ((UserAccountInfoCore?) -> Void)?

        /// the monitorable userAccount utility
        private let monitorable: UserAccountUtilityCoreImpl

        /// Constructor
        ///
        /// - Parameters:
        ///   - monitorable: the userAccount utility
        ///   - accountDidChange: closure called when userInfoAccount changes.
        fileprivate init(monitorable: UserAccountUtilityCoreImpl,
                         accountDidChange: @escaping (UserAccountInfoCore?) -> Void) {
            self.monitorable = monitorable
            self.accountDidChange = accountDidChange
        }

        public func stop() {
            accountDidChange = nil
            monitorable.stopUserAccountMonitoring(with: self)
        }
    }

    /// List of registered monitors for placemark.
    private var userAccountMonitors: Set<UserAccountMonitor> = []

    private (set) var userAccountInfo: UserAccountInfoCore? {
        didSet {
            if userAccountInfo != oldValue {
                // Notifies all monitors that the accountDidChange was updated
                userAccountMonitors.forEach { monitor in monitor.accountDidChange?(userAccountInfo) }
            }
        }
    }

    /// Update the userAccountInfo (used by the UserAccount Engine)
    public func update(userAccountInfo newValue: UserAccountInfoCore?) {
        userAccountInfo = newValue
    }

    // MARK: - Monitoring UserAccount
    func startMonitoring(accountDidChange: @escaping (UserAccountInfoCore?) -> Void) -> MonitorCore {
        let monitor = UserAccountMonitor(monitorable: self, accountDidChange: accountDidChange)
        userAccountMonitors.insert(monitor)
        // call callBacks for initializing values
        monitor.accountDidChange?(userAccountInfo)
        return monitor
    }

    /// Stops monitoring with a given monitor.
    ///
    /// - Parameter monitor: the monitor to stop.
    private func stopUserAccountMonitoring(with monitor: UserAccountMonitor) {
        userAccountMonitors.remove(monitor)
    }
}

/// UserAccount utility description
public class UserAccountUtilityCoreDesc: NSObject, UtilityCoreApiDescriptor {
    public typealias ApiProtocol = UserAccountUtilityCore
    public let uid = UtilityUid.userAccount.rawValue
}
