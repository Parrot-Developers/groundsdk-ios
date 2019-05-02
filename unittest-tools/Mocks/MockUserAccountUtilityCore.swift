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

import GroundSdk
import CoreLocation
import MapKit
import Contacts

class MockUserAccountUtilityCore: UserAccountUtilityCore {

    let desc: UtilityCoreDescriptor = Utilities.userAccount
    var userAccountInfo: UserAccountInfoCore?

    private class UserAccountMonitor: NSObject, MonitorCore {
        fileprivate var accountDidChange: ((UserAccountInfoCore?) -> Void)?
        private let monitorable: MockUserAccountUtilityCore

        fileprivate init(monitorable: MockUserAccountUtilityCore,
                         accountDidChange: @escaping (UserAccountInfoCore?) -> Void) {
            self.monitorable = monitorable
            self.accountDidChange = accountDidChange
        }

        public func stop() {
            accountDidChange = nil
            monitorable.monitors.remove(self)
        }
    }

    private var monitors = Set<UserAccountMonitor>()
    func startMonitoring(accountDidChange: @escaping (UserAccountInfoCore?) -> Void) -> MonitorCore {
        let monitor = UserAccountMonitor(monitorable: self, accountDidChange: accountDidChange)
        monitors.insert(monitor)
        // call callBacks for initializing values
        monitor.accountDidChange?(userAccountInfo)
        return monitor
    }
}
