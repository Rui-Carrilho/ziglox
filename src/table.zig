const std = @import("std");
const Object = @import("object.zig");
const Value = @import("value.zig");
const memory = @import("memory.zig");
const Allocator = @import("allocator.zig");

const TABLE_MAX_LOAD = 0.75;

pub const Table = struct { count: usize, entries: ?[]Entry };

pub const Entry = struct { key: ?*Object.ObjString, value: Value.Value };

pub fn initTable(table: *Table) void {
    table.count = 0;
    table.entries = null;
}

pub fn freeTable(table: *Table) void {
    memory.FREE_ARRAY(Entry, table.entries.?, table.entries.?.len);
    initTable(table);
}

pub fn findEntry(entries: []Entry, key: *Object.ObjString) *Entry {
    const index = key.hash % entries.len;
    while (true) {
        const entry = entries[index];
        if (entry.key == key or entry.key == null) {
            return entry;
        }

        index = (index + 1) % entries.len;
    }
}

pub fn adjustCapacity(table: *Table, capacity: usize) void {
    var entries = memory.ALLOCATE(Entry, capacity);
    var i: usize = 0;

    while (i < capacity) : (i = i + 1) {
        entries[i].key = null;
        entries[i].value = null;
    }

    i = 0;
    while (i < capacity) : (i = i + 1) {
        const entry = table.entries[i];
        if (entry.key == null) continue;

        var dest = findEntry(entries, entry.key);
        dest.key = entry.key;
        dest.value = entry.value;
    }

    memory.FREE_ARRAY(Entry, table.entries.?, table.entries.?.len);

    table.entries = entries;
    table.entries.?.len = capacity;
}

pub fn tableSet(table: *Table, key: *Object.ObjString, value: Value.Value) bool {
    if (table.count + 1 > table.entries.?.len * TABLE_MAX_LOAD) {
        const capacity = memory.GROW_CAPACITY(table.count);
        adjustCapacity(table, capacity);
    }

    const entry = findEntry(table.entries.?, table.count, key);
    const isNewKey = entry.key == NULL;
    if (isNewKey) {
        table.count += 1;
    }

    entry.key = key;
    entry.value = value;
    return isNewKey;
}

pub fn tableAddAll(from: *Table, to: *Table) void {
    var i: usize = 0;

    while (i < from.entries.?.len) : (i = i + 1) {
        const entry = from.entries[i];
        if (entry.key != null) {
            tableSet(to, entry.key, entry.value);
        }
    }
}

pub fn tableGet(table: *Table, key: *Object.ObjString, value: *Value.Value) bool {
    if (table.count == 0) return false;

    const entry = findEntry(table.entries, key);
    if (entry.key.? == null) return false;

    value.* = entry.value;
    return true;
}
