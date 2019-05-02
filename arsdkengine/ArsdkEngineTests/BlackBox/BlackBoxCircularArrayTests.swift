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

import XCTest
@testable import ArsdkEngine

/// Circular array tests
class BlackBoxCircularArrayTests: XCTestCase {

    func testWhenNotLooped() {
        var circularArray = BlackBoxCircularArray<Int>(size: 5)
        circularArray.append(1)
        circularArray.append(2)
        circularArray.append(3)
        assertThat(circularArray.readingArray, contains(1, 2, 3))
    }

    func testWhenLooped() {
        var circularArray = BlackBoxCircularArray<Int>(size: 5)
        circularArray.append(1)
        circularArray.append(2)
        circularArray.append(3)
        circularArray.append(4)
        circularArray.append(5)
        circularArray.append(6)
        circularArray.append(7)
        assertThat(circularArray.readingArray, contains(3, 4, 5, 6, 7))

        circularArray.append(8)
        circularArray.append(9)
        circularArray.append(10)
        circularArray.append(11)
        assertThat(circularArray.readingArray, contains(7, 8, 9, 10, 11))
    }
}
