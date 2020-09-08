// Copyright (C) 2020 Parrot Drones SAS
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

/// LogControl backend part.
public protocol LogControlBackend: class {
    /// Requests the deactivation of logs.
    ///
    /// - Note: The logs stay disabled for the session, and will be
    ///     enabled again at the next restart.
    ///
    /// - Returns: `true` if the deactivation has been asked, `false` otherwise
    func deactivateLogs() -> Bool
}

/// Internal log control peripheral implementation
public class LogControlCore: PeripheralCore, LogControl {
    /// Implementation backend
    private unowned let backend: LogControlBackend

    /// Indicates if the logs are enabled on the drone.
    private (set) public var areLogsEnabled: Bool = true

    /// Indicates if the deactivate command is supported
    private (set) public var canDeactivateLogs: Bool = false

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: store where this peripheral will be stored
    ///    - backend: LogControl info backend
    public init(store: ComponentStoreCore, backend: LogControlBackend) {
        self.backend = backend
        super.init(desc: Peripherals.logControl, store: store)
    }

    /// Requests the deactivation of logs.
    public func deactivateLogs() -> Bool {
        return backend.deactivateLogs()
    }
}

extension LogControlCore {
    /// Set whether the deactivate logs command is supported or not
    ///
    /// - Parameter canDeactivateLogs:the new value
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(canDeactivateLogs newValue: Bool) -> LogControlCore {
        if newValue != canDeactivateLogs {
            canDeactivateLogs = newValue
            markChanged()
        }
        return self
    }

    /// Set whether the logs are enabled or not
    ///
    /// - Parameter areLogsEnabled: the new value
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(areLogsEnabled newValue: Bool) -> LogControlCore {
        if areLogsEnabled != newValue {
            areLogsEnabled = newValue
            markChanged()
        }
        return self
    }
}
