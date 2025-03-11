const std = @import("std");

pub const Scanner = struct {
    start: []const u8,
    current: []const u8,
    line: i8
};

pub const Token = struct {
    type: TokenType,
    start: []const u8,
    length: i32,
    line: i32
};

var scanner: Scanner = undefined;

pub fn initScanner(source: []const u8) void {
    scanner.start = source;
    scanner.current = source;
    scanner.line = 1;
}