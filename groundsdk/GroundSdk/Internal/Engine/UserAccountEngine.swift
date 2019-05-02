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

/// Class to store the user account informations
public class UserAccountInfoCore: Equatable, CustomStringConvertible, Codable {

    private enum CodingKeys: String, CodingKey {
        case account
        case changeDate
        case anonymousDataPolicy
        case accountlessPersonalDataPolicy
    }

    /// User account identifier, `nil` if none
    public let account: String?
    /// Latest user account identifier change date
    public let changeDate: Date

    /// Indicates whether an unauthenticated user allows anonymous data communication. This flag is significant only
    /// if `account` is `nil` (ie if the user has not agreed to disclose his personal data)
    public let anonymousDataPolicy: AnonymousDataPolicy

    /// Policy to observe with regard to non-anonymous user data that were collected in the absence of a registered
    /// user account, upon registration of such an account.
    public let accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy

    /// Private Constructor for the UserAccountInfo (only public for test)
    ///
    /// - Parameters:
    ///    - account: user account identifier, `nil` if none
    ///    - changeDate: latest user account identifier change date
    ///    - anonymousDataPolicy: whether an unauthenticated user allows anonymous data communication
    ///    - accountlessPersonalDataPolicy: policy to observe with regard to non-anonymous user data
    ///      that were collected in the absence of a registered user account, upon registration of such an account
    internal init(account: String?, changeDate: Date, anonymousDataPolicy: AnonymousDataPolicy,
                  accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy) {
        self.account = account
        self.changeDate = changeDate
        self.anonymousDataPolicy = anonymousDataPolicy
        self.accountlessPersonalDataPolicy = accountlessPersonalDataPolicy
    }

    /// Constructor for the UserAccountInfo (the change Date will be set at current Date)
    ///
    /// - Parameters:
    ///   - account: user account identifier, nil if none
    ///   - anonymousDataPolicy: User allows or not to disclose anonymous Data or not (significant only if `account`
    /// parameter is `nil`)
    convenience init(account: String?, anonymousDataPolicy: AnonymousDataPolicy = .deny,
                     accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy = .denyUpload) {
        self.init(account: account, changeDate: Date(), anonymousDataPolicy: anonymousDataPolicy,
                  accountlessPersonalDataPolicy: accountlessPersonalDataPolicy)
    }

    /// Debug description.
    public var description: String {
        return "AccountInfo: account = \(account ?? "nil")), changeDate = \(changeDate))" +
        ", anonymousDataPolicy = \(anonymousDataPolicy)" +
        " accountlessPersonalDataPolicy = \(accountlessPersonalDataPolicy)"
    }

    /// Equatable concordance
    public static func == (lhs: UserAccountInfoCore, rhs: UserAccountInfoCore) -> Bool {
        return lhs.account == rhs.account && lhs.changeDate == rhs.changeDate &&
            lhs.anonymousDataPolicy == rhs.anonymousDataPolicy &&
            lhs.accountlessPersonalDataPolicy == rhs.accountlessPersonalDataPolicy
    }
}

/// Engine for UserAccount information.
/// The engine publishes the UserAccount utility and Facility
class UserAccountEngine: EngineBaseCore {

    /// Key used in UserDefaults dictionary
    private let storeDataKey = "userAccountEngine"

    private var userAccountInfo: UserAccountInfoCore? {
        didSet {
            userAccountUtilityCoreImpl.update(userAccountInfo: userAccountInfo)
        }
    }

    /// UserAccount facility (published in this Engine)
    private var userAccount: UserAccountCore!

    /// UserAccount utility (published in this Engine)
    private let userAccountUtilityCoreImpl: UserAccountUtilityCoreImpl

    private var groundSdkUserDefaults: GroundSdkUserDefaults!

    /// Constructor
    ///
    /// - Parameter enginesController: engines controller
    public required init(enginesController: EnginesControllerCore) {
        // init utilities
        userAccountUtilityCoreImpl = UserAccountUtilityCoreImpl()
        super.init(enginesController: enginesController)

        if let groundSdkUserDefaults = enginesController.groundSdkUserDefaults {
            self.groundSdkUserDefaults = groundSdkUserDefaults
        } else {
            self.groundSdkUserDefaults = GroundSdkUserDefaults(storeDataKey)
        }

        // init facilities : UserAccount
        userAccount = UserAccountCore(store: enginesController.facilityStore, backend: self)
        // reload persisting Datas
        loadData()
        ULog.d(.userAccountEngineTag, "Loading UserAccountEngine.")
        // publishes UserAccountUtility
        publishUtility(userAccountUtilityCoreImpl)
    }

    public override func startEngine() {
        ULog.d(.userAccountEngineTag, "Starting UserAccountEngine.")
        // publish facilities
        userAccount.publish()
    }

    public override func stopEngine() {
        ULog.d(.userAccountEngineTag, "Stopping UserAccountEngine.")
        // unpublish facilities
        userAccount.unpublish()
    }
}

// MARK: - UserAccountBackend
extension UserAccountEngine: UserAccountBackend {
    func set(account: String, accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy) {
        if userAccountInfo?.account != account
            || userAccountInfo?.accountlessPersonalDataPolicy != accountlessPersonalDataPolicy {
            userAccountInfo = UserAccountInfoCore(account: account,
                                                  accountlessPersonalDataPolicy: accountlessPersonalDataPolicy)
            saveData()
        }
    }

    func clear(anonymousDataPolicy: AnonymousDataPolicy) {
        // we update the UserAccountInfo if :
        //    - if userAccountInfo does not exist
        // or - if the accountId is not nil
        // or - if the anonymousDataPolicy flags changes
        if userAccountInfo == nil || userAccountInfo?.anonymousDataPolicy != anonymousDataPolicy ||
            userAccountInfo?.account != nil {
            userAccountInfo = UserAccountInfoCore(account: nil, anonymousDataPolicy: anonymousDataPolicy,
                                        accountlessPersonalDataPolicy: AccountlessPersonalDataPolicy.denyUpload)
        }
    }
}

// MARK: - loading and saving persisting data
extension UserAccountEngine {

    private enum PersistingDataKeys: String {
        case userAccountData
    }

    /// Save persisting data
    private func saveData() {
        let encoder = PropertyListEncoder()
        do {
            let data = try encoder.encode(userAccountInfo)
            let savedDictionary = [PersistingDataKeys.userAccountData.rawValue: data]
            groundSdkUserDefaults.storeData(savedDictionary)
        } catch {
            // Handle error
            ULog.e(.userAccountEngineTag, "saveData: " + error.localizedDescription)
        }
    }

    /// Load persisting data
    private func loadData() {
        let loadedDictionary = groundSdkUserDefaults.loadData() as? [String: Any]
        if let accountData = loadedDictionary?[PersistingDataKeys.userAccountData.rawValue] as? Data {
            let decoder = PropertyListDecoder()
            userAccountInfo = try? decoder.decode(UserAccountInfoCore.self, from: accountData)
        } else {
            userAccountInfo = nil
        }
    }
}
