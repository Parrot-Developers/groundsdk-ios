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

/// Camera exposure mode.
@objc(GSCameraExposureMode)
public enum CameraExposureMode: Int, CustomStringConvertible {
    /// Automatic exposure mode balanced.
    ///
    /// Both shutter speed and ISO sensitivity are automatically configured by the camera, with respect to some
    /// manually configured maximum ISO sensitivity value.
    case automatic

    /// Automatic exposure mode, prefer increasing iso sensitivity.
    ///
    /// Both shutter speed and ISO sensitivity are automatically configured by the camera, with respect to some
    /// manually configured maximum ISO sensitivity value. Prefer increasing iso sensitivity over using low
    /// shutter speed. This mode provides better results when the drone is moving dynamically.
    case automaticPreferIsoSensitivity

    /// Automatic exposure mode, prefer reducing shutter speed.
    ///
    /// Both shutter speed and ISO sensitivity are automatically configured by the camera, with respect to some
    /// manually configured maximum ISO sensitivity value. Prefer reducing shutter speed over using high iso
    /// sensitivity. This mode provides better results when the when the drone is moving slowly.
    case automaticPreferShutterSpeed

    /// Manual ISO sensitivity mode.
    ///
    /// Allows to configure ISO sensitivity manually. Shutter speed is automatically configured by the camera
    /// accordingly.
    case manualIsoSensitivity

    /// Manual shutter speed mode.
    ///
    /// Allows to configure shutter speed manually. ISO sensitivity is automatically configured by the camera
    /// accordingly.
    case manualShutterSpeed

    /// Manual mode.
    ///
    /// Allows to manually configure both the camera's shutter speed and the ISO sensitivity.
    case manual

    /// Debug description.
    public var description: String {
        switch self {
        case .automatic:                     return "automatic"
        case .automaticPreferIsoSensitivity: return "automaticPreferIsoSensitivity"
        case .automaticPreferShutterSpeed:   return "automaticPreferShutterSpeed"
        case .manualIsoSensitivity:          return "manualIsoSensitivity"
        case .manualShutterSpeed:            return "manualShutterSpeed"
        case .manual:                        return "manual"
        }
    }
}

/// Camera auto exposure metering mode.
@objc(GSCameraAutoExposureMeteringMode)
public enum CameraAutoExposureMeteringMode: Int, CustomStringConvertible, Comparable {

    /// Standard auto exposure metering mode.
    case standard

    /// centerTop auto exposure metering mode,
    case centerTop

    /// Debug description.
    public var description: String {
        switch self {
        case .standard:                     return "standard"
        case .centerTop:                    return "centerTop"
        }
    }

    /// Comparable concordance
    public static func < (lhs: CameraAutoExposureMeteringMode, rhs: CameraAutoExposureMeteringMode) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Camera shutter speed values
@objc(GSCameraShutterSpeed)
public enum CameraShutterSpeed: Int, CustomStringConvertible, Comparable {
    /// 1/10000 s
    case oneOver10000
    /// 1/8000 s
    case oneOver8000
    /// 1/6400 s
    case oneOver6400
    /// 1/5000 s
    case oneOver5000
    /// 1/4000 s
    case oneOver4000
    /// 1/3200 s
    case oneOver3200
    /// 1/2500 s
    case oneOver2500
    /// 1/2000 s
    case oneOver2000
    /// 1/1600 s
    case oneOver1600
    /// 1/1000 s
    case oneOver1250
    /// 1/1250 s
    case oneOver1000
    /// 1/800 s
    case oneOver800
    /// 1/640 s
    case oneOver640
    /// 1/500 s
    case oneOver500
    /// 1/400 s
    case oneOver400
    /// 1/320 s
    case oneOver320
    /// 1/240 s
    case oneOver240
    /// 1/200 s
    case oneOver200
    /// 1/160 s
    case oneOver160
    /// 1/120 s
    case oneOver120
    /// 1/100 s
    case oneOver100
    /// 1/60 s
    case oneOver60
    /// 1/80 s
    case oneOver80
    /// 1/50 s
    case oneOver50
    /// 1/40 s
    case oneOver40
    /// 1/30 s
    case oneOver30
    /// 1/25 s
    case oneOver25
    /// 1/15 s
    case oneOver15
    /// 1/10 s
    case oneOver10
    /// 1/8 s
    case oneOver8
    /// 1/6 s
    case oneOver6
    /// 1/4 s
    case oneOver4
    /// 1/3 s
    case oneOver3
    /// 1/2 s
    case oneOver2
    /// 1/1.5 s
    case oneOver1_5
    /// 1 s
    case one

    /// Set containing all possible values of CameraShutterSpeed.
    public static let allCases: Set<CameraShutterSpeed> = [
        oneOver10000, oneOver8000, oneOver6400, oneOver5000, oneOver4000, oneOver3200, oneOver2500, oneOver2000,
        oneOver1600, oneOver1250, oneOver1000, oneOver800, oneOver640, oneOver500, oneOver400, oneOver320, oneOver240,
        oneOver200, oneOver160, oneOver120, oneOver100, oneOver80, oneOver60, oneOver50, oneOver40, oneOver30,
        oneOver25, oneOver15, oneOver10, oneOver8, oneOver6, oneOver4, oneOver3, oneOver2, oneOver1_5, one]

    /// Comparator.
    public static func < (lhs: CameraShutterSpeed, rhs: CameraShutterSpeed) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    /// Debug description.
    public var description: String {
        switch self {
        case .oneOver10000: return "1/10000s"
        case .oneOver8000:  return "1/8000s"
        case .oneOver6400:  return "1/6400s"
        case .oneOver5000:  return "1/5000s"
        case .oneOver4000:  return "1/4000s"
        case .oneOver3200:  return "1/3200s"
        case .oneOver2500:  return "1/2500s"
        case .oneOver2000:  return "1/2000s"
        case .oneOver1600:  return "1/1600s"
        case .oneOver1250:  return "1/1250s"
        case .oneOver1000:  return "1/1000s"
        case .oneOver800:   return "1/800s"
        case .oneOver640:   return "1/640s"
        case .oneOver500:   return "1/500s"
        case .oneOver400:   return "1/400s"
        case .oneOver320:   return "1/320s"
        case .oneOver240:   return "1/240s"
        case .oneOver200:   return "1/200s"
        case .oneOver160:   return "1/160s"
        case .oneOver120:   return "1/120s"
        case .oneOver100:   return "1/100s"
        case .oneOver80:    return "1/80s"
        case .oneOver60:    return "1/60s"
        case .oneOver50:    return "1/50s"
        case .oneOver40:    return "1/40s"
        case .oneOver30:    return "1/30s"
        case .oneOver25:    return "1/25s"
        case .oneOver15:    return "1/15s"
        case .oneOver10:    return "1/10s"
        case .oneOver8:     return "1/8s"
        case .oneOver6:     return "1/6s"
        case .oneOver4:     return "1/4s"
        case .oneOver3:     return "1/3s"
        case .oneOver2:     return "1/2s"
        case .oneOver1_5:   return "1/1.5s"
        case .one:          return "1s"
        }
    }
}

/// Camera Iso Sensitivity.
@objc(GSCameraIso)
public enum CameraIso: Int, CustomStringConvertible, Comparable {
    /// 50 iso
    @objc(GSCameraIso50)
    case iso50
    /// 64 iso
    @objc(GSCameraIso64)
    case iso64
    /// 80 iso
    @objc(GSCameraIso80)
    case iso80
    /// 100 iso
    @objc(GSCameraIso100)
    case iso100
    /// 125 iso
    @objc(GSCameraIso125)
    case iso125
    /// 160 iso
    @objc(GSCameraIso160)
    case iso160
    /// 200 iso
    @objc(GSCameraIso200)
    case iso200
    /// 250 iso
    @objc(GSCameraIso250)
    case iso250
    /// 320 iso
    @objc(GSCameraIso320)
    case iso320
    /// 400 iso
    @objc(GSCameraIso400)
    case iso400
    /// 500 iso
    @objc(GSCameraIso500)
    case iso500
    /// 640 iso
    @objc(GSCameraIso640)
    case iso640
    /// 800 iso
    @objc(GSCameraIso800)
    case iso800
    /// 1200 iso
    @objc(GSCameraIso1200)
    case iso1200
    /// 1600 iso
    @objc(GSCameraIso1600)
    case iso1600
    /// 2500 iso
    @objc(GSCameraIso2500)
    case iso2500
    /// 3200 iso
    @objc(GSCameraIso3200)
    case iso3200

    /// Set containing all possible values of CameraShutterSpeed.
    public static let allCases: Set<CameraIso> = [
        iso50, iso64, iso80, iso100, iso125, iso160, iso200, iso250, iso320, iso400, iso500, iso640, iso800,
        iso1200, iso1600, iso2500, iso3200]

    /// Comparator.
    public static func < (lhs: CameraIso, rhs: CameraIso) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    /// Debug description.
    public var description: String {
        switch self {
        case .iso50:   return "iso 50"
        case .iso64:   return "iso 64"
        case .iso80:   return "iso 80"
        case .iso100:  return "iso 100"
        case .iso125:  return "iso 125"
        case .iso160:  return "iso 160"
        case .iso200:  return "iso 200"
        case .iso250:  return "iso 250"
        case .iso320:  return "iso 320"
        case .iso400:  return "iso 400"
        case .iso500:  return "iso 500"
        case .iso640:  return "iso 640"
        case .iso800:  return "iso 800"
        case .iso1200: return "iso 1200"
        case .iso1600: return "iso 1600"
        case .iso2500: return "iso 2500"
        case .iso3200: return "iso 3200"
        }
    }
}

/// Camera exposure setting.
///
/// Allows to configure the exposure mode and parameters, such as:
///     - ISO sensitivity,
///     - Shutter speed.
public protocol CameraExposureSettings: class {
    /// Tells if a setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Supported exposure modes.
    ///
    /// An empty set means that the whole setting is currently unsupported.
    var supportedModes: Set<CameraExposureMode> { get }

    /// Supported shutter speed `manualShutterSpeed` and `manual` mode.
    var supportedManualShutterSpeeds: Set<CameraShutterSpeed> { get }

    /// Supported iso sensitivity `manualIsoSensitivity` and `manual` mode.
    var supportedManualIsoSensitivity: Set<CameraIso> { get }

    /// Supported maximum iso sensitivity values.
    var supportedMaximumIsoSensitivity: Set<CameraIso> { get }

    /// Current exposure mode.
    ///
    /// Value should be considered meaningless in case the set of `supportedModes` is empty.
    var mode: CameraExposureMode { get set }

    /// Shutter speed when exposure mode is `manualShutterSpeed` or `manual` mode.
    ///
    /// Value should be considered meaningless in case the set of `supportedManualShutterSpeeds` is empty.
    /// Value can only be changed to one of the value `supportedManualShutterSpeeds`
    var manualShutterSpeed: CameraShutterSpeed { get set }

    /// Iso sensitivity when exposure mode is `manualIsoSensitivity` or `manual` mode.
    ///
    /// Value should be considered meaningless in case the set of `supportedManualIsoSensitivity` is empty.
    /// Value can only be changed to one of the value `supportedManualIsoSensitivity`
    var manualIsoSensitivity: CameraIso { get set }

    /// Maximum Iso sensitivity when exposure mode is `automatic`.
    ///
    /// Value should be considered meaningless in case the set of `supportedMaximumIsoSensitivity` is empty.
    /// Value can only be changed to one of the value `supportedMaximumIsoSensitivity`
    var maximumIsoSensitivity: CameraIso { get set }

    /// Current auto exposure metering mode..
    var autoExposureMeteringMode: CameraAutoExposureMeteringMode { get set }

    /// Changes exposure mode, manualShutterSpeed, manualIsoSensitivity and maximumIsoSensitivity.
    ///
    /// - Parameters:
    ///   - mode: requested exposure mode
    ///   - manualShutterSpeed: requested manual shutter speed if mode is `manualShutterSpeed` or `manual`, or `nil` to
    ///     keep the current value
    ///   - manualIsoSensitivity: requested iso sensitivity if exposure mode is `manualIsoSensitivity` or `manual`, or
    ///     `nil` to keep the current value
    ///   - maximumIsoSensitivity: requested maximum iso sensitivity when exposure mode is `automatic`, or `nil` to keep
    ///     the current value
    func set(mode: CameraExposureMode, manualShutterSpeed: CameraShutterSpeed?,
             manualIsoSensitivity: CameraIso?, maximumIsoSensitivity: CameraIso?)

    /// Changes exposure mode, manualShutterSpeed, manualIsoSensitivity and maximumIsoSensitivity.
    ///
    /// - Parameters:
    ///   - mode: requested exposure mode
    ///   - manualShutterSpeed: requested manual shutter speed if mode is `manualShutterSpeed` or `manual`, or `nil` to
    ///     keep the current value
    ///   - manualIsoSensitivity: requested iso sensitivity if exposure mode is `manualIsoSensitivity` or `manual`, or
    ///     `nil` to keep the current value
    ///   - maximumIsoSensitivity: requested maximum iso sensitivity when exposure mode is `automatic`, or `nil` to keep
    ///     the current value
    ///   - autoExposureMeteringMode: requested auto exposure metering mode
    func set(mode: CameraExposureMode, manualShutterSpeed: CameraShutterSpeed?,
             manualIsoSensitivity: CameraIso?, maximumIsoSensitivity: CameraIso?,
             autoExposureMeteringMode: CameraAutoExposureMeteringMode?)
}

// MARK: - objc compatibility

/// Settings to configure camera exposure mode and parameters.
/// - Note: This protocol is for Objective-C compatibility only.
@objc public protocol GSCameraExposureSettings {
    /// Tells if a setting value has been changed and is waiting for change confirmation.
    var updating: Bool { get }

    /// Exposure mode.
    var mode: CameraExposureMode { get set }

    /// Shutter speed when exposure mode is `manualShutterSpeed` or `manual` mode.
    var manualShutterSpeed: CameraShutterSpeed { get set }

    /// Iso sensitivity when exposure mode is `manualIsoSensitivity` or `manual` mode.
    var manualIsoSensitivity: CameraIso { get set }

    /// Maximum Iso sensitivity when exposure mode is `automatic`.
    var maximumIsoSensitivity: CameraIso { get set }

    /// Current auto exposure metering mode..
    var autoExposureMeteringMode: CameraAutoExposureMeteringMode { get set }

    /// Checks if a mode is supported.
    ///
    /// - Parameter mode: mode to check
    /// - Returns: `true` if the mode is supported
    func isModeSupported(_ mode: CameraExposureMode) -> Bool

    /// Checks if a manual shutter speed value is supported.
    ///
    /// - Parameter shutterSpeed: shutter speed to test
    /// - Returns: `true` if the shutter speed is supported
    func isManualShutterSpeedSupported(_ shutterSpeed: CameraShutterSpeed) -> Bool

    /// Checks if a manual iso sensitivity value is supported.
    ///
    /// - Parameter iso: iso sensitivity to check
    /// - Returns: `true` if the iso sensitivity is supported
    func isManualIsoSensitivitySupported(_ iso: CameraIso) -> Bool

    /// Checks if a maximum iso sensitivity value is supported.
    ///
    /// - Parameter iso: maximum iso sensitivity to check
    /// - Returns: `true` if the maximum iso sensitivity is supported
    func isMaximumIsoSensitivitySupported(_ iso: CameraIso) -> Bool

    /// Changes exposure mode, manualShutterSpeed, manualIsoSensitivity and maximumIsoSensitivity.
    ///
    /// - Parameters:
    ///   - mode: requested exposure mode
    ///   - manualShutterSpeed: requested manual shutter speed if mode is `manualShutterSpeed` or `manual`, or -1 to
    ///     keep the current value.
    ///   - manualIsoSensitivity: requested iso sensitivity if exposure mode is `manualIsoSensitivity` or `manual`, or
    ///     -1 to keep the current value
    ///   - maximumIsoSensitivity: requested maximum iso sensitivity when exposure mode is `automatic`, or -1 to keep
    ///     the current value
    ///   - autoExposureMeteringMode: requested auto exposure metering mode
    @objc(setMode:manualShutterSpeed:manualIsoSensitivity:maximumIsoSensitivity:autoExposureMeteringMode:)
    func set(mode: CameraExposureMode, manualShutterSpeed: Int, manualIsoSensitivity: Int,
             maximumIsoSensitivity: Int, autoExposureMeteringMode: Int)
}
