const std = @import("std");
const Scanner = @import("scanner.zig");

pub fn compile(source: []const u8) void {
    Scanner.initScanner(source);
    var line: i32 = -1;
    while (true) {
        const token = scanToken();
        if (token.line != line) {
            std.debug.print("{d:4}", .{token.line});
            line = token.line;
        } else {
            std.debug.print("   | ", .{});
        }
        std.debug.print("{d:2} '{s}'\n", .{@intFromEnum(token.type), token.start[0..token.length]});

        if (token.type == .TOKEN_EOF) break;
    }
}