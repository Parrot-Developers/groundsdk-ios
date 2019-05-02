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

func `is`(_ type: AnimationType) -> Matcher<Animation> {
    return Matcher("type=(\(type.description)") { $0.type == type }
}

func `is`(_ status: AnimationStatus) -> Matcher<Animation> {
    return Matcher("status=(\(status.description)") { $0.status == status }
}

func has(progress: Int) -> Matcher<Animation> {
    return Matcher("progress=(\(progress)") { $0.progress == progress }
}

// MARK: Config
func `is`(_ type: AnimationType) -> Matcher<AnimationConfig> {
    return Matcher("type=(\(type.description)") { $0.type == type }
}

// MARK: Candle
func `is`(speed: Double? = nil, verticalDistance: Double? = nil, mode: AnimationMode? = nil)
    -> Matcher<CandleAnimation> {
        return Matcher("speed=\(String(describing: speed)) && " +
            "verticalDistance=\(String(describing: verticalDistance)) " +
        "mode=\(String(describing: mode?.description)) ") {
            (speed == nil || $0.speed == speed) &&
                (verticalDistance == nil || $0.verticalDistance == verticalDistance) &&
                (mode == nil || $0.mode == mode)
        }
}

// MARK: DollySlide
func `is`(speed: Double? = nil, angle: Double? = nil, horizontalDistance: Double? = nil, mode: AnimationMode? = nil)
    -> Matcher<DollySlideAnimation> {
        return Matcher("speed=\(String(describing: speed)) && " +
            "angle=\(String(describing: angle)) && " +
            "horizontalDistance=\(String(describing: horizontalDistance)) " +
        "mode=\(String(describing: mode?.description)) ") {
            (speed == nil || $0.speed == speed) &&
                (angle == nil || $0.angle == angle) &&
                (horizontalDistance == nil || $0.horizontalDistance == horizontalDistance) &&
                (mode == nil || $0.mode == mode)
        }
}

// MARK: Dronie
func `is`(speed: Double? = nil, distance: Double? = nil, mode: AnimationMode? = nil) -> Matcher<DronieAnimation> {
        return Matcher("speed=\(String(describing: speed)) && " +
            "distance=\(String(describing: distance)) " +
        "mode=\(String(describing: mode?.description)) ") {
            (speed == nil || $0.speed == speed) &&
                (distance == nil || $0.distance == distance) &&
                (mode == nil || $0.mode == mode)
        }
}

// MARK: Flip
func has(direction: FlipAnimationDirection) -> Matcher<FlipAnimation> {
    return Matcher("direction=\(direction)") {
        $0.direction == direction
    }
}

// MARK: HorizontalPanorama
func `is`(rotationAngle: Double? = nil, rotationSpeed: Double? = nil) -> Matcher<HorizontalPanoramaAnimation> {
    return Matcher("rotationAngle=\(String(describing: rotationAngle)) && " +
    "rotationSpeed=\(String(describing: rotationSpeed))") {
        (rotationAngle == nil || $0.rotationAngle == rotationAngle) &&
            (rotationSpeed == nil || $0.rotationSpeed == rotationSpeed)
    }
}

func has(rotationAngle: Double) -> Matcher<HorizontalPanoramaAnimation> {
    return Matcher("rotationAngle=(\(rotationAngle)") { $0.rotationAngle == rotationAngle }
}

func has(rotationSpeed: Double) -> Matcher<HorizontalPanoramaAnimation> {
    return Matcher("rotationSpeed=(\(rotationSpeed)") { $0.rotationSpeed == rotationSpeed }
}

// MARK: HorizontalPanoramaConfig
func has(customRotationAngle: Double) -> Matcher<HorizontalPanoramaAnimationConfig> {
    return Matcher("rotationAngle=(\(customRotationAngle)") {
        $0.rotationAngle != nil && $0.rotationAngle == customRotationAngle
    }
}

func hasDefaultRotationAngle() -> Matcher<HorizontalPanoramaAnimationConfig> {
    return Matcher("default rotation angle") { $0.rotationAngle == nil }
}

func has(customRotationSpeed: Double) -> Matcher<HorizontalPanoramaAnimationConfig> {
    return Matcher("rotationSpeed=(\(customRotationSpeed)") {
        $0.rotationSpeed != nil && $0.rotationSpeed == customRotationSpeed
    }
}

func hasDefaultRotationSpeed() -> Matcher<HorizontalPanoramaAnimationConfig> {
    return Matcher("default rotation speed") { $0.rotationSpeed == nil }
}

// MARK: Vertigo
func `is`(
    duration: Double? = nil, maxZoomLevel: Double? = nil, finishAction: VertigoAnimationFinishAction? = nil,
    mode: AnimationMode? = nil) -> Matcher<VertigoAnimation> {

    var matchers = [Matcher<VertigoAnimation>]()
    if let duration = duration {
        matchers.append(Matcher("duration = \(duration)") {
            $0.duration == duration
        })
    }
    if let maxZoomLevel = maxZoomLevel {
        matchers.append(Matcher("maxZoomLevel = \(maxZoomLevel)") {
            $0.maxZoomLevel == maxZoomLevel
        })
    }
    if let finishAction = finishAction {
        matchers.append(Matcher("finishAction = \(finishAction)") {
            $0.finishAction == finishAction
        })
    }
    if let mode = mode {
        matchers.append(Matcher("mode = \(mode)") {
            $0.mode == mode
        })
    }
    return allOf(matchers)
}

// MARK: TwistUp
func `is`(speed: Double? = nil, verticalDistance: Double? = nil,  rotationAngle: Double? = nil,
          rotationSpeed: Double? = nil, mode: AnimationMode? = nil)
    -> Matcher<TwistUpAnimation> {

        var matchers = [Matcher<TwistUpAnimation>]()
        if let speed = speed {
            matchers.append(Matcher("speed = \(speed)") {
                $0.speed == speed
            })
        }
        if let verticalDistance = verticalDistance {
            matchers.append(Matcher("verticalDistance = \(verticalDistance)") {
                $0.verticalDistance == verticalDistance
            })
        }
        if let rotationAngle = rotationAngle {
            matchers.append(Matcher("rotationAngle = \(rotationAngle)") {
                $0.rotationAngle == rotationAngle
            })
        }
        if let rotationSpeed = rotationSpeed {
            matchers.append(Matcher("rotationSpeed = \(rotationSpeed)") {
                $0.rotationSpeed == rotationSpeed
            })
        }
        if let mode = mode {
            matchers.append(Matcher("mode = \(mode)") {
                $0.mode == mode
            })
        }
        return allOf(matchers)
}

// MARK: PositionTwistUp
func `is`(speed: Double? = nil, verticalDistance: Double? = nil,  rotationAngle: Double? = nil,
          rotationSpeed: Double? = nil, mode: AnimationMode? = nil)
    -> Matcher<PositionTwistUpAnimation> {

        var matchers = [Matcher<PositionTwistUpAnimation>]()
        if let speed = speed {
            matchers.append(Matcher("speed = \(speed)") {
                $0.speed == speed
            })
        }
        if let verticalDistance = verticalDistance {
            matchers.append(Matcher("verticalDistance = \(verticalDistance)") {
                $0.verticalDistance == verticalDistance
            })
        }
        if let rotationAngle = rotationAngle {
            matchers.append(Matcher("rotationAngle = \(rotationAngle)") {
                $0.rotationAngle == rotationAngle
            })
        }
        if let rotationSpeed = rotationSpeed {
            matchers.append(Matcher("rotationSpeed = \(rotationSpeed)") {
                $0.rotationSpeed == rotationSpeed
            })
        }
        if let mode = mode {
            matchers.append(Matcher("mode = \(mode)") {
                $0.mode == mode
            })
        }
        return allOf(matchers)
}

// MARK: VertigoConfig
func `is`(
    duration: Double? = nil, maxZoomLevel: Double? = nil, finishAction: VertigoAnimationFinishAction?,
    mode: AnimationMode? = nil) -> Matcher<VertigoAnimationConfig> {

    var matchers = [Matcher<VertigoAnimationConfig>]()
    if let duration = duration {
        matchers.append(Matcher("duration = \(duration)") {
            $0.duration == duration
        })
    } else {
        matchers.append(Matcher("duration is not custom") {
            $0.duration == nil
        })
    }
    if let maxZoomLevel = maxZoomLevel {
        matchers.append(Matcher("maxZoomLevel = \(maxZoomLevel)") {
            $0.maxZoomLevel == maxZoomLevel
        })
    } else {
        matchers.append(Matcher("maxZoomLevel is not custom") {
            $0.maxZoomLevel == nil
        })
    }
    if let finishAction = finishAction {
        matchers.append(Matcher("finishAction = \(finishAction)") {
            $0.finishAction == finishAction
        })
    } else {
        matchers.append(Matcher("finishAction is not custom") {
            $0.finishAction == nil
        })
    }
    if let mode = mode {
        matchers.append(Matcher("mode = \(mode)") {
            $0.mode == mode
        })
    } else {
        matchers.append(Matcher("mode is not custom") {
            $0.mode == nil
        })
    }
    return allOf(matchers)
}
