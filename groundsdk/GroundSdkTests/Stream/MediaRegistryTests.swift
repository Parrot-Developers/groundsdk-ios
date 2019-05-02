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

/// Test MediaRegistry
class MediaRegistryTests: XCTestCase {

    func testMediaRegistry() {
        let mediaRegistry = MediaRegistry()
        let yuvListener = YuvMediaListener()
        let h264Listener = H264MediaListener()

        let yuvMedia1 = SdkCoreYuvInfo(mediaId: 0)
        let yuvMedia2 = SdkCoreYuvInfo(mediaId: 1)
        let h264Media1 = SdkCoreH264Info(mediaId: 2)
        let h264Media2 = SdkCoreH264Info(mediaId: 3)

        assertThat(yuvListener.onMediaAvailableCount, `is`(0))
        assertThat(yuvListener.onMediaUnavailableCount, `is`(0))
        assertThat(h264Listener.onMediaAvailableCount, `is`(0))
        assertThat(h264Listener.onMediaUnavailableCount, `is`(0))

        // register YUV listener
        mediaRegistry.registerListener(listener: yuvListener, mediaType: .yuv)
        assertThat(yuvListener.onMediaAvailableCount, `is`(0))
        assertThat(yuvListener.onMediaUnavailableCount, `is`(0))
        assertThat(h264Listener.onMediaAvailableCount, `is`(0))
        assertThat(h264Listener.onMediaUnavailableCount, `is`(0))

        // add YUV media
        mediaRegistry.addMedia(info: yuvMedia1)
        assertThat(yuvListener.onMediaAvailableCount, `is`(1))
        assertThat(yuvListener.onMediaUnavailableCount, `is`(0))
        assertThat(h264Listener.onMediaAvailableCount, `is`(0))
        assertThat(h264Listener.onMediaUnavailableCount, `is`(0))

        // add H264 media
        mediaRegistry.addMedia(info: h264Media1)
        assertThat(yuvListener.onMediaAvailableCount, `is`(1))
        assertThat(yuvListener.onMediaUnavailableCount, `is`(0))
        assertThat(h264Listener.onMediaAvailableCount, `is`(0))
        assertThat(h264Listener.onMediaUnavailableCount, `is`(0))

        // register H264 listener
        mediaRegistry.registerListener(listener: h264Listener, mediaType: .H264)
        assertThat(yuvListener.onMediaAvailableCount, `is`(1))
        assertThat(yuvListener.onMediaUnavailableCount, `is`(0))
        assertThat(h264Listener.onMediaAvailableCount, `is`(1))
        assertThat(h264Listener.onMediaUnavailableCount, `is`(0))

        // add another YUV media
        mediaRegistry.addMedia(info: yuvMedia2)
        assertThat(yuvListener.onMediaAvailableCount, `is`(2))
        assertThat(yuvListener.onMediaUnavailableCount, `is`(1))
        assertThat(h264Listener.onMediaAvailableCount, `is`(1))
        assertThat(h264Listener.onMediaUnavailableCount, `is`(0))

        // add previous YUV media, nothing should change as it should already be removed
        mediaRegistry.removeMedia(info: yuvMedia1)
        assertThat(yuvListener.onMediaAvailableCount, `is`(2))
        assertThat(yuvListener.onMediaUnavailableCount, `is`(1))
        assertThat(h264Listener.onMediaAvailableCount, `is`(1))
        assertThat(h264Listener.onMediaUnavailableCount, `is`(0))

        // remove current YUV media
        mediaRegistry.removeMedia(info: yuvMedia2)
        assertThat(yuvListener.onMediaAvailableCount, `is`(2))
        assertThat(yuvListener.onMediaUnavailableCount, `is`(2))
        assertThat(h264Listener.onMediaAvailableCount, `is`(1))
        assertThat(h264Listener.onMediaUnavailableCount, `is`(0))

        // remove YUV listener, nothing should change
        mediaRegistry.unregisterListener(listener: yuvListener, mediaType: .yuv)
        assertThat(yuvListener.onMediaAvailableCount, `is`(2))
        assertThat(yuvListener.onMediaUnavailableCount, `is`(2))
        assertThat(h264Listener.onMediaAvailableCount, `is`(1))
        assertThat(h264Listener.onMediaUnavailableCount, `is`(0))

        // remove an H264 media that was not registered, nothing should change
        mediaRegistry.removeMedia(info: h264Media2)
        assertThat(yuvListener.onMediaAvailableCount, `is`(2))
        assertThat(yuvListener.onMediaUnavailableCount, `is`(2))
        assertThat(h264Listener.onMediaAvailableCount, `is`(1))
        assertThat(h264Listener.onMediaUnavailableCount, `is`(0))

        // remove H264 listener,
        mediaRegistry.unregisterListener(listener: h264Listener, mediaType: .H264)
        assertThat(yuvListener.onMediaAvailableCount, `is`(2))
        assertThat(yuvListener.onMediaUnavailableCount, `is`(2))
        assertThat(h264Listener.onMediaAvailableCount, `is`(1))
        assertThat(h264Listener.onMediaUnavailableCount, `is`(0))

        // remove current H264 media, nothing should changen as there is no more listener
        mediaRegistry.removeMedia(info: h264Media1)
        assertThat(yuvListener.onMediaAvailableCount, `is`(2))
        assertThat(yuvListener.onMediaUnavailableCount, `is`(2))
        assertThat(h264Listener.onMediaAvailableCount, `is`(1))
        assertThat(h264Listener.onMediaUnavailableCount, `is`(0))
    }

    private class YuvMediaListener: MediaListener {
        var onMediaAvailableCount = 0
        var onMediaUnavailableCount = 0

        override func onMediaAvailable(mediaInfo: SdkCoreMediaInfo) {
            guard mediaInfo as? SdkCoreYuvInfo != nil else {
                return
            }
            onMediaAvailableCount += 1
        }

        override func onMediaUnavailable() {
            onMediaUnavailableCount += 1
        }
    }

    private class H264MediaListener: MediaListener {
        var onMediaAvailableCount = 0
        var onMediaUnavailableCount = 0

        override func onMediaAvailable(mediaInfo: SdkCoreMediaInfo) {
            guard mediaInfo as? SdkCoreH264Info != nil else {
                return
            }
            onMediaAvailableCount += 1
        }

        override func onMediaUnavailable() {
            onMediaUnavailableCount += 1
        }
    }
}
