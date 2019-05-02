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

/// Activable piloting interface state.
/// There is only one piloting interface active at a time on a drone.
@objc(GSActivablePilotingItfState)
public enum ActivablePilotingItfState: Int, CustomStringConvertible {
    /// Piloting interface is available and is not the active one.
    case idle
    /// Piloting interface is the active one.
    case active
    /// Piloting interface is not available at this time.
    case unavailable

    /// Debug description.
    public var description: String {
        switch self {
        case .idle:         return "idle"
        case .active:       return "active"
        case .unavailable:  return "unavailable"
        }
    }
}

/// Base protocol for the piloting interfaces components that can be activated or deactivated.
@objc(GSActivablePilotingItf)
public protocol ActivablePilotingItf: class {
    /// Piloting interface state. There is only one piloting interface active at a time on a drone.
    var state: ActivablePilotingItfState { get }

    /// Deactivates this piloting interface.
    ///
    /// This will activate an other piloting interface (usually the default one)
    /// - Returns: `true` on success, `false` if the piloting interface can't be deactivated
    func deactivate() -> Bool
}
