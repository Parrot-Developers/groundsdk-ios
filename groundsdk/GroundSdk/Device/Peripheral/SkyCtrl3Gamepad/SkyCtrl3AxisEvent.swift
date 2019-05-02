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

/// An event that may be produced by a `RemoteControl.Model.skyCtrl3` gamepad input when grabbed.
///
/// The corresponding input has an axis behavior, i.e. it has a position in some range, and an event is sent each time
/// that position changes, along with the current position value linearly scaled in a [-100, 100] range.
@objc(GSSkyCtrl3AxisEvent)
public enum SkyCtrl3AxisEvent: Int {
    /// Event sent when the `SkyCtrl3Axis.leftStickHorizontal` is moved.
    case leftStickHorizontal

    /// Event sent when the `SkyCtrl3Axis.leftStickVertical` is moved.
    case leftStickVertical

    /// Event sent when the `SkyCtrl3Axis.rightStickHorizontal` is moved.
    case rightStickHorizontal

    /// Event sent when the `SkyCtrl3Axis.rightStickVertical` is moved.
    case rightStickVertical

    /// Event sent when the `SkyCtrl3Axis.leftSlider` is moved.
    case leftSlider

    /// Event sent when the `SkyCtrl3Axis.rightSlider` is moved
    case rightSlider

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
