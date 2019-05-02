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

/// Helper to create a bi-directional mapping between 2 hashable values
struct Mapper<SrcType: Hashable, DstType: Hashable> {
    /// Direct mapping
    private let mapping: [SrcType: DstType]
    /// Reverse mapping
    private let reverseMapping: [DstType: SrcType]

    /// Constructor
    ///
    /// - Parameter mapping: direct mapping
    init(_ mapping: [SrcType: DstType]) {
        self.mapping = mapping
        self.reverseMapping = mapping.reduce(into: [DstType: SrcType]()) { (result, entry) in
            result[entry.value] = entry.key
        }
    }

    /// Map from source type to dest type
    ///
    /// - Parameter value: value to map
    /// - Returns: mapped value
    func map(from value: SrcType) -> DstType? {
        return mapping[value]
    }

    /// Reverse map from dest type to the source type
    ///
    /// - Parameter value: value to map
    /// - Returns: mapped value
    func reverseMap(from value: DstType) -> SrcType? {
        return reverseMapping[value]
    }
}
