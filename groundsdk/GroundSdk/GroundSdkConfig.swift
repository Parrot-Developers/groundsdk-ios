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

/// Global GroundSdk configuration
///
/// Allows application to configure GroundSdk features. This configuration can be set by adding entries in the
/// application `info.plist` or by setting properties on the config shared instance **before** creating the
/// first `GroundSdk` instance (the best place for that is the `init` function of your `AppDelegate`).
///
/// In the application `info.plist`, configuration is set by adding an entry `GroundSdk`, type `Dictionary`, with
/// the following content:
///  - `Wifi` (Bool): enable local wifi support. Default is `true`.
///  - `Usb` (Bool): enable Usb support (for sky controllers). Default is `true`.
///  - `UsbDebug` (Bool): enable usb debug bridge support. Default is `false`.
///  - `Ble` (Bool): enable deprecated Ble support. Default is `false`.
///
///  - `SupportedDevices` (Array of String): List of all supported devices by the application. Default is all.
///     The devices name that should be given are the `description` of each `DeviceModel` you want to support.
///     The supported device list is used to restrict the device discovery. Thus, any saved device whose model is
///     restricted, will still be persisted (but never seen again).
///
///  - `OfflineSettings` (String): enable offline settings and send them to the drone at connection. Default is `model`.
///      - `off`: disable
///      - `model`: share settings between all drones of the same model
///
///  - `CrashReport` (Bool): enable crash reports from drone or remote control to be shared with Parrot. Default is
///     `true`.
///
///  - `FlightData` (Bool): enable download flight data files from drone. Default is `true`.
///
///  - `FlightLog` (Bool): enable flight logs (from drone or remote control) to be shared with Parrot. Default is
///     `true`.
///
///  - `GutmaLog` (Bool): enable convert flight data files from drone to GUTMA. Default is `true`.
///
///  - `BlackBox` (Bool): enable black box recording and sharing these records with Parrot. Default is `true`.
///
///  - `FirmwareSync` (Bool): enable firmware synchronization. Default is `true`.
///
///  - `AutoConnectionAtStartup` (Bool): Whether or not the auto connection should start immediately when GroundSdk is
///     started. Default is `false`.
///
///  - `AppDefaults` ([String: String]): Dictionary that list all plist file names describing the application default
///     values for the devices.
///     Indexed by device model name. Default is empty.
///
///  - `EmbeddedFirmwares` (Array of String): List of plist file names that describes the embedded firmwares.
///     Default is empty. Ignored if `FirmwareSync` is `false`.
///
///  - `BlacklistedVersions` (Array of String): List of plist file names that describe the blacklisted firmware
///     versions. Default is empty. Ignored if `FirmwareSync` is `false`.
///
///  - `AutoSelectWifiCountry` (Bool): Whether or not the auto wifi selection, based on reverse geocoding, is used.
///      Default is `true`.
///
///  - `Ephemeris` (Bool): Ephemeris files help the drone to be aware of its own gps position faster.
///      Default is `true`.
///
///  - `DevToolbox` (Bool): enable development toolbox. Default is `false`.
///
/// Example: Enable Usb debug and disable offline settings
///
///     <key>GroundSdk</key>
///      <dict>
///        <key>UsbDebug</key> <true/>
///        <key>OfflineSettings</key> <string>off</string>
///     </dict>
@objcMembers
@objc(GSConfig)
public class GroundSdkConfig: NSObject {

    /// Configuration singleton instance.
    public private(set) static var sharedInstance = GroundSdkConfig()

    /// Offline settings modes.
    public enum OfflineSettingsMode: Int {
        /// Don't allow offline settings, don't store any value.
        case off
        /// Allow offline settings, settings values are shared by all devices of the same model.
        case model

        /// Constructor from a string.
        init?(_ str: String) {
            switch str {
            case "off":
                self = .off
            case "model":
                self = .model
            default:
                return nil
            }
        }
    }

    /// Application key.
    public var applicationKey: String? {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Whether Wifi backend is enabled.
    public var enableWifi = true {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Whether Usb backend is enabled.
    public var enableUsb = true {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Whether Usb debug backend is enabled.
    public var enableUsbDebug = false {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Whether BLE backend is enabled.
    public var enableBle = false {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Enable offline settings and send them to the drone at connection.
    public var offlineSettings = OfflineSettingsMode.model {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Enable crash reporting.
    /// If the drone or the remote control connected crashes, the crash report will be shared with Parrot.
    public var enableCrashReport = true {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Enable FlightData (PUD).
    public var enableFlightData = true {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Enable FlightLog.
    public var enableFlightLog = true {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Enable gutma log
    public var enableGutmaLog = true {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Enable black box recording and sending them to Parrot's servers.
    /// If set to `true`, as soon as a device is connecting, a black box will be recorded in memory. Then, when
    /// the drone is disconnected, this black box is stored on the file system and will be sent to Parrot's servers.
    /// If no drone is connected, the remote control black box is abandoned.
    public var enableBlackBox = true {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Enable firmware synchronization.
    public var enableFirmwareSynchronization = true {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Alternate firmware server.
    public var alternateFirmwareServer: String? {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// List of all supported devices
    public var supportedDevices = DeviceModel.allDevices {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Whether or not the auto connection should automatically start when GroundSdk starts.
    public var autoConnectionAtStartup = false {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Whether or not the auto wifi selection, based on reverse geocoding, is used.
    public var autoSelectWifiCountry = true {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Ephemeris management.
    public var enableEphemeris = true {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Black box quota in mega bytes.
    public var blackBoxQuotaMb: Int? {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Flight log quota in mega bytes.
    public var flightLogQuotaMb: Int? {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Flight data quota in mega bytes.
    public var flightDataQuotaMb: Int? {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Gutma log quota in mega bytes.
    public var gutmaLogQuotaMb: Int? {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Crash report quota in mega bytes.
    public var crashReportQuotaMb: Int? {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Black box public folder.
    public var blackboxPublicFolder: String? {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Whether development toobox is enabled.
    public var enableDevToolbox = false {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// List of all supported devices.
    /// This API is ObjC only. For Swift, please use `supportedDevices`.
    @objc(supportedDevices)
    public var gsSupportedDevices: Set<GSDeviceModel> {
        get {
            return Set(supportedDevices.map { GSDeviceModel(deviceModel: $0) })
        }
        set(newGsSupportedDevices) {
            supportedDevices = Set(newGsSupportedDevices.map { $0.deviceModel })
        }
    }

    /// Application default values for the devices.
    /// It is the name of the plist describing app defaults for a given device model, indexed by device model.
    public var appDefaults: [DeviceModel: String] = [:] {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Embedded firmware descriptors.
    ///
    /// A descriptor is the name of the plist (located in the main bundle) that declares all informations about the
    /// embedded firmwares.
    public var embeddedFirmwareDescriptors: [String] = [] {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Embedded blacklisted firmware versions descriptors.
    ///
    /// A descriptor is the name of the plist (located in the main bundle) that declares all informations about the
    /// blacklisted firmwares.
    public var embeddedBlacklistedVersionDescriptors: [String] = [] {
        willSet(newValue) {
            checkLocked()
        }
    }

    /// Constructor.
    private override init() {
        let config = Bundle.main.object(forInfoDictionaryKey: Keys.root.rawValue) as? [String: Any]
        if let applicationKey = config?[Keys.applicationKey.rawValue] as? String {
            self.applicationKey = applicationKey
        }
        if let enableWifi = config?[Keys.enableWifi.rawValue] as? Bool {
            self.enableWifi = enableWifi
        }
        if let enableUsb = config?[Keys.enableUsb.rawValue] as? Bool {
            self.enableUsb = enableUsb
        }
        if let enableUsbDebug = config?[Keys.enableUsbDebug.rawValue] as? Bool {
            self.enableUsbDebug = enableUsbDebug
        }
        if let enableBle = config?[Keys.enableBle.rawValue] as? Bool {
            self.enableBle = enableBle
        }
        if let offlineSettingsStr = config?[Keys.offlineSettings.rawValue] as? String,
            let offlineSettings = OfflineSettingsMode(offlineSettingsStr) {
            self.offlineSettings = offlineSettings
        }
        if let enableCrashReport = config?[Keys.enableCrashReport.rawValue] as? Bool {
            self.enableCrashReport = enableCrashReport
        }
        if let enableFlightData = config?[Keys.enableFlightData.rawValue] as? Bool {
            self.enableFlightData = enableFlightData
        }
        if let enableFlightLog = config?[Keys.enableFlightLog.rawValue] as? Bool {
            self.enableFlightLog = enableFlightLog
        }
        if let enableGutmaLog = config?[Keys.enableGutmaLog.rawValue] as? Bool {
            self.enableGutmaLog = enableGutmaLog
        }
        if let enableBlackBox = config?[Keys.enableBlackBox.rawValue] as? Bool {
            self.enableBlackBox = enableBlackBox
        }
        if let enableFirmwareSynchronization = config?[Keys.enableFirmwareSynchronization.rawValue] as? Bool {
            self.enableFirmwareSynchronization = enableFirmwareSynchronization
        }
        if let alternateFirmwareServer = config?[Keys.firmwareServer.rawValue] as? String,
            !alternateFirmwareServer.isEmpty {
            self.alternateFirmwareServer = alternateFirmwareServer
        }
        if let supportedDevicesArr = config?[Keys.supportedDevices.rawValue] as? [String] {
            var supportedDevices: Set<DeviceModel> = []
            for deviceModelName in supportedDevicesArr {
                guard let deviceModel = DeviceModel.from(name: deviceModelName) else {
                    preconditionFailure("Invalid device model name: \(deviceModelName). Fix GroundSDK configuration")
                }
                supportedDevices.insert(deviceModel)
            }
            self.supportedDevices = supportedDevices
        }
        if let autoConnectionAtStartup = config?[Keys.autoConnectionAtStartup.rawValue] as? Bool {
            self.autoConnectionAtStartup = autoConnectionAtStartup
        }
        if let appDefaultsProductsDict = config?[Keys.appDefaults.rawValue] as? [String: String] {
            var appDefaultsDevices: [DeviceModel: String] = [:]
            appDefaultsProductsDict.forEach {
                guard let deviceModel = DeviceModel.from(name: $0.key) else {
                    preconditionFailure("Invalid device model name: \($0.key). Fix GroundSDK configuration")
                }
                guard appDefaultsDevices[deviceModel] == nil else {
                    preconditionFailure("Default product for model: \(deviceModel) is declared multiple times. " +
                        "Fix GroundSDK configuration")
                }
                appDefaultsDevices[deviceModel] = $0.value
            }
            self.appDefaults = appDefaultsDevices
        }
        if let embeddedFirmwareDescriptors = config?[Keys.embeddedFirmwares.rawValue] as? [String] {
            self.embeddedFirmwareDescriptors = embeddedFirmwareDescriptors
        }
        if let embeddedBlacklistedVersionDescriptors = config?[Keys.blacklistedVersions.rawValue] as? [String] {
            self.embeddedBlacklistedVersionDescriptors = embeddedBlacklistedVersionDescriptors
        }
        if let autoSelectWifiCountry = config?[Keys.autoSelectWifiCountry.rawValue] as? Bool {
            self.autoSelectWifiCountry = autoSelectWifiCountry
        }
        if let enableEphemeris = config?[Keys.enableEphemeris.rawValue] as? Bool {
            self.enableEphemeris = enableEphemeris
        }
        if let blackBoxQuotaMb = config?[Keys.blackBoxQuotaMb.rawValue] as? Int {
            self.blackBoxQuotaMb = blackBoxQuotaMb
        }
        if let flightLogQuotaMb = config?[Keys.flightLogQuotaMb.rawValue] as? Int {
            self.flightLogQuotaMb = flightLogQuotaMb
        }
        if let flightDataQuotaMb = config?[Keys.flightDataQuotaMb.rawValue] as? Int {
            self.flightDataQuotaMb = flightDataQuotaMb
        }
        if let gutmaLogQuotaMb = config?[Keys.gutmaLogQuotaMb.rawValue] as? Int {
            self.gutmaLogQuotaMb = gutmaLogQuotaMb
        }
        if let crashReportQuotaMb = config?[Keys.crashReportQuotaMb.rawValue] as? Int {
            self.crashReportQuotaMb = crashReportQuotaMb
        }
        if let blackboxPublicFolder = config?[Keys.blackboxPublicFolder.rawValue] as? String,
            !blackboxPublicFolder.isEmpty {
            self.blackboxPublicFolder = blackboxPublicFolder
        }
        if let enableDevToolbox = config?[Keys.enableDevToolbox.rawValue] as? Bool {
            self.enableDevToolbox = enableDevToolbox
        }
    }

    /// Settings info.plist keys.
    private enum Keys: String {
        case root = "GroundSdk"
        case applicationKey = "ApplicationKey"
        case enableWifi = "Wifi"
        case enableUsb = "Usb"
        case enableUsbDebug = "UsbDebug"
        case enableBle = "Ble"
        case offlineSettings = "OfflineSettings"
        case enableCrashReport = "CrashReport"
        case enableFlightData = "FlightData"
        case enableGutmaLog = "GutmaLog"
        case enableFirmwareSynchronization = "FirmwareSync"
        case firmwareServer = "FirmwareServer"
        case supportedDevices = "SupportedDevices"
        case autoConnectionAtStartup = "AutoConnectionAtStartup"
        case enableBlackBox = "BlackBox"
        case appDefaults = "AppDefaults"
        case embeddedFirmwares = "EmbeddedFirmwares"
        case blacklistedVersions = "BlacklistedVersions"
        case autoSelectWifiCountry = "AutoSelectWifiCountry"
        case enableEphemeris = "Ephemeris"
        case enableFlightLog = "FlightLog"
        case blackBoxQuotaMb = "BlackBoxQuotaMb"
        case flightLogQuotaMb = "FlightLogQuotaMb"
        case flightDataQuotaMb = "FlightDataQuotaMb"
        case gutmaLogQuotaMb = "GutmaLogQuotaMb"
        case crashReportQuotaMb = "CrashReportQuotaMb"
        case blackboxPublicFolder = "BlackboxPublicFolder"
        case enableDevToolbox = "DevToolbox"
    }

    /// `true` if configuration is locked, i.e. the first ground sdk instance has already been created.
    private var locked = false

    /// Locks configuration.
    func lock() {
        locked = true
    }

    /// Reloads configuration. Only for unit testing.
    static public func reload() {
        sharedInstance = GroundSdkConfig()
    }

    private func checkLocked() {
        if locked {
            assertionFailure("GroundSdkConfig must be set before starting the first session.")
        }
    }
}
