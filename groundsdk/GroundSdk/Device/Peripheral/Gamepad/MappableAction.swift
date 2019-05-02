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

/// An action that may be triggered when the gamepad inputs generate a specific set of button events.
///
/// Actions starting with appAction don't occur on the connected drone but are forwarded to the application
/// as `NSNotification` (see `GsdkActionGamepadAppAction`).
///
/// Other actions are predefined actions that are executed by the connected drone.
@objc(GSButtonsMappableAction)
public enum ButtonsMappableAction: Int {

    /// Triggers a `NSNotification`
    ///
    /// Notification key is `NSNotification.Name.GsdkActionGamepadAppAction` and the userInfo of the notification
    /// contains `.appActionSettings` for the key `GsdkActionGamepadAppActionKey`.
    /// This app action should open the settings in your application.
    case appActionSettings

    /// Triggers a `NSNotification`
    ///
    /// Notification key is `NSNotification.Name.GsdkActionGamepadAppAction` and the userInfo of the notification
    /// contains `.appAction1` for the key `GsdkActionGamepadAppActionKey`.
    case appAction1

    /// Triggers a `NSNotification`
    ///
    /// Notification key is `NSNotification.Name.GsdkActionGamepadAppAction` and the userInfo of the notification
    /// contains `.appAction2` for the key `GsdkActionGamepadAppActionKey`.
    case appAction2

    /// Triggers a `NSNotification`
    ///
    /// Notification key is `NSNotification.Name.GsdkActionGamepadAppAction` and the userInfo of the notification
    /// contains `.appAction3` for the key `GsdkActionGamepadAppActionKey`.
    case appAction3

    /// Triggers a `NSNotification`
    ///
    /// Notification key is `NSNotification.Name.GsdkActionGamepadAppAction` and the userInfo of the notification
    /// contains `.appAction4` for the key `GsdkActionGamepadAppActionKey`.
    case appAction4

    /// Triggers a `NSNotification`
    ///
    /// Notification key is `NSNotification.Name.GsdkActionGamepadAppAction` and the userInfo of the notification
    /// contains `.appAction5` for the key `GsdkActionGamepadAppActionKey`.
    case appAction5

    /// Triggers a `NSNotification`
    ///
    /// Notification key is `NSNotification.Name.GsdkActionGamepadAppAction` and the userInfo of the notification
    /// contains `.appAction6` for the key `GsdkActionGamepadAppActionKey`.
    case appAction6

    /// Triggers a `NSNotification`
    ///
    /// Notification key is `NSNotification.Name.GsdkActionGamepadAppAction` and the userInfo of the notification
    /// contains `.appAction7` for the key `GsdkActionGamepadAppActionKey`.
    case appAction7

    /// Triggers a `NSNotification`
    ///
    /// Notification key is `NSNotification.Name.GsdkActionGamepadAppAction` and the userInfo of the notification
    /// contains `.appAction8` for the key `GsdkActionGamepadAppActionKey`.
    case appAction8

    /// Triggers a `NSNotification`
    ///
    /// Notification key is `NSNotification.Name.GsdkActionGamepadAppAction` and the userInfo of the notification
    /// contains `.appAction9` for the key `GsdkActionGamepadAppActionKey`.
    case appAction9

    /// Triggers a `NSNotification`
    ///
    /// Notification key is `NSNotification.Name.GsdkActionGamepadAppAction` and the userInfo of the notification
    /// contains `.appAction10` for the key `GsdkActionGamepadAppActionKey`.
    case appAction10

    /// Triggers a `NSNotification`
    ///
    /// Notification key is `NSNotification.Name.GsdkActionGamepadAppAction` and the userInfo of the notification
    /// contains `.appAction11` for the key `GsdkActionGamepadAppActionKey`.
    case appAction11

    /// Triggers a `NSNotification`
    ///
    /// Notification key is `NSNotification.Name.GsdkActionGamepadAppAction` and the userInfo of the notification
    /// contains `.appAction12` for the key `GsdkActionGamepadAppActionKey`.
    case appAction12

    /// Triggers a `NSNotification`
    ///
    /// Notification key is `NSNotification.Name.GsdkActionGamepadAppAction` and the userInfo of the notification
    /// contains `.appAction13` for the key `GsdkActionGamepadAppActionKey`.
    case appAction13

    /// Triggers a `NSNotification`
    ///
    /// Notification key is `NSNotification.Name.GsdkActionGamepadAppAction` and the userInfo of the notification
    /// contains `.appAction14` for the key `GsdkActionGamepadAppActionKey`.
    case appAction14

    /// Triggers a `NSNotification`
    ///
    /// Notification key is `NSNotification.Name.GsdkActionGamepadAppAction` and the userInfo of the notification
    /// contains `.appAction15` for the key `GsdkActionGamepadAppActionKey`.
    case appAction15

    /// Commands the connected drone to return home
    case returnHome

    /// Commands the connected drone to take off or land (depending on its current state)
    case takeOffOrLand

    /// Commands the connected drone to start or stop recording the video (depending on its current state)
    case recordVideo

    /// Commands the connected drone to take a picture
    case takePicture

    /// Commands the connected drone to, either take a photo (in case the camera is in picture mode), or start/stop
    /// video recording (in case the camera is in recording mode)
    case photoOrVideo

    /// Commands the connected drone to center its camera
    case centerCamera

    /// Commands the connected drone to increase the camera exposition
    case increaseCameraExposition

    /// Commands the connected drone to decrease the camera exposition
    case decreaseCameraExposition

    /// Commands the connected drone to perform a left flip
    case flipLeft

    /// Commands the connected drone to perform a right flip
    case flipRight

    /// Commands the connected drone to perform a front flip
    case flipFront

    /// Commands the connected drone to perform a back flip
    case flipBack

    /// Commands the connected drone to perform an emergency motor cut-off
    case emergencyCutOff

    /// Commands the controller to cycle between different configurations of the HUD on the external HDMI display (if
    /// present and supported by the controller
    case cycleHud

    /// Debug description.
    public var description: String {
        switch self {
        case .appActionSettings:        return "appActionSettings"
        case .appAction1:               return "appAction1"
        case .appAction2:               return "appAction2"
        case .appAction3:               return "appAction3"
        case .appAction4:               return "appAction4"
        case .appAction5:               return "appAction5"
        case .appAction6:               return "appAction6"
        case .appAction7:               return "appAction7"
        case .appAction8:               return "appAction8"
        case .appAction9:               return "appAction9"
        case .appAction10:              return "appAction10"
        case .appAction11:              return "appAction11"
        case .appAction12:              return "appAction12"
        case .appAction13:              return "appAction13"
        case .appAction14:              return "appAction14"
        case .appAction15:              return "appAction15"
        case .returnHome:               return "returnHome"
        case .takeOffOrLand:            return "takeOffOrLand"
        case .recordVideo:              return "recordVideo"
        case .takePicture:              return "takePicture"
        case .photoOrVideo:             return "photoOrVideo"
        case .centerCamera:             return "centerCamera"
        case .increaseCameraExposition: return "increaseCameraExposition"
        case .decreaseCameraExposition: return "decreaseCameraExposition"
        case .flipLeft:                 return "flipLeft"
        case .flipRight:                return "flipRight"
        case .flipFront:                return "flipFront"
        case .flipBack:                 return "flipBack"
        case .emergencyCutOff:          return "emergencyCutOff"
        case .cycleHud:                 return "cycleHud"
        }
    }

    /// Set containing all possible buttons mappable actions.
    public static let allCases: Set<ButtonsMappableAction> =
        [.appActionSettings, .appAction1, .appAction2, .appAction3, .appAction4, .appAction5, .appAction6, .appAction7,
         .appAction8, .appAction9, .appAction10, .appAction11, .appAction12, .appAction13, .appAction14, .appAction15,
         .returnHome, .takeOffOrLand, .recordVideo, .takePicture, .photoOrVideo, .centerCamera,
         .increaseCameraExposition, .decreaseCameraExposition, .flipLeft, .flipRight, .flipFront, .flipBack,
         .emergencyCutOff, .cycleHud]
}

/// An action that may be triggered when the gamepad inputs generate a specific axis event, optionally in conjunction
/// with a specific set of button events.
///
/// Those are predefined actions that are executed by the connected drone.
@objc(GSAxisMappableAction)
public enum AxisMappableAction: Int {

    /// Controls the connected drone roll.
    case controlRoll

    /// Controls the connected drone pitch.
    case controlPitch

    /// Controls the connected drone yaw rotation speed.
    case controlYawRotationSpeed

    /// Controls the connected drone vertical speed.
    case controlThrottle

    /// Controls the connected drone camera pan.
    case panCamera

    /// Controls the connected drone camera tilt.
    case tiltCamera

    /// Controls the connected drone camera zoom.
    case zoomCamera

    /// Debug description.
    public var description: String {
        switch self {
        case .controlRoll:              return "controlRoll"
        case .controlPitch:             return "controlPitch"
        case .controlYawRotationSpeed:	return "controlYawRotationSpeed"
        case .controlThrottle:          return "controlThrottle"
        case .panCamera:                return "panCamera"
        case .tiltCamera:               return "tiltCamera"
        case .zoomCamera:               return "zoomCamera"
        }
    }

    /// Set containing all possible axis mappable actions.
    public static let allCases: Set<AxisMappableAction> =
        [.controlRoll, .controlPitch, .controlYawRotationSpeed, .controlThrottle, .panCamera, .tiltCamera, .zoomCamera]
}
