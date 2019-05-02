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

/// Camera white balance mode.
@objc(GSCameraWhiteBalanceMode)
public enum CameraWhiteBalanceMode: Int, CustomStringConvertible {
    /// White balance is automatically configured based on the current environment.
    case automatic
    /// Predefined white balance mode for environments lighted by candles.
    case candle
    /// Predefined white balance mode for use sunset lighted environments.
    case sunset
    /// Predefined white balance mode for environments lighted by incandescent light.
    case incandescent
    /// Predefined white balance mode for environments lighted by warm white fluorescent light.
    case warmWhiteFluorescent
    /// Predefined white balance mode for environments lighted by halogen light.
    case halogen
    /// Predefined white balance mode for environments lighted by fluorescent light.
    case fluorescent
    /// Predefined white balance mode for environments lighted by cool white fluorescent light.
    case coolWhiteFluorescent
    /// Predefined white balance mode for environments lighted by a flash light.
    case flash
    /// Predefined white balance mode for use in day light.
    case daylight
    /// Predefined white balance mode for use in sunny weather.
    case sunny
    /// Predefined white balance mode for use in cloudy weather.
    case cloudy
    /// Predefined white balance mode for use in snowy environment.
    case snow
    /// Predefined white balance mode for use in hazy environment.
    case hazy
    /// Predefined white balance mode for use in shaded environment.
    case shaded
    /// Predefined white balance mode for green foliage images.
    case greenFoliage
    /// Predefined white balance mode for blue sky images.
    case blueSky
    /// Custom white balance. White temperature can be configured manually in this mode.
    case custom

    /// Debug description.
    public var description: String {
        switch self {
        case .automatic: return "automatic"
        case .candle: return "candle"
        case .sunset: return "sunset"
        case .incandescent: return "incandescent"
        case .warmWhiteFluorescent: return "warmWhiteFluorescent"
        case .halogen: return "halogen"
        case .fluorescent: return "fluorescent"
        case .coolWhiteFluorescent: return "coolWhiteFluorescent"
        case .flash: return "flash"
        case .daylight: return "daylight"
        case .sunny: return "sunny"
        case .cloudy: return "cloudy"
        case .snow: return "snow"
        case .hazy: return "hazy"
        case .shaded: return "shaded"
        case .greenFoliage: return "greenFoliage"
        case .blueSky: return "blue_sky"
        case .custom: return "custom"
        }
    }

    /// Set containing all possible values of CameraWhiteBalanceMode.
    public static let allCases: Set<CameraWhiteBalanceMode> = [
        .automatic, .candle, .sunset, .incandescent, .warmWhiteFluorescent, .halogen, .fluorescent,
        .coolWhiteFluorescent, .flash, .daylight, .sunny, .cloudy, .snow, .hazy, .shaded, .greenFoliage, .blueSky,
        .custom]
}

/// Camera white balance temperature for custom white balance mode.
@objc(GSCameraWhiteBalanceTemperature)
public enum CameraWhiteBalanceTemperature: Int, CustomStringConvertible, Comparable {
    /// 1500 K
    @objc(GSCameraWhiteBalanceTemperature1500)
    case k1500 = 1500
    /// 1750 K
    @objc(GSCameraWhiteBalanceTemperature1750)
    case k1750 = 1750
    /// 2000K
    @objc(GSCameraWhiteBalanceTemperature2000)
    case k2000 = 2000
    /// 2250 K
    @objc(GSCameraWhiteBalanceTemperature2250)
    case k2250 = 2250
    /// 2500 K
    @objc(GSCameraWhiteBalanceTemperature2500 )
    case k2500 = 2500
    /// 2750 K
    @objc(GSCameraWhiteBalanceTemperature2750)
    case k2750 = 2750
    /// 3000 K
    @objc(GSCameraWhiteBalanceTemperature3000)
    case k3000 = 3000
    /// 3250 K
    @objc(GSCameraWhiteBalanceTemperature3250)
    case k3250 = 3250
    /// 3500 K
    @objc(GSCameraWhiteBalanceTemperature3500)
    case k3500 = 3500
    /// 3750 K
    @objc(GSCameraWhiteBalanceTemperature3750)
    case k3750 = 3750
    /// 4000 K
    @objc(GSCameraWhiteBalanceTemperature4000)
    case k4000 = 4000
    /// 4250 K
    @objc(GSCameraWhiteBalanceTemperature4250)
    case k4250 = 4250
    /// 4500 K
    @objc(GSCameraWhiteBalanceTemperature4500)
    case k4500 = 4500
    /// 4750 K
    @objc(GSCameraWhiteBalanceTemperature4750)
    case k4750 = 4750
    /// 5000 K
    @objc(GSCameraWhiteBalanceTemperature5000)
    case k5000 = 5000
    /// 5250 K
    @objc(GSCameraWhiteBalanceTemperature5250)
    case k5250 = 5250
    /// 5500 K
    @objc(GSCameraWhiteBalanceTemperature5500)
    case k5500 = 5500
    /// 5750 K
    @objc(GSCameraWhiteBalanceTemperature5750)
    case k5750 = 5750
    /// 6000 K
    @objc(GSCameraWhiteBalanceTemperature6000)
    case k6000 = 6000
    /// 6250 K
    @objc(GSCameraWhiteBalanceTemperature6250)
    case k6250 = 6250
    /// 6500 K
    @objc(GSCameraWhiteBalanceTemperature6500)
    case k6500 = 6500
    /// 6750 K
    @objc(GSCameraWhiteBalanceTemperature6750)
    case k6750 = 6750
    /// 7000 K
    @objc(GSCameraWhiteBalanceTemperature7000)
    case k7000 = 7000
    /// 7250 K
    @objc(GSCameraWhiteBalanceTemperature7250)
    case k7250 = 7250
    /// 7500 K
    @objc(GSCameraWhiteBalanceTemperature7500)
    case k7500 = 7500
    /// 7750 K
    @objc(GSCameraWhiteBalanceTemperature7750)
    case k7750 = 7750
    /// 8000 K
    @objc(GSCameraWhiteBalanceTemperature8000)
    case k8000 = 8000
    /// 8250 K
    @objc(GSCameraWhiteBalanceTemperature8250)
    case k8250 = 8250
    /// 8500 K
    @objc(GSCameraWhiteBalanceTemperature8500)
    case k8500 = 8500
    /// 8750 K
    @objc(GSCameraWhiteBalanceTemperature8750)
    case k8750 = 8750
    /// 9000 K
    @objc(GSCameraWhiteBalanceTemperature9000)
    case k9000 = 9000
    /// 9250 K
    @objc(GSCameraWhiteBalanceTemperature9250)
    case k9250 = 9250
    /// 9500 K
    @objc(GSCameraWhiteBalanceTemperature9500)
    case k9500 = 9500
    /// 9750 K
    @objc(GSCameraWhiteBalanceTemperature9750)
    case k9750 = 9750
    /// 10000 K
    @objc(GSCameraWhiteBalanceTemperature10000)
    case k10000 = 10000
    /// 10250 K
    @objc(GSCameraWhiteBalanceTemperature10250)
    case k10250 = 10250
    /// 10500 K
    @objc(GSCameraWhiteBalanceTemperature10500)
    case k10500 = 10500
    /// 10750 K
    @objc(GSCameraWhiteBalanceTemperature10750)
    case k10750 = 10750
    /// 11000 K
    @objc(GSCameraWhiteBalanceTemperature11000)
    case k11000 = 11000
    /// 11250 K
    @objc(GSCameraWhiteBalanceTemperature11250)
    case k11250 = 11250
    /// 11500 K
    @objc(GSCameraWhiteBalanceTemperature11500)
    case k11500 = 11500
    /// 11750 K
    @objc(GSCameraWhiteBalanceTemperature11750)
    case k11750 = 11750
    /// 12000 K
    @objc(GSCameraWhiteBalanceTemperature12000)
    case k12000 = 12000
    /// 12250 K
    @objc(GSCameraWhiteBalanceTemperature12250)
    case k12250 = 12250
    /// 12500 K
    @objc(GSCameraWhiteBalanceTemperature12500)
    case k12500 = 12500
    /// 12750 K
    @objc(GSCameraWhiteBalanceTemperature12750)
    case k12750 = 12750
    /// 13000 K
    @objc(GSCameraWhiteBalanceTemperature13000)
    case k13000 = 13000
    /// 13250 K
    @objc(GSCameraWhiteBalanceTemperature13250)
    case k13250 = 13250
    /// 13500 K
    @objc(GSCameraWhiteBalanceTemperature13500)
    case k13500 = 13500
    /// 13750 K
    @objc(GSCameraWhiteBalanceTemperature13750)
    case k13750 = 13750
    /// 14000 K
    @objc(GSCameraWhiteBalanceTemperature14000)
    case k14000 = 14000
    /// 14250 K
    @objc(GSCameraWhiteBalanceTemperature14250)
    case k14250 = 14250
    /// 14500 K
    @objc(GSCameraWhiteBalanceTemperature14500)
    case k14500 = 14500
    /// 14750 K
    @objc(GSCameraWhiteBalanceTemperature14750)
    case k14750 = 14750
    /// k15000 K
    @objc(GSCameraWhiteBalanceTemperature15000)
    case k15000 = 15000

    /// Set containing all possible values of CameraWhiteBalanceTemperature.
    public static let allCases: Set<CameraWhiteBalanceTemperature> = [
        k1500, k1750, k2000, k2250, k2500, k2750, k3000, k3250, k3500, k3750, k4000, k4250, k4500, k4750, k5000, k5250,
        k5500, k5750, k6000, k6250, k6500, k6750, k7000, k7250, k7500, k7750, k8000, k8250, k8500, k8750, k9000, k9250,
        k9500, k9750, k10000, k10250, k10500, k10750, k11000, k11250, k11500, k11750, k12000, k12250, k12500, k12750,
        k13000, k13250, k13500, k13750, k14000, k14250, k14500, k14750, k15000]

    /// Comparator.
    public static func < (lhs: CameraWhiteBalanceTemperature, rhs: CameraWhiteBalanceTemperature) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    /// Debug description.
    public var description: String {
        return String(rawValue)
    }
}

/// Settings to configure White balance.
///
/// Allows to configure the white balance mode and custom temperature.
public protocol CameraWhiteBalanceSettings: class {
    /// Tells if a setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Supported white balance modes.
    ///
    /// An empty set means that the whole setting is currently unsupported.
    var supportedModes: Set<CameraWhiteBalanceMode> { get }

    /// Supported temperatures when mode is `custom`.
    var supporteCustomTemperature: Set<CameraWhiteBalanceTemperature> { get }

    /// White balance mode.
    ///
    /// Value should be considered meaningless in case the set of `supportedModes` is empty.
    /// Value can only be changed to one of the value `supportedModes`
    var mode: CameraWhiteBalanceMode { get set }

    /// White balance temperatures when mode is `custom`.
    ///
    /// Value should be considered meaningless in case the set of `supportedModes` is empty.
    /// Value can only be changed to one of the value `supportedModes`
    var customTemperature: CameraWhiteBalanceTemperature { get set }

    /// Changes white balance mode and custom temperature.
    ///
    /// - Parameters:
    ///   - mode: requested white balance mode
    ///   - customTemperature: requested white balance temperature when mode is `custom`
    func set(mode: CameraWhiteBalanceMode, customTemperature: CameraWhiteBalanceTemperature?)
}

// MARK: - objc compatibility

/// Settings to configure White balance.
/// - Note: This protocol is for Objective-C compatibility only.
@objc public protocol GSCameraWhiteBalanceSettings {
    /// Tells if a setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// White balance mode.
    var mode: CameraWhiteBalanceMode { get set }

    /// White balance temperatures when mode is `custom`.
    var customTemperature: CameraWhiteBalanceTemperature { get set }

    /// Checks if a white balance mode is supported.
    ///
    /// - Parameter mode: mode to check
    /// - Returns: `true` if the mode is supported
    func isModeSupported(_ mode: CameraWhiteBalanceMode) -> Bool

    /// Checks if a white balance temperature for `custom` mode is supported.
    ///
    /// - Parameter temperature: white balance temperature to check
    /// - Returns: `true` if the white balance temperature is supported
    func isCustomTemperatureSupported(_ temperature: CameraWhiteBalanceTemperature) -> Bool

    /// Sets the white balance mode to custom with a temperature.
    ///
    /// - Parameter temperature: temperature to set with the custom mode
    func setCustomMode(temperature: CameraWhiteBalanceTemperature)
}
