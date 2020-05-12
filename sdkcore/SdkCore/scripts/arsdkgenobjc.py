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

CMD_STRUCT = "struct arsdk_cmd"

#===============================================================================

def class_name(name):
    splitted_name = name.split('_')
    return "ArsdkFeature" + "".join(x.capitalize() for x in splitted_name)

def enum_class_name(feature_strict_name, enum_name):
    splitted_name = enum_name.split('_')
    return class_name(feature_strict_name) + "".join(x.capitalize() for x in splitted_name)

def feature_source_file_name(name):
    return class_name(name) + ".m"

def feature_header_file_name(name):
    return class_name(name) + ".h"

def feature_callback_class_name(name):
    return class_name(name) + "Callback"

def enum_val_name(feature_strict_name, enum, name):
    splitted_name = name.split('_')
    val_name = enum_class_name(feature_strict_name, enum.name)
    # let the underscore between two tokens
    # if the first ends with a digit and the last begins with a digit
    for x in splitted_name:
        if x[0].isdigit() and val_name[-1].isdigit():
            val_name = val_name+"_"+x.capitalize()
        else:
            val_name = val_name+x.capitalize()
    return val_name

def enum_unknown_val_name(feature_strict_name, enum_name):
    return enum_class_name(feature_strict_name, enum_name)+"SdkCoreUnknown"

def method_name(name):
    components = name.split('_')
    return components[0][0].lower() + components[0][1:] + "".join(x[0].upper() + x[1:] for x in components[1:])

def param_name(name):
    components = name.split('_')
    return components[0].lower() + "".join(x[0].upper() + x[1:] for x in components[1:])

def arg_type(feature_strict_name, arg, is_fun_arg = False):
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
    else:
        argType = args[arg.argType]
    return argType


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
    else:
        argType = args[arg.argType]
    return argType

def arg_name(arg):
    if isinstance(arg.argType, arsdkparser.ArEnum):
        argName = param_name(arg.name)
    elif isinstance(arg.argType, arsdkparser.ArBitfield):
        argName = param_name(arg.name) + "BitField"
    else:
        argName = param_name(arg.name)
    return argName

def arg_value_from_c_to_obj_c(feature_strict_name, arg):
    if arg.argType == arsdkparser.ArArgType.STRING:
        return "[NSString stringWithUTF8String:" + arg_name(arg) + "]"
    else:
        return arg_name(arg)


def arg_value_from_obj_c_to_c(feature_strict_name, arg):
    if arg.argType == arsdkparser.ArArgType.STRING:
        return "[" + arg_name(arg) + " UTF8String]"
    elif arg_c_type(arg) != arg_type(feature_strict_name, arg):
        return "(" + arg_c_type(arg) + ")" + arg_name(arg)
    else:
        return arg_name(arg)


def call_callback_function_name(feature_name, evt_name, with_params=False):
    splitted_name = evt_name.split('_')
    function_name = "call" + "".join(x.capitalize() for x in splitted_name) + ":"
    if with_params:
        function_name = function_name + "(" + CMD_STRUCT + "*)"
    function_name += "command callback:"
    if with_params:
        function_name = function_name + "(id<" + feature_callback_class_name(feature_name) + ">)"
    function_name += "callback"
    return function_name


def c_name(val):
    return val[0].upper() + val[1:]

def uid_const_name(feature_name):
    return "k" + class_name(feature_name) + "Uid"

#===============================================================================

def gen_feature_enum_declaration(feature_obj, feature_name, enum, out):
    out.write("/** %s */\n", enum.doc)
    out.write("typedef NS_ENUM(NSInteger, " + enum_class_name(feature_obj.name, enum.name) + ") {\n")

    # write the unknown value
    out.write("    /**\n")
    out.write("     Unknown value from SdkCore.\n")
    out.write("     Only used if the received value cannot be matched with a declared value.\n")
    out.write("     This might occur when the drone or rc has a different sdk base from the controller.\n")
    out.write("     */\n")
    out.write("    %s = -1,\n", enum_unknown_val_name(feature_obj.name, enum.name))
    out.write("\n")

    for idx, enum_val in enumerate(enum.values):
        out.write("    /** %s */\n", enum_val.doc)
        out.write("    %s = %s,\n", enum_val_name(feature_obj.name, enum, enum_val.name), enum_val.value)
        out.write("\n")

    out.write("};\n")
    out.write("#define %sCnt %d\n", enum_class_name(feature_obj.name, enum.name), idx+1)
    out.write("\n")

    if enum.usedLikeBitfield:
        type = 'NSUInteger' if len(enum.values) <= 31 else 'uint64_t'
        out.write("@interface %sBitField : NSObject\n\n", enum_class_name(feature_obj.name, enum.name))
        out.write("+ (BOOL) isSet:(%s)val inBitField:(%s)bitfield;\n\n",
                  enum_class_name(feature_obj.name, enum.name), type)
        out.write("+ (void) forAllSetIn:(%s)bitfield execute:(void(^)(%s val))cb;\n\n",
                  type, enum_class_name(feature_obj.name, enum.name))
        out.write("@end\n")
        out.write("\n")

def gen_feature_callback_declaration(feature_obj, feature_name, evts, out):
    out.write("@protocol " + feature_callback_class_name(feature_name) + "<NSObject>\n")
    out.write("\n")
    out.write("@optional\n")
    out.write("\n")

    #for each event of the feature
    for evt in sorted(evts, key=lambda evt: evt.cmdId):
        # write the doc
        out.write("/**\n")
        out.write(" %s \n\n", evt.doc.desc)
        for arg in evt.args:
            out.write(" - parameter %s: %s\n", arg.name, arg.doc)
        out.write("*/\n")

        # write the method signature
        out.write("- (void)" + method_name("on_" + evt.name))
        if evt.args:
            # the first arg is special as the arg name is not part of the method name
            arg = evt.args[0]
            out.write(":(" + arg_type(feature_obj.name, arg, True) + ")" + arg_name(arg))
            for arg in evt.args[1:]:
                out.write(" " + arg_name(arg) + ":(" + arg_type(feature_obj.name, arg, True) + ")" + arg_name(arg))
        out.write("\n")
        out.write("NS_SWIFT_NAME(%s(", method_name("on_" + evt.name))
        for arg in evt.args:
            out.write("%s:", arg_name(arg))
        out.write("));\n")
        out.write("\n")
    out.write("\n")

    out.write("@end\n")
    out.write("\n")


def gen_decode_declaration(feature_name, out):
    out.write("+ (NSInteger)decode:("+ CMD_STRUCT +"*)command callback:(id<")
    out.write(feature_callback_class_name(feature_name) +">)callback;\n")
    out.write("\n")


def gen_feature_enum_implementation(feature_obj, feature_name, enum, out):
    if enum.usedLikeBitfield:
        type = 'NSUInteger' if len(enum.values) <= 32 else 'uint64_t'
        out.write("@implementation %sBitField\n\n", enum_class_name(feature_obj.name, enum.name))
        out.write("+ (BOOL) isSet:(%s)val inBitField:(%s)bitfield {\n",
                  enum_class_name(feature_obj.name, enum.name), type)
        out.write("    return (bitfield & (1 << val)) != 0;")
        out.write("}\n\n")
        out.write("+ (void) forAllSetIn:(%s)bitfield execute:(void(^)(%s val))cb{\n",
                   type, enum_class_name(feature_obj.name, enum.name))
        out.write("    for (NSInteger idx=0; idx<%d; idx++) {\n", len(enum.values));
        out.write("        if ((bitfield & (1ull << idx)) != 0) {\n");
        out.write("            cb(idx);\n")
        out.write("        }\n")
        out.write("    }\n")
        out.write("}\n\n")
        out.write("@end\n")
        out.write("\n")


def gen_decode_implementation(feature_name, feature_id, class_id, evts, out):
    out.write("+ (NSInteger)decode:("+ CMD_STRUCT +"*)command callback:(id<")
    out.write(feature_callback_class_name(feature_name) +">)callback {\n")

    out.write("    if ((command == NULL) || ")
    out.write("(command->prj_id != " + str(feature_id) + ") || ")
    out.write("(command->cls_id != %d)) {\n", class_id)
    out.write("        return -1;\n")
    out.write("    }\n")
    out.write("\n")

    out.write("    switch (command->cmd_id) {\n")

    for evt in sorted(evts, key=lambda evt: evt.cmdId):
        out.write("        case %d:\n", evt.cmdId)
        out.write("            return [%s %s];\n",
            class_name(feature_name), call_callback_function_name(feature_name, evt.name))
    out.write("        default:\n")
    out.write("            return -1;\n")

    out.write("    }\n")
    out.write("}\n")
    out.write("\n")


def gen_encode_declarations(feature_strict_name, cmds, out):
    for cmd in sorted(cmds, key=lambda cmd: cmd.cmdId):
        # write the doc
        out.write("/**\n")
        out.write(" %s \n\n", cmd.doc.desc)
        for arg in cmd.args:
            out.write(" - parameter %s: %s\n", arg.name, arg.doc)
        out.write(" - returns: a block that encodes the command\n")
        out.write("*/\n")
        out.write("+ (int (^)(struct arsdk_cmd *))" + method_name(cmd.name + "_encoder"))
        if cmd.args:
            # the first arg is special as the arg name is not part of the method name
            arg = cmd.args[0]
            out.write(":(" + arg_type(feature_strict_name, arg, True) + ")" + arg_name(arg))
            for arg in cmd.args[1:]:
                out.write(" " + arg_name(arg) + ":(" + arg_type(feature_strict_name, arg, True) + ")" + arg_name(arg))
        out.write("\n")
        out.write("NS_SWIFT_NAME(%s(", method_name(cmd.name + "_encoder"))
        for arg in cmd.args:
            out.write("%s:", arg_name(arg))
        out.write("));\n")
        out.write("\n")


def gen_encode_implementations(feature_obj, feature_name, cmds, out):
    for cmd in sorted(cmds, key=lambda cmd: cmd.cmdId):
        out.write("+ (int (^)(struct arsdk_cmd *))" + method_name(cmd.name + "_encoder"))
        if cmd.args:
            # the first arg is special as the arg name is not part of the method name
            arg = cmd.args[0]
            out.write(":(" + arg_type(feature_obj.name, arg, True) + ")" + arg_name(arg))
            for arg in cmd.args[1:]:
                out.write(" " + arg_name(arg) + ":(" + arg_type(feature_obj.name, arg, True) + ")" + arg_name(arg))
        out.write(" {\n")
        out.write("    return ^(struct arsdk_cmd* cmd) { \n")
        if cmd.args:
            out.write("        return arsdk_cmd_enc_%s_%s(cmd, %s);\n",
                    c_name(feature_name), c_name(cmd.name),
                    ", ".join(arg_value_from_obj_c_to_c(feature_obj.name, arg) for arg in cmd.args))
        else:
            out.write("        return arsdk_cmd_enc_%s_%s(cmd);\n",
                    c_name(feature_name), c_name(cmd.name))
        out.write("    }; \n")

        out.write("}\n")
        out.write("\n")


def gen_call_callbacks_implementations(feature_obj, feature_name, evts, out):
    for evt in sorted(evts, key=lambda evt: evt.cmdId):
        out.write("+ (int)%s {\n", call_callback_function_name(feature_name, evt.name, True))

        out.write("    if ([callback respondsToSelector:@selector(")
        out.write(method_name("on_" + evt.name))
        if evt.args:
            # the first arg is special as the arg name is not part of the method name
            out.write(":")
            for arg in evt.args[1:]:
                out.write(arg_name(arg) + ":")
        out.write(")]) {\n")

        for arg in evt.args:
            out.write("        %s %s;\n", arg_c_type(arg), arg_name(arg))

        if evt.args:
            out.write("        int res = arsdk_cmd_dec_%s_%s(command, %s);\n",
                    c_name(feature_name), c_name(evt.name),
                    ", ".join("&" + arg_name(arg) for arg in evt.args))
        else:
            out.write("        int res = arsdk_cmd_dec_%s_%s(command);\n",
                    c_name(feature_name), c_name(evt.name))

        out.write("        if (res < 0) {\n")
        out.write("            return res;\n")
        out.write("        }\n")

        for arg in (arg for arg in evt.args if isinstance(arg.argType, arsdkparser.ArEnum)):
            enum = arg.argType

            out.write("        if (")
            out.write("%s != %s", arg_name(arg), enum_val_name(feature_obj.name, enum, enum.values[0].name))
            for enum_val in enum.values[1:]:
                out.write("&&\n            %s != %s",
                    arg_name(arg), enum_val_name(feature_obj.name, enum, enum_val.name))
            out.write(") {\n")
            out.write("            %s = (%s)%s;\n",
                arg_name(arg), arg_c_type(arg), enum_unknown_val_name(feature_obj.name, enum.name))
            out.write("        }\n")

        out.write("        [callback %s", method_name("on_" + evt.name))
        if evt.args:
            # the first arg is special as the arg name is not part of the method name
            arg = evt.args[0]
            out.write(":" + arg_value_from_c_to_obj_c(feature_name, arg))
            for arg in evt.args[1:]:
                out.write(" " + arg_name(arg) + ":" + arg_value_from_c_to_obj_c(feature_name, arg))
        out.write("];\n")
        out.write("    }\n")
        out.write("    return 0;\n")

        out.write("}\n")
        out.write("\n")


def gen_header_file(feature_obj, feature_name, enums, cmds, evts, out):
    out.write("/** Generated, do not edit ! */\n")
    out.write("\n")

    out.write("#import <Foundation/Foundation.h>\n")
    out.write("\n")

    out.write("extern short const %s;\n", uid_const_name(feature_name))
    out.write("\n")

    out.write(CMD_STRUCT + ";\n")
    out.write("\n")

    # Enums
    for enum in enums:
        gen_feature_enum_declaration(feature_obj, feature_name, enum, out)

    # callbacks
    if evts:
        gen_feature_callback_declaration(feature_obj, feature_name, evts, out)

    # class definition
    out.write("@interface " + class_name(feature_name) + " : NSObject\n")
    out.write("\n")

    if evts:
        gen_decode_declaration(feature_name, out)

    if cmds:
        gen_encode_declarations(feature_obj.name, cmds, out)

    out.write("@end\n")
    out.write("\n")


def gen_source_file(feature_obj, feature_name, class_id, enums, cmds, evts, out):
    out.write("/** Generated, do not edit ! */\n")
    out.write("\n")

    out.write("#import \"" + feature_header_file_name(feature_name) + "\"\n")
    out.write("#import <arsdk/arsdk.h>\n")
    out.write("\n")

    out.write("short const %s = 0x%04X;\n", uid_const_name(feature_name), feature_obj.featureId * 256 + class_id)
    out.write("\n")

    # Enums
    for enum in enums:
        gen_feature_enum_implementation(feature_obj, feature_name, enum, out)

    out.write("@implementation " + class_name(feature_name) +"\n")
    out.write("\n")

    if evts:
        gen_decode_implementation(feature_name, feature_obj.featureId, class_id, evts, out)

    if cmds:
        gen_encode_implementations(feature_obj, feature_name, cmds, out)

    if evts:
        gen_call_callbacks_implementations(feature_obj, feature_name, evts, out)

    out.write("@end\n")
    out.write("\n")

def gen_root_header(generated_features, out):
    out.write("/** Generated, do not edit ! */\n")
    out.write("\n")

    #out.write("#import \"ArsdkFeatures.h\"\n")
    for header_file in generated_features:
        out.write("#include \"" + class_name(header_file) + ".h\"\n")

def gen_root_source(generated_features, out):
    out.write("/** Generated, do not edit ! */\n")
    out.write("\n")

    #out.write("#import \"ArsdkFeatures.h\"\n")
    for source_file in generated_features:
        out.write("#import \"" + class_name(source_file) + ".m\"\n")

#===============================================================================
#===============================================================================

def list_files(ctx, outdir, extra):
    None

#===============================================================================
#===============================================================================

def generate_feature(feature_obj, class_obj, outdir):
    # generate header file
    feature_name = feature_obj.name + ("_" + class_obj.name if class_obj else "")
    filepath = os.path.join(outdir, feature_header_file_name(feature_name))
    feature_id = feature_obj.featureId
    class_id = 0
    enums = feature_obj.enums
    cmds = feature_obj.cmds
    evts = feature_obj.evts
    if class_obj:
        # Project based (old)
        class_id = class_obj.classId
        enums = [enum for enum in feature_obj.enums if class_id == enum.msg.cls.classId]
        cmds = [cmd for cmd in feature_obj.cmds if class_id == cmd.cls.classId]
        evts = [evt for evt in feature_obj.evts if class_id == evt.cls.classId]

    with open(filepath, "w") as file_obj:
        gen_header_file(feature_obj, feature_name, enums, cmds, evts,
                        Writer(file_obj))


    # generate source file
    filepath = os.path.join(outdir, feature_source_file_name(feature_name))
    with open(filepath, "w") as file_obj:
        gen_source_file(feature_obj, feature_name, class_id, enums, cmds, evts, Writer(file_obj))

    return feature_name


def generate_files(ctx, outdir, extra):
    if not os.path.exists (outdir):
        os.mkdirs (outdir)
    else:
        filelist = [ f for f in os.listdir(outdir) if f.startswith(class_name("")) ]
        for f in filelist:
            os.remove(outdir + "/" + f)

    generated_features = []
    for feature_id in sorted(ctx.featuresById.keys()):
        feature_obj = ctx.featuresById[feature_id]
        if feature_obj.classes:
            # Project based (old)
            for cls_id in sorted(feature_obj.classesById.keys()):
                class_obj = feature_obj.classesById[cls_id]
                generated_feature = generate_feature(feature_obj, class_obj, outdir)
                generated_features.append(generated_feature)
        else:
            generated_feature = generate_feature(feature_obj, None, outdir)
            generated_features.append(generated_feature)


    # generate the main file that includes all other files
    filepath = os.path.join(outdir, "ArsdkFeatures.h")
    with open(filepath, "w") as fileobj:
        gen_root_header(generated_features, Writer(fileobj))

    # generate the main file that includes all other files
    filepath = os.path.join(outdir, "ArsdkFeatures.m")
    with open(filepath, "w") as fileobj:
        gen_root_source(generated_features, Writer(fileobj))

    print("Done generating features files")
