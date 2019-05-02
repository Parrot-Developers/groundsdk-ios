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

class GroundSdkUserDefaultsTests: XCTestCase {

    private let globalKey = "groundSdkStore"

    var groundSdkUserDefaults1: GroundSdkUserDefaults?
    var groundSdkUserDefaults2: GroundSdkUserDefaults?

    override func setUp() {
        super.setUp()
        groundSdkUserDefaults1 = GroundSdkUserDefaults("string1Key")
        groundSdkUserDefaults2 = GroundSdkUserDefaults("string2Key")
    }

    override func tearDown() {
        super.tearDown()
        groundSdkUserDefaults1 = nil
        groundSdkUserDefaults2 = nil
    }

    func testStoreAndGetValues() {
        // be sure we these have 2 values in the dictionay
        groundSdkUserDefaults1!.storeData("string1")
        groundSdkUserDefaults2!.storeData("string2")

        var getString1 = groundSdkUserDefaults1!.loadData() as? String
        assertThat(getString1, presentAnd(`is`("string1")))
        var getString2 = groundSdkUserDefaults2!.loadData() as? String
        assertThat(getString2, presentAnd(`is`("string2")))

        // change a value
        groundSdkUserDefaults1!.storeData("string1v2")
        getString1 = groundSdkUserDefaults1!.loadData() as? String
        assertThat(getString1, presentAnd(`is`("string1v2")))
        getString2 = groundSdkUserDefaults2!.loadData() as? String
        assertThat(getString2, presentAnd(`is`("string2")))

        // remove a value
        groundSdkUserDefaults1!.storeData(nil)
        getString1 = groundSdkUserDefaults1!.loadData() as? String
        assertThat(getString1, `is`(nilValue()))
        getString2 = groundSdkUserDefaults2!.loadData() as? String
        assertThat(getString2, presentAnd(`is`("string2")))

         // remove and alloc groundSdkUserDefaults
        groundSdkUserDefaults1 = nil
        groundSdkUserDefaults2 = nil
        let otherGroundSdkUserDefaults1 = GroundSdkUserDefaults("string1Key")
        let otherGroundSdkUserDefaults2 = GroundSdkUserDefaults("string2Key")
        getString1 = otherGroundSdkUserDefaults1.loadData() as? String
        assertThat(getString1, `is`(nilValue()))
        getString2 = otherGroundSdkUserDefaults2.loadData() as? String
        assertThat(getString2, presentAnd(`is`("string2")))

        // check UserDefaults dictionary with the globalKey
        let userDefaults = UserDefaults.standard
        let storeDictionary = userDefaults.dictionary(forKey: globalKey) ?? [:]

        let checkString2 = storeDictionary["string2Key"] as? String
        assertThat(checkString2, presentAnd(`is`("string2")))
    }
}
