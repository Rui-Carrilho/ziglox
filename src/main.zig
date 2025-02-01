const std = @import("std");
const common = @import("common.zig");
const memory = @import("memory.zig");


pub fn main() void {
    // Allocate memory
    const allocator = common.mem.Allocator.init(.heap.page_allocator);
    const pointer = allocator.alloc(u8, 8);

    // Grow the array
    const newPointer = memory.growArray(u8, allocator, pointer, 16);

    // Free the memory
    memory.freeArray(u8, allocator, newPointer, 16);
}



test "simple test" {}
