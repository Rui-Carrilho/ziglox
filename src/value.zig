const std = @import("std");
const memory = @import("memory.zig");

pub const ValueArray = struct { capacity: usize, count: usize, values: []Value };

pub const ValueType = enum { VAL_BOOL, VAL_NIL, VAL_NUMBER };

pub const Value = struct { type: ValueType, as: union { boolean: bool, number: f64 } };

pub fn BOOL_VAL(value: bool) Value {
    return Value{
        .type = ValueType.VAL_BOOL,
        .as = .{ .boolean = value },
    };
}

pub const NIL_VAL: Value = Value{
    .type = ValueType.VAL_NIL,
    .as = .{ .number = 0 },
};

pub fn NUMBER_VAL(value: f64) Value {
    return Value{
        .type = ValueType.VAL_NUMBER,
        .as = .{ .number = value },
    };
}

pub fn initValueArray(array: *ValueArray) void {
    array.values = memory.initArray(Value);
    array.capacity = 0;
    array.count = 0;
}

pub fn writeValueArray(array: *ValueArray, value: Value, allocator: *std.mem.Allocator) !void {
    if (array.capacity < array.count + 1) {
        const oldCapacity = array.capacity;
        array.capacity = memory.GROW_CAPACITY(oldCapacity);
        array.values = try memory.growArray(Value, allocator, (array.*).values, array.capacity);
    }

    array.values[array.count] = value;
    array.count += 1;
}

pub fn freeValueArray(array: *ValueArray, allocator: *std.mem.Allocator) void {
    memory.FREE_ARRAY(Value, allocator, array.values, array.capacity) catch unreachable;
    initValueArray(array);
}

pub fn printValue(value: Value) void {
    std.debug.print("{d}", .{value});
}
