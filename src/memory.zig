const std = @import("std");
const Allocator = @import("allocator.zig");
const VM = @import("vm.zig");
const Object = @import("object.zig");
const Chunk = @import("chunk.zig");

pub fn FREE(comptime T: type, pointer: []T) !void {
    _ = try reallocate(T, pointer, 1, 0);
}

pub fn GROW_CAPACITY(capacity: usize) usize {
    return if (capacity < 8) 8 else capacity * 2;
}

pub fn FREE_ARRAY(comptime T: type, pointer: []T, old_count: usize) !void {
    _ = try reallocate(T, pointer, old_count * @sizeOf(T), 0);
}

pub fn ALLOCATE(comptime T: type, count: usize) ![]T {
    return (try reallocate(T, null, 0, count)).?;
}

/// Type-safe array growth function
pub fn growArray(comptime T: type, pointer: []T, new_count: usize) ![]T {
    const old_count = pointer.len;
    const old_size = old_count * @sizeOf(T);
    const new_size = new_count * @sizeOf(T);

    // Use reallocate function for memory management
    const result = try reallocate(
        T,
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

pub fn reallocate(comptime T: type, pointer: ?[]T, oldSize: usize, newSize: usize) !?[]T {
    // If the new size is zero, free the memory and return null.
    const old_count = oldSize / @sizeOf(T);
    const new_count = newSize / @sizeOf(T);

    if (pointer == null) {
        return try Allocator.allocator.alloc(T, newSize);
    }

    if (newSize == 0) {
        const slice = pointer.?[0..old_count];
        Allocator.allocator.free(slice);
        return null;
    }
    // Otherwise, use the allocator's realloc function.
    // This call will automatically compute the correct byte sizes.
    //std.debug.print("pointer: {*},\nnewSize: {d}", .{ pointer, newSize });
    const old_slice = pointer.?[0..old_count];
    const result = try Allocator.allocator.realloc(old_slice, new_count);
    return result;
}

pub fn freeObject(object: *Object.Obj) !void {
    switch (object.node) {
        Object.ObjType.string => {
            const string = object.node.string;
            try FREE_ARRAY(u8, string.chars, string.chars.len);
            var objectSlice: []Object.Obj = undefined;
            objectSlice.ptr = @ptrCast(object);
            objectSlice.len = 1;
            try FREE(Object.Obj, objectSlice);
        },
        Object.ObjType.function => {
            const function = object.node.function;
            Chunk.freeChunk(@constCast(&function.chunk));
            var objectSlice: []Object.ObjFunction = undefined;
            objectSlice.ptr = @ptrCast(object);
            objectSlice.len = 1;
            try FREE(Object.ObjFunction, objectSlice);
        },
        Object.ObjType.uninitialized => std.debug.panic("lmao we hit an uninitialized in memory.zig", .{}),
    }
}

pub fn freeObjects() !void {
    var object = VM.vm.objects;
    while (object != null) {
        const next = object.?.next;
        try freeObject(object.?);
        object = next;
    }
}
