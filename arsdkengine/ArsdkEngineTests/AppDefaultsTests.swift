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
import GroundSdk
@testable import ArsdkEngine

/// Core arsdk engine tests
class AppDefaultsTests: XCTestCase {

    var mockPersistentStore = MockPersistentStore()

    /// This test is driven by the plist file `app_defaults_tests.plist`.
    /// It will test each test case declared in this plist, compare the generated PersistentStore to the expected
    /// dictionary declared in the test case.
    func testWithScriptedPlist() {
        let bundle = Bundle(for: type(of: self))
        let path = bundle.path(forResource: "app_defaults_tests", ofType: "plist")!
        let tests = NSArray(contentsOfFile: path)

        tests?.forEach {
            let test = $0 as! [String: AnyObject]
            let name = test["name"] as! String
            print("Test Case: \(name)")
            let model = DeviceModel.from(name: test["model"] as! String)!
            let initialStore = test["initialStore"] as? [String: AnyObject]
            let appDefaults = test["appDefaults"] as! [String: AnyObject]
            let expectedStore = test["expectedStore"] as! [String: AnyObject]

            // start with a clean persistent store
            mockPersistentStore = MockPersistentStore()
            if let initialStore = initialStore {
                mockPersistentStore.content = initialStore
            }

            // import test values
            AppDefaults.importDict(appDefaults, for: model, to: mockPersistentStore)

            // check that generated persistent store is equal to expectation
            assertThat(mockPersistentStore, `is`(expectedStore, testName: name))
        }
    }
}
