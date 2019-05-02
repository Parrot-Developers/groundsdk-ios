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

#import <arpa/inet.h>
#include <netinet/tcp.h>    // for TCP_NODELAY
#import <arsdkctrl/arsdkctrl.h>
#import "ArsdkMuxIpBackendController.h"
#import "ArsdkMux.h"
#import "ArsdkMuxBackend.h"
#import "ArsdkMuxDiscovery.h"
#import "Logger.h"

extern ULogTag* TAG;

@interface ArsdkMuxIpBackendController() <ArsdkMuxDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate>
/** Device types */
@property (nonatomic, strong) NSSet<NSNumber *> *deviceTypes;
/** Mux ip backend */
@property (nonatomic, strong) ArsdkMux *mux;
@property (nonatomic, strong) ArsdkMuxBackend *backend;
// static ip address
@property (nonatomic, strong) NSString *ipAddr;
@property (nonatomic, strong) NSString *hostName;
@property (nonatomic) NSInteger port;
/** Discovery */
@property (nonatomic, strong) ArsdkMuxDiscovery *discovery;
/** Bonjour */
@property (nonatomic, strong) NSNetServiceBrowser *netServiceBrowser;
@property (nonatomic, strong) NSNetService *currentService;

@end


#define RECONNECT_TIMEOUT (10 * NSEC_PER_SEC)
static NSString *kServiceType =  @"_arsdk-mux._tcp.";

@implementation ArsdkMuxIpBackendController

- (instancetype)initWithSupportedDeviceTypes:(NSSet<NSNumber*>*)deviceTypes {
    self = [super init];
    if (self) {
        _deviceTypes = deviceTypes;
    }
    return self;
}


- (instancetype)initWithSupportedDeviceTypes:(NSSet<NSNumber*>*)deviceTypes addr:(NSString*)addr
                                        port:(NSInteger)port {
    self = [super init];
    if (self) {
        _deviceTypes = deviceTypes;
        _ipAddr = addr;
        _port = port;
    }
    return self;
}

- (void)dealloc {
}

- (void)start:(ArsdkCore*)arsdkCore {
    if (_ipAddr) {
        [ULog i:TAG msg:@"ArsdkMuxIpBackendController starting on %s", _ipAddr.UTF8String];
    } else {
        [ULog i:TAG msg:@"ArsdkMuxIpBackendController starting"];
    }
    [super start:arsdkCore];
    // static ip address
    if (_ipAddr) {
        _hostName = _ipAddr;
        [self connect];
    } else {
        [self startServiceBrowser];
    }
}

- (void)stop {
    [super stop];
    [self stopServiceBrowser];
    _hostName = nil;
    [_discovery stop];
    _discovery = nil;
    _backend = nil;
    _mux = nil;
}

- (void)connect {
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef) _hostName, (uint32_t)_port,
                                       &readStream, &writeStream);

    _mux = [[ArsdkMux alloc] initWithDelegate:self
                                    arsdkCore:self.arsdkCore
                                 inputStream:(__bridge_transfer NSInputStream *)readStream
                                 outputStream:(__bridge_transfer NSOutputStream *)writeStream
                                    pomp_loop:arsdk_ctrl_get_loop(self.arsdkCore.ctrl)];
}

#pragma mark - ArsdkMuxDelegate
- (void)muxDidStart {
    [ULog i:TAG msg:@"ArsdkMuxIpBackendController, mux connected"];
    // set tcp_nodelay on output stream
    // Get socket data
    CFDataRef socketData = CFWriteStreamCopyProperty((__bridge CFWriteStreamRef)((NSOutputStream *)_mux.outputStream),
                                                     kCFStreamPropertySocketNativeHandle);
    // get a handle to the native socket
    CFSocketNativeHandle rawsock;
    CFDataGetBytes(socketData, CFRangeMake(0, sizeof(CFSocketNativeHandle)), (UInt8 *)&rawsock);
    CFRelease(socketData);
    static const int kOne = 1;
    setsockopt(rawsock, IPPROTO_TCP, TCP_NODELAY, &kOne, sizeof(kOne));

    // create backend and discovery
    _backend = [[ArsdkMuxBackend alloc] initWithArsdkCore:self.arsdkCore mux:_mux];
    _discovery = [[ArsdkMuxDiscovery alloc] initWithArsdkCore:self.arsdkCore mux:_mux backend:_backend
                                                  deviceTypes: _deviceTypes];
    [_discovery start];
}

- (void)muxDidFail {
    // retry if not stopped
    _discovery = nil;
    _backend = nil;
    _mux = nil;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)RECONNECT_TIMEOUT), dispatch_get_main_queue(), ^{
        if (self.arsdkCore && self.hostName) {
            [self connect];
        }
    });
}

#pragma mark - Bonjour

- (void)startServiceBrowser {
    _netServiceBrowser = [[NSNetServiceBrowser alloc] init];
    _netServiceBrowser.delegate = self;
    [_netServiceBrowser searchForServicesOfType:kServiceType inDomain:@""];
}

- (void)stopServiceBrowser {
    [_netServiceBrowser stop];
    _netServiceBrowser = nil;
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)service
               moreComing:(BOOL)moreComing {
    if (!_currentService) {
        _currentService = service;
        _currentService.delegate = self;
        [_currentService resolveWithTimeout:5.0];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)service
               moreComing:(BOOL)moreComing {

    if (service == _currentService) {
        _currentService = nil;
        _hostName = nil;
        // mux ping failure will cleanup the mux
    }
}

- (void)netServiceDidResolveAddress:(NSNetService *)service {
    _hostName = service.hostName;
    _port = service.port;
    if (_hostName) {
        [self connect];
    }
}

@end
