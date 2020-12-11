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
import UIKit

/// Core class for FileReplay.
public class FileReplayCore: ReplayCore, FileReplay {

    /// Played back file.
    public let source: FileReplaySource

    /// Pomp loop for pdraw.
    private var pompLoopUtil: PompLoopUtil?

    /// Constructor
    ///
    /// - Parameter source: source to be played back
    public init(source: FileReplaySource) {
        self.source = source
    }

    /// Create a stream backend.
    ///
    /// This is kept in a separated method, for testing purpose.
    ///
    /// - Parameters:
    ///    - pompLoopUtil: pomp loop utility
    ///    - source: video stream source
    ///    - listener: listener that will be called when events happen on the stream
    /// - Returns: a new 'SdkCoreStream' instance on success, otherwise 'nil'
    func createSdkCoreStream(pompLoopUtil: PompLoopUtil,
                             source: SdkCoreFileSource,
                             listener: SdkCoreStreamListener) -> SdkCoreStream? {
        return SdkCoreStream(pompLoopUtil: pompLoopUtil, source: source, track: self.source.trackName,
                             listener: listener)
    }

    override func openStream(listener: SdkCoreStreamListener) -> SdkCoreStream? {
        pompLoopUtil = PompLoopUtil(name: "FileReplay")

        guard let pompLoopUtil = pompLoopUtil,
            let url = source.file?.path,
            let source = SdkCoreFileSource(url: url),
            let sdkCoreStream = createSdkCoreStream(pompLoopUtil: pompLoopUtil, source: source, listener: listener)
            else {
                return nil
        }
        pompLoopUtil.runLoop()
        sdkCoreStream.open()
        registerAppBackgroundObserver()
        return sdkCoreStream
    }

    override func handleSdkCoreStreamClose() {
        super.handleSdkCoreStreamClose()
        unregisterAppBackgroundObserver()
    }

    public override func streamDidClose(_ sdkCoreStream: SdkCoreStream, reason: SdkCoreStreamCloseReason) {
        super.streamDidClose(sdkCoreStream, reason: reason)
        pompLoopUtil?.stopRun()
    }
}

/// Extension to pause streaming when the application is put in background.
extension FileReplayCore {

    /// Register observer to get notified when the application is put in background.
    func registerAppBackgroundObserver() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground),
                                       name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    /// Unregister observer notified when the application is put in background.
    func unregisterAppBackgroundObserver() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    /// Called when the application is put in background.
    /// Pause streaming.
    @objc
    func appMovedToBackground() {
        _ = self.pause()
    }
}
