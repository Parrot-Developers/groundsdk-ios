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

class GimbalViewController: UITableViewController, DeviceViewController {

    private let groundSdk = GroundSdk()
    private var droneUid: String?
    private var peripheralProvider: PeripheralProvider?
    private var gimbalRef: Ref<Gimbal>?
    /// sorted array of the supported axes
    private var supportedAxes = [GimbalAxis]()
    private var calibratableAxes = [GimbalAxis]()

    private var cells: [CellType: UITableViewCell] = [:]

    private var controlMode = GimbalControlMode.position
    private var targets: [GimbalAxis: Double] = [:]

    private enum CellType {
        case axisStabilization
        case axisMaxSpeed
        case controlMode
        case axisControl
        case correctOffsets
        case calibrate

        var identifier: String {
            switch self {
            case .axisStabilization:    return "AxisStabilizationCell"
            case .axisMaxSpeed:         return "AxisMaxSpeedCell"
            case .controlMode:          return "ControlModeCell"
            case .axisControl:          return "AxisControlCell"
            case .correctOffsets:       return "CorrectOffsetsCell"
            case .calibrate:            return "CalibrateCell"
            }
        }
    }

    private enum Section: Int {
        case stabilization
        case maxSpeed
        case control
        case offsetsCorrection
        case calibration

        var name: String {
            switch self {
            case .stabilization:        return "Stabilization"
            case .maxSpeed:             return "Max speed"
            case .control:              return "Control"
            case .offsetsCorrection:    return "Offsets correction"
            case .calibration:          return "Calibration"
            }
        }
    }

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        peripheralProvider = groundSdk.getDrone(uid: droneUid!)
        if let peripheralProvider = peripheralProvider {
            gimbalRef = peripheralProvider.getPeripheral(Peripherals.gimbal) { [weak self] gimbal in
                if let gimbal = gimbal {
                    self?.supportedAxes = Array(gimbal.supportedAxes).sorted { $0.rawValue < $1.rawValue }
                }
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? DeviceViewController {
            destination.setDeviceUid(droneUid!)
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cellType = cellType(forIndexPath: indexPath) else {
            preconditionFailure("Index path \(indexPath) has no matching cell type.")
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: cellType.identifier, for: indexPath)
        switch cellType {
        case .axisStabilization:
            if let cell = cell as? GimbalAxisStabilizationCell,
                let axis = axis(forIndexPath: indexPath) {

                cell.update(peripheralProvider: peripheralProvider!, axis: axis)
            }
        case .axisMaxSpeed:
            if let cell = cell as? GimbalAxisMaxSpeedCell,
                let axis = axis(forIndexPath: indexPath) {

                cell.update(peripheralProvider: peripheralProvider!, axis: axis)
            }
        case .controlMode:
            if let cell = cell as? GimbalControlModeCell {
                cell.update(controlMode: controlMode) { [weak self] mode in
                    self?.controlMode = mode
                    self?.targets = [:]
                    if let `self` = self, let gimbal = self.gimbalRef?.value {
                        gimbal.control(
                            mode: self.controlMode, yaw: self.targets[.yaw], pitch: self.targets[.pitch],
                            roll: self.targets[.roll])
                    }
                    tableView.reloadSections([Section.control.rawValue], with: .none)
                }
            }
        case .axisControl:
            if let cell = cell as? GimbalAxisControlCell,
                let axis = axis(forIndexPath: indexPath) {

                let targetChanged: (Double) -> Void = { [weak self] target in
                    self?.targets[axis] = target
                    if let `self` = self, let gimbal = self.gimbalRef?.value {
                        gimbal.control(
                            mode: self.controlMode, yaw: self.targets[.yaw], pitch: self.targets[.pitch],
                            roll: self.targets[.roll])
                    }
                }

                switch controlMode {
                case .position:
                    cell.updateWithControlInPosition(
                        peripheralProvider: peripheralProvider!, axis: axis,
                        currentAttitude: self.gimbalRef?.value?.currentAttitude[axis],
                        valueChanged: targetChanged)
                case .velocity:
                    cell.updateWithControlInVelocity(
                        peripheralProvider: peripheralProvider!, axis: axis, valueChanged: targetChanged)
                }
            }
        case .correctOffsets:
            break
        case .calibrate:
            break
        }

        cells[cellType] = cell
        return cell
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 5
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection sectionVal: Int) -> String? {
        guard let section = Section(rawValue: sectionVal) else {
            preconditionFailure("Section value \(sectionVal) has no matching section")
        }
        return section.name
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection sectionVal: Int) -> Int {
        guard let section = Section(rawValue: sectionVal) else {
            preconditionFailure("Section value \(sectionVal) has no matching section")
        }

        switch section {
        case .stabilization:        return supportedAxes.count
        case .maxSpeed:             return supportedAxes.count
        case .control:              return supportedAxes.count + 1
        case .offsetsCorrection:    return 1
        case .calibration:          return 1
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if let cellType = cellType(forIndexPath: indexPath),
            let cell = cells[cellType] {
            return cell.bounds.size.height
        }
        return 74
    }

    private func cellType(forIndexPath indexPath: IndexPath) -> CellType? {
        switch indexPath.section {
        case 0: return .axisStabilization
        case 1: return .axisMaxSpeed
        case 2: return indexPath.row == 0 ? .controlMode : .axisControl
        case 3: return .correctOffsets
        case 4: return .calibrate
        default: return nil
        }
    }

    private func axis(forIndexPath indexPath: IndexPath) -> GimbalAxis? {
        guard let section = Section(rawValue: indexPath.section) else {
            preconditionFailure("Section value \(indexPath.section) has no matching section")
        }

        switch section {
        case .stabilization:        return supportedAxes[indexPath.row]
        case .maxSpeed:             return supportedAxes[indexPath.row]
        case .control:              return supportedAxes[indexPath.row - 1]
        case .offsetsCorrection:    return nil
        case .calibration:          return nil
        }
    }
}

@objc(GimbalAxisStabilizationCell)
private class GimbalAxisStabilizationCell: UITableViewCell {

    @IBOutlet weak var settingView: BoolSettingView!

    private var gimbalRef: Ref<Gimbal>?
    private var axis: GimbalAxis?

    func update(peripheralProvider: PeripheralProvider, axis: GimbalAxis) {
        self.axis = axis
        settingView.label = axis.description
        gimbalRef = peripheralProvider.getPeripheral(Peripherals.gimbal) { [weak self] gimbal in
            self?.settingView.updateWith(boolSetting: gimbal?.stabilizationSettings[axis])
        }
    }

    @IBAction func valueDidChange(_ sender: BoolSettingView) {
        if let axis = axis, let setting = gimbalRef?.value?.stabilizationSettings[axis] {
            setting.value = sender.value
        }
    }
}

@objc(GimbalAxisMaxSpeedCell)
private class GimbalAxisMaxSpeedCell: UITableViewCell {
    @IBOutlet weak var settingView: NumSettingView!

    private var gimbalRef: Ref<Gimbal>?
    private var axis: GimbalAxis?

    func update(peripheralProvider: PeripheralProvider, axis: GimbalAxis) {
        self.axis = axis
        settingView.label = axis.description
        gimbalRef = peripheralProvider.getPeripheral(Peripherals.gimbal) { [weak self] gimbal in
            self?.settingView.updateWith(doubleSetting: gimbal?.maxSpeedSettings[axis])
        }
    }

    @IBAction func valueDidChange(_ sender: NumSettingView) {
        if let axis = axis, let setting = gimbalRef?.value?.maxSpeedSettings[axis] {
            setting.value = Double(sender.value)
        }
    }
}

@objc(GimbalControlModeCell)
private class GimbalControlModeCell: UITableViewCell {
    @IBOutlet weak var controlModeSegmentedControl: UISegmentedControl!
    private var controlModeDidChange: ((GimbalControlMode) -> Void)?

    func update(controlMode: GimbalControlMode, controlModeDidChange: @escaping (GimbalControlMode) -> Void) {
        controlModeSegmentedControl.selectedSegmentIndex = controlMode == .position ? 0 : 1
        self.controlModeDidChange = controlModeDidChange
    }

    @IBAction func controlDidChange(_ sender: UISegmentedControl) {
        controlModeDidChange?(sender.selectedSegmentIndex == 0 ? .position : .velocity)
    }
}

@objc(GimbalAxisControlCell)
private class GimbalAxisControlCell: UITableViewCell {
    @IBOutlet weak var controlSlider: UISlider!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var axisLabel: UILabel!

    private var gimbalRef: Ref<Gimbal>?
    var controlMode: GimbalControlMode?

    var valueChanged: ((Double) -> Void)?
    var axis: GimbalAxis?

    private func update(peripheralProvider: PeripheralProvider, axis: GimbalAxis,
                        valueChanged: @escaping (Double) -> Void) {
        self.axis = axis
        self.valueChanged = valueChanged
        axisLabel.text = axis.description
        gimbalRef = peripheralProvider.getPeripheral(Peripherals.gimbal) { [weak self] gimbal in
            if let bounds = gimbal?.attitudeBounds[axis], self?.controlMode == .position {
                self?.controlSlider.minimumValue = Float(bounds.lowerBound)
                self?.controlSlider.maximumValue = Float(bounds.upperBound)
            }
        }
    }

    func updateWithControlInPosition(
        peripheralProvider: PeripheralProvider, axis: GimbalAxis,
        currentAttitude: Double?, valueChanged: @escaping (Double) -> Void) {

        controlMode = .position
        update(peripheralProvider: peripheralProvider, axis: axis, valueChanged: valueChanged)
        if let currentAttitude = currentAttitude {
            controlSlider.value = Float(currentAttitude)
        } else {
            controlSlider.value = 0
        }
        valueLabel.text = controlSlider.value.description
    }

    func updateWithControlInVelocity(
        peripheralProvider: PeripheralProvider, axis: GimbalAxis, valueChanged: @escaping (Double) -> Void) {

        controlMode = .velocity
        update(peripheralProvider: peripheralProvider, axis: axis, valueChanged: valueChanged)

        controlSlider.minimumValue = -1
        controlSlider.maximumValue = 1
        controlSlider.value = 0
        valueLabel.text = controlSlider.value.description
    }

    @IBAction func targetDidChange(_ sender: UISlider) {
        valueChanged?(Double(sender.value))
        valueLabel.text = sender.value.description
    }

    @IBAction func sliderReleased(_ sender: UISlider) {
        if controlMode == .velocity {
            controlSlider.value = 0
            valueLabel.text = controlSlider.value.description
            valueChanged?(0.0)
        }
    }
}
