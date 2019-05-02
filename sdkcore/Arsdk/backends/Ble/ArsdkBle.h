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


#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@protocol ArsdkBleStateDelegate;
@protocol ArsdkBleScanDelegate;
@protocol ArsdkBleConnectDelegate;

/**
 Wrapper on CBCentralManager that dispatch delegates callbacks, shared between all class that needs to access it.
 */
@interface ArsdkBle : NSObject
// init

/** Delegate notified of state change */
@property (nonatomic, weak) id<ArsdkBleStateDelegate> _Nullable stateDelegate;
/** Constructor */
- (nullable instancetype)init;

// scan

/** Scan delegate notified of discovered devices */
@property (nonatomic, weak) id<ArsdkBleScanDelegate> _Nullable scanDelegate;
/** start scanning */
- (void)startScan;
/** stop scanning */
- (void)stopScan;

// connect

/** Delegate notified of device connect/disconnect */
@property (nonatomic, weak) id<ArsdkBleConnectDelegate> _Nullable connectDelegate;
/** Gets the device with the givent uuid. */
- (nullable CBPeripheral*)peripheralWithUid:(nonnull NSString *)uuid;
/** Connect a device */
- (void)connectPeripheral:(nonnull CBPeripheral *)peripheral;
/** Disconnect a device */
- (void)disconnectPeripheral:(nonnull CBPeripheral *)peripheral;

@end


/** Delegate notified of state change */
@protocol ArsdkBleStateDelegate
-(void) arsdkBle:(nonnull ArsdkBle*)manager isPowered:(BOOL)powered;
@end


/** Scan delegate notified of discovered devices */
@protocol ArsdkBleScanDelegate
- (void)arsdkBle:(nonnull ArsdkBle *)manager didDiscover:(nonnull NSString *)name
      deviceType:(NSInteger)deviceType uuid:(nullable NSString *)uuid rssi:(nonnull NSNumber *)rssi;
@end

/** Delegate notified of device connect/disconnect */
@protocol ArsdkBleConnectDelegate
- (void)arsdkBle:(nonnull ArsdkBle *)manager didConnectPeripheral:(nonnull CBPeripheral *)peripheral;
- (void)arsdkBle:(nonnull  ArsdkBle *)manager didFailToConnectPeripheral:(nonnull CBPeripheral *)peripheral
                   error:(nullable NSError *)error;
- (void)arsdkBle:(nonnull  ArsdkBle *)manager didDisconnectPeripheral:(nonnull CBPeripheral *)peripheral
                   error:(nullable NSError *)error;
@end
