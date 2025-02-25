const std = @import("std");
const memory = @import("memory.zig");
const chunk = @import("chunk.zig");
const debug = @import("debug.zig");
const VM = @import("vm.zig");

pub fn main() !void {
    // Allocate memory
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer gpa.deinit();

    VM.initVM();

    var newChunk: chunk.Chunk = undefined;
    chunk.initChunk(&newChunk);
    const constant = try chunk.addConstant(&newChunk, 1.2 , &allocator);
    try chunk.writeChunk(&newChunk, @intFromEnum(chunk.OpCode.OP_CONSTANT), 123, &allocator);
    try chunk.writeChunk(&newChunk, @intCast(constant), 123, &allocator);
    try chunk.writeChunk(&newChunk, @intFromEnum(chunk.OpCode.OP_RETURN), 123, &allocator);
    
    debug.disassembleChunk(&newChunk, "test chunk");
    
    VM.freeVM();
    chunk.freeChunk(&newChunk, &allocator);
}

test "simple test" {

}