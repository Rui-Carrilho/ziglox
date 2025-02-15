const std = @import("std");
const memory = @import("memory.zig");

// OpCode enum to represent different bytecode instructions
pub const OpCode = enum(u8) {
    OP_RETURN,
    OP_CONSTANT,
    OP_ADD,
    OP_SUBTRACT,
    OP_MULTIPLY,
    OP_DIVIDE,
};

pub const Chunk = struct {
    code: *u8,
    count: i8,
    capacity: i8
};

pub fn initChunk(chunk: *Chunk) void {
    chunk.code = undefined;
    chunk.count = 0;
    chunk.capacity = 0;
}

pub fn writeChunk(chunk: *Chunk, byte: u8, allocator: std.mem.Allocator) void {
    if(chunk.capacity < chunk.count + 1) {
        const oldCapacity = chunk.capacity;
        chunk.capacity = memory.GROW_CAPACITY(oldCapacity);
        chunk.code = memory.growArray(u8, allocator, *chunk.code, chunk.capacity);
    }

    chunk.code[chunk.count] = byte;
    chunk.count += 1;
}

pub fn freeChunk(chunk: *Chunk, allocator: std.mem.Allocator) void {
    memory.FREE_ARRAY(u8, allocator, chunk.code, chunk.capacity);
    initChunk(chunk);
}

// // Value type to store constants
// pub const Value = f64;

// // Chunk structure to hold bytecode and constants
// pub const Chunk = struct {
//     code: std.ArrayList(u8),
//     constants: std.ArrayList(Value),
//     lines: std.ArrayList(usize),
//     allocator: std.mem.Allocator,

//     // Initialize a new chunk
//     pub fn init(allocator: std.mem.Allocator) Chunk {
//         return Chunk{
//             .code = std.ArrayList(u8).init(allocator),
//             .constants = std.ArrayList(Value).init(allocator),
//             .lines = std.ArrayList(usize).init(allocator),
//             .allocator = allocator,
//         };
//     }

//     // Clean up resources
//     pub fn deinit(self: *Chunk) void {
//         self.code.deinit();
//         self.constants.deinit();
//         self.lines.deinit();
//     }

//     // Add a byte to the chunk
//     pub fn writeByte(self: *Chunk, byte: u8, line: usize) !void {
//         try self.code.append(byte);
//         try self.lines.append(line);
//     }

//     // Add a constant to the chunk and return its index
//     pub fn addConstant(self: *Chunk, value: Value) !usize {
//         try self.constants.append(value);
//         return self.constants.items.len - 1;
//     }

//     // Disassemble the entire chunk
//     pub fn disassemble(self: *const Chunk, name: []const u8) void {
//         std.debug.print("== {s} ==\n", .{name});

//         var offset: usize = 0;
//         while (offset < self.code.items.len) {
//             offset = self.disassembleInstruction(offset);
//         }
//     }

//     // Disassemble a single instruction
//     pub fn disassembleInstruction(self: *const Chunk, offset: usize) usize {
//         std.debug.print("{d:0>4} ", .{offset});

//         // Print line number
//         if (offset > 0 and self.lines.items[offset] == self.lines.items[offset - 1]) {
//             std.debug.print("   | ", .{});
//         } else {
//             std.debug.print("{d:>4} ", .{self.lines.items[offset]});
//         }

//         const instruction = @as(OpCode, @enumFromInt(self.code.items[offset]));
//         switch (instruction) {
//             .OP_RETURN => return simpleInstruction("OP_RETURN", offset),
//             .OP_CONSTANT => return self.constantInstruction("OP_CONSTANT", offset),
//             .OP_ADD => return simpleInstruction("OP_ADD", offset),
//             .OP_SUBTRACT => return simpleInstruction("OP_SUBTRACT", offset),
//             .OP_MULTIPLY => return simpleInstruction("OP_MULTIPLY", offset),
//             .OP_DIVIDE => return simpleInstruction("OP_DIVIDE", offset),
//         }
//     }

//     // Helper function to disassemble a constant instruction
//     fn constantInstruction(self: *const Chunk, name: []const u8, offset: usize) usize {
//         const constant = self.code.items[offset + 1];
//         std.debug.print("{s:<16} {d:>4} '", .{ name, constant });
//         std.debug.print("{d}", .{self.constants.items[constant]});
//         std.debug.print("'\n", .{});
//         return offset + 2;
//     }
// };

// // Helper function to disassemble a simple instruction
// fn simpleInstruction(name: []const u8, offset: usize) usize {
//     std.debug.print("{s}\n", .{name});
//     return offset + 1;
// }
