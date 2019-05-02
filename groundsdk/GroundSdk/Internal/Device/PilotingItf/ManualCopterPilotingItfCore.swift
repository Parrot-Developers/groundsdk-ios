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

/// ManualCopterPilotingItf backend protocol
public protocol ManualCopterPilotingItfBackend: ActivablePilotingItfBackend {
    /// Activate this piloting interface
    /// - Returns: false if it can't be activated
    func activate() -> Bool
    /// set the piloting command roll value
    func set(roll: Int)
    /// set the piloting command pitch value
    func set(pitch: Int)
    /// set the piloting command yaw rotation speed value
    func set(yawRotationSpeed: Int)
    /// set the piloting command vertical speed value
    func set(verticalSpeed: Int)
    /// Asks the drone to hover.
    func hover()
    /// send takeoff request
    func takeOff()
    /// send thrown takeoff request
    func thrownTakeOff()
    /// send land request
    func land()
    /// send emergency request
    func emergencyCutOut()
    /// change the max pitch/roll
    func set(maxPitchRoll value: Double) -> Bool
    /// change the max pitch/roll velocity
    func set(maxPitchRollVelocity value: Double) -> Bool
    /// change the max vertical speed
    func set(maxVerticalSpeed value: Double) -> Bool
    /// change the max yaw rotation speed
    func set(maxYawRotationSpeed value: Double) -> Bool
    /// change banked turn mode
    func set(bankedTurnMode value: Bool) -> Bool
    /// change the smartThrownTakeOff mode
    func set(useThrownTakeOffForSmartTakeOff: Bool) -> Bool
}

/// Internal manual copter piloting interface implementation
public class ManualCopterPilotingItfCore: ActivablePilotingItfCore, ManualCopterPilotingItf {

    /// Max pitch roll
    public var maxPitchRoll: DoubleSetting {
        return _maxPitchRoll
    }
    /// Max pitch roll velocity
    public var maxPitchRollVelocity: DoubleSetting? {
        return _maxPitchRollVelocity
    }
    /// Max vertical speed
    public var maxVerticalSpeed: DoubleSetting {
        return _maxVerticalSpeed
    }
    /// Max yaw rotation speed
    public var maxYawRotationSpeed: DoubleSetting {
        return _maxYawRotationSpeed
    }
    /// banked-turn mode
    public var bankedTurnMode: BoolSetting? {
        return _bankedTurnMode
    }
    /// thrown take off settings
    public var thrownTakeOffSettings: BoolSetting? {
        return _thrownTakeOffSettings
    }

    /// Flag to indicate if Hand launch is ready for a thrown takeoff (drone is moving or steady
    /// if this flag is YES, a smartTakeOffLandAction will perform a thrownTakeOff Action
    /// if NO, a smartTakeOffLandAction will perform a takeOff Action
    private var smartWillThrownTakeoff = false

    /// which action will be performed if `smartTakeOffLand()` is called.
    public var smartTakeOffLandAction: SmartTakeOffLandAction {
        if canLand {
            // landing
            return  .land
        } else if canTakeOff {
            // takeOff
            if let thrownTakeOffSettings = thrownTakeOffSettings, thrownTakeOffSettings.value &&
                smartWillThrownTakeoff {
                return .thrownTakeOff
            } else {
                return .takeOff
            }
        } else {
            return .none
        }
    }

    /// Tells if the drone is ready to takeoff
    private (set) public var canTakeOff = false
    /// Tells if the drone is ready to land
    private (set) public var canLand = false

    /// max pitch roll internal value
    private var _maxPitchRoll: DoubleSettingCore!
    /// max pitch roll velocity internal value
    private var _maxPitchRollVelocity: DoubleSettingCore?
    /// max vertical speed internal value
    private var _maxVerticalSpeed: DoubleSettingCore!
    /// max yaw rotation speed internal value
    private var _maxYawRotationSpeed: DoubleSettingCore!
    /// banked-turn mode internal value
    private var _bankedTurnMode: BoolSettingCore?
    /// thrown take off settings value
    private var _thrownTakeOffSettings: BoolSettingCore?

    /// Super class backend as ManualCopterPilotingItfBackend
    private var manualCopterfBackend: ManualCopterPilotingItfBackend {
        return backend as! ManualCopterPilotingItfBackend
    }

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: store where this interface will be stored
    ///    - backend: ManualCopterPilotingItf backend
    public init(store: ComponentStoreCore, backend: ManualCopterPilotingItfBackend) {
        super.init(desc: PilotingItfs.manualCopter, store: store, backend: backend)
        createSettings()
    }

    /// Create non all optional settings
    private func createSettings() {
        _maxPitchRoll = DoubleSettingCore(didChangeDelegate: self) { [unowned self] newValue in
            return self.manualCopterfBackend.set(maxPitchRoll: newValue)
        }
        _maxVerticalSpeed = DoubleSettingCore(didChangeDelegate: self) { [unowned self] newValue in
            return self.manualCopterfBackend.set(maxVerticalSpeed: newValue)
        }
        _maxYawRotationSpeed = DoubleSettingCore(didChangeDelegate: self) { [unowned self] newValue in
            return self.manualCopterfBackend.set(maxYawRotationSpeed: newValue)
        }
    }

    // MARK: API methods

    /// Activate this piloting interface
    ///
    /// - Returns: false if it can't be activated
    public func activate() -> Bool {
        if state == .idle {
            return manualCopterfBackend.activate()
        }
        return false
    }

    public func set(pitch: Int) {
        manualCopterfBackend.set(pitch: signedPercentInterval.clamp(pitch))
    }

    public func set(roll: Int) {
        manualCopterfBackend.set(roll: signedPercentInterval.clamp(roll))
    }

    public func set(yawRotationSpeed: Int) {
        manualCopterfBackend.set(yawRotationSpeed: signedPercentInterval.clamp(yawRotationSpeed))
    }

    public func set(verticalSpeed: Int) {
        manualCopterfBackend.set(verticalSpeed: signedPercentInterval.clamp(verticalSpeed))
    }

    public func hover() {
        manualCopterfBackend.hover()
    }

    public func takeOff() {
        manualCopterfBackend.takeOff()
    }

    public func thrownTakeOff() {
        manualCopterfBackend.thrownTakeOff()
    }

    public func land() {
        manualCopterfBackend.land()
    }

    public func emergencyCutOut() {
        manualCopterfBackend.emergencyCutOut()
    }

    public func smartTakeOffLand() {
        switch  smartTakeOffLandAction {
        case .takeOff:
            takeOff()
        case .thrownTakeOff:
            thrownTakeOff()
        case .land:
            land()
        case .none:
            break
        }
    }

    override func reset() {
        super.reset()
        // clear local computed flags
        canTakeOff = false
        canLand = false
        smartWillThrownTakeoff = false
        // delete optional settings
        _maxPitchRollVelocity = nil
        _bankedTurnMode = nil
        _thrownTakeOffSettings = nil
        // recreate non optional settings
        createSettings()
    }
}

/// Backend callback methods
extension ManualCopterPilotingItfCore {

    /// Changes the flag that tells if the drone is ready to takeoff.
    ///
    /// - Parameter canTakeOff: true if the drone is ready to takeoff
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(canTakeOff value: Bool) -> ManualCopterPilotingItfCore {
        if canTakeOff != value {
            canTakeOff = value
            markChanged()
        }
        return self
    }

    /// Changes the flag that tells if the drone is ready to land.
    ///
    /// - Parameter canLand: true if the drone is ready to land
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(canLand value: Bool) -> ManualCopterPilotingItfCore {
        if canLand != value {
            canLand = value
            markChanged()
        }
        return self
    }

    /// Changes the flag that tells if the drone ready for a thrownTakeOff
    ///
    /// - Parameter smartWillThrownTakeoff: true or false
    ///   if true, a smartTakeOffLand() will perform a thrownTakeOff (if useSmartTakeOff is true too),
    ///   otherwise a smartTakeOffLand() will perform a classic takeOff
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(smartWillThrownTakeoff value: Bool) -> ManualCopterPilotingItfCore {
        if smartWillThrownTakeoff != value {
            smartWillThrownTakeoff = value
            markChanged()
        }
        return self
    }

    /// Changes maximum pitch roll settings
    ///
    /// - Parameter maxPitchRoll: tuple containing new values. Only not nil values are updated
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(maxPitchRoll newSetting: (min: Double?, value: Double?, max: Double?))
        -> ManualCopterPilotingItfCore {
            if _maxPitchRoll.update(min: newSetting.min, value: newSetting.value, max: newSetting.max) {
                markChanged()
            }
            return self
    }

    /// Changes maximum pitch roll velocity settings
    ///
    /// - Parameter maxPitchRollVelocity: tuple containing new values. Only not nil values are updated
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(maxPitchRollVelocity newSetting: (min: Double?, value: Double?, max: Double?))
        -> ManualCopterPilotingItfCore {
            if _maxPitchRollVelocity == nil {
                _maxPitchRollVelocity = DoubleSettingCore(didChangeDelegate: self) { [unowned self] newValue in
                    return self.manualCopterfBackend.set(maxPitchRollVelocity: newValue)
                }
            }
            if _maxPitchRollVelocity!.update(min: newSetting.min, value: newSetting.value, max: newSetting.max) {
                markChanged()
            }
            return self
    }

    /// Changes maximum vertical speed settings
    ///
    /// - Parameter maxVerticalSpeed: tuple containing new values. Only not nil values are updated
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(maxVerticalSpeed newSetting: (min: Double?, value: Double?, max: Double?))
        -> ManualCopterPilotingItfCore {
            if _maxVerticalSpeed.update(min: newSetting.min, value: newSetting.value, max: newSetting.max) {
                markChanged()
            }
            return self
    }

    /// Changes maximum yaw rotation speed settings
    ///
    /// - Parameter maxYawRotationSpeed: tuple containing new values. Only not nil values are updated
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(maxYawRotationSpeed newSetting: (min: Double?, value: Double?, max: Double?))
        -> ManualCopterPilotingItfCore {
            if _maxYawRotationSpeed!.update(min: newSetting.min, value: newSetting.value, max: newSetting.max) {
                markChanged()
            }
            return self
    }

    /// Changes banked turn mode setting
    ///
    /// - Parameter bankedTurnMode: new mode
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(bankedTurnMode newSetting: Bool) -> ManualCopterPilotingItfCore {
        if _bankedTurnMode == nil {
            _bankedTurnMode = BoolSettingCore(didChangeDelegate: self) { [unowned self] newValue in
                return self.manualCopterfBackend.set(bankedTurnMode: newValue)
            }
        }
        if _bankedTurnMode!.update(value: newSetting) {
            markChanged()
        }
        return self
    }

    /// Changes useThrownTakeOffForSmartTakeOff mode setting
    ///
    /// - Parameter useThrownTakeOffForSmartTakeOff: new mode
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(useThrownTakeOffForSmartTakeOff newSetting: Bool)
        -> ManualCopterPilotingItfCore {
            if _thrownTakeOffSettings == nil {
                _thrownTakeOffSettings = BoolSettingCore(didChangeDelegate: self) { [unowned self] newUse in
                    return self.manualCopterfBackend.set(useThrownTakeOffForSmartTakeOff: newUse)
                }
                // mark changed when _thrownTakeOffSettings is created
                markChanged()
            }
            if _thrownTakeOffSettings!.update(value: newSetting) {
                markChanged()
            }
            return self
    }

    /// Cancels all pending settings rollbacks.
    ///
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func cancelSettingsRollback() -> ManualCopterPilotingItfCore {
        _maxPitchRoll.cancelRollback { markChanged() }
        _maxPitchRollVelocity?.cancelRollback { markChanged() }
        _maxVerticalSpeed.cancelRollback { markChanged() }
        _maxYawRotationSpeed.cancelRollback { markChanged() }
        _bankedTurnMode?.cancelRollback { markChanged() }
        _thrownTakeOffSettings?.cancelRollback { markChanged() }
        return self
    }
}
