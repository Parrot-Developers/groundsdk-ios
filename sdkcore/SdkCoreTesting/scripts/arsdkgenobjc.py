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

#===============================================================================

def class_name(name):
    splitted_name = name.split('_')
    return "ArsdkFeature" + "".join(x.capitalize() for x in splitted_name)

def enum_class_name(feature_strict_name, enum_name):
    splitted_name = enum_name.split('_')
    return class_name(feature_strict_name) + "".join(x.capitalize() for x in splitted_name)

def multiset_class_name(feature_strict_name, multiset_name):
    splitted_name = multiset_name.split('_')
    return class_name(feature_strict_name) + "".join(x.capitalize() for x in splitted_name)

def param_name(name):
    components = name.split('_')
    return components[0].lower() + "".join(x[0].upper() + x[1:] for x in components[1:])

def arg_type(feature_strict_name, arg, is_fun_arg=False):
    args = {
        arsdkparser.ArArgType.I8: "NSInteger",
        arsdkparser.ArArgType.U8: "NSUInteger",
        arsdkparser.ArArgType.I16: "NSInteger",
        arsdkparser.ArArgType.U16: "NSUInteger",
        arsdkparser.ArArgType.I32: "NSInteger",
        arsdkparser.ArArgType.U32: "NSUInteger",
        arsdkparser.ArArgType.I64: "int64_t",
        arsdkparser.ArArgType.U64: "uint64_t",
        arsdkparser.ArArgType.FLOAT: "float",
        arsdkparser.ArArgType.DOUBLE: "double",
        arsdkparser.ArArgType.STRING: "NSString*"
    }

    if isinstance(arg.argType, arsdkparser.ArEnum):
        argType = enum_class_name(feature_strict_name, arg.argType.name)
    elif isinstance(arg.argType, arsdkparser.ArBitfield):
        if arg.argType.btfType == arsdkparser.ArArgType.I64 or \
            arg.argType.btfType == arsdkparser.ArArgType.U64:
            argType = args[arsdkparser.ArArgType.U64]
        else:
            argType = args[arsdkparser.ArArgType.U32]
    elif isinstance(arg.argType, arsdkparser.ArMultiSetting):
        if is_fun_arg:
            argType = multiset_class_name(feature_strict_name, arg.argType.name) + ' *'
        else:
            argType = multiset_class_name(feature_strict_name, arg.argType.name)
    else:
        argType = args[arg.argType]
    return argType

def multiset_c_name(ftr, multiset):
    return "struct arsdk_%s_%s" % (ftr, multiset)

def arg_c_type(arg, is_fun_arg=False):
    args = {
        arsdkparser.ArArgType.I8: "int8_t",
        arsdkparser.ArArgType.U8: "uint8_t",
        arsdkparser.ArArgType.I16: "int16_t",
        arsdkparser.ArArgType.U16: "uint16_t",
        arsdkparser.ArArgType.I32: "int32_t",
        arsdkparser.ArArgType.U32: "uint32_t",
        arsdkparser.ArArgType.I64: "int64_t",
        arsdkparser.ArArgType.U64: "uint64_t",
        arsdkparser.ArArgType.FLOAT: "float",
        arsdkparser.ArArgType.DOUBLE: "double",
        arsdkparser.ArArgType.STRING: "const char*"
    }
    if isinstance(arg.argType, arsdkparser.ArEnum):
        argType = args[arsdkparser.ArArgType.I32]
    elif isinstance(arg.argType, arsdkparser.ArBitfield):
        argType = args[arg.argType.btfType]
    elif isinstance(arg.argType, arsdkparser.ArMultiSetting):
        if is_fun_arg:
            argType = multiset_c_name("generic", arg.argType.name.lower()) + ' *'
        else:
            argType = multiset_c_name("generic", arg.argType.name.lower())
    else:
        argType = args[arg.argType]
    return argType

def arg_name(arg):
    if isinstance(arg.argType, arsdkparser.ArEnum):
        argName = param_name(arg.name)
    elif isinstance(arg.argType, arsdkparser.ArBitfield):
        argName = param_name(arg.name) + "BitField"
    elif isinstance(arg.argType, arsdkparser.ArMultiSetting):
        argName = param_name(arg.name)
    else:
        argName = param_name(arg.name)
    return argName


def arg_value_from_obj_c_to_c(feature_strict_name, arg):
    if arg.argType == arsdkparser.ArArgType.STRING:
        return "[" + arg_name(arg) + " UTF8String]"
    elif isinstance(arg.argType, arsdkparser.ArMultiSetting):
        return "[%s getNativeSettings]" % arg_name(arg)
    elif arg_c_type(arg) != arg_type(feature_strict_name, arg):
        return "(" + arg_c_type(arg) + ")" + arg_name(arg)
    else:
        return arg_name(arg)

def c_name(val):
    return val[0].upper() + val[1:]

#===============================================================================

def expected_cmd_class():
    return "ExpectedCmd"

def command_name(feature_name, cmd):
    command_name_str = feature_name + "_" + cmd.name
    splitted_name = command_name_str.split('_')
    command_name_str = "".join(x.capitalize() for x in splitted_name)
    # lower first letter
    return command_name_str[0].lower() + command_name_str[1:]

def static_initializer_method_name(feature_obj, feature_name, cmd, with_swift_name=False):
    return_part = "+ (" + expected_cmd_class() + "*)"
    method_root_name = command_name(feature_name, cmd)

    method_name = return_part + method_root_name
    if cmd.args:
        # the first arg is special as the arg name is not part of the method name
        arg = cmd.args[0]
        method_name += ":(" + arg_type(feature_obj.name, arg, True) + ")" + arg_name(arg)
        for arg in cmd.args[1:]:
            method_name += " " + arg_name(arg) + ":(" + arg_type(feature_obj.name, arg, True) + ")" + arg_name(arg)
    if with_swift_name:
        method_name += "\nNS_SWIFT_NAME(" + method_root_name + "("
        for arg in cmd.args:
            method_name += arg_name(arg) + ":"
        method_name += "))"

    return method_name

def command_class_name(feature_name, cmd):
    command_name_str = command_name(feature_name, cmd)
    return expected_cmd_class() + command_name_str[0].upper() + command_name_str[1:]


def match_command_name():
    return "- (BOOL)match:(struct arsdk_cmd*)cmd checkParams:(BOOL)checkParams"


def gen_expected_header_file(ctx, out):
    out.write("/** Generated, do not edit ! */\n")
    out.write("\n")

    out.write("#import <Foundation/Foundation.h>\n")
    out.write("#import <SdkCore/Arsdk.h>\n")
    out.write("\n")

    out.write("struct arsdk_cmd;\n")
    out.write("\n")

    out.write("@interface %s : NSObject\n", expected_cmd_class())
    out.write("\n")

    out.write("%s;\n", match_command_name())
    out.write("- (NSString*)describe;\n");
    out.write("\n")

    for feature_id in sorted(ctx.featuresById.keys()):
        feature_obj = ctx.featuresById[feature_id]
        for cmd in feature_obj.cmds:
            feature_name = feature_obj.name + ("_" + cmd.cls.name if cmd.cls else "")
            out.write("%s;\n", static_initializer_method_name(feature_obj, feature_name, cmd, True))

    out.write("@end\n")
    out.write("\n")

    for feature_id in sorted(ctx.featuresById.keys()):
        feature_obj = ctx.featuresById[feature_id]
        for cmd in feature_obj.cmds:
            feature_name = feature_obj.name + ("_" + cmd.cls.name if cmd.cls else "")
            out.write("@interface %s : %s\n", command_class_name(feature_name, cmd), expected_cmd_class())
            out.write("@end\n")
            out.write("\n")


def gen_expected_source_file(ctx, out):
    out.write("/** Generated, do not edit ! */\n")
    out.write("\n")

    out.write("#import \"" + expected_cmd_class() + ".h\"\n")
    out.write("#import <arsdk/arsdk.h>\n")
    out.write("\n")

    out.write("@interface %s ()\n", expected_cmd_class())
    out.write("\n")

    out.write("@property (nonatomic, assign) struct arsdk_cmd* cmd;\n")

    out.write("@end\n")
    out.write("\n")

    out.write("@implementation %s\n", expected_cmd_class())
    out.write("\n")

    out.write("%s {return false;}\n", match_command_name())
    out.write("\n")

    out.write("- (NSString*)describe {\n");
    out.write("    return [ArsdkCommand describe:self.cmd];\n");
    out.write("}\n");
    out.write("\n")

    for feature_id in sorted(ctx.featuresById.keys()):
        feature_obj = ctx.featuresById[feature_id]
        for cmd in feature_obj.cmds:
            feature_name = feature_obj.name + ("_" + cmd.cls.name if cmd.cls else "")
            out.write("%s {\n", static_initializer_method_name(feature_obj, feature_name, cmd))

            out.write("    %s *expectedCmd = [[%s alloc] init];\n", 
                command_class_name(feature_name, cmd),
                command_class_name(feature_name, cmd))

            out.write("    expectedCmd.cmd = calloc(1, sizeof(*expectedCmd.cmd));\n")
            out.write("    arsdk_cmd_init(expectedCmd.cmd);\n")
            out.write("\n")

            if cmd.args:
                out.write("    int res = arsdk_cmd_enc_%s_%s(expectedCmd.cmd, %s);\n",
                    c_name(feature_name), c_name(cmd.name),
                    ", ".join(arg_value_from_obj_c_to_c(feature_obj.name, arg) for arg in cmd.args))
            else:
                out.write("    int res = arsdk_cmd_enc_%s_%s(expectedCmd.cmd);\n",
                    c_name(feature_name), c_name(cmd.name))

            out.write("    if (res < 0) {\n")
            out.write("        return nil;\n")
            out.write("    }\n")
            out.write("    return expectedCmd;\n")

            out.write("}\n")
            out.write("\n")

    out.write("@end\n")
    out.write("\n")

    for feature_id in sorted(ctx.featuresById.keys()):
        feature_obj = ctx.featuresById[feature_id]
        for cmd in feature_obj.cmds:
            feature_name = feature_obj.name + ("_" + cmd.cls.name if cmd.cls else "")
            out.write("@implementation %s\n", command_class_name(feature_name, cmd))
            out.write("\n")

            out.write("%s {\n", match_command_name())
            out.write("    if (self.cmd->id != cmd->id) return false;\n")
            out.write("\n")

            if cmd.args:
                out.write("    if (checkParams) {\n")
                for arg in cmd.args:
                    out.write("        %s _%s;\n", arg_c_type(arg), arg_name(arg))

                out.write("        int res = arsdk_cmd_dec_%s_%s(cmd, %s);\n",
                    c_name(feature_name), c_name(cmd.name),
                    ", ".join("&_" + arg_name(arg) for arg in cmd.args))
                out.write("        if (res < 0) {\n")
                out.write("            return false;\n")
                out.write("        }\n")
                out.write("\n")

                for arg in cmd.args:
                    out.write("        %s my%s;\n", arg_c_type(arg), arg_name(arg).title())

                out.write("        res = arsdk_cmd_dec_%s_%s(self.cmd, %s);\n",
                    c_name(feature_name), c_name(cmd.name),
                    ", ".join("&my" + arg_name(arg).title() for arg in cmd.args))
                out.write("        if (res < 0) {\n")
                out.write("            return false;\n")
                out.write("        }\n")
                out.write("\n")

                for arg in cmd.args:
                    if arg.argType == arsdkparser.ArArgType.STRING: 
                        out.write("        NSString* %sObj = [NSString stringWithUTF8String:_%s];\n",
                            arg_name(arg), arg_name(arg))
                        out.write("        NSString* my%sObj = [NSString stringWithUTF8String:my%s];\n",
                            arg_name(arg).title(), arg_name(arg).title())
                        out.write("        if (![%sObj isEqual:my%sObj]) return false;\n", arg_name(arg), arg_name(arg).title())
                    elif isinstance(arg.argType, arsdkparser.ArMultiSetting):
                        out.write("        res = memcmp(&_%s, &my%s, sizeof(my%s));\n", arg.name, arg_name(arg).title(),
                                  arg_name(arg).title())
                        out.write("        if (res != 0) {\n")
                        out.write("            return false;\n")
                        out.write("        }\n")
                    else:
                        out.write("        if (_%s != my%s) return false;\n", arg_name(arg), arg_name(arg).title())
                    out.write("\n")
                out.write("    }\n")

            out.write("    return true;\n")
            out.write("}\n")

            out.write("@end\n")
            out.write("\n")


#===============================================================================

def cmd_encoder_class():
    return "CmdEncoder"

def encoder_function_signature(feature_obj, msg, with_swift_name=False):
    feature_name = feature_obj.name + ("_" + msg.cls.name if msg.cls else "")
    function_underscored = command_name(feature_name, msg) + "_encoder"
    components = function_underscored.split('_')
    func_name = components[0][0].lower() + components[0][1:] + "".join(x[0].upper() + x[1:] for x in components[1:])
    function_signature = "+ (int (^)(struct arsdk_cmd *))" + func_name
    if msg.args:
        # the first arg is special as the arg name is not part of the method name
        arg = msg.args[0]
        function_signature += ":(" + arg_type(feature_obj.name, arg, True) + ")" + arg_name(arg)
        for arg in msg.args[1:]:
            function_signature += " " + arg_name(arg) + ":(" + arg_type(feature_obj.name, arg, True) + ")" + arg_name(arg)
    if with_swift_name:
        function_signature += "\nNS_SWIFT_NAME(" + func_name + "("
        for arg in msg.args:
            function_signature += arg_name(arg) + ":"
        function_signature += "))"
    return function_signature

def gen_encoder_header_file(ctx, out):
    out.write("/** Generated, do not edit ! */\n")
    out.write("\n")

    out.write("#import <Foundation/Foundation.h>\n")
    out.write("#import <SdkCore/Arsdk.h>\n")
    out.write("\n")

    out.write("struct arsdk_cmd;\n")
    out.write("\n")

    out.write("@interface %s : NSObject\n", cmd_encoder_class())
    out.write("\n")

    for feature_id in sorted(ctx.featuresById.keys()):
        feature_obj = ctx.featuresById[feature_id]
        for evt in feature_obj.evts:
            out.write("%s;\n", encoder_function_signature(feature_obj, evt, True))

    out.write("@end\n")
    out.write("\n")


def gen_encoder_source_file(ctx, out):
    out.write("/** Generated, do not edit ! */\n")
    out.write("\n")

    out.write("#import \"%s.h\"\n", cmd_encoder_class())
    out.write("#import <arsdk/arsdk.h>\n")
    out.write("\n")

    out.write("@implementation %s\n", cmd_encoder_class())
    out.write("\n")

    for feature_id in sorted(ctx.featuresById.keys()):
        feature_obj = ctx.featuresById[feature_id]
        for evt in feature_obj.evts:
            feature_name = feature_obj.name + ("_" + evt.cls.name if evt.cls else "")
            out.write("%s {\n", encoder_function_signature(feature_obj, evt))

            out.write("    return ^(struct arsdk_cmd* cmd) {\n")
            if evt.args:
                out.write("        return arsdk_cmd_enc_%s_%s(cmd, %s);\n",
                    c_name(feature_name), c_name(evt.name),
                    ", ".join(arg_value_from_obj_c_to_c(feature_obj.name, arg) for arg in evt.args))
            else:
                out.write("        return arsdk_cmd_enc_%s_%s(cmd);\n",
                    c_name(feature_name), c_name(evt.name))
            out.write("    };\n")
            out.write("}\n")
            out.write("\n")

    out.write("@end\n")
    out.write("\n")


#===============================================================================

def list_files(ctx, outdir, extra):
    None

#===============================================================================
#===============================================================================

def generate_files(ctx, outdir, extra):
    if not os.path.exists (outdir):
        os.mkdirs (outdir)
    else:
        filelist = os.listdir(outdir)
        for f in filelist:
            os.remove(outdir + "/" + f)

    filepath = os.path.join(outdir, expected_cmd_class() + ".h")
    with open(filepath, "w") as file_obj:
        gen_expected_header_file(ctx, Writer(file_obj))

    filepath = os.path.join(outdir, expected_cmd_class() + ".m")
    with open(filepath, "w") as file_obj:
        gen_expected_source_file(ctx, Writer(file_obj))

    filepath = os.path.join(outdir, cmd_encoder_class() + ".h")
    with open(filepath, "w") as file_obj:
        gen_encoder_header_file(ctx, Writer(file_obj))

    filepath = os.path.join(outdir, cmd_encoder_class() + ".m")
    with open(filepath, "w") as file_obj:
        gen_encoder_source_file(ctx, Writer(file_obj))

    print("Done generating test features files.")
