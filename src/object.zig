const std = @import("std");
const Value = @import("value.zig");
const memory = @import("memory.zig");
const Allocator = @import("allocator.zig");
const VM = @import("vm.zig");

pub const ObjType = enum { 
    string,
    uninitialized, //this is an erry hack
};

pub const ObjNode = union(ObjType) { 
    string: ObjString,
    uninitialized: void,
};

pub const Obj = struct {
    node: ObjNode,
    next: ?*Obj
};

pub const ObjString = struct { chars: []u8 };

pub fn isObjType(value: Value.Value, myType: ObjType) bool {
    return Value.IS_OBJ(value) and @as(ObjType, Value.AS_OBJ(value).node) == myType;
}

pub fn OBJ_TYPE(value: Value.Value) ObjType {
    return @as(ObjType, Value.AS_OBJ(value));
}

pub fn IS_STRING(value: Value.Value) bool {
    return isObjType(value, ObjType.string);
}

pub fn AS_STRING(value: Value.Value) ObjString {
    return switch (Value.AS_OBJ(value).node) {
        ObjType.string => |myValue| myValue,
        else => std.debug.panic("fuckup in AS_STRING (object.zig)", .{}),
    };
}

pub fn AS_CSTRING(value: Value.Value) [*]u8 {
    return AS_STRING(value).chars.ptr;
}

pub fn copyString(name: []const u8) !*Obj {
    const heapChars = try memory.ALLOCATE(u8, name.len);
    @memcpy(heapChars, name);
    return allocateString(heapChars);
}

pub fn allocateString(chars: []u8) !*Obj {
    const string = try allocateObject();
    string.* = .{
        .node = .{
            .string = .{
                .chars = chars
            }
        },
        .next = null,
    };

    return string;
}

pub fn takeString(chars: []u8) !*Obj {
    return allocateString(chars);
}

pub fn allocateObject() !*Obj {
    const object = try memory.reallocate(Obj, Allocator.allocator, null, 0, 1);
    const finalObject = object.?;
    const finalfinalObject: *Obj = @ptrCast(finalObject.ptr);
    finalfinalObject.node = ObjNode.uninitialized;
    finalfinalObject.next = VM.vm.objects;
    VM.vm.objects = finalfinalObject;
    return finalfinalObject;
}