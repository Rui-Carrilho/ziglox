const std = @import("std");
const memory = @import("memory.zig");

pub const Value = f64;

pub const ValueArray = struct {
    capacity: usize,
    count: usize,
    values: [] Value
};

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