const std = @import("std");
const Value = @import("value.zig");

pub const ObjType = enum {
    OBJ_STRING
};

pub const Obj = struct {type: ObjType};

pub const ObjString = struct {
    obj: Obj, 
    length: usize,
    chars: [*:0]u8 
};

pub fn OBJ_TYPE(value: Value.Value) Value.ValueType {
    return @as(Value.ValueType, Value.AS_OBJECT(value));
}