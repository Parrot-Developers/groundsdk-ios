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

@interface PilotingItfsTests : XCTestCase
@property(nonatomic, strong) MockGroundSdk *mockGsdk;
@property(nonatomic, strong) GroundSdk *gsdk;
@end

#pragma clang diagnostic ignored "-Wunused-variable"

@implementation PilotingItfsTests

- (void)setUp {
    _mockGsdk = [[MockGroundSdk alloc] init];
    _gsdk = [[GroundSdk alloc] init];
    [_mockGsdk addDroneWithUid:@"123" model:GSDroneModelAnafi4k name:@"MyDrone"];
}

- (void)tearDown {
    _gsdk = nil;
    _mockGsdk = nil;
}

- (void)testManualCopterPilotingItf {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPilotingItfWithUid:GSPilotingItfs.manualCopter.uid droneUid:@"123"];

    id<GSManualCopterPilotingItf> pilotingItf = (id<GSManualCopterPilotingItf>)
        [drone getPilotingItf:GSPilotingItfs.manualCopter];
    XCTAssertNotNil(pilotingItf);
    XCTAssertNotNil(pilotingItf.maxPitchRoll);
    XCTAssertNil(pilotingItf.maxPitchRollVelocity);
    XCTAssertNotNil(pilotingItf.maxVerticalSpeed);
    XCTAssertNotNil(pilotingItf.maxYawRotationSpeed);
    XCTAssertNil(pilotingItf.bankedTurnMode);
    XCTAssertFalse(pilotingItf.canTakeOff);
    XCTAssertFalse(pilotingItf.canLand);
    XCTAssertEqual(pilotingItf.smartTakeOffLandAction, GSSmartTakeOffLandActionNone);
    XCTAssertNil(pilotingItf.thrownTakeOffSettings);

    XCTAssertEqual(pilotingItf.state, GSActivablePilotingItfStateUnavailable);
    BOOL activated = [pilotingItf activate];
    [pilotingItf state];
    [pilotingItf setPitch:10];
    [pilotingItf setRoll:10];
    [pilotingItf setYawRotationSpeed:10];
    [pilotingItf setVerticalSpeed:10];
    [pilotingItf hover];
    [pilotingItf takeOff];
    [pilotingItf land];
    [pilotingItf smartTakeOffLand];
    [pilotingItf emergencyCutOut];
}

- (void)testReturnHomePilotingItf {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPilotingItfWithUid:GSPilotingItfs.returnHome.uid droneUid:@"123"];

    id<GSReturnHomePilotingItf> pilotingItf = (id<GSReturnHomePilotingItf>)
        [drone getPilotingItf:GSPilotingItfs.returnHome];
    XCTAssertNotNil(pilotingItf);
    XCTAssertNil(pilotingItf.homeLocation);
    XCTAssertEqual(pilotingItf.currentTarget, GSReturnHomeTargetTakeOffPosition);
    XCTAssertFalse(pilotingItf.gpsWasFixedOnTakeOff);
    id<GSReturnHomePreferredTarget> preferedTarget = pilotingItf.preferredTarget;
    XCTAssertNotNil(preferedTarget);
    XCTAssertFalse(preferedTarget.updating);
    XCTAssertEqual(preferedTarget.target, GSReturnHomeTargetTrackedTargetPosition);
    id<GSIntSetting> delay = pilotingItf.autoStartOnDisconnectDelay;
    XCTAssertNotNil(delay);
    XCTAssertEqual(pilotingItf.homeReachability, GSHomeReachabilityUnknown);
    XCTAssertEqual(pilotingItf.autoTriggerDelay, 0);
    GSHomeReachability homeReachability = pilotingItf.homeReachability;
    XCTAssertEqual(pilotingItf.state, GSActivablePilotingItfStateUnavailable);
    BOOL activated = [pilotingItf activate];
    [pilotingItf state];
}

- (void)testFlightPlanPilotingItf {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPilotingItfWithUid:GSPilotingItfs.flightPlan.uid droneUid:@"123"];

    id<GSFlightPlanPilotingItf> pilotingItf = (id<GSFlightPlanPilotingItf>)
        [drone getPilotingItf:GSPilotingItfs.flightPlan];
    XCTAssertNotNil(pilotingItf);

    XCTAssertEqual(pilotingItf.latestUploadState, GSFlightPlanFileUploadStateNone);
    XCTAssertEqual(pilotingItf.latestMissionItemExecuted, -1);
    XCTAssertEqual(pilotingItf.latestActivationError, GSFlightPlanActivationErrorNone);

    BOOL res = [pilotingItf hasUnavailabilityReason:GSFlightPlanUnavailabilityReasonDroneGpsInfoInacurate];

    [pilotingItf uploadFlightPlanWithFilepath:@""];

    BOOL activated = [pilotingItf activateWithRestart:YES];
    [pilotingItf state];
}

- (void)testAnimationPilotingItf {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPilotingItfWithUid:GSPilotingItfs.animation.uid droneUid:@"123"];

    id<GSAnimationPilotingItf> pilotingItf = (id<GSAnimationPilotingItf>)
    [drone getPilotingItf:GSPilotingItfs.animation];
    XCTAssertNotNil(pilotingItf);

    GSCandleAnimationConfig *config = [[[[GSCandleAnimationConfig alloc] init] withMode:GSAnimationModeOnce]
                                       withSpeed:5.0];
    BOOL res = [pilotingItf startAnimationWithConfig:config];
    res = [pilotingItf abortCurrentAnimation];

    GSTwistUpAnimationConfig *configTwistUpAnimation = [[GSTwistUpAnimationConfig alloc]init];
    [configTwistUpAnimation withMode:GSAnimationModeOnce];
    [configTwistUpAnimation withSpeed:1.0];
    [configTwistUpAnimation withRotationAngle: 2.0];
    [configTwistUpAnimation withRotationSpeed: 3.0];
    [configTwistUpAnimation withVerticalDistance:4.0];

    GSPositionTwistUpAnimationConfig *configPositionTwistUpAnimation = [[GSPositionTwistUpAnimationConfig alloc]init];
    [configPositionTwistUpAnimation withMode:GSAnimationModeOnce];
    [configPositionTwistUpAnimation withSpeed:1.0];
    [configPositionTwistUpAnimation withRotationAngle: 2.0];
    [configPositionTwistUpAnimation withRotationSpeed: 3.0];
    [configPositionTwistUpAnimation withVerticalDistance:4.0];

    GSHorizontal180PhotoPanoramaAnimationCfg *configHorizontal180PhotoPanoramaAnimation =
        [[GSHorizontal180PhotoPanoramaAnimationCfg alloc] init];
    res = [pilotingItf startAnimationWithConfig:configHorizontal180PhotoPanoramaAnimation];
    res = [pilotingItf abortCurrentAnimation];

    GSVertical180PhotoPanoramaAnimationConfig *configVertical180PhotoPanoramaAnimation =
    [[GSVertical180PhotoPanoramaAnimationConfig alloc] init];
    res = [pilotingItf startAnimationWithConfig:configVertical180PhotoPanoramaAnimation];
    res = [pilotingItf abortCurrentAnimation];

    GSSphericalPhotoPanoramaAnimationConfig *configSphericalPhotoPanoramaAnimation =
    [[GSSphericalPhotoPanoramaAnimationConfig alloc] init];
    res = [pilotingItf startAnimationWithConfig:configSphericalPhotoPanoramaAnimation];
    res = [pilotingItf abortCurrentAnimation];

}

- (void)testGuidedPilotingItf {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPilotingItfWithUid:GSPilotingItfs.guided.uid droneUid:@"123"];

    id<GSGuidedPilotingItf> pilotingItf = (id<GSGuidedPilotingItf>)
    [drone getPilotingItf:GSPilotingItfs.guided];

    XCTAssertEqual(pilotingItf.state, GSActivablePilotingItfStateUnavailable);

    XCTAssertNil(pilotingItf.currentDirective);
    XCTAssertNil(pilotingItf.latestFinishedFlightInfo);

    // test OBJ C members - Location Directive
    GSLocationDirective *testLocationDirectiveClass;
    GSGuidedType gsGuidedType = testLocationDirectiveClass.guidedType;
    GSOrientationDirective orientationDirective = testLocationDirectiveClass.orientationDirective;
    double heading = testLocationDirectiveClass.heading;

    // test OBJ C members - Finished Location
    id<GSFinishedFlightInfo> finishedFlightInfo = pilotingItf.latestFinishedFlightInfo;
    id<GSFinishedLocationFlightInfo> finishedLocationFlightInfo = (id<GSFinishedLocationFlightInfo>) finishedFlightInfo;
    gsGuidedType = finishedLocationFlightInfo.guidedType ;

    GSLocationDirective *locationDirective = finishedLocationFlightInfo.directive;
    GSOrientationDirective gsOrientationDirective = locationDirective.orientationDirective;

    // test OBJ C members  - Finished Relative
    id<GSFinishedRelativeMoveFlightInfo> finishedRelativeMoveFlightInfo = nil;
    id<GSRelativeMoveDirective> moveDirective = finishedRelativeMoveFlightInfo.directive;
    gsGuidedType = finishedRelativeMoveFlightInfo.guidedType ;
    double d = moveDirective.downwardComponent;

    // send commands
    [pilotingItf moveToLocationWithLatitude:1.1
                                  longitude:2.2
                                   altitude:3.3
                                orientation:GSOrientationDirectiveHeadingStart
                                    heading:4.4];
    [pilotingItf moveToRelativePositionWithForwardComponent:1.1
                                             rightComponent:2.2
                                          downwardComponent:3.3
                                            headingRotation:4.4];
    [pilotingItf state];
}

- (void)testPoiPilotingItf {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPilotingItfWithUid:GSPilotingItfs.pointOfInterest.uid droneUid:@"123"];

    id<GSPointOfInterestPilotingItf> pilotingItf = (id<GSPointOfInterestPilotingItf>)
    [drone getPilotingItf:GSPilotingItfs.pointOfInterest];

    XCTAssertEqual(pilotingItf.state, GSActivablePilotingItfStateUnavailable);
    XCTAssertNil(pilotingItf.currentPointOfInterest);

    id <GSPointOfInterest> pointOfInterest;
    double latitude = pointOfInterest.latitude;
    double longitude = pointOfInterest.longitude;
    double altitude = pointOfInterest.altitude;

    // send commands
    [pilotingItf startWithLatitude:1.1 longitude:2.2 altitude:3.3];
    [pilotingItf setRoll:10];
    [pilotingItf setPitch:20];
    [pilotingItf setVerticalSpeed:30];
}

- (void)testLookAtPilotingItf {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPilotingItfWithUid:GSPilotingItfs.lookAt.uid droneUid:@"123"];

    id<GSLookAtPilotingItf> pilotingItf = (id<GSLookAtPilotingItf>) [drone getPilotingItf:GSPilotingItfs.lookAt];

    BOOL testContains = [pilotingItf availabilityIssuesContains:(GSTrackingIssueDroneNotCalibrated)];
    testContains = [pilotingItf qualityIssuesContains:(GSTrackingIssueDroneTooCloseToTarget)];
    BOOL testEmpty = [pilotingItf qualityIssuesIsEmpty];

    // send commands
    [pilotingItf setRoll:10];
    [pilotingItf setPitch:20];
    [pilotingItf setVerticalSpeed:30];
}

- (void)testFollowMePilotingItf {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPilotingItfWithUid:GSPilotingItfs.followMe.uid droneUid:@"123"];

    id<GSFollowMePilotingItf> pilotingItf = (id<GSFollowMePilotingItf>) [drone getPilotingItf:GSPilotingItfs.followMe];

    BOOL testContains = [pilotingItf availabilityIssuesContains:(GSTrackingIssueDroneNotCalibrated)];
    testContains = [pilotingItf qualityIssuesContains:(GSTrackingIssueDroneTooCloseToTarget)];
    BOOL testEmpty = [pilotingItf qualityIssuesIsEmpty];

    GSFollowBehavior behavior = [pilotingItf followBehavior];

    GSFollowMode mode = pilotingItf.followMode.value;
    pilotingItf.followMode.value = GSFollowModeGeographic;
    XCTAssertFalse([pilotingItf.followMode modeIsSupported:GSFollowModeLeash]);

    // send commands
    [pilotingItf setRoll:10];
    [pilotingItf setPitch:20];
    [pilotingItf setVerticalSpeed:30];
}

- (void)testTargetTracker {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPilotingItfWithUid:GSPilotingItfs.followMe.uid droneUid:@"123"];

    id<GSFollowMePilotingItf> pilotingItf = (id<GSFollowMePilotingItf>) [drone getPilotingItf:GSPilotingItfs.followMe];

    BOOL testContains = [pilotingItf availabilityIssuesContains:(GSTrackingIssueDroneNotCalibrated)];
    testContains = [pilotingItf qualityIssuesContains:(GSTrackingIssueDroneTooCloseToTarget)];
    BOOL testEmpty = [pilotingItf qualityIssuesIsEmpty];

    GSFollowBehavior behavior = [pilotingItf followBehavior];

    GSFollowMode mode = pilotingItf.followMode.value;
    pilotingItf.followMode.value = GSFollowModeGeographic;

    // send commands
    [pilotingItf setRoll:10];
    [pilotingItf setPitch:20];
    [pilotingItf setVerticalSpeed:30];
}

@end


