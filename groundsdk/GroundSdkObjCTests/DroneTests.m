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

@interface DroneTests : XCTestCase
@property(nonatomic, strong) MockGroundSdk *mockGsdk;
@property(nonatomic, strong) GroundSdk *gsdk;
@end

#pragma clang diagnostic ignored "-Wunused-variable"

@implementation DroneTests

- (void)setUp {
    _mockGsdk = [[MockGroundSdk alloc] init];
    _gsdk = [[GroundSdk alloc] init];
    [_mockGsdk addDroneWithUid:@"123" model:GSDroneModelAnafi4k name:@"MyDrone"];
}

- (void)tearDown {
    _gsdk = nil;
    _mockGsdk = nil;
}

- (void)testProperties {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    // Ensure drone model enum is usable in objc
    GSDroneModel anafi4k = GSDroneModelAnafi4k;
    // check drones properties
    NSString *uid = drone.uid;
    XCTAssertEqualObjects(uid, @"123");
    GSDroneModel model = drone.model;
    XCTAssertEqual(model, GSDroneModelAnafi4k);
    NSString *name = drone.name;
    XCTAssertEqualObjects(name, @"MyDrone");
    GSDeviceState *state = drone.state;
    XCTAssertEqual(state.connectionState, GSDeviceConnectionStateDisconnected);
}

- (void)testEquatable {
    [_mockGsdk addDroneWithUid:@"123" model:GSDroneModelAnafi4k name:@"MyDrone"];
    GSDrone *drone1 = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addDroneWithUid:@"123" model:GSDroneModelAnafiThermal name:@"MyDrone2"];
    GSDrone *drone2 = [_gsdk getDroneWithUid:@"123"];
    XCTAssert([drone1 isEqual:drone2]);
}

- (void)testGetNameRef {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    __block int nameChangeCnt = 0;
    __block NSString *expectedName = @"MyDrone";

    GSNameRef *nameRef = [drone getNameRef: ^(NSString *newName){
        XCTAssertEqualObjects(newName, expectedName);
        nameChangeCnt++;
    }];
    XCTAssertEqual(1, nameChangeCnt);
    XCTAssertEqualObjects(nameRef.value, @"MyDrone");

    expectedName = @"newName";
    [_mockGsdk updateDroneWithUid:@"123" name:@"newName"];
    XCTAssertEqual(2, nameChangeCnt);
    XCTAssertEqualObjects(nameRef.value, @"newName");

    expectedName = NULL;
    nameRef = NULL;
}

- (void)testGetStateRef {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    __block int stateChangeCnt = 0;
    __block GSDeviceConnectionState expectedConnectionState = GSDeviceConnectionStateDisconnected;

    GSDeviceStateRef * stateRef = [drone getStateRef:^(GSDeviceState *newState) {
        XCTAssertEqual(newState.connectionState, expectedConnectionState);
        stateChangeCnt++;
    }];
    XCTAssertEqual(1, stateChangeCnt);

    expectedConnectionState = GSDeviceConnectionStateConnected;
    [_mockGsdk updateDroneWithUid:@"123" connectionState:GSDeviceConnectionStateConnected cause:GSDeviceConnectionStateCauseNone
                        persisted:NO visible:NO];
    XCTAssertEqual(2, stateChangeCnt);

    // check propreries can be access
    GSDeviceConnectionState state = stateRef.value.connectionState;
    GSDeviceConnectionStateCause cause = stateRef.value.connectionStateCause;

    expectedConnectionState = GSDeviceConnectionStateDisconnected;
    stateRef = NULL;
}

- (void)testActions {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    // test action methods are callable
    BOOL res;
    res = [drone connect];
    res = [drone connectWithConnector:LocalDeviceConnectorCore.wifi];
    res = [drone connectWithConnector:LocalDeviceConnectorCore.wifi password:@"password"];
    res = [drone disconnect];
    res = [drone forget];
}

@end
