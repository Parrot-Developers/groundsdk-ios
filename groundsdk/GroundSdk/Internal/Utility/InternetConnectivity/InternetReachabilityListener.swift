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
import SystemConfiguration

/// Protocol for objects that can start and stop listening for Internet reachability.
/// When Internet reachability changes, they call a given callback.
///
/// - Note: the main purpose of this protocol is to easily create mocks.
protocol InternetReachabilityListener {
    /// Constructor
    ///
    /// - Parameters:
    ///    - callback: the callback that should be called when Internet reachability changes
    ///    - internetAvailable: whether Internet is reachable
    init(callback: @escaping (_ internetAvailable: Bool) -> Void)

    /// Whether this object is currently listening for Internet reachability changes.
    var running: Bool { get }

    /// Start listening for Internet reachability changes
    func start()

    /// Stop listening for Internet reachability changes
    func stop()
}

/// Implementation of the Internet reachability listener protocol
class InternetReachabilityListenerImpl: InternetReachabilityListener {

    /// The callback that should be called when Internet reachability changes
    private let callback: (_ internetAvailable: Bool) -> Void

    /// `true` if Internet is available, `false' otherwise.
    private var internetAvailable: Bool {
        guard isReachableFlagSet else { return false }

        return !isConnectionRequiredAndTransientFlagSet
    }

    /// `true` if network flag "reachable" is set, `false` otherwise.
    private var isReachableFlagSet: Bool {
        return reachabilityFlags.contains(.reachable)
    }

    /// `true` if network flags "connectionRequired" and "transientConnection" are set, `false` otherwise.
    private var isConnectionRequiredAndTransientFlagSet: Bool {
        return reachabilityFlags.intersection([.connectionRequired, .transientConnection]) ==
            [.connectionRequired, .transientConnection]
    }

    /// Network reachability flags
    private var reachabilityFlags: SCNetworkReachabilityFlags {
        var flags = SCNetworkReachabilityFlags()
        let gotFlags = withUnsafeMutablePointer(to: &flags) {
            SCNetworkReachabilityGetFlags(reachabilityRef, UnsafeMutablePointer($0))
        }

        if gotFlags {
            return flags
        } else {
            return SCNetworkReachabilityFlags()
        }
    }

    /// Previous internet reachability state
    private var previousReachability = false

    /// `true` if the monitor is started, otherwise `false`
    ///
    /// - Note: read access is granted internally for testing purposes.
    private(set) var running = false

    /// The NetworkReachability
    private let reachabilityRef: SCNetworkReachability

    /// Internet listener executor queue
    private let reachabilitySerialQueue = DispatchQueue(label: "internetMonitor")

    /// Constructor
    ///
    /// - Parameters:
    ///    - callback: the callback that should be called when Internet reachability changes
    ///    - internetAvailable: whether Internet is reachable
    required init(callback: @escaping (_ internetAvailable: Bool) -> Void) {
        self.callback = callback

        var zeroAddress = sockaddr()
        zeroAddress.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zeroAddress.sa_family = sa_family_t(AF_INET)

        reachabilityRef = withUnsafePointer(to: &zeroAddress, {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0))!
        })
    }

    func start() {
        if !running {
            var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil,
                                                       copyDescription: nil)
            context.info = UnsafeMutableRawPointer(Unmanaged<InternetReachabilityListenerImpl>
                .passUnretained(self).toOpaque())
            if !SCNetworkReachabilitySetCallback(reachabilityRef, reachabilityCallback, &context) {
                stop()
                ULog.e(.internetConnectivityTag, "Failed to set callback.")
                return
            }

            if !SCNetworkReachabilitySetDispatchQueue(reachabilityRef, reachabilitySerialQueue) {
                stop()
                ULog.e(.internetConnectivityTag, "Failed to set dispatch queue.")
                return
            }

            running = true
            ULog.i(.internetConnectivityTag, "Started listening for Internet connectivity changes.")

            // Perform an initial check
            reachabilitySerialQueue.async {
                self.reachabilityChanged()
            }
        }
    }

    func stop() {
        if running {
            SCNetworkReachabilitySetCallback(reachabilityRef, nil, nil)
            SCNetworkReachabilitySetDispatchQueue(reachabilityRef, nil)

            self.callback(false)
            previousReachability = false
            running = false
            ULog.i(.internetConnectivityTag, "Stopped listening for Internet connectivity changes.")
        }
    }

    /// Updates internet reachability and notify listeners
    fileprivate func reachabilityChanged() {
        let newReachability = internetAvailable

        guard previousReachability != newReachability else { return }

        previousReachability = newReachability
        ULog.i(.internetConnectivityTag, (internetAvailable) ? "Internet is available." : "Internet is not available.")

        // notify
        DispatchQueue.main.async {
            if self.running {
                self.callback(self.internetAvailable)
            }
        }
    }
}

/// SCNetworkReachability callback
func reachabilityCallback(reachability: SCNetworkReachability, flags: SCNetworkReachabilityFlags,
                          info: UnsafeMutableRawPointer?) {
    guard let info = info else { return }

    let internetReachabilityListener = Unmanaged<InternetReachabilityListenerImpl>
        .fromOpaque(info).takeUnretainedValue()

    internetReachabilityListener.reachabilityChanged()
}
