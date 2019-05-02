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

class AnimationFeaturePilotingItfTests: ArsdkEngineTestBase {

    let allArsdkAvailableAnims: [ArsdkFeatureAnimationType] = [.candle, .horizontalPanorama, .dollySlide,
                                                               .twistUp, .positionTwistUp]
    let allAvailableAnims: [AnimationType] = [.candle, .horizontalPanorama, .dollySlide,
                                              .twistUp, .positionTwistUp]

    var drone: DroneCore!
    var animationPilotingItf: AnimationPilotingItf?
    var animationPilotingItfRef: Ref<AnimationPilotingItf>?
    var changeCnt = 0

    override func setUp() {
        super.setUp()
        mockArsdkCore.addDevice("123", type: Drone.Model.anafi4k.internalId, backendType: .net, name: "Drone1",
                                handle: 1)
        drone = droneStore.getDevice(uid: "123")!

        animationPilotingItfRef = drone.getPilotingItf(PilotingItfs.animation) { [unowned self] pilotingItf in
            self.animationPilotingItf = pilotingItf
            self.changeCnt += 1
        }
        changeCnt = 0
    }

    func testPublishUnpublish() {
        // should be unavailable when the drone is not connected and not known
        assertThat(animationPilotingItf, `is`(nilValue()))

        // connect the drone, piloting interface should be published
        connect(drone: drone, handle: 1)
        assertThat(animationPilotingItf, `is`(present()))
        assertThat(changeCnt, `is`(1))

        // disconnect drone
        disconnect(drone: drone, handle: 1)
        assertThat(animationPilotingItf, `is`(nilValue()))
        assertThat(changeCnt, `is`(2))
    }

    func testAvailableAnimations() {
        connect(drone: drone, handle: 1)

        // test that there is no available animation by default
        assertThat(animationPilotingItf!.availableAnimations, empty())
        assertThat(changeCnt, `is`(1))

        // test all animation available
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationAvailabilityEncoder(
            valuesBitField: Bitfield<ArsdkFeatureAnimationType>.of(allArsdkAvailableAnims)))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.availableAnimations, containsInAnyOrder(allAvailableAnims))

        // check that receiving a unknown value in the list is not reflected in the api
        // the values in this bitfield are the 32th val (does not exist) and the second one (flip)
        let unknownBitfield = 1 << 32 | 1 << 1
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationAvailabilityEncoder(
            valuesBitField: UInt(unknownBitfield)))
        assertThat(changeCnt, `is`(3))
        assertThat(animationPilotingItf!.availableAnimations, contains(.flip))

        // test each animation availability separately
        testAvailableAnimation(arsdkType: .candle, apiType: .candle)
        testAvailableAnimation(arsdkType: .dollySlide, apiType: .dollySlide)
        testAvailableAnimation(arsdkType: .dronie, apiType: .dronie)
        testAvailableAnimation(arsdkType: .flip, apiType: .flip)
        testAvailableAnimation(arsdkType: .horizontalPanorama, apiType: .horizontalPanorama)
        testAvailableAnimation(arsdkType: .horizontalReveal, apiType: .horizontalReveal)
        testAvailableAnimation(arsdkType: .parabola, apiType: .parabola)
        testAvailableAnimation(arsdkType: .spiral, apiType: .spiral)
        testAvailableAnimation(arsdkType: .verticalReveal, apiType: .verticalReveal)
        testAvailableAnimation(arsdkType: .vertigo, apiType: .vertigo)
        testAvailableAnimation(arsdkType: .twistUp, apiType: .twistUp)
        testAvailableAnimation(arsdkType: .positionTwistUp, apiType: .positionTwistUp)
        testAvailableAnimation(arsdkType: .horizontal180PhotoPanorama, apiType: .horizontal180PhotoPanorama)
        testAvailableAnimation(arsdkType: .vertical180PhotoPanorama, apiType: .vertical180PhotoPanorama)
        testAvailableAnimation(arsdkType: .sphericalPhotoPanorama, apiType: .sphericalPhotoPanorama)
    }

    func testGlobalAnimationState() {
        connect(drone: drone, handle: 1)

        // test that there is no animation by default
        assertThat(animationPilotingItf!.animation, nilValue())
        assertThat(changeCnt, `is`(1))

        // test unidentified anim
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationStateEncoder(
            type: .sdkCoreUnknown, percent: 50))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.unidentified), `is`(.animating), has(progress: 50))))

        // test progress
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationStateEncoder(
            type: .sdkCoreUnknown, percent: 75))
        assertThat(changeCnt, `is`(3))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.unidentified), `is`(.animating), has(progress: 75))))

        // test none type
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationStateEncoder(
            type: .none, percent: 99))
        assertThat(changeCnt, `is`(4))
        assertThat(animationPilotingItf!.animation, nilValue())
    }

    func testCandleAnimationState() {
        connect(drone: drone, handle: 1)

        // test animating state
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationCandleStateEncoder(
                state: .running, speed: 1.0, verticalDistance: 2.0, playMode: .onceThenMirrored))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.candle), `is`(.animating), has(progress: 0))))
        assertThat(animationPilotingItf!.animation as? CandleAnimation, presentAnd(
            `is`(speed: 1.0, verticalDistance: 2.0, mode: .onceThenMirrored)))

       // test change progress
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationStateEncoder(
            type: .candle, percent: 50))
        assertThat(changeCnt, `is`(3))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.candle), `is`(.animating), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? CandleAnimation, presentAnd(
            `is`(speed: 1.0, verticalDistance: 2.0, mode: .onceThenMirrored)))

        // test aborting state
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationCandleStateEncoder(
                state: .canceling, speed: 1.0, verticalDistance: 2.0, playMode: .onceThenMirrored))
        assertThat(changeCnt, `is`(4))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.candle), `is`(.aborting), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? CandleAnimation, presentAnd(
            `is`(speed: 1.0, verticalDistance: 2.0, mode: .onceThenMirrored)))

        // test idle state, no changes expected
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationCandleStateEncoder(
                state: .idle, speed: 1.0, verticalDistance: 2.0, playMode: .onceThenMirrored))
        assertThat(changeCnt, `is`(4))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.candle), `is`(.aborting), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? CandleAnimation, presentAnd(
            `is`(speed: 1.0, verticalDistance: 2.0, mode: .onceThenMirrored)))

        // test that when state is unsupported, status is ANIMATING
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationCandleStateEncoder(
                state: .sdkCoreUnknown, speed: 1.0, verticalDistance: 2.0, playMode: .onceThenMirrored))
        assertThat(changeCnt, `is`(5))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.candle), `is`(.animating), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? CandleAnimation, presentAnd(
            `is`(speed: 1.0, verticalDistance: 2.0, mode: .onceThenMirrored)))
    }

    func testDollySlideAnimationState() {
        connect(drone: drone, handle: 1)

        // test animating state
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationDollySlideStateEncoder(
                state: .running, speed: 1.0, angle: 2.0, horizontalDistance: 3.0, playMode: .normal))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.dollySlide), `is`(.animating), has(progress: 0))))
        assertThat(animationPilotingItf!.animation as? DollySlideAnimation, presentAnd(
            `is`(speed: 1.0, angle: 2.0.toDegrees(), horizontalDistance: 3.0, mode: .once)))

        // test change progress
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationStateEncoder(
            type: .dollySlide, percent: 50))
        assertThat(changeCnt, `is`(3))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.dollySlide), `is`(.animating), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? DollySlideAnimation, presentAnd(
            `is`(speed: 1.0, angle: 2.0.toDegrees(), horizontalDistance: 3.0, mode: .once)))

        // test aborting state
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationDollySlideStateEncoder(
                state: .canceling, speed: 1.0, angle: 2.0, horizontalDistance: 3.0, playMode: .normal))
        assertThat(changeCnt, `is`(4))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.dollySlide), `is`(.aborting), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? DollySlideAnimation, presentAnd(
            `is`(speed: 1.0, angle: 2.0.toDegrees(), horizontalDistance: 3.0, mode: .once)))

        // test idle state, no changes expected
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationDollySlideStateEncoder(
                state: .idle, speed: 1.0, angle: 2.0, horizontalDistance: 3.0, playMode: .normal))
        assertThat(changeCnt, `is`(4))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.dollySlide), `is`(.aborting), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? DollySlideAnimation, presentAnd(
            `is`(speed: 1.0, angle: 2.0.toDegrees(), horizontalDistance: 3.0, mode: .once)))

        // test that when state is unsupported, status is ANIMATING
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationDollySlideStateEncoder(
                state: .sdkCoreUnknown, speed: 1.0, angle: 2.0, horizontalDistance: 3.0, playMode: .normal))
        assertThat(changeCnt, `is`(5))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.dollySlide), `is`(.animating), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? DollySlideAnimation, presentAnd(
            `is`(speed: 1.0, angle: 2.0.toDegrees(), horizontalDistance: 3.0, mode: .once)))
    }

    func testDronieAnimationState() {
        connect(drone: drone, handle: 1)

        // test animating state
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationDronieStateEncoder(
                state: .running, speed: 1.0, distance: 3.0, playMode: .normal))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.dronie), `is`(.animating), has(progress: 0))))
        assertThat(animationPilotingItf!.animation as? DronieAnimation, presentAnd(
            `is`(speed: 1.0, distance: 3.0, mode: .once)))

        // test change progress
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationStateEncoder(
            type: .dronie, percent: 50))
        assertThat(changeCnt, `is`(3))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.dronie), `is`(.animating), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? DronieAnimation, presentAnd(
            `is`(speed: 1.0, distance: 3.0, mode: .once)))

        // test aborting state
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationDronieStateEncoder(
                state: .canceling, speed: 1.0, distance: 3.0, playMode: .normal))
        assertThat(changeCnt, `is`(4))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.dronie), `is`(.aborting), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? DronieAnimation, presentAnd(
            `is`(speed: 1.0, distance: 3.0, mode: .once)))

        // test idle state, no changes expected
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationDronieStateEncoder(
                state: .idle, speed: 1.0, distance: 3.0, playMode: .normal))
        assertThat(changeCnt, `is`(4))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.dronie), `is`(.aborting), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? DronieAnimation, presentAnd(
            `is`(speed: 1.0, distance: 3.0, mode: .once)))

        // test that when state is unsupported, status is ANIMATING
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationDronieStateEncoder(
                state: .sdkCoreUnknown, speed: 1.0, distance: 3.0, playMode: .normal))
        assertThat(changeCnt, `is`(5))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.dronie), `is`(.animating), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? DronieAnimation, presentAnd(
            `is`(speed: 1.0, distance: 3.0, mode: .once)))
    }

    func testFlipAnimationState() {
        connect(drone: drone, handle: 1)

        // test animating state
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationFlipStateEncoder(
                state: .running, type: .front))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.flip), `is`(.animating), has(progress: 0))))
        assertThat(animationPilotingItf!.animation as? FlipAnimation, presentAnd(has(direction: .front)))

        // test change progress
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationStateEncoder(
            type: .flip, percent: 50))
        assertThat(changeCnt, `is`(3))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.flip), `is`(.animating), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? FlipAnimation, presentAnd(has(direction: .front)))

        // test aborting state
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationFlipStateEncoder(
                state: .canceling, type: .front))
        assertThat(changeCnt, `is`(4))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.flip), `is`(.aborting), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? FlipAnimation, presentAnd(has(direction: .front)))

        // test idle state, no changes expected
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationFlipStateEncoder(
                state: .idle, type: .front))
        assertThat(changeCnt, `is`(4))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.flip), `is`(.aborting), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? FlipAnimation, presentAnd(has(direction: .front)))

        // test that when state is unsupported, status is ANIMATING
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationFlipStateEncoder(
                state: .sdkCoreUnknown, type: .front))
        assertThat(changeCnt, `is`(5))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.flip), `is`(.animating), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? FlipAnimation, presentAnd(has(direction: .front)))
    }

    func testHorizontalPanoramaAnimationState() {
        connect(drone: drone, handle: 1)

        // test animating state
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationHorizontalPanoramaStateEncoder(
                state: .running, rotationAngle: 1.0, rotationSpeed: 2.0))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.horizontalPanorama), `is`(.animating), has(progress: 0))))
        assertThat(animationPilotingItf!.animation as? HorizontalPanoramaAnimation, presentAnd(
            `is`(rotationAngle: 1.0.toDegrees(), rotationSpeed: 2.0.toDegrees())))

        // test change progress
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationStateEncoder(
            type: .horizontalPanorama, percent: 50))
        assertThat(changeCnt, `is`(3))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.horizontalPanorama), `is`(.animating), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? HorizontalPanoramaAnimation, presentAnd(
            `is`(rotationAngle: 1.0.toDegrees(), rotationSpeed: 2.0.toDegrees())))

        // test aborting state
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationHorizontalPanoramaStateEncoder(
                state: .canceling, rotationAngle: 1.0, rotationSpeed: 2.0))
        assertThat(changeCnt, `is`(4))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.horizontalPanorama), `is`(.aborting), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? HorizontalPanoramaAnimation, presentAnd(
            `is`(rotationAngle: 1.0.toDegrees(), rotationSpeed: 2.0.toDegrees())))

        // test idle state, no changes expected
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationHorizontalPanoramaStateEncoder(
                state: .idle, rotationAngle: 1.0, rotationSpeed: 2.0))
        assertThat(changeCnt, `is`(4))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.horizontalPanorama), `is`(.aborting), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? HorizontalPanoramaAnimation, presentAnd(
            `is`(rotationAngle: 1.0.toDegrees(), rotationSpeed: 2.0.toDegrees())))

        // test that when state is unsupported, status is ANIMATING
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationHorizontalPanoramaStateEncoder(
                state: .sdkCoreUnknown, rotationAngle: 1.0, rotationSpeed: 2.0))
        assertThat(changeCnt, `is`(5))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.horizontalPanorama), `is`(.animating), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? HorizontalPanoramaAnimation, presentAnd(
            `is`(rotationAngle: 1.0.toDegrees(), rotationSpeed: 2.0.toDegrees())))
    }

    func testVertigoAnimationState() {
        connect(drone: drone, handle: 1)

        // test animating state
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationVertigoStateEncoder(
            state: .running, duration: 10, maxZoomLevel: 3.5, finishAction: .none, playMode: .normal))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.vertigo), `is`(.animating), has(progress: 0))))
        assertThat(animationPilotingItf!.animation as? VertigoAnimation, presentAnd(
            `is`(duration: 10, maxZoomLevel: 3.5, finishAction: .none, mode: .once)))

        // test change progress
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationStateEncoder(
            type: .vertigo, percent: 50))
        assertThat(changeCnt, `is`(3))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.vertigo), `is`(.animating), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? VertigoAnimation, presentAnd(
            `is`(duration: 10, maxZoomLevel: 3.5, finishAction: .none, mode: .once)))

        // test aborting state
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationVertigoStateEncoder(
            state: .canceling, duration: 10, maxZoomLevel: 3.5, finishAction: .none, playMode: .normal))
        assertThat(changeCnt, `is`(4))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.vertigo), `is`(.aborting), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? VertigoAnimation, presentAnd(
            `is`(duration: 10, maxZoomLevel: 3.5, finishAction: .none, mode: .once)))

        // test idle state, no changes expected
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationVertigoStateEncoder(
            state: .idle, duration: 10, maxZoomLevel: 3.5, finishAction: .none, playMode: .normal))
        assertThat(changeCnt, `is`(4))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.vertigo), `is`(.aborting), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? VertigoAnimation, presentAnd(
            `is`(duration: 10, maxZoomLevel: 3.5, finishAction: .none, mode: .once)))

        // test that when state is unsupported, status is ANIMATING
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationVertigoStateEncoder(
            state: .sdkCoreUnknown, duration: 10, maxZoomLevel: 3.5, finishAction: .none, playMode: .normal))
        assertThat(changeCnt, `is`(5))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.vertigo), `is`(.animating), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? VertigoAnimation, presentAnd(
            `is`(duration: 10, maxZoomLevel: 3.5, finishAction: .none, mode: .once)))
    }

    func testTwistUpAnimationState() {
        connect(drone: drone, handle: 1)

        // test animating state
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationTwistUpStateEncoder(
                state: .running, speed: 1.0, verticalDistance: 2.0, rotationAngle: 3.0, rotationSpeed: 4.0,
                playMode: .onceThenMirrored))
        assertThat(changeCnt, `is`(2))

        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.twistUp), `is`(.animating), has(progress: 0))))
        assertThat(animationPilotingItf!.animation as? TwistUpAnimation, presentAnd(`is`(speed: 1.0,
                    verticalDistance: 2.0, rotationAngle: 3.0.toDegrees(), rotationSpeed: 4.0.toDegrees(),
                    mode: .onceThenMirrored)))

        // test change progress
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationStateEncoder(
            type: .twistUp, percent: 50))
        assertThat(changeCnt, `is`(3))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.twistUp), `is`(.animating), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? TwistUpAnimation, presentAnd(`is`(speed: 1.0,
                    verticalDistance: 2.0, rotationAngle: 3.0.toDegrees(), rotationSpeed: 4.0.toDegrees(),
                    mode: .onceThenMirrored)))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationTwistUpStateEncoder(
                state: .canceling, speed: 1.0, verticalDistance: 2.0, rotationAngle: 3.0,
                rotationSpeed: 4.0, playMode: .onceThenMirrored))
        assertThat(changeCnt, `is`(4))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.twistUp), `is`(.aborting), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? TwistUpAnimation, presentAnd(`is`(speed: 1.0,
                    verticalDistance: 2.0, rotationAngle: 3.0.toDegrees(), rotationSpeed: 4.0.toDegrees(),
                    mode: .onceThenMirrored)))

        // test idle state, no changes expected
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationTwistUpStateEncoder(
                state: .idle, speed: 1.0, verticalDistance: 2.0, rotationAngle: 3.0,
                rotationSpeed: 4.0, playMode: .onceThenMirrored))
        assertThat(changeCnt, `is`(4))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.twistUp), `is`(.aborting), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? TwistUpAnimation, presentAnd(`is`(speed: 1.0,
                    verticalDistance: 2.0, rotationAngle: 3.0.toDegrees(), rotationSpeed: 4.0.toDegrees(),
                    mode: .onceThenMirrored)))

        // test that when state is unsupported, status is ANIMATING
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationTwistUpStateEncoder(
                state: .sdkCoreUnknown, speed: 1.0, verticalDistance: 2.0, rotationAngle: 3.0,
                rotationSpeed: 4.0, playMode: .onceThenMirrored))
        assertThat(changeCnt, `is`(5))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.twistUp), `is`(.animating), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? TwistUpAnimation, presentAnd(`is`(speed: 1.0,
                    verticalDistance: 2.0, rotationAngle: 3.0.toDegrees(), rotationSpeed: 4.0.toDegrees(),
                    mode: .onceThenMirrored)))
    }

    func testPositionTwistUpAnimationState() {
        connect(drone: drone, handle: 1)

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationPositionTwistUpStateEncoder(
                state: .running, speed: 1.0, verticalDistance: 2.0, rotationAngle: 3.0, rotationSpeed: 4.0,
                playMode: .onceThenMirrored))
        assertThat(changeCnt, `is`(2))

        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.positionTwistUp), `is`(.animating), has(progress: 0))))
        assertThat(animationPilotingItf!.animation as? PositionTwistUpAnimation, presentAnd(`is`(speed: 1.0,
                    verticalDistance: 2.0, rotationAngle: 3.0.toDegrees(), rotationSpeed: 4.0.toDegrees(),
                    mode: .onceThenMirrored)))

        // test change progress
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationStateEncoder(
            type: .positionTwistUp, percent: 50))
        assertThat(changeCnt, `is`(3))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.positionTwistUp), `is`(.animating), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? PositionTwistUpAnimation, presentAnd(`is`(speed: 1.0,
                    verticalDistance: 2.0, rotationAngle: 3.0.toDegrees(), rotationSpeed: 4.0.toDegrees(),
                    mode: .onceThenMirrored)))

        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationPositionTwistUpStateEncoder(
                state: .canceling, speed: 1.0, verticalDistance: 2.0, rotationAngle: 3.0,
                rotationSpeed: 4.0, playMode: .onceThenMirrored))
        assertThat(changeCnt, `is`(4))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.positionTwistUp), `is`(.aborting), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? PositionTwistUpAnimation, presentAnd(`is`(speed: 1.0,
                    verticalDistance: 2.0, rotationAngle: 3.0.toDegrees(), rotationSpeed: 4.0.toDegrees(),
                    mode: .onceThenMirrored)))

        // test idle state, no changes expected
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationPositionTwistUpStateEncoder(
                state: .idle, speed: 1.0, verticalDistance: 2.0, rotationAngle: 3.0,
                rotationSpeed: 4.0, playMode: .onceThenMirrored))
        assertThat(changeCnt, `is`(4))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.positionTwistUp), `is`(.aborting), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? PositionTwistUpAnimation, presentAnd(`is`(speed: 1.0,
                    verticalDistance: 2.0, rotationAngle: 3.0.toDegrees(), rotationSpeed: 4.0.toDegrees(),
                    mode: .onceThenMirrored)))

        // test that when state is unsupported, status is ANIMATING
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationPositionTwistUpStateEncoder(
                state: .sdkCoreUnknown, speed: 1.0, verticalDistance: 2.0, rotationAngle: 3.0,
                rotationSpeed: 4.0, playMode: .onceThenMirrored))
        assertThat(changeCnt, `is`(5))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.positionTwistUp), `is`(.animating), has(progress: 50))))
        assertThat(animationPilotingItf!.animation as? PositionTwistUpAnimation, presentAnd(`is`(speed: 1.0,
                    verticalDistance: 2.0, rotationAngle: 3.0.toDegrees(), rotationSpeed: 4.0.toDegrees(),
                    mode: .onceThenMirrored)))
    }

    func testHorizontal180PhotoPanoramaState() {
        connect(drone: drone, handle: 1)
        assertThat(changeCnt, `is`(1))

        // test animating state
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationHorizontal180PhotoPanoramaStateEncoder(state: .running))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.horizontal180PhotoPanorama), `is`(.animating), has(progress: 0))))

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationStateEncoder(
            type: .horizontal180PhotoPanorama, percent: 50))
        assertThat(changeCnt, `is`(3))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.horizontal180PhotoPanorama), `is`(.animating), has(progress: 50))))

        // test aborting state
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationHorizontal180PhotoPanoramaStateEncoder(
                state: .canceling))
        assertThat(changeCnt, `is`(4))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.horizontal180PhotoPanorama), `is`(.aborting), has(progress: 50))))

        // test idle state, no changes expected
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationHorizontal180PhotoPanoramaStateEncoder(
                state: .idle))
        assertThat(changeCnt, `is`(4))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.horizontal180PhotoPanorama), `is`(.aborting), has(progress: 50))))

        // test that when state is unsupported, status is ANIMATING
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationHorizontal180PhotoPanoramaStateEncoder(
                state: .sdkCoreUnknown))
        assertThat(changeCnt, `is`(5))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.horizontal180PhotoPanorama), `is`(.animating), has(progress: 50))))

    }

    func testVertical180PhotoPanoramaState() {
        connect(drone: drone, handle: 1)
        assertThat(changeCnt, `is`(1))

        // test animating state
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationHorizontal180PhotoPanoramaStateEncoder(state: .running))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.horizontal180PhotoPanorama), `is`(.animating), has(progress: 0))))

        // test aborting state
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationHorizontal180PhotoPanoramaStateEncoder(
                state: .canceling))
        assertThat(changeCnt, `is`(3))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.horizontal180PhotoPanorama), `is`(.aborting), has(progress: 0))))

        // test idle state, no changes expected
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationHorizontal180PhotoPanoramaStateEncoder(
                state: .idle))
        assertThat(changeCnt, `is`(3))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.horizontal180PhotoPanorama), `is`(.aborting), has(progress: 0))))

        // test that when state is unsupported, status is ANIMATING
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationHorizontal180PhotoPanoramaStateEncoder(
                state: .sdkCoreUnknown))
        assertThat(changeCnt, `is`(4))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.horizontal180PhotoPanorama), `is`(.animating), has(progress: 0))))
    }

    func testSphericalPhotoPanoramaState() {
        connect(drone: drone, handle: 1)
        assertThat(changeCnt, `is`(1))

        // test animating state
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationHorizontal180PhotoPanoramaStateEncoder(state: .running))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.horizontal180PhotoPanorama), `is`(.animating), has(progress: 0))))

        // test aborting state
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationHorizontal180PhotoPanoramaStateEncoder(
                state: .canceling))
        assertThat(changeCnt, `is`(3))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.horizontal180PhotoPanorama), `is`(.aborting), has(progress: 0))))

        // test idle state, no changes expected
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationHorizontal180PhotoPanoramaStateEncoder(
                state: .idle))
        assertThat(changeCnt, `is`(3))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.horizontal180PhotoPanorama), `is`(.aborting), has(progress: 0))))

        // test that when state is unsupported, status is ANIMATING
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationHorizontal180PhotoPanoramaStateEncoder(
                state: .sdkCoreUnknown))
        assertThat(changeCnt, `is`(4))
        assertThat(animationPilotingItf!.animation, presentAnd(allOf(
            `is`(.horizontal180PhotoPanorama), `is`(.animating), has(progress: 0))))
    }
    func testAbortAnimation() {
        connect(drone: drone, handle: 1)

        // mock animating state
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationHorizontalPanoramaStateEncoder(
                state: .running, rotationAngle: 1.0, rotationSpeed: 2.0))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.animation, presentAnd(`is`(.animating)))

        // abort animation
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.animationCancel())
        _ = animationPilotingItf!.abortCurrentAnimation()
    }

    func testStartCandle() {
        connect(drone: drone, handle: 1)

        // mock candle animations available
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationAvailabilityEncoder(
            valuesBitField: Bitfield<ArsdkFeatureAnimationType>.of(.candle)))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.availableAnimations, contains(.candle))

        // test default config
        let config = CandleAnimationConfig()
        testStartCandle(config: config, params: [])

        // test speed parameter
        _ = config.with(speed: 1.1234567)
        testStartCandle(config: config, params: [.speed])

        // test speed and vertical distance parameter
        _ = config.with(verticalDistance: 10.1234567)
        testStartCandle(config: config, params: [.speed, .verticalDistance])

        // test speed, vertical distance and mode parameter
        _ = config.with(mode: .onceThenMirrored)
        testStartCandle(config: config, params: [.speed, .verticalDistance, .playMode])
    }

    func testStartDollySlide() {
        connect(drone: drone, handle: 1)

        // mock dolly slide animations available
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationAvailabilityEncoder(
            valuesBitField: Bitfield<ArsdkFeatureAnimationType>.of(.dollySlide)))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.availableAnimations, contains(.dollySlide))

        // test default config
        let config = DollySlideAnimationConfig()
        testStartDollySlide(config: config, params: [])

        _ = config.with(speed: 1.1234567)
        testStartDollySlide(config: config, params: [.speed])

        _ = config.with(angle: 90.1234567)
        testStartDollySlide(config: config, params: [.speed, .angle])

        _ = config.with(horizontalDistance: 10.123456789)
        testStartDollySlide(config: config, params: [.speed, .angle, .horizontalDistance])

        _ = config.with(mode: .onceThenMirrored)
        testStartDollySlide(config: config, params: [.speed, .angle, .horizontalDistance, .playMode])
    }

    func testStartDronie() {
        connect(drone: drone, handle: 1)

        // mock candle animations available
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationAvailabilityEncoder(
            valuesBitField: Bitfield<ArsdkFeatureAnimationType>.of(.dronie)))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.availableAnimations, contains(.dronie))

        // test default config
        let config = DronieAnimationConfig()
        testStartDronie(config: config, params: [])

        // test speed parameter
        _ = config.with(speed: 1.123456789)
        testStartDronie(config: config, params: [.speed])

        // test speed and vertical distance parameter
        _ = config.with(distance: 10.123456789)
        testStartDronie(config: config, params: [.speed, .distance])

        // test speed, vertical distance and mode parameter
        _ = config.with(mode: .onceThenMirrored)
        testStartDronie(config: config, params: [.speed, .distance, .playMode])
    }

    func testStartFlip() {
        connect(drone: drone, handle: 1)

        // mock candle animations available
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationAvailabilityEncoder(
            valuesBitField: Bitfield<ArsdkFeatureAnimationType>.of(.flip)))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.availableAnimations, contains(.flip))

        // test default config
        var config = FlipAnimationConfig(direction: .front)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.animationStartFlip(type: .front))
        _ = animationPilotingItf?.startAnimation(config: config)

        config = FlipAnimationConfig(direction: .back)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.animationStartFlip(type: .back))
        _ = animationPilotingItf?.startAnimation(config: config)

        config = FlipAnimationConfig(direction: .left)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.animationStartFlip(type: .left))
        _ = animationPilotingItf?.startAnimation(config: config)

        config = FlipAnimationConfig(direction: .right)
        expectCommand(handle: 1, expectedCmd: ExpectedCmd.animationStartFlip(type: .right))
        _ = animationPilotingItf?.startAnimation(config: config)
    }

    func testStartHorizontalPanorama() {
        connect(drone: drone, handle: 1)

        // mock horizontalPanorama animations available
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationAvailabilityEncoder(
            valuesBitField: Bitfield<ArsdkFeatureAnimationType>.of(.horizontalPanorama)))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.availableAnimations, contains(.horizontalPanorama))

        // test default config
        let config = HorizontalPanoramaAnimationConfig()
        testStartHorizontalPanorama(config: config, params: [])

        // test rotation angle parameter
        _ = config.with(rotationAngle: -75.123456789)
        testStartHorizontalPanorama(config: config, params: [.rotationAngle])

        // test rotation angle and rotation speed parameter
        _ = config.with(rotationSpeed: 10.123456789)
        testStartHorizontalPanorama(config: config, params: [.rotationAngle, .rotationSpeed])
    }

    func testStartHorizontalReveal() {
        connect(drone: drone, handle: 1)

        // mock candle animations available
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationAvailabilityEncoder(
            valuesBitField: Bitfield<ArsdkFeatureAnimationType>.of(.horizontalReveal)))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.availableAnimations, contains(.horizontalReveal))

        // test default config
        let config = HorizontalRevealAnimationConfig()
        testStartHorizontalReveal(config: config, params: [])

        // test speed parameter
        _ = config.with(speed: 1.123456789)
        testStartHorizontalReveal(config: config, params: [.speed])

        // test speed and vertical distance parameter
        _ = config.with(distance: 10.123456789)
        testStartHorizontalReveal(config: config, params: [.speed, .distance])

        // test speed, vertical distance and mode parameter
        _ = config.with(mode: .onceThenMirrored)
        testStartHorizontalReveal(config: config, params: [.speed, .distance, .playMode])
    }

    func testStartParabola() {
        connect(drone: drone, handle: 1)

        // mock candle animations available
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationAvailabilityEncoder(
            valuesBitField: Bitfield<ArsdkFeatureAnimationType>.of(.parabola)))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.availableAnimations, contains(.parabola))

        // test default config
        let config = ParabolaAnimationConfig()
        testStartParabola(config: config, params: [])

        // test speed parameter
        _ = config.with(speed: 1.123456789)
        testStartParabola(config: config, params: [.speed])

        // test speed and vertical distance parameter
        _ = config.with(verticalDistance: 10.123456789)
        testStartParabola(config: config, params: [.speed, .verticalDistance])

        // test speed, vertical distance and mode parameter
        _ = config.with(mode: .onceThenMirrored)
        testStartParabola(config: config, params: [.speed, .verticalDistance, .playMode])
    }

    func testStartSpiral() {
        connect(drone: drone, handle: 1)

        // mock candle animations available
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationAvailabilityEncoder(
            valuesBitField: Bitfield<ArsdkFeatureAnimationType>.of(.spiral)))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.availableAnimations, contains(.spiral))

        // test default config
        let config = SpiralAnimationConfig()
        testStartSpiral(config: config, params: [])

        // test speed parameter
        _ = config.with(speed: 1.123456789)
        testStartSpiral(config: config, params: [.speed])

        _ = config.with(radiusVariation: 2.123456789)
        testStartSpiral(config: config, params: [.speed, .radiusVariation])

        _ = config.with(verticalDistance: 10.123456789)
        testStartSpiral(config: config, params: [.speed, .radiusVariation, .verticalDistance])

        _ = config.with(revolutionAmount: 0.123456789)
        testStartSpiral(config: config, params: [.speed, .radiusVariation, .verticalDistance, .revolutionNb])

        _ = config.with(mode: .onceThenMirrored)
        testStartSpiral(config: config, params: [.speed, .radiusVariation, .verticalDistance, .revolutionNb,
                                                 .playMode])
    }

    func testStartVerticalReveal() {
        connect(drone: drone, handle: 1)

        // mock candle animations available
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationAvailabilityEncoder(
            valuesBitField: Bitfield<ArsdkFeatureAnimationType>.of(.verticalReveal)))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.availableAnimations, contains(.verticalReveal))

        // test default config
        let config = VerticalRevealAnimationConfig()
        testStartVerticalReveal(config: config, params: [])

        // test speed parameter
        _ = config.with(verticalSpeed: 1.123456789)
        testStartVerticalReveal(config: config, params: [.speed])

        _ = config.with(verticalDistance: 10.123456789)
        testStartVerticalReveal(config: config, params: [.speed, .verticalDistance])

        _ = config.with(rotationAngle: 0.123456789)
        testStartVerticalReveal(config: config, params: [.speed, .verticalDistance, .rotationAngle])

        _ = config.with(rotationSpeed: 5.123456789)
        testStartVerticalReveal(config: config, params: [.speed, .verticalDistance, .rotationAngle, .rotationSpeed])

        _ = config.with(mode: .onceThenMirrored)
        testStartVerticalReveal(config: config, params: [.speed, .verticalDistance, .rotationAngle, .rotationSpeed,
                                                         .playMode])
    }

    func testStartVertigo() {
        connect(drone: drone, handle: 1)

        // mock vertigo animations available
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationAvailabilityEncoder(
            valuesBitField: Bitfield<ArsdkFeatureAnimationType>.of(.vertigo)))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.availableAnimations, contains(.vertigo))

        // test default config
        let config = VertigoAnimationConfig()
        testStartVertigo(config: config, params: [])

        // test duration parameter
        _ = config.with(duration: 20.123456789)
        testStartVertigo(config: config, params: [.duration])

        _ = config.with(maxZoomLevel: 10.123456789)
        testStartVertigo(config: config, params: [.duration, .maxZoomLevel])

        _ = config.with(finishAction: .unzoom)
        testStartVertigo(config: config, params: [.duration, .maxZoomLevel, .finishAction])

        _ = config.with(mode: .onceThenMirrored)
        testStartVertigo(config: config, params: [.duration, .maxZoomLevel, .finishAction, .playMode])
    }

    func testStartTwistUp() {
        connect(drone: drone, handle: 1)

        // mock candle animations available
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationAvailabilityEncoder(
            valuesBitField: Bitfield<ArsdkFeatureAnimationType>.of(.twistUp)))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.availableAnimations, contains(.twistUp))

        // test default config
        let config = TwistUpAnimationConfig()
        testStartTwistUp(config: config, params: [])

        // test speed parameter
        _ = config.with(speed: 1.123456789)
        testStartTwistUp(config: config, params: [.speed])

        _ = config.with(verticalDistance: 10.123456789)
        testStartTwistUp(config: config, params: [.speed, .verticalDistance])

        _ = config.with(rotationAngle: 0.123456789)
        testStartTwistUp(config: config, params: [.speed, .verticalDistance, .rotationAngle])

        _ = config.with(rotationSpeed: 5.123456789)
        testStartTwistUp(config: config, params: [.speed, .verticalDistance, .rotationAngle, .rotationSpeed])

        _ = config.with(mode: .onceThenMirrored)
        testStartTwistUp(config: config, params: [.speed, .verticalDistance, .rotationAngle, .rotationSpeed,
                                                         .playMode])
    }

    func testStartPositionTwistUp() {
        connect(drone: drone, handle: 1)

        // mock candle animations available
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationAvailabilityEncoder(
            valuesBitField: Bitfield<ArsdkFeatureAnimationType>.of(.positionTwistUp)))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.availableAnimations, contains(.positionTwistUp))

        // test default config
        let config = PositionTwistUpAnimationConfig()
        testStartPositionTwistUp(config: config, params: [])

        // test speed parameter
        _ = config.with(speed: 1.123456789)
        testStartPositionTwistUp(config: config, params: [.speed])

        _ = config.with(verticalDistance: 10.123456789)
        testStartPositionTwistUp(config: config, params: [.speed, .verticalDistance])

        _ = config.with(rotationAngle: 0.123456789)
        testStartPositionTwistUp(config: config, params: [.speed, .verticalDistance, .rotationAngle])

        _ = config.with(rotationSpeed: 5.123456789)
        testStartPositionTwistUp(config: config, params: [.speed, .verticalDistance, .rotationAngle, .rotationSpeed])

        _ = config.with(mode: .onceThenMirrored)
        testStartPositionTwistUp(config: config, params: [.speed, .verticalDistance, .rotationAngle, .rotationSpeed,
                                                         .playMode])
    }
}

extension AnimationFeaturePilotingItfTests {
    func testAvailableAnimation(arsdkType: ArsdkFeatureAnimationType, apiType: AnimationType) {
        let changeCntCpy = changeCnt

        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationAvailabilityEncoder(
            valuesBitField: Bitfield<ArsdkFeatureAnimationType>.of(arsdkType)))
        assertThat(changeCnt, `is`(changeCntCpy + 1))
        assertThat(animationPilotingItf!.availableAnimations, contains(apiType))
    }

    func testStartCandle(
        config: CandleAnimationConfig, params: [ArsdkFeatureAnimationCandleConfigParam]) {
        expectCommand(handle: 1,
            expectedCmd: ExpectedCmd.animationStartCandle(
                providedParamsBitField: Bitfield<ArsdkFeatureAnimationCandleConfigParam>.of(params),
                speed: Float(config.speed ?? 0.0),
                verticalDistance: Float(config.verticalDistance ?? 0.0),
                playMode: config.mode?.arsdkValue ?? .normal))
        _ = animationPilotingItf?.startAnimation(config: config)
        assertNoExpectation()

        // mock reception
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationCandleStateEncoder(
                state: .running,
                speed: Float(config.speed ?? 0.0),
                verticalDistance: Float(config.verticalDistance ?? 0.0),
                playMode: config.mode?.arsdkValue ?? .normal))

        assertThat(animationPilotingItf!.animation?.matches(config: config), `is`(true))
    }

    func testStartDollySlide(
        config: DollySlideAnimationConfig, params: [ArsdkFeatureAnimationDollySlideConfigParam]) {
        expectCommand(handle: 1,
            expectedCmd: ExpectedCmd.animationStartDollySlide(
                providedParamsBitField: Bitfield<ArsdkFeatureAnimationDollySlideConfigParam>.of(params),
                speed: Float(config.speed ?? 0.0),
                angle: Float((config.angle ?? 0.0).toRadians()),
                horizontalDistance: Float(config.horizontalDistance ?? 0.0),
                playMode: config.mode?.arsdkValue ?? .normal))
        _ = animationPilotingItf?.startAnimation(config: config)
        assertNoExpectation()

        // mock reception
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationDollySlideStateEncoder(
                state: .running,
                speed: Float(config.speed ?? 0.0),
                angle: Float((config.angle ?? 0.0).toRadians()),
                horizontalDistance: Float(config.horizontalDistance ?? 0.0),
                playMode: config.mode?.arsdkValue ?? .normal))

        assertThat(animationPilotingItf!.animation?.matches(config: config), `is`(true))
    }

    func testStartDronie(
        config: DronieAnimationConfig, params: [ArsdkFeatureAnimationDronieConfigParam]) {
        expectCommand(handle: 1,
            expectedCmd: ExpectedCmd.animationStartDronie(
                providedParamsBitField: Bitfield<ArsdkFeatureAnimationDronieConfigParam>.of(params),
                speed: Float(config.speed ?? 0.0),
                distance: Float(config.distance ?? 0.0),
                playMode: config.mode?.arsdkValue ?? .normal))
        _ = animationPilotingItf?.startAnimation(config: config)
        assertNoExpectation()

        // mock reception
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationDronieStateEncoder(
                state: .running,
                speed: Float(config.speed ?? 0.0),
                distance: Float(config.distance ?? 0.0),
                playMode: config.mode?.arsdkValue ?? .normal))

        assertThat(animationPilotingItf!.animation?.matches(config: config), `is`(true))
    }

    func testStartHorizontalPanorama(
        config: HorizontalPanoramaAnimationConfig, params: [ArsdkFeatureAnimationHorizontalPanoramaConfigParam]) {
        expectCommand(handle: 1,
            expectedCmd: ExpectedCmd.animationStartHorizontalPanorama(
                providedParamsBitField: Bitfield<ArsdkFeatureAnimationHorizontalPanoramaConfigParam>.of(params),
                rotationAngle: Float((config.rotationAngle ?? 0.0).toRadians()),
                rotationSpeed: Float((config.rotationSpeed ?? 0.0).toRadians())))
        _ = animationPilotingItf?.startAnimation(config: config)
        assertNoExpectation()

        // mock reception
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationHorizontalPanoramaStateEncoder(
                state: .running,
                rotationAngle: Float((config.rotationAngle ?? 0.0).toRadians()),
                rotationSpeed: Float((config.rotationSpeed ?? 0.0).toRadians())))

        assertThat(animationPilotingItf!.animation?.matches(config: config), `is`(true))
    }

    func testStartHorizontalReveal(
        config: HorizontalRevealAnimationConfig, params: [ArsdkFeatureAnimationHorizontalRevealConfigParam]) {
        expectCommand(handle: 1,
            expectedCmd: ExpectedCmd.animationStartHorizontalReveal(
                providedParamsBitField: Bitfield<ArsdkFeatureAnimationHorizontalRevealConfigParam>.of(params),
                speed: Float(config.speed ?? 0.0),
                distance: Float(config.distance ?? 0.0),
                playMode: config.mode?.arsdkValue ?? .normal))
        _ = animationPilotingItf?.startAnimation(config: config)
        assertNoExpectation()

        // mock reception
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationHorizontalRevealStateEncoder(
                state: .running,
                speed: Float(config.speed ?? 0.0),
                distance: Float(config.distance ?? 0.0),
                playMode: config.mode?.arsdkValue ?? .normal))

        assertThat(animationPilotingItf!.animation?.matches(config: config), `is`(true))
    }

    func testStartParabola(
        config: ParabolaAnimationConfig, params: [ArsdkFeatureAnimationParabolaConfigParam]) {
        expectCommand(handle: 1,
            expectedCmd: ExpectedCmd.animationStartParabola(
                providedParamsBitField: Bitfield<ArsdkFeatureAnimationParabolaConfigParam>.of(params),
                speed: Float(config.speed ?? 0.0),
                verticalDistance: Float(config.verticalDistance ?? 0.0),
                playMode: config.mode?.arsdkValue ?? .normal))
        _ = animationPilotingItf?.startAnimation(config: config)
        assertNoExpectation()

        // mock reception
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationParabolaStateEncoder(
                state: .running,
                speed: Float(config.speed ?? 0.0),
                verticalDistance: Float(config.verticalDistance ?? 0.0),
                playMode: config.mode?.arsdkValue ?? .normal))

        assertThat(animationPilotingItf!.animation?.matches(config: config), `is`(true))
    }

    func testStartSpiral(
        config: SpiralAnimationConfig, params: [ArsdkFeatureAnimationSpiralConfigParam]) {
        expectCommand(handle: 1,
            expectedCmd: ExpectedCmd.animationStartSpiral(
                providedParamsBitField: Bitfield<ArsdkFeatureAnimationSpiralConfigParam>.of(params),
                speed: Float(config.speed ?? 0.0),
                radiusVariation: Float(config.radiusVariation ?? 0.0),
                verticalDistance: Float(config.verticalDistance ?? 0.0),
                revolutionNb: Float(config.revolutionAmount ?? 0.0),
                playMode: config.mode?.arsdkValue ?? .normal))
        _ = animationPilotingItf?.startAnimation(config: config)
        assertNoExpectation()

        // mock reception
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationSpiralStateEncoder(
                state: .running,
                speed: Float(config.speed ?? 0.0),
                radiusVariation: Float(config.radiusVariation ?? 0.0),
                verticalDistance: Float(config.verticalDistance ?? 0.0),
                revolutionNb: Float(config.revolutionAmount ?? 0.0),
                playMode: config.mode?.arsdkValue ?? .normal))

        assertThat(animationPilotingItf!.animation?.matches(config: config), `is`(true))
    }

    func testStartVerticalReveal(
        config: VerticalRevealAnimationConfig, params: [ArsdkFeatureAnimationVerticalRevealConfigParam]) {
        expectCommand(handle: 1,
            expectedCmd: ExpectedCmd.animationStartVerticalReveal(
                providedParamsBitField: Bitfield<ArsdkFeatureAnimationVerticalRevealConfigParam>.of(params),
                speed: Float(config.verticalSpeed ?? 0.0),
                verticalDistance: Float(config.verticalDistance ?? 0.0),
                rotationAngle: Float((config.rotationAngle ?? 0.0).toRadians()),
                rotationSpeed: Float((config.rotationSpeed ?? 0.0).toRadians()),
                playMode: config.mode?.arsdkValue ?? .normal))
        _ = animationPilotingItf?.startAnimation(config: config)
        assertNoExpectation()

        // mock reception
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationVerticalRevealStateEncoder(
                state: .running,
                speed: Float(config.verticalSpeed ?? 0.0),
                verticalDistance: Float(config.verticalDistance ?? 0.0),
                rotationAngle: Float((config.rotationAngle ?? 0.0).toRadians()),
                rotationSpeed: Float((config.rotationSpeed ?? 0.0).toRadians()),
                playMode: config.mode?.arsdkValue ?? .normal))

        assertThat(animationPilotingItf!.animation?.matches(config: config), `is`(true))
    }

    func testStartVertigo(
        config: VertigoAnimationConfig, params: [ArsdkFeatureAnimationVertigoConfigParam]) {
        expectCommand(handle: 1,
                      expectedCmd: ExpectedCmd.animationStartVertigo(
                        providedParamsBitField: Bitfield<ArsdkFeatureAnimationVertigoConfigParam>.of(params),
                        duration: Float(config.duration ?? 0),
                        maxZoomLevel: Float(config.maxZoomLevel ?? 0.0),
                        finishAction: config.finishAction?.arsdkValue ?? .none,
                        playMode: config.mode?.arsdkValue ?? .normal))
        _ = animationPilotingItf?.startAnimation(config: config)
        assertNoExpectation()

        // mock reception
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationVertigoStateEncoder(
                state: .running,
                duration: Float(config.duration ?? 0),
                maxZoomLevel: Float(config.maxZoomLevel ?? 0.0),
                finishAction: config.finishAction?.arsdkValue ?? .none,
                playMode: config.mode?.arsdkValue ?? .normal))

        assertThat(animationPilotingItf!.animation?.matches(config: config), `is`(true))
    }

    func testStartTwistUp(config: TwistUpAnimationConfig, params: [ArsdkFeatureAnimationTwistUpConfigParam]) {
        expectCommand(handle: 1,
                      expectedCmd: ExpectedCmd.animationStartTwistUp(
                        providedParamsBitField: Bitfield<ArsdkFeatureAnimationTwistUpConfigParam>.of(params),
                        speed: Float(config.speed ?? 0.0),
                        verticalDistance: Float(config.verticalDistance ?? 0.0),
                        rotationAngle: Float((config.rotationAngle ?? 0.0).toRadians()),
                        rotationSpeed: Float((config.rotationSpeed ?? 0.0).toRadians()),
                        playMode: config.mode?.arsdkValue ?? .normal))
        _ = animationPilotingItf?.startAnimation(config: config)
        assertNoExpectation()

        // mock reception
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationTwistUpStateEncoder(
                state: .running,
                speed: Float(config.speed ?? 0.0),
                verticalDistance: Float(config.verticalDistance ?? 0.0),
                rotationAngle: Float((config.rotationAngle ?? 0.0).toRadians()),
                rotationSpeed: Float((config.rotationSpeed ?? 0.0).toRadians()),
                playMode: config.mode?.arsdkValue ?? .normal))

        assertThat(animationPilotingItf!.animation?.matches(config: config), `is`(true))
    }

    func testStartPositionTwistUp(config: PositionTwistUpAnimationConfig,
                                  params: [ArsdkFeatureAnimationTwistUpConfigParam]) {
        expectCommand(handle: 1,
                      expectedCmd: ExpectedCmd.animationStartPositionTwistUp(
                        providedParamsBitField: Bitfield<ArsdkFeatureAnimationTwistUpConfigParam>.of(params),
                        speed: Float(config.speed ?? 0),
                        verticalDistance: Float(config.verticalDistance ?? 0.0),
                        rotationAngle: Float((config.rotationAngle ?? 0.0).toRadians()),
                        rotationSpeed: Float((config.rotationSpeed ?? 0.0).toRadians()),
                        playMode: config.mode?.arsdkValue ?? .normal))
        _ = animationPilotingItf?.startAnimation(config: config)
        assertNoExpectation()

        // mock reception
        mockArsdkCore.onCommandReceived(
            1, encoder: CmdEncoder.animationPositionTwistUpStateEncoder(
                state: .running,
                speed: Float(config.speed ?? 0.0),
                verticalDistance: Float(config.verticalDistance ?? 0.0),
                rotationAngle: Float((config.rotationAngle ?? 0.0).toRadians()),
                rotationSpeed: Float((config.rotationSpeed ?? 0.0).toRadians()),
                playMode: config.mode?.arsdkValue ?? .normal))

        assertThat(animationPilotingItf!.animation?.matches(config: config), `is`(true))
    }

    func testStartHorizontal180PhotoPanorama() {
        connect(drone: drone, handle: 1)

        // mock horizontal 180 photo panorama animations available
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationAvailabilityEncoder(
            valuesBitField: Bitfield<ArsdkFeatureAnimationType>.of(.horizontal180PhotoPanorama)))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.availableAnimations, contains(.horizontal180PhotoPanorama))
    }

    func testStartVertical180PhotoPanorama() {
        connect(drone: drone, handle: 1)

        // mock vertical 180 photo panorama animations available
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationAvailabilityEncoder(
            valuesBitField: Bitfield<ArsdkFeatureAnimationType>.of(.vertical180PhotoPanorama)))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.availableAnimations, contains(.vertical180PhotoPanorama))
    }

    func testStartSphericalPhotoPanorama() {
        connect(drone: drone, handle: 1)

        // mock spherical photo panorama animations available
        mockArsdkCore.onCommandReceived(1, encoder: CmdEncoder.animationAvailabilityEncoder(
            valuesBitField: Bitfield<ArsdkFeatureAnimationType>.of(.sphericalPhotoPanorama)))
        assertThat(changeCnt, `is`(2))
        assertThat(animationPilotingItf!.availableAnimations, contains(.sphericalPhotoPanorama))
    }
}
