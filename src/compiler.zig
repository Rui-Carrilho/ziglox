const std = @import("std");
const Scanner = @import("scanner.zig");
const Chunk = @import("chunk.zig");
const Value = @import("value.zig");
const Debug = @import("debug.zig");
const Allocator = @import("allocator.zig");

pub const Parser = struct { current: Scanner.Token, previous: Scanner.Token, hadError: bool, panicMode: bool };

pub const Precedence = enum {
    PREC_NONE,
    PREC_ASSIGNMENT, // =
    PREC_OR, // or
    PREC_AND, // and
    PREC_EQUALITY, // == !=
    PREC_COMPARISON, // < > <= >=
    PREC_TERM, // + -
    PREC_FACTOR, // * /
    PREC_UNARY, // ! -
    PREC_CALL, // . ()
    PREC_PRIMARY,
};

const ParseFn = ?*const fn () anyerror!void;

pub const TokenType = enum(u8) {
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,
    COMMA,
    DOT,
    MINUS,
    PLUS,
    SEMICOLON,
    SLASH,
    STAR,
    BANG,
    BANG_EQUAL,
    EQUAL,
    EQUAL_EQUAL,
    GREATER,
    GREATER_EQUAL,
    LESS,
    LESS_EQUAL,
    IDENTIFIER,
    STRING,
    NUMBER,
    AND,
    CLASS,
    ELSE,
    FALSE,
    FOR,
    FUN,
    IF,
    NIL,
    OR,
    PRINT,
    RETURN,
    SUPER,
    THIS,
    TRUE,
    VAR,
    WHILE,
    ERROR,
    EOF,
};

pub const ParseRule = struct { 
    prefix: ParseFn, 
    infix: ParseFn, 
    precedence: Precedence 
};

var parser: Parser = undefined;
var compilingChunk: *Chunk.Chunk = undefined;

const debugPrintCode = true;

pub fn currentChunk() *Chunk.Chunk {
    return compilingChunk;
}

pub fn errorAt(token: *Scanner.Token, message: []const u8) void {
    if (parser.panicMode) return;
    parser.panicMode = true;
    const stderr = std.io.getStdErr().writer();

    // Print error line information
    stderr.print("[line {d}] Error", .{token.line}) catch {};

    if (token.type == Scanner.TokenType.TOKEN_EOF) {
        stderr.print(" at end", .{}) catch {};
    } else if (token.type == Scanner.TokenType.TOKEN_ERROR) {
        //nothing
    } else {
        stderr.print(" at '{s}'", .{token.name}) catch {};
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
    try expression();
    consume(Scanner.TokenType.TOKEN_EOF, "Expected end of expression.");
    _ = try endCompiler(allocator);
    return !parser.hadError;
}

pub fn advance() void {
    parser.previous = parser.current;

    while (true) {
        parser.current = Scanner.scanToken();
        if (parser.current.type != Scanner.TokenType.TOKEN_ERROR) break;

        errorAtCurrent(parser.current.name);
    }
}

pub fn consume(tokenType: Scanner.TokenType, message: []const u8) void {
    //this function advances the thing until we get to the token specified in tokenType. if it doesn't find it, it spits out the message
    if (parser.current.type == tokenType) {
        advance();
        return;
    }

    errorAtCurrent(message);
}

pub fn emitByte(byte: u8, allocator: *std.mem.Allocator) !void {
    try Chunk.writeChunk(currentChunk(), byte, parser.previous.line, allocator);
}

pub fn emitBytes(byte1: u8, byte2: u8, allocator: *std.mem.Allocator) !void {
    try emitByte(byte1, allocator);
    try emitByte(byte2, allocator);
}

pub fn emitReturn(allocator: *std.mem.Allocator) !void {
    try emitByte(@intFromEnum(Chunk.OpCode.OP_RETURN), allocator);
}

pub fn makeConstant(value: Value.Value) !u8 {
    const constant = try Chunk.addConstant(currentChunk(), value, Allocator.allocator);
    if (constant > @as(usize, std.math.maxInt(u8))) {
        errorBase("too many constants in one chunk.");
        return 0;
    }

    return @intCast(constant);
}

pub fn emitConstant(value: Value.Value, allocator: *std.mem.Allocator) !void {
    const newConstant = try makeConstant(value);
    try emitBytes(@intFromEnum(Chunk.OpCode.OP_CONSTANT), newConstant, allocator);
}

pub fn endCompiler(allocator: *std.mem.Allocator) !void {
    try emitReturn(allocator);

    if (debugPrintCode) {
        if (!parser.hadError) {
            Debug.disassembleChunk(currentChunk(), "code");
        }
    }
}

pub fn binary() !void {
    const operatorType = parser.previous.type;
    const rule = getRule(operatorType);
    try parsePrecedence(@enumFromInt(@intFromEnum(rule.precedence) + 1));

    try switch (operatorType) {
        Scanner.TokenType.TOKEN_PLUS => emitByte(@intFromEnum(Chunk.OpCode.OP_ADD), Allocator.allocator),
        Scanner.TokenType.TOKEN_MINUS => emitByte(@intFromEnum(Chunk.OpCode.OP_SUBTRACT), Allocator.allocator),
        Scanner.TokenType.TOKEN_STAR => emitByte(@intFromEnum(Chunk.OpCode.OP_MULTIPLY), Allocator.allocator),
        Scanner.TokenType.TOKEN_SLASH => emitByte(@intFromEnum(Chunk.OpCode.OP_DIVIDE), Allocator.allocator),
        else => unreachable,
    };
}

pub fn literal() void {
    switch (parser.previous.type) {
        Scanner.TokenType.TOKEN_FALSE => emitByte(@intFromEnum(Chunk.OpCode.OP_FALSE), Allocator.allocator),
        Scanner.TokenType.TOKEN_NIL => emitByte(@intFromEnum(Chunk.OpCode.OP_NIL), Allocator.allocator),
        Scanner.TokenType.TOKEN_TRUE => emitByte(@intFromEnum(Chunk.OpCode.OP_TRUE), Allocator.allocator),
        else => return
    }
}

pub fn grouping() !void {
    try expression();
    consume(Scanner.TokenType.TOKEN_RIGHT_PAREN, "Expect ')' after expression.");
}

pub fn number() !void {
    const value = std.fmt.parseFloat(f64, parser.previous.name) catch |err| {
        std.debug.print("Error parsing float: {}\n", .{err});
        try emitConstant(Value.NUMBER_VAL(0), Allocator.allocator);
        return;
    };
    try emitConstant(Value.NUMBER_VAL(value), Allocator.allocator);
}

pub fn unary() !void {
    const operatorType = parser.previous.type;

    //compile the operand
    try parsePrecedence(Precedence.PREC_UNARY);

    //emit the operator instruction
    try switch (operatorType) {
        Scanner.TokenType.TOKEN_MINUS => emitByte(@intFromEnum(Chunk.OpCode.OP_NEGATE), Allocator.allocator),
        else => unreachable,
    };
}

pub const rules = [_]ParseRule{
    .{ .prefix = grouping, .infix = null, .precedence = Precedence.PREC_NONE }, // LEFT_PAREN
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // RIGHT_PAREN
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // LEFT_BRACE
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // RIGHT_BRACE
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // COMMA
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // DOT
    .{ .prefix = unary, .infix = binary, .precedence = Precedence.PREC_TERM }, // MINUS
    .{ .prefix = null, .infix = binary, .precedence = Precedence.PREC_TERM }, // PLUS
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // SEMICOLON
    .{ .prefix = null, .infix = binary, .precedence = Precedence.PREC_FACTOR }, // SLASH
    .{ .prefix = null, .infix = binary, .precedence = Precedence.PREC_FACTOR }, // STAR
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // BANG
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // BANG_EQUAL
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // EQUAL
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // EQUAL_EQUAL
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // GREATER
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // GREATER_EQUAL
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // LESS
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // LESS_EQUAL
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // IDENTIFIER
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // STRING
    .{ .prefix = number, .infix = null, .precedence = Precedence.PREC_NONE }, // NUMBER
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // AND
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // CLASS
    .{ .prefix = literal, .infix = null, .precedence = Precedence.PREC_NONE }, // ELSE
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // FALSE
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // FOR
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // FUN
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // IF
    .{ .prefix = literal, .infix = null, .precedence = Precedence.PREC_NONE }, // NIL
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // OR
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // PRINT
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // RETURN
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // SUPER
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // THIS
    .{ .prefix = literal, .infix = null, .precedence = Precedence.PREC_NONE }, // TRUE
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // VAR
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // WHILE
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // ERROR
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // EOF
};

pub fn parsePrecedence(precedence: Precedence) !void {
    advance();
    const prefixRule = getRule(parser.previous.type).prefix;
    if (prefixRule == null) {
        errorBase("Expect expression");
        return;
    }

    try prefixRule.?();

    while (@intFromEnum(precedence) <= @intFromEnum(getRule(parser.current.type).precedence)) {
        advance();
        const infixRule = getRule(parser.previous.type).infix;
        try infixRule.?();
    }
}

pub fn getRule(ruleType: Scanner.TokenType) *const ParseRule {
    return &rules[@intFromEnum(ruleType)];
}

pub fn expression() !void {
    try parsePrecedence(Precedence.PREC_ASSIGNMENT);
}
