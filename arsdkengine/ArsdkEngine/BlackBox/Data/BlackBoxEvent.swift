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
import GroundSdk

/// Black box event factory
struct BlackBoxEvent: Encodable {

    /// Obtains an alert state change event
    ///
    /// - Parameter state: alert state
    /// - Returns: alert state change event
    static func alertStateChange(_ state: Int) -> BlackBoxEvent {
        return BlackBoxEvent(type: "product_alert", value: state)
    }

    /// Obtains a hovering warning event
    ///
    /// - Parameter tooDark: `true` if the reason is darkness, `false` if it's the drone height
    /// - Returns: hovering warning event
    static func hoveringWarning(tooDark: Bool) -> BlackBoxEvent {
        return BlackBoxEvent(type: "product_hovering_warning", value: tooDark ? "no_gps_too_dark" : "no_gps_too_high")
    }

    /// Obtains a forced landing event
    ///
    /// - Parameter reason: forced landing reason
    /// - Returns: forced landing event
    static func forcedLanding(_ reason: Int) -> BlackBoxEvent {
        return BlackBoxEvent(type: "product_forced_landing", value: reason)
    }

    /// Obtains a wind state change event
    ///
    /// - Parameter state: wind state
    /// - Returns: wind state change event
    static func windStateChange(_ state: Int) -> BlackBoxEvent {
        return BlackBoxEvent(type: "product_wind", value: state)
    }

    /// Obtains a vibration level change event
    ///
    /// - Parameter state: vibration level state
    /// - Returns: vibration level change event
    static func vibrationLevelChange(_ state: Int) -> BlackBoxEvent {
        return BlackBoxEvent(type: "product_vibration_level", value: state)
    }

    /// Obtains a motor error event
    ///
    /// - Parameter error: motor error
    /// - Returns: motor error event
    static func motorError(_ error: Int) -> BlackBoxEvent {
        return BlackBoxEvent(type: "product_motor_error", value: error)
    }

    /// Obtains a battery alert event
    ///
    /// - Parameters:
    ///   - critical: `true` if the alert is critical, `false` if it's a warning
    ///   - type: alert type
    /// - Returns: battery alert event
    static func batteryAlert(critical: Bool, type: Int) -> BlackBoxEvent {
        return BlackBoxEvent(type: "product_battery_" + (critical ? "critical" : "warning"), value: type)
    }

    /// Obtains a sensor error event
    ///
    /// - Parameter sensor: sensor
    /// - Returns: sensor error event
    static func sensorError(_ sensor: Int) -> BlackBoxEvent {
        return BlackBoxEvent(type: "product_sensor_error", value: sensor)
    }

    /// Obtains a battery level change event
    ///
    /// - Parameter level: battery level
    /// - Returns: battery level change event
    static func batteryLevelChange(_ level: Int) -> BlackBoxEvent {
        return BlackBoxEvent(type: "product_battery", value: level)
    }

    /// Obtains a country change event
    ///
    /// - Parameter level: country code
    /// - Returns: country change event
    static func countryChange(countryCode: String) -> BlackBoxEvent {
        return BlackBoxEvent(type: "wifi_country", value: countryCode)
    }

    /// Obtains a flight plan state change event
    ///
    /// - Parameter state: flight plan state
    /// - Returns: flight plan state change event
    static func flightPlanStateChange(state: Int) -> BlackBoxEvent {
        return BlackBoxEvent(type: "product_fp_state", value: state)
    }

    /// Obtains a flying state change event
    ///
    /// - Parameter state: flying state
    /// - Returns: flying state change event
    static func flyingStateChange(state: Int) -> BlackBoxEvent {
        return BlackBoxEvent(type: "product_flying_state", value: state)
    }

    /// Obtains a follow me mode change event
    ///
    /// - Parameter mode: follow me mode
    /// - Returns: follow me mode change event
    static func followMeModeChange(mode: Int) -> BlackBoxEvent {
        return BlackBoxEvent(type: "product_followme_state", value: mode)
    }

    /// Obtains a gps fix change event
    ///
    /// - Parameter fix: gps fix (1 if fixed, 0 if not)
    /// - Returns: gps fix change event
    static func gpsFixChange(fix: Int) -> BlackBoxEvent {
        return BlackBoxEvent(type: "product_gps_fix", value: fix)
    }

    /// Obtains a home location change event
    ///
    /// - Parameter location: home location
    /// - Returns: country change event
    static func homeLocationChange(location: BlackBoxLocationData) -> BlackBoxEvent {
        return BlackBoxEvent(type: "product_home", value: location)
    }

    /// Obtains a landing event
    ///
    /// - Returns: landing event
    static func landing() -> BlackBoxEvent {
        return BlackBoxEvent(type: "app_command", value: "landing")
    }

    /// Obtains a remote controller button action change event
    ///
    /// - Parameter action: button action code
    /// - Returns: remote controller button action
    static func rcButtonAction(_ action: Int) -> BlackBoxEvent {
        return BlackBoxEvent(type: "mpp_button", value: action)
    }

    /// Obtains a return-home state change event
    ///
    /// - Parameter state: return home state
    /// - Returns: return-home state change event
    static func returnHomeStateChange(_ state: Int) -> BlackBoxEvent {
        return BlackBoxEvent(type: "product_rth_state", value: state)
    }

    /// Obtains a run id change event
    ///
    /// - Parameter runId: run identifier
    /// - Returns: run identifier change event
    static func runIdChange(_ runId: String) -> BlackBoxEvent {
        return BlackBoxEvent(type: "product_run_id", value: runId)
    }

    /// Obtains a take-off location event
    ///
    /// - Parameter location: takeoff location
    /// - Returns: take-off location event
    static func takeOffLocation(_ location: BlackBoxLocationData) -> BlackBoxEvent {
        return BlackBoxEvent(type: "product_gps_takingoff", value: location)
    }

    /// Obtains a wifi band change event
    ///
    /// - Parameter band: wifi band
    /// - Returns: wifi band change event
    static func wifiBandChange(_ band: Int) -> BlackBoxEvent {
        return BlackBoxEvent(type: "wifi_band", value: band)
    }

    /// Obtains a wifi channel change event
    ///
    /// - Parameter channel: wifi channel
    /// - Returns: wifi channel change event
    static func wifiChannelChange(_ channel: Int) -> BlackBoxEvent {
        return BlackBoxEvent(type: "wifi_channel", value: channel)
    }

    /// The encodable data (used for type erasure)
    private let encodable: Encodable

    /// Constructor
    ///
    /// - Parameters:
    ///   - type: type of the event
    ///   - value: value of the event, might be anything that is encodable.
    private init<DataType: Encodable>(type: String, value: DataType) {
        encodable = BlackBoxEventData(type: type, value: value)
    }

    func encode(to encoder: Encoder) throws {
        try encodable.encode(to: encoder)
    }
}

/// Black box event data
/// This object is needed to provide type erasure.
private struct BlackBoxEventData<DataType: Encodable>: Encodable {
    private enum CodingKeys: String, CodingKey {
        case timestamp
        case type
        case value = "datas"
    }

    /// Timestamp of the event
    fileprivate let timestamp = TimeProvider.timeInterval
    /// Type of the event
    fileprivate let type: String
    /// Value of the event
    fileprivate let value: DataType
}
