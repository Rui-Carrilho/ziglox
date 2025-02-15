const std = @import("std");
const Chunk = @import("chunk.zig");

pub fn disassembleChunk(chunk: *Chunk.Chunk, name: []i8) void {
    std.debug.print("== {} ==\n", .{name});

    for (chunk.count) |offset| {
        offset = disassembleInstruction(chunk, offset);
    }
}

pub fn disassembleInstruction(chunk: *Chunk.Chunk, offset: i32) i32 {
    std.debug.print("{d:0>4} ", .{offset});

    const instruction = chunk.code[offset];
    switch (instruction) {
        Chunk.OpCode.OP_RETURN => return simpleInstruction("OP_RETURN", offset),
        else => {
            std.debug.print("Unknown opcode {d}\n", .{instruction});
            return offset + 1;
        }
    }
}

pub fn simpleInstruction(name: []const u8, offset: i32) i32 {
    std.debug.print("{s}\n", .{name});
    return offset + 1;
}