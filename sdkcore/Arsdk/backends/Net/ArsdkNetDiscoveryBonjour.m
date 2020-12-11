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

#include <arpa/inet.h>
#import <UIKit/UIKit.h>

#import "ArsdkNetDiscoveryBonjour.h"
#import "ArsdkDiscovery+Protected.h"
#import "ArsdkCore.h"
#import "Logger.h"

static NSString *kServiceNetType =      @"_arsdk-%04x._udp.";
static NSString *kServiceNetDomain =    @"local";
static NSString *kDeviceId =            @"device_id";
extern ULogTag* TAG;

@interface ArsdkNetDiscoveryBonjour () <NSNetServiceBrowserDelegate, NSNetServiceDelegate>

/** Dictionary of NSNetServiceBrowser indexed by service type (NSString*) */
@property (nonatomic, strong) NSDictionary* browsers;

/** Dictionary of type (DeviceModel.internalId wrapped in NSNumber) indexed by service type (NSString*) */
@property (nonatomic, strong) NSDictionary* services;

/** Array of service found. Only here to have a retain on all services */
@property (nonatomic, strong) NSMutableArray* servicesFound;

/** Flag to indicate if servicesbrowser is started */
@property (nonatomic) BOOL serviceBrowsersStarted;

@end


@implementation ArsdkNetDiscoveryBonjour

-(instancetype)initWithArsdkCore:(ArsdkCore*)arsdk backend:(ArsdkNetBackend*)backend
                        andTypes:(NSSet<NSNumber*>*)types
{
    self = [super initWithArsdkCore:arsdk backend:backend andName:@"bonjour"];
    if (self) {
        self.serviceBrowsersStarted = FALSE;
        NSMutableDictionary *browsers = [NSMutableDictionary dictionaryWithCapacity:types.count];
        NSMutableDictionary *services = [NSMutableDictionary dictionaryWithCapacity:types.count];
        for (NSNumber *typeAsNumber in types) {
            NSString *serviceType = [NSString stringWithFormat:kServiceNetType, [typeAsNumber intValue]];
            // add the type in the dictionary matching the serviceType
            [services setObject:typeAsNumber forKey:serviceType];

            // add a net service browser matching the serviceType
            NSNetServiceBrowser *netServiceBrowser = [[NSNetServiceBrowser alloc] init];
            netServiceBrowser.delegate = self;
            [browsers setObject:netServiceBrowser forKey:serviceType];
        }
        _browsers = browsers;
        _services = services;
        _servicesFound = [NSMutableArray array];

        [self registerNotifications];

    }
    return self;
}

- (void)dealloc {
    [self unregisterNotifications];
}

- (void)doStart {
    [super doStart];
    [self startServiceBrowsers];
}

- (void)doStop {
    [self stopServiceBrowsers];
    [super doStop];
}

/**
 Start the discovery and the bonjour discovery for all service types
 */
- (void)startServiceBrowsers {
    // guard serviceBrowsersStarted is false
    // Prevents the servicesbrowser from being started twice in a row (for example in the case of foreground /
    // background notifications)
    if (self.serviceBrowsersStarted) {
        return;
    }
    for (NSString *serviceType in [_browsers allKeys]) {
        NSNetServiceBrowser *browser = [_browsers objectForKey:serviceType];
        [browser searchForServicesOfType:serviceType inDomain:kServiceNetDomain];
    }
    self.serviceBrowsersStarted = TRUE;
}

/**
 Stop the discovery and the bonjour discovery for all service types
 */
- (void)stopServiceBrowsers {
    // guard serviceBrowsersStarted is true
    if (!self.serviceBrowsersStarted) {
        return;
    }
    for (NSString *serviceType in [_browsers allKeys]) {
        NSNetServiceBrowser *browser = [_browsers objectForKey:serviceType];
        [browser stop];
    }

    // Remove all found services
    for (NSNetService* service in _servicesFound) {
        [self removeDeviceFromService:service];
    }
    [_servicesFound removeAllObjects];
    self.serviceBrowsersStarted = FALSE;
}

/**
 Add the service as a device into the backend
 */
- (void)addDeviceFromService:(NSNetService*)service {
    // ip, uid and type are required
    NSString *ipString = [ArsdkNetDiscoveryBonjour getIpV4FromService:service];
    NSString *uid = [ArsdkNetDiscoveryBonjour getUidFromService:service];
    NSNumber *typeAsNumber = [_services objectForKey:service.type];

    if (typeAsNumber && ipString && uid) {
        int type = [typeAsNumber intValue];
        [self addDevice:service.name type:type addr:ipString port:service.port uid:uid];

        // remove the delegate because we don't need it anymore
        service.delegate = nil;
    }
}

/**
 Remove the service as a device from the backend
 */
- (void)removeDeviceFromService:(NSNetService*)service {
    NSNumber *typeAsNumber = [_services objectForKey:service.type];
    int type = [typeAsNumber intValue];
    [self removeDevice:service.name type:type];
}

#pragma mark notification registration
- (void)registerNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enteredBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification object: nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification object: nil];
}

- (void)unregisterNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object: nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object: nil];
}

#pragma mark - application notifications
- (void)enterForeground:(NSNotification*)notification {
    // when app goes into foreground, restart bonjour discovery if start was asked
    if (self.started) {
        [self startServiceBrowsers];
    }
}

- (void)enteredBackground:(NSNotification*)notification {
    // when app goes into background, stop bonjour discovery if start has been asked on the ArsdkNetDiscoverBonjour obj
    if (self.started) {
        [self stopServiceBrowsers];
    }
}

#pragma mark NSNetServiceBrowserDelegate

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)service
               moreComing:(BOOL)moreComing {
    NSNumber *typeAsNumber = [_services objectForKey:service.type];
    if (typeAsNumber) {
        [_servicesFound addObject:service];
        service.delegate = self;
        // TODO: see if we need to do the startMonitoring. By experience, TXTRecordData is already written in the netServiceDidResolveAddress.
        //[service startMonitoring];
        [service resolveWithTimeout:5.0];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)service
               moreComing:(BOOL)moreComing {
    NSNumber *typeAsNumber = [_services objectForKey:service.type];
    if (typeAsNumber) {
        [_servicesFound removeObject:service];
        // remove the device from the backend
        [self removeDeviceFromService:service];
    }
}

#pragma mark NSNetServiceDelegate
// TODO: this function won't be called because we have not called startMonitoring
// (linked to the TODO in netServiceBrowser:didFindService:)
- (void)netService:(NSNetService *)service didUpdateTXTRecordData:(NSData *)data {
    /*NSData *txtRecordData = data;
     NSString *myString = [[NSString alloc] initWithData:txtRecordData encoding:NSUTF8StringEncoding];

     [service stopMonitoring];
     [service resolveWithTimeout:5.0];*/
}

- (void)netServiceDidResolveAddress:(NSNetService *)service {
    if (service.TXTRecordData && service.addresses) {
        [self addDeviceFromService:service];
    }
}

// TODO: what to do?
- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary<NSString *, NSNumber *> *)errorDict {
    [ULog e:TAG msg:@"bonjour didNotResolve %@", errorDict];
}

#pragma mark static methods
/**
 Get ip v4 string of a given service

 @param service: the service
 @return the ip v4 as NSString if possible, nil otherwise
 */
+ (NSString*)getIpV4FromService:(NSNetService*)service {
    struct sockaddr_in *socketAddress = NULL;

    for (NSData *address in service.addresses) {
        socketAddress = (struct sockaddr_in *) [address bytes];
        if (socketAddress->sin_family == AF_INET)//AF_INET -> IPv4, AF_INET6 -> IPv6
        {
            char ip[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &socketAddress->sin_addr, ip, INET_ADDRSTRLEN);
            return [NSString stringWithFormat: @"%s", ip];
        }
    }
    return nil;
}

/**
 Split the whole txt record data from the given service into an array of strings
 Each record data is a string in the returned array

 @param service: the service
 @return an array containing a string for each record data
 */
+ (NSArray*)getRecordDataAsStrArray:(NSNetService*)service {
    NSUInteger dataLen = 0;
    NSUInteger currentPos = 0;
    NSMutableArray *strArr = [NSMutableArray array];
    // for each record data
    while (currentPos + 1 < service.TXTRecordData.length) {
        // read the two bytes describing the length of the record data
        [service.TXTRecordData getBytes:&dataLen range:NSMakeRange(currentPos, 1)];

        // get the sub data
        // from the current pos + 1 to omit the data size
        // to dataLen
        NSData *recordData = [service.TXTRecordData subdataWithRange:NSMakeRange(currentPos + 1, dataLen)];
        NSString *recordDataStr = [[NSString alloc] initWithData:recordData encoding:NSUTF8StringEncoding];
        [strArr addObject:recordDataStr];
        currentPos += dataLen;
    }
    return strArr;
}

/**
 Get unique identifier of a given service
 The uid is the value corresponding to the key device_id in the txt record data

 @param service: the service
 @return the uid as NSString if possible, nil otherwise
 */
+ (NSString*)getUidFromService:(NSNetService*)service {
    NSArray *recordDataArr = [ArsdkNetDiscoveryBonjour getRecordDataAsStrArray:service];
    if (recordDataArr && recordDataArr.count > 0) {
        NSError *error = nil;
        // for the moment, get the object at index 0 because there is only one.
        NSString *recordDataJsonStr = [recordDataArr objectAtIndex:0];
        NSData *recordDataJsonData = [recordDataJsonStr dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *recordDict = [NSJSONSerialization JSONObjectWithData:recordDataJsonData options:0 error:&error];
        if (!error && recordDict) {
            return [recordDict objectForKey:kDeviceId];
        }
    }
    return nil;
}
@end
