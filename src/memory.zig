const std = @import("std");

pub fn GROW_CAPACITY(capacity: i8) i8 {
    return if (capacity < 8) 8 else capacity * 2;
}

pub fn FREE_ARRAY(comptime T: type, allocator: std.mem.Allocator, pointer: ?[]T, old_count: usize) void {
    _ = reallocate(allocator, if (pointer) |p| @ptrCast(p.ptr) else null, old_count * @sizeOf(T), 0);
}

/// Type-safe array growth function
pub fn growArray(comptime T: type, allocator: std.mem.Allocator, pointer: ?[]T, new_count: usize) std.MemoryError![]T {
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

pub fn reallocate(allocator: *std.mem.Allocator, pointer: ?*u8, oldSize: usize, newSize: usize) !?*u8 {
    // If the new size is zero, free the memory and return null.
    if (newSize == 0) {
        if (pointer) |ptr| {
            allocator.free(ptr);
        }
        return null;
    }
    // Otherwise, use the allocator's realloc function.
    // This call will automatically compute the correct byte sizes.
    const result = try allocator.realloc(u8, pointer, oldSize, newSize);
    return result;
}
