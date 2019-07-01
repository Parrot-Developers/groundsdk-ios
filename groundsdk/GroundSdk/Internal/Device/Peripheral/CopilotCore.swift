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

/// Copilot backend part.
public protocol CopilotBackend: class {
    /// Sets piloting source
    ///
    /// - Parameter source: the new source
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(source: CopilotSource) -> Bool
}

/// Copilot setting implementation
class CopilotSettingCore: CopilotSetting, CustomDebugStringConvertible {

    /// Delegate called when the setting value is changed by setting properties
    private unowned let didChangeDelegate: SettingChangeDelegate

    /// Timeout object.
    ///
    /// Visibility is internal for testing purposes
    let timeout = SettingTimeout()

    /// Tells if the setting value has been changed and is waiting for change confirmation
    var updating: Bool { return timeout.isScheduled }

    /// Current piloting source
    var source: CopilotSource {
        get {
            return _source
        }
        set {
            if _source != newValue {
                if backend(newValue) {
                    let oldValue = _source
                    // value sent to the backend, update setting value and mark it updating
                    _source = newValue
                    timeout.schedule { [weak self] in
                        if let `self` = self, self.update(source: oldValue) {
                            self.didChangeDelegate.userDidChangeSetting()
                        }
                    }
                    didChangeDelegate.userDidChangeSetting()
                }
            }
        }
    }
    /// Copilot source
    private var _source: CopilotSource = .remoteControl

    /// Closure to call to change the value
    private let backend: ((CopilotSource) -> Bool)

    /// Constructor
    ///
    /// - Parameters:
    ///   - didChangeDelegate: delegate called when the setting value is changed by setting properties
    ///   - backend: closure to call to change the setting value
    init(didChangeDelegate: SettingChangeDelegate, backend: @escaping (CopilotSource) -> Bool) {
        self.didChangeDelegate = didChangeDelegate
        self.backend = backend
    }

    /// Called by the backend, change the current source
    ///
    /// - Parameter source: new source
    /// - Returns: true if the setting has been changed, false otherwise
    func update(source newSource: CopilotSource) -> Bool {
        if updating || _source != newSource {
            _source = newSource
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

    /// Debug description
    var debugDescription: String {
        return "value: \(_source) updating: [\(updating)]"
    }
}

/// Internal copilot peripheral implementation
public class CopilotCore: PeripheralCore, Copilot {
    ///  Copilot setting
    public var setting: CopilotSetting {
        return _setting
    }
    private var _setting: CopilotSettingCore!

    /// Implementation backend
    private unowned let backend: CopilotBackend

    /// Debug description
    public override var description: String {
        return "Copilot : setting = \(setting)]"
    }

    /// Constructor.
    ///
    /// - Parameters:
    ///    - store: store where this peripheral will be stored
    ///    - backend: copilot backend
    public init(store: ComponentStoreCore, backend: CopilotBackend) {
        self.backend = backend
        super.init(desc: Peripherals.copilot, store: store)
        _setting = CopilotSettingCore(didChangeDelegate: self, backend: { [unowned self] source in
            return self.backend.set(source: source)})
    }

    /// Sends the copilot source to drone.
    ///
    /// - Parameter source: new source
    public func setCopilotSource(_ source: CopilotSource) {
        _ = backend.set(source: source)
    }
}

/// Backend callback methods
extension CopilotCore {

    /// Set the source for copilot
    ///
    /// - Parameter source: the copilot source
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(source newSource: CopilotSource) -> CopilotCore {
        if _setting.update(source: newSource) {
            markChanged()
        }
        return self
    }
}
