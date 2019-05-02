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

/// Beeper backend part.
public protocol BeeperBackend: class {
    /// Commands the device to play alert sound.
    ///
    /// The alert sound shall be stopped with `stopAlertSound`.
    func startAlertSound() -> Bool

    /// Commands the device to stop playing the alert sound.
    ///
    /// - Returns: `true` if the stop alert sound operation could be initiated, `false` otherwise
    func stopAlertSound() -> Bool
}

/// Internal Beeper peripheral implementation
public class BeeperCore: PeripheralCore, Beeper {

    /// Whther the device is currently playing an alert sound.
    private (set) public var alertSoundPlaying = false

    /// Implementation backend
    private unowned let backend: BeeperBackend

    /// Debug description
    public override var description: String {
        return "Beeper: alertSoundPlaying = \(alertSoundPlaying)"
    }

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: store where this peripheral will be stored
    ///    - backend: Beeper backend
    public init(store: ComponentStoreCore, backend: BeeperBackend) {
        self.backend = backend
        super.init(desc: Peripherals.beeper, store: store)
    }

    /// Commands the device to play alert sound.
    public func startAlertSound() -> Bool {
        guard !alertSoundPlaying else {
            return false
        }
        return backend.startAlertSound()
    }

    /// Commands the device to stop playing the alert sound.
    public func stopAlertSound() -> Bool {
        guard alertSoundPlaying else {
            return false
        }
        return backend.stopAlertSound()
    }
}

/// Backend callback methods
extension BeeperCore {

    /// Set the Playing alert status
    ///
    /// - Parameter alertSoundPlaying: tells if the device is currently playing an alert sound.
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(alertSoundPlaying newValue: Bool) -> BeeperCore {
        if newValue != alertSoundPlaying {
            alertSoundPlaying = newValue
            markChanged()
        }
        return self
    }
}
