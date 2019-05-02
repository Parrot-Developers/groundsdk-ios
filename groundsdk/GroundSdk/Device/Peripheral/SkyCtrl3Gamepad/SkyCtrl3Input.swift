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

/// A physical button that can be grabbed on a `RemoteControl.Model.skyCtrl3` gamepad.
@objc(GSSkyCtrl3Button)
public enum SkyCtrl3Button: Int {

    /// Top-most button on the front of the controller, immediately above frontBottomButton, featuring a return-home
    /// icon print.
    /// Produces `SkyCtrl3ButtonEvent.frontTopButton` events when grabbed.
    case frontTopButton

    /// Bottom-most button on the front of the controller, immediately below frontTopButton, featuring a takeoff/land
    /// icon print.
    /// Produces `SkyCtrl3ButtonEvent.frontBottomButton` events when grabbed.
    case frontBottomButton

    /// Left-most button on the rear of the controller, immediately above AxisLeftSlider, featuring a centering icon
    /// print.
    /// Produces:
    /// * `SkyCtrl3ButtonEvent.rearLeftButton` events when grabbed
    /// * `VirtualGamepadEvent.ok` events when `VirtualGamepad` peripheral is grabbed
    case rearLeftButton

    /// Right-most button on the rear of the controller, immediately above AxisRightSlider, featuring a
    /// take-photo/record icon print.
    /// Produces:
    /// * `SkyCtrl3ButtonEvent.rearRightButton` events when grabbed
    /// * `VirtualGamepadEvent.cancel` events when `VirtualGamepad` peripheral is grabbed
    case rearRightButton

    /// Set containing all possible buttons.
    public static let allCases: Set<SkyCtrl3Button> = [
        .frontTopButton, .frontBottomButton, .rearLeftButton, .rearRightButton]

    /// Debug description.
    public var description: String {
        switch self {
        case .frontTopButton:    return "frontTopButton"
        case .frontBottomButton: return "frontBottomButton"
        case .rearLeftButton:    return "rearLeftButton"
        case .rearRightButton:   return "rearRightButton"
        }
    }
}

/// A physical axis that can be grabbed on a `RemoteControl.Model.skyCtrl3` gamepad.
@objc(GSSkyCtrl3Axis)
public enum SkyCtrl3Axis: Int {
    /// Horizontal (left/right) axis of the left control stick.
    /// Produces:
    /// * `SkyCtrl3ButtonEvent.leftStickLeft` and `SkyCtrl3ButtonEvent.leftStickRight` events when grabbed
    /// * `VirtualGamepadEvent.left` and `VirtualGamepadEvent.right` events when `VirtualGamepad` peripheral is grabbed
    case leftStickHorizontal

    /// Vertical (down/up) axis of the left control stick.
    /// Produces:
    /// * `SkyCtrl3ButtonEvent.leftStickDown` and `SkyCtrl3ButtonEvent.leftStickUp` events when grabbed
    /// * `VirtualGamepadEvent.down` and `VirtualGamepadEvent.up` events when `VirtualGamepad` peripheral is grabbed
    case leftStickVertical

    /// Horizontal (left/right) axis of the right control stick.
    /// Produces `SkyCtrl3ButtonEvent.rightStickLeft` and `SkyCtrl3ButtonEvent.rightStickRight` events when grabbed
    case rightStickHorizontal

    /// Vertical (down/up) axis of the right control stick.
    /// Produces `SkyCtrl3ButtonEvent.rightStickDown` and `SkyCtrl3ButtonEvent.rightStickUp` events when grabbed
    case rightStickVertical

    /// Slider on the rear, to the left of the controller, immediately below rearLeftButton, featuring a gimbal icon
    /// print.
    /// Produces `SkyCtrl3ButtonEvent.leftSliderUp` and `SkyCtrl3ButtonEvent.leftSliderDown` events when grabbed
    case leftSlider

    /// Slider on the rear, to the right of the controller, immediately below rearRightButton, featuring a zoom icon
    /// print.
    /// Produces `SkyCtrl3ButtonEvent.rightSliderUp` and `SkyCtrl3ButtonEvent.rightSliderDown` events when grabbed
    case rightSlider

    /// Set containing all possible axes.
    public static let allCases: Set<SkyCtrl3Axis> = [
        .leftStickHorizontal, .leftStickVertical, .rightStickHorizontal, .rightStickVertical, .leftSlider, .rightSlider]

    /// Debug description.
    public var description: String {
        switch self {
        case .leftStickHorizontal:  return "leftStickHorizontal"
        case .leftStickVertical:    return "leftStickVertical"
        case .rightStickHorizontal: return "rightStickHorizontal"
        case .rightStickVertical:   return "rightStickVertical"
        case .leftSlider:           return "leftSlider"
        case .rightSlider:          return "rightSlider"
        }
    }
}

/// Wrapper around a Set of `GSSkyCtrl3Button`.
/// This is only for Objective-C use.
@objcMembers
public class GSSkyCtrl3ButtonSet: NSObject {
    let set: Set<SkyCtrl3Button>

    /// Constructor.
    ///
    /// - Parameter buttons: list of all buttons
    init(buttons: SkyCtrl3Button...) {
        set = Set(buttons)
    }

    /// Swift Constructor.
    ///
    /// - Parameter buttonSet: set of all buttons
    init(buttonSet: Set<SkyCtrl3Button>) {
        set = buttonSet
    }

    /// Tells whether a given button is contained in the set.
    ///
    /// - Parameter button: the button
    /// - Returns: `true` if the set contains the button
    public func contains(_ button: SkyCtrl3Button) -> Bool {
        return set.contains(button)
    }
}

/// Wrapper around a Set of `GSSkyCtrl3AxisSet`.
/// This is only for Objective-C use.
@objcMembers
public class GSSkyCtrl3AxisSet: NSObject {
    let set: Set<SkyCtrl3Axis>

    /// Constructor.
    ///
    /// - Parameter axes: list of all axes
    init(axes: SkyCtrl3Axis...) {
        set = Set(axes)
    }

    /// Swift Constructor.
    ///
    /// - Parameter axisSet: set of all axes
    init(axisSet: Set<SkyCtrl3Axis>) {
        set = axisSet
    }

    /// Tells whether a given axis is contained in the set.
    ///
    /// - Parameter axis: the axis
    /// - Returns: `true` if the set contains the axis
    public func contains(_ axis: SkyCtrl3Axis) -> Bool {
        return set.contains(axis)
    }
}
