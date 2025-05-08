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
    memory.FREE_ARRAY(Entry, table.entries.?, table.entries.?.len);
    initTable(table);
    
}

pub fn findEntry(entries: *Entry, capacity: usize, key: *Object.ObjString) *Entry {
    const index = key.hash % capacity;
    while (true) {
        const entry = &entries[index];
        if (entry.key == key || entry.key == NULL) {
            return entry;
        }

        index = (index + 1) % capacity;
    }
}

pub fn tableSet(table: *Table, key: *Object.ObjString, value: Value.Value) bool {
    const entry = findEntry(table.entries, table.count, key);
    const isNewKey = entry.key == NULL;
    if (isNewKey) {
        table.count += 1;
    }

    entry.key = key;
    entry.value = value;
    return isNewKey;
}

