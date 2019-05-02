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

/// Thermal control modes.
@objc(GSThermalControlMode)
public enum ThermalControlMode: Int, CustomStringConvertible {
    /// Thermal control is off.
    case disabled
    /// Thermal control is enabled, in standard mode.
    case standard

    /// Debug description.
    public var description: String {
        switch self {
        case .disabled: return "disabled"
        case .standard: return "standard"
        }
    }
}

/// Thermal sensitivity ranges.
@objc(GSThermalSensitivityRange)
public enum ThermalSensitivityRange: Int, CustomStringConvertible {
    /// Thermal sensitivity range is high (from -10 to 400°C).
    case high
    /// Thermal sensitivity range is low (from -10 to 140°C).
    case low

    /// Debug description.
    public var description: String {
        switch self {
        case .high: return "high"
        case .low: return "low"
        }
    }
}

/// Thermal rendering modes.
@objc(GSThermalRenderingMode)
public enum ThermalRenderingMode: Int, CustomStringConvertible {
    /// Visible image only.
    case visible
    /// Thermal image only.
    case thermal
    /// Blending between visible and thermal images.
    case blended
    /// Visible image is in black and white.
    case monochrome

    /// Debug description.
    public var description: String {
        switch self {
        case .visible: return "visible"
        case .thermal: return "thermal"
        case .blended: return "blended"
        case .monochrome: return "monochrome"
        }
    }
}

/// Setting to change the thermal control mode.
public protocol ThermalControlSetting: class {
    /// Tells if the setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Supported modes.
    var supportedModes: Set<ThermalControlMode> { get }

    /// Current thermal control mode setting.
    var mode: ThermalControlMode { get set }
}

/// Setting to change the sensitivity range.
public protocol ThermalSensitivityRangeSetting: class {
    /// Tells if the setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Supported ranges.
    var supportedSensitivityRanges: Set<ThermalSensitivityRange> { get }

    /// Current sensitivity range.
    var sensitivityRange: ThermalSensitivityRange { get set }
}

/// Thermal palette colorization modes.
@objc(GSThermalColorizationMode)
public enum ThermalColorizationMode: Int, CustomStringConvertible {
    /// Use black color if temperature is outside palette bounds.
    case limited
    /// Use boundaries colors if temperature is outside palette bounds.
    case extended

    /// Debug description.
    public var description: String {
        switch self {
        case .limited: return "limited"
        case .extended: return "extended"
        }
    }
}

/// Thermal spot palette types.
@objc(GSThermalSpotType)
public enum ThermalSpotType: Int, CustomStringConvertible {
    /// Colorize only if temperature is below threshold.
    case cold
    /// Colorize only if temperature is above threshold.
    case hot

    /// Debug description.
    public var description: String {
        switch self {
        case .cold: return "cold"
        case .hot: return "hot"
        }
    }
}

/// Thermal rendering.
@objcMembers
@objc(GSThermalRendering)
public class ThermalRendering: NSObject {
    /// Rendering mode.
    public let mode: ThermalRenderingMode

    /// Blending rate, in range [0, 1], used only in blended mode.
    public let blendingRate: Double

    /// Constructor.
    ///
    /// - Parameters:
    ///    - mode: mode
    ///    - blendingRate: blending rate, in range [0, 1], used only in blended mode
    public init (mode: ThermalRenderingMode, blendingRate: Double) {
        self.mode = mode
        self.blendingRate = blendingRate
    }

    /// Debug description.
    override public var description: String {
        return "ThermalRendering: mode = \(mode), blendingRate =\(blendingRate)"
    }
}

/// Color for thermal palette.
@objcMembers
@objc(GSThermalColor)
public class ThermalColor: NSObject {

    /// Red component, in range [0, 1].
    public let red: Double

    /// Green component, in range [0, 1].
    public let green: Double

    /// Blue component, in range [0, 1].
    public let blue: Double

    /// Index in the palette where given color should be applied, in range [0, 1].
    public let position: Double

    /// Constructor.
    ///
    /// - Parameters:
    ///    - red: red component, in range [0, 1]
    ///    - green: green component, in range [0, 1]
    ///    - blue: blue component, in range [0, 1]
    ///    - position: index in the palette, in range [0, 1]
    public init(_ red: Double, _ green: Double, _ blue: Double, _ position: Double) {
        self.red = unsignedPercentIntervalDouble.clamp(red)
        self.green = unsignedPercentIntervalDouble.clamp(green)
        self.blue = unsignedPercentIntervalDouble.clamp(blue)
        self.position = unsignedPercentIntervalDouble.clamp(position)
    }

    override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? ThermalColor else {
            return false
        }
        return Float(red) == Float(other.red)
            && Float(green) == Float(other.green)
            && Float(blue) == Float(other.blue)
            && Float(position) == Float(other.position)
    }

    /// Debug description.
    override public var description: String {
        return "ThermalColor: \(red), \(green), \(blue), \(position)"
    }
}

/// Base class for thermal palette.
@objcMembers
@objc(GSThermalPalette)
public class ThermalPalette: NSObject {

    /// Palette colors.
    public var colors: [ThermalColor]

    /// Constructor.
    ///
    /// - Parameter colors: palette colors
    public init(colors: [ThermalColor]) {
        self.colors = colors
    }
}

/// Absolute thermal palette.
@objcMembers
@objc(GSThermalAbsolutePalette)
public class ThermalAbsolutePalette: ThermalPalette {

    /// Temperature associated to the lower boundary of the palette, in Kelvin.
    public var lowestTemperature: Double

    /// Temperature associated to the higher boundary of the palette, in Kelvin.
    public var highestTemperature: Double

    /// Colorization mode outside palette bounds.
    public var outsideColorization: ThermalColorizationMode

    /// Constructor.
    ///
    /// - Parameters:
    ///    - colors: palette colors
    ///    - lowestTemp: temperature associated to the lower boundary of the palette, in Kelvin
    ///    - highestTemp: temperature associated to the higher boundary of the palette, in Kelvin
    ///    - outsideColorization: colorization mode outside palette bounds
    public init(colors: [ThermalColor],
                lowestTemp: Double, highestTemp: Double,
                outsideColorization: ThermalColorizationMode) {
        self.lowestTemperature = lowestTemp
        self.highestTemperature = highestTemp
        self.outsideColorization = outsideColorization
        super.init(colors: colors)
    }

    /// Debug description.
    override public var description: String {
        return "ThermalAbsolutePalette: lowestTemp = \(lowestTemperature), highestTemp = \(highestTemperature),"
            + " outsideColorization = \(outsideColorization), colors = \(colors)"
    }
}

/// Relative thermal palette.
@objcMembers
@objc(GSThermalRelativePalette)
public class ThermalRelativePalette: ThermalPalette {

    /// Temperature associated to the lower boundary of the palette, in Kelvin,
    /// used only when palette is 'locked'.
    public var lowestTemperature: Double

    /// Temperature associated to the higher boundary of the palette, in Kelvin,
    /// used only when palette is 'locked'.
    public var highestTemperature: Double

    /// Whether the palette is locked.
    ///
    /// When 'false', lowest and highest temperatures associated with palette bounds
    /// are computed at each frame.
    /// When 'true', lowest and highest temperatures associated with palette bounds are locked.
    public var locked: Bool

    /// Constructor.
    ///
    /// - Parameters:
    ///    - colors: palette colors
    ///    - locked: 'true' if the palette is locked, otherwise 'false'
    ///    - lowestTemp: temperature associated to the lower boundary of the palette, in Kelvin,
    ///                  used only when palette is 'locked'
    ///    - highestTemp: temperature associated to the higher boundary of the palette, in Kelvin,
    ///                   used only when palette is 'locked'
    public init(colors: [ThermalColor], locked: Bool,
                lowestTemp: Double, highestTemp: Double) {
        self.locked = locked
        self.lowestTemperature = lowestTemp
        self.highestTemperature = highestTemp
        super.init(colors: colors)
    }

    /// Debug description.
    override public var description: String {
        return "ThermalRelativePalette: lowestTemp = \(lowestTemperature), highestTemp = \(highestTemperature),"
            + " locked = \(locked), colors = \(colors)"
    }
}

/// Spot thermal palette.
@objcMembers
@objc(GSThermalSpotPalette)
public class ThermalSpotPalette: ThermalPalette {

    /// Temperature type to highlight.
    public var type: ThermalSpotType

    /// Threshold palette index for highlighting, from 0 to 1.
    public var threshold: Double

    /// Constructor.
    ///
    /// - Parameters:
    ///    - colors: palette colors
    ///    - type: temperature type to highlight
    ///    - threshold: threshold palette index for highlighting, from 0 to 1
    public init(colors: [ThermalColor], type: ThermalSpotType, threshold: Double) {
        self.type = type
        self.threshold = threshold
        super.init(colors: colors)
    }

    /// Debug description.
    override public var description: String {
        return "ThermalRelativePalette: type = \(type), threshold = \(threshold), colors = \(colors)"
    }
}

/// Peripheral managing thermal control.
///
/// This peripheral can be retrieved by:
/// ```
/// device.getPeripheral(Peripherals.ThermalControl)
/// ```
public protocol ThermalControl: Peripheral {
    /// Thermal control setting
    var setting: ThermalControlSetting { get }

    /// Sensitivity range setting
    var sensitivitySetting: ThermalSensitivityRangeSetting { get }

    /// Sends emissivity value.
    ///
    /// - Parameter emissivity: emissivity value in range [0, 1]
    func sendEmissivity(_ emissivity: Double)

    /// Sends thermal palette configuration to drone.
    ///
    /// - Parameter palette: palette configuration
    func sendPalette(_ palette: ThermalPalette)

    /// Sends background temperature to drone.
    ///
    /// - Parameter backgroundTemperature: background temperature (Kelvin)
    func sendBackgroundTemperature(_ backgroundTemperature: Double)

    /// Sends rendering configuration to drone.
    ///
    /// - Parameter rendering: rendering configuration
    func sendRendering(rendering: ThermalRendering)
}

/// :nodoc:
/// ThermalControl description
@objc(GSThermalControlDesc)
public class ThermalControlDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = ThermalControl
    public let uid = PeripheralUid.thermalControl.rawValue
    public let parent: ComponentDescriptor? = nil
}

// MARK: - objc compatibility

/// Setting to change the thermal control mode.
/// - Note: This protocol is for Objective-C compatibility only.
@objc public protocol GSThermalControlSetting {
    /// Tells if a setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Thermal control mode setting.
    var mode: ThermalControlMode { get set }

    /// Checks if a mode is supported.
    ///
    /// - Parameter mode: mode to check
    /// - Returns: `true` if the mode is supported
    func isModeSupported(_ mode: ThermalControlMode) -> Bool
}

// MARK: - objc compatibility

/// Setting to change the thermal sensitivity range
/// - Note: This protocol is for Objective-C compatibility only.
@objc public protocol GSThermalSensitivityRangeSetting {
    /// Tells if a setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Checks if a sensitivity range is supported.
    ///
    /// - Parameter range: range to check
    /// - Returns: `true` if the sensitivity range is supported
    func isSensitivityRangeSupported(_ range: ThermalSensitivityRange) -> Bool

    /// Current sensitivity range.
    var sensitivityRange: ThermalSensitivityRange { get set }
}

/// Peripheral managing thermal control.
/// - Note: This protocol is for Objective-C compatibility only.
@objc public protocol GSThermalControl {
    /// Thermal control setting.
    @objc(setting)
    var gsSetting: GSThermalControlSetting { get }

    /// Sensitivity range setting.
    @objc(sensitivitySetting)
    var gsSensitivityRangeSetting: GSThermalSensitivityRangeSetting { get }

    /// Send emissivity value.
    ///
    /// - Parameter emissivity: emissivity value in range [0, 1]
    func sendEmissivity(_ emissivity: Double)

    /// Send thermal palette configuration to drone.
    ///
    /// - Parameter palette: palette configuration
    func sendPalette(_ palette: ThermalPalette)

    /// Sends background temperature to drone.
    ///
    /// - Parameter backgroundTemperature: background temperature (Kelvin)
    func sendBackgroundTemperature(_ backgroundTemperature: Double)

    /// Sends rendering configuration to drone.
    ///
    /// - Parameter rendering: rendering configuration
    func sendRendering(rendering: ThermalRendering)
}
