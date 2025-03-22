const std = @import("std");
const Scanner = @import("scanner.zig");
const Chunk = @import("chunk.zig");


pub const Parser = struct {
    current: Scanner.Token,
    previous: Scanner.Token,
    hadError: bool,
    panicMode: bool
};

var parser: Parser = undefined;

pub fn errorAt(token: *Scanner.Token, message: []const u8) void {
    if(parser.panicMode) return;
    parser.panicMode = true;
    const stderr = std.io.getStdErr().writer();
    
    // Print error line information
    stderr.print("[line {d}] Error", .{token.line}) catch {};

    if(token.type == Scanner.TokenType.TOKEN_EOF) {
        stderr.print(" at end", .{}) catch {};
    } else if (token.type == Scanner.TokenType.TOKEN_ERROR) {
        //nothing
    } else {
        stderr.print(" at '{s}'", .{token.name[0..token.length]}) catch {};
    }

    // Print the error message
    stderr.print(": {s}\n", .{message}) catch {};

    parser.hadError = true;
}

pub fn errorBase(message: []const u8) void {
    errorAt(&parser.previous, message);
}

pub fn errorAtCurrent(message: []const u8) void {
    errorAt(&parser.current, message);
}

pub fn compile(source: []const u8, chunk: *Chunk.Chunk) void {
    Scanner.initScanner(source);

    parser.hadError = false;
    parser.panicMode = false;

    advance();
    expression();
    consume(Scanner.TokenType.TOKEN_EOF, "Expected end of expression.");
    return !parser.hadError;
}

pub fn advance() void {
    parser.previous = parser.current;

    while (true) {
        parser.current = Scanner.scanToken();
        if(parser.current.type != Scanner.TokenType.TOKEN_ERROR) break;

        errorAtCurrent(parser.current.name[0]);
    }
}

pub fn consume(tokenType: Scanner.TokenType, message: [*:0]const u8) void {
    if(parser.current.type == tokenType) {
        advance();
        return;
    }

    errorAtCurrent(message);
}

pub fn expression() void {

}