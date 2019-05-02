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
import CoreMotion

class SystemBarometerCoreTests: XCTestCase {

    var systemBarometerUtility: SystemBarometerCoreImpl!
    var lastBarometerMeasure: BarometerMeasure?
    var barometerMonitor: MonitorCore?
    var measureChangeCnt = 0

    override func setUp() {
        super.setUp()
        systemBarometerUtility = SystemBarometerCoreImpl(mockVersion: "MOCK")
    }

    /// create and start a Monitor for Altitude
    func startMonitorBarometer() {
        barometerMonitor = systemBarometerUtility.startMonitoring(measureDidChange: { (barometerMeasure) in
            self.measureChangeCnt += 1
            self.lastBarometerMeasure = barometerMeasure
        })
    }

    /// free the Heading Monitor
    func stopMonitorBarometer() {
        barometerMonitor?.stop()
    }

    func testInitialValue() {
        // monitor
        startMonitorBarometer()
        assertThat(measureChangeCnt, equalTo(0))
        assertThat(lastBarometerMeasure, nilValue())

        stopMonitorBarometer()
        assertThat(measureChangeCnt, equalTo(0))
        assertThat(lastBarometerMeasure, nilValue())
    }

    func testMutipleMonitors() {
        let measureDate = Date()
        let testBarometerMeasure = BarometerMeasure(pressure: 101325, timestamp: measureDate)
        var isStarted = systemBarometerUtility.mockBarometerMeasure(testBarometerMeasure)
        assertThat(isStarted, equalTo(false))

        let monitor1 = systemBarometerUtility.startMonitoring(measureDidChange: { _ in })
        isStarted = systemBarometerUtility.mockBarometerMeasure(testBarometerMeasure)
        assertThat(isStarted, equalTo(true))

        let monitor2 = systemBarometerUtility.startMonitoring(measureDidChange: { _ in })
        isStarted = systemBarometerUtility.mockBarometerMeasure(testBarometerMeasure)
        assertThat(isStarted, equalTo(true))

        monitor1?.stop()
        isStarted = systemBarometerUtility.mockBarometerMeasure(testBarometerMeasure)
        assertThat(isStarted, equalTo(true))

        monitor2?.stop()
        isStarted = systemBarometerUtility.mockBarometerMeasure(testBarometerMeasure)
        assertThat(isStarted, equalTo(false))
    }

    func testBarometerData() {
        let measureDate = Date()
        let testBarometerMeasure = BarometerMeasure(pressure: 101325, timestamp: measureDate)
        var isStarted = systemBarometerUtility.mockBarometerMeasure(testBarometerMeasure)
        assertThat(measureChangeCnt, equalTo(0))
        assertThat(isStarted, equalTo(false))

        startMonitorBarometer()
        assertThat(measureChangeCnt, equalTo(0))
        assertThat(lastBarometerMeasure, nilValue())
        isStarted = systemBarometerUtility.mockBarometerMeasure(testBarometerMeasure)
        assertThat(isStarted, equalTo(true))
        assertThat(lastBarometerMeasure, presentAnd(`is`(pressure: 101325, timestamp: measureDate)))
        assertThat(measureChangeCnt, equalTo(1))

        // send same measure with same timestamp
        isStarted = systemBarometerUtility.mockBarometerMeasure(testBarometerMeasure)
        assertThat(isStarted, equalTo(true))
        assertThat(lastBarometerMeasure, presentAnd(`is`(pressure: 101325, timestamp: measureDate)))
        assertThat(measureChangeCnt, equalTo(1))

        // send  new measure with new timestamp
        let measureDateV2 = measureDate.addingTimeInterval(10)
        let testBarometerMeasureV2 = BarometerMeasure(pressure: 101344, timestamp: measureDateV2)
        isStarted = systemBarometerUtility.mockBarometerMeasure(testBarometerMeasureV2)
        assertThat(isStarted, equalTo(true))
        assertThat(lastBarometerMeasure, presentAnd(`is`(pressure: 101344, timestamp: measureDateV2)))
        assertThat(measureChangeCnt, equalTo(2))

        // same measure but with a new timestamp
        let measureDateV3 = measureDateV2.addingTimeInterval(10)
        let testBarometerMeasureV3 = BarometerMeasure(pressure: 101344, timestamp: measureDateV3)
        isStarted = systemBarometerUtility.mockBarometerMeasure(testBarometerMeasureV3)
        assertThat(isStarted, equalTo(true))
        assertThat(lastBarometerMeasure, presentAnd(`is`(pressure: 101344, timestamp: measureDateV3)))
        assertThat(measureChangeCnt, equalTo(3))

        stopMonitorBarometer()
        assertThat(measureChangeCnt, equalTo(3))
        isStarted = systemBarometerUtility.mockBarometerMeasure(testBarometerMeasureV3)
        assertThat(isStarted, equalTo(false))
    }
}
