#!/usr/bin/env python3

import sys, os
import arsdkparser

#===============================================================================
class Writer(object):
    def __init__(self, fileobj):
        self.fileobj = fileobj

    def write(self, fmt, *args):
        if args:
            self.fileobj.write(fmt % (args))
        else:
            self.fileobj.write(fmt % ())

def capitalize_first(arstr):
    nameParts = arstr.split('_')
    name = ''
    for part in nameParts:
        if len(part) > 1:
            name =  name + part[0].upper() + part[1:]
        elif len(part) == 1:
            name = name + part[0].upper()
    return name

def capitalize(arstr):
    return "".join(x.capitalize() for x in arstr.split('_'))

def format_cmd_name(msg):
    return capitalize_first(msg.name) if msg.cls is None else capitalize_first(msg.cls.name) + capitalize_first(msg.name)

def ftr_old_name(ftr):
    FROM_NEW_NAME = { 'common': '', 'ardrone3':'ARDrone3',
                        'common_dbg':'commonDebug', 'jpsumo':'JumpingSumo',
                        'minidrone':'MiniDrone', 'skyctrl':'SkyController'}
    if ftr.name in FROM_NEW_NAME:
        return FROM_NEW_NAME[ftr.name]
    else:
        return capitalize(ftr.name)
#===============================================================================

CONSTS_FILENAME = "DeviceCtrlCompatConsts"

GENERATED_HEADER = "/** Generated, do not edit ! */"

DICT_CHANGED_NOTIF = "DeviceControllerNotificationsDictionaryChanged"

DEVICE_CONTROLLER_CLASS_NAME = "DeviceController"

DEFAULT_PROJECT_NAME = "common"

#===============================================================================

def const_decl(const_name):
    return "extern NSString *const " + const_name + ";"

def const_impl(const_name):
    return "NSString *const " + const_name + " = @\"" + const_name + "\";"

def const_name(feature, evt, param = None):
    const_name = ""
    if ftr_old_name(feature) != DEFAULT_PROJECT_NAME:
        const_name += capitalize_first(ftr_old_name(feature))

    const_name += DEVICE_CONTROLLER_CLASS_NAME + capitalize_first(format_cmd_name(evt)) + "Notification"
    if param:
        const_name += capitalize_first(param.name) + "Key"
    return const_name
#===============================================================================
#===============================================================================

def gen_header_file(ctx, out):
    out.write("%s\n\n", GENERATED_HEADER)

    out.write("#import <Foundation/Foundation.h>\n\n")

    out.write("%s\n\n", const_decl(DICT_CHANGED_NOTIF))

    for featureId in sorted(ctx.featuresById.keys()):
        feature = ctx.featuresById[featureId]
        for evt in feature.evts:
            out.write("%s\n", const_decl(const_name(feature, evt)))

            for arg in evt.args:
                out.write("%s\n", const_decl(const_name(feature, evt, arg)))
            out.write("\n")
            

def gen_source_file(ctx, out):
    out.write("%s\n\n", GENERATED_HEADER)

    out.write("#import \"%s.h\"\n\n", CONSTS_FILENAME)

    out.write("%s\n\n", const_impl(DICT_CHANGED_NOTIF))

    for featureId in sorted(ctx.featuresById.keys()):
        feature = ctx.featuresById[featureId]
        for evt in feature.evts:
            out.write("%s\n", const_impl(const_name(feature, evt)))

            for arg in evt.args:
                out.write("%s\n", const_impl(const_name(feature, evt, arg)))
            out.write("\n")

#===============================================================================
#===============================================================================

def list_files(ctx, outdir, extra):
    print(os.path.join(outdir, CONSTS_FILENAME + ".h"))
    print(os.path.join(outdir, CONSTS_FILENAME + ".m"))

def generate_files(ctx, outdir, extra):
    if not os.path.exists (outdir):
        os.mkdirs (outdir)

    # generate the header file
    filepath = os.path.join(outdir, CONSTS_FILENAME + ".h")
    with open(filepath, "w") as fileobj:
        gen_header_file(ctx, Writer(fileobj))

    # generate the source file
    filepath = os.path.join(outdir, CONSTS_FILENAME + ".m")
    with open(filepath, "w") as fileobj:
        gen_source_file(ctx, Writer(fileobj))

    print("Done generating ff4 compat consts files")
