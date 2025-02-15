const std = @import("std");
const memory = @import("memory.zig");
const chunk = @import("chunk.zig");
const debug = @import("debug.zig");


pub fn main() void {
    // Allocate memory
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var newChunk: chunk.Chunk = undefined;
    chunk.initChunk(&newChunk);
    chunk.writeChunk(&newChunk, @intFromEnum(chunk.OpCode.OP_RETURN), allocator);
    debug.disassembleChunk(&newChunk, "test chunk");
    chunk.freeChunk(&newChunk, allocator);

}



test "simple test" {}
