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

import XCTest
@testable import GroundSdk

/// Test StreamServer peripheral
class StreamServerTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: StreamServerCore!
    private var backend: Backend!

    let mockRes: MediaItem.Resource = MediaItemResourceCore(uid: "0", format: .mp4, size: 0,
                                                            duration: nil, streamUrl: "live",
                                                            location: nil, creationDate: Date(),
                                                            metadataTypes: Set([.thermal]))

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
    }

    func testPublishUnpublish() {
        impl = StreamServerCore(store: store!, backend: backend!)
        impl.publish()
        assertThat(store!.get(Peripherals.streamServer), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.streamServer), nilValue())
    }

    func testEnable() {
        impl = StreamServerCore(store: store!, backend: backend!)
        impl.publish()
        var cnt = 0
        let streamServer = store.get(Peripherals.streamServer)!
        _ = store.register(desc: Peripherals.streamServer) {
            cnt += 1
        }

        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(streamServer.enabled, `is`(false))

        // enable streaming
        streamServer.enabled = true
        assertThat(cnt, `is`(1))
        assertThat(streamServer.enabled, `is`(true))

        // change from backend
        impl.update(enable: false).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(streamServer.enabled, `is`(false))

        // set to same value should change nothing
        streamServer.enabled = false
        assertThat(cnt, `is`(2))
        assertThat(streamServer.enabled, `is`(false))

        // update from backend to same value should change nothing
        impl.update(enable: false).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(streamServer.enabled, `is`(false))
    }

    func testCameraLive() {
        impl = StreamServerCore(store: store!, backend: backend!)
        impl.publish()
        var cnt = 0
        let streamServer = store.get(Peripherals.streamServer)!
        _ = store.register(desc: Peripherals.streamServer) {
            cnt += 1
        }

        var streamCnt = 0
        var streamRef: Ref<CameraLive>?
        streamRef = streamServer.live {_ in
            streamCnt += 1
        }

        assertThat(streamRef?.value, present())
        let stream = streamRef?.value! as! CameraLiveCore

        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(streamServer.enabled, `is`(false))
        assertThat(streamCnt, `is`(1))
        assertThat(stream, `is`(state: .stopped, playState: .none))
        assertThat(backend.openStreamCnt, `is`(0))
        assertThat(backend.mockSdkCoreStream, nilValue())

        // enable streaming
        streamServer.enabled = true
        assertThat(cnt, `is`(1))
        assertThat(streamServer.enabled, `is`(true))
        assertThat(streamCnt, `is`(1))
        assertThat(stream, `is`(state: .stopped, playState: .none))
        assertThat(backend.openStreamCnt, `is`(0))
        assertThat(backend.mockSdkCoreStream, nilValue())

        // play stream
        _ = stream.play()
        assertThat(streamCnt, `is`(2))
        assertThat(stream, `is`(state: .starting, playState: .none))
        assertThat(backend.openStreamCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream, present())
        assertThat(backend.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.playCnt, `is`(0))
        assertThat(backend.mockSdkCoreStream!.pauseCnt, `is`(0))

        // stream open notification from backend
        stream.streamDidOpen(backend.mockSdkCoreStream!)
        assertThat(streamCnt, `is`(3))
        assertThat(stream, `is`(state: .started, playState: .none))
        assertThat(backend.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.playCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.pauseCnt, `is`(0))

        // stream playing notification from backend
        stream.streamPlaybackStateDidChange(backend.mockSdkCoreStream!,
                                            duration: 10000, position: 0, speed: 1, timestamp: 0)
        assertThat(streamCnt, `is`(4))
        assertThat(stream, `is`(state: .started, playState: .playing))

        // play stream again should change nothing
        _ = stream.play()
        assertThat(streamCnt, `is`(4))
        assertThat(stream, `is`(state: .started, playState: .playing))
        assertThat(backend.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.playCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.pauseCnt, `is`(0))

        // stream playing notification from backend should change nothing
        stream.streamPlaybackStateDidChange(backend.mockSdkCoreStream!,
                                            duration: 10000, position: 0, speed: 1, timestamp: 0)
        assertThat(streamCnt, `is`(4))
        assertThat(stream, `is`(state: .started, playState: .playing))

        // pause stream
        _ = stream.pause()
        assertThat(streamCnt, `is`(4))
        assertThat(stream, `is`(state: .started, playState: .playing))
        assertThat(backend.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.playCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.pauseCnt, `is`(1))

        // stream paused notification from backend
        stream.streamPlaybackStateDidChange(backend.mockSdkCoreStream!,
                                            duration: 10000, position: 0, speed: 0, timestamp: 0)
        assertThat(streamCnt, `is`(5))
        assertThat(stream, `is`(state: .started, playState: .paused))

        // pause stream again should change nothing
        _ = stream.pause()
        assertThat(streamCnt, `is`(5))
        assertThat(stream, `is`(state: .started, playState: .paused))
        assertThat(backend.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.playCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.pauseCnt, `is`(1))

        // stream paused notification from backend should change nothing
        stream.streamPlaybackStateDidChange(backend.mockSdkCoreStream!,
                                            duration: 10000, position: 0, speed: 0, timestamp: 0)
        assertThat(streamCnt, `is`(5))
        assertThat(stream, `is`(state: .started, playState: .paused))

        // play stream
        _ = stream.play()
        assertThat(streamCnt, `is`(5))
        assertThat(stream, `is`(state: .started, playState: .paused))
        assertThat(backend.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.playCnt, `is`(2))
        assertThat(backend.mockSdkCoreStream!.pauseCnt, `is`(1))

        // stream playing notification from backend
        stream.streamPlaybackStateDidChange(backend.mockSdkCoreStream!,
                                            duration: 10000, position: 0, speed: 1, timestamp: 0)
        assertThat(streamCnt, `is`(6))
        assertThat(stream, `is`(state: .started, playState: .playing))

        // unpublish the stream server
        assertThat(backend.mockSdkCoreStream!.closeCnt, `is`(0))
        impl.unpublish()
        assertThat(streamRef?.value, nilValue())

        // check that unreferencing the stream, removes the observer
        assertThat(stream.countListeners(), `is`(1))
        streamRef = nil
        assertThat(stream.countListeners(), `is`(0))

        assertThat(backend.mockSdkCoreStream!.closeCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.closeReason, presentAnd(`is`(.userRequested)))
    }

    func testMediaReplaySourceDefault() {
        impl = StreamServerCore(store: store!, backend: backend!)
        impl.publish()
        var cnt = 0
        let streamServer = store.get(Peripherals.streamServer)!
        _ = store.register(desc: Peripherals.streamServer) {
            cnt += 1
        }

        var streamCnt = 0
        var streamRef = streamServer.replay(
            source: MediaReplaySourceFactory.videoTrackOf(resource: mockRes, track: .defaultVideo)) {_ in
            streamCnt += 1
        }

        assertThat(streamRef?.value, present())
        let stream = streamRef?.value! as! MediaReplayCore

        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(streamServer.enabled, `is`(false))
        assertThat(streamCnt, `is`(1))
        assertThat(stream, `is`(state: .stopped, playState: .none))
        assertThat(stream.position, `is`(0))
        assertThat(stream.duration, `is`(0))
        assertThat(stream.source.track, `is`(.defaultVideo))
        assertThat(stream.source.mediaUid, `is`(nilValue()))
        assertThat(stream.source.resourceUid, `is`(mockRes.uid))
        assertThat(backend.openStreamCnt, `is`(0))
        assertThat(backend.mockSdkCoreStream, nilValue())

        // enable streaming
        streamServer.enabled = true
        assertThat(cnt, `is`(1))
        assertThat(streamServer.enabled, `is`(true))
        assertThat(streamCnt, `is`(1))
        assertThat(stream, `is`(state: .stopped, playState: .none))

        // play stream
        _ = stream.play()
        assertThat(streamCnt, `is`(2))
        assertThat(stream, `is`(state: .starting, playState: .none))
        assertThat(backend.openStreamCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream, present())
        assertThat(backend.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.playCnt, `is`(0))
        assertThat(backend.mockSdkCoreStream!.pauseCnt, `is`(0))

        // stream open notification from backend
        stream.streamDidOpen(backend.mockSdkCoreStream!)
        assertThat(streamCnt, `is`(3))
        assertThat(stream, `is`(state: .started, playState: .none))
        assertThat(backend.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.playCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.pauseCnt, `is`(0))

        // stream playing notification from backend
        stream.streamPlaybackStateDidChange(backend.mockSdkCoreStream!,
                                            duration: 1000, position: 0, speed: 1, timestamp: 0)
        assertThat(streamCnt, `is`(4))
        assertThat(stream, `is`(state: .started, playState: .playing))

        // play stream again should change nothing
        _ = stream.play()
        assertThat(streamCnt, `is`(4))
        assertThat(stream, `is`(state: .started, playState: .playing))
        assertThat(backend.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.playCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.pauseCnt, `is`(0))

        // stream playing notification from backend should change nothing
        stream.streamPlaybackStateDidChange(backend.mockSdkCoreStream!,
                                            duration: 1000, position: 0, speed: 1, timestamp: 0)
        assertThat(streamCnt, `is`(4))
        assertThat(stream, `is`(state: .started, playState: .playing))

        // pause stream
        _ = stream.pause()
        assertThat(streamCnt, `is`(4))
        assertThat(stream, `is`(state: .started, playState: .playing))
        assertThat(backend.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.playCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.pauseCnt, `is`(1))

        // stream paused notification from backend
        stream.streamPlaybackStateDidChange(backend.mockSdkCoreStream!,
                                            duration: 1000, position: 0, speed: 0, timestamp: 0)
        assertThat(streamCnt, `is`(5))
        assertThat(stream, `is`(state: .started, playState: .paused))

        // pause stream again should change nothing
        _ = stream.pause()
        assertThat(streamCnt, `is`(5))
        assertThat(stream, `is`(state: .started, playState: .paused))
        assertThat(backend.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.playCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.pauseCnt, `is`(1))

        // stream paused notification from backend should change nothing
        stream.streamPlaybackStateDidChange(backend.mockSdkCoreStream!,
                                            duration: 1000, position: 0, speed: 0, timestamp: 0)
        assertThat(streamCnt, `is`(5))
        assertThat(stream, `is`(state: .started, playState: .paused))

        // play stream
        _ = stream.play()
        assertThat(streamCnt, `is`(5))
        assertThat(stream, `is`(state: .started, playState: .paused))
        assertThat(backend.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.playCnt, `is`(2))
        assertThat(backend.mockSdkCoreStream!.pauseCnt, `is`(1))

        // duration update
        stream.streamPlaybackStateDidChange(backend.mockSdkCoreStream!,
                                            duration: 10000, position: 0, speed: 0, timestamp: 0)
        assertThat(streamCnt, `is`(6))
        assertThat(stream.duration, `is`(10))

        // duration update to same value should change nothing
        stream.streamPlaybackStateDidChange(backend.mockSdkCoreStream!,
                                            duration: 10000, position: 0, speed: 0, timestamp: 0)
        assertThat(streamCnt, `is`(6))
        assertThat(stream.duration, `is`(10))

        // position update, should not trigger a change notification
        stream.streamPlaybackStateDidChange(backend.mockSdkCoreStream!,
                                            duration: 10000, position: 1000, speed: 0, timestamp: 0)
        assertThat(streamCnt, `is`(6))
        assertThat(stream.position, `is`(1))

        // position update to same value should change nothing
        stream.streamPlaybackStateDidChange(backend.mockSdkCoreStream!,
                                            duration: 10000, position: 1000, speed: 0, timestamp: 0)
        assertThat(streamCnt, `is`(6))
        assertThat(stream.position, `is`(1))

        // seek to position
        _ = stream.seekTo(position: 2)
        assertThat(streamCnt, `is`(6))
        assertThat(stream.position, `is`(1))
        assertThat(backend.mockSdkCoreStream!.seekCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.seekPosition, `is`(2000))

        // unpublish the stream server
        assertThat(backend.mockSdkCoreStream!.closeCnt, `is`(0))
        impl.unpublish()
        assertThat(streamRef?.value, nilValue())

        // check that unreferencing the stream, removes the observer
        assertThat(stream.countListeners(), `is`(1))
        streamRef = nil
        assertThat(stream.countListeners(), `is`(0))
        assertThat(backend.mockSdkCoreStream!.closeCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.closeReason, presentAnd(`is`(.userRequested)))
    }

    func testMediaReplaySourceThermal() {
        impl = StreamServerCore(store: store!, backend: backend!)
        impl.publish()
        var cnt = 0
        let streamServer = store.get(Peripherals.streamServer)!
        _ = store.register(desc: Peripherals.streamServer) {
            cnt += 1
        }

        var streamCnt = 0
        var streamRef = streamServer.replay(
        source: MediaReplaySourceFactory.videoTrackOf(resource: mockRes, track: .thermalUnblended)) {_ in
            streamCnt += 1
        }

        assertThat(streamRef?.value, present())
        let stream = streamRef?.value! as! MediaReplayCore

        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(streamServer.enabled, `is`(false))
        assertThat(streamCnt, `is`(1))
        assertThat(stream, `is`(state: .stopped, playState: .none))
        assertThat(stream.position, `is`(0))
        assertThat(stream.duration, `is`(0))
        assertThat(stream.source.track, `is`(.thermalUnblended))
        assertThat(stream.source.mediaUid, `is`(nilValue()))
        assertThat(stream.source.resourceUid, `is`(mockRes.uid))
        assertThat(backend.openStreamCnt, `is`(0))
        assertThat(backend.mockSdkCoreStream, nilValue())

        // enable streaming
        streamServer.enabled = true
        assertThat(cnt, `is`(1))
        assertThat(streamServer.enabled, `is`(true))
        assertThat(streamCnt, `is`(1))
        assertThat(stream, `is`(state: .stopped, playState: .none))

        // play stream
        _ = stream.play()
        assertThat(streamCnt, `is`(2))
        assertThat(stream, `is`(state: .starting, playState: .none))
        assertThat(backend.openStreamCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream, present())
        assertThat(backend.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.playCnt, `is`(0))
        assertThat(backend.mockSdkCoreStream!.pauseCnt, `is`(0))

        // stream open notification from backend
        stream.streamDidOpen(backend.mockSdkCoreStream!)
        assertThat(streamCnt, `is`(3))
        assertThat(stream, `is`(state: .started, playState: .none))
        assertThat(backend.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.playCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.pauseCnt, `is`(0))

        // stream playing notification from backend
        stream.streamPlaybackStateDidChange(backend.mockSdkCoreStream!,
                                            duration: 1000, position: 0, speed: 1, timestamp: 0)
        assertThat(streamCnt, `is`(4))
        assertThat(stream, `is`(state: .started, playState: .playing))

        // play stream again should change nothing
        _ = stream.play()
        assertThat(streamCnt, `is`(4))
        assertThat(stream, `is`(state: .started, playState: .playing))
        assertThat(backend.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.playCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.pauseCnt, `is`(0))

        // stream playing notification from backend should change nothing
        stream.streamPlaybackStateDidChange(backend.mockSdkCoreStream!,
                                            duration: 1000, position: 0, speed: 1, timestamp: 0)
        assertThat(streamCnt, `is`(4))
        assertThat(stream, `is`(state: .started, playState: .playing))

        // pause stream
        _ = stream.pause()
        assertThat(streamCnt, `is`(4))
        assertThat(stream, `is`(state: .started, playState: .playing))
        assertThat(backend.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.playCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.pauseCnt, `is`(1))

        // stream paused notification from backend
        stream.streamPlaybackStateDidChange(backend.mockSdkCoreStream!,
                                            duration: 1000, position: 0, speed: 0, timestamp: 0)
        assertThat(streamCnt, `is`(5))
        assertThat(stream, `is`(state: .started, playState: .paused))

        // pause stream again should change nothing
        _ = stream.pause()
        assertThat(streamCnt, `is`(5))
        assertThat(stream, `is`(state: .started, playState: .paused))
        assertThat(backend.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.playCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.pauseCnt, `is`(1))

        // stream paused notification from backend should change nothing
        stream.streamPlaybackStateDidChange(backend.mockSdkCoreStream!,
                                            duration: 1000, position: 0, speed: 0, timestamp: 0)
        assertThat(streamCnt, `is`(5))
        assertThat(stream, `is`(state: .started, playState: .paused))

        // play stream
        _ = stream.play()
        assertThat(streamCnt, `is`(5))
        assertThat(stream, `is`(state: .started, playState: .paused))
        assertThat(backend.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.playCnt, `is`(2))
        assertThat(backend.mockSdkCoreStream!.pauseCnt, `is`(1))

        // duration update
        stream.streamPlaybackStateDidChange(backend.mockSdkCoreStream!,
                                            duration: 10000, position: 0, speed: 0, timestamp: 0)
        assertThat(streamCnt, `is`(6))
        assertThat(stream.duration, `is`(10))

        // duration update to same value should change nothing
        stream.streamPlaybackStateDidChange(backend.mockSdkCoreStream!,
                                            duration: 10000, position: 0, speed: 0, timestamp: 0)
        assertThat(streamCnt, `is`(6))
        assertThat(stream.duration, `is`(10))

        // position update, should not trigger a change notification
        stream.streamPlaybackStateDidChange(backend.mockSdkCoreStream!,
                                            duration: 10000, position: 1000, speed: 0, timestamp: 0)
        assertThat(streamCnt, `is`(6))
        assertThat(stream.position, `is`(1))

        // position update to same value should change nothing
        stream.streamPlaybackStateDidChange(backend.mockSdkCoreStream!,
                                            duration: 10000, position: 1000, speed: 0, timestamp: 0)
        assertThat(streamCnt, `is`(6))
        assertThat(stream.position, `is`(1))

        // seek to position
        _ = stream.seekTo(position: 2)
        assertThat(streamCnt, `is`(6))
        assertThat(stream.position, `is`(1))
        assertThat(backend.mockSdkCoreStream!.seekCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.seekPosition, `is`(2000))

        // unpublish the stream server
        assertThat(backend.mockSdkCoreStream!.closeCnt, `is`(0))
        impl.unpublish()
        assertThat(streamRef?.value, nilValue())

        // check that unreferencing the stream, removes the observer
        assertThat(stream.countListeners(), `is`(1))
        streamRef = nil
        assertThat(stream.countListeners(), `is`(0))
        assertThat(backend.mockSdkCoreStream!.closeCnt, `is`(1))
        assertThat(backend.mockSdkCoreStream!.closeReason, presentAnd(`is`(.userRequested)))
    }

    private class Backend: StreamServerBackend {

        var openStreamCnt = 0
        var mockSdkCoreStream: MockSdkCoreStream?

        func openStream(url: String, track: String, listener: SdkCoreStreamListener) -> SdkCoreStream? {
            openStreamCnt += 1
            mockSdkCoreStream = MockSdkCoreStream()
            mockSdkCoreStream?.open()
            return mockSdkCoreStream
        }
    }

    private class MockSdkCoreStream: SdkCoreStream {

        var openCnt = 0
        var closeReason: SdkCoreStreamCloseReason?
        var closeCnt = 0
        var playCnt = 0
        var pauseCnt = 0
        var seekCnt = 0
        var seekPosition: Int32?

        override func open() {
            openCnt += 1
        }

        override func close(_ reason: SdkCoreStreamCloseReason) {
            closeCnt += 1
            closeReason = reason
        }

        override func play() {
            playCnt += 1
        }

        override func pause() {
            pauseCnt += 1
        }

        override func seek(to position: Int32) {
            seekCnt += 1
            seekPosition = position
        }
    }
}
