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
import CoreLocation

/// Utility protocol allowing to Geolocalization services.
public protocol ReverseGeocoderUtilityCore: UtilityCore {

    /// Latest placemark known
    var placemark: CLPlacemark? { get }

    /// Start monitoring and be informed when `placemark` change
    ///
    /// - Note: When the monitoring is not needed anymore, you should call `stop()` on the monitor otherwise
    ///   the monitor **and** this utility will be leaked.
    ///
    /// - Parameter placemarkDidChange: closure called when placemark changes.
    /// - Returns: a monitor
    func startReverseGeocoderMonitoring(placemarkDidChange: @escaping (CLPlacemark?) -> Void) -> MonitorCore
}

/// Implementation of the `ReverseGeocoderUtilityCore` utility.
class ReverseGeocoderUtilityCoreImpl: ReverseGeocoderUtilityCore {

    let desc: UtilityCoreDescriptor = Utilities.reverseGeocoder

    /// List of registered monitors for placemark.
    private var reverseGeocoderMonitors: Set<ReverseGeocoderMonitor> = []

    private(set) var placemark: CLPlacemark? {
        didSet {
            if placemark != oldValue {
                // Notifies all monitors that the placemark was updated
                reverseGeocoderMonitors.forEach { monitor in monitor.placemarkDidChange?(placemark) }
            }
        }
    }

    /// Update the placemark (used by the ReverseGeocoder Engine)
    public func update(placemark newValue: CLPlacemark?) {
        placemark = newValue
    }

    // MARK: - Monitoring ReverseGeocoder
    // Start monitoring the ReverseGeocoder (Utility interface)
    func startReverseGeocoderMonitoring(placemarkDidChange: @escaping (CLPlacemark?) -> Void) -> MonitorCore {
        let monitor = ReverseGeocoderMonitor(monitorable: self, placemarkDidChange: placemarkDidChange)
        reverseGeocoderMonitors.insert(monitor)
        // call callbacks for initializing values
        monitor.placemarkDidChange?(placemark)
        return monitor
    }

    /// Monitor that calls back a closure when placemark changes.
    private class ReverseGeocoderMonitor: NSObject, MonitorCore {
        /// Called back when placemark changes.
        fileprivate var placemarkDidChange: ((CLPlacemark?) -> Void)?

        /// The monitorable reverseGeocoder utility
        private let monitorable: ReverseGeocoderUtilityCoreImpl

        /// Constructor
        ///
        /// - Parameters:
        ///   - monitorable: the reverseGeocoder utility
        ///   - placemarkDidChange: closure called when placemark changes.
        fileprivate init(monitorable: ReverseGeocoderUtilityCoreImpl,
                         placemarkDidChange: @escaping (CLPlacemark?) -> Void) {
            self.monitorable = monitorable
            self.placemarkDidChange = placemarkDidChange
        }

        public func stop() {
            placemarkDidChange = nil
            monitorable.stopReverseGeocoderMonitoring(with: self)
        }
    }

    /// Stops monitoring with a given monitor.
    ///
    /// - Parameter monitor: the monitor to stop.
    private func stopReverseGeocoderMonitoring(with monitor: ReverseGeocoderMonitor) {
        reverseGeocoderMonitors.remove(monitor)
    }
}

/// ReverseGeocoder utility description
public class ReverseGeocoderUtilityCoreDesc: NSObject, UtilityCoreApiDescriptor {
    public typealias ApiProtocol = ReverseGeocoderUtilityCore
    public let uid = UtilityUid.reverseGeocoder.rawValue
}
