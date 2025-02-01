const std = @import("std");
const common = @import("common.zig");
const memory: type = @import("memory.zig");

const OpCode = enum {
    OP_RETURN,
};

pub const Chunk = struct {
    count: i32,
    capacity: i32,
    code: [*c]u8,
};

pub fn initChunk(chunk: *Chunk) void {
    chunk.count = 0;
    chunk.capacity = 0;
    chunk.code = null;
}

pub fn freeChunk(chunk: *Chunk) void {
    memory.FREE_ARRAY(u8, chunk.code, chunk.capacity);
    initChunk(chunk);
}

pub fn writeChunk(chunk: *Chunk, byte: u8) void {
    if (chunk.capacity < chunk.count + 1) {
        const oldCapacity = chunk.capacity;
        chunk.capacity = memory.GROW_CAPACITY(oldCapacity);
        chunk.code = memory.growArray(u8, chunk.code, oldCapacity, chunk.capacity);
    }

    chunk.code[chunk.count] = byte;
    chunk.count += 1;
}