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

/// Animation piloting interface component controller base class
class AnimFeaturePilotingItfController: DeviceComponentController {

    /// Animation piloting itf component
    private var animationPilotingItf: AnimationPilotingItfCore!

    /// Cached current animation type
    private var animationType = ArsdkFeatureAnimationType.none

    /// Constructor
    ///
    /// - Parameter droneController: drone controller owning this component controller (weak)
    init(droneController: DroneController) {
        super.init(deviceController: droneController)
        animationPilotingItf = AnimationPilotingItfCore(store: deviceController.device.pilotingItfStore, backend: self)
    }

    override func didConnect() {
        animationPilotingItf.publish()
    }

    override func didDisconnect() {
        animationPilotingItf.unpublish()
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureAnimationUid {
            ArsdkFeatureAnimation.decode(command, callback: self)
        }
    }

    /// Start an horizontal panorama animation.
    ///
    /// - Parameter config: the config that should be used to start the animation
    /// - Returns: true if the command has been sent, false otherwise
    private func startHorizontalPanorama(_ config: HorizontalPanoramaAnimationConfig) -> Bool {
        var customParamsBitfield = UInt(0)
        if config.rotationAngle != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationHorizontalPanoramaConfigParam>.of(.rotationAngle)
        }

        if config.rotationSpeed != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationHorizontalPanoramaConfigParam>.of(.rotationSpeed)
        }

        sendCommand(ArsdkFeatureAnimation.startHorizontalPanoramaEncoder(
            providedParamsBitField: customParamsBitfield,
            rotationAngle: Float((config.rotationAngle ?? 0.0).toRadians()),
            rotationSpeed: Float((config.rotationSpeed ?? 0.0).toRadians())))

        return true
    }

    /// Start a candle animation.
    ///
    /// - Parameter config: the config that should be used to start the animation
    /// - Returns: true if the command has been sent, false otherwise
    private func startCandle(_ config: CandleAnimationConfig) -> Bool {
        var customParamsBitfield = UInt(0)
        if config.speed != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationCandleConfigParam>.of(.speed)
        }

        if config.verticalDistance != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationCandleConfigParam>.of(.verticalDistance)
        }

        if config.mode != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationCandleConfigParam>.of(.playMode)
        }

        sendCommand(ArsdkFeatureAnimation.startCandleEncoder(
            providedParamsBitField: customParamsBitfield,
            speed: Float(config.speed ?? 0.0),
            verticalDistance: Float(config.verticalDistance ?? 0.0),
            playMode: config.mode?.arsdkValue ?? .normal))

        return true
    }

    /// Start a dolly slide animation.
    ///
    /// - Parameter config: the config that should be used to start the animation
    /// - Returns: true if the command has been sent, false otherwise
    private func startDollySlide(_ config: DollySlideAnimationConfig) -> Bool {
        var customParamsBitfield = UInt(0)
        if config.speed != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationDollySlideConfigParam>.of(.speed)
        }

        if config.angle != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationDollySlideConfigParam>.of(.angle)
        }

        if config.horizontalDistance != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationDollySlideConfigParam>.of(.horizontalDistance)
        }

        if config.mode != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationDollySlideConfigParam>.of(.playMode)
        }

        sendCommand(ArsdkFeatureAnimation.startDollySlideEncoder(
            providedParamsBitField: customParamsBitfield,
            speed: Float(config.speed ?? 0.0),
            angle: Float((config.angle ?? 0.0).toRadians()),
            horizontalDistance: Float(config.horizontalDistance ?? 0.0),
            playMode: config.mode?.arsdkValue ?? .normal))

        return true
    }

    /// Start a dronie animation.
    ///
    /// - Parameter config: the config that should be used to start the animation
    /// - Returns: true if the command has been sent, false otherwise
    private func startDronie(_ config: DronieAnimationConfig) -> Bool {
        var customParamsBitfield = UInt(0)
        if config.speed != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationDronieConfigParam>.of(.speed)
        }

        if config.distance != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationDronieConfigParam>.of(.distance)
        }

        if config.mode != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationDronieConfigParam>.of(.playMode)
        }

        sendCommand(ArsdkFeatureAnimation.startDronieEncoder(
            providedParamsBitField: customParamsBitfield,
            speed: Float(config.speed ?? 0.0),
            distance: Float(config.distance ?? 0.0),
            playMode: config.mode?.arsdkValue ?? .normal))

        return true
    }

    /// Start a flip animation.
    ///
    /// - Parameter config: the config that should be used to start the animation
    /// - Returns: true if the command has been sent, false otherwise
    private func startFlip(_ config: FlipAnimationConfig) -> Bool {
        sendCommand(ArsdkFeatureAnimation.startFlipEncoder(type: config.direction.arsdkVal()))

        return true
    }

    /// Start an horizontal reveal animation.
    ///
    /// - Parameter config: the config that should be used to start the animation
    /// - Returns: true if the command has been sent, false otherwise
    private func startHorizontalReveal(_ config: HorizontalRevealAnimationConfig) -> Bool {
        var customParamsBitfield = UInt(0)
        if config.speed != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationHorizontalRevealConfigParam>.of(.speed)
        }

        if config.distance != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationHorizontalRevealConfigParam>.of(.distance)
        }

        if config.mode != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationHorizontalRevealConfigParam>.of(.playMode)
        }

        sendCommand(ArsdkFeatureAnimation.startHorizontalRevealEncoder(
            providedParamsBitField: customParamsBitfield,
            speed: Float(config.speed ?? 0.0),
            distance: Float(config.distance ?? 0.0),
            playMode: config.mode?.arsdkValue ?? .normal))

        return true
    }

    /// Start a parabola animation.
    ///
    /// - Parameter config: the config that should be used to start the animation
    /// - Returns: true if the command has been sent, false otherwise
    private func startParabola(_ config: ParabolaAnimationConfig) -> Bool {
        var customParamsBitfield = UInt(0)
        if config.speed != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationParabolaConfigParam>.of(.speed)
        }

        if config.verticalDistance != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationParabolaConfigParam>.of(.verticalDistance)
        }

        if config.mode != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationParabolaConfigParam>.of(.playMode)
        }

        sendCommand(ArsdkFeatureAnimation.startParabolaEncoder(
            providedParamsBitField: customParamsBitfield,
            speed: Float(config.speed ?? 0.0),
            verticalDistance: Float(config.verticalDistance ?? 0.0),
            playMode: config.mode?.arsdkValue ?? .normal))

        return true
    }

    /// Start a spiral animation.
    ///
    /// - Parameter config: the config that should be used to start the animation
    /// - Returns: true if the command has been sent, false otherwise
    private func startSpiral(_ config: SpiralAnimationConfig) -> Bool {
        var customParamsBitfield = UInt(0)
        if config.speed != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationSpiralConfigParam>.of(.speed)
        }

        if config.radiusVariation != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationSpiralConfigParam>.of(.radiusVariation)
        }

        if config.verticalDistance != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationSpiralConfigParam>.of(.verticalDistance)
        }

        if config.revolutionAmount != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationSpiralConfigParam>.of(.revolutionNb)
        }

        if config.mode != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationSpiralConfigParam>.of(.playMode)
        }

        sendCommand(ArsdkFeatureAnimation.startSpiralEncoder(
            providedParamsBitField: customParamsBitfield,
            speed: Float(config.speed ?? 0.0),
            radiusVariation: Float(config.radiusVariation ?? 0.0),
            verticalDistance: Float(config.verticalDistance ?? 0.0),
            revolutionNb: Float(config.revolutionAmount ?? 0.0),
            playMode: config.mode?.arsdkValue ?? .normal))

        return true
    }

    /// Start a spiral animation.
    ///
    /// - Parameter config: the config that should be used to start the animation
    /// - Returns: true if the command has been sent, false otherwise
    private func startVerticalReveal(_ config: VerticalRevealAnimationConfig) -> Bool {
        var customParamsBitfield = UInt(0)
        if config.verticalSpeed != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationVerticalRevealConfigParam>.of(.speed)
        }

        if config.verticalDistance != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationVerticalRevealConfigParam>.of(.verticalDistance)
        }

        if config.rotationAngle != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationVerticalRevealConfigParam>.of(.rotationAngle)
        }

        if config.rotationSpeed != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationVerticalRevealConfigParam>.of(.rotationSpeed)
        }

        if config.mode != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationVerticalRevealConfigParam>.of(.playMode)
        }

        sendCommand(ArsdkFeatureAnimation.startVerticalRevealEncoder(
            providedParamsBitField: customParamsBitfield,
            speed: Float(config.verticalSpeed ?? 0.0),
            verticalDistance: Float(config.verticalDistance ?? 0.0),
            rotationAngle: Float((config.rotationAngle ?? 0.0).toRadians()),
            rotationSpeed: Float((config.rotationSpeed ?? 0.0).toRadians()),
            playMode: config.mode?.arsdkValue ?? .normal))

        return true
    }

    /// Start a vertigo animation.
    ///
    /// - Parameter config: the config that should be used to start the animation
    /// - Returns: true if the command has been sent, false otherwise
    private func startVertigo(_ config: VertigoAnimationConfig) -> Bool {
        var customParamsBitfield = UInt(0)
        if config.duration != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationVertigoConfigParam>.of(.duration)
        }

        if config.maxZoomLevel != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationVertigoConfigParam>.of(.maxZoomLevel)
        }

        if config.finishAction != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationVertigoConfigParam>.of(.finishAction)
        }

        if config.mode != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationVertigoConfigParam>.of(.playMode)
        }

        sendCommand(ArsdkFeatureAnimation.startVertigoEncoder(
            providedParamsBitField: customParamsBitfield,
            duration: Float(config.duration ?? 0),
            maxZoomLevel: Float(config.maxZoomLevel ?? 0.0),
            finishAction: config.finishAction?.arsdkValue ?? .none,
            playMode: config.mode?.arsdkValue ?? .normal))

        return true
    }

    /// Start twist up animation
    ///
    /// - Parameter config: the config that should be used to start the animation
    /// - Returns: true if the command has been sent, false otherwise
    private func startTwistUp(_ config: TwistUpAnimationConfig) -> Bool {
        var customParamsBitfield = UInt(0)
        if config.speed != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationTwistUpConfigParam>.of(.speed)
        }

        if config.verticalDistance != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationTwistUpConfigParam>.of(.verticalDistance)
        }

        if config.rotationAngle != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationTwistUpConfigParam>.of(.rotationAngle)
        }

        if config.rotationSpeed != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationTwistUpConfigParam>.of(.rotationSpeed)
        }
        if config.mode != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationTwistUpConfigParam>.of(.playMode)
        }
        sendCommand(ArsdkFeatureAnimation.startTwistUpEncoder(
            providedParamsBitField: customParamsBitfield,
            speed: Float(config.speed ?? 0.0),
            verticalDistance: Float(config.verticalDistance ?? 0.0),
            rotationAngle: Float((config.rotationAngle ?? 0.0).toRadians()),
            rotationSpeed: Float((config.rotationSpeed ?? 0.0).toRadians()),
            playMode: config.mode?.arsdkValue ?? .normal))
        return true
    }

    /// Start position twist up animation
    ///
    /// - Parameter config: the config that should be used to start the animation
    /// - Returns: true if the command has been sent, false otherwise
    private func startPositionTwistUp(_ config: PositionTwistUpAnimationConfig) -> Bool {
        var customParamsBitfield = UInt(0)
        if config.speed != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationTwistUpConfigParam>.of(.speed)
        }

        if config.verticalDistance != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationTwistUpConfigParam>.of(.verticalDistance)
        }

        if config.rotationAngle != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationTwistUpConfigParam>.of(.rotationAngle)
        }

        if config.rotationSpeed != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationTwistUpConfigParam>.of(.rotationSpeed)
        }

        if config.mode != nil {
            customParamsBitfield = customParamsBitfield |
                Bitfield<ArsdkFeatureAnimationTwistUpConfigParam>.of(.playMode)
        }
        sendCommand(ArsdkFeatureAnimation.startPositionTwistUpEncoder(
            providedParamsBitField: customParamsBitfield,
            speed: Float(config.speed ?? 0.0),
            verticalDistance: Float(config.verticalDistance ?? 0.0),
            rotationAngle: Float((config.rotationAngle ?? 0.0).toRadians()),
            rotationSpeed: Float((config.rotationSpeed ?? 0.0).toRadians()),
            playMode: config.mode?.arsdkValue ?? .normal))
        return true
    }

    private func startHorizontal180PhotoPanorama(_ config: Horizontal180PhotoPanoramaAnimationCfg) -> Bool {
        sendCommand(ArsdkFeatureAnimation.startHorizontal180PhotoPanoramaEncoder())
        return true
    }

    private func startVertical180PhotoPanorama(_ config: Vertical180PhotoPanoramaAnimationConfig) -> Bool {
        sendCommand(ArsdkFeatureAnimation.startVertical180PhotoPanoramaEncoder())
        return true
    }

    private func startSphericalPhotoPanorama(_ config: SphericalPhotoPanoramaAnimationConfig) -> Bool {
        sendCommand(ArsdkFeatureAnimation.startSphericalPhotoPanoramaEncoder())
        return true
    }
}

/// Extension of AnimFeaturePilotingItfController that implements the backend methods
extension AnimFeaturePilotingItfController: AnimationPilotingItfBackend {
    func startAnimation(config: AnimationConfig) -> Bool {
        switch config.type {
        case .candle:
            return startCandle(config as! CandleAnimationConfig)
        case .dollySlide:
            return startDollySlide(config as! DollySlideAnimationConfig)
        case .dronie:
            return startDronie(config as! DronieAnimationConfig)
        case .flip:
            return startFlip(config as! FlipAnimationConfig)
        case .horizontalPanorama:
            return startHorizontalPanorama(config as! HorizontalPanoramaAnimationConfig)
        case .horizontalReveal:
            return startHorizontalReveal(config as! HorizontalRevealAnimationConfig)
        case .parabola:
            return startParabola(config as! ParabolaAnimationConfig)
        case .spiral:
            return startSpiral(config as! SpiralAnimationConfig)
        case .verticalReveal:
            return startVerticalReveal(config as! VerticalRevealAnimationConfig)
        case .vertigo:
            return startVertigo(config as! VertigoAnimationConfig)
        case .twistUp:
            return startTwistUp(config as! TwistUpAnimationConfig)
        case .positionTwistUp:
            return startPositionTwistUp(config as! PositionTwistUpAnimationConfig)
        case .horizontal180PhotoPanorama:
            return startHorizontal180PhotoPanorama(config as! Horizontal180PhotoPanoramaAnimationCfg)
        case .vertical180PhotoPanorama:
            return startVertical180PhotoPanorama(config as! Vertical180PhotoPanoramaAnimationConfig)
        case .sphericalPhotoPanorama:
            return startSphericalPhotoPanorama(config as! SphericalPhotoPanoramaAnimationConfig)
        case .unidentified:
            break
        }
        return false
    }

    func abortCurrentAnimation() -> Bool {
        sendCommand(ArsdkFeatureAnimation.cancelEncoder())
        return true
    }

}

/// Extension of AnimFeaturePilotingItfController that implements the animation feature callbacks
extension AnimFeaturePilotingItfController: ArsdkFeatureAnimationCallback {

    func onAvailability(valuesBitField: UInt) {
        var availableAnimations: Set<AnimationType> = []
        if ArsdkFeatureAnimationTypeBitField.isSet(.candle, inBitField: valuesBitField) {
            availableAnimations.insert(.candle)
        }
        if ArsdkFeatureAnimationTypeBitField.isSet(.dollySlide, inBitField: valuesBitField) {
            availableAnimations.insert(.dollySlide)
        }
        if ArsdkFeatureAnimationTypeBitField.isSet(.dronie, inBitField: valuesBitField) {
            availableAnimations.insert(.dronie)
        }
        if ArsdkFeatureAnimationTypeBitField.isSet(.flip, inBitField: valuesBitField) {
            availableAnimations.insert(.flip)
        }
        if ArsdkFeatureAnimationTypeBitField.isSet(.horizontalPanorama, inBitField: valuesBitField) {
            availableAnimations.insert(.horizontalPanorama)
        }
        if ArsdkFeatureAnimationTypeBitField.isSet(.horizontalReveal, inBitField: valuesBitField) {
            availableAnimations.insert(.horizontalReveal)
        }
        if ArsdkFeatureAnimationTypeBitField.isSet(.parabola, inBitField: valuesBitField) {
            availableAnimations.insert(.parabola)
        }
        if ArsdkFeatureAnimationTypeBitField.isSet(.spiral, inBitField: valuesBitField) {
            availableAnimations.insert(.spiral)
        }
        if ArsdkFeatureAnimationTypeBitField.isSet(.verticalReveal, inBitField: valuesBitField) {
            availableAnimations.insert(.verticalReveal)
        }
        if ArsdkFeatureAnimationTypeBitField.isSet(.vertigo, inBitField: valuesBitField) {
            availableAnimations.insert(.vertigo)
        }
        if ArsdkFeatureAnimationTypeBitField.isSet(.twistUp, inBitField: valuesBitField) {
            availableAnimations.insert(.twistUp)
        }
        if ArsdkFeatureAnimationTypeBitField.isSet(.positionTwistUp, inBitField: valuesBitField) {
            availableAnimations.insert(.positionTwistUp)
        }
        if ArsdkFeatureAnimationTypeBitField.isSet(.horizontal180PhotoPanorama, inBitField: valuesBitField) {
            availableAnimations.insert(.horizontal180PhotoPanorama)
        }
        if ArsdkFeatureAnimationTypeBitField.isSet(.vertical180PhotoPanorama, inBitField: valuesBitField) {
            availableAnimations.insert(.vertical180PhotoPanorama)
        }
        if ArsdkFeatureAnimationTypeBitField.isSet(.sphericalPhotoPanorama, inBitField: valuesBitField) {
            availableAnimations.insert(.sphericalPhotoPanorama)
        }

        animationPilotingItf.update(availableAnimations: availableAnimations).notifyUpdated()
    }

    func onState(type: ArsdkFeatureAnimationType, percent: UInt) {
        if type == .none {
            animationType = .none
            animationPilotingItf.update(animation: nil).update(progress: 0)
                .notifyUpdated()
        } else if animationType == type {
            animationPilotingItf.update(progress: Int(percent)).notifyUpdated()
        } else if type == .sdkCoreUnknown {
            // in case we don't know the current animation, tell that there is an unknown animation running anyway
            animationType = .sdkCoreUnknown
            animationPilotingItf.update(animation: AnimationCore.Unidentified())
                .update(progress: Int(percent)).notifyUpdated()
        } else {
            ULog.w(.animationTag, "Animation type mismatch: received \(type) but expected \(animationType). \n" +
                "This maybe means that the general state has been received before the specific one.")
        }
    }

    func onCandleState(state: ArsdkFeatureAnimationState, speed: Float, verticalDistance: Float,
                       playMode: ArsdkFeatureAnimationPlayMode) {
        var animation: AnimationCore?
        if state != .idle {
            animationType = .candle
            if let mode = AnimationMode(fromArsdk: playMode) {
            animation = CandleCore(speed: Double(speed), verticalDistance: Double(verticalDistance), mode: mode)
            } else {
                animation = AnimationCore.Unidentified()
            }
            animationPilotingItf.update(animation: animation, status: AnimationStatus.from(state)).notifyUpdated()
        }
    }

    func onDollySlideState(state: ArsdkFeatureAnimationState, speed: Float, angle: Float, horizontalDistance: Float,
                           playMode: ArsdkFeatureAnimationPlayMode) {
        var animation: AnimationCore?
        if state != .idle {
            animationType = .dollySlide
            if let mode = AnimationMode(fromArsdk: playMode) {
                animation = DollySlideCore(
                    speed: Double(speed), angle: Double(angle).toDegrees(),
                    horizontalDistance: Double(horizontalDistance), mode: mode)
            } else {
                animation = AnimationCore.Unidentified()
            }
            animationPilotingItf.update(animation: animation, status: AnimationStatus.from(state)).notifyUpdated()
        }
    }

    func onDronieState(state: ArsdkFeatureAnimationState, speed: Float, distance: Float,
                       playMode: ArsdkFeatureAnimationPlayMode) {
        var animation: AnimationCore?
        if state != .idle {
            animationType = .dronie
            if let mode = AnimationMode(fromArsdk: playMode) {
                animation = DronieCore(speed: Double(speed), distance: Double(distance), mode: mode)
            } else {
                animation = AnimationCore.Unidentified()
            }
            animationPilotingItf.update(animation: animation, status: AnimationStatus.from(state)).notifyUpdated()
        }
    }

    func onFlipState(state: ArsdkFeatureAnimationState, type: ArsdkFeatureAnimationFlipType) {
        var animation: AnimationCore?
        if state != .idle {
            animationType = .flip
            if let direction = FlipAnimationDirection.from(type) {
                animation = FlipCore(direction: direction)
            } else {
                animation = AnimationCore.Unidentified()
            }
            animationPilotingItf.update(animation: animation, status: AnimationStatus.from(state)).notifyUpdated()
        }
    }

    func onHorizontalPanoramaState(state: ArsdkFeatureAnimationState, rotationAngle: Float, rotationSpeed: Float) {
        var animation: AnimationCore?
        if state != .idle {
            animationType = .horizontalPanorama
            animation = HorizontalPanoramaCore(
                rotationAngle: Double(rotationAngle).toDegrees(),
                rotationSpeed: Double(rotationSpeed).toDegrees())
            animationPilotingItf.update(animation: animation, status: AnimationStatus.from(state)).notifyUpdated()
        }
    }

    func onHorizontalRevealState(state: ArsdkFeatureAnimationState, speed: Float, distance: Float,
                                 playMode: ArsdkFeatureAnimationPlayMode) {
        var animation: AnimationCore?
        if state != .idle {
            animationType = .horizontalReveal
            if let mode = AnimationMode(fromArsdk: playMode) {
                animation = HorizontalRevealCore(speed: Double(speed), distance: Double(distance), mode: mode)
            } else {
                animation = AnimationCore.Unidentified()
            }
            animationPilotingItf.update(animation: animation, status: AnimationStatus.from(state)).notifyUpdated()
        }
    }

    func onParabolaState(state: ArsdkFeatureAnimationState, speed: Float, verticalDistance: Float,
                         playMode: ArsdkFeatureAnimationPlayMode) {
        var animation: AnimationCore?
        if state != .idle {
            animationType = .parabola
            if let mode = AnimationMode(fromArsdk: playMode) {
                animation = ParabolaCore(speed: Double(speed), verticalDistance: Double(verticalDistance), mode: mode)
            } else {
                animation = AnimationCore.Unidentified()
            }
            animationPilotingItf.update(animation: animation, status: AnimationStatus.from(state)).notifyUpdated()
        }
    }

    func onSpiralState(state: ArsdkFeatureAnimationState, speed: Float, radiusVariation: Float, verticalDistance: Float,
                       revolutionNb: Float, playMode: ArsdkFeatureAnimationPlayMode) {
        var animation: AnimationCore?
        if state != .idle {
            animationType = .spiral
            if let mode = AnimationMode(fromArsdk: playMode) {
                animation = SpiralCore(
                    speed: Double(speed), radiusVariation: Double(radiusVariation),
                    verticalDistance: Double(verticalDistance), revolutionAmount: Double(revolutionNb), mode: mode)
            } else {
                animation = AnimationCore.Unidentified()
            }
            animationPilotingItf.update(animation: animation, status: AnimationStatus.from(state)).notifyUpdated()
        }
    }

    func onVerticalRevealState(state: ArsdkFeatureAnimationState, speed: Float, verticalDistance: Float,
                               rotationAngle: Float, rotationSpeed: Float, playMode: ArsdkFeatureAnimationPlayMode) {
        var animation: AnimationCore?
        if state != .idle {
            animationType = .verticalReveal
            if let mode = AnimationMode(fromArsdk: playMode) {
                animation = VerticalRevealCore(
                    verticalSpeed: Double(speed), verticalDistance: Double(verticalDistance),
                    rotationAngle: Double(rotationAngle).toDegrees(), rotationSpeed: Double(rotationSpeed).toDegrees(),
                    mode: mode)
            } else {
                animation = AnimationCore.Unidentified()
            }
            animationPilotingItf.update(animation: animation, status: AnimationStatus.from(state)).notifyUpdated()
        }
    }

    func onVertigoState(
        state: ArsdkFeatureAnimationState, duration: Float, maxZoomLevel: Float,
        finishAction: ArsdkFeatureAnimationVertigoFinishAction, playMode: ArsdkFeatureAnimationPlayMode) {

        var animation: AnimationCore?
        if state != .idle {
            animationType = .vertigo
            if let mode = AnimationMode(fromArsdk: playMode),
                let finishAction = VertigoAnimationFinishAction(fromArsdk: finishAction) {

                animation = VertigoCore(
                    duration: Double(duration), maxZoomLevel: Double(maxZoomLevel),
                    finishAction: finishAction, mode: mode)
            } else {
                animation = AnimationCore.Unidentified()
            }
            animationPilotingItf.update(animation: animation, status: AnimationStatus.from(state)).notifyUpdated()
        }
    }

    func onTwistUpState(state: ArsdkFeatureAnimationState, speed: Float, verticalDistance: Float, rotationAngle: Float,
                        rotationSpeed: Float, playMode: ArsdkFeatureAnimationPlayMode) {

        var animation: AnimationCore?
        if state != .idle {
            animationType = .twistUp
            if let mode = AnimationMode(fromArsdk: playMode) {
                animation = GenericTwistUpCore(type: .twistUp, speed: Double(speed),
                                        verticalDistance: Double(verticalDistance),
                                        rotationAngle: Double(rotationAngle).toDegrees(),
                                        rotationSpeed: Double(rotationSpeed).toDegrees(),
                                        mode: mode)
            } else {
                animation = AnimationCore.Unidentified()
            }
            animationPilotingItf.update(animation: animation, status: AnimationStatus.from(state)).notifyUpdated()
        }
    }

    func onPositionTwistUpState(state: ArsdkFeatureAnimationState, speed: Float, verticalDistance: Float,
                                rotationAngle: Float, rotationSpeed: Float,
                                playMode: ArsdkFeatureAnimationPlayMode) {
        var animation: AnimationCore?
        if state != .idle {
            animationType = .positionTwistUp
            if let mode = AnimationMode(fromArsdk: playMode) {
                animation = GenericTwistUpCore(type: .positionTwistUp, speed: Double(speed),
                                        verticalDistance: Double(verticalDistance),
                                        rotationAngle: Double(rotationAngle).toDegrees(),
                                        rotationSpeed: Double(rotationSpeed).toDegrees(),
                                        mode: mode)
            } else {
                animation = AnimationCore.Unidentified()
            }
            animationPilotingItf.update(animation: animation, status: AnimationStatus.from(state)).notifyUpdated()
        }
    }

    func onVertical180PhotoPanoramaState(state: ArsdkFeatureAnimationState) {
        if state != .idle {
            animationType = .vertical180PhotoPanorama
            animationPilotingItf.update(animation: Vertical180PhotoPanoramaCore(),
                                        status: AnimationStatus.from(state)).notifyUpdated()
        }
    }

    func onHorizontal180PhotoPanoramaState(state: ArsdkFeatureAnimationState) {
        if state != .idle {
            animationType = .horizontal180PhotoPanorama
            animationPilotingItf.update(animation: Horizontal180PhotoPanoramaCore(),
                                        status: AnimationStatus.from(state)).notifyUpdated()
        }
    }

    func onSphericalPhotoPanoramaState(state: ArsdkFeatureAnimationState) {
        if state != .idle {
            animationType = .sphericalPhotoPanorama
            animationPilotingItf.update(animation: SphericalPhotoPanoramaCore(),
                                        status: AnimationStatus.from(state)).notifyUpdated()
        }
    }
}

/// Extension of AnimationType that converts ArsdkFeatureAnimationType into AnimationType
extension AnimationType {
    /// Translate an `ArsdkFeatureAnimationType` into an `AnimationType`.
    ///
    /// - Parameter arsdkAnimationType: arsdk animation type
    /// - Returns: the corresponding animation type if found, nil otherwise
    private static func from(_ arsdkAnimationType: ArsdkFeatureAnimationType) -> AnimationType? {
        switch arsdkAnimationType {
        case .candle:
            return .candle
        case .dollySlide:
            return .dollySlide
        case .dronie:
            return .dronie
        case .flip:
            return .flip
        case .horizontalPanorama:
            return .horizontalPanorama
        case .horizontalReveal:
            return .horizontalReveal
        case .parabola:
            return .parabola
        case .spiral:
            return .spiral
        case .verticalReveal:
            return .verticalReveal
        case .vertigo:
            return .vertigo
        case .twistUp:
            return .twistUp
        case .positionTwistUp:
            return .positionTwistUp
        case .horizontal180PhotoPanorama:
            return .horizontal180PhotoPanorama
        case .vertical180PhotoPanorama:
            return .vertical180PhotoPanorama
        case .sphericalPhotoPanorama:
            return .sphericalPhotoPanorama
        case .sdkCoreUnknown,
             .none:
            return nil
        }
    }
}

/// Extension of AnimationStatus that converts ArsdkFeatureAnimationState into AnimationStatus
extension AnimationStatus {
    /// Translate an `ArsdkFeatureAnimationState` into an `AnimationStatus`.
    ///
    /// - Parameter arsdkAnimationState: arsdk animation state
    /// - Returns: the corresponding animation status if found, animating otherwise
    /// - Note: note that as the `idle` value does not exist, if `ArsdkFeatureAnimationState.idle` is given,
    ///  `.animating` will be returned.
    fileprivate static func from(_ arsdkAnimationState: ArsdkFeatureAnimationState) -> AnimationStatus {
        switch arsdkAnimationState {
        case .running:
            return .animating
        case .canceling:
            return .aborting
        default:
            // if we don't handle this state, assume animating
            return .animating
        }
    }
}

/// Extension of AnimationMode that converts ArsdkFeatureAnimationPlayMode into AnimationMode
extension AnimationMode: ArsdkMappableEnum {

    static let arsdkMapper = Mapper<AnimationMode, ArsdkFeatureAnimationPlayMode>([
        .once: .normal,
        .onceThenMirrored: .onceThenMirrored])
}

/// Extension of AnimationMode that converts ArsdkFeatureAnimationPlayMode into AnimationMode
extension VertigoAnimationFinishAction: ArsdkMappableEnum {

    static let arsdkMapper = Mapper<VertigoAnimationFinishAction, ArsdkFeatureAnimationVertigoFinishAction>([
        .none: .none,
        .unzoom: .unzoom])
}

/// Extension of FlipDirection that converts ArsdkFeatureAnimationFlipType into FlipDirection
fileprivate extension FlipAnimationDirection {
    /// Translate an `ArsdkFeatureAnimationFlipType` into an `FlipDirection`.
    ///
    /// - Parameter arsdkDirection: arsdk flip direction
    /// - Returns: the corresponding direction if found, nil otherwise
    static func from(_ arsdkDirection: ArsdkFeatureAnimationFlipType) -> FlipAnimationDirection? {
        switch arsdkDirection {
        case .front:
            return .front
        case .back:
            return .back
        case .left:
            return .left
        case .right:
            return .right
        case .sdkCoreUnknown:
            return nil
        }
    }

    func arsdkVal() -> ArsdkFeatureAnimationFlipType {
        switch self {
        case .front:
            return .front
        case .back:
            return .back
        case .left:
            return .left
        case .right:
            return .right
        }
    }
}
