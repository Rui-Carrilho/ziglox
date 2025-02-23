const std = @import("std");
const Chunk = @import("chunk.zig");

pub const VM = struct {
    chunk: *Chunk.Chunk
};;