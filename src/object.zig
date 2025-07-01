const std = @import("std");
const Value = @import("value.zig");
const memory = @import("memory.zig");
const Allocator = @import("allocator.zig");
const VM = @import("vm.zig");
const Table = @import("table.zig");

pub const ObjType = enum {
    string,
    uninitialized, //this is an erry hack
};

pub const ObjNode = union(ObjType) {
    string: ObjString,
    uninitialized: void,
};

pub const Obj = struct { node: ObjNode, next: ?*Obj };

pub const ObjString = struct { chars: []u8, hash: u32 };

pub fn isObjType(value: Value.Value, myType: ObjType) bool {
    return Value.IS_OBJ(value) and @as(ObjType, Value.AS_OBJ(value).node) == myType;
}

pub fn OBJ_TYPE(value: Value.Value) ObjType {
    return @as(ObjType, Value.AS_OBJ(value));
}

pub fn IS_STRING(value: Value.Value) bool {
    return isObjType(value, ObjType.string);
}

pub fn OBJ_AS_STRING(obj: Obj) ObjString {
    return switch (obj.node) {
        ObjType.string => |myValue| myValue,
        else => std.debug.panic("fuckup in OBJ_AS_STRING (object.zig)", .{}),
    };
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
    const hash = hashString(name);
    const heapChars = try memory.ALLOCATE(u8, name.len);

    const interned = Table.tableFindString(&VM.vm.strings, name, hash);

    if (interned != null) {
        const string = try allocateObject();
        string.* = .{
            .node = .{ .string = interned.? },
            .next = null,
        };
        return string;
    }

    @memcpy(heapChars, name);
    return allocateString(heapChars, hash);
}

pub fn allocateString(chars: []u8, hash: u32) !*Obj {
    const string = try allocateObject();
    string.* = .{
        .node = .{ .string = .{ .chars = chars, .hash = hash } },
        .next = null,
    };
    _ = try Table.tableSet(&VM.vm.strings, string, Value.NIL_VAL);

    return string;
}

pub fn hashString(key: []const u8) u32 {
    var hash: u32 = 2166136261;
    var i: usize = 0;
    while (i < key.len) : (i += 1) {
        hash ^= @as(u8, key[i]);
        hash *%= 16777619;
    }

    return hash;
}

pub fn takeString(chars: []u8) !*Obj {
    const hash = hashString(chars);
    const interned = Table.tableFindString(&VM.vm.strings, chars, hash);

    if (interned != null) {
        try memory.FREE_ARRAY(u8, chars, chars.len);
        const string = try allocateObject();
        string.* = .{
            .node = .{ .string = interned.? },
            .next = null,
        };
        return string;
    }
    return allocateString(chars, hash);
    //haha
}

pub fn allocateObject() !*Obj {
    const object = try memory.reallocate(Obj, null, 0, 1);
    const finalObject = object.?;
    const finalfinalObject: *Obj = @ptrCast(finalObject.ptr);
    finalfinalObject.node = ObjNode.uninitialized;
    finalfinalObject.next = VM.vm.objects;
    VM.vm.objects = finalfinalObject;
    return finalfinalObject;
}
