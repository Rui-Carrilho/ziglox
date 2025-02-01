const common: type = @import("common.zig");

pub fn GROW_CAPACITY(capacity: u8) u8 {
    return if (capacity < 8) 8 else capacity * 2;
}

pub fn FREE_ARRAY(comptime T: type, allocator: common.mem.Allocator, pointer: ?[]T, old_count: usize) void {
    _ = reallocate(allocator, if (pointer) |p| @ptrCast(p.ptr) else null, old_count * @sizeOf(T), 0);
}

/// Type-safe array growth function
pub fn growArray(
    comptime T: type,
    allocator: common.mem.Allocator,
    pointer: ?[]T,
    new_count: usize,
) common.MemoryError![]T {
    const old_count = if (pointer) |p| p.len else 0;
    const old_size = old_count * @sizeOf(T);
    const new_size = new_count * @sizeOf(T);

    // Use reallocate function for memory management
    const result = try reallocate(
        allocator,
        if (pointer) |p| @ptrCast(p.ptr) else null,
        old_size,
        new_size,
    );

    if (new_size == 0) {
        return &[_]T{};
    }

    return @as([*]T, @ptrCast(result.?))[0..new_count];
}

/// General purpose reallocation function
pub fn reallocate(
    allocator: common.mem.Allocator,
    pointer: ?[*]u8,
    old_size: usize,
    new_size: usize,
) common.MemoryError!?[*]u8 {
    // If new size is 0, free the memory
    if (new_size == 0) {
        if (pointer) |ptr| {
            allocator.free(ptr[0..old_size]);
        }
        return null;
    }

    // Reallocate memory
    if (pointer) |ptr| {
        const new_memory = allocator.realloc(ptr[0..old_size], new_size) catch |err| {
            switch (err) {
                error.OutOfMemory => {
                    // Similar to the C version's exit(1), but we can handle it more gracefully
                    common.debug.print("Fatal: Out of memory\n", .{});
                    common.process.exit(1);
                },
                else => return err,
            }
        };
        return @ptrCast(new_memory);
    } else {
        const new_memory = allocator.alloc(u8, new_size) catch |err| {
            switch (err) {
                error.OutOfMemory => {
                    common.debug.print("Fatal: Out of memory\n", .{});
                    common.process.exit(1);
                },
                else => return err,
            }
        };
        return @ptrCast(new_memory);
    }
}
