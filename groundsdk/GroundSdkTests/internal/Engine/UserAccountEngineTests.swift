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
//    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES LOSS
//    OF USE, DATA, OR PROFITS OR BUSINESS INTERRUPTION) HOWEVER CAUSED
//    AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
//    OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//    SUCH DAMAGE.

import XCTest
@testable import GroundSdk
import GroundSdkMock

class UserAccountEngineTests: XCTestCase {

    var groundSdkUserDefaults: MockGroundSdkUserDefaults?

    // Facility
    var userAccountRef: Ref<UserAccount>!
    var userAccountFacility: UserAccount?
    var changeUtilityCnt = 0

    // Utility
    var userAccountUtilityMonitor: MonitorCore?
    var latestUserAccountInfo: UserAccountInfoCore?
    var monitorCnt = 0

    // need to be retained (normally retained by the EnginesController)
    private let facilityStore = ComponentStoreCore()
    private var enginesController: MockEnginesController!

    private var engine: UserAccountEngine!

    override func setUp() {
        super.setUp()
        groundSdkUserDefaults = MockGroundSdkUserDefaults("mockUserAccount")
        startEngines(storeUserDefaults: groundSdkUserDefaults!)
    }

    func startEngines(storeUserDefaults: MockGroundSdkUserDefaults) {
        let utilityRegistry = UtilityCoreRegistry()
        enginesController = MockEnginesController(
            utilityRegistry: utilityRegistry,
            facilityStore: facilityStore,
            initEngineClosure: {
                self.engine = UserAccountEngine(enginesController: $0)
                return [self.engine] },
            groundSdkUserDefaults: storeUserDefaults)

        userAccountRef = ComponentRefCore(
            store: facilityStore,
            desc: Facilities.userAccount) { [unowned self] userAccount in
                self.userAccountFacility = userAccount
                self.changeUtilityCnt += 1
        }
    }

    func startMonitoringUserAccountUtility () {
        // monitor Utility UserAccount
        // monitor internet connectivity
        let userAccountUtility = self.engine.utilities.getUtility(Utilities.userAccount)
        userAccountUtilityMonitor = userAccountUtility?.startMonitoring(
            accountDidChange: { (userAccountInfo) in
                self.latestUserAccountInfo = userAccountInfo
                self.monitorCnt += 1
        })
    }

    func stopMonitoringUserAccountUtility () {
        userAccountUtilityMonitor?.stop()
        userAccountUtilityMonitor = nil
        monitorCnt = 0
        latestUserAccountInfo = nil
    }

   func testPublishUnpublish() {
        // should be unavailable when the engine is not started
        assertThat(userAccountFacility, nilValue())

        enginesController.start()

        assertThat(userAccountFacility, present())
        assertThat(changeUtilityCnt, `is`(1))

        enginesController.stop()
        assertThat(userAccountFacility, nilValue())
        assertThat(changeUtilityCnt, `is`(2))
    }

    func testInitialValue() {
        enginesController.start()
        startMonitoringUserAccountUtility()
        assertThat(latestUserAccountInfo, nilValue())
        assertThat(monitorCnt, `is`(1))
    }

    func testUpdateAccount() {
        enginesController.start()
        startMonitoringUserAccountUtility()
        assertThat(latestUserAccountInfo, nilValue())
        userAccountFacility?.set(accountProvider: "account1", accountId: "id",
                                 accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.allowUpload)
        assertThat(latestUserAccountInfo?.account, presentAnd(`is`("account1 id")))
        assertThat(latestUserAccountInfo?.accountlessPersonalDataPolicy,
                   presentAnd(`is`(AccountlessPersonalDataPolicy.allowUpload)))

        assertThat(monitorCnt, `is`(2))

        userAccountFacility?.clear(anonymousDataPolicy: AnonymousDataPolicy.deny)
        // now we have a latestUserAccountInfo (with a changeDate, even the account id is nil)
        assertThat(latestUserAccountInfo, present())
        assertThat(latestUserAccountInfo?.account, nilValue())
        assertThat(latestUserAccountInfo?.accountlessPersonalDataPolicy,
                   presentAnd(`is`(AccountlessPersonalDataPolicy.denyUpload)))
        assertThat(monitorCnt, `is`(3))
    }

    func testPersistent() {
        enginesController.start()
        startMonitoringUserAccountUtility()
        assertThat(latestUserAccountInfo, nilValue())
        userAccountFacility?.set(accountProvider: "account1", accountId: "id",
                                 accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.allowUpload)
        assertThat(latestUserAccountInfo?.account, presentAnd(`is`("account1 id")))
        assertThat(latestUserAccountInfo?.accountlessPersonalDataPolicy,
                   presentAnd(`is`(AccountlessPersonalDataPolicy.allowUpload)))
        assertThat(monitorCnt, `is`(2))

        let keepUserAccountInfo = latestUserAccountInfo

        // keeps values after a stop / stop (with the same engine)
        stopMonitoringUserAccountUtility()
        enginesController.stop()
        assertThat(latestUserAccountInfo, nilValue())
        enginesController.start()
        startMonitoringUserAccountUtility()
        assertThat(latestUserAccountInfo, presentAnd(`is`(keepUserAccountInfo)))
        assertThat(monitorCnt, `is`(1))

        // checks that value account is in UserDefaults
        let store: [String: Any]? = groundSdkUserDefaults?.mockUserDefaults.store["groundSdkStore"] as? [String: Any]
        let mockUserAccount: [String: Any]? = store?["mockUserAccount"] as? [String: Any]
        let userAccountData = mockUserAccount?["userAccountData"] as? Data
        let decoder = PropertyListDecoder()
        let decodedAccount: UserAccountInfoCore? = try? decoder.decode(UserAccountInfoCore.self, from: userAccountData!)

        assertThat(decodedAccount?.account, presentAnd(`is`("account1 id")))

        // restart engines (new engine but we keep the store)
        stopMonitoringUserAccountUtility()
        enginesController.stop()
        assertThat(latestUserAccountInfo, nilValue())
        // keep the same store - Reinit enginesController
        startEngines(storeUserDefaults: groundSdkUserDefaults!)
        enginesController.start()
        startMonitoringUserAccountUtility()
        assertThat(latestUserAccountInfo, presentAnd(`is`(keepUserAccountInfo)))
        assertThat(monitorCnt, `is`(1))
    }

}
