const std = @import("std");
const memory = @import("memory.zig");
const Value = @import("value.zig");

// OpCode enum to represent different bytecode instructions
pub const OpCode = enum(u8) {
    OP_ADD,
    OP_CONSTANT,
    OP_DEFINE_GLOBAL,
    OP_DIVIDE,
    OP_EQUAL,
    OP_FALSE,
    OP_GET_GLOBAL,
    OP_GET_LOCAL,
    OP_GREATER,
    OP_JUMP,
    OP_JUMP_IF_FALSE,
    OP_LESS,
    OP_LOOP,
    OP_MULTIPLY,
    OP_NEGATE,
    OP_NIL,
    OP_NOT,
    OP_POP,
    OP_PRINT,
    OP_RETURN,
    OP_SET_GLOBAL,
    OP_SET_LOCAL,
    OP_SUBTRACT,
    OP_TRUE,
};

pub const Chunk = struct { code: []u8, count: usize, capacity: usize, constants: Value.ValueArray, lines: []i32 };

pub fn initChunk(chunk: *Chunk) void {
    std.debug.print("in - initChunk (chunk)\n", .{});
    chunk.code = memory.initArray(u8);
    chunk.lines = memory.initArray(i32);
    chunk.count = 0;
    chunk.capacity = 0;
    Value.initValueArray(&chunk.constants);
    std.debug.print("out - initChunk (chunk)\n", .{});
}

pub fn writeChunk(chunk: *Chunk, byte: u8, line: i32) !void {
    std.debug.print("doing writeChunk (chunk)\n", .{});
    if (chunk.capacity < chunk.count + 1) {
        const oldCapacity = chunk.capacity;
        chunk.capacity = memory.GROW_CAPACITY(oldCapacity);
        chunk.code = try memory.growArray(u8, (chunk.*).code, chunk.capacity);
        chunk.lines = try memory.growArray(i32, chunk.*.lines, chunk.capacity);
    }

    chunk.code[chunk.count] = byte;
    chunk.lines[chunk.count] = line;
    chunk.count += 1;
}

pub fn addConstant(chunk: *Chunk, value: Value.Value) !usize {
    std.debug.print("doing addConstant (chunk.zig)\n", .{});
    std.debug.print("chunk: count - {d}\n", .{chunk.constants.count});
    try Value.writeValueArray(&chunk.constants, value);
    return chunk.constants.count - 1;
}

pub fn freeChunk(chunk: *Chunk) void {
    memory.FREE_ARRAY(u8, chunk.code, chunk.capacity) catch unreachable;
    Value.freeValueArray(&chunk.constants);
    initChunk(chunk);
}
