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

/// Base protocol for all Piloting interfaces components.
@objc(GSPilotingItf)
public protocol PilotingItf: Component {
}

/// PilotingInteface component descriptor.
public protocol PilotingItfClassDesc: ComponentApiDescriptor {
    /// Protocol of the piloting interface.
    associatedtype ApiProtocol = PilotingItf
}

/// Defines all known Piloting Interfaces descriptors.
@objcMembers
@objc(GSPilotingItfs)
public class PilotingItfs: NSObject {
    /// Piloting interface of a copter for manual piloting.
    public static let manualCopter = ManualCopterPilotingItfs()
    /// Piloting interface for the return home feature.
    public static let returnHome = ReturnHomePilotingItfs()
    /// Piloting interface for the flight plan.
    public static let flightPlan = FlightPlanPilotingItfs()
    /// Piloting interface for the animations.
    public static let animation = AnimationPilotingItfs()
    /// Piloting interface for guided piloting.
    public static let guided = GuidedPilotingItfs()
    /// Piloting interface for Point Of Interest piloting.
    public static let pointOfInterest = PointOfInterestPilotingItfs()
    /// Piloting interface for LookAt Mode.
    public static let lookAt = LookAtPilotingItfs()
    /// Piloting interface for FollowMe mode.
    public static let followMe = FollowMePilotingItfs()
}

/// Piloting interfaces uid.
enum PilotingItfUid: Int {
    case manualCopter
    case returnHome
    case flightPlan
    case animation
    case guided
    case pointOfInterest
    case lookAt
    case followMe
}

/// Objective-C wrapper of Ref<PilotingItf>. Required because swift generics can't be used from Objective-C.
/// - Note: This class is for Objective-C only and must not be used in Swift.
@objcMembers
public class GSPilotingItfRef: NSObject {
    let ref: Ref<PilotingItf>

    /// Referenced piloting interface.
    public var value: PilotingItf? {
        return ref.value
    }

    /// Constructor.
    ///
    /// - Parameter ref: referenced piloting interface
    init(ref: Ref<PilotingItf>) {
        self.ref = ref
    }
}
