const std = @import("std");
const Scanner = @import("scanner.zig");
const Chunk = @import("chunk.zig");

pub const Parser = struct {
    current: Scanner.Token,
    previous: Scanner.Token,
};

var parser: Parser = undefined;

pub fn compile(source: []const u8, chunk: *Chunk.Chunk) void {
    Scanner.initScanner(source);
    advance();
    expression();
    consume(Scanner.TokenType.TOKEN_EOF, "Expected end of expression.");
}

pub fn advance() void {
    parser.previous = parser.current;

    while (true) {
        parser.current = Scanner.scanToken();
        if(parser.current.type != Scanner.TokenType.TOKEN_ERROR) break;

        errorAtCurrent(parser.current.name[0]);
    }
}

pub fn consume(type: Scanner.TokenType, message: [*:0]const u8) void {

}

pub fn expression() void {

}