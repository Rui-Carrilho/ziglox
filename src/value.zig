const std = @import("std");
const memory = @import("memory.zig");
const Object = @import("object.zig");

pub const ValueArray = struct { capacity: usize, count: usize, values: []Value };

pub const ValueType = enum { boolean, number, obj, nil };

//pub const Value = struct { type: ValueType, as: union { boolean: bool, number: f64 } };

pub const Value = union(ValueType) { boolean: bool, number: f64, obj: *Object.Obj, nil: void };

pub fn BOOL_VAL(value: bool) Value {
    return .{ .boolean = value };
}

pub const NIL_VAL: Value = .nil;

pub fn NUMBER_VAL(value: f64) Value {
    return .{ .number = value };
}

pub fn OBJ_VAL(value: *Object.Obj) Value {
    return .{ .obj = value };
}

pub fn AS_BOOL(value: Value) bool {
    return switch (value) {
        Value.boolean => |myValue| myValue,
        else => {
            std.debug.panic("fuckup in AS_BOOL(value.zig)", .{});
        },
    };
}

//test
pub fn AS_NUMBER(value: Value) f64 {
    return switch (value) {
        Value.number => |myValue| myValue,
        else => {
            std.debug.panic("fuckup in AS_NUMBER(value.zig)", .{});
        },
    };
}

pub fn AS_OBJ(value: Value) *Object.Obj {
    return switch (value) {
        Value.obj => |myValue| myValue,
        else => {
            std.debug.panic("fuckup in AS_OBJECT(value.zig)", .{});
        },
    };
}

pub fn IS_BOOL(value: Value) bool {
    return switch (value) {
        Value.boolean => true,
        else => false,
    };
}

pub fn IS_NIL(value: Value) bool {
    return switch (value) {
        Value.nil => true,
        else => false,
    };
}

pub fn IS_NUMBER(value: Value) bool {
    return switch (value) {
        Value.number => true,
        else => false,
    };
}

pub fn IS_OBJ(value: Value) bool {
    return switch (value) {
        Value.obj => true,
        else => false,
    };
}

pub fn initValueArray(array: *ValueArray) void {
    array.values = memory.initArray(Value);
    array.capacity = 0;
    array.count = 0;
}

pub fn writeValueArray(array: *ValueArray, value: Value) !void {
    if (array.capacity < array.count + 1) {
        const oldCapacity = array.capacity;
        array.capacity = memory.GROW_CAPACITY(oldCapacity);
        array.values = try memory.growArray(Value, (array.*).values, array.capacity);
    }

    array.values[array.count] = value;
    array.count += 1;
}

pub fn freeValueArray(array: *ValueArray) void {
    memory.FREE_ARRAY(Value, array.values, array.capacity) catch unreachable;
    initValueArray(array);
}

pub fn printValue(value: Value) void {
    switch (value) {
        Value.boolean => |myValue| {
            std.debug.print("{}", .{myValue});
        },
        Value.number => |myValue| {
            std.debug.print("{d}", .{myValue});
        },
        Value.nil => std.debug.print("nil", .{}),
        Value.obj => |myValue| printObject(myValue),
    }
}

pub fn printObject(value: *Object.Obj) void {
    switch (value.node) {
        Object.ObjType.string => |myValue| std.debug.print("{s}", .{myValue.chars}),
        Object.ObjType.uninitialized => std.debug.print("oops, uninitialized", .{}),
    }
}

pub fn valuesEqual(a: Value, b: Value) bool {
    if (@as(ValueType, a) != @as(ValueType, b)) return false;
    switch (a) {
        ValueType.boolean => return AS_BOOL(a) == AS_BOOL(b),
        ValueType.nil => return true,
        ValueType.number => return AS_NUMBER(a) == AS_NUMBER(b),
        ValueType.obj => return AS_OBJ(a) == AS_OBJ(b),
    }
}
