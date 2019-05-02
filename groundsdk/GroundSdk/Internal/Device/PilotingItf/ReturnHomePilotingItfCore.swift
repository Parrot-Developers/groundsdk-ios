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
import CoreLocation

/// Internal return home preferred target implementation
class ReturnHomePreferredTargetCore: NSObject, ReturnHomePreferredTarget {
    /// Delegate called when the setting value is changed by setting `value` property
    private unowned let didChangeDelegate: SettingChangeDelegate

    /// Timeout object.
    ///
    /// Visibility is internal for testing purposes
    let timeout = SettingTimeout()

    /// Tells if the setting value has been changed and is waiting for change confirmation
    var updating: Bool { return timeout.isScheduled }

    /// Preferred target
    var target: ReturnHomeTarget {
        get {
            return _target
        }

        set {
            if _target != newValue {
                if backend(newValue) {
                    let oldValue = _target
                    // value sent to the backend, update setting value and mark it updating
                    _target = newValue
                    timeout.schedule { [weak self] in
                        if let `self` = self, self.update(target: oldValue) {
                            self.didChangeDelegate.userDidChangeSetting()
                        }
                    }
                    didChangeDelegate.userDidChangeSetting()
                }
            }
        }
    }

    /// Preferred target value
    private var _target: ReturnHomeTarget = .trackedTargetPosition
    /// Closure to call to change the value.
    /// Return `true` if the new value has been sent and setting must become updating.
    private let backend: ((ReturnHomeTarget) -> Bool)

    /// Constructor
    ///
    /// - Parameters:
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting `value` property
    ///   - backend: closure to call to change the setting value
    init(didChangeDelegate: SettingChangeDelegate, backend: @escaping (ReturnHomeTarget) -> Bool) {
        self.didChangeDelegate = didChangeDelegate
        self.backend = backend
    }

    /// Called by the backend, change the setting data
    ///
    /// - Parameter target: new preferred target
    /// - Returns: `true` if the setting has been changed, `false` otherwise
    func update(target newTarget: ReturnHomeTarget) -> Bool {
        if updating || _target != newTarget {
            _target = newTarget
            timeout.cancel()
            return true
        }
        return false
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

    /// Debug description.
    override var description: String {
        return "\(_target) [\(updating)]"
    }
}

/// ReturnHomePilotingItf backend protocol
public protocol ReturnHomePilotingItfBackend: ActivablePilotingItfBackend {
    /// Activate this piloting interface
    ///
    /// - Returns: `false` if it can't be activated
    func activate() -> Bool
    /// Cancels any current auto trigger.
    func cancelAutoTrigger()
    /// Change the preferred return home target.
    func set(preferredTarget: ReturnHomeTarget) -> Bool
    /// Change minimum altitude
    func set(minAltitude: Double) -> Bool
    /// Change the auto start after disconnect value
    func set(autoStartOnDisconnectDelay: Int) -> Bool
}

/// Internal return home piloting interface implementation
public class ReturnHomePilotingItfCore: ActivablePilotingItfCore, ReturnHomePilotingItf {

    /// Current home location, nil if unknown.
    public var homeLocation: CLLocation? {
        if let homeLocationtimeStamp = _homeLocationtimeStamp {
            return CLLocation(coordinate: CLLocationCoordinate2D(latitude: _latitude, longitude: _longitude),
                              altitude: _altitude, horizontalAccuracy: -1, verticalAccuracy: -1,
                              timestamp: homeLocationtimeStamp)
        }
        return nil
    }

    /// Reason why the return home is active.
    internal(set) public var reason = ReturnHomeReason.none

    /// Gives an estimate of the possibility for the drone to reach its return point.
    public private(set) var homeReachability = HomeReachability.unknown

    /// Delay before the drone starts a return home when `homeReachability` is `.warning`.
    public private(set) var autoTriggerDelay: TimeInterval = 0

    /// of the selected target are not met.
    /// May be nil if return home is not available, for example because the drone doesn't have a gps fix.
    public var currentTarget: ReturnHomeTarget {
        return _currentTarget
    }

    /// If the first fix was made after take off, the drone will return at this first fix position that
    /// may be different from the takeoff position
    public var gpsWasFixedOnTakeOff: Bool {
        return _gpsWasFixedOnTakeOff
    }

    /// current pilot position (as provided by .....
    public var preferredTarget: ReturnHomePreferredTarget {
        return _preferredTarget
    }

    /// Minimum return home altitude
    public var minAltitude: DoubleSetting? {
        return _minAltitude
    }

    /// Delay before starting return home when the controller connection is lost, in seconds
    public var autoStartOnDisconnectDelay: IntSetting {
        return _autoStartOnDisconnectDelay
    }

    /// return home location latitude
    private var _latitude = 0.0
    /// return home location longitude
    private var _longitude = 0.0
    /// return home location altitude
    private var _altitude = 0.0
    /// Timestamp of the latest return home location update, nil if location has never been updated
    private var _homeLocationtimeStamp: Date?
    /// Current return home target
    private var _currentTarget = ReturnHomeTarget.takeOffPosition
    /// If current target is TakeOffPosition, indicate that the first gps fix was made at or after takeoff.
    private var _gpsWasFixedOnTakeOff = false
    /// Preferred target
    private var _preferredTarget: ReturnHomePreferredTargetCore!
    /// Minimum return home altitude
    private var _minAltitude: DoubleSettingCore?
    /// Delay before starting return home when the controller connection is lost, in seconds
    private var _autoStartOnDisconnectDelay: IntSettingCore!
    /// return super class backend as ReturnHomePilotingItfBackend
    private var returnHomeBackend: ReturnHomePilotingItfBackend {
        return backend as! ReturnHomePilotingItfBackend
    }

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: store where this interface will be stored
    ///    - backend: ReturnHomePilotingItf backend
    public init(store: ComponentStoreCore, backend: ReturnHomePilotingItfBackend) {
        super.init(desc: PilotingItfs.returnHome, store: store, backend: backend)
        createSettings()
    }

    override func reset() {
        super.reset()
        // recreate non optional settings
        createSettings()
    }

    /// Activate this piloting interface
    ///
    /// - Returns: false if it can't be activated
    public func activate() -> Bool {
        if state == .idle {
            return returnHomeBackend.activate()
        }
        return false
    }

    public func cancelAutoTrigger() {
        if homeReachability == .warning {
            returnHomeBackend.cancelAutoTrigger()
        }
    }

    /// Create all non optional settings
    private func createSettings() {
        _preferredTarget = ReturnHomePreferredTargetCore(didChangeDelegate: self) { [unowned self] newTarget in
            return self.returnHomeBackend.set(preferredTarget: newTarget)
        }
        _autoStartOnDisconnectDelay = IntSettingCore(didChangeDelegate: self) { [unowned self] newValue in
            return self.returnHomeBackend.set(autoStartOnDisconnectDelay: newValue)
        }
    }
}

/// Backend callback methods
extension ReturnHomePilotingItfCore {
    /// Changes current active reason.
    ///
    /// - Parameter reason: new reason
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(reason newReason: ReturnHomeReason) -> ReturnHomePilotingItfCore {
            if reason != newReason {
                reason = newReason
                markChanged()
            }
            return self
    }

    /// Changes current return home location.
    ///
    /// - Parameter homeLocation: new home location
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(
        homeLocation newHome: (latitude: Double, longitude: Double, altitude: Double)?) -> ReturnHomePilotingItfCore {
            if let newHome = newHome {
                var changed = false
                if _latitude != newHome.latitude {
                    _latitude = newHome.latitude
                    changed = true
                }
                if _longitude != newHome.longitude {
                    _longitude = newHome.longitude
                    changed = true
                }
                if _altitude != newHome.altitude {
                    _altitude = newHome.altitude
                    changed = true
                }
                if _homeLocationtimeStamp == nil || changed {
                    _homeLocationtimeStamp = Date()
                    changed = true
                }
                if changed {
                    markChanged()
                }
            } else if _homeLocationtimeStamp != nil {
                // clear current location
                _homeLocationtimeStamp = nil
                _latitude = 0
                _longitude = 0
                _altitude = 0
                markChanged()
            }
            return self
    }

    /// Changes current return target.
    ///
    /// - Parameters:
    ///    - currentTarget: new home current target
    ///    - gpsFixedOnTakeOff: if currentTarget is take off position, `true` if gps was fix at takeoff time
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(currentTarget newTarget: ReturnHomeTarget, gpsFixedOnTakeOff: Bool)
        -> ReturnHomePilotingItfCore {
            if _currentTarget != newTarget {
                _currentTarget = newTarget
                markChanged()
            }
            if _currentTarget == .takeOffPosition {
                if _gpsWasFixedOnTakeOff != gpsFixedOnTakeOff {
                    _gpsWasFixedOnTakeOff = gpsFixedOnTakeOff
                    markChanged()
                }
            } else {
                _gpsWasFixedOnTakeOff = true
            }
            return self
    }

    /// Changes preferred return home target.
    ///
    /// - Parameter preferredTarget: new preferred return home target
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(preferredTarget newTarget: ReturnHomeTarget)
        -> ReturnHomePilotingItfCore {
            if _preferredTarget.update(target: newTarget) {
                markChanged()
            }
            return self
    }

    /// Changes minimum return home altitude.
    ///
    /// - Parameter newMinAltitude: new minimum return home altitude
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(minAltitude newMinAltitude: (min: Double?, value: Double?, max: Double?))
        -> ReturnHomePilotingItfCore {
        if _minAltitude == nil {
            _minAltitude = DoubleSettingCore(didChangeDelegate: self) { [unowned self] newValue in
                return self.returnHomeBackend.set(minAltitude: newValue)
            }
        }
        if _minAltitude!.update(min: newMinAltitude.min, value: newMinAltitude.value, max: newMinAltitude.max) {
            markChanged()
        }
        return self
    }

    /// Changes delay to start return home after disconnection.
    ///
    /// - Parameter autoStartOnDisconnectDelay: new delay settings
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(autoStartOnDisconnectDelay newSetting: (min: Int?, value: Int?, max: Int?))
        -> ReturnHomePilotingItfCore {
            if _autoStartOnDisconnectDelay.update(min: newSetting.min, value: newSetting.value,
                                                  max: newSetting.max) {
                markChanged()
            }
            return self
    }

    /// Changes the homeReachability.
    ///
    /// - Parameter homeReachability: new homeReachability value
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(homeReachability newHomeReachability: HomeReachability)
        -> ReturnHomePilotingItfCore {
            if homeReachability != newHomeReachability {
                homeReachability = newHomeReachability
                markChanged()
            }
            return self
    }

    /// Changes the autoTriggerDelay.
    ///
    /// - Parameter autoTriggerDelay: new autoTriggerDelay
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(autoTriggerDelay newAutoTriggerDelay: TimeInterval?)
        -> ReturnHomePilotingItfCore {
            let newAutoTriggerDelay = newAutoTriggerDelay ?? 0
            if autoTriggerDelay != newAutoTriggerDelay {
                autoTriggerDelay = newAutoTriggerDelay
                markChanged()
            }
            return self
    }

    /// Cancels all pending settings rollbacks.
    ///
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func cancelSettingsRollback() -> ReturnHomePilotingItfCore {
        _preferredTarget.cancelRollback { markChanged() }
        _autoStartOnDisconnectDelay.cancelRollback { markChanged() }
        _minAltitude?.cancelRollback { markChanged() }
        return self
    }
}
