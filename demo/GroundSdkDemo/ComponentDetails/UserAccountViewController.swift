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

import UIKit
import GroundSdk

class UserAccountViewController: UIViewController {

    private let groundSdk = GroundSdk()

    private var userAccountRef: Ref<UserAccount>?

    @IBOutlet var accountProviderTextField: UITextField!
    @IBOutlet var userIdTextField: UITextField!
    @IBOutlet var setUserButton: UIButton!
    @IBOutlet var clearButton: UIButton!
    @IBOutlet var lastAction: UILabel!
    @IBOutlet var segmentedCollectedPolicy: UISegmentedControl!

    override func viewDidLoad() {
        super.viewDidLoad()
        userAccountRef = groundSdk.getFacility(Facilities.userAccount) { _ in }
        UILabel.appearance(whenContainedInInstancesOf: [UISegmentedControl.self]).numberOfLines = 0
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        editingChanged(self)
    }

    @IBAction func setUserAccount(_ sender: UIButton) {
        doSetUser()
    }

    @IBAction func clearUser(_ sender: Any) {
        doClear()
    }

    @IBAction func AllowAnonymousAction(_ sender: Any) {
        doSetAnonymous(true)
    }

    @IBAction func ResuseAnonymousAction(_ sender: Any) {
        doSetAnonymous(false)
    }

    @IBAction func editingChanged(_ sender: Any) {
        lastAction.text = ""
        let providerString = accountProviderTextField.text ?? ""
        let idString = userIdTextField.text ?? ""
        setUserButton.isEnabled = providerString.count > 0 && idString.count > 0
    }

    private func doClear() {
        if let userAccount = userAccountRef?.value {
            userAccount.clear(anonymousDataPolicy: AnonymousDataPolicy.deny)
            accountProviderTextField.text = ""
            userIdTextField.text = ""
            editingChanged(self)
            lastAction.text = "last action = clear action (anonymous: false)"
        }
    }

    private func doSetUser() {
        if let userAccount = userAccountRef?.value {
            let providerString = accountProviderTextField.text ?? ""
            let idString = userIdTextField.text ?? ""

            userAccount.set(accountProvider: providerString, accountId: idString, accountlessPersonalDataPolicy:
                segmentedCollectedPolicy.selectedSegmentIndex == 0 ?
                    AccountlessPersonalDataPolicy.denyUpload : AccountlessPersonalDataPolicy.allowUpload)
            lastAction.text = "last action = set accountProvider and accountId"
        }
    }

    private func doSetAnonymous(_ value: Bool) {
        if let userAccount = userAccountRef?.value {
            userAccount.clear(anonymousDataPolicy: value ? AnonymousDataPolicy.allow : AnonymousDataPolicy.deny)
            accountProviderTextField.text = ""
            userIdTextField.text = ""
            editingChanged(self)
            lastAction.text = "last action = clear / anonymousDataPolicy: \(value)"
        }
    }
}

extension UserAccountViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textField(
        _ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard string != " " else {
            return false
        }
        return true
    }

}
