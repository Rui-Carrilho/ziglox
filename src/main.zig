const std = @import("std");
const memory = @import("memory.zig");
const chunk = @import("chunk.zig");
const debug = @import("debug.zig");
const VM = @import("vm.zig");

pub fn main() !void {
    // Allocate memory
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    //defer _ = gpa.deinit();

    const args = std.os.argv;
    const argc = args.len;

    VM.initVM();

    if (argc == 1) {
        try repl();
    } else if (argc == 2) {
        try runFile(args[1]);
    } else {
        std.debug.print("Usage: clox [path]\n", .{});
        std.process.exit(64);
    }

    var newChunk: chunk.Chunk = undefined;
    chunk.initChunk(&newChunk);
    var constant: usize = try chunk.addConstant(&newChunk, 3, &allocator);
    try chunk.writeChunk(&newChunk, @intFromEnum(chunk.OpCode.OP_CONSTANT), 123, &allocator);
    try chunk.writeChunk(&newChunk, @intCast(constant), 123, &allocator);

    constant = try chunk.addConstant(&newChunk, 2, &allocator);
    try chunk.writeChunk(&newChunk, @intFromEnum(chunk.OpCode.OP_CONSTANT), 123, &allocator);
    try chunk.writeChunk(&newChunk, @intCast(constant), 123, &allocator);

    try chunk.writeChunk(&newChunk, @intFromEnum(chunk.OpCode.OP_SUBTRACT), 123, &allocator);

    constant = try chunk.addConstant(&newChunk, 1, &allocator);
    try chunk.writeChunk(&newChunk, @intFromEnum(chunk.OpCode.OP_CONSTANT), 123, &allocator);
    try chunk.writeChunk(&newChunk, @intCast(constant), 123, &allocator);

    try chunk.writeChunk(&newChunk, @intFromEnum(chunk.OpCode.OP_SUBTRACT), 123, &allocator);

    //try chunk.writeChunk(&newChunk, @intFromEnum(chunk.OpCode.OP_NEGATE), 123, &allocator);
    try chunk.writeChunk(&newChunk, @intFromEnum(chunk.OpCode.OP_RETURN), 123, &allocator);

    debug.disassembleChunk(&newChunk, "test chunk");
    _ = VM.interpret(&newChunk);

    VM.freeVM();
    chunk.freeChunk(&newChunk, &allocator);
}

pub fn repl() !void {
    var line: [1024]u8 = undefined;
    
    while (true) {
        std.debug.print("> ", .{});

        const input = std.io.getStdIn().reader().readUntilDelimiterOrEof(
            &line,
            '\n'
        ) catch |err| {
            std.debug.print("\n", .{});
            return err;
        };

        if (input == null) {
            std.debug.print("\n", .{});
            break;
        }

        try interpret(input.?);
    }
}

test "simple test" {}
