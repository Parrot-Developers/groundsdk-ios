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

/// Test SystemVersionCore class
class FirmwareVersionTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    /// Test the constructors of the system version core implementation
    func testFirmwareVersion() {
        testFirmwareVersion("1.2.3-alpha1", presentAnd(allOf(
            `is`(major: 1, minor: 2, patch: 3, type: .alpha, buildNumber: 1),
            has(desc: "1.2.3-alpha1"))))
        testFirmwareVersion("3.2.1-beta4", presentAnd(allOf(
            `is`(major: 3, minor: 2, patch: 1, type: .beta, buildNumber: 4),
            has(desc: "3.2.1-beta4"))))
        testFirmwareVersion("0.0.1-rc2", presentAnd(allOf(
            `is`(major: 0, minor: 0, patch: 1, type: .rc, buildNumber: 2),
            has(desc: "0.0.1-rc2"))))
        testFirmwareVersion("1.0.1", presentAnd(allOf(
            `is`(major: 1, minor: 0, patch: 1, type: .release, buildNumber: 0),
            isReleaseVersion(major: 1, minor: 0, patch: 1),
            has(desc: "1.0.1"))))
        testFirmwareVersion("0.0.0", presentAnd(allOf(
            `is`(major: 0, minor: 0, patch: 0, type: .dev, buildNumber: 0),
            isDevelopmentVersion(), has(desc: "0.0.0"))))

        /*testFirmwareVersion("1.2.3.rc-4", nilValue())
        testFirmwareVersion("1.2.a3", nilValue())*/
    }

    /// Tests the implementation of the Comparable protocol
    func testComparison() {
        let version1 = FirmwareVersion.parse(versionStr: "1.2.3-beta2")
        let version2 = FirmwareVersion.parse(versionStr: "1.2.3-beta3")
        let version3 = FirmwareVersion.parse(versionStr: "1.2.3-rc3")
        let version4 = FirmwareVersion.parse(versionStr: "1.2.4-rc2")
        let version5 = FirmwareVersion.parse(versionStr: "1.3.0")
        let version6 = FirmwareVersion.parse(versionStr: "2.0.0-alpha2")
        let version6Bis = FirmwareVersion.parse(versionStr: "2.0.0-alpha2")

        assertThat(version1!, lessThan(version2!))
        assertThat(version2!, lessThan(version3!))
        assertThat(version3!, lessThan(version4!))
        assertThat(version4!, lessThan(version5!))
        assertThat(version5!, lessThan(version6!))
        assertThat(version6!, equalTo(version6Bis!))

        assertThat(version6!, greaterThan(version5!))
        assertThat(version5!, greaterThan(version4!))
        assertThat(version4!, greaterThan(version3!))
        assertThat(version3!, greaterThan(version2!))
        assertThat(version2!, greaterThan(version1!))

        let dev = FirmwareVersion.parse(versionStr: "0.0.0")
        assertThat(dev!, greaterThan(version2!))
        assertThat(dev!, greaterThan(version3!))
        assertThat(dev!, greaterThan(version4!))
        assertThat(dev!, greaterThan(version5!))
        assertThat(dev!, greaterThan(version6!))

        assertThat(version6!, lessThan(dev!))
        assertThat(version5!, lessThan(dev!))
        assertThat(version4!, lessThan(dev!))
        assertThat(version3!, lessThan(dev!))
        assertThat(version2!, lessThan(dev!))
    }
}

extension FirmwareVersionTests {
    public func testFirmwareVersion(_ versionStr: String, _ matcher: Matcher<FirmwareVersion?>) {
        assertThat(FirmwareVersion.parse(versionStr: versionStr), matcher)
    }
}
