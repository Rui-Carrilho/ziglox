const std = @import("std");
const Value = @import("value.zig");
const memory = @import("memory.zig");
const Allocator = @import("allocator.zig");

pub const ObjType = enum { 
    string,
    uninitialized //this is an erry hack
};

pub const Obj = union(ObjType) { 
    string: ObjString,
    uninitialized: void
};

pub const ObjString = struct { chars: []u8 };

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

pub fn AS_CSTRING(value: Value.Value) [*]u8 {
    return AS_STRING(value).chars.ptr;
}

pub fn copyString(name: []const u8) !*Obj {
    const heapChars = try memory.ALLOCATE(u8, name.len);
    @memcpy(heapChars, name);
    return allocateString(heapChars, name.len);
}

pub fn allocateString(chars: []u8) *Obj {
    const string = allocateObject();
    string.* = .{
        .string = .{
            .chars = chars
        }
    };

    return string;
}

pub fn allocateObject() *Obj {
    const object = try memory.reallocate(Obj, Allocator.allocator, null, 0, 1);
    const finalObject = object.?;
    const finalfinalObject: *Obj = @ptrCast(finalObject.ptr);
    finalfinalObject.* = Obj.uninitialized;
    return finalfinalObject;
}