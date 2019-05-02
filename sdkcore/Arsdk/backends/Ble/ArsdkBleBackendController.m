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

#import "ArsdkBleBackendController.h"
#import "ArsdkBle.h"
#import "ArsdkBleBackend.h"
#import "ArsdkBleDiscovery.h"

#import "Logger.h"

extern ULogTag* TAG;

@interface ArsdkBleBackendController() <ArsdkBleStateDelegate>
/** Device types */
@property (nonatomic, strong) NSSet<NSNumber *> *deviceTypes;
/** CBCentralManager wrapper */
@property (nonatomic) ArsdkBle *arsdkBle;
/** Net backend */
@property (nonatomic, strong) ArsdkBleBackend *backend;
/** Discovery */
@property (nonatomic, strong) ArsdkBleDiscovery *discovery;
@end

@implementation ArsdkBleBackendController

/**
 Constructor
 */
- (instancetype)initWithSupportedDeviceTypes:(NSSet<NSNumber*>*)deviceTypes
{
    self = [super init];
    if (self) {
        _deviceTypes = deviceTypes;
        _arsdkBle = [[ArsdkBle alloc] init];
        _arsdkBle.stateDelegate = self;
    }
    return self;
}

/**
 Destructor
 */
- (void)dealloc {
}

/**
 start controller (override)
 */
- (void)start:(ArsdkCore*)arsdkCore {
    [super start:arsdkCore];
}

/**
 stop controller (override)
 */
- (void)stop {
    [super stop];
}

/**
 Handle bluetooth on
 */
- (void)bluetoothAvailable {
    [ULog i:TAG msg:@"bluetooth on, creating BLE backend and discovery"];
    _backend = [[ArsdkBleBackend alloc]initWithArsdkCore:self.arsdkCore arsdkBle: _arsdkBle];
    _discovery = [[ArsdkBleDiscovery alloc]initWithArsdkCore:self.arsdkCore backend: _backend arsdkBle:_arsdkBle
                                                 deviceTypes: _deviceTypes];
    [_discovery start];
}

/**
 Handle bluetooth off
 */
- (void)bluetoothUnavailable {
    [ULog i:TAG msg:@"bluetooth off, deleting BLE backend and discovery"];
    [_discovery stop];
    _discovery = nil;
    _backend = nil;
}

#pragma mark ArsdkBleStateDelegate

-(void) arsdkBle:(nonnull ArsdkBle*)manager isPowered:(BOOL)powered {
    if (powered) {
        [self bluetoothAvailable];
    } else {
        [self bluetoothUnavailable];
    }
}


@end
