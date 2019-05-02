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


#import <CoreBluetooth/CoreBluetooth.h>
#import "ArsdkBleDeviceConnection.h"
#import "ArsdkCore+Internal.h"
#include <arsdkctrl/arsdkctrl.h>
#include <arsdkctrl/internal/arsdkctrl_internal.h>
#import "Logger.h"

extern ULogTag* TAG;

/** arsdk-ng connection and transport ble implementation */
@interface ArsdkBleDeviceConnection () <CBPeripheralDelegate>
@property (nonatomic, readonly, weak) ArsdkCore* arsdkCore;
/** arsdk-ng transport */
@property (nonatomic, assign) struct arsdk_transport* transport;
/** arsdk-ng connection callbacks */
@property (nonatomic, assign) struct arsdk_device_conn_internal_cbs cbs;

-(int)sendDataWithHeader:(const struct arsdk_transport_header *)header
                 payload:(const struct arsdk_transport_payload *)payload
             extraHeader:(const void *)extraHeader
          extraHeaderLen:(size_t)extraHeaderLen;

-(void)receiveData:(NSData*)data forId:(uint8_t)id;
@end

// as defined in Delos_BLE_config.h, send/receivce inverted

#define ARCOMMAND_SENDING_SERVICE		  "FA00"
#define ARCOMMAND_RECEIVING_SERVICE       "FB00"
#define PERFORMANCE_COUNTER_SERVICE       "FC00"
#define NORMAL_BLE_FTP_SERVICE            "FD21"
#define UPDATE_BLE_FTP_SERVICE            "FD51"
#define UPDATE_RFCOMM_SERVICE             "FE00"

// header [type/seq (8bits)] + 1 byte payload
#define BLE_MIN_DATA_LEN                         3

/** arsk-ng transport callback */
int transport_dispose(struct arsdk_transport *base) {
    // nothing to do to dispose transport
    return 0;
}

/** arsk-ng transport callback */
int transport_start(struct arsdk_transport *base) {
    // nothing to do to start transport
    return 0;
}


/** arsk-ng transport callback */
int transport_stop(struct arsdk_transport *base) {
    // nothing to do to stop transport
    return 0;
}


/** arsk-ng transport callback */
int transport_send_data(struct arsdk_transport *base, const struct arsdk_transport_header *header,
                        const struct arsdk_transport_payload *payload, const void *extra_hdr, size_t extra_hdrlen) {
    ArsdkBleDeviceConnection* self = (__bridge ArsdkBleDeviceConnection*)arsdk_transport_get_child(base);
    return [self sendDataWithHeader:header payload:payload extraHeader:extra_hdr extraHeaderLen:extra_hdrlen];
}

/** transport operations */
static const struct arsdk_transport_ops sTransportOps = {
    .dispose = &transport_dispose,
    .start = &transport_start,
    .stop = &transport_stop,
    .send_data = &transport_send_data
};


@implementation ArsdkBleDeviceConnection

/**
 Constructor
 */
-(instancetype)initWithPeripheral:(CBPeripheral*)peripheral cfg:(const struct arsdk_device_conn_cfg *)cfg
                              cbs:(const struct arsdk_device_conn_internal_cbs*)cbs device:(struct arsdk_device*)device
                             loop:(struct pomp_loop*)loop arsdkCore:(ArsdkCore*)arsdkCore {
    self = [super init];
    if (self) {
        _peripheral = peripheral;
        _peripheral.delegate = self;
        _cbs = *cbs;
        _device = device;
        _loop = loop;
        _arsdkCore = arsdkCore;
        _cbs.connecting(device, (__bridge struct arsdk_device_conn*)self, _cbs.userdata);
    }
    return self;
}

/**
 Stop connection
 */
-(void)stop {
    _cbs.disconnected(_device, (__bridge struct arsdk_device_conn*)self, _cbs.userdata);
    if (_transport) {
        int res = arsdk_transport_stop(_transport);
        if (res < 0) {
            [ULog e:TAG msg:@"stop: error in arsdk_transport_stop %s", strerror(res)];
        }
        res = arsdk_transport_destroy(_transport);
        if (res < 0) {
            [ULog e:TAG msg:@"stop: error in arsdk_transport_destroy %s", strerror(res)];
        }
        _transport = NULL;
    }
}

/**
 Called by the backend when the device is connected 
 */
-(void)didConnect {
    // ask to discover all device services
    [_peripheral discoverServices:nil];
}

/**
 Called by the backend when the device is diconnected
 */
-(void)didDisconnect {
    _cbs.disconnected(_device, (__bridge struct arsdk_device_conn*)self, _cbs.userdata);
    if (_transport) {
        int res = arsdk_transport_stop(_transport);
        if (res < 0) {
            [ULog e:TAG msg:@"didDisconnect: error in arsdk_transport_stop %s", strerror(res)];
        }
        res = arsdk_transport_destroy(_transport);
        if (res < 0) {
            [ULog e:TAG msg:@"didDisconnect: error in arsdk_transport_destroy %s", strerror(res)];
        }
        _transport = NULL;
    }
}

/**
 Called by the backend when the device fail to connect
 */
-(void)didFailToConnect {
    _cbs.canceled(_device, (__bridge struct arsdk_device_conn*)self, ARSDK_CONN_CANCEL_REASON_LOCAL, _cbs.userdata);
}


/**
 Send ble frame
 */
-(int)sendDataWithHeader:(const struct arsdk_transport_header *)header
                 payload:(const struct arsdk_transport_payload *)payload
             extraHeader:(const void *)extraHeader
          extraHeaderLen:(size_t)extraHeaderLen {
    // create data to send
    NSMutableData *data = [NSMutableData dataWithCapacity:2 + extraHeaderLen + payload->len];
    // add type and seq nr from the header (id is not set as it defined by the property used to send the frame)
    [data appendBytes:&(header->type) length:sizeof(uint8_t)];
    [data appendBytes:&(header->seq) length:sizeof(uint8_t)];
    // append extra header
    [data appendBytes:extraHeader length:extraHeaderLen];
    // append payload
    [data appendBytes:payload->cdata length:payload->len];
    // gets the characteristic for the requested channel id
    CBCharacteristic* characteristic = _senderService.characteristics[header->id];
    // characteristic may be null if the device just drop the connection
    if (characteristic) {
        [_peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
    }
    return 0;
}

/**
 Process received data
 */
-(void)receiveData:(NSData*)data forId:(uint8_t)id {
    struct arsdk_transport_header header;
    struct arsdk_transport_payload payload;
    // setup arsdk-ng header
    memset(&header, 0, sizeof(header));
    arsdk_transport_payload_init(&payload);
    // read type
    [data getBytes:&header.type range:NSMakeRange(0, 1)];
    header.id = id;
    // read seq number
    [data getBytes:&header.seq range:NSMakeRange(1, 1)];

    // setup arsdk-ng payload
    void *bufdata = NULL;
    size_t payloadLen = data.length-2;
    struct pomp_buffer *buf = pomp_buffer_new_get_data(payloadLen, &bufdata);
    if (buf) {
        [data getBytes:bufdata range:NSMakeRange(2, payloadLen)];
        pomp_buffer_set_len(buf, payloadLen);
        arsdk_transport_payload_init_with_buf(&payload, buf);
        int res = arsdk_transport_recv_data(_transport, &header, &payload);
        if (res < 0) {
            [ULog e:TAG msg:@"receiveData: error in arsdk_transport_recv_data %s", strerror(res)];
        }
        pomp_buffer_unref(buf);
    } else {
        [ULog e:TAG msg:@"receiveData: error in pomp_buffer_new_get_data"];
    }
 }


#pragma mark CBPeripheralDelegate

/**
 Device services discovered
 */
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error {
    // search sending/receiving services
    for (CBService* service in _peripheral.services) {
        NSString* servicePostfix = [service.UUID.UUIDString substringFromIndex:4];
        if ([servicePostfix hasPrefix:@ARCOMMAND_SENDING_SERVICE] ||
            [servicePostfix hasPrefix:@ARCOMMAND_RECEIVING_SERVICE]) {
            [_peripheral discoverCharacteristics:nil forService:service];
        }
    }
}

/**
 Service Characteristics discovered
 */
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    NSString* servicePostfix = [service.UUID.UUIDString substringFromIndex:4];
    if (_senderService == nil && [servicePostfix hasPrefix:@ARCOMMAND_SENDING_SERVICE]) {
        // _senderService: store sender service
        _senderService = service;
    } else if (_receiverService == nil && [servicePostfix hasPrefix:@ARCOMMAND_RECEIVING_SERVICE]) {
        // _receiverService store it and register notification on all receiver characteristiques
        _receiverService = service;
        for (CBCharacteristic* characteristic in _receiverService.characteristics) {
            [_peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
    if (_senderService && _receiverService) {
        [_arsdkCore dispatch:^{
            // got requested services, create transport for device
            int res = arsdk_transport_new((__bridge void*)self, &sTransportOps,
                                          self->_loop, 0, "ble", &self->_transport);
            if (res == 0) {
                self->_cbs.connected(self->_device, NULL, (__bridge struct arsdk_device_conn*)self,
                                     self->_transport, self->_cbs.userdata);
            }
        }];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(nullable NSError *)error {
    NSData* data = [NSData dataWithData:characteristic.value];
    // gets the id from characteristique
    NSScanner* scanner = [NSScanner scannerWithString:[characteristic.UUID.UUIDString
                                                       substringWithRange:NSMakeRange(6, 2)]];
    if (data.length >= BLE_MIN_DATA_LEN) {
        unsigned int id =-1;
        [scanner scanHexInt:&id];
        if (id != -1) {
            [_arsdkCore dispatch:^{
                [self receiveData:data forId:id];
            }];
        } else {
            [ULog w:TAG msg:@"ignoring characteristic update %s", characteristic.description.UTF8String];
        }
    }
}

@end
