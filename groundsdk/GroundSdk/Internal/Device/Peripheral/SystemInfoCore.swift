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

/// System info backend part.
public protocol SystemInfoBackend: class {
    /// Asks to the device to do a settings reset.
    ///
    /// - Returns: true if the reset factory is in progress
    func resetSettings() -> Bool

    /// Asks to the device to do a factory reset.
    ///
    /// - Returns: true if the reset factory is in progress
    func factoryReset() -> Bool
}

/// Internal system info peripheral implementation
public class SystemInfoCore: PeripheralCore, SystemInfo {

    /// Implementation backend
    private unowned let backend: SystemInfoBackend

    /// Firmware version of the device
    private(set) public var firmwareVersion = ""

    /// Whether firmware is blacklisted
    public var isFirmwareBlacklisted = false

    /// Hardware version of the device
    private(set) public var hardwareVersion = ""

    /// Serial of the device
    private(set) public var serial = ""

    /// Device board identifier.
    private(set) public var boardId = ""

    /// Whether or not the reset settings is in progress
    private(set) public var  isResetSettingsInProgress = false

    /// Whether or not the factory reset is in progress
    private(set) public var isFactoryResetInProgress = false

    /// Constructor
    ///
    /// - Parameters:
    ///    - store: store where this peripheral will be stored
    ///    - backend: System info backend
    public init(store: ComponentStoreCore, backend: SystemInfoBackend) {
        self.backend = backend
        super.init(desc: Peripherals.systemInfo, store: store)
    }

    /// Constructor for subclasses
    ///
    /// - Parameters:
    ///    - desc: subclass component descriptor
    ///    - store: store where this interface will be stored
    ///    - backend: System info backend
    init(desc: ComponentDescriptor, store: ComponentStoreCore, backend: SystemInfoBackend) {
        self.backend = backend
        super.init(desc: desc, store: store)
    }

    public func resetSettings() -> Bool {
        let inProgress = backend.resetSettings()
        if inProgress && !isResetSettingsInProgress {
            isResetSettingsInProgress = true
            markChanged()
            notifyUpdated()
        }
        return inProgress
    }

    public func factoryReset() -> Bool {
        let inProgress = backend.factoryReset()
        if inProgress && !isFactoryResetInProgress {
            isFactoryResetInProgress = true
            markChanged()
            notifyUpdated()
        }
        return inProgress
    }
}

/// Backend callback methods
extension SystemInfoCore {

    /// Changes the firmware version
    ///
    /// - Parameter firmwareVersion: new firmware version
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(firmwareVersion newValue: String) -> SystemInfoCore {
        if newValue != firmwareVersion {
            firmwareVersion = newValue
            markChanged()
        }
        return self
    }

    /// Changes the blacklist info about the firmware version
    ///
    /// - Parameter isBlacklisted: whether the current firmware of the device is blacklisted
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(isBlacklisted newValue: Bool) -> SystemInfoCore {
        if newValue != isFirmwareBlacklisted {
            isFirmwareBlacklisted = newValue
            markChanged()
        }
        return self
    }

    /// Changes the hardware version
    ///
    /// - Parameter hardwareVersion: new hardware version
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(hardwareVersion newValue: String) -> SystemInfoCore {
        if newValue != hardwareVersion {
            hardwareVersion = newValue
            markChanged()
        }
        return self
    }

    /// Changes the serial
    ///
    /// - Parameter serial: new serial
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(serial newValue: String) -> SystemInfoCore {
        if newValue != serial {
            serial = newValue
            markChanged()
        }
        return self
    }

    /// Changes the board id
    ///
    /// - Parameter boardId: new board id
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(boardId newValue: String) -> SystemInfoCore {
        if newValue != boardId {
            boardId = newValue
            markChanged()
        }
        return self
    }

    /// Reset settings process has ended
    ///
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func resetSettingsEnded() -> SystemInfoCore {
        if isResetSettingsInProgress != false {
            isResetSettingsInProgress = false
            markChanged()
        }
        return self
    }

    /// Factory reset process has ended
    ///
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func factoryResetEnded() -> SystemInfoCore {
        if isFactoryResetInProgress != false {
            isFactoryResetInProgress = false
            markChanged()
        }
        return self
    }
}
