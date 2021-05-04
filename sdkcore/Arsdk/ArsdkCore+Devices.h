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
#import "ArsdkCore.h"

struct arsdk_cmd;
@class ArsdkTcpProxy, NoAckStorage;

/**
 Defines a block that encode a command. This bloc takes the command to encode
 */
typedef int(^ArsdkCommandEncoder)(struct arsdk_cmd* _Nonnull);

/**
 Defines a block that will be called after a tcp proxy creation request

 @param proxy: the tcp proxy. nil in case of error
 @param addr: the address of the tcp proxy. nil in case of error
 @param port: the port if the tct proxy. If addr is nil, the port value should be ignored.
 */
typedef void(^ArsdkTcpProxyCreationCompletion)(ArsdkTcpProxy *_Nullable proxy, NSString *_Nullable addr,
                                               NSInteger port);

/** Reason of a connection cancel */
typedef NS_ENUM(NSInteger, ArsdkConnCancelReason) {
    // Numerical values must be kept in sync with C code

    /** Connection canceled on local request */
    ArsdkConnCancelReasonLocal =     0,
    /** Remote canceled the connection request */
    ArsdkConnCancelReasonRemote =    1,
    /** Remote rejected the connection request */
    ArsdkConnCancelReasonReject =    2,
};

/** A Tcp proxy */
@interface ArsdkTcpProxy : NSObject

@end

/**
 Device listener, notified of device event.
 */
@protocol ArsdkCoreDeviceListener <NSObject>

/**
 Called when the device is connecting (i.e sending connecting json)
 */
- (void)onConnecting;

/**
 Called when the device is connected (i.e device json has be received). At this time the command interface has
 been created and the device may start to send commands
 */
- (void)onConnectedWithApi:(ArsdkApiCapabilities)api
NS_SWIFT_NAME(onConnected(api:));

/**
 Called when device has been disconnected

 @param removing: true if the device has been disconnected because it's about to be removed
 */
- (void)onDisconnected:(BOOL)removing;

/**
 Called when connecting sequence has been canceled

 @param reason: cancel reason
 @param removing: true if the device has been disconnected because it's about to be removed
 */
- (void)onConnectionCancel:(ArsdkConnCancelReason)reason removing:(BOOL)removing;

/**
 Called when the link is down, command cannot be sent/received
 */
- (void)onLinkDown;

/**
 Called when a command has been received

 @param command: received command
 */
- (void)onCommandReceived:(const struct arsdk_cmd* _Nonnull)command;
@end


/** Value of a invalid device handle */
extern short const ARSDK_INVALID_DEVICE_HANDLE;

/**
 Arsdk Controller, Devices related functions
 */
@interface ArsdkCore (Devices)

/**
 Connect to a device

 @param handle: the handle of the device
 @param deviceListener: listener notified when device connection changes and recevied commands.
 Retained until callback disconnected or canceled is called
 */
- (void)connectDevice:(int16_t)handle deviceListener:(id<ArsdkCoreDeviceListener> _Nonnull)deviceListener;

/**
 Disconnect from a device

 The callback given in the connectDevice method will be called to notify about disconnection
 */
- (void)disconnectDevice:(int16_t)handle;

/**
 Send a command to a device

 Command must have been allocated on the heap. This method take ownership of the command.

 @param handle: device handle to which send the command
 @param encoder: command encoder of the command to send
 */
- (void)sendCommand:(int16_t)handle
            encoder:(__attribute__((noescape)) int(^ _Nonnull)(struct arsdk_cmd* _Nonnull))encoder;


/**
 Create the noAck command loop.

 Some commands, like piloting commands, are sent at regular period. This method create a loop object
 (see NoAckCommandLoop) in charge to initiate the loop.
 The loop timer is not activated in this method. The timer will be activated when commands will be added (see
 `setNoAckCommands` method)

 @param handle device handle to which send the command
 @param period piloting commead send period in ms
 */
- (void)createNoAckCmdLoop:(int16_t)handle periodMs:(int)period;

/**
 Delete the NoAck command loop
 */
- (void)deleteNoAckCmdLoop:(int16_t)handle;


/**
 Set a array of blocks to be executed continuously in the loop, each returning an ArsdkCommandEncoder.
 This "new array" replace any previous array.

  - warning closure is called in a separate thread. This closure must not block.

 @param encoders: The array of NoAck commands, each stored in a NoAckStorage Object
 @param handle: device handle to which send the command
 */
- (void)setNoAckCommands:(NSArray<NoAckStorage *> *_Nullable)encoders handle:(short)handle
NS_SWIFT_NAME(setNoAckCommands(encoders:handle:));


/**
 Creates a tcp proxy on a device.

 @param handle: the device handle
 @param deviceType: type of the device to access
 @param port: port to access
 @param completion: completion callback. This callback will be called on the caller thread. If an error occurred, it will
                    be called with nil as address parameter.
 */
- (void)createTcpProxy:(int16_t)handle deviceType:(NSInteger)deviceType port:(uint16_t)port
            completion:(ArsdkTcpProxyCreationCompletion _Nonnull)completion;

@end


/**
 helper to send command to a device
 */
void send_command(struct arsdk_ctrl * _Nonnull mgnr, int16_t handle, struct arsdk_cmd * _Nonnull command);
