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

/// A view controller that can modify the color palette
class ThermalPaletteViewController: UIViewController, ThermalPaletteAddColorDelegate, UICollectionViewDataSource,
                                    UICollectionViewDelegate {

    @IBOutlet weak var addColorButton: UIButton!
    @IBOutlet weak var sendColorPaletteButton: UIButton!
    @IBOutlet weak var colorCollectionView: UICollectionView!

    @IBOutlet weak var lowestTemperatureLabel: UILabel!

    @IBOutlet weak var lowestTemperatureValueLabel: UILabel!
    @IBOutlet weak var lowestTemperatureSlider: UISlider!

    @IBOutlet weak var hightestTemperatureLabel: UILabel!
    @IBOutlet weak var hightestTemperatureValueLabel: UILabel!
    @IBOutlet weak var hightestTemperatureSlider: UISlider!

    @IBOutlet weak var outsideColorisationSegmented: UISegmentedControl!

    @IBOutlet weak var temperatureTypeLabel: UILabel!
    @IBOutlet weak var temperatureTypeSegmented: UISegmentedControl!

    @IBOutlet weak var lockedLabel: UILabel!
    @IBOutlet weak var lockedSwitch: UISwitch!

    @IBOutlet weak var thresholdLabel: UILabel!
    @IBOutlet weak var thresholdValueLabel: UILabel!
    @IBOutlet weak var thresholdSlider: UISlider!

    @IBOutlet weak var collectionView: UICollectionView!

    private let groundSdk = GroundSdk()
    private var thermalControl: Ref<ThermalControl>?
    private var droneUid: String!
    private var palette: String!
    private var index: Int = -1

    private var colorsIndex: [Int: Float]!
    private var colorsArray: [Float: ThermalColor]!

    private var selectedColor: ThermalColor?

    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }

    func setPalette(_ palette: String) {
        self.palette = palette
        colorsArray = [:]
        colorsIndex = [:]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        lowestTemperatureSlider.minimumValue = 273.15
        lowestTemperatureSlider.maximumValue = 433.15
        lowestTemperatureSlider.value = 273.15
        lowestTemperatureValueLabel.text = String(273.15)

        hightestTemperatureSlider.minimumValue = 273.15
        hightestTemperatureSlider.maximumValue = 433.15
        hightestTemperatureSlider.value = 433.15
        hightestTemperatureValueLabel.text = String(433.15)

        thresholdSlider.minimumValue = 0.0
        thresholdSlider.maximumValue = 1.0
        thresholdSlider.value = 0.0

        colorsIndex = [:]
        colorsArray = [:]
        collectionView.delegate = self

        lowestTemperatureSlider.maximumTrackTintColor = lowestTemperatureSlider.tintColor
        lowestTemperatureSlider.minimumTrackTintColor = UIColor.lightGray
        hightestTemperatureSlider.maximumTrackTintColor = UIColor.lightGray
        hightestTemperatureSlider.minimumTrackTintColor = lowestTemperatureSlider.tintColor

        addColorButton.layer.cornerRadius = 0.5 * addColorButton.bounds.size.height
        addColorButton.clipsToBounds = true
        addColorButton.layer.borderWidth = 1
        addColorButton.layer.borderColor = addColorButton.tintColor.cgColor

        sendColorPaletteButton.layer.cornerRadius = 0.5 * sendColorPaletteButton.bounds.size.height
        sendColorPaletteButton.clipsToBounds = true
        sendColorPaletteButton.layer.borderWidth = 1
        sendColorPaletteButton.layer.borderColor = sendColorPaletteButton.tintColor.cgColor

        if let drone = groundSdk.getDrone(uid: droneUid) {
            thermalControl = drone.getPeripheral(Peripherals.thermalControl) { [weak self] thermalControl in
                if thermalControl == nil, let `self` = self {
                    self.performSegue(withIdentifier: "exit", sender: self)
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if colorsArray.isEmpty {
            sendColorPaletteButton.isEnabled = false
        } else {
            sendColorPaletteButton.isEnabled = true
        }

        collectionView.reloadData()
        if palette == "absolute" {
            outsideColorisationSegmented.isHidden = false
            lockedLabel.isHidden = true
            lockedSwitch.isHidden = true
            thresholdLabel.isHidden = true
            thresholdValueLabel.isHidden = true
            thresholdSlider.isHidden = true
            temperatureTypeLabel.isHidden = true
            temperatureTypeSegmented.isHidden = true
            lowestTemperatureLabel.isHidden = false
            lowestTemperatureValueLabel.isHidden = false
            lowestTemperatureSlider.isHidden = false
            hightestTemperatureLabel.isHidden = false
            hightestTemperatureValueLabel.isHidden = false
            hightestTemperatureSlider.isHidden = false
        } else if palette == "relative" {
            outsideColorisationSegmented.isHidden = true
            lockedLabel.isHidden = false
            lockedSwitch.isHidden = false
            thresholdLabel.isHidden = true
            thresholdValueLabel.isHidden = true
            thresholdSlider.isHidden = true
            temperatureTypeLabel.isHidden = true
            temperatureTypeSegmented.isHidden = true
            lowestTemperatureLabel.isHidden = false
            lowestTemperatureValueLabel.isHidden = false
            lowestTemperatureSlider.isHidden = false
            hightestTemperatureLabel.isHidden = false
            hightestTemperatureValueLabel.isHidden = false
            hightestTemperatureSlider.isHidden = false
        } else if palette == "spot" {
            outsideColorisationSegmented.isHidden = true
            lockedLabel.isHidden = true
            lockedSwitch.isHidden = true
            thresholdLabel.isHidden = false
            thresholdValueLabel.isHidden = false
            thresholdSlider.isHidden = false
            temperatureTypeLabel.isHidden = false
            temperatureTypeSegmented.isHidden = false
            lowestTemperatureLabel.isHidden = true
            lowestTemperatureValueLabel.isHidden = true
            lowestTemperatureSlider.isHidden = true
            hightestTemperatureLabel.isHidden = true
            hightestTemperatureValueLabel.isHidden = true
            hightestTemperatureSlider.isHidden = true
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "addColor" {
            (segue.destination as! ThermalPaletteAddColorVC).delegate = self
            if selectedColor != nil {
                (segue.destination as! ThermalPaletteAddColorVC).setColor(selectedColor!)
            }
        }
    }

    // IBAction
    @IBAction func sliderDidChange(_ sender: UISlider) {
        switch sender {
        case lowestTemperatureSlider:
            lowestTemperatureValueLabel.text = String(sender.value)
            hightestTemperatureSlider.minimumValue = sender.value
        case hightestTemperatureSlider:
            hightestTemperatureValueLabel.text = String(sender.value)
            lowestTemperatureSlider.maximumValue = sender.value
        case thresholdSlider:
            thresholdValueLabel.text = String(sender.value)
        default:
            break
        }
    }

    @IBAction func touchUpInside(_ sender: UIButton) {
        if sender == addColorButton {
            selectedColor = nil
            performSegue(withIdentifier: "addColor", sender: self)
        } else if sender == sendColorPaletteButton {
            if colorsArray.isEmpty {
                return
            }

            var colors: [ThermalColor] = []
            for (_, color) in colorsArray {
                colors.append(color)
            }

            // send command
            switch palette {
            case "absolute":
                let palette = ThermalAbsolutePalette(colors: colors,
                                    lowestTemp: Double(lowestTemperatureSlider!.value),
                                    highestTemp: Double(hightestTemperatureSlider!.value),
                                    outsideColorization:
                                        outsideColorisationSegmented!.selectedSegmentIndex == 0 ? .limited : .extended)
                thermalControl?.value?.sendPalette(palette)
            case "relative":
                let palette = ThermalRelativePalette(colors: colors,
                                                     locked: lockedSwitch.isSelected,
                                                     lowestTemp: Double(lowestTemperatureSlider!.value),
                                                     highestTemp: Double(hightestTemperatureSlider!.value))

                thermalControl?.value?.sendPalette(palette)
            case "spot":
                let palette = ThermalSpotPalette(colors: colors,
                                            type: temperatureTypeSegmented.selectedSegmentIndex == 0 ? .cold : .hot,
                                            threshold: Double(thresholdSlider.value))
                thermalControl?.value?.sendPalette(palette)
            default:
                break

            }
        }
    }

    // ThermalPaletteAddColor delegate
    func addColor(thermalColor: ThermalColor) {
        if colorsArray[Float(thermalColor.position)] == nil {
            index += 1
            colorsIndex[index] = Float(thermalColor.position)
        }
        colorsArray[Float(thermalColor.position)] = thermalColor
    }

    func removeColor(thermalColor: ThermalColor) {
        colorsArray.removeValue(forKey: Float(thermalColor.position))
        resetIndexArray()
    }

    func resetIndexArray() {
        index = -1
        colorsIndex = [:]
        for color in colorsArray {
            index += 1
            colorsIndex[index] = color.key
        }
    }

    // CollectionView delegate
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return colorsArray.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
        -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "colorCell", for: indexPath)
            if let position = colorsIndex[indexPath.row] {
                if let color = colorsArray[position] {
                    cell.backgroundColor = UIColor(red: CGFloat(color.red), green: CGFloat(color.green),
                                                   blue: CGFloat(color.blue), alpha: 1)
                }
            }

            return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let position = colorsIndex[indexPath.row] {
            if let color = colorsArray[position] {
                selectedColor = color
                performSegue(withIdentifier: "addColor", sender: self)
            }
        }
    }

}
