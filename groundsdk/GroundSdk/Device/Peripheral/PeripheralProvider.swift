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

/// Protocol that provides functions to get peripherals.
public protocol PeripheralProvider {
    /// Gets a peripheral.
    ///
    /// Return the requested peripheral or `nil` if the drone doesn't have the requested peripheral, or if the
    ///  peripheral is not available in the current connection state.
    ///
    /// - Parameter desc: requested peripheral. See `Peripherals` api for available descriptors instances.
    /// - Returns: requested peripheral
    func getPeripheral<Desc: PeripheralClassDesc>(_ desc: Desc) -> Desc.ApiProtocol?

    /// Gets a peripheral and registers an observer notified each time it changes.
    ///
    /// If the peripheral is present, the observer will be called immediately with. If the peripheral is not present,
    /// the observer won't be called until the peripheral is added to the drone.
    /// If the peripheral or the drone are removed, the observer will be notified and referenced value is set to `nil`.
    ///
    /// - Parameters:
    ///    - desc: requested peripheral. See `Peripherals` api for available descriptors instances.
    ///    - observer: observer to notify when the peripheral changes
    /// - Returns: reference to the requested peripheral
    func getPeripheral<Desc: PeripheralClassDesc>(_ desc: Desc,
                       observer: @escaping Ref<Desc.ApiProtocol>.Observer) -> Ref<Desc.ApiProtocol>
}

/// Protocol that provides functions to get peripherals.
/// Those methods should no be used from swift.
@objc
public protocol GSPeripheralProvider {
    /// Gets a peripheral.
    ///
    /// - Parameter desc: requested peripheral. See `Peripherals` api for available descriptors instances.
    /// - Returns: requested peripheral
    /// - Note: This method is for Objective-C only. Swift must use `func getPeripheral:`.
    @objc(getPeripheral:)
    func getPeripheral(desc: ComponentDescriptor) -> Peripheral?

    /// Gets a peripheral and registers an observer notified each time it changes
    ///
    /// - Parameters:
    ///    - desc: requested peripheral. See `Peripherals` api for available descriptors instances.
    ///    - observer: observer to notify when the peripheral changes
    /// - Returns: reference to the requested peripheral
    /// - Note: This method is for Objective-C only. Swift must use `func getPeripheral:desc:observer`.
    @objc(getPeripheral:observer:)
    func getPeripheralRef(desc: ComponentDescriptor, observer: @escaping (Peripheral?) -> Void) -> GSPeripheralRef
}
