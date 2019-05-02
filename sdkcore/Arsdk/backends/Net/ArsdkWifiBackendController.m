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

#import "ArsdkWifiBackendController.h"
#import "ArsdkNetBackend.h"
#import "ArsdkNetDiscoveryBonjour.h"

@interface ArsdkWifiBackendController ()

/** Device types */
@property (nonatomic, strong) NSSet<NSNumber *> *deviceTypes;

/** Net backend */
@property (nonatomic, strong) ArsdkNetBackend *backend;

/** Discovery */
@property (nonatomic, strong) ArsdkNetDiscovery *discovery;

@end

@implementation ArsdkWifiBackendController
- (instancetype)initWithSupportedDeviceTypes:(NSSet<NSNumber*>*)deviceTypes;
{
    self = [super init];
    if (self) {
        _deviceTypes = deviceTypes;
     }
    return self;
}

- (void)dealloc {
    [self stop];
}

/**
 Create the backend and start the discovery
 */
- (void)start:(ArsdkCore*)arsdkCore {
    [super start:arsdkCore];

    _backend = [[ArsdkNetBackend alloc] initWithArsdkCore:self.arsdkCore];
    _discovery = [[ArsdkNetDiscoveryBonjour alloc] initWithArsdkCore:self.arsdkCore
                                                             backend:_backend
                                                            andTypes:_deviceTypes];
    [_discovery start];

}

/**
 Stop the discovery and release discovery and backend
 */
- (void)stop {
    [_discovery stop];
    _discovery = nil;
    _backend = nil;

    [super stop];
}

@end
