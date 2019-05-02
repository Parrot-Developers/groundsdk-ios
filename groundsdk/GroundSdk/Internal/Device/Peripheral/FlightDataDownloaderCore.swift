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

/// Internal implementation of the FlightDataDownloader
public class FlightDataDownloaderCore: PeripheralCore, FlightDataDownloader {

    /// Core implementation of the state
    public private(set) var state: FlightDataDownloaderState

    private(set) public var isDownloading = false

    /// Constructor
    ///
    /// - Parameter store: store where this peripheral will be stored
    public init(store: ComponentStoreCore) {
        state = FlightDataDownloaderState()
        super.init(desc: Peripherals.flightDataDownloader, store: store)
    }
}

// MARK: - Backend callback methods
extension FlightDataDownloaderCore {

    /// Updates the currently downloading flag.
    ///
    /// - Parameter isDownloading: the new downloading flag
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(isDownloading newValue: Bool) -> FlightDataDownloaderCore {
        if isDownloading != newValue {
            isDownloading = newValue
            markChanged()
        }
        return self
    }

    /// Updates latestDownloadCount.
    ///
    /// - Parameter downloadedCount: new downloaded count
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(latestDownloadCount newValue: Int) -> FlightDataDownloaderCore {
        if state.latestDownloadCount != newValue {
            state.latestDownloadCount = newValue
            markChanged()
        }
        return self
    }

    /// Updates download completion status.
    ///
    /// - Parameter status: new  status
    /// - Returns: self to allow call chaining
    /// - Note: Changes are not notified until notifyUpdated() is called.
    @discardableResult public func update(status newValue: FlightDataDownloadCompletionStatus)
        -> FlightDataDownloaderCore {
            if state.status != newValue {
                state.status = newValue
                markChanged()
            }
        return self
    }
}
