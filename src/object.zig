const std = @import("std");
const Value = @import("value.zig");
const memory = @import("memory.zig");

pub const ObjType = enum { string };

pub const Obj = union(ObjType) { string: ObjString };

pub const ObjString = struct { length: usize, chars: [*:0]u8 };

pub fn isObjType(value: Value.Value, myType: ObjType) bool {
    return Value.IS_OBJ(value) and @as(ObjType, Value.AS_OBJ(value)) == myType;
}

pub fn OBJ_TYPE(value: Value.Value) ObjType {
    return @as(ObjType, Value.AS_OBJ(value));
}

pub fn IS_STRING(value: Value.Value) bool {
    return isObjType(value, ObjType.string);
}

pub fn AS_STRING(value: Value.Value) ObjString {
    return switch (value) {
        ObjType.string => |myValue| myValue,
        else => std.debug.print("fuckup in AS_STRING (object.zig)", .{}),
    };
}

pub fn AS_CSTRING(value: Value.Value) [*:0]u8 {
    return AS_STRING(value).chars;
}

pub fn copyString(name: []u8) *ObjString {
    const heapChars = memory.ALLOCATE(u8)
}
