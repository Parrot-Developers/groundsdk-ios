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
@testable import GroundSdkMock
@testable import GroundSdk

class InternetConnectivityCoreTests: XCTestCase {

    var internetConnectivity: MockInternetConnectivity!
    var internetAvailable = false
    var monitor1Calls = 0
    var monitor2Calls = 0
    var monitor3Calls = 0

    override func setUp() {
        super.setUp()
        internetConnectivity = MockInternetConnectivity()
    }

    func testMonitoring() {
        // check that with no monitors, the connectivity listener is not running
        assertThat(internetConnectivity.running, `is`(false))

        // start monitoring with monitor1
        let monitor1 = internetConnectivity.startMonitoring { internetAvailable in
            self.internetAvailable = internetAvailable
            self.monitor1Calls += 1
        }

        // adding the first monitor should start the connectivity listener
        assertThat(internetConnectivity.running, `is`(true))
        assertThat(monitor1Calls, `is`(0))

        // check that receiving that internet is not available does not calls back the monitor
        internetConnectivity.mockInternetAvailable = false
        assertThat(internetConnectivity.running, `is`(true))
        assertThat(monitor1Calls, `is`(0))

        // start monitoring with monitor2 (while internet is still not available)
        let monitor2 = internetConnectivity.startMonitoring { _ in
            self.monitor2Calls += 1
        }

        // as Internet is still not available, callbacks should not be called
        assertThat(internetConnectivity.running, `is`(true))
        assertThat(monitor1Calls, `is`(0))
        assertThat(monitor2Calls, `is`(0))

        // Mock internet becomes available
        internetConnectivity.mockInternetAvailable = true
        assertThat(internetConnectivity.running, `is`(true))
        assertThat(internetAvailable, `is`(true))
        assertThat(monitor1Calls, `is`(1))
        assertThat(monitor2Calls, `is`(1))

        // start monitoring with monitor3 (while internet is available)
        let monitor3 = internetConnectivity.startMonitoring { _ in
            self.monitor3Calls += 1
        }

        // as Internet is available, added monitor should be directly called
        assertThat(internetConnectivity.running, `is`(true))
        assertThat(internetAvailable, `is`(true))
        assertThat(monitor1Calls, `is`(1))
        assertThat(monitor2Calls, `is`(1))
        assertThat(monitor3Calls, `is`(1))

        // check that a stopped monitor does not receive changes
        monitor3.stop()
        internetConnectivity.mockInternetAvailable = false

        assertThat(internetConnectivity.running, `is`(true))
        assertThat(internetAvailable, `is`(false))
        assertThat(monitor1Calls, `is`(2))
        assertThat(monitor2Calls, `is`(2))
        assertThat(monitor3Calls, `is`(1))

        // check that connectivity listener is only running when there are, at least, one monitor still registered
        monitor2.stop()
        assertThat(internetConnectivity.running, `is`(true))
        monitor1.stop()
        assertThat(internetConnectivity.running, `is`(false))

        // check that registering a new monitor starts again the connectivity listener
        let monitor4 = internetConnectivity.startMonitoring { _ in }
        assertThat(internetConnectivity.running, `is`(true))
        monitor4.stop()
        assertThat(internetConnectivity.running, `is`(false))
    }
}
