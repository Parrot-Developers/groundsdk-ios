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

/// Wifi scanner backend
public protocol WifiScannerBackend: class {
    /// Starts scanning channels occupation rate.
    func startScan()

    /// Stops ongoing channels occupation rate scan.
    func stopScan()
}

/// Internal implementation of the Wifi scanner
public class WifiScannerCore: PeripheralCore, WifiScanner {
    /// Whether or not the peripheral is currently scanning Wifi networks environment.
    private (set) public var scanning = false

    /// Map of occupation rate (amount of scanned networks), by wifi channel.
    private var scannedChannels: [WifiChannel: Int] = [:]

    /// Implementation backend
    private unowned let backend: WifiScannerBackend

    /// Constructor
    ///
    /// - Parameters:
    ///   - store: store where this peripheral will be stored
    ///   - backend: wifi scanner backend
    public init(store: ComponentStoreCore, backend: WifiScannerBackend) {
        self.backend = backend
        super.init(desc: Peripherals.wifiScanner, store: store)
    }

    public func startScan() {
        if !scanning {
            backend.startScan()
        }
    }

    public func stopScan() {
        if scanning {
            backend.stopScan()
        }
    }

    public func getOccupationRate(forChannel channel: WifiChannel) -> Int {
        return scannedChannels[channel] ?? 0
    }
}

/// Backend callback methods
extension WifiScannerCore {
    /// Changes channels occupation rate.
    ///
    /// - Parameter scannedChannels: new map of occupation rate (amount of wifi networks) by channel
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(scannedChannels newValue: [WifiChannel: Int]) -> WifiScannerCore {
        if scannedChannels != newValue {
            markChanged()
            scannedChannels = newValue
        }
        return self
    }

    /// Changes the scanning flag.
    ///
    /// - Parameter scanning: new scanning flag value
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(scanning newValue: Bool) -> WifiScannerCore {
        if scanning != newValue {
            markChanged()
            scanning = newValue
        }
        return self
    }
}
