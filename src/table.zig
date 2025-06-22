const std = @import("std");
const Object = @import("object.zig");
const Value = @import("value.zig");
const memory = @import("memory.zig");
const Allocator = @import("allocator.zig");

const TABLE_MAX_LOAD = 0.75;

pub const Table = struct { count: usize, entries: ?[]Entry };

pub const Entry = struct { key: ?*Object.Obj, value: ?Value.Value };

pub fn initTable(table: *Table) void {
    table.count = 0;
    table.entries = null;
}

pub fn freeTable(table: *Table) !void {
    try memory.FREE_ARRAY(Entry, table.entries.?, table.entries.?.len);
    initTable(table);
}

pub fn findEntry(entries: []Entry, key: *Object.Obj) *Entry {
    const keyString = Object.OBJ_AS_STRING(key.*);
    var index = keyString.hash % entries.len;
    var tombstone: ?*Entry = null;

    while (true) {
        var entry = entries[index];
        if (entry.key == null) {
            if (Value.IS_NIL(entry.value.?)) {
                return if(tombstone != null) tombstone.? else &entry; 
            } else {
                if (tombstone == null) tombstone = &entry;
            }
        } else if (entry.key.? == key) {
            return &entry;
        }

        index = (index + 1) % entries.len;
    }
}

pub fn adjustCapacity(table: *Table, capacity: usize) !void {
    var entries = try memory.ALLOCATE(Entry, capacity);
    var i: usize = 0;

    while (i < capacity) : (i = i + 1) {
        entries[i].key = null;
        entries[i].value = null;
    }

    table.count = 0;

    i = 0;
    while (i < capacity) : (i = i + 1) {
        const entry = table.entries.?[i];
        if (entry.key == null) continue;

        var dest = findEntry(entries, entry.key.?);
        dest.key = entry.key;
        dest.value = entry.value;
        table.count += 1;
    }

    try memory.FREE_ARRAY(Entry, table.entries.?, table.entries.?.len);

    table.entries = entries;
    table.entries.?.len = capacity;
}

pub fn tableSet(table: *Table, key: *Object.Obj, value: Value.Value) !bool {
    if (table.count + 1 > @as(usize, @intFromFloat(@as(f64, @floatFromInt(table.entries.?.len)) * TABLE_MAX_LOAD))) {
        const capacity = memory.GROW_CAPACITY(table.count);
        try adjustCapacity(table, capacity);
    }

    const entry = findEntry(table.entries.?, key);
    const isNewKey = entry.key == null;
    if (isNewKey and Value.IS_NIL(entry.value.?)) {
        table.count += 1;
    }

    entry.key = key;
    entry.value = value;
    return isNewKey;
}

pub fn tableDelete(table: *Table, key: *Object.ObjString) bool {
    if (table.count == 0) return false;

    const entry = findEntry(table.entries, key);
    if (entry.key.? == null) return false;

    entry.key = null;
    entry.value = Value.BOOL_VAL(true);
    return true;
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

pub fn tableFindString(table: *Table, chars: []const u8, hash: u32) ?*Object.ObjString {
    if (table.count == 0) return null;

    const index = hash % table.entries.?.len;

    while (true) {
        const entry = &table.entries.?[index];
        if (entry.key == null) {
            if (Value.IS_NIL(entry.value.?)) return null;
        } else if (entry.key.?.node.string.hash == hash and entry.key.?.node.string.chars == chars) {
            return entry.key.?;
        }

        index = (index + 1) % table.entries.?.len; 
    }
}

pub fn tableGet(table: *Table, key: *Object.ObjString, value: *Value.Value) bool {
    if (table.count == 0) return false;

    const entry = findEntry(table.entries, key);
    if (entry.key.? == null) return false;

    value.* = entry.value;
    return true;
}
