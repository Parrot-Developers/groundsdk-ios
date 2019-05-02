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

#import "ArsdkFirmwareInfo.h"
#import "Logger.h"
#import <arsdkctrl/arsdkctrl.h>
#import <libpuf.h>

/** common loging tag */
ULogTag *FW_TAG;

@implementation ArsdkFirmwareVersion

+(void) initialize {
    FW_TAG = [[ULogTag alloc]initWithName:@"arsdk.ctrl.fw"];
}

- (instancetype _Nullable)initFromName:(NSString* _Nullable)name {
    return [self initFromCName:[name UTF8String]];
}

- (instancetype _Nullable)initWithMajor:(NSInteger)major minor:(NSInteger)minor patch:(NSInteger)patch
                                  build:(NSInteger)build type:(ArsdkFirmwareVersionType)type{
    self = [super init];
    if (self) {
        _major = major;
        _minor = minor;
        _patch = patch;
        _build = build;
        _type = type;
    }
    return self;
}

- (instancetype _Nullable)initFromCName:(const char* _Nullable)name {
    self = [super init];
    if (self) {
        struct puf_version fw_version;
        int res = puf_version_fromstring(name, &fw_version);
        if (res != 0) {
            [ULog e:FW_TAG msg:@"arsdk_updater_get_fw_version_from_name error: %s", strerror(-res)];
            return nil;
        }

        _major = fw_version.major;
        _minor = fw_version.minor;
        _patch = fw_version.patch;
        _build = fw_version.build;
        _type = (ArsdkFirmwareVersionType)fw_version.type;
    }
    return self;
}

- (NSComparisonResult)compare:(ArsdkFirmwareVersion* _Nonnull)otherVersion {
    // On app point of view, development version is greater than any version
    if (self.type == ArsdkFirmwareVersionDev && otherVersion.type != ArsdkFirmwareVersionDev) {
        return NSOrderedDescending;
    }
    if (self.type != ArsdkFirmwareVersionDev && otherVersion.type == ArsdkFirmwareVersionDev) {
        return NSOrderedAscending;
    }
    struct puf_version lhs = {
        .type = (enum puf_version_type) _type,
        .major = (uint32_t) _major,
        .minor = (uint32_t) _minor,
        .patch = (uint32_t) _patch,
        .build = (uint32_t) _build
    };

    struct puf_version rhs = {
        .type = (enum puf_version_type) otherVersion.type,
        .major = (uint32_t) otherVersion.major,
        .minor = (uint32_t) otherVersion.minor,
        .patch = (uint32_t) otherVersion.patch,
        .build = (uint32_t) otherVersion.build
    };

    return puf_compare_version(&lhs, &rhs);
}

@end

@implementation ArsdkFirmwareInfo

- (instancetype _Nullable)initFromFile:(NSString* _Nonnull)filepath {
    struct puf *puf = NULL;
    self = [super init];
    if (self) {
        _filepath = filepath;
        /* get version */
        struct puf_version puf_version;
        puf = puf_new([filepath UTF8String]);
        if (puf == NULL) {
            [ULog e:FW_TAG msg:@"puf_new failed"];
            return nil;
        }

        int res = puf_get_version(puf, &puf_version);
        if (res < 0) {
            [ULog e:FW_TAG msg:@"puf_get_version error: %s", strerror(-res)];
            goto error;
        }

        /* get version name */
        char name[50];
        res = puf_version_tostring(&puf_version, name, sizeof(name));
        if (res < 0) {
            [ULog e:FW_TAG msg:@"puf_version_tostring error: %s", strerror(-res)];
            goto error;
        }

        ArsdkFirmwareVersion *version = [[ArsdkFirmwareVersion alloc] initWithMajor:puf_version.major
                                                                    minor:puf_version.minor
                                                                    patch:puf_version.patch
                                                                    build:puf_version.build
                                                                    type:(ArsdkFirmwareVersionType)puf_version.type];
        if (!version) {
            goto error;
        }

        /* get device type */
        uint32_t app_id = 0;
        res = puf_get_app_id(puf, &app_id);
        if (res < 0) {
            [ULog e:FW_TAG msg:@"puf_get_app_id error: %s", strerror(-res)];
            goto error;
        }
        enum arsdk_device_type deviceType = arsdk_updater_appid_to_devtype(app_id);

        _version = version;
        _name = [NSString stringWithUTF8String:name];
        _device = deviceType;

        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath: _filepath error: NULL];
        if (!attrs) {
            goto error;
        }
        _size = (size_t)[attrs fileSize];
        puf_destroy(puf);
    }
    return self;

error:
    puf_destroy(puf);
    return nil;
}

@end
