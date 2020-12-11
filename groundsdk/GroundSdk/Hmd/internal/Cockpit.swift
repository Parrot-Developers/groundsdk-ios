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

/// Parameters used according to the model of CockpitGlasses used
public enum Cockpit {
    /// Parrot CockpitGlasses1 (Bebop, Disco)
    case glasses1
    /// Parrot CockpitGlasses2 (Bebop Power, Anafi)
    case glasses2

    /// Prefix uses for ressources in th Bundle
    func filePrefix () -> String {
        switch self {
        case .glasses1:
            return "cockpitg1_"
        case .glasses2:
            return "cockpitg2_"
        }
    }
    /// Interval allowed for interpupillary distance
    var minMaxInterpupillaryDistanceMM: ClosedRange<CGFloat> {
        switch self {
        case .glasses1:
            return (63 ... 63)
        case .glasses2:
            return (62 ... 67)
        }
    }
    /// Default interpupillary distance
    var defaultInterpupillaryDistanceMM: CGFloat {
        switch self {
        case .glasses1:
            return 63
        case .glasses2:
            return 62
        }
    }
    /// Correction of chromatic aberration (applied at the shader level)
    var calculatedDistScaleFactor: (red: Float, green: Float, blue: Float) {
        switch self {
        case .glasses1:
            return (1, 1, 1)
        case .glasses2:
            return (0.995, 1, 1.009)
        }
    }
}
