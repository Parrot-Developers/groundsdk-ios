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

/// Base protocol for all Peripheral components.
@objc(GSPeripheral)
public protocol Peripheral: Component {
}

/// Peripheral component descriptor.
public protocol PeripheralClassDesc: ComponentApiDescriptor {
    /// Protocol of the peripheral.
    associatedtype ApiProtocol = Peripheral
}

/// Defines all known Peripheral descriptors.
@objcMembers
@objc(GSPeripherals)
public class Peripherals: NSObject {
    /// Magnetometer peripheral.
    public static let magnetometer = MagnetometerDesc()
    /// 3-steps calibration magnetometer peripheral.
    public static let magnetometerWith3StepCalibration = MagnetometerWith3StepCalibrationDesc()
    /// 1-step calibration magnetometer peripheral.
    public static let magnetometerWith1StepCalibration = MagnetometerWith1StepCalibrationDesc()
    /// Drone finder peripheral.
    public static let droneFinder = DroneFinderDesc()
    /// Video stream peripheral.
    public static let streamServer = StreamServerDesc()
    /// Main camera peripheral.
    public static let mainCamera = MainCameraDesc()
    /// Thermal camera peripheral.
    public static let thermalCamera = ThermalCameraDesc()
    /// System info peripheral.
    public static let systemInfo = SystemInfoDesc()
    /// Media store peripheral.
    public static let mediaStore = MediaStoreDesc()
    /// Virtual gamepad peripheral.
    public static let virtualGamepad = VirtualGamepadDesc()
    /// SkyController3 gamepad peripheral.
    public static let skyCtrl3Gamepad = SkyCtrl3GamepadDesc()
    /// Firmware updater peripheral.
    public static let updater = UpdaterDesc()
    /// Copter motors peripheral.
    public static let copterMotors = CopterMotorsDesc()
    /// Wifi scanner peripheral.
    public static let wifiScanner = WifiScannerDesc()
    /// Crash report downloader peripheral.
    public static let crashReportDownloader = CrashReportDownloaderDesc()
    /// Wifi access point peripheral.
    public static let wifiAccessPoint = WifiAccessPointDesc()
    /// Removable user storage.
    public static let removableUserStorage = RemovableUserStorageDesc()
    /// Beeper.
    public static let beeper = BeeperDesc()
    /// Gimbal.
    public static let gimbal = GimbalDesc()
    /// Anti-flicker.
    public static let antiflicker = AntiflickerDesc()
    /// Target Tracker
    public static let targetTracker = TargetTrackerDesc()
    /// Geofence.
    public static let geofence = GeofenceDesc()
    /// File Data (PUD) downloader.
    public static let flightDataDownloader = FlightDataDownloaderDesc()
    /// Flight Log downloader.
    public static let flightLogDownloader = FlightLogDownloaderDesc()
    /// Precise home.
    public static let preciseHome = PreciseHomeDesc()
    /// Thermal control.
    public static let thermalControl = ThermalControlDesc()
    /// Leds.
    public static let leds = LedsDesc()
    /// Copilot.
    public static let copilot = CopilotDesc()
    /// Piloting control.
    public static let pilotingControl = PilotingControlDesc()
}

/// Peripheral uid.
enum PeripheralUid: Int {
    case magnetometer
    case magnetometerWith1StepCalibration
    case magnetometerWith3StepCalibration
    case droneFinder
    case streamServer
    case mainCamera
    case thermalCamera
    case systemInfo
    case mediaStore
    case virtualGamepad
    case skyCtrl3Gamepad
    case updater
    case copterMotors
    case wifiScanner
    case wifiAccessPoint
    case crashReportDownloader
    case pitotTube
    case removableUserStorage
    case beeper
    case gimbal
    case antiflicker
    case targetTracker
    case geofence
    case flightDataDownloader
    case flightLogDownloader
    case preciseHome
    case thermalControl
    case leds
    case copilot
    case pilotingControl
}

/// Objective-C wrapper of Ref<Peripheral>. Required because swift generics can't be used from Objective-C.
/// - Note: This class is for Objective-C only and must not be used in Swift.
@objcMembers
public class GSPeripheralRef: NSObject {

    private let ref: Ref<Peripheral>

    /// Referenced peripheral.
    public var value: Peripheral? {
        return ref.value
    }

    /// Constructor.
    ///
    /// - Parameter ref: referenced peripheral
    init(ref: Ref<Peripheral>) {
        self.ref = ref
    }
}
