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

@interface FacilitiesTests : XCTestCase
@property(nonatomic, strong) MockGroundSdk *mockGsdk;
@property(nonatomic, strong) GroundSdk *gsdk;
@end

#pragma clang diagnostic ignored "-Wunused-variable"
#pragma clang diagnostic ignored "-Wunused-result"

@implementation FacilitiesTests

- (void)setUp {
    // add app key required by some engine
    [GSConfig reload];
    GSConfig.sharedInstance.applicationKey = @"secret";
    _mockGsdk = [[MockGroundSdk alloc] init];
    _gsdk = [[GroundSdk alloc] init];
}

- (void)tearDown {
    _gsdk = nil;
    _mockGsdk = nil;
}

- (void)testAutoConnection {
    GroundSdk *gsdk = [[GroundSdk alloc] init];

    GSFacilityRef *ref = [gsdk getFacility:GSFacilities.autoConnection
                                  observer:^(id<GSFacility> _Nullable autoConnection) {

                                  }];
    id<GSAutoConnection> autoConnection = (id<GSAutoConnection>)[gsdk getFacility:GSFacilities.autoConnection];
    XCTAssertNotNil(autoConnection);
    [autoConnection start];
    [autoConnection stop];
    GSAutoConnectionState state = autoConnection.state;

    GSDrone *drone = autoConnection.drone;
    GSRemoteControl *remoteControl = autoConnection.remoteControl;
}

- (void)testCrashReporter {
    GroundSdk *gsdk = [[GroundSdk alloc] init];

    GSFacilityRef *ref = [gsdk getFacility:GSFacilities.crashReporter
                                  observer:^(id<GSFacility> _Nullable crashReporter) {

                                  }];
    id<GSCrashReporter> crashReporter = (id<GSCrashReporter>)[gsdk getFacility:GSFacilities.crashReporter];
    XCTAssertNotNil(crashReporter);
    NSInteger pendingCount = crashReporter.pendingCount;
    BOOL isUploading = crashReporter.isUploading;
}

- (void)testFirmwareManager {
    GroundSdk *gsdk = [[GroundSdk alloc] init];
    [_mockGsdk addFacilityWithUid:GSFacilities.firmwareManager.uid];

    GSFacilityRef *ref = [gsdk getFacility:GSFacilities.firmwareManager
                                  observer:^(id<GSFacility> _Nullable firmwareManager) {

                                  }];
    id<GSFirmwareManager> updateManager = (id<GSFirmwareManager>)[gsdk getFacility:GSFacilities.firmwareManager];
    XCTAssertNotNil(updateManager);

    [updateManager isQueryingRemoteUpdates];
    [updateManager queryRemoteUpdates];
    NSArray<GSFirmwareManagerEntry*> *entries = updateManager.firmwares;
    BOOL canDelete = entries.firstObject.canDelete;
    BOOL cancelDownload = entries.firstObject.cancelDownload;
    GSFirmwareManagerEntryState state = entries.firstObject.state;
    state = GSFirmwareManagerEntryStateDownloaded;
    [entries.firstObject download];
    [entries.firstObject cancelDownload];
    [entries.firstObject delete];
}

- (void)testUserLocation {
    GroundSdk *gsdk = [[GroundSdk alloc] init];
    [_mockGsdk addFacilityWithUid:GSFacilities.userLocation.uid];

    GSFacilityRef *ref = [gsdk getFacility:GSFacilities.userLocation
                                  observer:^(id<GSFacility> _Nullable userLocation) {
                                  }];
    id<GSUserLocation> userLocation = (id<GSUserLocation>)[gsdk getFacility:GSFacilities.userLocation];
    XCTAssertNotNil(userLocation);
    XCTAssertFalse([userLocation stopped]);
    XCTAssertFalse([userLocation authorized]);
    CLLocation *location = userLocation.location;
    BOOL stopped = userLocation.stopped;
    BOOL authorized = userLocation.authorized;
}

- (void)testUserHeading {
    GroundSdk *gsdk = [[GroundSdk alloc] init];
    [_mockGsdk addFacilityWithUid:GSFacilities.userHeading.uid];

    GSFacilityRef *ref = [gsdk getFacility:GSFacilities.userHeading
                                  observer:^(id<GSFacility> _Nullable userLocation) {
                                  }];
    id<GSUserHeading> userHeading;
    userHeading = (id<GSUserHeading>)[gsdk getFacility:GSFacilities.userHeading];
    XCTAssertNotNil(userHeading);
    CLHeading *heading = userHeading.heading;
}

- (void)testReverseGeocoder {
    GroundSdk *gsdk = [[GroundSdk alloc] init];
    [_mockGsdk addFacilityWithUid:GSFacilities.reverseGeocoder.uid];

    GSFacilityRef *ref = [gsdk getFacility:GSFacilities.reverseGeocoder
                                  observer:^(id<GSFacility> _Nullable GSReverseGeocoder) {
                                  }];
    id<GSReverseGeocoder> reverseGeocoder;
    reverseGeocoder = (id<GSReverseGeocoder>)[gsdk getFacility:GSFacilities.reverseGeocoder];
    XCTAssertNotNil(reverseGeocoder);
    CLPlacemark *placemark = reverseGeocoder.placemark;
}

- (void)testFlightDataManager {
    GroundSdk *gsdk = [[GroundSdk alloc] init];
    [_mockGsdk addFacilityWithUid:GSFacilities.flightDataManager.uid];

    GSFacilityRef *ref = [gsdk getFacility:GSFacilities.flightDataManager
                                  observer:^(id<GSFacility> _Nullable GSFlightDataManager) {
                                  }];
    id<GSFlightDataManager> flightDataManager;
    flightDataManager = (id<GSFlightDataManager>)[gsdk getFacility:GSFacilities.flightDataManager];
    XCTAssertNotNil(flightDataManager);
    [flightDataManager deleteWithFile:[[NSURL alloc] initWithString:@"aFilePath"]];
    NSSet *setOfUrls = flightDataManager.files;
}

- (void)testUserAccount {
    GroundSdk *gsdk = [[GroundSdk alloc] init];
    [_mockGsdk addFacilityWithUid:GSFacilities.userAccount.uid];

    GSFacilityRef *ref = [gsdk getFacility:GSFacilities.userAccount
                                  observer:^(id<GSFacility> _Nullable GSUserAccount) {
                                  }];
    id<GSUserAccount> userAccount;
    userAccount = (id<GSUserAccount>)[gsdk getFacility:GSFacilities.userAccount];
    XCTAssertNotNil(userAccount);
    [userAccount clearWithAnonymousDataPolicy:GSAnonymousDataPolicyDeny];
    [userAccount setAccountProvider:@"accountProvider" accountId:@"accountId"
                accountlessPersonalDataPolicy:GSAccountlessPersonalDataPolicyAllowUpload];
}

- (void)testFlightLogReporter {
    GroundSdk *gsdk = [[GroundSdk alloc] init];

    GSFacilityRef *ref = [gsdk getFacility:GSFacilities.flightLogReporter
                                  observer:^(id<GSFacility> _Nullable flightLogReporter) {

                                  }];
    id<GSFlightLogReporter> flightLogReporter = (id<GSFlightLogReporter>)[gsdk getFacility:GSFacilities.flightLogReporter];
    XCTAssertNotNil(flightLogReporter);
    NSInteger pendingCount = flightLogReporter.pendingCount;
    BOOL isUploading = flightLogReporter.isUploading;
}

@end

