const std = @import("std");
const Chunk = @import("chunk.zig");
const Value = @import("value.zig");

pub const debug_trace_execution = true;

pub fn disassembleChunk(chunk: *Chunk.Chunk, name: []const u8) void {
    std.debug.print("== {s} ==\n", .{name});

    var offset: usize = 0;
    while (offset < chunk.count) {
        offset = disassembleInstruction(chunk, offset);
    }
}

pub fn disassembleInstruction(chunk: *Chunk.Chunk, offset: usize) usize {
    std.debug.print("{d:0>4} ", .{offset});

    if (offset > 0 and chunk.lines[offset] == chunk.lines[offset - 1]) {
        std.debug.print("    | ", .{});
    } else {
        std.debug.print("{d:4} ", .{chunk.lines[offset]});
    }

    const instruction = chunk.code[offset];
    switch (instruction) {
        @intFromEnum(Chunk.OpCode.OP_ADD) => return simpleInstruction("OP_ADD", offset),
        @intFromEnum(Chunk.OpCode.OP_CONSTANT) => return constantInstruction("OP_CONSTANT", chunk, offset),
        @intFromEnum(Chunk.OpCode.OP_DEFINE_GLOBAL) => return constantInstruction("OP_DEFINE_GLOBAL", chunk, offset),
        @intFromEnum(Chunk.OpCode.OP_DIVIDE) => return simpleInstruction("OP_DIVIDE", offset),
        @intFromEnum(Chunk.OpCode.OP_FALSE) => return simpleInstruction("OP_FALSE", offset),
        @intFromEnum(Chunk.OpCode.OP_GET_GLOBAL) => return simpleInstruction("OP_GET_GLOBAL", offset),
        @intFromEnum(Chunk.OpCode.OP_MULTIPLY) => return simpleInstruction("OP_MULTIPLY", offset),
        @intFromEnum(Chunk.OpCode.OP_NEGATE) => return simpleInstruction("OP_NEGATE", offset),
        @intFromEnum(Chunk.OpCode.OP_NIL) => return simpleInstruction("OP_NIL", offset),
        @intFromEnum(Chunk.OpCode.OP_NOT) => return simpleInstruction("OP_NOT", offset),
        @intFromEnum(Chunk.OpCode.OP_POP) => return simpleInstruction("OP_POP", offset),
        @intFromEnum(Chunk.OpCode.OP_PRINT) => return simpleInstruction("OP_PRINT", offset),
        @intFromEnum(Chunk.OpCode.OP_RETURN) => return simpleInstruction("OP_RETURN", offset),
        @intFromEnum(Chunk.OpCode.OP_SUBTRACT) => return simpleInstruction("OP_SUBTRACT", offset),
        @intFromEnum(Chunk.OpCode.OP_TRUE) => return simpleInstruction("OP_TRUE", offset),
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

pub fn constantInstruction(name: []const u8, chunk: *Chunk.Chunk, offset: usize) usize {
    const constant = chunk.code[offset + 1];
    std.debug.print("{s:<16} {d:>4} ", .{ name, constant });
    Value.printValue(chunk.constants.values[constant]);
    std.debug.print("\n", .{});
    return offset + 2;
}
