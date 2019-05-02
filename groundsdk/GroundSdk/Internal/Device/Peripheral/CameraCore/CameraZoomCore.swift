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

/// Camera zoom backend.
protocol CameraZoomBackend: class {

    /// Sets the max zoom speed
    ///
    /// - Parameter maxSpeed: the new max zoom speed
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(maxZoomSpeed: Double) -> Bool
    /// Sets the quality degradation allowance during zoom change with velocity.
    ///
    /// - Parameter qualityDegradationAllowance: the new allowance
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(qualityDegradationAllowance: Bool) -> Bool

    /// Control the zoom.
    ///
    /// Unit of the `target` depends on the value of the `mode` parameter:
    ///    - `.level`: target is in zoom level.1 means no zoom.
    ///                This value will be clamped to the `maxLossyLevel` if it is greater than this value.
    ///    - `.velocity`: value is in signed ratio (from -1 to 1) of `maxVelocity` setting value.
    ///                   Negative values will produce a zoom out, positive value will zoom in.
    ///
    /// - Parameters:
    ///   - mode: the mode that should be used to control the zoom.
    ///   - target: Either level or velocity zoom target, clamped in the correct range
    func control(mode: CameraZoomControlMode, target: Double)
}

/// Camera zoom core implementation.
class CameraZoomCore: CameraZoom {
    /// Backend of this object
    private unowned let backend: CameraZoomBackend

    public var maxSpeed: DoubleSetting {
        return _maxSpeed
    }
    private var _maxSpeed: DoubleSettingCore!

    public var velocityQualityDegradationAllowance: BoolSetting {
        return _velocityQualityDegradationAllowance
    }
    private var _velocityQualityDegradationAllowance: BoolSettingCore!

    public private(set) var isAvailable = false
    public private(set) var currentLevel = 1.0
    public private(set) var maxLossyLevel = 1.0
    public private(set) var maxLossLessLevel = 1.0

    /// Range of the level.
    /// Express that the level can go from 1.0 to `maxLossyLevel`
    private var levelRange: ClosedRange<Double> {
        return 1.0...maxLossyLevel
    }

    /// Constructor
    ///
    /// - Parameters:
    ///   - backend: the backend (unowned)
    ///   - settingDidChangeDelegate: the delegate that should be called when a setting value changes
    init(backend: CameraZoomBackend, settingDidChangeDelegate: SettingChangeDelegate) {
        self.backend = backend

        _maxSpeed = DoubleSettingCore(didChangeDelegate: settingDidChangeDelegate) { [unowned self] maxZoomSpeed in
                return self.backend.set(maxZoomSpeed: maxZoomSpeed)
        }

        _velocityQualityDegradationAllowance =
            BoolSettingCore(didChangeDelegate: settingDidChangeDelegate) { [unowned self] allowed in
                return self.backend.set(qualityDegradationAllowance: allowed)
        }
    }

    func control(mode: CameraZoomControlMode, target: Double) {
        let clampedTarget: Double
        switch mode {
        case .level:
            clampedTarget = levelRange.clamp(target)
        case .velocity:
            clampedTarget = signedPercentIntervalDouble.clamp(target)
        }
        backend.control(mode: mode, target: clampedTarget)
    }
}

// MARK: - Backend
/// Backend callback methods
extension CameraZoomCore {
    /// Changes zoom availability
    ///
    /// - Parameter isAvailable: new availability
    /// - Returns: true if value has been changed
    func update(isAvailable newValue: Bool) -> Bool {
        if isAvailable != newValue {
            isAvailable = newValue
            return true
        }
        return false
    }

    /// Changes zoom level
    ///
    /// - Parameter currentLevel: new zoom level
    /// - Returns: true if value has been changed
    public func update(currentLevel newValue: Double) -> Bool {
        if currentLevel != newValue {
            currentLevel = newValue
            return true
        }
        return false
    }

    /// Changes max lossy (i.e. with quality degradation) zoom level
    ///
    /// - Parameter maxLossyLevel: new max lossy zoom level
    /// - Returns: true if value has been changed
    public func update(maxLossyLevel newValue: Double) -> Bool {
        if maxLossyLevel != newValue {
            maxLossyLevel = newValue
            return true
        }
        return false
    }

    /// Changes max loss less (i.e. without quality degradation) zoom level
    ///
    /// - Parameter maxLossLessLevel: new max loss less zoom level
    /// - Returns: true if value has been changed
    public func update(maxLossLessLevel newValue: Double) -> Bool {
        if maxLossLessLevel != newValue {
            maxLossLessLevel = newValue
            return true
        }
        return false
    }

    /// Changes quality degradation allowance during zoom change with velocity
    ///
    /// - Parameter qualityDegradationAllowed: new allowance
    /// - Returns: true if value has been changed
    public func update(qualityDegradationAllowed newValue: Bool) -> Bool {
        return _velocityQualityDegradationAllowance.update(value: newValue)
    }

    /// Changes max speed setting
    ///
    /// - Parameters:
    ///   - maxSpeedLowerBound: new max lower bound, nil if bound does not change
    ///   - maxSpeed: new setting value, nil if it does not change
    ///   - maxSpeedUpperBound: new max upper bound, nil if bound does not change
    /// - Returns: true if value has been changed
    public func update(
        maxSpeedLowerBound: Double?, maxSpeed: Double?, maxSpeedUpperBound: Double?) -> Bool {
        return _maxSpeed.update(min: maxSpeedLowerBound, value: maxSpeed, max: maxSpeedUpperBound)
    }

    /// Cancels any pending setting rollback.
    ///
    /// - Parameter completionClosure: block that will be called if a rollback was pending
    func cancelSettingsRollback(completionClosure: () -> Void) {
        _maxSpeed.cancelRollback(completionClosure: completionClosure)
        _velocityQualityDegradationAllowance.cancelRollback(completionClosure: completionClosure)
    }

    /// Resets values to defaults.
    ///
    /// - Note: this function does not reset the settings
    func resetValues() {
        isAvailable = false
        currentLevel = 1.0
        maxLossyLevel = 1.0
        maxLossLessLevel = 1.0
    }
}
