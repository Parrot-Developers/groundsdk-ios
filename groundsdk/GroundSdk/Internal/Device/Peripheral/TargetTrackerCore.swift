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

/// TargetTracker backend part.
public protocol TargetTrackerBackend: class {

    /// Set the position of the desired target in frame
    ///
    /// - Parameter framing: tuple (horizontal, vertical) - `horizontal` is a relative position, from left (0.0)
    /// to right (1.0)). `vertical` is a relative position, from bottom (0.0) to top (1.0)
    /// - Returns: true if the command was sent, false otherwise
    func set(framing: (horizontal: Double, vertical: Double)) -> Bool

    /// Enables or disables the used of the controller as target.
    ///
    /// - Parameter targetIsController: true / false if the controller tracking is enabled or not
    func set(targetIsController: Bool)

    /// Forward the result of the target analysis
    ///
    /// - Parameter targetDetectionInfo: TargetDetectionInfo object
    func set(targetDetectionInfo: TargetDetectionInfo)
}

/// Internal implementation of TargetTrajectory
public class TargetTrajectoryCore: TargetTrajectory, Equatable {

    public let latitude: Double
    public let longitude: Double
    public let altitude: Double
    public let northSpeed: Double
    public let eastSpeed: Double
    public let downSpeed: Double

    /// Constructor
    public init(latitude: Double, longitude: Double, altitude: Double, northSpeed: Double, eastSpeed: Double,
                downSpeed: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.northSpeed = northSpeed
        self.eastSpeed = eastSpeed
        self.downSpeed = downSpeed
    }

    /// Debug description.
    public var description: String {
        return "Trajectory / lat: \(latitude), long: \(longitude), alt: \(altitude)" +
        ", NSpeed: \(northSpeed), ESpeed: \(eastSpeed), DSpeed: \(downSpeed)"
    }
    // Equatable Concordance
    public static func == (lhs: TargetTrajectoryCore, rhs: TargetTrajectoryCore) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude && lhs.altitude == rhs.altitude &&
            lhs.northSpeed == rhs.northSpeed && lhs.eastSpeed == rhs.eastSpeed && lhs.downSpeed == rhs.downSpeed
    }
}

/// Internal TargetFramingSetting implementation
class TargetFramingSettingCore: TargetFramingSetting, CustomStringConvertible {
    /// Delegate called when the setting value is changed by setting `value` property
    private unowned let didChangeDelegate: SettingChangeDelegate

    /// Timeout object.
    ///
    /// Visibility is internal for testing purposes
    let timeout = SettingTimeout()

    /// Tells if the setting value has been changed and is waiting for change confirmation
    var updating: Bool { return timeout.isScheduled }

    /// Setting current value
    public var value: (horizontal: Double, vertical: Double) {
        get {
            return _value
        }
        set {
            let clampedNewVal = (unsignedPercentIntervalDouble.clamp(newValue.horizontal),
                                 unsignedPercentIntervalDouble.clamp(newValue.vertical))
            if _value != clampedNewVal {
                if backend(clampedNewVal) {
                    let oldValue = _value
                    // value sent to the backend mark it updating
                    _value = clampedNewVal
                    timeout.schedule { [weak self] in
                        if let `self` = self, self.update(newValue: oldValue) {
                            self.didChangeDelegate.userDidChangeSetting()
                        }
                    }
                    didChangeDelegate.userDidChangeSetting()
                }
            }
        }
    }
    /// Internal value
    private var _value = (horizontal: 0.0, vertical: 0.0)

    /// Closure to call to change the value. Return true if the new value has been sent and setting must become updating
    private let backend: (((horizontal: Double, vertical: Double)) -> Bool)

    /// Debug description.
    public var description: String {
        return "\(value) [\(updating)]"
    }

    /// Constructor
    ///
    /// - Parameters:
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting `value` property
    ///   - backend: closure to call to change the setting value
    init(didChangeDelegate: SettingChangeDelegate,
         backend: @escaping ((horizontal: Double, vertical: Double)) -> Bool) {
        self.didChangeDelegate = didChangeDelegate
        self.backend = backend
    }

    /// Called by the backend, change the setting data
    ///
    /// - Parameters:
    ///   - min: if not nil the new min value
    ///   - value: if not nil the new current value
    ///   - max: if not nil the new max value
    /// - Returns: true if the setting has been changed, false else
    func update(newValue: (horizontal: Double, vertical: Double)) -> Bool {
        var changed = false

        if updating || _value != newValue {
            _value = newValue
            timeout.cancel()
            changed = true
        }
        return changed
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

/// Internal PositionInFrameSetting implementation for objectiveC
extension TargetFramingSettingCore: GSTargetFramingSetting {
    public var horizontalPosition: Double {
        return value.horizontal
    }
    public var verticalPosition: Double {
        return value.vertical
    }
    public func setValue(horizontal: Double, vertical: Double) {
        value = (horizontal, vertical)
    }
}

/// Internal targetTracker peripheral implementation
public class TargetTrackerCore: PeripheralCore, TargetTracker {

    public private(set) var targetIsController = false

    public var framing: TargetFramingSetting {
        return _framing
    }
    // internal value
    private var _framing: TargetFramingSettingCore!

    public var targetTrajectory: TargetTrajectory? { return _targetTrajectory }
    /// targetTrajectory internal implementation
    private var _targetTrajectory: TargetTrajectoryCore?

    /// implementation backend
    private unowned let targetTrackerBackend: TargetTrackerBackend

    /// Constructor
    ///
    /// - Parameters:
    ///   - store: store where this peripheral will be stored
    ///   - backend: targetTracker backend
    public init(store: ComponentStoreCore, backend: TargetTrackerBackend) {
        self.targetTrackerBackend = backend
        super.init(desc: Peripherals.targetTracker, store: store)
        _framing = TargetFramingSettingCore(
            didChangeDelegate: self, backend: { [unowned self] framing in
                return self.targetTrackerBackend.set(framing: framing)
        })
    }

    public func sendTargetDetectionInfo(_ info: TargetDetectionInfo) {
        targetTrackerBackend.set(targetDetectionInfo: info)
    }

    public func enableControllerTracking() {
        targetTrackerBackend.set(targetIsController: true)
    }

    public func disableControllerTracking() {
        targetTrackerBackend.set(targetIsController: false)
    }

}

/// Internal targetTracker implementation for objectiveC
extension TargetTrackerCore: GSTargetTracker {

    public var gsFraming: GSTargetFramingSetting {
        return _framing
    }
}

/// Backend callback methods
extension TargetTrackerCore {
    /// Updates the position in frame.
    ///
    /// - Parameter newValue: new position in frame
    /// - Returns: self to allow call chaining
    @discardableResult public func update(
        framing newValue: (horizontal: Double, vertical: Double)) -> TargetTrackerCore {
        if _framing.update(newValue: newValue) {
            markChanged()
        }
        return self
    }

    /// Updates the targetIsController
    ///
    /// - Parameter newValue: true or false is the controller is used as target
    /// - Returns: self to allow call chaining
    @discardableResult public func update(targetIsController newValue: Bool) -> TargetTrackerCore {
        if newValue != targetIsController {
            targetIsController = newValue
            markChanged()
        }
        return self
    }

    /// Update targetTrajectory
    ///
    /// - Parameter targetTrajectory: new targetTrajectory
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(targetTrajectory value: TargetTrajectoryCore?) -> TargetTrackerCore {
        if _targetTrajectory != value {
            _targetTrajectory = value
            markChanged()
        }
        return self
    }

    /// Cancels all pending settings rollbacks.
    ///
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func cancelSettingsRollback() -> TargetTrackerCore {
        _framing.cancelRollback { markChanged() }
        return self
    }
}
