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

import UIKit
import GroundSdk

class AnimationPilotingItfCell: PilotingItfProviderContentCell {

    @IBOutlet weak var availableAnims: UILabel!
    @IBOutlet weak var currentAnim: UILabel!
    @IBOutlet weak var status: UILabel!
    @IBOutlet weak var progress: UILabel!
    @IBOutlet weak var startBt: UIButton!
    @IBOutlet weak var abortBt: UIButton!

    private var pilotingItf: Ref<AnimationPilotingItf>?

    private var availableAnimations: [AnimationType] = []

    var viewController: UIViewController?

    override func set(pilotingItfProvider provider: PilotingItfProvider) {
        super.set(pilotingItfProvider: provider)
        pilotingItf = provider.getPilotingItf(PilotingItfs.animation) { [weak self] pilotingItf in
            if let `self` = self {
                if let pilotingItf = pilotingItf {
                    self.show()

                    self.availableAnimations = pilotingItf.availableAnimations.map { $0 }
                    let availableAnimsStr = pilotingItf.availableAnimations.map { $0.description }
                        .joined(separator: ", ")
                    self.availableAnims.text = "\(availableAnimsStr)"

                    if let animation = pilotingItf.animation {
                        self.currentAnim.text = "\(animation.type.description)"
                        self.status.text = "\(animation.status.description)"
                        self.progress.text = "\(animation.progress)%"
                    } else {
                        self.currentAnim.text = ""
                        self.status.text = ""
                        self.progress.text = "0%"
                    }

                    self.startBt.isEnabled = !self.availableAnimations.isEmpty
                    self.abortBt.isEnabled = pilotingItf.animation != nil

                } else {
                    self.hide()
                }
            }
        }
    }

    @IBAction func startPushed(_ sender: Any) {
        if !availableAnimations.isEmpty {
            let alert = UIAlertController(
                title: "Start animation", message: "Chose the preconfigured animation to use.",
                preferredStyle: .actionSheet)

            for animationType in availableAnimations {
                var config: AnimationConfig?
                switch animationType {
                case .candle:
                    config = CandleAnimationConfig()
                case .dollySlide:
                    config = DollySlideAnimationConfig()
                case .dronie:
                    config = DronieAnimationConfig()
                case .flip:
                    config = FlipAnimationConfig(direction: .front)
                case .horizontalPanorama:
                    config = HorizontalPanoramaAnimationConfig()
                case .horizontalReveal:
                    config = HorizontalRevealAnimationConfig()
                case .parabola:
                    config = ParabolaAnimationConfig()
                case .spiral:
                    config = SpiralAnimationConfig()
                case .verticalReveal:
                    config = VerticalRevealAnimationConfig()
                case .vertigo:
                    config = VertigoAnimationConfig()
                case .twistUp:
                    config = TwistUpAnimationConfig()
                case .positionTwistUp:
                    config = PositionTwistUpAnimationConfig()
                case .horizontal180PhotoPanorama:
                    config = Horizontal180PhotoPanoramaAnimationCfg()
                case .vertical180PhotoPanorama:
                    config = Vertical180PhotoPanoramaAnimationConfig()
                case .sphericalPhotoPanorama:
                    config = SphericalPhotoPanoramaAnimationConfig()
                case .unidentified:
                    config = nil
                }
                if let config = config {
                    let handler: (UIAlertAction) -> Void = { [weak self] action in
                        _ = self?.pilotingItf?.value?.startAnimation(config: config)
                    }
                    alert.addAction(UIAlertAction(title: animationType.description, style: .default, handler: handler))
                }
            }
            if let presenter = alert.popoverPresentationController {
                presenter.sourceView = self
                presenter.sourceRect = self.bounds
            }

            viewController?.present(alert, animated: true, completion: nil)
        }
    }

    @IBAction func abortPushed(_ sender: Any) {
        if let pilotingItf = pilotingItf?.value {
            _ = pilotingItf.abortCurrentAnimation()
        }
    }
}
