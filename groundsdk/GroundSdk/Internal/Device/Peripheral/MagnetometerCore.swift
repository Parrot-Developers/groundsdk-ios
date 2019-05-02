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

/// Magnetometer backend part.
public protocol MagnetometerBackend: class {
    /// Asks to the drone to start the calibration process.
    func startCalibrationProcess()

    /// Asks to the drone to cancel the current calibration process.
    func cancelCalibrationProcess()
}

/// Internal magnetometer base peripheral implementation
public class MagnetometerCore: PeripheralCore, Magnetometer {

    /// Whether the magnetometer is calibrated or not.
    private(set) public var calibrated = false

    /// implementation backend
    private unowned let backend: MagnetometerBackend

    /// Constructor
    ///
    /// - Parameters:
    ///   - store: store where this peripheral will be stored
    ///   - backend: magnetometer calibration backend
    public init(store: ComponentStoreCore, backend: MagnetometerBackend) {
        self.backend = backend
        super.init(desc: Peripherals.magnetometer, store: store)
    }

    /// Constructor for subclasses
    ///
    /// - Parameters:
    ///   - desc: piloting interface component descriptor
    ///   - store: store where this peripheral will be stored
    ///   - backend: magnetometer calibration backend
    init(desc: ComponentDescriptor, store: ComponentStoreCore, backend: MagnetometerBackend) {
        self.backend = backend
        super.init(desc: desc, store: store)
    }
}

/// Backend callback methods
extension MagnetometerCore {
    /// Changes the info about the calibration state of the magnetometer.
    ///
    /// - Parameter calibrated: whether or not the drone is calibrated
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(calibrated newValue: Bool) -> MagnetometerCore {
        if calibrated != newValue {
            markChanged()
            calibrated = newValue
        }
        return self
    }
}
