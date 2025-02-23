const std = @import("std");

pub fn GROW_CAPACITY(capacity: usize) usize {
    return if (capacity < 8) 8 else capacity * 2;
}

pub fn FREE_ARRAY(comptime T: type, allocator: *std.mem.Allocator, pointer: []T, old_count: usize) !void {
    _ = try reallocate(T, allocator, pointer, old_count * @sizeOf(T), 0);
}

/// Type-safe array growth function
pub fn growArray(comptime T: type, allocator: *std.mem.Allocator, pointer: []T, new_count: usize) ![]T {
    const old_count = pointer.len;
    const old_size = old_count * @sizeOf(T);
    const new_size = new_count * @sizeOf(T);

    // Use reallocate function for memory management
    const result = try reallocate(
        T,
        allocator,
        pointer,
        old_size,
        new_size,
    );

    if (new_size == 0) {
        return &[_]T{};
    }

    return @as([*]T, @ptrCast(result.?))[0..new_count];
}

pub fn initArray(comptime T: type) []T {
    return &[_]T{};
}

pub fn reallocate(comptime T: type, allocator: *std.mem.Allocator, pointer: []T, oldSize: usize, newSize: usize) !?[]T {
    // If the new size is zero, free the memory and return null.
    const old_count = oldSize / @sizeOf(T);
    const new_count = newSize / @sizeOf(T);

    if (newSize == 0) {
        const slice = pointer[0..old_count];
        allocator.free(slice);
        return null;
    }
    // Otherwise, use the allocator's realloc function.
    // This call will automatically compute the correct byte sizes.
    //std.debug.print("pointer: {*},\nnewSize: {d}", .{ pointer, newSize });
    const old_slice = pointer[0..old_count];
    const result = try allocator.realloc(old_slice, new_count);
    return result;
}
