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

#define ARBLESERVICE_BLE_MANUFACTURER_DATA_LENGTH   8
#define ARBLESERVICE_PARROT_BT_VENDOR_ID            0X0043  // Parrot Company ID registered by Bluetooth SIG
#define ARBLESERVICE_PARROT_USB_VENDOR_ID           0x19cf  // Official Parrot USB Vendor ID

#import "ArsdkBle.h"
#import "Logger.h"

extern ULogTag* TAG;

@interface ArsdkBle () <CBCentralManagerDelegate>
@property (nonatomic) CBCentralManager *cbCentralManager;
@end

@implementation ArsdkBle

/**
 Constructor
 */
- (nullable instancetype)init {
    self = [super init];
    if (self) {
        _cbCentralManager = [[CBCentralManager alloc]
                             initWithDelegate:self queue:nil options:@{CBCentralManagerOptionShowPowerAlertKey: @(NO)}];
    }
    return self;
}

/**
 Start scan
 */
- (void)startScan {
    [_cbCentralManager scanForPeripheralsWithServices:nil options:nil];
}

/**
 Stop scan
 */
- (void)stopScan {
    [_cbCentralManager stopScan];
}

/**
 Gets a CBPeripheral based on its uid. Return nil if not found
 */
- (nullable CBPeripheral*)peripheralWithUid:(nonnull NSString *)uuid {
    NSArray<CBPeripheral*>* devices = [_cbCentralManager
                                       retrievePeripheralsWithIdentifiers:@[[[NSUUID alloc]initWithUUIDString:uuid]]];
    if (devices.count == 1) {
        return devices[0];
    }
    if ([ULog d:TAG]) {
        [ULog d:TAG msg:@"ArsdkBle.peripheralWithUid %s not found", uuid.UTF8String];
    }
    return nil;
}

/**
 Connect a peripheral
 */
- (void)connectPeripheral:(nonnull CBPeripheral *)peripheral {
    if ([ULog d:TAG]) {
        [ULog d:TAG msg:@"connecting peripheral %s", peripheral.name.UTF8String];
    }
    [_cbCentralManager connectPeripheral:peripheral options:nil];
}

/**
 Disconnect a peripheral
 */
- (void)disconnectPeripheral:(nonnull CBPeripheral *)peripheral {
    if ([ULog d:TAG]) {
        [ULog d:TAG msg:@"disconnecting peripheral %s", peripheral.name.UTF8String];
    }
    [_cbCentralManager cancelPeripheralConnection:peripheral];
}

#pragma mark CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    switch (central.state) {
        case CBCentralManagerStateUnknown:
        case CBCentralManagerStateResetting:
        case CBCentralManagerStateUnsupported:
        case CBCentralManagerStateUnauthorized:
        case CBCentralManagerStatePoweredOff:
            [_stateDelegate arsdkBle:self isPowered:NO];
            break;
        case CBCentralManagerStatePoweredOn:
            [_stateDelegate arsdkBle:self isPowered:YES];
            break;
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI {
    NSData *manufacturerData = [advertisementData valueForKey:CBAdvertisementDataManufacturerDataKey];
    // check if it's a Parrot data
    if ((manufacturerData != nil) && (manufacturerData.length == ARBLESERVICE_BLE_MANUFACTURER_DATA_LENGTH)) {
        uint16_t *ids = (uint16_t*) manufacturerData.bytes;
        if ((ids[0] == ARBLESERVICE_PARROT_BT_VENDOR_ID) && (ids[1] == ARBLESERVICE_PARROT_USB_VENDOR_ID)) {
            uint16_t deviceType = ids[2];
            [_scanDelegate arsdkBle:self didDiscover:peripheral.name deviceType:deviceType
                               uuid:peripheral.identifier.UUIDString rssi:RSSI];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    if ([ULog d:TAG]) {
        [ULog d:TAG msg:@"centralManager didConnectPeripheral %d", peripheral.name.UTF8String];
    }
    [_connectDelegate arsdkBle:self didConnectPeripheral:peripheral];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral
                 error:(nullable NSError *)error {
    if ([ULog d:TAG]) {
        [ULog d:TAG msg:@"centralManager didFailToConnectPeripheral %s %s", peripheral.name.UTF8String,
         error.description.UTF8String];
    }
    [_connectDelegate arsdkBle:self didFailToConnectPeripheral:peripheral error:error];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral
                 error:(nullable NSError *)error {
    if ([ULog d:TAG]) {
        [ULog d:TAG msg:@"centralManager didDisconnectPeripheral %s %s", peripheral.name.UTF8String,
            error.description.UTF8String];
    }
    [_connectDelegate arsdkBle:self didDisconnectPeripheral:peripheral error:error];
}


@end
