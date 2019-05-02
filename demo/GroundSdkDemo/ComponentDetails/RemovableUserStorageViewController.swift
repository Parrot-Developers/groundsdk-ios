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

class RemoveUserStorageViewController: UIViewController, DeviceViewController {
    @IBOutlet var formattingNameTextField: UITextField!
    @IBOutlet var formattingTypesSegmentedControl: UISegmentedControl!
    @IBOutlet var formatButton: UIButton!
    @IBOutlet var formattingStep: UILabel!
    @IBOutlet var formattingProgressView: UIProgressView!
    @IBOutlet var viewFormattingType: UIView!
    @IBOutlet var viewFormattingState: UIView!
    private let groundSdk = GroundSdk()
    private var droneUid: String?
    private var storage: Ref<RemovableUserStorage>?
    private var supportedFormattingTypes: Set<FormattingType>?
    private var arraySegmented: [FormattingType]?

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let drone = groundSdk.getDrone(uid: droneUid!) {
            storage = drone.getPeripheral(
            Peripherals.removableUserStorage) { [weak self] storage in
                if let storage = storage, let `self` = self {
                    self.viewFormattingType.isHidden = storage.supportedFormattingTypes.count < 2
                    if self.supportedFormattingTypes != storage.supportedFormattingTypes {
                        self.supportedFormattingTypes = storage.supportedFormattingTypes
                        self.arraySegmented = Array(storage.supportedFormattingTypes)
                        self.formattingTypesSegmentedControl.removeAllSegments()
                        for (index, type) in self.arraySegmented!.enumerated() {
                            self.formattingTypesSegmentedControl
                                .insertSegment(withTitle: type.description, at: index, animated: false)
                        }
                        self.formattingTypesSegmentedControl.selectedSegmentIndex = 0
                    }
                    self.formattingNameTextField.isEnabled = storage.canFormat
                    self.formattingTypesSegmentedControl.isEnabled = storage.canFormat
                    self.formatButton.isEnabled = storage.canFormat
                    if let formattingState = storage.formattingState, storage.state == .formatting {
                        self.viewFormattingState.isHidden = false
                        self.formattingProgressView.progress = Float(formattingState.progress / 100)
                        self.formattingStep.text = formattingState.step.description
                    } else {
                        self.viewFormattingState.isHidden = true
                    }
                }
            }
        }
    }

    @IBAction func format(_ sender: UIButton) {
        formattingNameTextField.resignFirstResponder()
        if let storageValue = storage?.value {
            var formattingType: FormattingType = .full
            if let arraySegmented = self.arraySegmented {
                if  0...arraySegmented.count ~= formattingTypesSegmentedControl.selectedSegmentIndex {
                     formattingType = arraySegmented[formattingTypesSegmentedControl.selectedSegmentIndex]
                }
            }
            if let formattingNameTextField = formattingNameTextField.text, !formattingNameTextField.isEmpty {
                _ = storageValue.format(formattingType: formattingType,
                                                     newMediaName: formattingNameTextField)
            } else {
                _ = storageValue.format(formattingType: formattingType)
            }
        }
    }
}
