// Copyright (C) 2020 Parrot Drones SAS
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

class BlendedThermalLiveStreamController: UITableViewController, DeviceViewController {

    private let groundSdk = GroundSdk()
    private var droneUid: String?
    private var camera: Ref<BlendedThermalCamera>?
    private var mode: CameraPhotoMode?
    @IBOutlet weak var modeControl: UISegmentedControl!
    @IBOutlet weak var exposureMode: UILabel!
    @IBOutlet weak var manualShutterSpeed: UILabel!
    @IBOutlet weak var manualIso: UILabel!
    @IBOutlet weak var maximumIso: UILabel!
    @IBOutlet weak var evCompensation: UILabel!
    @IBOutlet weak var exposureLockMode: UILabel!
    @IBOutlet weak var whiteBalanceMode: UILabel!
    @IBOutlet weak var whiteBalanceTemperature: UILabel!
    @IBOutlet weak var whiteBalanceLock: UILabel!
    @IBOutlet weak var whiteBalanceLockSwitch: UISwitch!
    @IBOutlet weak var activeStyle: UILabel!
    @IBOutlet weak var styleSaturation: UILabel!
    @IBOutlet weak var styleContrast: UILabel!
    @IBOutlet weak var styleSharpness: UILabel!
    @IBOutlet weak var hdrAvailable: UILabel!
    @IBOutlet weak var hdrSetting: UISwitch!
    @IBOutlet weak var hdrState: UILabel!
    @IBOutlet weak var recordingMode: UILabel!
    @IBOutlet weak var recordingResolution: UILabel!
    @IBOutlet weak var recordingFramerate: UILabel!
    @IBOutlet weak var recordingHyperlapse: UILabel!
    @IBOutlet weak var autoRecordSetting: UISwitch!
    @IBOutlet weak var photoMode: UILabel!
    @IBOutlet weak var photoFormat: UILabel!
    @IBOutlet weak var photoFileFormat: UILabel!
    @IBOutlet weak var photoBurst: UILabel!
    @IBOutlet weak var photoBracketing: UILabel!
    @IBOutlet weak var startStopRecordingBtn: UIButton!
    @IBOutlet weak var recordingState: UILabel!
    @IBOutlet weak var recordingStartTime: UILabel!
    @IBOutlet weak var recordingMediaId: UILabel!
    @IBOutlet weak var photoState: UILabel!
    @IBOutlet weak var takePhotoBtn: UIButton!
    @IBOutlet weak var stopPhotoBtn: UIButton!
    @IBOutlet weak var latestPhotoCnt: UILabel!
    @IBOutlet weak var photoMediaId: UILabel!
    @IBOutlet weak var zoomAvailability: UILabel!
    @IBOutlet weak var maxLossLessZoomLevel: UILabel!
    @IBOutlet weak var maxLossyZoomLevel: UILabel!
    @IBOutlet weak var zoomLevel: UILabel!
    @IBOutlet weak var maxZoomSpeedSetting: UILabel!
    @IBOutlet weak var zoomVelocityQualityDegradationAllowed: UILabel!
    @IBOutlet weak var changeZoomBt: UIButton!
    @IBOutlet weak var gpslapseCaptureInterval: UILabel!
    @IBOutlet weak var timelapseCaptureInterval: UILabel!
    @IBOutlet weak var alignmentBt: UIButton!

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    // section in tableview
    private enum Section: Int {
        case mode
        case exposure
        case exposureCompensation
        case exposureLock
        case whiteBalance
        case styles
        case hdr
        case recordingSettings
        case autorecord
        case photoSettings
        case recording
        case photo
        case zoom
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let drone = groundSdk.getDrone(uid: droneUid!) {
            camera = drone.getPeripheral(Peripherals.blendedThermalCamera) { [weak self] camera in
                if let camera = camera, let `self` = self {
                    // mode
                    let supportedModes = camera.modeSetting.supportedModes
                    self.modeControl.setEnabled(supportedModes.contains(.photo), forSegmentAt: 0)
                    self.modeControl.setEnabled(supportedModes.contains(.recording), forSegmentAt: 1)
                    switch camera.modeSetting.mode {
                    case .photo:
                        self.modeControl.selectedSegmentIndex = 0
                    case .recording:
                        self.modeControl.selectedSegmentIndex = 1
                    }
                    self.modeControl.isEnabled = !camera.modeSetting.updating

                    // exposure
                    self.tableView.enable(section: Section.exposure.rawValue, on: !camera.exposureSettings.updating)
                    if !camera.exposureSettings.supportedModes.isEmpty {
                        self.exposureMode.text = camera.exposureSettings.mode.description
                    } else {
                        self.exposureMode.text = "Not Supported"
                    }
                    if !camera.exposureSettings.supportedManualShutterSpeeds.isEmpty {
                        self.manualShutterSpeed.text = camera.exposureSettings.manualShutterSpeed.description
                    } else {
                        self.manualShutterSpeed.text = "Not Supported"
                    }
                    if !camera.exposureSettings.supportedManualIsoSensitivity.isEmpty {
                        self.manualIso.text = camera.exposureSettings.manualIsoSensitivity.description
                    } else {
                        self.manualIso.text = "Not Supported"
                    }
                    if !camera.exposureSettings.supportedMaximumIsoSensitivity.isEmpty {
                        self.maximumIso.text = camera.exposureSettings.maximumIsoSensitivity.description
                    } else {
                        self.maximumIso.text = "Not Supported"
                    }

                    // exposure compensation
                    self.tableView.enable(section: Section.exposureCompensation.rawValue,
                                          on: !camera.exposureCompensationSetting.updating)
                    if !camera.exposureCompensationSetting.supportedValues.isEmpty {
                        self.evCompensation.text = camera.exposureCompensationSetting.value.description
                    } else {
                        self.evCompensation.text = "Not Supported"
                    }

                    // exposure lock
                    self.tableView.enable(section: Section.exposureLock.rawValue, on: (camera.exposureLock != nil))
                    self.exposureLockMode.text = camera.exposureLock?.mode.description ?? "Not Supported"

                    // white balance
                    self.tableView.enable(section: Section.whiteBalance.rawValue,
                                          on: !camera.whiteBalanceSettings.updating)
                    if !camera.whiteBalanceSettings.supportedModes.isEmpty {
                        self.whiteBalanceMode.text = camera.whiteBalanceSettings.mode.description
                    } else {
                        self.whiteBalanceMode.text = "Not Supported"
                    }
                    if !camera.whiteBalanceSettings.supporteCustomTemperature.isEmpty {
                        self.whiteBalanceTemperature.text = camera.whiteBalanceSettings.customTemperature.description
                    } else {
                        self.whiteBalanceTemperature.text = "Not Supported"
                    }

                    if let whiteBalanceLock = camera.whiteBalanceLock, let isLockable = whiteBalanceLock.isLockable {
                        self.whiteBalanceLockSwitch.isHidden = !isLockable
                        self.whiteBalanceLockSwitch.isOn = whiteBalanceLock.locked
                        self.whiteBalanceLock.isHidden = isLockable
                        self.whiteBalanceLock.text = isLockable ?
                            "Lockable" : "Not Lockable"
                    } else {
                        self.whiteBalanceLock.text = "Not Supported"
                        self.whiteBalanceLockSwitch.isHidden = true
                        self.whiteBalanceLock.isHidden = false
                    }

                    // styles
                    self.tableView.enable(section: Section.styles.rawValue, on: !camera.styleSettings.updating)
                    if !camera.styleSettings.supportedStyles.isEmpty {
                        self.activeStyle.text = camera.styleSettings.activeStyle.description
                        self.styleSaturation.text = camera.styleSettings.saturation.displayString
                        self.styleContrast.text = camera.styleSettings.contrast.displayString
                        self.styleSharpness.text = camera.styleSettings.sharpness.displayString
                    } else {
                        self.activeStyle.text = "Not Supported"
                        self.styleSaturation.text = "-"
                        self.styleContrast.text = "-"
                        self.styleSharpness.text = "-"
                    }

                    // hdr
                    self.tableView.enable(section: Section.hdr.rawValue, on: camera.hdrSetting != nil)
                    self.hdrAvailable.text = camera.hdrAvailable.description
                    self.hdrSetting.isEnabled = !(camera.hdrSetting?.updating ?? true)
                    self.hdrSetting.isOn = camera.hdrSetting?.value ?? false
                    self.hdrState.text = camera.hdrState ? "On" : "Off"

                    // recording settings
                    self.tableView.enable(section: Section.recordingSettings.rawValue,
                                          on: !camera.recordingSettings.updating)
                    if !camera.recordingSettings.supportedModes.isEmpty {
                        self.recordingMode.text = camera.recordingSettings.mode.description
                    } else {
                        self.recordingMode.text = "Not Supported"
                    }
                    if !camera.recordingSettings.supportedResolutions.isEmpty {
                        self.recordingResolution.text = camera.recordingSettings.resolution.description
                    } else {
                        self.recordingResolution.text = "Not Supported"
                    }
                    if !camera.recordingSettings.supportedFramerates.isEmpty {
                        self.recordingFramerate.text = camera.recordingSettings.framerate.description
                    } else {
                        self.recordingFramerate.text = "Not Supported"
                    }
                    if !camera.recordingSettings.supportedHyperlapseValues.isEmpty {
                        self.recordingHyperlapse.text = camera.recordingSettings.hyperlapseValue.description
                    } else {
                        self.recordingHyperlapse.text = "Not Supported"
                    }

                    // auto-record
                    self.tableView.enable(section: Section.autorecord.rawValue, on: camera.autoRecordSetting != nil)
                    self.autoRecordSetting.isEnabled = !(camera.autoRecordSetting?.updating ?? true)
                    self.autoRecordSetting.isOn = camera.autoRecordSetting?.value ?? false

                    // photo settings
                    self.tableView.enable(section: Section.photoSettings.rawValue,
                                          on: !camera.recordingSettings.updating)
                    if !camera.photoSettings.supportedModes.isEmpty {
                        self.photoMode.text = camera.photoSettings.mode.description
                    } else {
                        self.photoMode.text = "Not Supported"
                    }
                    if !camera.photoSettings.supportedFormats.isEmpty {
                        self.photoFormat.text = camera.photoSettings.format.description
                    } else {
                        self.photoFormat.text = "Not Supported"
                    }
                    if !camera.photoSettings.supportedFileFormats.isEmpty {
                        self.photoFileFormat.text = camera.photoSettings.fileFormat.description
                    } else {
                        self.photoFileFormat.text = "Not Supported"
                    }
                    if !camera.photoSettings.supportedBurstValues.isEmpty {
                        self.photoBurst.text = camera.photoSettings.burstValue.description
                    } else {
                        self.photoBurst.text = "Not Supported"
                    }
                    if !camera.photoSettings.supportedBracketingValues.isEmpty {
                        self.photoBracketing.text = camera.photoSettings.bracketingValue.description
                    } else {
                        self.photoBracketing.text = "Not Supported"
                    }

                    self.gpslapseCaptureInterval.text = String(camera.photoSettings.gpslapseCaptureInterval)
                    self.timelapseCaptureInterval.text = String(camera.photoSettings.timelapseCaptureInterval)
                    // recording state
                    self.recordingState.text = camera.recordingState.functionState.description
                    if camera.canStartRecord {
                        self.startStopRecordingBtn.isEnabled = true
                        self.startStopRecordingBtn?.setTitle("Start Recording", for: .normal)
                    } else if camera.canStopRecord {
                        self.startStopRecordingBtn.isEnabled = true
                        self.startStopRecordingBtn?.setTitle("Stop Recording", for: .normal)
                    } else {
                        self.startStopRecordingBtn.isEnabled = false
                    }
                    self.recordingStartTime.text = camera.recordingState.startTime?.description ?? "-"
                    self.recordingMediaId.text = camera.recordingState.mediaId?.description ?? "-"

                    // recording error
                    let recordingErrorString: String?
                    switch camera.recordingState.functionState {
                    case .errorInsufficientStorageSpace:
                        recordingErrorString = "No Space left on device"
                    case .errorInsufficientStorageSpeed:
                        recordingErrorString = "Storage too slow"
                    case .errorInternal:
                        recordingErrorString = "Unkown error"
                    default:
                        recordingErrorString = nil
                    }
                    if let error = recordingErrorString {
                        let alertController =
                            UIAlertController(title: "Recording", message: error, preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self.present(alertController, animated: true, completion: nil)
                    }

                    // photo state
                    self.takePhotoBtn.isEnabled = camera.canStartPhotoCapture
                    self.stopPhotoBtn.isEnabled = camera.canStopPhotoCapture
                    self.photoState.text = camera.photoState.functionState.description
                    self.latestPhotoCnt.text = camera.photoState.photoCount.description
                    self.photoMediaId.text = camera.photoState.mediaId?.description ?? "-"

                    // photo error
                    let photoErrorString: String?
                    switch camera.photoState.functionState {
                    case .errorInsufficientStorageSpace:
                        photoErrorString = "No Space left on Device"
                    case .errorInternal:
                        photoErrorString = "Unkown Error"
                    default:
                        photoErrorString = nil
                    }
                    if let error = photoErrorString {
                        let alertController =
                            UIAlertController(title: "Photo", message: error, preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self.present(alertController, animated: true, completion: nil)
                    }

                    // zoom
                    if let zoom = camera.zoom {
                        self.zoomAvailability.text = zoom.isAvailable ? "Available" : "Unavailable"
                        self.changeZoomBt.isEnabled = zoom.isAvailable ? true : false
                        self.maxLossLessZoomLevel.text = String(format: "%.2f", zoom.maxLossLessLevel)
                        self.maxLossyZoomLevel.text = String(format: "%.2f", zoom.maxLossyLevel)
                        self.zoomLevel.text = String(format: "%.2f", zoom.currentLevel)
                        self.maxZoomSpeedSetting.text = zoom.maxSpeed.displayString
                        self.zoomVelocityQualityDegradationAllowed.text =
                            zoom.velocityQualityDegradationAllowance.displayString
                    } else {
                        self.zoomAvailability.text = "-"
                        self.changeZoomBt.isEnabled = false
                        self.maxLossLessZoomLevel.text = "-"
                        self.maxLossyZoomLevel.text = "-"
                        self.zoomLevel.text = "-"
                        self.maxZoomSpeedSetting.text = "-"
                        self.zoomVelocityQualityDegradationAllowed.text = "-"
                    }

                    // alignment
                    self.alignmentBt.isEnabled = camera.alignment != nil
                } else {
                    self?.performSegue(withIdentifier: "exit", sender: self)
                }
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let cell = sender as? UITableViewCell
        if let reuseIdentifier = cell?.reuseIdentifier, let action = CellAction(reuseIdentifier),
            let camera = camera?.value {

            switch action {
            case .enumValue(let value):
                // can force cast destination into ChooseEnumViewController
                let target = segue.destination as! ChooseEnumViewController
                switch value {
                case .style:
                    target.initialize(data: ChooseEnumViewController.Data(
                        dataSource: [CameraStyle](camera.styleSettings.supportedStyles),
                        selectedValue: camera.styleSettings.activeStyle.description,
                        itemDidSelect: { [unowned self] value in
                            self.camera?.value?.styleSettings.activeStyle = value as! CameraStyle
                        }
                    ))
                case .exposureMode:
                    target.initialize(data: ChooseEnumViewController.Data(
                        dataSource: [CameraExposureMode](camera.exposureSettings.supportedModes),
                        selectedValue: camera.exposureSettings.mode.description,
                        itemDidSelect: { [unowned self] value in
                            self.camera?.value?.exposureSettings.mode = value as! CameraExposureMode
                        }
                    ))
                case .manualShutterSpeed:
                    target.initialize(data: ChooseEnumViewController.Data(
                        dataSource: [CameraShutterSpeed](camera.exposureSettings.supportedManualShutterSpeeds).sorted(),
                        selectedValue: camera.exposureSettings.manualShutterSpeed.description,
                        itemDidSelect: { [unowned self] value in
                            self.camera?.value?.exposureSettings.manualShutterSpeed = value as! CameraShutterSpeed
                        }
                    ))
                case .manualIso:
                    target.initialize(data: ChooseEnumViewController.Data(
                        dataSource: [CameraIso](camera.exposureSettings.supportedManualIsoSensitivity).sorted(),
                        selectedValue: camera.exposureSettings.manualIsoSensitivity.description,
                        itemDidSelect: { [unowned self] value in
                            self.camera?.value?.exposureSettings.manualIsoSensitivity = value as! CameraIso
                        }
                    ))
                case .maximumIso:
                    target.initialize(data: ChooseEnumViewController.Data(
                        dataSource: [CameraIso](camera.exposureSettings.supportedMaximumIsoSensitivity).sorted(),
                        selectedValue: camera.exposureSettings.maximumIsoSensitivity.description,
                        itemDidSelect: { [unowned self] value in
                            self.camera?.value?.exposureSettings.maximumIsoSensitivity = value as! CameraIso
                        }
                    ))

                case .evCompensation:
                    target.initialize(data: ChooseEnumViewController.Data(
                        dataSource: [CameraEvCompensation](camera.exposureCompensationSetting.supportedValues).sorted(),
                        selectedValue: camera.exposureCompensationSetting.value.description,
                        itemDidSelect: { [unowned self] value in
                            self.camera?.value?.exposureCompensationSetting.value = value as! CameraEvCompensation
                        }
                    ))

                case .whiteBalanceMode:
                    target.initialize(data: ChooseEnumViewController.Data(
                        dataSource: [CameraWhiteBalanceMode](camera.whiteBalanceSettings.supportedModes),
                        selectedValue: camera.whiteBalanceSettings.mode.description,
                        itemDidSelect: { [unowned self] value in
                            self.camera?.value?.whiteBalanceSettings.mode = value as! CameraWhiteBalanceMode
                        }
                    ))

                case .whiteBalanceTemperature:
                    target.initialize(data: ChooseEnumViewController.Data(
                        dataSource: [CameraWhiteBalanceTemperature](camera.whiteBalanceSettings
                            .supporteCustomTemperature),
                        selectedValue: camera.whiteBalanceSettings.customTemperature.description,
                        itemDidSelect: { [unowned self] value in
                            self.camera?.value?.whiteBalanceSettings.customTemperature =
                                value as! CameraWhiteBalanceTemperature
                        }
                    ))
                case .recordingMode:
                    target.initialize(data: ChooseEnumViewController.Data(
                        dataSource: [CameraRecordingMode](camera.recordingSettings.supportedModes),
                        selectedValue: camera.recordingSettings.mode.description,
                        itemDidSelect: { [unowned self] value in
                            self.camera?.value?.recordingSettings.mode = value as! CameraRecordingMode
                        }
                    ))
                case .resolution:
                    target.initialize(data: ChooseEnumViewController.Data(
                        dataSource: [CameraRecordingResolution](camera.recordingSettings.supportedResolutions),
                        selectedValue: camera.recordingSettings.resolution.description,
                        itemDidSelect: { [unowned self] value in
                            self.camera?.value?.recordingSettings.resolution = value as! CameraRecordingResolution
                        }
                    ))
                case .framerate:
                    target.initialize(data: ChooseEnumViewController.Data(
                        dataSource: [CameraRecordingFramerate](camera.recordingSettings.supportedFramerates),
                        selectedValue: camera.recordingSettings.framerate.description,
                        itemDidSelect: { [unowned self] value in
                            self.camera?.value?.recordingSettings.framerate = value as! CameraRecordingFramerate
                        }
                    ))
                case .hyperlapse:
                    target.initialize(data: ChooseEnumViewController.Data(
                        dataSource: [CameraHyperlapseValue](camera.recordingSettings.supportedHyperlapseValues),
                        selectedValue: camera.recordingSettings.hyperlapseValue.description,
                        itemDidSelect: { [unowned self] value in
                            self.camera?.value?.recordingSettings.hyperlapseValue = value as! CameraHyperlapseValue
                        }
                    ))
                case .photoMode:
                    target.initialize(data: ChooseEnumViewController.Data(
                        dataSource: [CameraPhotoMode](camera.photoSettings.supportedModes),
                        selectedValue: camera.photoSettings.mode.description,
                        itemDidSelect: { [unowned self] value in
                            self.camera?.value?.photoSettings.mode = value as! CameraPhotoMode
                        }
                    ))
                case .photoFormat:
                    target.initialize(data: ChooseEnumViewController.Data(
                        dataSource: [CameraPhotoFormat](camera.photoSettings.supportedFormats),
                        selectedValue: camera.photoSettings.format.description,
                        itemDidSelect: { [unowned self] value in
                            self.camera?.value?.photoSettings.format = value as! CameraPhotoFormat
                        }
                    ))
                case .photoFileFormat:
                    target.initialize(data: ChooseEnumViewController.Data(
                        dataSource: [CameraPhotoFileFormat](camera.photoSettings.supportedFileFormats),
                        selectedValue: camera.photoSettings.fileFormat.description,
                        itemDidSelect: { [unowned self] value in
                            self.camera?.value?.photoSettings.fileFormat = value as! CameraPhotoFileFormat
                        }
                    ))
                case .burst:
                    target.initialize(data: ChooseEnumViewController.Data(
                        dataSource: [CameraBurstValue](camera.photoSettings.supportedBurstValues),
                        selectedValue: camera.photoSettings.burstValue.description,
                        itemDidSelect: { [unowned self] value in
                            self.camera?.value?.photoSettings.burstValue = value as! CameraBurstValue
                        }
                    ))
                case .bracketing:
                    target.initialize(data: ChooseEnumViewController.Data(
                        dataSource: [CameraBracketingValue](camera.photoSettings.supportedBracketingValues),
                        selectedValue: camera.photoSettings.bracketingValue.description,
                        itemDidSelect: { [unowned self] value in
                            self.camera?.value?.photoSettings.bracketingValue = value as! CameraBracketingValue
                        }
                    ))
                }
            case .doubleSetting(let value):
                // can force cast destination into ChooseNumberViewController
                let target = segue.destination as! ChooseNumberViewController
                switch value {
                case .zoomVelocity:
                    if let zoom = camera.zoom {
                        target.initialize(data: ChooseNumberViewController.Data(
                            dataSource: zoom.maxSpeed,
                            title: "Max zoom speed"))
                    }
                }
            case .boolSetting(let value):
                // can force cast destination into ChooseBoolViewController
                let target = segue.destination as! ChooseBoolViewController
                switch value {
                case .zoomVelocityQualityDegradation:
                    if let zoom = camera.zoom {
                        target.initialize(data: ChooseBoolViewController.Data(
                            dataSource: zoom.velocityQualityDegradationAllowance,
                            title: "Qual. deg. allowed"))
                    }
                }
            case .styleParametres:
                (segue.destination as! BlendedThermalCameraStyleParametresVC).setDeviceUid(droneUid!)

            case .exposureLock:
                (segue.destination as! BlendedThermalCameraExposureLockVC).setDeviceUid(droneUid!)
            case .timelapseCaptureInterval, .gpslapseCaptureInterval:
                (segue.destination as! BlendedThermalCameraCaptureIntervalVC).setDeviceUid(droneUid!)
                (segue.destination as! BlendedThermalCameraCaptureIntervalVC).setMode(mode!)
            }
        } else if segue.identifier == "changeZoom" {
            (segue.destination as! BlendedThermalCameraChangeZoomVC).setDeviceUid(droneUid!)
        } else if segue.identifier == "alignment" {
            (segue.destination as! BlendedThermalCameraAlignmentVC).setDeviceUid(droneUid!)
        }
    }

    @IBAction func modeDidChange() {
        camera?.value?.modeSetting.mode = modeControl.selectedSegmentIndex == 0 ? .photo : .recording
    }

    @IBAction func hdrSettingDidChange() {
        camera?.value?.hdrSetting?.value = hdrSetting.isOn
    }

    @IBAction func autoRecordSettingDidChange() {
        camera?.value?.autoRecordSetting?.value = autoRecordSetting.isOn
    }

    @IBAction func whiteBalanceLockDidChange() {
        camera?.value?.whiteBalanceLock?.setLock(lock: whiteBalanceLockSwitch.isOn)
    }

    @IBAction func startStopRecording() {
        if let camera = camera?.value {
            if camera.canStartRecord {
                camera.startRecording()
            } else if camera.canStopRecord {
                camera.stopRecording()
            }
        }
    }

    @IBAction func takePhoto() {
        if let camera = camera?.value {
            if camera.canStartPhotoCapture {
                camera.startPhotoCapture()
            }
        }
    }

    @IBAction func stopPhoto() {
        if let camera = camera?.value {
            if camera.canStopPhotoCapture {
                camera.stopPhotoCapture()
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        if let reuseIdentifier = cell?.reuseIdentifier, let action = CellAction(reuseIdentifier) {
            let segueIdentifier: String
            switch action {
            case .enumValue:
                segueIdentifier = "selectEnumValue"
            case .doubleSetting:
                segueIdentifier = "selectNumValue"
            case .boolSetting:
                segueIdentifier = "selectBoolValue"
            case .styleParametres:
                segueIdentifier = "styleParams"
            case .exposureLock:
                segueIdentifier = "exposureLock"
            case .gpslapseCaptureInterval:
                mode = .gpsLapse
                segueIdentifier = "captureInterval"
            case .timelapseCaptureInterval:
                mode = .timeLapse
                segueIdentifier = "captureInterval"
            }
            performSegue(withIdentifier: segueIdentifier, sender: cell)
        } else {
            tableView.deselectRow(at: indexPath, animated: false)
        }
    }

    // Settings that takes an enum value
    private enum EnumValue {
        case exposureMode
        case manualShutterSpeed
        case manualIso
        case maximumIso
        case evCompensation
        case whiteBalanceMode
        case whiteBalanceTemperature
        case recordingMode
        case resolution
        case framerate
        case hyperlapse
        case photoMode
        case photoFormat
        case photoFileFormat
        case burst
        case bracketing
        case style
    }

    // Settings that takes a double value
    private enum DoubleValue {
        case zoomVelocity
    }

    // Settings that takes a boolean value
    private enum BoolValue {
        case zoomVelocityQualityDegradation
    }

    /// Action triggered by the cell selection.
    private enum CellAction {
        /// "selectEnumValue" segue will be triggered
        case enumValue(EnumValue)
        /// "selectDoubleValue" segue will be triggered
        case doubleSetting(DoubleValue)
        /// "selectBoolValue" segue will be triggered
        case boolSetting(BoolValue)
        /// "styleParams" segue will be triggered
        case styleParametres
        /// "exposureLock" segue will be triggered
        case exposureLock
        /// "captureInterval" segue will be triggered
        case gpslapseCaptureInterval
        /// "captureInterval" segue will be triggered
        case timelapseCaptureInterval

        init?(_ strVal: String) {
            switch strVal {
            case "exposureMode":
                self = .enumValue(.exposureMode)
            case "manualShutterSpeed":
                self = .enumValue(.manualShutterSpeed)
            case "manualIso":
                self = .enumValue(.manualIso)
            case "maximumIso":
                self = .enumValue(.maximumIso)
            case "evCompensation":
                self = .enumValue(.evCompensation)
            case "exposureLockMode":
                self = .exposureLock
            case "whiteBalanceMode":
                self = .enumValue(.whiteBalanceMode)
            case "whiteBalanceTemperature":
                self = .enumValue(.whiteBalanceTemperature)
            case "styleSaturation", "styleContrast", "styleSharpness":
                self = .styleParametres
            case "recordingMode":
                self = .enumValue(.recordingMode)
            case "resolution":
                self = .enumValue(.resolution)
            case "framerate":
                self = .enumValue(.framerate)
            case "hyperlapse":
                self = .enumValue(.hyperlapse)
            case "photoMode":
                self = .enumValue(.photoMode)
            case "photoFormat":
                self = .enumValue(.photoFormat)
            case "photoFileFormat":
                self = .enumValue(.photoFileFormat)
            case "burst":
                self = .enumValue(.burst)
            case "bracketing":
                self = .enumValue(.bracketing)
            case "zoomVelocity":
                self = .doubleSetting(.zoomVelocity)
            case "zoomVelocityQualityDegradation":
                self = .boolSetting(.zoomVelocityQualityDegradation)
            case "style":
                self = .enumValue(.style)
            case "gpslapseCaptureInterval":
                self = .gpslapseCaptureInterval
            case "timelapseCaptureInterval":
                self = .timelapseCaptureInterval
            default:
                return nil
            }
        }
    }
}

private extension UITableView {
    func enable(section: Int, on: Bool) {
        for cellIndex in 0..<numberOfRows(inSection: section) {
            cellForRow(at: IndexPath(item: cellIndex, section: section))?.enable(on: on)
        }
    }
}

private extension UITableViewCell {
    func enable(on: Bool) {
        for view in contentView.subviews {
            view.isUserInteractionEnabled = on
            view.alpha = on ? 1 : 0.5
        }
    }
}
