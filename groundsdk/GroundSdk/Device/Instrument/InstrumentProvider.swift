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

/// Protocol that provides functions to get instruments.
public protocol InstrumentProvider {
    /// Gets an instrument.
    ///
    /// Returns the requested instrument or `nil` if the drone doesn't have the requested instrument
    /// or if the instrument is not available in the current connection state.
    ///
    /// - Parameter desc: requested instrument. See `Instruments` api for available descriptors instances.
    /// - Returns: requested instrument
    func getInstrument<Desc: InstrumentClassDesc>(_ desc: Desc) -> Desc.ApiProtocol?

    /// Gets an instrument and registers an observer notified each time it changes.
    ///
    /// If the instrument is present, the observer will be called immediately with. If the instrument is not present,
    /// the observer won't be called until the instrument is added to the drone.
    /// If the instrument or the drone are removed, the observer will be notified and referenced value is set to `nil`.
    ///
    /// - Parameters:
    ///    - desc: requested instrument. See `Instruments` api for available descriptors instances.
    ///    - observer: observer to notify when the instrument changes
    /// - Returns: reference to the requested instrument
    func getInstrument<Desc: InstrumentClassDesc>(_ desc: Desc,
                              observer: @escaping Ref<Desc.ApiProtocol>.Observer) -> Ref<Desc.ApiProtocol>
}

/// Protocol that provides functions to get instruments.
/// Those methods should no be used from Swift.
@objc
public protocol GSInstrumentProvider {
    /// Gets an instrument.
    ///
    /// - Parameter desc: requested instrument. See `Instruments` api for available descriptors instances.
    /// - Returns: requested instrument
    /// - Note: This method is for Objective-C only. Swift must use `func getInstrument:`.
    @objc(getInstrument:)
    func getInstrument(desc: ComponentDescriptor) -> Instrument?

    /// Gets an instrument and registers an observer notified each time it changes.
    ///
    /// - Parameters:
    ///    - desc: requested instrument. See `Instruments` api for available descriptors instances.
    ///    - observer: observer to notify when the instrument changes
    /// - Returns: reference to the requested instrument
    /// - Note: This method is for Objective-C only. Swift must use `func getInstrument:desc:observer`.
    @objc(getInstrument:observer:)
    func getInstrumentRef(desc: ComponentDescriptor, observer: @escaping (Instrument?) -> Void)
        -> GSInstrumentRef
}
