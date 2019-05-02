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

/// Test Animation piloting interface
class AnimationPilotingItfTest: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: AnimationPilotingItfCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = AnimationPilotingItfCore(store: store, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store.get(PilotingItfs.animation), present())
        impl.unpublish()
        assertThat(store.get(PilotingItfs.animation), nilValue())
    }

    func testAvailableAnimations() {
        impl.publish()
        var cnt = 0
        let animationItf = store.get(PilotingItfs.animation)!
        _ = store.register(desc: PilotingItfs.animation) {
            cnt += 1
        }

        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(animationItf.availableAnimations, empty())

        // mock update from low-level
        impl.update(availableAnimations: [.horizontalPanorama, .candle]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(animationItf.availableAnimations, containsInAnyOrder(.horizontalPanorama, .candle))

        // mock same update from low-level -- no notification expected
        impl.update(availableAnimations: [.horizontalPanorama, .candle]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(animationItf.availableAnimations, containsInAnyOrder(.horizontalPanorama, .candle))

        // mock another update
        impl.update(availableAnimations: [.dollySlide]).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(animationItf.availableAnimations, containsInAnyOrder(.dollySlide))
    }

    func testCurrentAnimation() {
        impl.publish()
        var cnt = 0
        let animationItf = store.get(PilotingItfs.animation)!
        _ = store.register(desc: PilotingItfs.animation) {
            cnt += 1
        }

        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(animationItf.animation, nilValue())

        // mock update from low-level
        var anim = HorizontalPanoramaCore(rotationAngle: 2.0, rotationSpeed: 3.0)
        impl.update(animation: anim).notifyUpdated()
        var horizontalPanorama = animationItf.animation as? HorizontalPanoramaAnimation
        assertThat(cnt, `is`(1))
        assertThat(horizontalPanorama, presentAnd(allOf(
            `is`(.horizontalPanorama), has(progress: 0), `is`(.animating))))
        assertThat(horizontalPanorama, presentAnd(allOf(
            has(rotationAngle: 2.0), has(rotationSpeed: 3.0))))

        // mock same update from low-level -- no notification expected
        impl.update(animation: anim, status: .animating).notifyUpdated()
        horizontalPanorama = animationItf.animation as? HorizontalPanoramaAnimation
        assertThat(cnt, `is`(1))
        assertThat(horizontalPanorama, presentAnd(allOf(
            `is`(.horizontalPanorama), has(progress: 0), `is`(.animating))))
        assertThat(horizontalPanorama, presentAnd(allOf(
            has(rotationAngle: 2.0), has(rotationSpeed: 3.0))))

        // mock update with a different object but equal values -- no notification expected
        anim = HorizontalPanoramaCore(rotationAngle: 2.0, rotationSpeed: 3.0)
        impl.update(animation: anim).notifyUpdated()
        horizontalPanorama = animationItf.animation as? HorizontalPanoramaAnimation
        assertThat(cnt, `is`(1))
        assertThat(horizontalPanorama, presentAnd(allOf(
            `is`(.horizontalPanorama), has(progress: 0), `is`(.animating))))
        assertThat(horizontalPanorama, presentAnd(allOf(
            has(rotationAngle: 2.0), has(rotationSpeed: 3.0))))

        // mock percentage update
        impl.update(progress: 50).notifyUpdated()
        horizontalPanorama = animationItf.animation as? HorizontalPanoramaAnimation
        assertThat(cnt, `is`(2))
        assertThat(horizontalPanorama, presentAnd(allOf(
            `is`(.horizontalPanorama), has(progress: 50), `is`(.animating))))
        assertThat(horizontalPanorama, presentAnd(allOf(
            has(rotationAngle: 2.0), has(rotationSpeed: 3.0))))

        // mock new status
        anim = HorizontalPanoramaCore(rotationAngle: 2.0, rotationSpeed: 3.0)
        impl.update(animation: anim, status: .aborting).notifyUpdated()
        horizontalPanorama = animationItf.animation as? HorizontalPanoramaAnimation
        assertThat(cnt, `is`(3))
        assertThat(horizontalPanorama, presentAnd(allOf(
            `is`(.horizontalPanorama), has(progress: 50), `is`(.aborting))))
        assertThat(horizontalPanorama, presentAnd(allOf(
            has(rotationAngle: 2.0), has(rotationSpeed: 3.0))))

        // mock same animation received
        // Note that the progress is kept
        anim = HorizontalPanoramaCore(rotationAngle: 2.0, rotationSpeed: 3.0)
        impl.update(animation: anim, status: .animating).notifyUpdated()
        horizontalPanorama = animationItf.animation as? HorizontalPanoramaAnimation
        assertThat(cnt, `is`(4))
        assertThat(horizontalPanorama, presentAnd(allOf(
            `is`(.horizontalPanorama), has(progress: 50), `is`(.animating))))
        assertThat(horizontalPanorama, presentAnd(allOf(
            has(rotationAngle: 2.0), has(rotationSpeed: 3.0))))

        // mock no animation
        impl.update(animation: nil).notifyUpdated()
        assertThat(cnt, `is`(5))
        assertThat(animationItf.animation, nilValue())

        // check that updating the progress when animation is nil, does not change anything
        impl.update(progress: 50).notifyUpdated()
        assertThat(cnt, `is`(5))
        assertThat(animationItf.animation, nilValue())

        // mock unidentified animation
        impl.update(animation: AnimationCore.Unidentified()).notifyUpdated()
        assertThat(cnt, `is`(6))
        assertThat(animationItf.animation, presentAnd(allOf(
            `is`(.unidentified), has(progress: 0), `is`(.animating))))

        // mock unidentified animation progress changed
        impl.update(progress: 50).notifyUpdated()
        assertThat(cnt, `is`(7))
        assertThat(animationItf.animation, presentAnd(allOf(
            `is`(.unidentified), has(progress: 50), `is`(.animating))))
    }

    func testStartAndAbortAnimation() {
        impl.publish()
        var cnt = 0
        let animationItf = store.get(PilotingItfs.animation)!
        _ = store.register(desc: PilotingItfs.animation) {
            cnt += 1
        }

        // test initial value
        assertThat(cnt, `is`(0))
        assertThat(animationItf.availableAnimations, empty())
        assertThat(backend.config, nilValue())

        // test that starting an unavailable animation is forbidden
        let config = HorizontalPanoramaAnimationConfig()
        var res = animationItf.startAnimation(config: config)
        assertThat(res, `is`(false))
        assertThat(cnt, `is`(0))
        assertThat(backend.config, nilValue())

        // test that aborting is forbidden when there is no current animation
        res = animationItf.abortCurrentAnimation()
        assertThat(res, `is`(false))
        assertThat(cnt, `is`(0))
        assertThat(backend.abortCalled, `is`(0))

        // mock update list of available animations
        impl.update(availableAnimations: [.horizontalPanorama]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(animationItf.availableAnimations, containsInAnyOrder(.horizontalPanorama))

        // test that starting an available animation is permitted
        res = animationItf.startAnimation(config: config)
        assertThat(res, `is`(true))
        assertThat(backend.config, presentAnd(`is`(.horizontalPanorama)))
        assertThat(backend.config as? HorizontalPanoramaAnimationConfig, presentAnd(allOf(
            hasDefaultRotationAngle(), hasDefaultRotationSpeed())))

        // mock animation started
        impl.update(animation: AnimationCore.Unidentified()).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(animationItf.animation, presentAnd(`is`(.animating)))

        // test that aborting is permitted when status is ANIMATING
        res = animationItf.abortCurrentAnimation()
        assertThat(res, `is`(true))
        assertThat(cnt, `is`(2))
        assertThat(backend.abortCalled, `is`(1))

        // mock animation aborting
        impl.update(animation: AnimationCore.Unidentified(), status: .aborting).notifyUpdated()
        assertThat(cnt, `is`(3))
        assertThat(animationItf.animation, presentAnd(`is`(.aborting)))

        // test that aborting is forbidden when status is ABORTING
        res = animationItf.abortCurrentAnimation()
        assertThat(res, `is`(false))
        assertThat(cnt, `is`(3))
        assertThat(backend.abortCalled, `is`(1))
    }
}

private class Backend: AnimationPilotingItfBackend {
    var config: AnimationConfig?
    var abortCalled = 0

    func startAnimation(config: AnimationConfig) -> Bool {
        self.config = config
        return true
    }

    func abortCurrentAnimation() -> Bool {
        abortCalled += 1
        return true
    }
}
