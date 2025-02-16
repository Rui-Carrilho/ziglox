const std = @import("std");
const Chunk = @import("chunk.zig");

pub fn disassembleChunk(chunk: *Chunk.Chunk, name: []const u8) void {
    std.debug.print("== {} ==\n", .{name});

    var offset: usize = 0;
    while (offset < chunk.count) {
        offset = disassembleInstruction(chunk, offset);
    }
}

pub fn disassembleInstruction(chunk: *Chunk.Chunk, offset: usize) usize {
    std.debug.print("{d:0>4} ", .{offset});

    const instruction = chunk.code[offset];
    switch (instruction) {
        @intFromEnum(Chunk.OpCode.OP_RETURN) => return simpleInstruction("OP_RETURN", offset),
        else => {
            std.debug.print("Unknown opcode {d}\n", .{instruction});
            return offset + 1;
        },
    }
}

pub fn simpleInstruction(name: []const u8, offset: usize) usize {
    std.debug.print("{s}\n", .{name});
    return offset + 1;
}
