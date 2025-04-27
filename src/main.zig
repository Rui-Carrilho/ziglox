const std = @import("std");
const memory = @import("memory.zig");
const chunk = @import("chunk.zig");
const debug = @import("debug.zig");
const VM = @import("vm.zig");
const Compiler = @import("compiler.zig");
const Allocator = @import("allocator.zig");

pub fn main() !void {
    // Allocate memory
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    Allocator.allocator = &allocator;
    //defer _ = gpa.deinit();

    VM.initVM();

    var args = try std.process.argsWithAllocator(allocator);

    // Skip the program name
    _ = args.next();

    // Count remaining arguments
    const arg = args.next();

    if (arg == null) {
        try repl(&allocator);
    } else if (args.next() == null) {
        try runFile(arg.?, &allocator);
    } else {
        std.debug.print("Usage: clox [path]\n", .{});
        std.process.exit(64);
    }

    try VM.freeVM();
}

pub fn repl(allocator: *std.mem.Allocator) !void {
    var line: [1024]u8 = undefined;
    var line_terminated: [1024]u8 = undefined;

    while (true) {
        std.debug.print("> ", .{});

        const input = std.io.getStdIn().reader().readUntilDelimiterOrEof(&line, '\n') catch |err| {
            std.debug.print("we got an error getting the input\n", .{});
            return err;
        };

        if (input == null) {
            std.debug.print("null input\n", .{});
            break;
        }

        std.mem.copyForwards(u8, &line_terminated, input.?);

        line_terminated[input.?.len] = 0;

        const final_input = line_terminated[0..input.?.len :0];

        _ = try VM.interpret(final_input, allocator);
    }
}

pub fn runFile(path: []const u8, allocator: *std.mem.Allocator) !void {
    const source = readFile(path, allocator);
    defer allocator.free(source);

    const result = try VM.interpret(source, allocator);

    if (result == VM.InterpretResult.INTERPRET_COMPILE_ERROR) std.process.exit(65);
    if (result == VM.InterpretResult.INTERPRET_RUNTIME_ERROR) std.process.exit(70);
}

pub fn readFile(path: []const u8, allocator: *std.mem.Allocator) []u8 {
    const file = std.fs.cwd().openFile(path, .{}) catch {
        std.debug.print("Could not open file \"{s}\".\n", .{path});
        std.process.exit(74);
    };
    defer file.close();

    const fileSize = file.getEndPos() catch {
        std.debug.print("Not enough memory to read \"{s}\".\n", .{path});
        std.process.exit(74);
    };

    const buffer = allocator.alloc(u8, fileSize) catch {
        std.debug.print("Not enough memory to read \"{s}\".\n", .{path});
        std.process.exit(74);
    };

    const bytesRead = file.readAll(buffer) catch {
        std.debug.print("Could not read file \"{s}\".\n", .{path});
        allocator.free(buffer);
        std.process.exit(74);
    };

    if (bytesRead < fileSize) {
        std.debug.print("Could not read file \"{s}\".\n", .{path});
        allocator.free(buffer);
        std.process.exit(74);
    }

    return buffer;
}

test "simple test" {}
