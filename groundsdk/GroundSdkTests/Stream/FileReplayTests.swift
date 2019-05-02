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

/// Test FileReplay
class FileReplayTests: XCTestCase {

    func testMediaReplay() {
        let url = URL(fileURLWithPath: "/mock/url")

        let stream = MockFileReplayCore(source: FileReplayFactory.videoTrackOf(file: url,
                                                                               track: .defaultVideo))
        var streamCnt = 0
        var streamRef: FileReplayRefCore?
        streamRef = FileReplayRefCore(stream: stream) {_ in
            streamCnt += 1
        }

        // test initial value
        assertThat(streamRef?.value, present())
        assertThat(streamCnt, `is`(1))
        assertThat(stream.source.file, `is`(url))
        assertThat(stream, `is`(state: .stopped, playState: .none))
        assertThat(stream.position, `is`(0))
        assertThat(stream.duration, `is`(0))
        assertThat(stream.createStreamCnt, `is`(0))
        assertThat(stream.mockSdkCoreStream, nilValue())

        // play stream
        _ = stream.play()
        assertThat(streamCnt, `is`(2))
        assertThat(stream, `is`(state: .starting, playState: .none))
        assertThat(stream.createStreamCnt, `is`(1))
        assertThat(stream.mockSdkCoreStream, present())
        assertThat(stream.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(stream.mockSdkCoreStream!.playCnt, `is`(0))
        assertThat(stream.mockSdkCoreStream!.pauseCnt, `is`(0))

        // stream open notification from backend
        stream.streamDidOpen(stream.mockSdkCoreStream!)
        assertThat(streamCnt, `is`(3))
        assertThat(stream, `is`(state: .started, playState: .none))
        assertThat(stream.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(stream.mockSdkCoreStream!.playCnt, `is`(1))
        assertThat(stream.mockSdkCoreStream!.pauseCnt, `is`(0))

        // stream playing notification from backend
        stream.streamPlaybackStateDidChange(stream.mockSdkCoreStream!,
                                            duration: 1000, position: 0, speed: 1, timestamp: 0)
        assertThat(streamCnt, `is`(4))
        assertThat(stream, `is`(state: .started, playState: .playing))

        // play stream again should change nothing
        _ = stream.play()
        assertThat(streamCnt, `is`(4))
        assertThat(stream, `is`(state: .started, playState: .playing))
        assertThat(stream.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(stream.mockSdkCoreStream!.playCnt, `is`(1))
        assertThat(stream.mockSdkCoreStream!.pauseCnt, `is`(0))

        // stream playing notification from backend should change nothing
        stream.streamPlaybackStateDidChange(stream.mockSdkCoreStream!,
                                            duration: 1000, position: 0, speed: 1, timestamp: 0)
        assertThat(streamCnt, `is`(4))
        assertThat(stream, `is`(state: .started, playState: .playing))

        // pause stream
        _ = stream.pause()
        assertThat(streamCnt, `is`(4))
        assertThat(stream, `is`(state: .started, playState: .playing))
        assertThat(stream.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(stream.mockSdkCoreStream!.playCnt, `is`(1))
        assertThat(stream.mockSdkCoreStream!.pauseCnt, `is`(1))

        // stream paused notification from backend
        stream.streamPlaybackStateDidChange(stream.mockSdkCoreStream!,
                                            duration: 1000, position: 0, speed: 0, timestamp: 0)
        assertThat(streamCnt, `is`(5))
        assertThat(stream, `is`(state: .started, playState: .paused))

        // pause stream again should change nothing
        _ = stream.pause()
        assertThat(streamCnt, `is`(5))
        assertThat(stream, `is`(state: .started, playState: .paused))
        assertThat(stream.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(stream.mockSdkCoreStream!.playCnt, `is`(1))
        assertThat(stream.mockSdkCoreStream!.pauseCnt, `is`(1))

        // stream paused notification from backend should change nothing
        stream.streamPlaybackStateDidChange(stream.mockSdkCoreStream!,
                                            duration: 1000, position: 0, speed: 0, timestamp: 0)
        assertThat(streamCnt, `is`(5))
        assertThat(stream, `is`(state: .started, playState: .paused))

        // play stream
        _ = stream.play()
        assertThat(streamCnt, `is`(5))
        assertThat(stream, `is`(state: .started, playState: .paused))
        assertThat(stream.mockSdkCoreStream!.openCnt, `is`(1))
        assertThat(stream.mockSdkCoreStream!.playCnt, `is`(2))
        assertThat(stream.mockSdkCoreStream!.pauseCnt, `is`(1))

        // duration update
        stream.streamPlaybackStateDidChange(stream.mockSdkCoreStream!,
                                            duration: 10000, position: 0, speed: 0, timestamp: 0)
        assertThat(streamCnt, `is`(6))
        assertThat(stream.duration, `is`(10))

        // duration update to same value should change nothing
        stream.streamPlaybackStateDidChange(stream.mockSdkCoreStream!,
                                            duration: 10000, position: 0, speed: 0, timestamp: 0)
        assertThat(streamCnt, `is`(6))
        assertThat(stream.duration, `is`(10))

        // position update, should not trigger a change notification
        stream.streamPlaybackStateDidChange(stream.mockSdkCoreStream!,
                                            duration: 10000, position: 1000, speed: 0, timestamp: 0)
        assertThat(streamCnt, `is`(6))
        assertThat(stream.position, `is`(1))

        // position update to same value should change nothing
        stream.streamPlaybackStateDidChange(stream.mockSdkCoreStream!,
                                            duration: 10000, position: 1000, speed: 0, timestamp: 0)
        assertThat(streamCnt, `is`(6))
        assertThat(stream.position, `is`(1))

        // seek to position
        _ = stream.seekTo(position: 2)
        assertThat(streamCnt, `is`(6))
        assertThat(stream.position, `is`(1))
        assertThat(stream.mockSdkCoreStream!.seekCnt, `is`(1))
        assertThat(stream.mockSdkCoreStream!.seekPosition, `is`(2000))

        // check that unreferencing the stream, removes the observer
        assertThat(stream.countListeners(), `is`(1))
        assertThat(stream.mockSdkCoreStream!.closeCnt, `is`(0))
        streamRef = nil
        assertThat(stream.countListeners(), `is`(0))
        assertThat(stream.mockSdkCoreStream!.closeCnt, `is`(1))
        assertThat(stream.mockSdkCoreStream!.closeReason, presentAnd(`is`(.userRequested)))
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

    private class MockFileReplayCore: FileReplayCore {

        var createStreamCnt = 0
        var mockSdkCoreStream: MockSdkCoreStream?

        override func createSdkCoreStream(pompLoopUtil: PompLoopUtil,
                                          source: SdkCoreFileSource,
                                          listener: SdkCoreStreamListener) -> SdkCoreStream {
            createStreamCnt += 1
            mockSdkCoreStream = MockSdkCoreStream()
            return mockSdkCoreStream!
        }
    }
}
