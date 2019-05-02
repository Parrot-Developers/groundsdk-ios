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

/// Geofence modes, indicating the zone type where the drone is able to fly.
@objc(GSGeofenceMode)
public enum GeofenceMode: Int, CustomStringConvertible {
    /// The drone flying zone is only bounded by the maximum altitude setting.
    case altitude
    /// The drone flying zone is bounded by the cylinder defined by the maximum altitude and distance settings.
    case cylinder

    /// Debug description.
    public var description: String {
        switch self {
        case .altitude: return "altitude"
        case .cylinder: return "cylinder"
        }
    }
}

/// Setting providing access to the GeofenceMode.
@objc(GSGeofenceMode)
public protocol GeofenceModeSetting: class {
    /// Tells if the setting value has been changed and is waiting for change confirmation
    var updating: Bool { get }

    /// Geofence mode value.
    var value: GeofenceMode { get set }
}

/// Geofence peripheral interface.
///
/// This peripheral provides access to geofence settings, which prevent the drone from flying over the given altitude
/// and distance.
///
/// This peripheral can be retrieved by:
/// ```
/// device.getPeripheral(Peripherals.geofence)
/// ```
@objc(GSGeofence)
public protocol Geofence: Peripheral {

    /// Maximum altitude setting.
    /// This setting allows to define the maximum altitude relative to the takeoff altitude, in meters. The drone won't
    /// go higher than this maximum altitude.
    var maxAltitude: DoubleSetting { get }

    /// Maximum distance setting.
    /// This setting allows to define the maximum distance relative to the `geofenceCenter` in meters.
    ///
    /// If current `geofenceMode` is `.cylinder`, the drone won't fly over the given distance in any piloting mode,
    /// otherwise this setting is ignored.
    var maxDistance: DoubleSetting { get }

    /// Geofence mode setting.
    var mode: GeofenceModeSetting { get }

    /// Geofence center location.
    ///
    /// This location represents the center of the geofence zone. This can be either the controller position, or the
    /// home location.
    var center: CLLocation? { get }
}

/// :nodoc:
/// Geofence description
@objc(GSGeofenceDesc)
public class GeofenceDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = Geofence
    public let uid = PeripheralUid.geofence.rawValue
    public let parent: ComponentDescriptor? = nil
}
