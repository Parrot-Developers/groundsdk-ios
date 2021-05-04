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

@interface GroundSdkTests : XCTestCase
@property(nonatomic, strong) MockGroundSdk *mockGsdk;
@property(nonatomic, strong) GroundSdk *gsdk;
@end

#pragma clang diagnostic ignored "-Wunused-variable"

@implementation GroundSdkTests

- (void)setUp {
    _mockGsdk = [[MockGroundSdk alloc] init];
    _gsdk = [[GroundSdk alloc] init];
    [_mockGsdk addDroneWithUid:@"111" model:GSDroneModelAnafi4k name:@"anafi4k"];
    [_mockGsdk addDroneWithUid:@"222" model:GSDroneModelAnafiThermal name:@"anafiThermal"];

    [_mockGsdk addRemoteControlWithUid:@"999" model:GSRemoteControlModelSkyCtrl3 name:@"mpp"];
}

- (void)tearDown {
    _gsdk = nil;
    _mockGsdk = nil;
}

- (void)testGetDrone {
    GroundSdk *gsdk = [[GroundSdk alloc] init];
    // check that getDroneWithUid selector is available
    GSDrone *drone = [gsdk getDroneWithUid: @"111"];
    XCTAssertNotNil(drone);
}

- (void)testGetRemoteControl {
    GroundSdk *gsdk = [[GroundSdk alloc] init];
    // check that getRemoteControlWithUid selector is available
    GSRemoteControl *rc = [gsdk getRemoteControlWithUid: @"999"];
    XCTAssertNotNil(rc);
}

- (void)testGetDroneList {
    GroundSdk *gsdk = [[GroundSdk alloc] init];
    __block int expectedList1Size = 2;
    __block int expectedList2Size = 1;
    __block int list1ChangeCnt = 0;
    __block int list2ChangeCnt = 0;
    // check getDroneList is callable
    GSDroneListRef *list1 = [gsdk getDroneList:^(NSArray<GSDroneListEntry *> *list) {
        XCTAssertEqual(list.count, expectedList1Size);
        list1ChangeCnt++;
    }];
    GSDroneListRef *list2 = [gsdk getDroneList:^(NSArray<GSDroneListEntry *> *list) {
        XCTAssertEqual(list.count, expectedList2Size);
        list2ChangeCnt++;
    } filter:^BOOL(GSDroneListEntry *entry){
        return entry.model == GSDroneModelAnafiThermal;
    }];
    XCTAssertEqual(1, list1ChangeCnt);
    XCTAssertEqual(1, list2ChangeCnt);

    // check DroneListEntry access
    GSDroneListEntry *entry = list2.value[0];
    XCTAssertEqualObjects(@"222", entry.uid);
    XCTAssertEqual(GSDroneModelAnafiThermal, entry.model);
    XCTAssertEqualObjects(@"anafiThermal", entry.name);
    XCTAssertEqual(GSDeviceConnectionStateDisconnected, entry.state.connectionState);

    expectedList1Size = 1;
    [_mockGsdk removeDroneWithUid:@"111"];
    XCTAssertEqual(2, list1ChangeCnt);
    XCTAssertEqual(1, list2ChangeCnt);

    // check drone related methods are callable
    BOOL res;
    res = [gsdk connectDroneWithUid:@"222"];
    res = [gsdk connectDroneWithUid:@"222" connector:LocalDeviceConnectorCore.wifi];
    res = [gsdk connectDroneWithUid:@"222" connector:LocalDeviceConnectorCore.wifi password:@"password"];
    res = [gsdk disconnectDroneWithUid:@"222"];
    res = [gsdk forgetDroneWithUid:@"222"];
}

- (void)testGetRemoteControlList {
    GroundSdk *gsdk = [[GroundSdk alloc] init];
    __block int expectedListSize = 1;
    __block int listChangeCnt;
    // check getDroneList is callable
    GSRemoteControlListRef *list = [gsdk getRemoteControlList:^(NSArray<GSRemoteControlListEntry *> *list) {
        XCTAssertEqual(list.count, expectedListSize);
        listChangeCnt++;
    }];

    XCTAssertEqual(1, listChangeCnt);

    // check RemoteControlListEntry access
    GSRemoteControlListEntry *entry = list.value[0];
    XCTAssertEqualObjects(@"999", entry.uid);
    XCTAssertEqual(GSRemoteControlModelSkyCtrl3, entry.model);
    XCTAssertEqualObjects(@"mpp", entry.name);
    XCTAssertEqual(GSDeviceConnectionStateDisconnected, entry.state.connectionState);

    expectedListSize = 0;
    [_mockGsdk removeRemoteControlWithUid:@"999"];
    XCTAssertEqual(2, listChangeCnt);


    // check rc related methods are callable
    BOOL res;
    res = [gsdk connectRemoteControlWithUid:@"999"];
    res = [gsdk disconnectRemoteControlWithUid:@"999"];
    res = [gsdk forgetRemoteControlWithUid:@"999"];
}

@end
