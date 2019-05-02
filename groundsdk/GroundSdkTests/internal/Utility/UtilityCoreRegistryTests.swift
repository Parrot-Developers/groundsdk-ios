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
@testable import GroundSdk

class UtilityCoreRegistryTests: XCTestCase {

    let registry = UtilityCoreRegistry()
    private let utilityA = TestUtilityA()
    private let utilityB = TestUtilityB()

    private static let testUtilityADesc = TestUtilityADesc()
    private static let testUtilityBDesc = TestUtilityBDesc()

    func testAddOptionalUtility() {
        assertThat(registry.getUtility(UtilityCoreRegistryTests.testUtilityADesc), nilValue())
        assertThat(registry.getUtility(UtilityCoreRegistryTests.testUtilityBDesc), nilValue())

        registry.publish(utility: utilityA)
        assertThat(registry.getUtility(UtilityCoreRegistryTests.testUtilityADesc), presentAnd(`is`(utilityA)))
        assertThat(registry.getUtility(UtilityCoreRegistryTests.testUtilityBDesc), nilValue())

        registry.publish(utility: utilityB)
        assertThat(registry.getUtility(UtilityCoreRegistryTests.testUtilityADesc), presentAnd(`is`(utilityA)))
        assertThat(registry.getUtility(UtilityCoreRegistryTests.testUtilityBDesc), presentAnd(`is`(utilityB)))
    }

    private class TestUtilityADesc: UtilityCoreApiDescriptor {
        public typealias ApiProtocol = TestUtilityA
        let uid = 1
    }

    private class TestUtilityBDesc: UtilityCoreApiDescriptor {
        public typealias ApiProtocol = TestUtilityB
        let uid = 2
    }

    private class TestUtilityA: NSObject, UtilityCore {
        var desc: UtilityCoreDescriptor = testUtilityADesc
    }

    private class TestUtilityB: NSObject, UtilityCore {
        let desc: UtilityCoreDescriptor = testUtilityBDesc
    }
}
