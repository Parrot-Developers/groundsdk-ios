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

@testable import GroundSdk

/// Mocking class for the Internet Connectivity utility.
/// This mock class uses a `MockInternetReachabilityListener` instead of the real one to be able to mock Internet
/// reachability changes.
class MockInternetConnectivity: InternetConnectivityCoreImpl {

    private var mockInternetReachabilityListener: MockInternetReachabilityListener!

    /// Mock way of setting the Internet availability changes.
    /// Changes will be applied immediately after the set.
    public var mockInternetAvailable = false {
        didSet {
            mockInternetReachabilityListener.internetAvailable = mockInternetAvailable
        }
    }

    override public func createInternetReachabilityListener(callback: @escaping (_ internetAvailable: Bool) -> Void)
        -> InternetReachabilityListener {
            mockInternetReachabilityListener = MockInternetReachabilityListener(callback: callback)
            return mockInternetReachabilityListener
    }

    private class MockInternetReachabilityListener: InternetReachabilityListener {

        /// Mock way of setting the Internet availability changes.
        /// When set, the callback will be called.
        public var internetAvailable = false {
            didSet {
                if running {
                    callback(internetAvailable)
                }
            }
        }

        private(set) public var running = false

        /// The callback that should be called when Internet reachability changes
        private let callback: (_ internetAvailable: Bool) -> Void

        required public init(callback: @escaping (Bool) -> Void) {
            self.callback = callback
        }

        public func start() {
            running = true
            // mimic the real implementation
            callback(internetAvailable)
        }

        public func stop() {
            running = false
        }
    }
}

