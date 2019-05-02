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
@testable import GroundSdk

/// Test UserAccount facility
class UserAccountTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: UserAccountCore!
    private var backend: UserAccountBackendMock!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = UserAccountBackendMock()
        impl = UserAccountCore(store: store, backend: backend)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Facilities.userAccount), present())
        impl.unpublish()
        assertThat(store!.get(Facilities.userAccount), nilValue())
    }

    func testSetAccount() {
        impl.publish()
        var cnt = 0
        let userAccount = store.get(Facilities.userAccount)!
        _ = store.register(desc: Facilities.userAccount) {
            cnt += 1
        }

        assertThat(backend.account, `is`(nil))

        userAccount.set(accountProvider: "accountString", accountId: "accountIdString",
                        accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.allowUpload)
        // test result
        assertThat(backend.account, presentAnd(`is`("accountString accountIdString")))
        assertThat(backend.accountlessPersonalDataPolicy, presentAnd(`is`(.allowUpload)))
        userAccount.clear(anonymousDataPolicy: AnonymousDataPolicy.deny)
        assertThat(backend.accountlessPersonalDataPolicy, presentAnd(`is`(.denyUpload)))
        assertThat(backend.anonymousDataPolicy, presentAnd(`is`(.deny)))
        assertThat(backend.account, nilValue())
        assertThat(cnt, `is`(0))
    }
}

class UserAccountBackendMock: UserAccountBackend {

    var anonymousDataPolicy: AnonymousDataPolicy = .deny
    var account: String?
    var accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy = .denyUpload

    func set(account: String, accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy) {
        self.account = account
        self.accountlessPersonalDataPolicy = accountlessPersonalDataPolicy
    }

    func clear(anonymousDataPolicy: AnonymousDataPolicy) {
        account = nil
        self.accountlessPersonalDataPolicy = .denyUpload
        self.anonymousDataPolicy = anonymousDataPolicy
    }
}
