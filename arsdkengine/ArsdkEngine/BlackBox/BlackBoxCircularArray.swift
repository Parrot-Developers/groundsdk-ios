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

/// A circular array that takes an encodable element
struct BlackBoxCircularArray<T: Encodable>: Encodable {
    /// Max size
    let size: Int
    /// Backing array
    private var array: [T] = []
    /// Writing head
    private var head = 0
    /// Whether the array has been fully written at least once
    private var hasLooped = false

    /// Output array
    ///
    /// Visibility is internal for testing purpose only
    var readingArray: [T] {
        if !hasLooped {
            return array
        } else {
            // add to output the head to endIndex
            var output = Array(array[head ..< size])

            // add to output the beginning of array (which should be the last part in the output)
            let endPart = Array(array[0 ..< head])
            output.append(contentsOf: endPart)

            return output
        }
    }

    /// Constructor
    ///
    /// - Parameter size: size of the circular array
    init(size: Int) {
        self.size = size
    }

    /// Appends a value to the circular array
    ///
    /// - Parameter value: the value to add
    mutating func append(_ value: T) {
        if !hasLooped {
            array.append(value)
        } else {
            array[head] = value
        }
        head += 1
        if head == size {
            head = 0
            hasLooped = true
        }
    }

    func encode(to encoder: Encoder) throws {
        try readingArray.encode(to: encoder)
    }
}
