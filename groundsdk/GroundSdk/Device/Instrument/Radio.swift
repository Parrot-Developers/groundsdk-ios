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

/// Instrument that informs about the radio.
///
/// This instrument can be retrieved by:
/// ```
/// drone.getInstrument(Instruments.radio)
/// ```
public protocol Radio: Instrument {

    /// Received signal strength indication (RSSI), expressed in dBm.
    /// Usually between -30 (good signal) and -80 (very bad signal level), 0 if undefined.
    var rssi: Int { get }

    /// The quality varies from 0 to 4.
    ///
    /// (0) means that a disconnection is highly probable, (4) means that the link signal quality is very good.
    /// 'nil' if undefined.
    var linkSignalQuality: Int? { get }

    /// Whether the radio link is perturbed by external elements.
    /// `true` if the link signal quality is low although the link quality might be good.
    /// This indicates that the radio link is perturbed by external elements.
    var isLinkPerturbed: Bool { get }

    /// Whether the smartphone's 4G is interfering.
    /// 'true' if a 4G interference is currently detected.
    /// In that case, it is advised to disable smartphone's 4G.
    var is4GInterfering: Bool { get }
}

// MARK: Objective-C API
/// Instrument that informs about the radio.
///
/// This instrument can be retrieved by:
/// ```
/// id<GSRadio> radio = (id<GSRadio>)[drone getInstrument:GSInstruments.radio];
/// ```
/// - Note: This protocol is for Objective-C only. Swift must use the protocol `Radio`.
@objc
public protocol GSRadio {
    /// Received signal strength indication (RSSI), expressed in dBm.
    /// Usually between -30 (good signal) and -80 (very bad signal level), 0 if undefined
    var rssi: Int { get }

    /// The quality varies from 0 to 4.
    /// (0) means that a disconnection is highly probable, (4) means that the link signal quality is very good.
    ///
    /// (-1) if the linkSignalQuality in undefined.
    @objc(linkSignalQuality)
    var gsLinkSignalQuality: Int { get }

    /// Whether the radio link is perturbed by external elements.
    /// `true` if the link signal quality is low although the link quality might be good.
    /// This indicates that the radio link is perturbed by external elements.
    var isLinkPerturbed: Bool { get }

    /// Whether the smartphone's 4G is interfering.
    /// 'true' if a 4G interference is currently detected.
    /// In that case, it is advised to disable smartphone's 4G.
    var is4GInterfering: Bool { get }
}

/// :nodoc:
/// Instrument descriptor
public class RadioDesc: NSObject, InstrumentClassDesc {
    public typealias ApiProtocol = Radio
    public let uid = InstrumentUid.radio.rawValue
    public let parent: ComponentDescriptor? = nil
}
