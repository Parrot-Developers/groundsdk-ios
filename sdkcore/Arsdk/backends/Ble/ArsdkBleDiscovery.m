//    Copyright (C) 2019 Parrot Drones SAS
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


#import "ArsdkBleDiscovery.h"
#import "ArsdkDiscovery+Protected.h"
#import <arsdkctrl/arsdkctrl.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "Logger.h"

extern ULogTag* TAG;

/** discovery timeout in second before restarting discovery */
#define DISCOVERY_TIMEOUT 5
/** number of time a discovered devices is considered not visible anymore */
#define DISCOVERY_CNT 2

@interface DeviceInfo : NSObject
-(instancetype)initWithName:(NSString*)name andType:(NSInteger)type;
@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) NSInteger deviceType;
@property (nonatomic, readwrite) NSInteger discoveryCnt;
@end

@interface ArsdkBleDiscovery() <ArsdkBleScanDelegate>
/** CBCentralManger wrapper */
@property (nonatomic) ArsdkBle* arsdkBle;
/** Device types */
@property (nonatomic, strong) NSSet<NSNumber *> *deviceTypes;
/** Discovery timer */
@property (nonatomic) NSTimer* timer;
/** Dictionnay of discovered devices by uuid */
@property (nonatomic) NSMutableDictionary<NSString*, DeviceInfo*>* devices;
@end


@implementation ArsdkBleDiscovery

/**
 Constructor
 */
-(instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore backend:(ArsdkBleBackend*)backend arsdkBle:(ArsdkBle*)arsdkBle
                     deviceTypes:(NSSet<NSNumber*>*)deviceTypes {
    self =  [super initWithArsdkCore:arsdkCore backend:backend.backend andName:@"ble"];
    if (self) {
        _arsdkBle = arsdkBle;
        _arsdkBle.scanDelegate = self;
        _deviceTypes = deviceTypes;
        _devices = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    return self;
}


-(void) doStart {
    [super doStart];
    [self startScan];
}

-(void) doStop {
    [self stopScan];
    [_devices removeAllObjects];
    [super doStop];
}

-(void)startScan {
    _timer = [NSTimer scheduledTimerWithTimeInterval:DISCOVERY_TIMEOUT target:self selector:@selector(scanTimeout)
                                            userInfo:nil repeats:NO];
    [_arsdkBle startScan];
}

-(void)stopScan {
    [_arsdkBle stopScan];
    [_timer invalidate];
    _timer = nil;
}

-(void)scanTimeout {
    [_arsdkBle stopScan];
    [_timer invalidate];
    _timer = nil;
    for (NSString* uuid in _devices.allKeys) {
        DeviceInfo* deviceInfo = _devices[uuid];
        CBPeripheral* peripheral = [_arsdkBle peripheralWithUid:uuid];
        // connected devices are always visible
        if (!peripheral || peripheral.state == CBPeripheralStateDisconnected) {
            deviceInfo.discoveryCnt--;
            if (deviceInfo.discoveryCnt <= 0) {
                [_devices removeObjectForKey:uuid];
                [self removeDeviceWithUid:uuid type:deviceInfo.deviceType];
            }
        }
    }
    [self startScan];
}


#pragma mark ArsdkBleScanDelegate
- (void)arsdkBle:(nonnull ArsdkBle *)manager didDiscover:(nonnull NSString *)name
      deviceType:(NSInteger)deviceType uuid:(nullable NSString *)uuid rssi:(nonnull NSNumber *)rssi {
    if (_devices[uuid] == nil && [_deviceTypes containsObject:[NSNumber numberWithLong:deviceType]]) {
        if ([ULog d:TAG]) {
            [ULog d:TAG msg:@"Adding %s %x %s %d", name.UTF8String, deviceType, uuid.UTF8String, rssi];
        }
        [self addDevice:name type:deviceType addr:uuid port:0 uid:uuid];
    }
    _devices[uuid] = [[DeviceInfo alloc ]initWithName:name andType:deviceType];
}

@end


@implementation DeviceInfo
-(instancetype)initWithName:(NSString*)name andType:(NSInteger)type {
    self = [super init];
    if (self) {
        _name = name;
        _deviceType = type;
        _discoveryCnt = DISCOVERY_CNT;
    }
    return self;
}
@end
