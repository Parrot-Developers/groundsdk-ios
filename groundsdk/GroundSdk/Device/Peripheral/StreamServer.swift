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

/// StreamServer peripheral interface.
/// This peripheral allows streaming of live camera video and replay of video files stored in drone memory.
///
/// This peripheral can be retrieved by:
///
/// ```
/// drone.getPeripheral(Peripherals.streamServer)
/// ```
public protocol StreamServer: Peripheral {

    /// Tells whether streaming is enabled.
    ///
    /// When streaming gets enabled, currently suspended stream will be resumed.
    /// When streaming is enabled, streams can be started.
    ///
    /// When streaming gets disabled, currently started stream gets suspended,
    /// in case it supports suspended state (CameraLive), or stopped otherwise (MediaReplay).
    /// When streaming is disabled, no stream can be started.
    var enabled: Bool { get set }

    /// Provides access to the drone camera live stream.
    /// There is only one live stream instance that is shared amongst all open references.
    /// Dereferencing the returned reference does NOT automatically stops the referenced camera live stream.
    ///
    /// - Parameter observer: notified when the stream state changes
    /// - Returns: a reference to the camera live stream interface
    func live(observer: @escaping (_ stream: CameraLive?) -> Void) -> Ref<CameraLive>

    /// Creates a new replay stream for a media resource.
    /// Every successful call to this method creates a new replay stream instance for the given media resource,
    /// that must be disposed by dereferencing the returned reference once that stream is not needed.
    /// Dereferencing the returned reference automatically stops the referenced media replay stream.
    ///
    /// - Parameter source: media source to stream
    /// - Parameter observer: notified when the stream state changes
    /// - Returns: a reference to the replay stream interface,
    ///            or 'nil' in case the provided resource cannot be streamed
    func replay(source: MediaReplaySource, observer: @escaping (_ stream: MediaReplay?) -> Void) -> Ref<MediaReplay>?
}

/// :nodoc:
/// StreamServer description
@objc(GSStreamServerDesc)
public class StreamServerDesc: NSObject, PeripheralClassDesc {
    public typealias ApiProtocol = StreamServer
    public let uid = PeripheralUid.streamServer.rawValue
    public let parent: ComponentDescriptor? = nil
}

/// StreamServer peripheral interface.
/// This peripheral allows streaming of live camera video and replay of video files stored in drone memory.
/// Those methods should no be used from swift
@objc
public protocol GSStreamServer {

    /// Tells whether streaming is enabled.
    ///
    /// When streaming gets enabled, currently suspended stream will be resumed.
    /// When streaming is enabled, streams can be started.
    ///
    /// When streaming gets disabled, currently started stream gets suspended,
    /// in case it supports suspended state (CameraLive), or stopped otherwise (MediaReplay).
    /// When streaming is disabled, no stream can be started.
    var enabled: Bool { get set }

    /// Provides access to the drone camera live stream.
    /// There is only one live stream instance that is shared amongst all open references.
    /// Closing the returned reference does NOT automatically stops the referenced camera live stream.
    ///
    /// - Parameter observer: notified when the stream state changes
    /// - Returns: a reference to the camera live stream interface
    func live(observer: @escaping (_ stream: CameraLive?) -> Void) -> GSCameraLiveRef

    /// Creates a new replay stream for a media resource.
    /// Every successful call to this method creates a new replay stream instance for the given media resource,
    /// that must be disposed by closing the returned reference once that stream is not needed.
    /// Closing the returned reference automatically stops the referenced media replay stream.
    ///
    /// - Parameter resource: media resource to stream
    /// - Parameter observer: notified when the stream state changes
    /// - Returns: a reference to the camera live stream interface,
    ///            or 'nil' in case the provided resource cannot be streamed
    func replay(source: MediaReplaySource, observer: @escaping (_ stream: MediaReplay?) -> Void) -> GSMediaReplayRef?
}
