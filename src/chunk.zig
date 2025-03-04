const std = @import("std");
const memory = @import("memory.zig");
const values = @import("value.zig");

// OpCode enum to represent different bytecode instructions
pub const OpCode = enum(u8) {
    OP_ADD,
    OP_CONSTANT,
    OP_DIVIDE,
    OP_MULTIPLY,
    OP_NEGATE,
    OP_RETURN,
    OP_SUBTRACT,
};

pub const Chunk = struct { 
    code: []u8, 
    count: usize, 
    capacity: usize, 
    constants: values.ValueArray, 
    lines: []i32 
};

pub fn initChunk(chunk: *Chunk) void {
    chunk.code = memory.initArray(u8);
    chunk.lines = memory.initArray(i32);
    chunk.count = 0;
    chunk.capacity = 0;
    values.initValueArray(&chunk.constants);
}

pub fn writeChunk(chunk: *Chunk, byte: u8, line: i32, allocator: *std.mem.Allocator) !void {
    if (chunk.capacity < chunk.count + 1) {
        const oldCapacity = chunk.capacity;
        chunk.capacity = memory.GROW_CAPACITY(oldCapacity);
        chunk.code = try memory.growArray(u8, allocator, (chunk.*).code, chunk.capacity);
        chunk.lines = try memory.growArray(i32, allocator, chunk.*.lines, chunk.capacity);
    }

    chunk.code[chunk.count] = byte;
    chunk.lines[chunk.count] = line;
    chunk.count += 1;
}

pub fn addConstant(chunk: *Chunk, value: values.Value, allocator: *std.mem.Allocator) !usize {
    try values.writeValueArray(&chunk.constants, value, allocator);
    return chunk.constants.count - 1;
}

pub fn freeChunk(chunk: *Chunk, allocator: *std.mem.Allocator) void {
    memory.FREE_ARRAY(u8, allocator, chunk.code, chunk.capacity) catch unreachable;
    values.freeValueArray(&chunk.constants, allocator);
    initChunk(chunk);
}
