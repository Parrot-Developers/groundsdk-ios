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

/// Camera alignment backend.
protocol CameraAlignmentBackend: class {

    /// Sets alignment offsets.
    ///
    /// - Parameter yawOffset: the new offset to apply to the yaw axis
    /// - Parameter pitchOffset: the new offset to apply to the pitch axis
    /// - Parameter rollOffset: the new offset to apply to the roll axis
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(yawOffset: Double, pitchOffset: Double, rollOffset: Double) -> Bool

    /// Factory reset camera alignment.
    ///
    /// - Returns: true if the command has been sent, false otherwise
    func resetAlignment() -> Bool
}

/// Camera Alignment core implementation.
class CameraAlignmentCore: CameraAlignment {

    /// Backend of this object.
    private unowned let backend: CameraAlignmentBackend

    /// Delegate called when the setting value is changed by setting properties
    private unowned let didChangeDelegate: SettingChangeDelegate

    /// Timeout object.
    ///
    /// Visibility is internal for testing purposes
    let timeout = SettingTimeout()

    /// Tells if the setting value has been changed and is waiting for change confirmation
    var updating: Bool { return timeout.isScheduled }

    public var supportedYawRange: ClosedRange<Double> = 0.0...0.0

    public var supportedPitchRange: ClosedRange<Double> = 0.0...0.0

    public var supportedRollRange: ClosedRange<Double> = 0.0...0.0

    /// Alignment offset applied to the yaw axis, in degrees.
    public var yaw: Double {
        get {
            return _yaw
        }

        set {
            let clampValue = supportedYawRange.clamp(newValue)
            if yaw != clampValue &&
                backend.set(yawOffset: clampValue, pitchOffset: pitch, rollOffset: roll) {

                let oldYaw = _yaw
                // value sent to the backend, update setting value and mark it updating
                _yaw = clampValue
                timeout.schedule { [weak self] in
                    if let `self` = self, self.update(yawLowerBound: self.supportedYawRange.lowerBound,
                                                      yaw: oldYaw, yawUpperBound: self.supportedYawRange.upperBound) {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
                didChangeDelegate.userDidChangeSetting()
            }
        }
    }
    /// Internal alignment offset applied to the yaw axis, in degrees.
    private var _yaw = 0.0

    /// Alignment offset applied to the pitch axis, in degrees.
    public var pitch: Double {
        get {
            return _pitch
        }

        set {
            let clampValue = supportedPitchRange.clamp(newValue)
            if pitch != clampValue &&
                backend.set(yawOffset: yaw, pitchOffset: clampValue, rollOffset: roll) {

                let oldPitch = _pitch
                // value sent to the backend, update setting value and mark it updating
                _pitch = clampValue
                timeout.schedule { [weak self] in
                    if let `self` = self, self.update(pitchLowerBound: self.supportedPitchRange.lowerBound,
                                                      pitch: oldPitch,
                                                      pitchUpperBound: self.supportedPitchRange.upperBound) {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
                didChangeDelegate.userDidChangeSetting()
            }
        }
    }
    /// Internal alignment offset applied to the pitch axis, in degrees.
    private var _pitch = 0.0

    /// Alignment offset applied to the roll axis, in degrees.
    public var roll: Double {
        get {
            return _roll
        }

        set {
            let clampValue = supportedRollRange.clamp(newValue)
            if roll != clampValue &&
                backend.set(yawOffset: yaw, pitchOffset: pitch, rollOffset: clampValue) {

                let oldRoll = _roll
                // value sent to the backend, update setting value and mark it updating
                _roll = clampValue
                timeout.schedule { [weak self] in
                    if let `self` = self, self.update(rollLowerBound: self.supportedRollRange.lowerBound,
                                                      roll: oldRoll,
                                                      rollUpperBound: self.supportedRollRange.upperBound) {
                        self.didChangeDelegate.userDidChangeSetting()
                    }
                }
                didChangeDelegate.userDidChangeSetting()
            }
        }
    }
    /// Internal alignment offset applied to the roll axis, in degrees.
    private var _roll = 0.0

    /// Constructor
    ///
    /// - Parameters:
    ///   - backend: the backend (unowned)
    ///   - didChangeDelegate: the delegate that should be called when a setting value changes
    init(backend: CameraAlignmentBackend, didChangeDelegate: SettingChangeDelegate) {
        self.backend = backend
        self.didChangeDelegate = didChangeDelegate
    }

    func reset() -> Bool {
        return backend.resetAlignment()
    }

    /// Cancels any pending rollback.
    ///
    /// - Parameter completionClosure: block that will be called if a rollback was pending
    func cancelRollback(completionClosure: () -> Void) {
        if timeout.isScheduled {
            timeout.cancel()
            completionClosure()
        }
    }
}

// MARK: - Backend
/// Backend callback methods
extension CameraAlignmentCore {
    /// Changes alignment offset applied to the yaw axis setting.
    ///
    /// - Parameters:
    ///   - yawLowerBound: new yaw offset lower bound
    ///   - yaw: new yaw offset value
    ///   - yawUpperBound: new yaw offset upper bound
    /// - Returns: `true` if value has been changed
    public func update(yawLowerBound: Double, yaw: Double, yawUpperBound: Double) -> Bool {
        var changed = false

        if supportedYawRange.lowerBound != yawLowerBound || supportedYawRange.upperBound != yawUpperBound {
            supportedYawRange = yawLowerBound...yawUpperBound
            changed = true
        }

        if updating || _yaw != yaw {
            _yaw = supportedYawRange.clamp(yaw)
            changed = true
            timeout.cancel()
        }
        return changed
    }

    /// Changes alignment offset applied to the pitch axis setting.
    ///
    /// - Parameters:
    ///   - pitchLowerBound: new pitch offset lower bound
    ///   - pitch: new pitch offset value
    ///   - pitchUpperBound: new pitch offset upper bound
    /// - Returns: `true` if value has been changed
    public func update(pitchLowerBound: Double, pitch: Double, pitchUpperBound: Double) -> Bool {
        var changed = false

        if supportedPitchRange.lowerBound != pitchLowerBound || supportedPitchRange.upperBound != pitchUpperBound {
            supportedPitchRange = pitchLowerBound...pitchUpperBound
            changed = true
        }

        if updating || _pitch != pitch {
            _pitch = supportedPitchRange.clamp(pitch)
            changed = true
            timeout.cancel()
        }
        return changed
    }

    /// Changes alignment offset applied to the roll axis setting.
    ///
    /// - Parameters:
    ///   - rollLowerBound: new roll offset lower bound
    ///   - roll: new pitch offset value
    ///   - rollUpperBound: new roll offset upper bound
    /// - Returns: `true` if value has been changed
    public func update(rollLowerBound: Double, roll: Double, rollUpperBound: Double) -> Bool {
        var changed = false

        if supportedRollRange.lowerBound != rollLowerBound || supportedRollRange.upperBound != rollUpperBound {
            supportedRollRange = rollLowerBound...rollUpperBound
            changed = true
        }

        if updating || _roll != roll {
            _roll = supportedRollRange.clamp(roll)
            changed = true
            timeout.cancel()
        }
        return changed
    }
}

// MARK: - objc compatibility
extension CameraAlignmentCore: GSCameraAlignment {
    var gsMinSupportedYawRange: Double {
        return supportedYawRange.lowerBound
    }

    var gsMaxSupportedYawRange: Double {
        return supportedYawRange.upperBound
    }

    var gsMinSupportedPitchRange: Double {
        return supportedPitchRange.lowerBound
    }

    var gsMaxSupportedPitchRange: Double {
        return supportedPitchRange.upperBound
    }

    var gsMinSupportedRollRange: Double {
        return supportedRollRange.lowerBound
    }

    var gsMaxSupportedRollRange: Double {
        return supportedRollRange.upperBound
    }
}
