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

pub fn isObjType(value: Value.Value, myType: ObjType) bool {
    return Value.IS_OBJECT(value) and Value.AS_OBJECT(value).type == myType;
}

pub fn OBJ_TYPE(value: Value.Value) Value.ValueType {
    return @as(Value.ValueType, Value.AS_OBJECT(value));
}

pub fn IS_STRING(value: Value.Value) bool {
    return isObjType(value, ObjType.OBJ_STRING);
}

pub fn AS_STRING(value: Value.Value) ObjString {
    return switch (value) {

    }
}