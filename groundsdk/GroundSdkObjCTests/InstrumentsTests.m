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

#import <XCTest/XCTest.h>
#import <GroundSdk/GroundSdk-Swift.h>
#import <GroundSdkMock/GroundSdkMock-Swift.h>

@interface InstrumentsTests : XCTestCase
@property(nonatomic, strong) MockGroundSdk *mockGsdk;
@property(nonatomic, strong) GroundSdk *gsdk;
@end

#pragma clang diagnostic ignored "-Wunused-variable"

@implementation InstrumentsTests

- (void)setUp {
    _mockGsdk = [[MockGroundSdk alloc] init];
    _gsdk = [[GroundSdk alloc] init];
    [_mockGsdk addDroneWithUid:@"123" model:GSDroneModelAnafi4k name:@"MyDrone"];
}

- (void)tearDown {
    _gsdk = nil;
    _mockGsdk = nil;
}

- (void)testAlarms {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addInstrumentWithUid:GSInstruments.alarms.uid droneUid:@"123"];

    id<GSAlarms> alarms = (id<GSAlarms>)[drone getInstrument:GSInstruments.alarms];
    XCTAssertNotNil(alarms);
    GSAlarm* alarm = [alarms getAlarmWithKind:GSAlarmKindPower];
    XCTAssertEqual(alarm.kind, GSAlarmKindPower);
    XCTAssertEqual(alarm.level, GSAlarmLevelOff);
    XCTAssertEqual(alarms.automaticLandingDelay, 0);
}

- (void)testAltimeter {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addInstrumentWithUid:GSInstruments.altimeter.uid droneUid:@"123"];

    id<GSAltimeter> altimeter = (id<GSAltimeter>)[drone getInstrument:GSInstruments.altimeter];
    XCTAssertNotNil(altimeter);
    XCTAssertNil([altimeter getVerticalSpeed]);
    XCTAssertNil([altimeter getAbsoluteAltitude]);
    XCTAssertNil([altimeter getGroundRelativeAltitude]);
    XCTAssertNil([altimeter getTakeoffRelativeAltitude]);
}

- (void)testAttitudeIndicator {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addInstrumentWithUid:GSInstruments.attitudeIndicator.uid droneUid:@"123"];

    id<GSAttitudeIndicator> attitudeIndicator = (id<GSAttitudeIndicator>)
        [drone getInstrument:GSInstruments.attitudeIndicator];
    XCTAssertNotNil(attitudeIndicator);
    XCTAssertEqual(attitudeIndicator.roll, 0.0);
    XCTAssertEqual(attitudeIndicator.pitch, 0.0);
}

- (void)testCompass {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addInstrumentWithUid:GSInstruments.compass.uid droneUid:@"123"];

    id<GSCompass> compass = (id<GSCompass>)[drone getInstrument:GSInstruments.compass];
    XCTAssertNotNil(compass);
    XCTAssertEqual(compass.heading, 0.0);
}

- (void)testFlyingIndicators {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addInstrumentWithUid:GSInstruments.flyingIndicators.uid droneUid:@"123"];

    id<GSFlyingIndicators> flyingIndicators =
        (id<GSFlyingIndicators>)[drone getInstrument:GSInstruments.flyingIndicators];
    XCTAssertNotNil(flyingIndicators);
    XCTAssertEqual(flyingIndicators.state, GSFlyingIndicatorsStateLanded);
    XCTAssertEqual(flyingIndicators.landedState, GSFlyingIndicatorsLandedStateInitializing);
    XCTAssertEqual(flyingIndicators.flyingState, GSFlyingIndicatorsFlyingStateNone);
}

- (void)testGps {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addInstrumentWithUid:GSInstruments.gps.uid droneUid:@"123"];

    id<GSGps> gps = (id<GSGps>)[drone getInstrument:GSInstruments.gps];
    XCTAssertNotNil(gps);
    XCTAssertFalse(gps.fixed);
    XCTAssertNil(gps.lastKnownLocation);
    XCTAssertEqual(gps.satelliteCount, 0);
}

- (void)testSpeedometer {
    // test that we get a GSSpeedometer because this is a different protocol from the Swift protocol
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addInstrumentWithUid:GSInstruments.speedometer.uid droneUid:@"123"];

    id<GSSpeedometer> speedometer = (id<GSSpeedometer>)[drone getInstrument:GSInstruments.speedometer];
    XCTAssertNotNil(speedometer);
    XCTAssertEqual([speedometer getGroundSpeed], 0);
}

- (void)testRadio {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addInstrumentWithUid:GSInstruments.radio.uid droneUid:@"123"];

    id<GSRadio> radio = (id<GSRadio>)[drone getInstrument:GSInstruments.radio];
    XCTAssertNotNil(radio);
    XCTAssertEqual(radio.rssi, 0);
    XCTAssertEqual(radio.linkSignalQuality, -1); // optional value in swift (nil), -1 for objc
    XCTAssertEqual(radio.isLinkPerturbed, false);
    XCTAssertEqual(radio.is4GInterfering, false);
}

- (void)testBatteryInfo {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addInstrumentWithUid:GSInstruments.batteryInfo.uid droneUid:@"123"];

    id<GSBatteryInfo> batteryInfo = (id<GSBatteryInfo>)[drone getInstrument:GSInstruments.batteryInfo];
    XCTAssertNotNil(batteryInfo);
    XCTAssertEqual(batteryInfo.batteryLevel, 0);
    XCTAssertEqual(batteryInfo.isCharging, NO);
    XCTAssertNil(batteryInfo.batteryHealth);
}

- (void)testFlightMeter {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addInstrumentWithUid:GSInstruments.flightMeter.uid droneUid:@"123"];

    id<GSFlightMeter> flightMeter = (id<GSFlightMeter>)[drone getInstrument:GSInstruments.flightMeter];
    XCTAssertNotNil(flightMeter);
    XCTAssertEqual(flightMeter.totalFlightDuration, 0);
    XCTAssertEqual(flightMeter.totalFlights, 0);
    XCTAssertEqual(flightMeter.lastFlightDuration, 0);
}

- (void)testCameraExposureValues {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addInstrumentWithUid:GSInstruments.cameraExposureValues.uid droneUid:@"123"];

    id<GSCameraExposureValues> exposureValues =
        (id<GSCameraExposureValues>)[drone getInstrument:GSInstruments.cameraExposureValues];
    XCTAssertNotNil(exposureValues);
    XCTAssertEqual(exposureValues.shutterSpeed, GSCameraShutterSpeedOneOver10000);
    XCTAssertEqual(exposureValues.isoSensitivity, GSCameraIso50);
}
@end
