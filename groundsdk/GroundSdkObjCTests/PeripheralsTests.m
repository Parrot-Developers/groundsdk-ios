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
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>

@interface PeripheralsTests : XCTestCase
@property(nonatomic, strong) MockGroundSdk *mockGsdk;
@property(nonatomic, strong) GroundSdk *gsdk;
@end

#pragma clang diagnostic ignored "-Wunused-variable"

@implementation PeripheralsTests

- (void)setUp {
    _mockGsdk = [[MockGroundSdk alloc] init];
    _gsdk = [[GroundSdk alloc] init];
    [_mockGsdk addDroneWithUid:@"123" model:GSDroneModelAnafi4k name:@"MyDrone"];
    [_mockGsdk addRemoteControlWithUid:@"456" model:GSRemoteControlModelSkyCtrl3 name:@"MyRc"];
    [_mockGsdk addRemoteControlWithUid:@"333" model:GSRemoteControlModelSkyCtrl3 name:@"MyRc3"];
}

- (void)tearDown {
    _gsdk = nil;
    _mockGsdk = nil;
}

- (void)testMagnetometer {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.magnetometer.uid droneUid:@"123"];

    id<GSMagnetometer> magnetometer = (id<GSMagnetometer>) [drone getPeripheral:GSPeripherals.magnetometer];
    XCTAssertNotNil(magnetometer);
    XCTAssertEqual(magnetometer.calibrationState, GSMagnetometerCalibrationStateRequired);
}

- (void)testMagnetometerWith3StepCalibration {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.magnetometerWith3StepCalibration.uid droneUid:@"123"];

    id<GSMagnetometerWith3StepCalibration> magnetometer =
    (id<GSMagnetometerWith3StepCalibration>) [drone getPeripheral:
                                              GSPeripherals.magnetometerWith3StepCalibration];
    XCTAssertNotNil(magnetometer);
    XCTAssertNil(magnetometer.calibrationProcessState);
    XCTAssertEqual(magnetometer.calibrationState, GSMagnetometerCalibrationStateRequired);

    XCTAssertEqual(magnetometer.calibrationProcessState.currentAxis, GSMagnetometerAxisNone);
    XCTAssertFalse(magnetometer.calibrationProcessState.failed);
    XCTAssertFalse([magnetometer.calibrationProcessState isCalibratedWithAxis:GSMagnetometerAxisRoll]);

    [magnetometer startCalibrationProcess];
    [magnetometer cancelCalibrationProcess];
}

- (void)testMagnetometerWith1StepCalibration {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.magnetometerWith1StepCalibration.uid droneUid:@"123"];

    id<GSMagnetometerWith1StepCalibration> magnetometer =
    (id<GSMagnetometerWith1StepCalibration>) [drone getPeripheral:
                                              GSPeripherals.magnetometerWith1StepCalibration];
    XCTAssertNotNil(magnetometer);
    XCTAssertEqual(magnetometer.calibrationState, GSMagnetometerCalibrationStateRequired);
    XCTAssertEqual(magnetometer.calibrationProcessState.rollProgress, 0);
    XCTAssertEqual(magnetometer.calibrationProcessState.pitchProgress, 0);
    XCTAssertEqual(magnetometer.calibrationProcessState.yawProgress, 0);

    [magnetometer startCalibrationProcess];
    [magnetometer cancelCalibrationProcess];
}

- (void)testDroneFinder {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.droneFinder.uid droneUid:@"123"];

    id<GSDroneFinder> droneFinder = (id<GSDroneFinder>) [drone getPeripheral:GSPeripherals.droneFinder];
    XCTAssertNotNil(droneFinder);
    XCTAssertEqual(droneFinder.state, GSDroneFinderStateIdle);
    XCTAssertNotNil(droneFinder.discoveredDrones);
    XCTAssertEqual(droneFinder.discoveredDrones.count, 0);

    GSDiscoveredDrone* discoveredDrone = [[DiscoveredDroneCore alloc] initWithUid:@"123"
                                                                            model:GSDroneModelAnafi4k
                                                                             name:@"anafi4k"
                                                                            known:false
                                                                             rssi:-30
                                                               connectionSecurity:GSConnectionSecurityPassword];

    XCTAssertEqual(discoveredDrone.uid, @"123");
    XCTAssertEqual(discoveredDrone.model, GSDroneModelAnafi4k);
    XCTAssertEqual(discoveredDrone.name, @"anafi4k");
    XCTAssertEqual(discoveredDrone.known, false);
    XCTAssertEqual(discoveredDrone.rssi, -30);
    XCTAssertEqual(discoveredDrone.connectionSecurity, GSConnectionSecurityPassword);

    [droneFinder clear];
    [droneFinder refresh];
    BOOL res;
    res = [droneFinder connectWithDiscoveredDrone:discoveredDrone];
    res = [droneFinder connectWithDiscoveredDrone:discoveredDrone password:@"password"];
}

- (void)testSystemInfo {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.systemInfo.uid droneUid:@"123"];

    id<GSSystemInfo> systemInfo = (id<GSSystemInfo>) [drone getPeripheral:GSPeripherals.systemInfo];
    XCTAssertNotNil(systemInfo);

    XCTAssertEqualObjects(systemInfo.firmwareVersion, @"");
    XCTAssertEqualObjects(systemInfo.hardwareVersion, @"");
    XCTAssertEqualObjects(systemInfo.serial, @"");

    BOOL res;
    res = [systemInfo resetSettings];
    res = [systemInfo factoryReset];
}

- (void)testUpdater {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.updater.uid droneUid:@"123"];

    id<GSUpdater> firmwareUpdater = (id<GSUpdater>) [drone getPeripheral:GSPeripherals.updater];
    XCTAssertNotNil(firmwareUpdater);

    XCTAssertEqual(firmwareUpdater.downloadableFirmwares.count, 0);
    XCTAssertTrue(firmwareUpdater.isUpToDate);
    XCTAssertNil(firmwareUpdater.currentDownload);
    XCTAssertEqual(firmwareUpdater.applicableFirmwares.count, 0);
    XCTAssertNil(firmwareUpdater.currentUpdate);
    XCTAssertNil(firmwareUpdater.idealVersion);

    [firmwareUpdater downloadNextFirmware];
    [firmwareUpdater downloadAllFirmwares];
    [firmwareUpdater cancelDownload];

    [firmwareUpdater updateToNextFirmware];
    [firmwareUpdater updateToLatestFirmware];
    [firmwareUpdater cancelUpdate];

    BOOL res = [firmwareUpdater isPreventingDownloadWithReason:GSUpdaterDownloadUnavailabilityReasonInternetUnavailable];
    res = [firmwareUpdater isPreventingUpdateWithReason:GSUpdaterUpdateUnavailabilityReasonNotLanded];

    // check API of GSFirmwareUpdaterDownload
    XCTAssertNil(firmwareUpdater.currentDownload.currentFirmware);
    XCTAssertEqual(firmwareUpdater.currentDownload.currentProgress, 0);
    XCTAssertEqual(firmwareUpdater.currentDownload.currentIndex, 0);
    XCTAssertEqual(firmwareUpdater.currentDownload.totalCount, 0);
    XCTAssertEqual(firmwareUpdater.currentDownload.totalProgress, 0);
    XCTAssertEqual(firmwareUpdater.currentDownload.state, GSUpdaterDownloadStateDownloading);

    // check API of GSFirmwareUpdaterUpdate
    XCTAssertNil(firmwareUpdater.currentUpdate.currentFirmware);
    XCTAssertEqual(firmwareUpdater.currentUpdate.currentProgress, 0);
    XCTAssertEqual(firmwareUpdater.currentUpdate.currentIndex, 0);
    XCTAssertEqual(firmwareUpdater.currentUpdate.totalCount, 0);
    XCTAssertEqual(firmwareUpdater.currentUpdate.totalProgress, 0);
    XCTAssertEqual(firmwareUpdater.currentUpdate.state, GSUpdaterUpdateStateUploading);
}

- (void)testMediaStore {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.mediaStore.uid droneUid:@"123"];

    id<GSMediaStore> mediaStore = (id<GSMediaStore>) [drone getPeripheral:GSPeripherals.mediaStore];
    XCTAssertNotNil(mediaStore);
    XCTAssertEqual(mediaStore.indexingState, GSMediaStoreIndexingStateUnavailable);
    XCTAssertEqual(mediaStore.photoMediaCount, 0);
    XCTAssertEqual(mediaStore.photoResourceCount, 0);
    XCTAssertEqual(mediaStore.videoMediaCount, 0);
    XCTAssertEqual(mediaStore.videoResourceCount, 0);

    GSMediaListRef* listRef = [mediaStore newList:^(NSArray<GSMediaItem *> * medialist) {}];
    XCTAssertNotNil(listRef.value);
    XCTAssertEqualObjects(listRef.value[0].uid, @"1");
    XCTAssertEqualObjects(listRef.value[0].name, @"media1");
    XCTAssertEqual(listRef.value[0].type, GSMediaItemTypePhoto);
    XCTAssertEqual(listRef.value[0].hasPhotoMode, YES);
    XCTAssertEqual(listRef.value[0].photoMode, GSMediaItemPhotoModeSingle);
    XCTAssertEqual(listRef.value[0].hasPanoramaType, NO);
    XCTAssertEqual(listRef.value[0].hasExpectedCount, NO);
    XCTAssertEqual(listRef.value[0].expectedCount,0);
    XCTAssertEqual(listRef.value[0].panoramaType, GSMediaItemPanoramaTypeHorizontal_180);
    XCTAssertEqualObjects(listRef.value[0].runUid, @"r1");
    XCTAssertEqualObjects(listRef.value[0].creationDate.description, @"2016-01-02 00:00:00 +0000");
    XCTAssertEqual([listRef.value[0] hasMetadataType: GSMetadataTypeThermal], NO);

    XCTAssertEqual(listRef.value[0].resources.count, 2);
    GSMediaItemResource* r1 = listRef.value[0].resources[0];
    XCTAssertEqual(r1.format, GSMediaItemFormatMp4);
    XCTAssertEqual(r1.size, 20);
    XCTAssertEqual(r1.duration, 15.2);
    XCTAssertEqual(r1.streamable, YES);
    GSMediaItemResource* r2 = listRef.value[0].resources[1];
    XCTAssertEqual(r2.format, GSMediaItemFormatDng);
    XCTAssertEqual(r2.size, 100);
    XCTAssertEqual(r2.duration, 0);
    XCTAssertEqual(r2.streamable, NO);
    XCTAssertEqual(r2.location, nil);
    XCTAssertNotNil(r2.creationDate);
    XCTAssertEqual([r2 hasMetadataType: GSMetadataTypeThermal], NO);

    GSMediaImageRef *imageRef = [mediaStore newThumbnailDownloaderForMedia:listRef.value[0]
                                                                  observer:^(UIImage * _Nullable img) {}];
    GSMediaDownloaderRef *downloaderRef =
    [mediaStore newDownloaderForMediaResources:[GSMediaResourceListFactory listWithAllOf:listRef.value]
                                   destination:[[GSDownloadDestination alloc]init]
                                      observer:^(GSMediaDownloader * downloader) { }];
    XCTAssertEqual(downloaderRef.value.totalMediaCount, 1);
    XCTAssertEqual(downloaderRef.value.currentMediaCount, 0);
    XCTAssertEqual(downloaderRef.value.totalResourceCount, 1);
    XCTAssertEqual(downloaderRef.value.currentResourceCount, 0);
    XCTAssertEqual(downloaderRef.value.currentFileProgress, 0.0);
    XCTAssertEqual(downloaderRef.value.totalProgress, 0.0);
    XCTAssertEqual(downloaderRef.value.status, GSMediaTaskStatusRunning);

    GSMediaDeleterRef *deleter = [mediaStore newDeleterForMedia:listRef.value observer:^(GSMediaDeleter * _Nullable deleter) {}];
    XCTAssertEqual(deleter.value.status, GSMediaTaskStatusRunning);
    XCTAssertEqual(deleter.value.totalCount, 2);
    XCTAssertEqual(deleter.value.currentCount, 1);

    GSAllMediasDeleterRef *allDeleter = [mediaStore newAllMediasDeleterWithObserver:^(GSAllMediaDeleter * _Nullable deleter) {}];
    XCTAssertEqual(allDeleter.value.status, GSMediaTaskStatusRunning);
}

- (void)testRemovableUserStorage {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.removableUserStorage.uid droneUid:@"123"];

    id<GSRemovableUserStorage> removableUserStorage =
    (id<GSRemovableUserStorage>) [drone getPeripheral:GSPeripherals.removableUserStorage];
    XCTAssertNotNil(removableUserStorage);

    XCTAssertEqual(removableUserStorage.physicalState, GSUserStoragePhysicalStateNoMedia);
    XCTAssertEqual(removableUserStorage.fileSystemState, GSUserStorageFileSystemStateError);
    XCTAssertNotNil(removableUserStorage.mediaInfo);
    XCTAssertEqual(removableUserStorage.availableSpace, 5);
    XCTAssertEqual(removableUserStorage.canFormat, YES);
    XCTAssertEqual([removableUserStorage formatWithFormattingType: GSFormattingTypeQuick], YES);
    XCTAssertEqual([removableUserStorage formatWithFormattingType: GSFormattingTypeQuick newMediaName: @"abc"] , YES);

    XCTAssertEqual([removableUserStorage isFormattingTypeSupported: GSFormattingTypeQuick], NO);
    XCTAssertEqual([removableUserStorage isFormattingTypeSupported: GSFormattingTypeFull], YES);
}

- (void)testSkyCtrl3Gamepad {
    __block id<GSSkyCtrl3Gamepad> gamepad;
    __block int nbCalls = 0;

    GSRemoteControl *rc = [_gsdk getRemoteControlWithUid:@"333"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.skyCtrl3Gamepad.uid rcUid:@"333"];

    GSPeripheralRef *gamepadRef = [rc getPeripheral:GSPeripherals.skyCtrl3Gamepad
                                           observer:(^(id <GSSkyCtrl3Gamepad> newGamepad) {
        gamepad = newGamepad;
        nbCalls++;
    })];
    SkyCtrl3GamepadCore *impl = (SkyCtrl3GamepadCore*) [rc getPeripheral:GSPeripherals.skyCtrl3Gamepad];
    XCTAssertNotNil(gamepad);
    XCTAssertEqual(nbCalls, 1);
    XCTAssertEqual([gamepad mappingForModel:GSDroneModelAnafi4k].count, 0);

    // try to register a mapping entry
    NSSet *buttonSet = [[NSSet alloc] initWithObjects:[NSNumber numberWithInt:GSSkyCtrl3ButtonRearLeftButton], nil];
    GSSkyCtrl3MappingEntry *mappingEntry = [[GSSkyCtrl3AxisMappingEntry alloc] initWithDroneModel:GSDroneModelAnafi4k action:GSAxisMappableActionPanCamera axisEvent:GSSkyCtrl3AxisEventLeftSlider buttonEventsAsInt:buttonSet];
    [gamepad registerMappingEntry:mappingEntry];

    [[impl updateAxisMappings:[NSArray arrayWithObject:mappingEntry]] notifyUpdated];
    XCTAssertEqual(nbCalls, 2);
    XCTAssertEqual([[gamepad mappingForModel:GSDroneModelAnafi4k] containsObject:mappingEntry], YES);

    // check active drone model
    [[impl updateActiveDroneModel:GSDroneModelAnafi4k] notifyUpdated];
    XCTAssertEqual(nbCalls, 3);
    XCTAssertEqual([gamepad activeDroneModelAsNumber], [NSNumber numberWithInteger:GSDroneModelAnafi4k]);
}

- (void)testStreamServer {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.streamServer.uid droneUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.mediaStore.uid droneUid:@"123"];

    id<GSStreamServer> streamServer = (id<GSStreamServer>) [drone getPeripheral:GSPeripherals.streamServer];
    XCTAssertNotNil(streamServer);
    XCTAssertEqual(streamServer.enabled, false);

    GSCameraLiveRef* cameraLiveRef = [streamServer liveWithObserver:^(id<GSCameraLive> _Nullable stream) {
    }];
    XCTAssertNotNil(cameraLiveRef);
    XCTAssertEqual(cameraLiveRef.value.state, GSStateStopped);
    XCTAssertEqual(cameraLiveRef.value.playState, GSCameraLivePlayStateNone);
    BOOL res = [cameraLiveRef.value play];
    res = [cameraLiveRef.value pause];
    [cameraLiveRef.value stop];

    id<GSMediaStore> mediaStore = (id<GSMediaStore>) [drone getPeripheral:GSPeripherals.mediaStore];
    GSMediaListRef* listRef = [mediaStore newList:^(NSArray<GSMediaItem *> * medialist) {}];
    GSMediaItemResource* mockResource = listRef.value[0].resources[0];
    
    GSMediaReplayRef* mediaReplayRef = [streamServer replayWithSource:[GSMediaReplaySourceFactory videoTrackOf:mockResource track:GSMediaItemTrackDefaultVideo] observer:^(id<GSMediaReplay> _Nullable stream) {
    }];

    XCTAssertNotNil(mediaReplayRef);
    XCTAssertEqual(mediaReplayRef.value.state, GSStateStopped);
    XCTAssertEqual(mediaReplayRef.value.playState, GSReplayPlayStateNone);
    XCTAssertEqual(mediaReplayRef.value.duration, 0);
    XCTAssertEqual(mediaReplayRef.value.position, 0);
    res = [mediaReplayRef.value play];
    res = [mediaReplayRef.value pause];
    res = [mediaReplayRef.value seekToPosition:0];
    [mediaReplayRef.value stop];
}

- (void)testCamera {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.mainCamera.uid droneUid:@"123"];

    id<GSCamera> camera = (id<GSCamera>) [drone getPeripheral:GSPeripherals.mainCamera];
    XCTAssertNotNil(camera);

    // active
    XCTAssertFalse(camera.isActive);

    // mode
    XCTAssertTrue([camera.modeSetting isModeSupported:GSCameraModeRecording]);
    XCTAssertEqual(camera.modeSetting.mode, GSCameraModeRecording);
    XCTAssertEqual(camera.modeSetting.updating, false);

    // exposure
    XCTAssertTrue([camera.exposureSettings isModeSupported:GSCameraExposureModeAutomatic]);
    XCTAssertTrue([camera.exposureSettings isManualShutterSpeedSupported:GSCameraShutterSpeedOne]);
    XCTAssertTrue([camera.exposureSettings isManualIsoSensitivitySupported:GSCameraIso100]);
    XCTAssertTrue([camera.exposureSettings isMaximumIsoSensitivitySupported:GSCameraIso3200]);

    XCTAssertEqual(camera.exposureSettings.mode, GSCameraExposureModeAutomatic);
    XCTAssertEqual(camera.exposureSettings.manualShutterSpeed, GSCameraShutterSpeedOne);
    XCTAssertEqual(camera.exposureSettings.manualIsoSensitivity, GSCameraIso100);
    XCTAssertEqual(camera.exposureSettings.maximumIsoSensitivity, GSCameraIso3200);
    XCTAssertEqual(camera.exposureSettings.updating, false);
    [camera.exposureSettings setMode:GSCameraExposureModeManual
                   manualShutterSpeed:-1
                 manualIsoSensitivity:GSCameraShutterSpeedOneOver3
                maximumIsoSensitivity:GSCameraIso50
            autoExposureMeteringMode: GSCameraAutoExposureMeteringModeStandard];

    // exposure lock
    XCTAssertEqual(camera.exposureLock.mode, GSCameraExposureLockModeNone);
    XCTAssertEqual(camera.exposureLock.regionCenterX, 0);
    XCTAssertEqual(camera.exposureLock.regionCenterY, 0);
    XCTAssertEqual(camera.exposureLock.regionWidth, 0);
    XCTAssertEqual(camera.exposureLock.regionHeight, 0);
    XCTAssertFalse(camera.exposureLock.updating);
    [camera.exposureLock unlock];
    [camera.exposureLock lockOnCurrentValues];
    [camera.exposureLock lockOnRegionWithCenterX:0.0 centerY:0.5];

    // exposure compensation
    XCTAssertTrue([camera.exposureCompensationSetting isValueSupported:GSCameraEv0_00]);
    XCTAssertEqual(camera.exposureCompensationSetting.value, GSCameraEv0_00);
    XCTAssertEqual(camera.modeSetting.updating, false);

    // white balance
    XCTAssertTrue([camera.whiteBalanceSettings isModeSupported:GSCameraWhiteBalanceModeAutomatic]);
    XCTAssertTrue([camera.whiteBalanceSettings isCustomTemperatureSupported:GSCameraWhiteBalanceTemperature1500]);

    XCTAssertEqual(camera.whiteBalanceSettings.mode, GSCameraWhiteBalanceModeAutomatic);
    XCTAssertEqual(camera.whiteBalanceSettings.customTemperature, GSCameraWhiteBalanceTemperature1500);
    XCTAssertEqual(camera.whiteBalanceSettings.updating, false);
    [camera.whiteBalanceSettings setCustomTemperature:GSCameraWhiteBalanceTemperature3500];
    // whiteBalanceLock
    XCTAssertEqual(camera.whiteBalanceLock.isLockableSupported, false);
    XCTAssertEqual(camera.whiteBalanceLock.isLockable, false);
    [camera.whiteBalanceLock setLockWithLock:true];
    XCTAssertEqual(camera.whiteBalanceLock.isLockableSupported, false);
    XCTAssertEqual(camera.whiteBalanceLock.isLockable, false);
    XCTAssertEqual(camera.whiteBalanceLock.updating, false);

    // hdr
    XCTAssertNil(camera.hdrSetting);
    XCTAssertFalse(camera.hdrState);

    // styles
    XCTAssertTrue([camera.styleSettings isStyleSupported:GSCameraStyleStandard]);
    XCTAssertEqual(camera.styleSettings.saturation.min , 0);
    XCTAssertEqual(camera.styleSettings.saturation.value , 0);
    XCTAssertEqual(camera.styleSettings.saturation.max , 0);
    XCTAssertEqual(camera.styleSettings.saturation.mutable, false);
    [camera.styleSettings.saturation setValue:0];

    // recording settings
    XCTAssertTrue([camera.recordingSettings isModeSupported:GSCameraRecordingModeStandard]);
    XCTAssertTrue([camera.recordingSettings isResolutionSupported:GSCameraRecordingResolutionUhd4k]);
    XCTAssertTrue([camera.recordingSettings isResolutionSupported:GSCameraRecordingResolutionUhd4k
                                                          forMode:GSCameraRecordingModeStandard]);
    XCTAssertTrue([camera.recordingSettings isFramerateSupported:GSCameraRecordingFramerate30]);
    XCTAssertTrue([camera.recordingSettings isFramerateSupported:GSCameraRecordingFramerate30
                                                         forMode:GSCameraRecordingModeStandard
                                                   andResolution:GSCameraRecordingResolutionUhd4k]);
    XCTAssertTrue(camera.recordingSettings.hdrAvailable);
    XCTAssertTrue([camera.recordingSettings isHdrAvailableForMode:GSCameraRecordingModeStandard
                                                       resolution:GSCameraRecordingResolutionUhd4k
                                                        framerate:GSCameraRecordingFramerate30]);
    XCTAssertTrue([camera.recordingSettings isHyperlapseValueSupported:GSCameraHyperlapseValueRatio30]);

    XCTAssertEqual(camera.recordingSettings.mode, GSCameraRecordingModeStandard);
    XCTAssertEqual(camera.recordingSettings.resolution, GSCameraRecordingResolutionUhd4k);
    XCTAssertEqual(camera.recordingSettings.framerate, GSCameraRecordingFramerate30);
    XCTAssertEqual(camera.recordingSettings.hyperlapseValue, GSCameraHyperlapseValueRatio30);
    [camera.recordingSettings setMode:GSCameraRecordingModeStandard
                           resolution:GSCameraRecordingResolutionDci4k
                            framerate:GSCameraRecordingFramerate30
                      hyperlapseValue:GSCameraHyperlapseValueRatio30];

    // auto-record setting
    XCTAssertNil(camera.autoRecordSetting);

    // photos settings
    XCTAssertTrue([camera.photoSettings isModeSupported:GSCameraPhotoModeSingle]);
    XCTAssertTrue([camera.photoSettings isFormatSupported:GSCameraPhotoFormatFullFrame]);
    XCTAssertTrue([camera.photoSettings isFormatSupported:GSCameraPhotoFormatFullFrame
                                                  forMode:GSCameraPhotoModeSingle]);
    XCTAssertTrue([camera.photoSettings isFileFormatSupported:GSCameraPhotoFileFormatDng]);
    XCTAssertTrue([camera.photoSettings isFileFormatSupported:GSCameraPhotoFileFormatDng
                                                 forPhotoMode:GSCameraPhotoModeSingle
                                               andPhotoFormat:GSCameraPhotoFormatFullFrame]);
    XCTAssertTrue(camera.photoSettings.hdrAvailable);
    XCTAssertTrue([camera.photoSettings isHdrAvailableForMode:GSCameraPhotoModeSingle
                                                       format:GSCameraPhotoFormatFullFrame
                                                   fileFormat:GSCameraPhotoFileFormatDng]);
    XCTAssertTrue([camera.photoSettings isBurstValueSupported:GSCameraBurst4Over1s]);
    XCTAssertTrue([camera.photoSettings isBracketingValueSupported:GSCameraBracketingPreset1ev2ev]);

    XCTAssertEqual(camera.photoSettings.mode, GSCameraPhotoModeSingle);
    XCTAssertEqual(camera.photoSettings.format, GSCameraPhotoFormatFullFrame);
    XCTAssertEqual(camera.photoSettings.fileFormat, GSCameraPhotoFileFormatDng);
    XCTAssertEqual(camera.photoSettings.burstValue, GSCameraBurst4Over1s);
    XCTAssertEqual(camera.photoSettings.bracketingValue, GSCameraBracketingPreset1ev2ev);
    [camera.photoSettings setMode:GSCameraPhotoModeBurst
                           format:GSCameraPhotoFormatFullFrame
                       fileformat:GSCameraPhotoFileFormatDng
                       burstValue:GSCameraBurst4Over1s
                  bracketingValue:GSCameraBracketingPreset1ev2ev
     gpslapseCaptureIntervalValue:0.0
    timelapseCaptureIntervalValue:0.0];

    // take picture
    XCTAssertEqual(camera.photoState.functionState, GSCameraPhotoFunctionStateUnavailable);
    XCTAssertEqual(camera.photoState.photoCount, 0);
    XCTAssertEqual(camera.photoState.mediaId, NULL);

    // zoom
    XCTAssertEqual(camera.zoom.maxSpeed.value, 0.0);
    XCTAssertFalse(camera.zoom.velocityQualityDegradationAllowance.value);
    XCTAssertFalse(camera.zoom.isAvailable);
    XCTAssertEqual(camera.zoom.currentLevel, 0.0);
    XCTAssertEqual(camera.zoom.maxLossyLevel, 0.0);
    XCTAssertEqual(camera.zoom.maxLossLessLevel, 0.0);

    camera.zoom.maxSpeed.value = 1.0;
    camera.zoom.velocityQualityDegradationAllowance.value = YES;
    [camera.zoom controlWithMode:GSCameraZoomControlModeLevel target:2.0];
    [camera.zoom controlWithMode:GSCameraZoomControlModeVelocity target:-1.0];

    // alignment
    XCTAssertEqual(camera.alignment.yaw, 0.0);
    XCTAssertEqual(camera.alignment.pitch, 0.0);
    XCTAssertEqual(camera.alignment.roll, 0.0);
    XCTAssertEqual(camera.alignment.gsMinSupportedYawRange, 0.0);
    XCTAssertEqual(camera.alignment.gsMaxSupportedYawRange, 0.0);
    XCTAssertEqual(camera.alignment.gsMinSupportedPitchRange, 0.0);
    XCTAssertEqual(camera.alignment.gsMaxSupportedPitchRange, 0.0);
    XCTAssertEqual(camera.alignment.gsMinSupportedRollRange, 0.0);
    XCTAssertEqual(camera.alignment.gsMaxSupportedRollRange, 0.0);

    XCTAssertEqual([camera.alignment reset], false);
}

- (void)testAntiflicker {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.antiflicker.uid droneUid:@"123"];
    id<GSAntiflicker> antiflicker = (id<GSAntiflicker>) [drone getPeripheral:GSPeripherals.antiflicker];
    XCTAssertNotNil(antiflicker);
    XCTAssertEqual(antiflicker.setting.mode, GSAntiflickerModeOff);
    XCTAssertFalse(antiflicker.setting.updating);
    XCTAssertFalse([antiflicker.setting isModeSupported:GSAntiflickerMode50Hz]);
    antiflicker.setting.mode = GSAntiflickerMode60Hz;
    XCTAssertEqual(antiflicker.value, GSAntiflickerValueUnknown);
}

- (void)testPreciseHome {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.preciseHome.uid droneUid:@"123"];
    id<GSPreciseHome> preciseHome = (id<GSPreciseHome>) [drone getPeripheral:GSPeripherals.preciseHome];
    XCTAssertNotNil(preciseHome);
    XCTAssertEqual(preciseHome.setting.mode, GSPreciseHomeModeDisabled);
    XCTAssertFalse(preciseHome.setting.updating);
    XCTAssertFalse([preciseHome.setting isModeSupported:GSPreciseHomeModeDisabled]);
    preciseHome.setting.mode = GSPreciseHomeModeStandard;
    XCTAssertEqual(preciseHome.state, GSPreciseHomeStateUnavailable);
}

- (void)testPilotingControl {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.pilotingControl.uid droneUid:@"123"];
    id<GSPilotingControl> pilotingControl = (id<GSPilotingControl>) [drone getPeripheral:GSPeripherals.pilotingControl];
    XCTAssertNotNil(pilotingControl);
}

- (void)testCopilot {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.copilot.uid droneUid:@"123"];
    id<GSCopilot> copilot = (id<GSCopilot>) [drone getPeripheral:GSPeripherals.copilot];
    XCTAssertNotNil(copilot);
}

- (void)testThermalControl{
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.thermalControl.uid droneUid:@"123"];
    id<GSThermalControl> thermalControl = (id<GSThermalControl>) [drone getPeripheral:GSPeripherals.thermalControl];
    XCTAssertNotNil(thermalControl);

    XCTAssertEqual(thermalControl.setting.mode, GSThermalControlModeDisabled);
    XCTAssertFalse(thermalControl.setting.updating);
    XCTAssertFalse([thermalControl.setting isModeSupported:GSThermalControlModeDisabled]);
    thermalControl.setting.mode = GSThermalControlModeStandard;

    GSThermalColor *color1 = [[GSThermalColor alloc] init:0 :0 :1 :0];
    GSThermalColor *color2 = [[GSThermalColor alloc] init:0 :1 :0 :1];
    GSThermalColor *color3 = [[GSThermalColor alloc] init:0 :0 :1 :2];
    NSArray<GSThermalColor *> *colors = [[NSArray alloc] initWithObjects:color1, color2, color3, nil];

    GSThermalAbsolutePalette *aboslutePalette = [[GSThermalAbsolutePalette alloc] initWithColors:colors
                                                                                      lowestTemp:0.0
                                                                                     highestTemp:0.0
                                                                             outsideColorization:GSThermalColorizationModeExtended];
    [thermalControl sendPalette:aboslutePalette];

    GSThermalRelativePalette *relativePalette = [[GSThermalRelativePalette alloc] initWithColors:colors
                                                                                          locked:true
                                                                                      lowestTemp:0.0
                                                                                     highestTemp:0.0];
    [thermalControl sendPalette:relativePalette];

    GSThermalSpotPalette *spotPalette = [[GSThermalSpotPalette alloc] initWithColors:colors
                                                                                type:GSThermalSpotTypeCold
                                                                           threshold:100];
    [thermalControl sendPalette:spotPalette];

    XCTAssertEqual(thermalControl.calibration.mode, GSThermalCalibrationModeAutomatic);
    XCTAssertFalse(thermalControl.calibration.updating);
    XCTAssertFalse([thermalControl.calibration isModeSupported:GSThermalCalibrationModeAutomatic]);
}

- (void)testGimbal {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.gimbal.uid droneUid:@"123"];

    id<GSGimbal> gimbal = (id<GSGimbal>) [drone getPeripheral:GSPeripherals.gimbal];
    XCTAssertNotNil(gimbal);

    BOOL resBool = [gimbal isAxisSupported:GSGimbalAxisYaw];
    resBool = [gimbal isAxisLocked:GSGimbalAxisRoll];
    id<GSDoubleSetting> maxSpeed = [gimbal maxSpeedOnAxis:GSGimbalAxisPitch];
    id<GSBoolSetting> stab = [gimbal stabilizationOnAxis:GSGimbalAxisPitch];
    NSNumber *resNumber = [gimbal attitudeLowerBoundOnAxis:GSGimbalAxisPitch];
    resNumber = [gimbal attitudeUpperBoundOnAxis:GSGimbalAxisPitch];
    [gimbal controlWithMode:GSGimbalControlModePosition yaw:nil pitch:[NSNumber numberWithDouble:0.0] roll:nil];

    [gimbal startOffsetsCorrectionProcess];
    resBool = [gimbal.offsetsCorrectionProcess isAxisCorrectable:GSGimbalAxisPitch];
    id<GSDoubleSetting> offset = [gimbal.offsetsCorrectionProcess offsetCorrectionOnAxis:GSGimbalAxisRoll];
    [gimbal stopOffsetsCorrectionProcess];
    resBool = [gimbal hasError:GSGimbalErrorCritical];

    [gimbal startCalibration];
    [gimbal cancelCalibration];
    XCTAssertEqual(gimbal.calibrationProcessState, GSGimbalCalibrationProcessStateNone);
    XCTAssertEqual(gimbal.calibrated, false);
}

- (void)testWifiScanner {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.wifiScanner.uid droneUid:@"123"];

    id<GSWifiScanner> wifiScanner = (id<GSWifiScanner>) [drone getPeripheral:GSPeripherals.wifiScanner];
    XCTAssertNotNil(wifiScanner);
    XCTAssertFalse(wifiScanner.scanning);

    [wifiScanner startScan];
    [wifiScanner stopScan];
    NSInteger occupation = [wifiScanner getOccupationRateForChannel:GSWifiChannelBand_2_4_channel1];
    GSBand band = [GSWifiChannelInfo getBandFromWifiChannel:GSWifiChannelBand_2_4_channel1];
    NSInteger channel = [GSWifiChannelInfo getChannelIdFromWifiChannel:GSWifiChannelBand_2_4_channel1];

    XCTAssertEqual(band, GSBandBand_2_4_Ghz);
    XCTAssertEqual(channel, 1);
}

- (void)testWifiAccessPoint {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.wifiAccessPoint.uid droneUid:@"123"];

    id<GSWifiAccessPoint> wifiAccessPoint = (id<GSWifiAccessPoint>) [drone getPeripheral:GSPeripherals.wifiAccessPoint];
    XCTAssertNotNil(wifiAccessPoint);
    XCTAssertNotNil(wifiAccessPoint.environment);
    XCTAssertNotNil(wifiAccessPoint.isoCountryCode);
    XCTAssertNotNil(wifiAccessPoint.availableCountries);
    XCTAssertNotNil(wifiAccessPoint.channel);
    XCTAssertNotNil(wifiAccessPoint.ssid);
    XCTAssertNotNil(wifiAccessPoint.security);
    BOOL resultSupported = [wifiAccessPoint.security isModeSupported:GSSecurityModeOpen];

    [wifiAccessPoint.security open];
    BOOL result = [wifiAccessPoint.security secureWithWpa2WithPassword:@"password"];

    id<GSSecurityModeSetting> modeSetting =  wifiAccessPoint.security;
    BOOL valid = [modeSetting secureWithWpa2WithPassword:@"mypassword"];

    NSString *passwordPattern = GSWifiPasswordUtil.passwordPattern ;
    valid = [GSWifiPasswordUtil isValid:@"apassword"];

    XCTAssertNotNil(wifiAccessPoint.channel.availableChannelsAsInt);
    [wifiAccessPoint.channel selectWithChannel:GSWifiChannelBand_5_channel34];
    BOOL canAutoSelectOnBand = [wifiAccessPoint.channel canAutoSelectOnBand:GSBandBand_2_4_Ghz];
    [wifiAccessPoint.channel autoSelectOnBand:GSBandBand_2_4_Ghz];
    BOOL canAutoSelect = [wifiAccessPoint.channel canAutoSelect];
    [wifiAccessPoint.channel autoSelect];
}

- (void)testBeeper {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.beeper.uid droneUid:@"123"];

    id<GSBeeper> beeper = (id<GSBeeper>) [drone getPeripheral:GSPeripherals.beeper];
    XCTAssertNotNil(beeper);

    XCTAssertEqual(beeper.alertSoundPlaying, false);

    BOOL res;
    res = [beeper startAlertSound];
    res = [beeper stopAlertSound];
}

- (void)testTargetTracker {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.targetTracker.uid droneUid:@"123"];

    id<GSTargetTracker> targetTracker = (id<GSTargetTracker>) [drone getPeripheral:GSPeripherals.targetTracker];
    XCTAssertNotNil(targetTracker);

    double valHorizontal = targetTracker.framing.horizontalPosition;
    double valVertical = targetTracker.framing.verticalPosition;
    [targetTracker.framing setValueWithHorizontal:valHorizontal vertical:valVertical];
    BOOL testUpdating = targetTracker.framing.updating;
    GSTargetDetectionInfo *imageDetectionInfo = [[GSTargetDetectionInfo alloc] initWithTargetAzimuth:0.0
                                                                                     targetElevation:0.0
                                                                                       changeOfScale:0.0
                                                                                          confidence:0.0
                                                                                         isNewTarget:NO
                                                                                           timestamp:0];
    [targetTracker sendTargetDetectionInfo:imageDetectionInfo];
    [targetTracker enableControllerTracking];
    [targetTracker disableControllerTracking];

    id<GSTargetTrajectory> trajectory = targetTracker.targetTrajectory;
    double altitude = trajectory.altitude;
    double latitude = trajectory.latitude;
    double longitude = trajectory.longitude;
    double northSpeed = trajectory.northSpeed;
    double east = trajectory.eastSpeed;
    double downSpeed = trajectory.downSpeed;
}

- (void)testGeofence {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.geofence.uid droneUid:@"123"];
    id<GSGeofence> geofence = (id<GSGeofence>) [drone getPeripheral:GSPeripherals.geofence];
    XCTAssertNotNil(geofence);
    XCTAssertEqual(geofence.mode.value, GSGeofenceModeAltitude);
    XCTAssertFalse(geofence.mode.updating);
    XCTAssertNotNil(geofence.maxDistance);
    XCTAssertNotNil(geofence.maxAltitude);
    CLLocation *center = geofence.center;
}

- (void)testFlightData {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.flightDataDownloader.uid droneUid:@"123"];
    id<GSFlightDataDownloader> flightDataDownloader =
    (id<GSFlightDataDownloader>) [drone getPeripheral:GSPeripherals.flightDataDownloader];
    XCTAssertNotNil(flightDataDownloader);
    BOOL isDownloading = flightDataDownloader.isDownloading;
    GSFlightDataDownloaderState *state = flightDataDownloader.state;

    GSFlightDataDownloadCompletionStatus status = state.status;
    status = GSFlightDataDownloadCompletionStatusNone;
    NSInteger count = state.latestDownloadCount;
}

- (void)testFlightLog {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.flightLogDownloader.uid droneUid:@"123"];
    id<GSFlightLogDownloader> flightLogDownloader =
    (id<GSFlightLogDownloader>) [drone getPeripheral:GSPeripherals.flightLogDownloader];
    XCTAssertNotNil(flightLogDownloader);
    BOOL isDownloading = flightLogDownloader.isDownloading;
    GSFlightLogDownloaderState *state = flightLogDownloader.state;

    GSFlightLogDownloadCompletionStatus status = state.status;
    status = GSFlightLogDownloadCompletionStatusNone;
    NSInteger count = state.downloadedCount;
}

- (void)testCrashml {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.crashReportDownloader.uid droneUid:@"123"];
    id<GSCrashReportDownloader> crashReportDownloader =
    (id<GSCrashReportDownloader>) [drone getPeripheral:GSPeripherals.crashReportDownloader];
    XCTAssertNotNil(crashReportDownloader);
    BOOL isDownloading = crashReportDownloader.isDownloading;
    GSCrashReportDownloaderState *state = crashReportDownloader.state;

    GSCrashReportDownloadCompletionStatus status = state.status;
    status = GSCrashReportDownloadCompletionStatusNone;
    NSInteger count = state.downloadedCount;
}

- (void)testEmissivity {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.thermalControl.uid droneUid:@"123"];
    id<GSThermalControl> thermalControl = (id<GSThermalControl>) [drone getPeripheral:GSPeripherals.thermalControl];
    [thermalControl sendEmissivity:0.5];
}

- (void)testSensitivityRange {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.thermalControl.uid droneUid:@"123"];
    id<GSThermalControl> thermalControl = (id<GSThermalControl>) [drone getPeripheral:GSPeripherals.thermalControl];
    XCTAssertNotNil(thermalControl);
    XCTAssertEqual(thermalControl.sensitivitySetting.sensitivityRange, GSThermalSensitivityRangeHigh);
    thermalControl.sensitivitySetting.sensitivityRange = GSThermalSensitivityRangeLow;
    XCTAssertEqual([thermalControl.sensitivitySetting isSensitivityRangeSupported:GSThermalSensitivityRangeHigh], true);
    XCTAssertEqual([thermalControl.sensitivitySetting isSensitivityRangeSupported:GSThermalSensitivityRangeLow], true);
}

- (void)testBackgroundTemperature {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.thermalControl.uid droneUid:@"123"];
    id<GSThermalControl> thermalControl = (id<GSThermalControl>) [drone getPeripheral:GSPeripherals.thermalControl];
    [thermalControl sendBackgroundTemperature:250.0];
}

- (void)testRendering {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.thermalControl.uid droneUid:@"123"];
    id<GSThermalControl> thermalControl = (id<GSThermalControl>) [drone getPeripheral:GSPeripherals.thermalControl];
    [thermalControl sendRenderingWithRendering: [[GSThermalRendering alloc] initWithMode:GSThermalRenderingModeBlended blendingRate:0.5]];

}

- (void)testLeds {
    GSDrone *drone = [_gsdk getDroneWithUid:@"123"];
    [_mockGsdk addPeripheralWithUid:GSPeripherals.leds.uid droneUid:@"123"];
    id<GSLeds> leds = (id<GSLeds>) [drone getPeripheral:GSPeripherals.leds];
    XCTAssertNotNil(leds);
}
@end
