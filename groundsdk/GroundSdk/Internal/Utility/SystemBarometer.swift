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
import CoreMotion

/// Struct representing the measurement of the system Barometer as well as a timestamp of the measurement.
public struct BarometerMeasure: Equatable {
    /// The recorded pressure, in pascals (Pa).
    public let pressure: Double
    /// Timestamp of the recorded measure
    public let timestamp: Date

    /// Constructor
    ///
    /// - Parameters:
    ///   - pressure: The recorded pressure, in pascals (Pa).
    ///   - timestamp: Timestamp of the recorded measure.
    init(pressure: Double, timestamp: Date) {
        self.pressure = pressure
        self.timestamp = timestamp
    }

    /// Constructor with CoreMotion Data
    ///
    /// - Parameter altitudeData: altitude data from a CMAltimeter handler
    init(_ altitudeData: CMAltitudeData) {
        self.pressure = altitudeData.pressure.doubleValue * 1000.0
        self.timestamp = Date()
    }

    /// Equatable concordance
    public static func == (lhs: BarometerMeasure, rhs: BarometerMeasure) -> Bool {
        return lhs.pressure == rhs.pressure && lhs.timestamp == rhs.timestamp
    }
}

/// Utility protocol allowing to device's Barometer / Altitude services.
public protocol SystemBarometerCore: UtilityCore {

    /// Latest barometer measure.
    var barometerMeasure: BarometerMeasure? { get }

    /// Start monitoring and be informed when `barometerMeasure` changes
    ///
    /// - Note: When the monitoring is not needed anymore, you should call `stop()` on the monitor otherwise
    ///   the monitor **and** this utility will be leaked. `startHeadingMonitoring()` requests continuous barometer
    ///   measure updates.
    ///
    /// - Parameter mesureDidChange: closure called when user's barometer's measure changes.
    /// - Returns: a monitor only if the device supports generating data for barometer, `nil` otherwise.
    func startMonitoring(measureDidChange: @escaping (BarometerMeasure?) -> Void) -> MonitorCore?
}

/// Implementation of the `UserLocationCore` utility.
class SystemBarometerCoreImpl: SystemBarometerCore {

    let desc: UtilityCoreDescriptor = Utilities.systemBarometer

    /// Monitor that calls back a closure when barometer's measure changes.
    private class BarometerMonitor: NSObject, MonitorCore {
        /// Called back when barometer's measure changes.
        fileprivate var measureDidChange: ((BarometerMeasure?) -> Void)?

        /// The monitorable User Location utility
        private let monitorable: SystemBarometerCoreImpl

        /// Constructor
        ///
        /// - Parameters:
        ///   - monitorable: the User Location utility
        ///   - measureDidChange: closure called when barometer's measure changes.
        fileprivate init(
            monitorable: SystemBarometerCoreImpl, measureDidChange: @escaping (BarometerMeasure?) -> Void) {
            self.monitorable = monitorable
            self.measureDidChange = measureDidChange
        }

        public func stop() {
            measureDidChange = nil
            monitorable.stopBarometerMonitoring(with: self)
        }
    }

    /// All registered monitors for barometer
    private var barometerMonitors = Set<BarometerMonitor>()

    private(set) var barometerMeasure: BarometerMeasure? {
        didSet {
            if barometerMeasure != oldValue {
                // Notifies all monitors that a barometer measure was updated
                barometerMonitors.forEach { monitor in monitor.measureDidChange?(barometerMeasure) }
            }
        }
    }

    /// System altitude-related changes manager.
    private lazy var cmAltimeter = CMAltimeter()

    /// Whether continuous barometer updates are required. Altitude services will be started or stopped
    /// accordingly.
    private var needsBarometerUpdates = false {
        didSet {
            if oldValue != needsBarometerUpdates {
                if needsBarometerUpdates {
                    let handler: CMAltitudeHandler = { [unowned self] (altitudeData, error) in
                        if let altitudeData = altitudeData, error == nil {
                            self.barometerMeasure = BarometerMeasure(altitudeData)
                        } else {
                            self.barometerMeasure = nil
                        }
                    }
                    cmAltimeter.startRelativeAltitudeUpdates(to: OperationQueue.main, withHandler: handler)
                } else {
                    cmAltimeter.stopRelativeAltitudeUpdates()
                }
            }
        }
    }

    /// `true` if the utility is used without the system's Barometer (for testing), `false` otherwise
    private let mockVersionWithoutAltimeter: Bool

    /// Constructor
    init() {
        // normal use of the utility
        mockVersionWithoutAltimeter = false
    }

    /// Constructor only for testing (mock version)
    ///
    /// - Parameter mockVersion: any String (this parameter is just present to differentiate the mock Init)
    init(mockVersion: String) {
        // disable the system cmAltimeter. AltitudeData measurements will be simulated
        mockVersionWithoutAltimeter = true
    }

    /// Auto check the start/stop Altimeter Services
    ///
    /// This function starts or stop the barometer continuous update according to existing subscribers
    private func checkStartStopServices() {
        guard !mockVersionWithoutAltimeter else {
            return
        }
        // --- Check for altitude updates
        // if existing subscribers for heading
        needsBarometerUpdates = barometerMonitors.count > 0
    }

    /// Stops monitoring with a given monitor.
    ///
    /// - Parameter monitor: the monitor to stop.
    private func stopBarometerMonitoring(with monitor: BarometerMonitor) {
        barometerMonitors.remove(monitor)
        checkStartStopServices()
    }

    // MARK: - Monitoring Barometer
    // Start monitoring for barometer (Utility interface)
    func startMonitoring(measureDidChange: @escaping (BarometerMeasure?) -> Void) -> MonitorCore? {
        // Guard that the device supports relative altitude changes.
        guard CMAltimeter.isRelativeAltitudeAvailable() || mockVersionWithoutAltimeter else {
            return nil
        }
        let monitor = BarometerMonitor(monitorable: self, measureDidChange: measureDidChange)
        barometerMonitors.insert(monitor)
        checkStartStopServices()
        return monitor
    }

    // MARK: - MOCK Barometer
    /// Mock barometer measure for tests
    ///
    /// - Parameter measure: BarometerMeasure in order to simulate the result of a CMAltimeter
    /// - Returns: true if at least a monitor is registered, false otherwise and do nothing.
    func mockBarometerMeasure(_ measure: BarometerMeasure) -> Bool {
        guard barometerMonitors.count > 0 else {
            return false
        }
        barometerMeasure = measure
        return true
    }

}

/// System Barometer utility description
public class SystemBarometerCoreDesc: NSObject, UtilityCoreApiDescriptor {
    public typealias ApiProtocol = SystemBarometerCore
    public let uid = UtilityUid.systemBarometer.rawValue
}
