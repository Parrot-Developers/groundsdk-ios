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


#import "ArsdkBleBackend.h"
#import "ArsdkBleDeviceConnection.h"
#import "ArsdkCore+Internal.h"
#import <arsdkctrl/arsdkctrl.h>
#import <arsdkctrl/internal/arsdkctrl_internal.h>
#import "Logger.h"

extern ULogTag* TAG;

@interface ArsdkBleBackend ()  <ArsdkBleConnectDelegate>
/** arsdk ble instance */
@property (nonatomic) ArsdkBle* arsdkBle;
/** arsdk ctrl instance, used to dispatch CBCentralManager and CBDevice callback in the pomp loop thread */
@property (nonatomic, weak) ArsdkCore* arsdkCore;
/** Connections, by device uuid */
@property (nonatomic) NSMutableDictionary<NSString *, ArsdkBleDeviceConnection *>* connections;

/** connect a device */
-(ArsdkBleDeviceConnection *)startConnectionForDeviceUid:(NSString *)uuid cfg:(const struct arsdk_device_conn_cfg *)cfg
                                                     cbs:(const struct arsdk_device_conn_internal_cbs*)cbs
                                                  device:(struct arsdk_device*)device loop:(struct pomp_loop*)loop;
/** disconnect a device */
-(void)stopConnection:(ArsdkBleDeviceConnection *)connection;
@end

# pragma mark arsdkctrl_backend callbacks

static int start_device_conn(struct arsdkctrl_backend *base,  struct arsdk_device *device, struct arsdk_device_info *info,
                             const struct arsdk_device_conn_cfg *cfg, const struct arsdk_device_conn_internal_cbs *cbs,
                             struct pomp_loop *loop, struct arsdk_device_conn **ret_conn) {
    ArsdkBleBackend* self = (__bridge ArsdkBleBackend*)arsdkctrl_backend_get_child(base);
    ArsdkBleDeviceConnection* connection = [self startConnectionForDeviceUid:[NSString stringWithUTF8String:info->addr]
                                                                         cfg:cfg cbs:cbs device:device loop:loop];
    *ret_conn = (__bridge struct arsdk_device_conn*)connection;
    return connection!=nil?0:-ENODEV;
}

static int stop_device_conn(struct arsdkctrl_backend *base, struct arsdk_device *device, struct arsdk_device_conn *conn) {
    ArsdkBleBackend* self = (__bridge ArsdkBleBackend *)arsdkctrl_backend_get_child(base);
    ArsdkBleDeviceConnection* connection =(__bridge ArsdkBleDeviceConnection *)conn;
    [self stopConnection:connection];
    return 0;
}

static const struct arsdkctrl_backend_ops sBackendOps = {
    .start_device_conn = &start_device_conn,
    .stop_device_conn = &stop_device_conn,
};


# pragma mark ArsdkBleBackend implementation

@implementation ArsdkBleBackend

/**
 Constructor
 */
-(instancetype)initWithArsdkCore:(ArsdkCore*)arsdkCore arsdkBle:(ArsdkBle*)arsdkBle {
    self = [super init];
    if (self) {
        _arsdkCore = arsdkCore;
        _arsdkBle = arsdkBle;
        _connections = [[NSMutableDictionary alloc]init];
        _arsdkBle.connectDelegate = self;
        int res;
        res = arsdkctrl_backend_new((__bridge void*)self, _arsdkCore.ctrl, "ble", ARSDK_BACKEND_TYPE_BLE,
                                    &sBackendOps, &_backend);
        if (res < 0) {
            [ULog w:TAG msg:@"ArsdkBleBackend: arsdkctrl_backend_new returned an error: %i", res];
            return nil;
        }
    }
    return self;
}

/**
 Destructor
 */
-(void)dealloc {
    int res = arsdkctrl_backend_destroy(_backend);
    if (res < 0) {
        [ULog w:TAG msg:@"ArsdkBleBackend: arsdkctrl_backend_destroy returned an error: %i", res];
    }
}

/**
 Start device connection
 */
-(ArsdkBleDeviceConnection *)startConnectionForDeviceUid:(NSString *)uuid cfg:(const struct arsdk_device_conn_cfg *)cfg
                                                     cbs:(const struct arsdk_device_conn_internal_cbs*)cbs
                                                  device:(struct arsdk_device*)device loop:(struct pomp_loop*)loop {
    CBPeripheral* peripheral = [_arsdkBle peripheralWithUid:uuid];
    if (peripheral) {
        ArsdkBleDeviceConnection* connection = [[ArsdkBleDeviceConnection alloc]
                                                initWithPeripheral:peripheral cfg:cfg cbs:cbs device:device loop:loop
                                                arsdkCore:_arsdkCore];
        [_connections setValue:connection forKey:uuid];
        [_arsdkBle connectPeripheral:peripheral];
        return connection;
    }
    return nil;
}

/**
 Stop device connection
 */
-(void)stopConnection:(ArsdkBleDeviceConnection *)connection {
    [_arsdkBle disconnectPeripheral:connection.peripheral];
    [connection stop];
    [_connections removeObjectForKey:connection.peripheral.identifier.UUIDString];
}

#pragma mark ArsdkBleConnectDelegate

- (void)arsdkBle:(nonnull ArsdkBle *)manager didConnectPeripheral:(nonnull CBPeripheral *)peripheral {
    [_arsdkCore dispatch:^{
        // forward notification to the connection
        [[self->_connections objectForKey:peripheral.identifier.UUIDString] didConnect];
    }];
}

- (void)arsdkBle:(nonnull  ArsdkBle *)manager didFailToConnectPeripheral:(nonnull CBPeripheral *)peripheral
           error:(nullable NSError *)error {
    [_arsdkCore dispatch:^{
        // forward notification to the connection
        [[self->_connections objectForKey:peripheral.identifier.UUIDString] didFailToConnect];
        // remove connection
        [self->_connections removeObjectForKey:peripheral.identifier.UUIDString];
    }];
}

- (void)arsdkBle:(nonnull  ArsdkBle *)manager didDisconnectPeripheral:(nonnull CBPeripheral *)peripheral
           error:(nullable NSError *)error {
    [_arsdkCore dispatch:^{
        // forward notification to the connection
        [[self->_connections objectForKey:peripheral.identifier.UUIDString] didDisconnect];
        // remove connection
        [self->_connections removeObjectForKey:peripheral.identifier.UUIDString];
    }];
}

@end


