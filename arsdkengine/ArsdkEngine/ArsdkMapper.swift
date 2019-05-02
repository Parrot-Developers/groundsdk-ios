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

/// Protocol an enum can conform to, to be mappable to/from an ArsdkEnum
protocol ArsdkMappableEnum {
    /// Type of the mappable enum
    associatedtype EnumType: Hashable
    /// Arsdk type this enum maps to
    associatedtype ArsdkType: Hashable

    /// Arsdk value corresponding to the enum value
    var arsdkValue: ArsdkType? { get }

    /// Create a enum from an arsdk enum value
    ///
    /// - Parameter arsdkValue: arsdk enum value
    init?(fromArsdk arsdkValue: ArsdkType)

    /// Mapper. Enum conforming to this protocol must create the Mapper.
    static var arsdkMapper: Mapper<EnumType, ArsdkType> { get }
}

// ArsdkMappableEnum default implementation
extension ArsdkMappableEnum where EnumType == Self {
    /// Arsdk value corresponding to the enum value using the mapper instance
    var arsdkValue: ArsdkType? {
        return Self.arsdkMapper.map(from: self)
    }

    /// Create a enum from an arsdk enum value using the mapper instance
    ///
    /// - Parameter arsdkValue: arsdk enum value
    init?(fromArsdk arsdkValue: ArsdkType) {
        if let me = Self.arsdkMapper.reverseMap(from: arsdkValue) {
            self = me
        } else {
            return nil
        }
    }
}
