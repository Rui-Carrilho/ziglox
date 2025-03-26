const std = @import("std");
const Scanner = @import("scanner.zig");
const Chunk = @import("chunk.zig");
const Value = @import("value.zig");


pub const Parser = struct {
    current: Scanner.Token,
    previous: Scanner.Token,
    hadError: bool,
    panicMode: bool
};

pub const Precedence = enum {
    PREC_NONE,
    PREC_ASSIGNMENT,     // =
    PREC_OR,             // or
    PREC_AND,            // and
    PREC_EQUALITY,       // == !=
    PREC_COMPARISON,     // < > <= >=
    PREC_TERM,           // + -
    PREC_FACTOR,         // * /
    PREC_UNARY,          // ! -
    PREC_CALL,           // . ()
    PREC_PRIMARY
};

var parser: Parser = undefined;
var compilingChunk: *Chunk.Chunk = undefined;

pub fn currentChunk() *Chunk.Chunk {
    return compilingChunk;
}

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
        stderr.print(" at '{s}'", .{token.name[0..token.name.len]}) catch {};
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

pub fn compile(source: []const u8, chunk: *Chunk.Chunk, allocator: *std.mem.Allocator) !bool {
    Scanner.initScanner(source);
    compilingChunk = chunk;

    parser.hadError = false;
    parser.panicMode = false;

    advance();
    expression();
    consume(Scanner.TokenType.TOKEN_EOF, "Expected end of expression.");
    _ = try endCompiler(allocator);
    return !parser.hadError;
}

pub fn advance() void {
    parser.previous = parser.current;

    while (true) {
        parser.current = Scanner.scanToken();
        if(parser.current.type != Scanner.TokenType.TOKEN_ERROR) break;

        errorAtCurrent(parser.current.name);
    }
}

pub fn consume(tokenType: Scanner.TokenType, message: []const u8) void {
    //this function advances the thing until we get to the token specified in tokenType. if it doesn't find it, it spits out the message
    if(parser.current.type == tokenType) {
        advance();
        return;
    }

    errorAtCurrent(message);
}

pub fn emitByte(byte: u8, allocator: *std.mem.Allocator) !void {
    try Chunk.writeChunk(currentChunk(), byte, parser.previous.line, allocator);
}

pub fn emitBytes(byte1: u8, byte2: u8, allocator: *std.mem.Allocator) void {
    emitByte(byte1, allocator);
    emitByte(byte2, allocator);
}

pub fn emitReturn(allocator: *std.mem.Allocator) !void {
    try emitByte(@intFromEnum(Chunk.OpCode.OP_RETURN), allocator);
}

pub fn makeConstant(value: Value.Value) u8 {
    const constant = Chunk.addConstant(currentChunk(), value);
    if (constant > std.math.maxInt(u8)) {
        errorBase("too many constants in one chunk.");
        return 0;
    }

    return @as(u8, constant);
}

pub fn emitConstant(value: Value.Value, allocator: *std.mem.Allocator) void {
    emitBytes(Chunk.OpCode.OP_CONSTANT, makeConstant(value), allocator);
}

pub fn endCompiler(allocator: *std.mem.Allocator) !void {
    try emitReturn(allocator);
}

pub fn grouping() void {
    expression();
    consume(Scanner.TokenType.TOKEN_RIGHT_PAREN, "Expect ')' after expression.");
}

pub fn number() void {
    const value = std.fmt.parseFloat(Value.Value, parser.previous.name[0..parser.previous.name.len]) catch |err| {
        std.debug.print("Error parsing float: {}\n", .{err});
        return;
    };
    emitConstant(value);
}

pub fn unary(allocator: *std.mem.Allocator) void {
    const operatorType = parser.previous.type;

    //compile the operand
    parsePrecedence(Precedence.PREC_UNARY);

    //emit the operator instruction
    switch (operatorType) {
        Scanner.TokenType.TOKEN_MINUS => emitByte(Chunk.OpCode.OP_NEGATE, allocator),
        else => unreachable
    }
}

pub fn parsePrecedence(precedence: Precedence) void {

}

pub fn expression() void {
    parsePrecedence(Precedence.PREC_ASSIGNMENT);
}