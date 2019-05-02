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

#import "ArsdkCore.h"
#import "ArsdkCore+Internal.h"
#import "ArsdkCore+Devices.h"
#import "ArsdkCore+Stream.h"
#import "Logger.h"
#import <arsdkctrl/arsdkctrl.h>
#import "NoAckCommandLoop.h"
#import "NoAckStorage.h"
#import <arsdkctrl/internal/arsdkctrl_internal.h>

/** common loging tag */
extern ULogTag *TAG;

short const ARSDK_INVALID_DEVICE_HANDLE = ARSDK_INVALID_HANDLE;

@interface ArsdkTcpProxy ()
/** The native tcp proxy */
@property (nonatomic, assign) struct arsdk_device_tcp_proxy * _Nonnull proxy;

@end

@implementation ArsdkTcpProxy

- (instancetype)initWithNativeProxy:(struct arsdk_device_tcp_proxy * _Nonnull) proxy {
    self = [super init];
    if (self) {
        _proxy = proxy;
    }
    return self;
}

- (void)dealloc {
    int res = arsdk_device_destroy_tcp_proxy(_proxy);
    if (res < 0) {
        [ULog w:TAG msg:@"Proxy could not be destroyed."];
    }
}

@end


/**
 * Listener object given to arsdk_ng.
 * It contains a reference to the ArsdkCoreDeviceListener, with the associated device handle.
 */
@interface ArsdkCoreDeviceListenerHandler: NSObject

@property (readonly, nonatomic, strong) id<ArsdkCoreDeviceListener> listener;
@property (readonly, nonatomic, weak) ArsdkCore *core;
@property (readonly, nonatomic) int16_t handle;

- (instancetype)initWithArsdkCore:(ArsdkCore * _Nonnull)core listener:(id<ArsdkCoreDeviceListener> _Nonnull)listener handle:(int16_t)handle;

@end

@implementation ArsdkCoreDeviceListenerHandler

- (instancetype)initWithArsdkCore:(ArsdkCore * _Nonnull)core listener:(id<ArsdkCoreDeviceListener> _Nonnull)listener handle:(int16_t)handle {
    self = [super init];
    if (self) {
        _core = core;
        _listener = listener;
        _handle = handle;
    }
    return self;
}

@end

@implementation ArsdkCore (Devices)

/**
 Connect to a device

 @param handle: the handle of the device
 @param deviceListener: listener notified when device connection changes and recevied commands.
 Retained until callback disconnected or canceled is called
 */
- (void)connectDevice:(int16_t)handle deviceListener:(id<ArsdkCoreDeviceListener>)deviceListener {
    [self assertCallerThread];
    if ([ULog d:TAG]) {
        [ULog d:TAG msg:@"connecting device handle %d", handle];
    }
    [self dispatch:^{
        ArsdkCoreDeviceListenerHandler *handler = [[ArsdkCoreDeviceListenerHandler alloc] initWithArsdkCore:self listener:deviceListener handle:handle];
        struct arsdk_device *nativeDevice = arsdk_ctrl_get_device(self.ctrl, handle);
        if (nativeDevice ==  NULL) {
            [ULog e:TAG msg:@"ArsdkCore.connectDevice arsdk_ctrl_get_device: nativeDevice not found"];
            goto error;
        }

        const struct arsdk_device_info *info;
        arsdk_device_get_info(nativeDevice, &info);

        struct arsdk_device_conn_cfg cfg;
        memset(&cfg, 0, sizeof(cfg));
        cfg.ctrl_name = [self.controllerVersion UTF8String];
        cfg.ctrl_type = [self.controllerDescriptor UTF8String];

        struct arsdk_device_conn_cbs device_conn_cbs;
        memset(&device_conn_cbs, 0, sizeof(device_conn_cbs));
        device_conn_cbs.userdata = (__bridge_retained void *)handler;
        device_conn_cbs.connecting = &connecting;
        device_conn_cbs.connected = &connected;
        device_conn_cbs.disconnected = &disconnected;
        device_conn_cbs.canceled = &canceled;
        device_conn_cbs.link_status = &link_status;

        int res = arsdk_device_connect(nativeDevice, &cfg, &device_conn_cbs, arsdk_ctrl_get_loop(self.ctrl));
        if (res < 0) {
            (void)(__bridge_transfer ArsdkCoreDeviceListenerHandler *)device_conn_cbs.userdata;
            [ULog w:TAG msg:@"ArsdkCore.connectDevice arsdk_device_connect %s", strerror(-res)];
            goto error;
        }
        return;

    error:
        // notify error by telling that the connection has been canceled
        dispatch_async(dispatch_get_main_queue(), ^{
            [deviceListener onConnectionCancel:ArsdkConnCancelReasonLocal removing:NO];
        });
    }];
}

/**
 Disconnect from a device

 The callback given in the connectDevice method will be called to notify about disconnection
 */
- (void)disconnectDevice:(int16_t)handle {
    [self assertCallerThread];

    // security, remove any NoAckCdeLoop
    // In normal operation, creation and destruction are done at the Device Controller level
    // (func protocolDidDisconnect() and func protocolDidConnect())
    [self deleteNoAckCmdLoop: handle];

    if ([ULog d:TAG]) {
        [ULog d:TAG msg:@"disconnecting device handle %d", handle];
    }
    [self dispatch:^{
        struct arsdk_device *nativeDevice = arsdk_ctrl_get_device(self.ctrl, handle);
        if (nativeDevice ==  NULL) {
            [ULog e:TAG msg:@"ArsdkCore.disconnectDevice arsdk_ctrl_get_device: device not found"];
            return;
        }

        int res = arsdk_device_disconnect(nativeDevice);
        if (res < 0) {
            [ULog w:TAG msg:@"ArsdkCore.disconnectDevice arsdk_device_disconnect %s", strerror(-res)];
        }
    }];
}

/**
 Send a command to a device

 Command must have been allocated on the heap. This method take ownership of the command.

 @param handle: device handle to which send the command
 @param encoder: command encoder of the command to send
 */
- (void)sendCommand:(int16_t)handle encoder:(int(^)(struct arsdk_cmd*)) __attribute__((noescape)) encoder {
    [self assertCallerThread];
    struct arsdk_cmd* command = calloc(1, sizeof(*command));
    int res = encoder(command);
    if (res == 0) {
        [self dispatch:^{
            send_command(self.ctrl, handle, command);
            // release the command and free it
            arsdk_cmd_clear(command);
            free(command);
        }];
    } else {
        // TODO: log error
        arsdk_cmd_clear(command);
        free(command);
    }
}

- (void)createNoAckCmdLoop:(int16_t)handle periodMs:(int)period {
    [self assertCallerThread];

    [self dispatch:^{

        NoAckCommandLoop* pcmdLoop = [[NoAckCommandLoop alloc] initWithArsdkctrl:self.ctrl
                                                                    deviceHandle:handle
                                                                        periodMs:(int)period];

        struct arsdk_device *nativeDevice = arsdk_ctrl_get_device(self.ctrl, handle);
        if (nativeDevice ==  NULL) {
            [ULog e:TAG msg:@"startNoAckCmdLoopp arsdk_ctrl_get_device: device not found"];
            return;
        }

        struct arsdk_cmd_itf *cmd_itf = arsdk_device_get_cmd_itf(nativeDevice);
        if (cmd_itf ==  NULL) {
            [ULog e:TAG msg:@"ArsdkCore.startNoAckCmdLoop arsdk_device_get_cmd_itf: device not found"];
            return;
        }

        if(arsdk_cmd_itf_get_osdata(cmd_itf) != NULL) {
            [ULog e:TAG msg:@"ArsdkCore.startNoAckCmdLoop previous loopCmd was not deleted"];
            NoAckCommandLoop* prevPcmdLoop = (__bridge_transfer NoAckCommandLoop*)arsdk_cmd_itf_get_osdata(cmd_itf);
            // be sure there is no more command list and force to stop the timer
            [prevPcmdLoop reset];
        }
        arsdk_cmd_itf_set_osdata(cmd_itf, (__bridge_retained  void*)pcmdLoop);
    }];
}

/**
 Delete NoAck command loop
 */
- (void)deleteNoAckCmdLoop:(short)handle {
    [self assertCallerThread];

    [self dispatch:^{
        struct arsdk_device *nativeDevice = arsdk_ctrl_get_device(self.ctrl, handle);
        if (nativeDevice ==  NULL) {
            [ULog e:TAG msg:@"ArsdkCore.stopNoAckCmdLoop arsdk_ctrl_get_device: device not found"];
            return;
        }

        struct arsdk_cmd_itf *cmd_itf = arsdk_device_get_cmd_itf(nativeDevice);
        if (cmd_itf ==  NULL) {
            [ULog e:TAG msg:@"ArsdkCore.stopNoAckCmdLoop arsdk_device_get_cmd_itf: device not found"];
            return;
        }

        NoAckCommandLoop* pcmdLoop = (__bridge_transfer NoAckCommandLoop*)arsdk_cmd_itf_get_osdata(cmd_itf);
        [pcmdLoop reset];
        pcmdLoop = NULL;
        arsdk_cmd_itf_set_osdata(cmd_itf, NULL);
    }];
}

/** set the list of ArsdkCommandEncoder used in the loop. This "new list" replace any previous list
 */
- (void)setNoAckCommands:(NSArray<NoAckStorage *> *_Nullable)encoders handle:(short)handle {

    [self assertCallerThread];
    [self dispatch:^{
        struct arsdk_device *nativeDevice = arsdk_ctrl_get_device(self.ctrl, handle);
        if (nativeDevice ==  NULL) {
            // device not found, ignore the set command list
            return;
        }

        struct arsdk_cmd_itf *cmd_itf = arsdk_device_get_cmd_itf(nativeDevice);
        if (cmd_itf ==  NULL) {
            // command interface not found, ignore the set command list
            return;
        }

        NoAckCommandLoop* pcmdLoop = (__bridge NoAckCommandLoop*)arsdk_cmd_itf_get_osdata(cmd_itf);
        // Note: if the pcmdLoop was deleted before, 'pcmdLoop' is NULL. There is no risk that a new list of commands
        // will restart the timer
        [pcmdLoop setEncoderList:encoders];
    }];
}

- (void)createTcpProxy:(int16_t)handle deviceType:(NSInteger)deviceType port:(uint16_t)port
            completion:(ArsdkTcpProxyCreationCompletion)completion {
    [self assertCallerThread];

    [self dispatch:^{

        struct arsdk_device_tcp_proxy *proxy = NULL;
        ArsdkTcpProxy *arsdkProxy = nil;
        NSString *proxyAddress = nil;
        int proxyPort = 0;

        struct arsdk_device *nativeDevice = arsdk_ctrl_get_device(self.ctrl, handle);
        if (nativeDevice ==  NULL) {
            [ULog e:TAG msg:@"ArsdkCore.createTcpProxy arsdk_ctrl_get_device: device not found"];
            goto completion;
        }

        int res = arsdk_device_create_tcp_proxy(nativeDevice, (enum arsdk_device_type)deviceType, port, &proxy);
        if (res < 0) {
            [ULog e:TAG msg:@"ArsdkCore.createTcpProxy creating tcp proxy failed"];
            goto completion;
        }

        const char *addressCStr = arsdk_device_tcp_proxy_get_addr(proxy);
        proxyPort = arsdk_device_tcp_proxy_get_port(proxy);
        if (addressCStr != NULL && proxyPort >= 0) {
            proxyAddress = [NSString stringWithUTF8String:addressCStr];
        }

        arsdkProxy = [[ArsdkTcpProxy alloc] initWithNativeProxy:proxy];

    completion:
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(arsdkProxy, proxyAddress, proxyPort);
        });
    }];
}

/**
 Send command to a device
 */
void send_command(struct arsdk_ctrl * _Nonnull mgnr, int16_t handle, struct arsdk_cmd * _Nonnull command) {
    struct arsdk_device *nativeDevice = arsdk_ctrl_get_device(mgnr, handle);
    if (nativeDevice ==  NULL) {
        [ULog e:TAG msg:@"ArsdkCore.send_command arsdk_ctrl_get_device: device not found"];
        return;
    }

    struct arsdk_cmd_itf *cmd_itf = arsdk_device_get_cmd_itf(nativeDevice);
    if (cmd_itf ==  NULL) {
        [ULog e:TAG msg:@"ArsdkCore.send_command arsdk_device_get_cmd_itf: device not found"];
        return;
    }

    int res = arsdk_cmd_itf_send(cmd_itf, command, NULL, NULL);
    if (res < 0) {
        [ULog w:TAG msg:@"ArsdkCore.send_command arsdk_cmd_itf_send %s", strerror(-res)];
    }
}

#pragma mark - device connection callbacks impl

#pragma mark - stream itf callback impl

static void connecting (struct arsdk_device *nativeDevice, const struct arsdk_device_info *info, void *userdata) {
    ArsdkCoreDeviceListenerHandler *handler = (__bridge ArsdkCoreDeviceListenerHandler *)(userdata);

    dispatch_async(dispatch_get_main_queue(), ^{
        [handler.listener onConnecting];
    });
}

static void connected (struct arsdk_device *nativeDevice, const struct arsdk_device_info *info, void *userdata) {
    ArsdkCoreDeviceListenerHandler *handler = (__bridge ArsdkCoreDeviceListenerHandler *)(userdata);

    int res = 0;

    /* create command interface */
    struct arsdk_cmd_itf *cmd_itf = NULL;

    struct arsdk_cmd_itf_cbs cbs;
    memset(&cbs, 0, sizeof(cbs));
    cbs.userdata = userdata;
    cbs.recv_cmd = &recv_cmd;
    cbs.send_status = &cmd_sent_status;
    cbs.cmd_log = &command_log;
    cbs.link_quality = &link_quality_log;

    res = arsdk_device_create_cmd_itf(nativeDevice, &cbs, &cmd_itf);
    if (res < 0) {
        [ULog e:TAG msg:@"arsdk_device_create_cmd_itf %s", strerror(-res)];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [handler.core deviceConnected:handler.handle];
        [handler.listener onConnected];
    });
}

static void disconnected (struct arsdk_device *nativeDevice, const struct arsdk_device_info *info, void *userdata) {
    // bridge transfer will release the retained bridge
    ArsdkCoreDeviceListenerHandler *handler = (__bridge_transfer ArsdkCoreDeviceListenerHandler *)(userdata);
    struct arsdk_cmd_itf *cmd_itf = arsdk_device_get_cmd_itf(nativeDevice);
    // stop pcmd loop if running
    if (cmd_itf) {
        NoAckCommandLoop* pcmdLoop = (__bridge_transfer NoAckCommandLoop*)arsdk_cmd_itf_get_osdata(cmd_itf);
        [pcmdLoop reset];
        pcmdLoop = NULL;
        arsdk_cmd_itf_set_osdata(cmd_itf, NULL);
    }

    BOOL removing = info->state == ARSDK_DEVICE_STATE_REMOVING;
    dispatch_async(dispatch_get_main_queue(), ^{
        [handler.core deviceDisconnected:handler.handle];
        [handler.listener onDisconnected:removing];
    });
}


static void canceled (struct arsdk_device *nativeDevice, const struct arsdk_device_info *info,
                      enum arsdk_conn_cancel_reason reason, void *userdata) {
    // bridge transfer will release the retained bridge
    ArsdkCoreDeviceListenerHandler *handler = (__bridge_transfer ArsdkCoreDeviceListenerHandler *)(userdata);

    BOOL removing = info->state == ARSDK_DEVICE_STATE_REMOVING;
    dispatch_async(dispatch_get_main_queue(), ^{
        [handler.listener onConnectionCancel:(ArsdkConnCancelReason)reason removing:removing];
    });
}

static void link_status (struct arsdk_device *nativeDevice, const struct arsdk_device_info *info,
                         enum arsdk_link_status status, void *userdata) {
    ArsdkCoreDeviceListenerHandler *handler = (__bridge ArsdkCoreDeviceListenerHandler *)(userdata);
    if (status == ARSDK_LINK_STATUS_KO) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [handler.listener onLinkDown];
        });
    }
}

#pragma mark - commands callback impl

static void recv_cmd(struct arsdk_cmd_itf *itf, const struct arsdk_cmd *cmd, void *userdata) {
    ArsdkCoreDeviceListenerHandler *handler = (__bridge ArsdkCoreDeviceListenerHandler *)(userdata);

    struct arsdk_cmd *cmdCpy = calloc(1, sizeof(*cmd));
    arsdk_cmd_copy(cmdCpy, cmd);
    dispatch_async(dispatch_get_main_queue(), ^{
        [handler.core passCommandToListeners:cmdCpy forDevice:handler.handle];
        [handler.listener onCommandReceived:cmdCpy];
        arsdk_cmd_clear(cmdCpy);
        free(cmdCpy);
    });
}

static void cmd_sent_status(struct arsdk_cmd_itf *itf, const struct arsdk_cmd *cmd,
                            enum arsdk_cmd_itf_send_status status, int done, void *userdata) {
    // TODO
}

static void command_log(struct arsdk_cmd_itf *itf, enum arsdk_cmd_dir dir, const struct arsdk_cmd *cmd,
                       void *userdata) {
    switch (arsdkCoreCmdLogLevel) {
        case ArsdkCmdLogNone:
            return;
        case ArsdkCmdLogAcknowledgedOnlyWithoutFrequent:
            switch (cmd->id) {
            case ARSDK_ID_ARDRONE3_GPSSTATE_NUMBEROFSATELLITECHANGED:
                return;
            }
            // fallthrough
        case ArsdkCmdLogAcknowledgedOnly:
            if (cmd->buffer_type == ARSDK_CMD_BUFFER_TYPE_NON_ACK)
                return;
            if (cmd->buffer_type == ARSDK_CMD_BUFFER_TYPE_INVALID) {
                const struct arsdk_cmd_desc* cmd_desc = arsdk_cmd_find_desc(cmd);
                if (cmd_desc && cmd_desc->buffer_type == ARSDK_CMD_BUFFER_TYPE_NON_ACK)
                    return;
            }
            // fallthrough
        case ArsdkCmdLogAll: {
            char cmdstr[512];
            int res = 0;

            // Command to string
            res = arsdk_cmd_fmt(cmd, cmdstr, sizeof(cmdstr));
            if (res < 0)
                return;

            [ULog d:TAG msg:@"%s %s", dir == ARSDK_CMD_DIR_TX ? ">>": "<<", cmdstr];
            break;
        }
    }
}

static void link_quality_log(struct arsdk_cmd_itf *itf, int32_t tx_quality,
                     int32_t rx_quality, int32_t rx_useful, void *userdata) {
    [ULog i:TAG msg:@"link quality tx_quality:%d rx_quality:%d rx_useful:%d",
            tx_quality, rx_quality, rx_useful];
}

@end
#
