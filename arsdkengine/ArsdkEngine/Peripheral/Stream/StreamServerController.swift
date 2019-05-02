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
import GroundSdk

/// StreamServer implementation over ArsdkStream.
class StreamServerController: DeviceComponentController {

    /// StreamServer peripheral for which this object is the backend.
    private var streamServerCore: StreamServerCore!

    /// Active stream
    var currentStream: ArsdkStream?

    /// Stream waiting to become the active stream
    var pendingStream: ArsdkStream?

    /// Constructor
    ///
    /// - Parameter devicontroller: the drone controller that owns this peripheral controller.
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        streamServerCore = StreamServerCore(store: deviceController.device.peripheralStore, backend: self)
    }

    /// Drone is connected.
    override func didConnect() {
        streamServerCore.update(enable: true)
        streamServerCore.publish()
    }

    /// Drone is disconnected.
    override func didDisconnect() {
        streamServerCore.unpublish()
    }
}

/// Backend of StreamServerCore implementation.
extension StreamServerController: StreamServerBackend {

    func openStream(url: String, track: String, listener: SdkCoreStreamListener) -> SdkCoreStream? {
        let listenerWrapper: StreamListenerWrapper = StreamListenerWrapper(controller: self, listener: listener)
        let stream: ArsdkStream? = (deviceController as! DroneController).createVideoStream(url: url, track: track,
                                                                                            listener: listenerWrapper)
        if currentStream == nil {
            currentStream = stream
            currentStream?.open()
        } else if let streamToClose = pendingStream {
            streamToClose.close(.interrupted)
            pendingStream = stream
        } else {
            pendingStream = stream
            currentStream!.close(.interrupted)
        }
        return stream
    }
}

/// Wrapper over SdkCoreStreamListener.
/// It intends to manage opening of pending stream when current stream is closed.
/// It is itself a SdkCoreStreamListener that forwards notifications to another SdkCoreStreamListener.
class StreamListenerWrapper: NSObject, SdkCoreStreamListener {

    /// Stream server controller.
    private let controller: StreamServerController

    /// Stream listener to which notifications are forwarded.
    private let listener: SdkCoreStreamListener

    /// Constructor
    ///
    /// - Parameters:
    ///    - controller: stream server controller
    ///    - listener: stream listener to which notifications are forwarded
    init(controller: StreamServerController, listener: SdkCoreStreamListener) {
        self.controller = controller
        self.listener = listener
    }

    func streamDidOpen(_ stream: SdkCoreStream) {
        listener.streamDidOpen(stream)
    }

    func streamPlaybackStateDidChange(_ stream: SdkCoreStream, duration: Int64, position: Int64, speed: Double,
                                      timestamp: TimeInterval) {
        listener.streamPlaybackStateDidChange(stream, duration: duration, position: position, speed: speed,
                                              timestamp: timestamp)
    }

    func streamDidClosing(_ stream: SdkCoreStream, reason: SdkCoreStreamCloseReason) {
        listener.streamDidClosing(stream, reason: reason)
    }

    func streamDidClose(_ stream: SdkCoreStream, reason: SdkCoreStreamCloseReason) {
        if stream.isEqual(controller.currentStream) {
            controller.currentStream = controller.pendingStream
            controller.pendingStream = nil
            controller.currentStream?.open()
        } else if stream.isEqual(controller.pendingStream) {
            controller.pendingStream = nil
        }
        listener.streamDidClose(stream, reason: reason)
    }

    func mediaAdded(_ stream: SdkCoreStream, mediaInfo: SdkCoreMediaInfo) {
        listener.mediaAdded(stream, mediaInfo: mediaInfo)
    }

    func mediaRemoved(_ stream: SdkCoreStream, mediaInfo: SdkCoreMediaInfo) {
        listener.mediaRemoved(stream, mediaInfo: mediaInfo)
    }
}
