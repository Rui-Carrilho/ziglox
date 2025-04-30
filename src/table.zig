const std = @import("std");
const Object = @import("object.zig");
const Value = @import("value.zig");
const memory = @import("memory.zig");
const Allocator = @import("allocator.zig");


pub const Table = struct {
    count: usize,
    entries: ?[]Entry
};

pub const Entry = struct {
    key: *Object.ObjString,
    value: Value.Value
};

pub fn initTable(table: *Table) void {
    table.count = 0;
    table.entries = null;
}

pub fn freeTable(table: *Table) void {
    memory.FREE_ARRAY(Entry, allocator: *std.mem.Allocator, pointer: []T, old_count: usize)
}