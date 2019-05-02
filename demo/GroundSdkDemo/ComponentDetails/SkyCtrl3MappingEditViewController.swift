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

class SkyCtrl3MappingEditViewController: UIViewController, DeviceViewController {

    private enum PickerType {
        case entryType(dataSource: [SkyCtrl3MappingEntryType])
        case axisAction(dataSource: [AxisMappableAction])
        case buttonsAction(dataSource: [ButtonsMappableAction])
    }

    private let groundSdk = GroundSdk()
    private var rcUid: String?
    private var skyCtrl3Gamepad: Ref<SkyCtrl3Gamepad>?

    public var droneModel: Drone.Model!
    public var entry: SkyCtrl3MappingEntry?

    @IBOutlet private weak var droneModelLabel: UILabel!
    @IBOutlet private weak var entryTypeValue: UITextField!
    @IBOutlet private weak var actionValue: UITextField!
    @IBOutlet private weak var axisEventView: UIView!
    @IBOutlet private weak var axisEventLabel: UILabel!
    @IBOutlet private weak var buttonEventsLabel: UILabel!
    @IBOutlet private weak var editButtonEventsBt: UIButton!
    @IBOutlet private weak var editAxisEventsBt: UIButton!
    @IBOutlet private weak var picker: UIPickerView!
    @IBOutlet private weak var hintLabel: UILabel!
    @IBOutlet private weak var saveBt: UIBarButtonItem!

    private var isEditingButtonEvents = false
    private var isEditingAxisEvent = false
    private var pickerType: PickerType?

    // parts of the entry that will be used to create the (new) entry
    private var entryType: SkyCtrl3MappingEntryType! {
        didSet {
            if entryType != oldValue {
                if entryType == .buttons {
                    axisAction = nil
                    buttonAction = ButtonsMappableAction.allCases.first
                } else if entryType == .axis {
                    buttonAction = nil
                    axisAction = AxisMappableAction.allCases.first
                }
                updateUi()
            }
        }
    }
    private var buttonAction: ButtonsMappableAction?
    private var axisAction: AxisMappableAction?
    private var axisEvent: SkyCtrl3AxisEvent?
    private var buttonEvents: Set<SkyCtrl3ButtonEvent> = []

    func setDeviceUid(_ uid: String) {
        rcUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        entryTypeValue.isEnabled = entry == nil
        actionValue.isEnabled = entry == nil
        picker.isHidden = true

        if let entry = entry {
            entryType = entry.type
            switch entry.type {
            case .buttons:
                let buttonsEntry = entry as! SkyCtrl3ButtonsMappingEntry
                buttonAction = buttonsEntry.action
                buttonEvents = buttonsEntry.buttonEvents
            case .axis:
                let axisEntry = entry as! SkyCtrl3AxisMappingEntry
                axisAction = axisEntry.action
                axisEvent = axisEntry.axisEvent
                buttonEvents = axisEntry.buttonEvents
            }
        }

        if entry == nil {
            entryType = .buttons
        }
        updateUi()

        if let remoteControl = groundSdk.getRemoteControl(uid: rcUid!) {
            skyCtrl3Gamepad =
                remoteControl.getPeripheral(Peripherals.skyCtrl3Gamepad) { [weak self] skyCtrl3Gamepad in
                    if skyCtrl3Gamepad == nil {
                        self?.performSegue(withIdentifier: "exit", sender: self)
                    }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let skyCtrl3Gamepad = skyCtrl3Gamepad?.value {
            skyCtrl3Gamepad.buttonEventListener = nil
            skyCtrl3Gamepad.grab(buttons: [], axes: [])
        }
    }

    private func updateUi() {
        droneModelLabel.text = droneModel.description
        entryTypeValue.text = entryType?.description

        if let entryType = entryType {
            switch entryType {
            case .buttons:
                actionValue.text = buttonAction?.description
                buttonEventsLabel.text = buttonEvents.map({ $0.description }).description

                saveBt.isEnabled = buttonAction != nil && !buttonEvents.isEmpty && !isEditingButtonEvents
                axisEventView.isHidden = true
            case .axis:
                actionValue.text = axisAction?.description
                axisEventLabel.text = axisEvent?.description
                buttonEventsLabel.text = buttonEvents.map({ $0.description }).description

                saveBt.isEnabled = axisAction != nil && axisEvent != nil && !isEditingAxisEvent &&
                    !isEditingButtonEvents
                axisEventView.isHidden = false
            }
        }

        if isEditingButtonEvents {
            editAxisEventsBt.isEnabled = false
            editButtonEventsBt.setTitle("Done", for: .normal)
        } else {
            editAxisEventsBt.isEnabled = true
            editButtonEventsBt.setTitle("Edit", for: .normal)
        }
        if isEditingAxisEvent {
            editButtonEventsBt.isEnabled = false
            editAxisEventsBt.setTitle("Done", for: .normal)
        } else {
            editButtonEventsBt.isEnabled = true
            editAxisEventsBt.setTitle("Edit", for: .normal)
        }
        updateHintLabel()
    }

    private func updateHintLabel() {
        var hintStr = ""
        if isEditingButtonEvents {
            hintStr = "Use your gamepad to (un)select a button\nPress DONE when finished"
        } else if isEditingAxisEvent {
            hintStr = "Use your gamepad to select an axis\nPress DONE when finished"
        }
        if isCurrentlyOverridingAMapping() {
            hintStr += "\nThis will override an existing mapping"
        }
        hintLabel.text = hintStr
    }

    private func isCurrentlyOverridingAMapping() -> Bool {
        if let mapping = skyCtrl3Gamepad?.value?.mapping(forModel: droneModel) {
            for entry in mapping  where entry.type == entryType {
                switch entry.type {
                case .buttons:
                    let buttonEntry = entry as! SkyCtrl3ButtonsMappingEntry
                    if self.entry == nil && buttonEntry.action == buttonAction! {
                        return true
                    }
                    if self.buttonEvents == buttonEntry.buttonEvents && self.entry != entry {
                        return true
                    }
                case .axis:
                    let axisEntry = entry as! SkyCtrl3AxisMappingEntry
                    if self.entry == nil && axisEntry.action == axisAction! {
                        return true
                    }
                    if self.buttonEvents == axisEntry.buttonEvents && self.axisEvent == axisEntry.axisEvent &&
                        self.entry != entry {
                        return true
                    }
                }
            }
        }

        return false
    }

    @IBAction func onEditButtonEventsPushed(_ sender: AnyObject) {
        if let skyCtrl3Gamepad = skyCtrl3Gamepad?.value {
            isEditingButtonEvents = !isEditingButtonEvents
            if isEditingButtonEvents {
                skyCtrl3Gamepad.buttonEventListener = {
                    [unowned self] (event, state) in
                    if state == .pressed {
                        return
                    }
                    if self.buttonEvents.contains(event) {
                        self.buttonEvents.remove(event)
                    } else {
                        self.buttonEvents.insert(event)
                    }
                    self.updateUi()
                }
                skyCtrl3Gamepad.grab(buttons: SkyCtrl3Button.allCases, axes: [])
            } else {
                skyCtrl3Gamepad.buttonEventListener = nil
                skyCtrl3Gamepad.grab(buttons: [], axes: [])
            }
            updateUi()
        }
    }

    @IBAction func onEditAxisEventPushed(_ sender: AnyObject) {
        if let skyCtrl3Gamepad = skyCtrl3Gamepad?.value {
            isEditingAxisEvent = !isEditingAxisEvent
            if isEditingAxisEvent {
                skyCtrl3Gamepad.buttonEventListener = {
                    [unowned self] (event, state) in
                    let axis: SkyCtrl3AxisEvent
                    switch event {
                    case .leftStickLeft,
                         .leftStickRight:
                        axis = .leftStickHorizontal
                    case .leftStickUp,
                         .leftStickDown:
                        axis = .leftStickVertical
                    case .rightStickLeft,
                         .rightStickRight:
                        axis = .rightStickHorizontal
                    case .rightStickUp,
                         .rightStickDown:
                        axis = .rightStickVertical
                    case .leftSliderUp,
                         .leftSliderDown:
                        axis = .leftSlider
                    case .rightSliderUp,
                         .rightSliderDown:
                        axis = .rightSlider
                    default:
                        return
                    }
                    self.axisEvent = axis
                    self.updateUi()
                }
                skyCtrl3Gamepad.grab(buttons: [], axes: SkyCtrl3Axis.allCases)
            } else {
                skyCtrl3Gamepad.buttonEventListener = nil
                skyCtrl3Gamepad.grab(buttons: [], axes: [])
            }
            updateUi()
        }
    }

    @IBAction func onSavePushed(_ sender: AnyObject) {
        let newEntry: SkyCtrl3MappingEntry
        switch entryType! {
        case .buttons:
            newEntry = SkyCtrl3ButtonsMappingEntry(
                droneModel: droneModel, action: buttonAction!, buttonEvents: buttonEvents)
        case .axis:
            newEntry = SkyCtrl3AxisMappingEntry(
                droneModel: droneModel, action: axisAction!, axisEvent: axisEvent!, buttonEvents: buttonEvents)
        }
        skyCtrl3Gamepad!.value?.register(mappingEntry: newEntry)

        _ = self.navigationController?.popViewController(animated: true)
    }
}

extension SkyCtrl3MappingEditViewController: UITextFieldDelegate {
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        switch textField {
        case entryTypeValue:
            pickerType = .entryType(dataSource: [.buttons, .axis])
        case actionValue:
            switch entryType! {
            case .buttons:
                pickerType = .buttonsAction(dataSource: Array(ButtonsMappableAction.allCases).sorted(by: {
                    $0.rawValue < $1.rawValue
                }))
            case .axis:
                pickerType = .axisAction(dataSource: Array(AxisMappableAction.allCases).sorted(by: {
                    $0.rawValue < $1.rawValue
                }))
            }
        default:
            break
        }
        picker.isHidden = false
        hintLabel.isHidden = true
        picker.reloadAllComponents()
        return false
    }
}

extension SkyCtrl3MappingEditViewController: UIPickerViewDataSource {

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if let pickerType = pickerType {
            switch pickerType {
            case .entryType(let dataSource):
                return dataSource.count
            case .buttonsAction(let dataSource):
                return dataSource.count
            case .axisAction(let dataSource):
                return dataSource.count
            }
        }
        return 0
    }
}

extension SkyCtrl3MappingEditViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch pickerType! {
        case .entryType(let dataSource):
            return dataSource[row].description
        case .buttonsAction(let dataSource):
            return dataSource[row].description
        case .axisAction(let dataSource):
            return dataSource[row].description
        }
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch pickerType! {
        case .entryType(let dataSource):
            entryType = dataSource[row]
            // do not need to call updateUi since it is called if value has changed
        case .buttonsAction(let dataSource):
            buttonAction = dataSource[row]
            updateUi()
        case .axisAction(let dataSource):
            axisAction = dataSource[row]
            updateUi()
        }
        picker.isHidden = true
        hintLabel.isHidden = false
    }
}
