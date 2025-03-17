const std = @import("std");
const Scanner = @import("scanner.zig");

pub fn compile(source: []const u8) void {
    Scanner.initScanner(source);
    std.debug.print("in compile - source: {d} (d) {s} (s)", .{source, source});
    var line: i32 = -1;
    while (true) {
        const token = Scanner.scanToken();
        if (token.line != line) {
            std.debug.print("{d:4}", .{token.line});
            line = token.line;
        } else {
            std.debug.print("   | ", .{});
        }
        var slice: []const u8 = undefined;
        slice.ptr = @ptrCast(token.start);
        slice.len = @intCast(token.length);
        std.debug.print("{d:2} '{s}'\n", .{@intFromEnum(token.type), slice});

        if (token.type == Scanner.TokenType.TOKEN_EOF) break;
    }
}