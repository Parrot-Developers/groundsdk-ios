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

/// Internal camera exposure values implementation
public class CameraExposureValuesCore: InstrumentCore, CameraExposureValues {

    private(set) public var shutterSpeed = CameraShutterSpeed.oneOver10000

    private(set) public var isoSensitivity = CameraIso.iso50

    /// Debug description
    public override var description: String {
        return "Expo values: shutterSpeed = \(shutterSpeed), isoSensitivity = \(isoSensitivity)"
    }

    /// Constructor
    ///
    /// - Parameter store: component store owning this component
    public init(store: ComponentStoreCore) {
        super.init(desc: Instruments.cameraExposureValues, store: store)
    }
}

/// Backend callback methods
extension CameraExposureValuesCore {

    /// Updates the shutter speed value.
    ///
    /// - Parameter shutterSpeed: the new shutter speed to set
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(shutterSpeed newValue: CameraShutterSpeed) -> CameraExposureValuesCore {
        if shutterSpeed != newValue {
            markChanged()
            shutterSpeed = newValue
        }
        return self
    }

    /// Updates the iso sensitivity value.
    ///
    /// - Parameter isoSensitivity: the new iso sensitivity to set
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(isoSensitivity newValue: CameraIso) -> CameraExposureValuesCore {
        if isoSensitivity != newValue {
            markChanged()
            isoSensitivity = newValue
        }
        return self
    }
}
