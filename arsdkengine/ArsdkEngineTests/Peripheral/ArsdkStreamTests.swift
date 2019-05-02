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
import XCTest

@testable import ArsdkEngine
@testable import GroundSdk
import SdkCoreTesting

class ArsdkStreamTests: ArsdkEngineTestBase {

    var drone: DroneCore!
    var streamServer: StreamServer?
    var streamServerRef: Ref<StreamServer>?
    var changeCnt = 0

    var cameraLive1Ref: Ref<CameraLive>?
    var cameraLive1: CameraLive?
    var cameraLive1ChangeCnt = 0
    var cameraLive2Ref: Ref<CameraLive>?
    var cameraLive2: CameraLive?
    var cameraLive2ChangeCnt = 0
    var mediaReplay1Ref: Ref<MediaReplay>?
    var mediaReplay1: MediaReplay?
    var mediaReplay1ChangeCnt = 0
    var mediaReplay2Ref: Ref<MediaReplay>?
    var mediaReplay2: MediaReplay?
    var mediaReplay2ChangeCnt = 0

    let mockRes: MediaItem.Resource = MediaItemResourceCore(uid: "0", format: .mp4, size: 0,
                                                            duration: nil, streamUrl: "live",
                                                            location: nil, creationDate: Date())

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        streamServerRef = drone.getPeripheral(Peripherals.streamServer) { [unowned self] streamServer in
            self.streamServer = streamServer
            self.changeCnt += 1
        }
        changeCnt = 0
        cameraLive1ChangeCnt = 0
        cameraLive2ChangeCnt = 0
        mediaReplay1ChangeCnt = 0
        mediaReplay2ChangeCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected
        assertThat(streamServer, `is`(nilValue()))

        connect(drone: drone, handle: 1)
        assertThat(streamServer, `is`(present()))
        assertThat(changeCnt, `is`(1))

        disconnect(drone: drone, handle: 1)
        assertThat(streamServer, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testCameraLivePublishUnpublish() {
        connect(drone: drone, handle: 1)

        cameraLive1Ref = streamServer?.live { cameraLive in
            self.cameraLive1 = cameraLive
            self.cameraLive1ChangeCnt += 1
        }
        assertThat(cameraLive1ChangeCnt, `is`(1))
        assertThat(cameraLive1, `is`(present()))

        disconnect(drone: drone, handle: 1)
        assertThat(cameraLive1ChangeCnt, `is`(2))
        assertThat(cameraLive1, `is`(nilValue()))

        connect(drone: drone, handle: 1)

        cameraLive1ChangeCnt = 0
        cameraLive1Ref = streamServer?.live { cameraLive in
            self.cameraLive1 = cameraLive
            self.cameraLive1ChangeCnt += 1
        }
        assertThat(cameraLive1ChangeCnt, `is`(1))
        assertThat(cameraLive1, `is`(present()))

        disconnect(drone: drone, handle: 1)
        assertThat(cameraLive1ChangeCnt, `is`(2))
        assertThat(cameraLive1, `is`(nilValue()))
    }

    func testCameraLive() {
        connect(drone: drone, handle: 1)

        cameraLive1Ref = streamServer?.live { stream in
            self.cameraLive1 = stream
            self.cameraLive1ChangeCnt += 1
        }
        cameraLive2Ref = streamServer?.live { stream in
            self.cameraLive2 = stream
            self.cameraLive2ChangeCnt += 1
        }

        // check default values
        assertThat(changeCnt, `is`(1))
        assertThat(cameraLive1ChangeCnt, `is`(1))
        assertThat(cameraLive2ChangeCnt, `is`(1))
        assertThat(cameraLive1, `is`(present()))
        assertThat(cameraLive1!, `is`(state: .stopped, playState: .none))
        assertThat(cameraLive2, `is`(present()))
        assertThat(cameraLive2!, `is`(state: .stopped, playState: .none))

        // request camera live stream play
        _ = expectStreamCreate(handle: 1)
        _ = cameraLive1?.play()
        assertThat(cameraLive1ChangeCnt, `is`(2))
        assertThat(cameraLive2ChangeCnt, `is`(2))
        assertThat(cameraLive1!, `is`(state: .starting, playState: .none))
        assertThat(cameraLive2!, `is`(state: .starting, playState: .none))
        let mockStream = mockArsdkCore.getVideoStream()
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 0, pauseCnt: 0, closeCnt: 0))

        // stream open notification from backend
        mockStream?.mockStreamOpen()
        assertThat(cameraLive1ChangeCnt, `is`(3))
        assertThat(cameraLive2ChangeCnt, `is`(3))
        assertThat(cameraLive1!, `is`(state: .started, playState: .none))
        assertThat(cameraLive2!, `is`(state: .started, playState: .none))
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 0))

        // stream play notification from backend
        mockStream?.mockStreamPlayState(10000, position: 0, speed: 1, timestamp: 0)
        assertThat(cameraLive1ChangeCnt, `is`(4))
        assertThat(cameraLive2ChangeCnt, `is`(4))
        assertThat(cameraLive1!, `is`(state: .started, playState: .playing))
        assertThat(cameraLive2!, `is`(state: .started, playState: .playing))
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 0))

        // request stream pause
        _ = cameraLive1?.pause()
        assertThat(cameraLive1ChangeCnt, `is`(4))
        assertThat(cameraLive2ChangeCnt, `is`(4))
        assertThat(cameraLive1!, `is`(state: .started, playState: .playing))
        assertThat(cameraLive2!, `is`(state: .started, playState: .playing))
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 1, closeCnt: 0))

        // stream pause notification from backend
        mockStream?.mockStreamPlayState(10000, position: 0, speed: 0, timestamp: 0)
        assertThat(cameraLive1ChangeCnt, `is`(5))
        assertThat(cameraLive2ChangeCnt, `is`(5))
        assertThat(cameraLive1!, `is`(state: .started, playState: .paused))
        assertThat(cameraLive2!, `is`(state: .started, playState: .paused))
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 1, closeCnt: 0))

        // request stream play
        _ = cameraLive1?.play()
        assertThat(cameraLive1ChangeCnt, `is`(5))
        assertThat(cameraLive2ChangeCnt, `is`(5))
        assertThat(cameraLive1!, `is`(state: .started, playState: .paused))
        assertThat(cameraLive2!, `is`(state: .started, playState: .paused))
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 2, pauseCnt: 1, closeCnt: 0))

        // stream play notification from backend
        mockStream?.mockStreamPlayState(10000, position: 0, speed: 1, timestamp: 0)
        assertThat(cameraLive1ChangeCnt, `is`(6))
        assertThat(cameraLive2ChangeCnt, `is`(6))
        assertThat(cameraLive1!, `is`(state: .started, playState: .playing))
        assertThat(cameraLive2!, `is`(state: .started, playState: .playing))
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 2, pauseCnt: 1, closeCnt: 0))

        // request stream stop
        cameraLive1?.stop()
        assertThat(cameraLive1ChangeCnt, `is`(7))
        assertThat(cameraLive2ChangeCnt, `is`(7))
        assertThat(cameraLive1!, `is`(state: .stopped, playState: .none))
        assertThat(cameraLive2!, `is`(state: .stopped, playState: .none))
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 2, pauseCnt: 1, closeCnt: 1))

        // stream closing and close notification from backend
        mockStream?.mockStreamClosing(.userRequested)
        mockStream?.mockStreamClose(.userRequested)
        assertThat(cameraLive1ChangeCnt, `is`(7))
        assertThat(cameraLive2ChangeCnt, `is`(7))
        assertThat(cameraLive1!, `is`(state: .stopped, playState: .none))
        assertThat(cameraLive2!, `is`(state: .stopped, playState: .none))
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 2, pauseCnt: 1, closeCnt: 1))
    }

    func testCameraLiveEnable() {
        connect(drone: drone, handle: 1)

        cameraLive1Ref = streamServer?.live { stream in
            self.cameraLive1 = stream
            self.cameraLive1ChangeCnt += 1
        }

        // check default values
        assertThat(changeCnt, `is`(1))
        assertThat(streamServer!, `is`(enabled: true))
        assertThat(cameraLive1ChangeCnt, `is`(1))
        assertThat(cameraLive1, `is`(present()))
        assertThat(cameraLive1!, `is`(state: .stopped, playState: .none))

        // request camera live stream play
        _ = expectStreamCreate(handle: 1)
        _ = cameraLive1?.play()
        assertThat(cameraLive1ChangeCnt, `is`(2))
        assertThat(cameraLive1!, `is`(state: .starting, playState: .none))
        var mockStream = mockArsdkCore.getVideoStream()
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 0, pauseCnt: 0, closeCnt: 0))

        // stream open notification from backend
        mockStream?.mockStreamOpen()
        assertThat(cameraLive1ChangeCnt, `is`(3))
        assertThat(cameraLive1!, `is`(state: .started, playState: .none))
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 0))

        // stream play notification from backend
        mockStream?.mockStreamPlayState(10000, position: 0, speed: 1, timestamp: 0)
        assertThat(cameraLive1ChangeCnt, `is`(4))
        assertThat(cameraLive1!, `is`(state: .started, playState: .playing))
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 0))

        // disable streaming
        streamServer?.enabled = false
        assertThat(changeCnt, `is`(2))
        assertThat(streamServer!, `is`(enabled: false))
        assertThat(cameraLive1ChangeCnt, `is`(5))
        assertThat(cameraLive1!, `is`(state: .suspended, playState: .playing))
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 1))

        // stream closing notification from backend
        mockStream?.mockStreamClosing(.interrupted)
        assertThat(changeCnt, `is`(2))
        assertThat(cameraLive1ChangeCnt, `is`(5))
        assertThat(cameraLive1!, `is`(state: .suspended, playState: .playing))
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 1))

        // stream close notification from backend
        mockStream?.mockStreamClose(.interrupted)
        assertThat(changeCnt, `is`(2))
        assertThat(cameraLive1ChangeCnt, `is`(5))
        assertThat(cameraLive1!, `is`(state: .suspended, playState: .playing))
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 1))

        // request stream pause while streaming in disabled
        _ = cameraLive1?.pause()
        assertThat(changeCnt, `is`(2))
        assertThat(cameraLive1ChangeCnt, `is`(6))
        assertThat(cameraLive1!, `is`(state: .suspended, playState: .paused))
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 1))

        // request stream play while streaming in disabled
        _ = cameraLive1?.play()
        assertThat(changeCnt, `is`(2))
        assertThat(cameraLive1ChangeCnt, `is`(7))
        assertThat(cameraLive1!, `is`(state: .suspended, playState: .playing))
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 1))

        // enable streaming
        _ = expectStreamCreate(handle: 1)
        streamServer?.enabled = true
        assertThat(changeCnt, `is`(3))
        assertThat(streamServer!, `is`(enabled: true))
        assertThat(cameraLive1ChangeCnt, `is`(8))
        assertThat(cameraLive1!, `is`(state: .starting, playState: .playing))
        mockStream = mockArsdkCore.getVideoStream()
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 0, pauseCnt: 0, closeCnt: 0))

        // stream open notification from backend
        mockStream?.mockStreamOpen()
        assertThat(cameraLive1ChangeCnt, `is`(9))
        assertThat(cameraLive1!, `is`(state: .started, playState: .playing))
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 0))
    }

    func testMediaReplayPublishUnpublish() {
        connect(drone: drone, handle: 1)

        mediaReplay1Ref = streamServer?.replay(source: MediaReplaySourceFactory.videoTrackOf(resource: mockRes,
                                                                                    track: .defaultVideo)) { stream in
            self.mediaReplay1 = stream
            self.mediaReplay1ChangeCnt += 1
        }
        assertThat(mediaReplay1ChangeCnt, `is`(1))
        assertThat(mediaReplay1, `is`(present()))

        disconnect(drone: drone, handle: 1)
        assertThat(mediaReplay1ChangeCnt, `is`(2))
        assertThat(mediaReplay1, `is`(nilValue()))
    }

    func testMediaReplay() {
        connect(drone: drone, handle: 1)

        mediaReplay1Ref = streamServer?.replay(source: MediaReplaySourceFactory.videoTrackOf(resource: mockRes,
                                                                                    track: .defaultVideo)) { stream in
            self.mediaReplay1 = stream
            self.mediaReplay1ChangeCnt += 1
        }
        mediaReplay2Ref = streamServer?.replay(source: MediaReplaySourceFactory.videoTrackOf(resource: mockRes,
                                                                                    track: .defaultVideo)) { stream in
            self.mediaReplay2 = stream
            self.mediaReplay2ChangeCnt += 1
        }

        // check default values
        assertThat(changeCnt, `is`(1))
        assertThat(mediaReplay1ChangeCnt, `is`(1))
        assertThat(mediaReplay2ChangeCnt, `is`(1))
        assertThat(mediaReplay1, `is`(present()))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        assertThat(mediaReplay2, `is`(present()))
        assertThat(mediaReplay2!, `is`(state: .stopped, playState: .none))

        // request media replay stream 1 play
        _ = expectStreamCreate(handle: 1)
        _ = mediaReplay1?.play()
        assertThat(mediaReplay1ChangeCnt, `is`(2))
        assertThat(mediaReplay2ChangeCnt, `is`(1))
        assertThat(mediaReplay1!, `is`(state: .starting, playState: .none))
        assertThat(mediaReplay2!, `is`(state: .stopped, playState: .none))
        let mockStream1 = mockArsdkCore.getVideoStream()
        assertThat(mockStream1!, `is`(openCnt: 1, playCnt: 0, pauseCnt: 0, closeCnt: 0))

        // stream 1 open notification from backend
        mockStream1?.mockStreamOpen()
        assertThat(mediaReplay1ChangeCnt, `is`(3))
        assertThat(mediaReplay2ChangeCnt, `is`(1))
        assertThat(mediaReplay1!, `is`(state: .started, playState: .none))
        assertThat(mediaReplay2!, `is`(state: .stopped, playState: .none))
        assertThat(mockStream1!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 0))

        // stream 1 play notification from backend
        mockStream1?.mockStreamPlayState(10000, position: 0, speed: 1, timestamp: 0)
        assertThat(mediaReplay1ChangeCnt, `is`(4))
        assertThat(mediaReplay2ChangeCnt, `is`(1))
        assertThat(mediaReplay1!, `is`(state: .started, playState: .playing))
        assertThat(mediaReplay2!, `is`(state: .stopped, playState: .none))
        assertThat(mockStream1!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 0))

        // request media replay stream 2 play
        _ = expectStreamCreate(handle: 1)
        _ = mediaReplay2?.play()
        assertThat(mediaReplay1ChangeCnt, `is`(4))
        assertThat(mediaReplay2ChangeCnt, `is`(2))
        assertThat(mediaReplay1!, `is`(state: .started, playState: .playing))
        assertThat(mediaReplay2!, `is`(state: .starting, playState: .none))
        let mockStream2 = mockArsdkCore.getVideoStream()
        assertThat(mockStream1!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 1))
        assertThat(mockStream2!, `is`(openCnt: 0, playCnt: 0, pauseCnt: 0, closeCnt: 0))

        // stream 1 closing notification from backend
        mockStream1?.mockStreamClosing(.userRequested)
        assertThat(mediaReplay1ChangeCnt, `is`(5))
        assertThat(mediaReplay2ChangeCnt, `is`(2))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        assertThat(mediaReplay2!, `is`(state: .starting, playState: .none))
        assertThat(mockStream1!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 1))
        assertThat(mockStream2!, `is`(openCnt: 0, playCnt: 0, pauseCnt: 0, closeCnt: 0))

        // stream 1 close notification from backend
        mockStream1?.mockStreamClose(.userRequested)
        assertThat(mediaReplay1ChangeCnt, `is`(5))
        assertThat(mediaReplay2ChangeCnt, `is`(2))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        assertThat(mediaReplay2!, `is`(state: .starting, playState: .none))
        assertThat(mockStream1!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 1))
        assertThat(mockStream2!, `is`(openCnt: 1, playCnt: 0, pauseCnt: 0, closeCnt: 0))

        // stream 2 open notification from backend
        mockStream2?.mockStreamOpen()
        assertThat(mediaReplay1ChangeCnt, `is`(5))
        assertThat(mediaReplay2ChangeCnt, `is`(3))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        assertThat(mediaReplay2!, `is`(state: .started, playState: .none))
        assertThat(mockStream2!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 0))

        // stream 2 play notification from backend
        mockStream2?.mockStreamPlayState(10000, position: 0, speed: 1, timestamp: 0)
        assertThat(mediaReplay1ChangeCnt, `is`(5))
        assertThat(mediaReplay2ChangeCnt, `is`(4))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        assertThat(mediaReplay2!, `is`(state: .started, playState: .playing))
        assertThat(mockStream2!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 0))

        // request media replay stream 2 pause
        _ = mediaReplay2?.pause()
        assertThat(mediaReplay1ChangeCnt, `is`(5))
        assertThat(mediaReplay2ChangeCnt, `is`(4))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        assertThat(mediaReplay2!, `is`(state: .started, playState: .playing))
        assertThat(mockStream2!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 1, closeCnt: 0))

        // stream 2 pause notification from backend
        mockStream2?.mockStreamPlayState(10000, position: 0, speed: 0, timestamp: 0)
        assertThat(mediaReplay1ChangeCnt, `is`(5))
        assertThat(mediaReplay2ChangeCnt, `is`(5))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        assertThat(mediaReplay2!, `is`(state: .started, playState: .paused))
        assertThat(mockStream2!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 1, closeCnt: 0))

        // request media replay stream 2 play
        _ = mediaReplay2?.play()
        assertThat(mediaReplay1ChangeCnt, `is`(5))
        assertThat(mediaReplay2ChangeCnt, `is`(5))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        assertThat(mediaReplay2!, `is`(state: .started, playState: .paused))
        assertThat(mockStream2!, `is`(openCnt: 1, playCnt: 2, pauseCnt: 1, closeCnt: 0))

        // stream 2 play notification from backend
        mockStream2?.mockStreamPlayState(10000, position: 0, speed: 1, timestamp: 0)
        assertThat(mediaReplay1ChangeCnt, `is`(5))
        assertThat(mediaReplay2ChangeCnt, `is`(6))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        assertThat(mediaReplay2!, `is`(state: .started, playState: .playing))
        assertThat(mockStream2!, `is`(openCnt: 1, playCnt: 2, pauseCnt: 1, closeCnt: 0))

        // request media replay stream 2 stop
        mediaReplay2?.stop()
        assertThat(mediaReplay1ChangeCnt, `is`(5))
        assertThat(mediaReplay2ChangeCnt, `is`(7))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        assertThat(mediaReplay2!, `is`(state: .stopped, playState: .none))
        assertThat(mockStream2!, `is`(openCnt: 1, playCnt: 2, pauseCnt: 1, closeCnt: 1))

        // stream 2 closing and close notifications from backend
        mockStream2?.mockStreamClosing(.userRequested)
        mockStream2?.mockStreamClose(.userRequested)
        assertThat(mediaReplay1ChangeCnt, `is`(5))
        assertThat(mediaReplay2ChangeCnt, `is`(7))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        assertThat(mediaReplay2!, `is`(state: .stopped, playState: .none))
        assertThat(mockStream2!, `is`(openCnt: 1, playCnt: 2, pauseCnt: 1, closeCnt: 1))
    }

    func testMediaReplayTime() {
        connect(drone: drone, handle: 1)

        mediaReplay1Ref = streamServer?.replay(source: MediaReplaySourceFactory.videoTrackOf(resource: mockRes,
                                                                                    track: .defaultVideo)) { stream in
            self.mediaReplay1 = stream
            self.mediaReplay1ChangeCnt += 1
        }

        // check default values
        assertThat(changeCnt, `is`(1))
        assertThat(mediaReplay1ChangeCnt, `is`(1))
        assertThat(mediaReplay1, `is`(present()))
        assertThat(mediaReplay1!.duration, `is`(0))
        assertThat(mediaReplay1!.position, `is`(0))

        // play stream
        _ = expectStreamCreate(handle: 1)
        _ = mediaReplay1?.play()
        assertThat(mediaReplay1ChangeCnt, `is`(2))

        // stream duration notification from backend
        let mockStream = mockArsdkCore.getVideoStream()
        mockStream?.mockStreamPlayState(10000, position: 0, speed: 0, timestamp: 0)
        assertThat(mediaReplay1ChangeCnt, `is`(3))
        assertThat(mediaReplay1!.duration, `is`(10))
        assertThat(mediaReplay1!.position, `is`(0))

        // stream position notification from backend
        mockStream?.mockStreamPlayState(10000, position: 1000, speed: 0, timestamp: 0)
        assertThat(mediaReplay1ChangeCnt, `is`(3)) // no notification for position change
        assertThat(mediaReplay1!.duration, `is`(10))
        assertThat(mediaReplay1!.position, `is`(1))

        // seek to time position
        _ = mediaReplay1?.seekTo(position: 2000)
        assertThat(mediaReplay1ChangeCnt, `is`(3))
        assertThat(mediaReplay1!.duration, `is`(10))
        assertThat(mediaReplay1!.position, `is`(1))

        // stream position notification from backend
        mockStream?.mockStreamPlayState(10000, position: 2000, speed: 0, timestamp: 0)
        assertThat(mediaReplay1ChangeCnt, `is`(3)) // no notification for position change
        assertThat(mediaReplay1!.duration, `is`(10))
        assertThat(mediaReplay1!.position, `is`(2))
    }

    func testMediaReplayEnable() {
        connect(drone: drone, handle: 1)

        mediaReplay1Ref = streamServer?.replay(source: MediaReplaySourceFactory.videoTrackOf(resource: mockRes,
                                                                                    track: .defaultVideo)) { stream in
            self.mediaReplay1 = stream
            self.mediaReplay1ChangeCnt += 1
        }

        // check default values
        assertThat(changeCnt, `is`(1))
        assertThat(streamServer!, `is`(enabled: true))
        assertThat(mediaReplay1ChangeCnt, `is`(1))
        assertThat(mediaReplay1, `is`(present()))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))

        // request media replay stream 1 play
        _ = expectStreamCreate(handle: 1)
        _ = mediaReplay1?.play()
        assertThat(mediaReplay1ChangeCnt, `is`(2))
        assertThat(mediaReplay1!, `is`(state: .starting, playState: .none))
        let mockStream = mockArsdkCore.getVideoStream()
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 0, pauseCnt: 0, closeCnt: 0))

        // stream 1 open notification from backend
        mockStream?.mockStreamOpen()
        assertThat(mediaReplay1ChangeCnt, `is`(3))
        assertThat(mediaReplay1!, `is`(state: .started, playState: .none))
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 0))

        // stream 1 play notification from backend
        mockStream?.mockStreamPlayState(10000, position: 0, speed: 1, timestamp: 0)
        assertThat(mediaReplay1ChangeCnt, `is`(4))
        assertThat(mediaReplay1!, `is`(state: .started, playState: .playing))
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 0))

        // disable streaming
        streamServer?.enabled = false
        assertThat(changeCnt, `is`(2))
        assertThat(streamServer!, `is`(enabled: false))
        assertThat(mediaReplay1ChangeCnt, `is`(5))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 1))

        // stream closing and close notifications from backend
        mockStream?.mockStreamClosing(.interrupted)
        mockStream?.mockStreamClose(.interrupted)
        assertThat(changeCnt, `is`(2))
        assertThat(mediaReplay1ChangeCnt, `is`(5))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 1))

        // request media replay stream play, nothing should change
        _ = mediaReplay1?.play()
        assertThat(changeCnt, `is`(2))
        assertThat(mediaReplay1ChangeCnt, `is`(5))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        assertThat(mockStream!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 1))

        // enable streaming
        streamServer?.enabled = true
        assertThat(streamServer!, `is`(enabled: true))
        assertThat(changeCnt, `is`(3))
        assertThat(mediaReplay1ChangeCnt, `is`(5))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
    }

    func testCameraLiveAndMediaReplay() {
        connect(drone: drone, handle: 1)

        cameraLive1Ref = streamServer?.live { stream in
            self.cameraLive1 = stream
            self.cameraLive1ChangeCnt += 1
        }
        mediaReplay1Ref = streamServer?.replay(source: MediaReplaySourceFactory.videoTrackOf(resource: mockRes,
                                                                                    track: .defaultVideo)) { stream in
            self.mediaReplay1 = stream
            self.mediaReplay1ChangeCnt += 1
        }

        // check default values
        assertThat(changeCnt, `is`(1))
        assertThat(cameraLive1ChangeCnt, `is`(1))
        assertThat(mediaReplay1ChangeCnt, `is`(1))
        assertThat(cameraLive1, `is`(present()))
        assertThat(cameraLive1!, `is`(state: .stopped, playState: .none))
        assertThat(mediaReplay1, `is`(present()))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))

        // request camera live stream play
        _ = expectStreamCreate(handle: 1)
        _ = cameraLive1?.play()
        assertThat(cameraLive1ChangeCnt, `is`(2))
        assertThat(mediaReplay1ChangeCnt, `is`(1))
        assertThat(cameraLive1!, `is`(state: .starting, playState: .none))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        var mockStream1 = mockArsdkCore.getVideoStream()
        assertThat(mockStream1!, `is`(openCnt: 1, playCnt: 0, pauseCnt: 0, closeCnt: 0))

        // camera live stream open notification from backend
        mockStream1?.mockStreamOpen()
        assertThat(cameraLive1ChangeCnt, `is`(3))
        assertThat(mediaReplay1ChangeCnt, `is`(1))
        assertThat(cameraLive1!, `is`(state: .started, playState: .none))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        assertThat(mockStream1!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 0))

        // camera live stream play notification from backend
        mockStream1?.mockStreamPlayState(10000, position: 0, speed: 1, timestamp: 0)
        assertThat(cameraLive1ChangeCnt, `is`(4))
        assertThat(mediaReplay1ChangeCnt, `is`(1))
        assertThat(cameraLive1!, `is`(state: .started, playState: .playing))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        assertThat(mockStream1!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 0))

        // request media replay stream play
        _ = expectStreamCreate(handle: 1)
        _ = mediaReplay1?.play()
        assertThat(cameraLive1ChangeCnt, `is`(4))
        assertThat(mediaReplay1ChangeCnt, `is`(2))
        assertThat(cameraLive1!, `is`(state: .started, playState: .playing))
        assertThat(mediaReplay1!, `is`(state: .starting, playState: .none))
        assertThat(mockStream1!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 1))
        let mockStream2 = mockArsdkCore.getVideoStream()
        assertThat(mockStream2!, `is`(openCnt: 0, playCnt: 0, pauseCnt: 0, closeCnt: 0))

        // camera live stream closing notification from backend
        mockStream1?.mockStreamClosing(.interrupted)
        assertThat(cameraLive1ChangeCnt, `is`(5))
        assertThat(mediaReplay1ChangeCnt, `is`(2))
        assertThat(cameraLive1!, `is`(state: .suspended, playState: .playing))
        assertThat(mediaReplay1!, `is`(state: .starting, playState: .none))
        assertThat(mockStream1!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 1))
        assertThat(mockStream2!, `is`(openCnt: 0, playCnt: 0, pauseCnt: 0, closeCnt: 0))

        // camera live stream close notification from backend
        mockStream1?.mockStreamClose(.interrupted)
        assertThat(cameraLive1ChangeCnt, `is`(5))
        assertThat(mediaReplay1ChangeCnt, `is`(2))
        assertThat(cameraLive1!, `is`(state: .suspended, playState: .playing))
        assertThat(mediaReplay1!, `is`(state: .starting, playState: .none))
        assertThat(mockStream1!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 1))
        assertThat(mockStream2!, `is`(openCnt: 1, playCnt: 0, pauseCnt: 0, closeCnt: 0))

        // media replay stream open notification from backend
        mockStream2?.mockStreamOpen()
        assertThat(cameraLive1ChangeCnt, `is`(5))
        assertThat(mediaReplay1ChangeCnt, `is`(3))
        assertThat(cameraLive1!, `is`(state: .suspended, playState: .playing))
        assertThat(mediaReplay1!, `is`(state: .started, playState: .none))
        assertThat(mockStream2!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 0))

        // media replay stream play notification from backend
        mockStream2?.mockStreamPlayState(10000, position: 0, speed: 1, timestamp: 0)
        assertThat(cameraLive1ChangeCnt, `is`(5))
        assertThat(mediaReplay1ChangeCnt, `is`(4))
        assertThat(cameraLive1!, `is`(state: .suspended, playState: .playing))
        assertThat(mediaReplay1!, `is`(state: .started, playState: .playing))
        assertThat(mockStream2!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 0))

        // request media replay stream stop
        _ = expectStreamCreate(handle: 1)
        mediaReplay1?.stop()
        assertThat(cameraLive1ChangeCnt, `is`(6))
        assertThat(mediaReplay1ChangeCnt, `is`(5))
        assertThat(cameraLive1!, `is`(state: .starting, playState: .playing))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        assertThat(mockStream2!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 2))  // TODO closeCnt should be 1

        // media replay stream closing notification from backend
        mockStream2?.mockStreamClosing(.userRequested)
        assertThat(cameraLive1ChangeCnt, `is`(6))
        assertThat(mediaReplay1ChangeCnt, `is`(5))
        assertThat(cameraLive1!, `is`(state: .starting, playState: .playing))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        mockStream1 = mockArsdkCore.getVideoStream()
        assertThat(mockStream1!, `is`(openCnt: 0, playCnt: 0, pauseCnt: 0, closeCnt: 0))
        assertThat(mockStream2!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 2))

        // media replay stream close notification from backend
        mockStream2?.mockStreamClose(.userRequested)
        assertThat(cameraLive1ChangeCnt, `is`(6))
        assertThat(mediaReplay1ChangeCnt, `is`(5))
        assertThat(cameraLive1!, `is`(state: .starting, playState: .playing))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        assertThat(mockStream1!, `is`(openCnt: 1, playCnt: 0, pauseCnt: 0, closeCnt: 0))
        assertThat(mockStream2!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 2))

        // camera live stream open notification from backend
        mockStream1?.mockStreamOpen()
        assertThat(cameraLive1ChangeCnt, `is`(7))
        assertThat(mediaReplay1ChangeCnt, `is`(5))
        assertThat(cameraLive1!, `is`(state: .started, playState: .playing))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        assertThat(mockStream1!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 0))

        // camera live stream play notification from backend
        mockStream1?.mockStreamPlayState(10000, position: 0, speed: 1, timestamp: 0)
        assertThat(cameraLive1ChangeCnt, `is`(7))
        assertThat(mediaReplay1ChangeCnt, `is`(5))
        assertThat(cameraLive1!, `is`(state: .started, playState: .playing))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        assertThat(mockStream1!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 0))

        // request camera live stream stop
        cameraLive1?.stop()
        assertThat(cameraLive1ChangeCnt, `is`(8))
        assertThat(mediaReplay1ChangeCnt, `is`(5))
        assertThat(cameraLive1!, `is`(state: .stopped, playState: .none))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        assertThat(mockStream1!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 1))

        // camera live stream closing and close notifications from backend
        mockStream1?.mockStreamClosing(.userRequested)
        mockStream1?.mockStreamClose(.userRequested)
        assertThat(cameraLive1ChangeCnt, `is`(8))
        assertThat(mediaReplay1ChangeCnt, `is`(5))
        assertThat(cameraLive1!, `is`(state: .stopped, playState: .none))
        assertThat(mediaReplay1!, `is`(state: .stopped, playState: .none))
        assertThat(mockStream1!, `is`(openCnt: 1, playCnt: 1, pauseCnt: 0, closeCnt: 1))
    }
}
