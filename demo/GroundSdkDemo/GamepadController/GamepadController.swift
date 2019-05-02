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

/// Protocol that handles gamepad actions
protocol GamepadControllerBackend {
    var leftThumbstickMoveHandler: GCControllerDirectionPadValueChangedHandler? { get }
    var rightThumbstickMoveHandler: GCControllerDirectionPadValueChangedHandler? { get }
    var buttonAPressedHandler: GCControllerButtonValueChangedHandler? { get }
    var buttonBPressedHandler: GCControllerButtonValueChangedHandler? { get }
    var buttonXPressedHandler: GCControllerButtonValueChangedHandler? { get }
    var buttonYPressedHandler: GCControllerButtonValueChangedHandler? { get }

    /// Should put the drone in a waiting state
    func reset()
}

/// Singleton class that handles GCController.
/// The GamepadController uses the connected gamepad or search for a new one
/// It will pilot the given drone.
class GamepadController {

    /// Singleton instance
    static var sharedInstance = GamepadController()

    /// Name of the notification sent when a Gamecontroller did connect
    static let GamepadDidConnect = "GamepadDidConnect"

    /// Name of the notification sent when the Gamecontroller did disconnect
    static let GamepadDidDisconnect = "GamepadDidDisconnect"

    private var gcController: GCController?
    var gamepadIsConnected: Bool {
        return gcController != nil
    }

    private var backends: [GamepadControllerBackend] = []

    private let groundSdk = GroundSdk()
    var droneUid: String? = nil {
        didSet {
            if let droneUid = droneUid {
                let drone = groundSdk.getDrone(uid: droneUid)
                if let drone = drone {
                    self.backends.append(CopterGpControllerBackend(drone: drone))
                    self.backends.append(ReturnHomeGpControllerBackend(drone: drone))
                }
            } else {
                for backend in backends {
                    backend.reset()
                }
                backends.removeAll()
            }
        }
    }

    private init() {
        initGcControllerWithCurrentGamepad()
        listenToGcConnections()
    }

    deinit {
        stopListeningToGcConnections()
        unbindHandlersToGcController()
    }

    private func listenToGcConnections() {
        NotificationCenter.default.addObserver(self, selector: #selector(gcControllerDidConnect(_:)),
            name: NSNotification.Name.GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(gcControllerDidDisconnect(_:)),
            name: NSNotification.Name.GCControllerDidDisconnect, object: nil)
    }

    private func stopListeningToGcConnections() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.GCControllerDidConnect, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.GCControllerDidDisconnect,
            object: nil)
    }

    private func initGcControllerWithCurrentGamepad() {
        for controller in GCController.controllers() where controller.extendedGamepad != nil {
            set(gcController: controller)
            break
        }
    }

    private func set(gcController: GCController?) {
        self.gcController = gcController
        if self.gcController != nil {
            bindHandlersToGcController()
            NotificationCenter.default.post(
                name: Notification.Name(rawValue: GamepadController.GamepadDidConnect), object: nil)
        } else {
            for backend in backends {
                backend.reset()
            }
            NotificationCenter.default.post(
                name: Notification.Name(rawValue: GamepadController.GamepadDidDisconnect), object: nil)
        }
    }

    @objc
    private func gcControllerDidConnect(_ notif: Notification) {
        let connectedGcController = notif.object as? GCController
        if gcController == nil && connectedGcController?.extendedGamepad != nil {
            set(gcController: connectedGcController)
        }
    }

    @objc
    private func gcControllerDidDisconnect(_ notif: Notification) {
        let disconnectedGcController = notif.object as? GCController
        if gcController == disconnectedGcController {
            set(gcController: nil)
        }
    }
}

// Gamepad handler extension
extension GamepadController {
    var leftThumbstickMoveHandler: GCControllerDirectionPadValueChangedHandler {
        return {
            [unowned self](dpad, xValue, yValue) in
            for backend in self.backends {
                backend.leftThumbstickMoveHandler?(dpad, xValue, yValue)
            }
        }
    }

    var rightThumbstickMoveHandler: GCControllerDirectionPadValueChangedHandler {
        return {
            [unowned self](dpad, xValue, yValue) in
            for backend in self.backends {
                backend.rightThumbstickMoveHandler?(dpad, xValue, yValue)
            }
        }
    }

    var buttonAPressedHandler: GCControllerButtonValueChangedHandler {
        return {
            [unowned self](gamepad, element, pressed) in
            for backend in self.backends {
                backend.buttonAPressedHandler?(gamepad, element, pressed)
            }
        }
    }

    var buttonBPressedHandler: GCControllerButtonValueChangedHandler {
        return {
            [unowned self](gamepad, element, pressed) in
            for backend in self.backends {
                backend.buttonBPressedHandler?(gamepad, element, pressed)
            }
        }
    }

    var buttonXPressedHandler: GCControllerButtonValueChangedHandler {
        return {
            [unowned self](gamepad, element, pressed) in
            for backend in self.backends {
                backend.buttonXPressedHandler?(gamepad, element, pressed)
            }
        }
    }

    var buttonYPressedHandler: GCControllerButtonValueChangedHandler {
        return {
            [unowned self](gamepad, element, pressed) in
            for backend in self.backends {
                backend.buttonYPressedHandler?(gamepad, element, pressed)
            }
        }
    }

    private func bindHandlersToGcController() {
        if let gcController = gcController {
            gcController.extendedGamepad?.buttonA.pressedChangedHandler = buttonAPressedHandler
            gcController.extendedGamepad?.buttonB.pressedChangedHandler = buttonBPressedHandler
            gcController.extendedGamepad?.buttonX.pressedChangedHandler = buttonXPressedHandler
            gcController.extendedGamepad?.buttonY.pressedChangedHandler = buttonYPressedHandler
            gcController.extendedGamepad?.leftThumbstick.valueChangedHandler = leftThumbstickMoveHandler
            gcController.extendedGamepad?.rightThumbstick.valueChangedHandler = rightThumbstickMoveHandler
        }
    }

    private func unbindHandlersToGcController() {
        if let gcController = gcController {
            gcController.extendedGamepad?.buttonA.pressedChangedHandler = nil
            gcController.extendedGamepad?.buttonB.pressedChangedHandler = nil
            gcController.extendedGamepad?.buttonX.pressedChangedHandler = nil
            gcController.extendedGamepad?.buttonY.pressedChangedHandler = nil
            gcController.extendedGamepad?.leftThumbstick.valueChangedHandler = nil
            gcController.extendedGamepad?.rightThumbstick.valueChangedHandler = nil
        }
    }
}
