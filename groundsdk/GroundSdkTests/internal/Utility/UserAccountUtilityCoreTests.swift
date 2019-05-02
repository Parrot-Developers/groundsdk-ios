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
@testable import GroundSdkMock
@testable import GroundSdk

class UserAccountUtilityCoreTests: XCTestCase {

    var  userAccountUtility: UserAccountUtilityCoreImpl!

    var changeCntAccount = 0

    var lastAccount: UserAccountInfoCore?

    var monitorUserAccount: MonitorCore?

    override func setUp() {
        super.setUp()
        userAccountUtility = UserAccountUtilityCoreImpl()
    }

    /// create and start a Monitor for UserAccount
    func startMonitorUserAccount() {
        monitorUserAccount =  userAccountUtility.startMonitoring(
            accountDidChange: { (userAccountInfo) in
                self.changeCntAccount += 1
                self.lastAccount = userAccountInfo
        })
    }

    /// free the Monitor
    func stopMonitorUserAccount() {
        monitorUserAccount?.stop()
        monitorUserAccount = nil
        changeCntAccount = 0
    }

    func testInitialValue() {

        // monitor UserAccount
        startMonitorUserAccount()

        // all values are updated when starting monitoring
        assertThat(lastAccount, nilValue())
    }

    func testAccountUpdated() {

        // monitor UserAccount
        startMonitorUserAccount()

        assertThat(changeCntAccount, equalTo(1))
        assertThat(lastAccount, nilValue())

        // Check that setting same value from low-level does not trigger the notification
        userAccountUtility.update(userAccountInfo: nil)
        assertThat(changeCntAccount, equalTo(1))
        assertThat(lastAccount, nilValue())

        // value change from low-level
        let userAccountInfo = UserAccountInfoCore(account: "rabbit",
                                                accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload)
        userAccountUtility.update(userAccountInfo: userAccountInfo)
        assertThat(changeCntAccount, equalTo(2))
        assertThat(lastAccount, presentAnd(`is`(userAccountInfo)))

        // stop and restart monitor
        stopMonitorUserAccount()
        assertThat(changeCntAccount, equalTo(0))
        startMonitorUserAccount()
        assertThat(changeCntAccount, equalTo(1))
        assertThat(lastAccount, presentAnd(`is`(userAccountInfo)))

        // value change from low-level (same value)
        userAccountUtility.update(userAccountInfo: userAccountInfo)
        assertThat(changeCntAccount, equalTo(1))
        assertThat(lastAccount, presentAnd(`is`(userAccountInfo)))

        let userAccountInfo2 = UserAccountInfoCore(account: "rabbit",
                                                accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload)
        userAccountUtility.update(userAccountInfo: userAccountInfo2)
        // same account id, but the the date will change
        assertThat(changeCntAccount, equalTo(2))
        assertThat(lastAccount, presentAnd(`is`(userAccountInfo2)))
    }
}
