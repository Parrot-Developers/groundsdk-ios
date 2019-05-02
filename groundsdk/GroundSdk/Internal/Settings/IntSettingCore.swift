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

/// Represent an integer setting with a current value and a valide range
class IntSettingCore: NSObject, IntSetting {
    /// Delegate called when the setting value is changed by setting `value` property
    private unowned let didChangeDelegate: SettingChangeDelegate

    /// Timeout object.
    ///
    /// Visibility is internal for testing purposes
    let timeout = SettingTimeout()

    /// Tells if the setting value has been changed and is waiting for change confirmation
    var updating: Bool { return timeout.isScheduled }
    /// Setting minimum value
    var min: Int {
        return range.lowerBound
    }
    /// Setting maximum value
    var max: Int {
        return range.upperBound
    }
    /// Setting current value
    var value: Int {
        get {
            return _value
        }

        set {
            if _value != newValue {
                let val = range.clamp(newValue)
                if backend(val) {
                    let oldValue = _value
                    // value sent to the backend, update setting value and mark it updating
                    _value = val
                    timeout.schedule { [weak self] in
                        if let `self` = self, self.update(min: nil, value: oldValue, max: nil) {
                            self.didChangeDelegate.userDidChangeSetting()
                        }
                    }
                    didChangeDelegate.userDidChangeSetting()
                }
            }
        }
    }
    /// Internal value
    private var _value = 0
    /// Range
    private var range: ClosedRange<Int> = 0...0
    /// Closure to call to change the value.
    /// Return `true` if the new value has been sent and setting must become updating.
    private let backend: ((Int) -> Bool)

    /// Debug description.
    override var description: String {
        return "\(min) / \(value) / \(max) [\(updating)]"
    }

    /// Constructor
    ///
    /// - Parameters:
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting `value` property
    ///   - backend: closure to call to change the setting value
    init(didChangeDelegate: SettingChangeDelegate, backend: @escaping (Int) -> Bool) {
        self.didChangeDelegate = didChangeDelegate
        self.backend = backend
    }

    /// Called by the backend, change the setting data
    ///
    /// - Parameters:
    ///   - min: if not `nil` the new min value
    ///   - value: if not `nil` the new current value
    ///   - max: if not `nil` the new max value
    /// - Returns: `true` if the setting has been changed, `false` otherwise
    func update(min newMin: Int?, value newValue: Int?, max newMax: Int?) -> Bool {
        var changed = false

        if let newMin = newMin, let newMax = newMax {
            if range.lowerBound != newMin || range.upperBound != newMax {
                range = newMin...newMax
                changed = true
            }
        } else if let newMin = newMin {
            if range.lowerBound != newMin {
                range = newMin...range.upperBound
                changed = true
            }
        } else if let newMax = newMax {
            if range.upperBound != newMax {
                range = range.lowerBound...newMax
                changed = true
            }
        }

        if let newValue = newValue {
            if updating || _value != newValue {
                _value = range.clamp(newValue)
                changed = true
                timeout.cancel()
            }
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
