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

/// UserAccount backend
protocol UserAccountBackend: class {

    /// Sets the user account.
    ///
    /// - Parameters:
    ///   - account: account to set or `nil` to clear the user account
    ///   - accountlessPersonalDataPolicy:
    ///         true: Already collected data without account may be uploaded.
    ///         false: Already collected data without account must not be uploaded and should be deleted.
    func set(account: String, accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy)

    /// Clears any registered user account.
    ///
    /// - Parameters:
    ///   - anonymousDataPolicy: true if anonymous data are allowed, false otherwise
    func clear(anonymousDataPolicy: AnonymousDataPolicy)
}

/// Core implementation of the UserAccount facility
class UserAccountCore: FacilityCore, UserAccount {

    /// implementation backend
    private unowned let backend: UserAccountBackend

    /// Constructor
    ///
    /// - Parameters:
    ///   - store: component store owning this component
    ///   - backend:  UserAccountBackend backend
    init(store: ComponentStoreCore, backend: UserAccountBackend) {
        self.backend = backend
        super.init(desc: Facilities.userAccount, store: store)
    }

    func set(accountProvider: String, accountId: String,
             accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy) {
        backend.set(account: accountProvider + " " + accountId,
                    accountlessPersonalDataPolicy: accountlessPersonalDataPolicy)
    }
    func clear(anonymousDataPolicy: AnonymousDataPolicy) {
        backend.clear(anonymousDataPolicy: anonymousDataPolicy)
    }
}
