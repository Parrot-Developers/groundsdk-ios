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
import GameController

class CopterGpControllerBackend: GamepadControllerBackend {

    let manualPilotingItf: Ref<ManualCopterPilotingItf>?

    init(drone: Drone) {
        manualPilotingItf = drone.getPilotingItf(PilotingItfs.manualCopter) { _ in }
    }

    var leftThumbstickMoveHandler: GCControllerDirectionPadValueChangedHandler? {
        return {
            [unowned self]
            (dpad, xValue, yValue) in

            if let pilotingItf = self.manualPilotingItf?.value {
                pilotingItf.set(pitch: -Int(yValue * 100))
                pilotingItf.set(roll: Int(xValue * 100))
            }
        }
    }

    var rightThumbstickMoveHandler: GCControllerDirectionPadValueChangedHandler? {
        return {
            [unowned self]
            (dpad, xValue, yValue) in

            if let pilotingItf = self.manualPilotingItf?.value {
                pilotingItf.set(verticalSpeed: Int(yValue * 100))
                pilotingItf.set(yawRotationSpeed: Int(xValue * 100))
            }
        }
    }

    var buttonAPressedHandler: GCControllerButtonValueChangedHandler? {
        return {
            [unowned self]
            (gamepad, element, pressed) in

            if pressed {
                if let pilotingItf = self.manualPilotingItf?.value {
                    pilotingItf.smartTakeOffLand()
                }
            }
        }
    }

    var buttonBPressedHandler: GCControllerButtonValueChangedHandler? {
        return nil
    }

    var buttonXPressedHandler: GCControllerButtonValueChangedHandler? {
        return nil
    }

    var buttonYPressedHandler: GCControllerButtonValueChangedHandler? {
        return nil
    }

    func reset() {
        if let pilotingItf = self.manualPilotingItf?.value {
            pilotingItf.set(verticalSpeed: 0)
            pilotingItf.set(yawRotationSpeed: 0)
            pilotingItf.hover()
        }
    }
}
