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

/// Base protocol for all Instrument components.
@objc(GSInstrument)
public protocol Instrument: Component {
}

/// Instrument component descriptor.
public protocol InstrumentClassDesc: ComponentApiDescriptor {
    /// Protocol of the instrument
    associatedtype ApiProtocol = Instrument
}

/// Defines all known Instrument descriptors.
@objcMembers
@objc(GSInstruments)
public class Instruments: NSObject {
    /// Flying indicators instrument.
    public static let flyingIndicators = FlyingIndicatorsDesc()
    /// Alarms information instrument.
    public static let alarms = AlarmsDesc()
    /// Location instrument.
    public static let gps = GpsDesc()
    /// Heading instrument.
    public static let compass = CompassDesc()
    /// Altimeter instrument.
    public static let altimeter = AltimeterDesc()
    /// Speedometer instrument.
    public static let speedometer = SpeedometerDesc()
    /// Attitude instrument.
    public static let attitudeIndicator = AttitudeIndicatorDesc()
    /// Radio instrument.
    public static let radio = RadioDesc()
    /// Battery information instrument.
    public static let batteryInfo = BatteryInfoDesc()
    /// Flight meter instrument.
    public static let flightMeter = FlightMeterDesc()
    /// Camera exposure values instrument.
    public static let cameraExposureValues = CameraExposureValuesDesc()
    /// Photo progress instrument.
    public static let photoProgressIndicator = PhotoProgressIndicatorDesc()
}

/// Instruments uid.
enum InstrumentUid: Int {
    case flyingIndicators = 1
    case alarms
    case gps
    case compass
    case altimeter
    case speedometer
    case attitudeIndicator
    case radio
    case batteryInfo
    case flightMeter
    case cameraExposureValues
    case photoProgressIndicator
}

/// Objective-C wrapper of Ref<Instrument>. Required because swift generics can't be used from Objective-C.
/// - Note: This class is for Objective-C only and must not be used in Swift.
@objcMembers
public class GSInstrumentRef: NSObject {
    private let ref: Ref<Instrument>

    /// Referenced instrument.
    public var value: Instrument? {
        return ref.value
    }

    /// Constructor.
    ///
    /// - Parameter ref: referenced instrument
    init(ref: Ref<Instrument>) {
        self.ref = ref
    }
}
