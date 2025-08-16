const std = @import("std");
const Scanner = @import("scanner.zig");
const Chunk = @import("chunk.zig");
const Value = @import("value.zig");
const Debug = @import("debug.zig");
const Allocator = @import("allocator.zig");
const Object = @import("object.zig");

const UINT8_COUNT = std.math.maxInt(u8) + 1;

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

const ParseFn = ?*const fn (canAssign: bool) anyerror!void;

pub const ParseRule = struct { prefix: ParseFn, infix: ParseFn, precedence: Precedence };

pub const Compiler = struct { function: ?*Object.ObjFunction, type: FunctionType, locals: [UINT8_COUNT]Local, localCount: usize, scopeDepth: i32 };

pub const Local = struct { name: Scanner.Token, depth: i32 };

pub const FunctionType = enum { TYPE_FUNCTION, TYPE_SCRIPT };

var parser: Parser = undefined;
var current: ?*Compiler = null;

const debugPrintCode = true;

pub fn currentChunk() *Chunk.Chunk {
    return &current.?.function.?.chunk;
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

pub fn compile(source: []const u8) !?*Object.ObjFunction {
    Scanner.initScanner(source);
    var compiler: Compiler = undefined;
    try initCompiler(&compiler, FunctionType.TYPE_SCRIPT);

    parser.hadError = false;
    parser.panicMode = false;

    advance();

    while (!match(Scanner.TokenType.TOKEN_EOF)) {
        try declaration();
    }

    const function = try endCompiler();
    return if (parser.hadError) null else function;
}

pub fn advance() void {
    parser.previous = parser.current;

    while (true) {
        parser.current = Scanner.scanToken();
        if (parser.current.type != Scanner.TokenType.TOKEN_ERROR) break;

        errorAtCurrent(parser.current.name);
    }
}

pub fn consume(tokenType: Scanner.TokenType, message: []const u8) !void {
    //this function advances the thing until we get to the token specified in tokenType. if it doesn't find it, it spits out the message
    if (parser.current.type == tokenType) {
        advance();
        return;
    }

    errorAtCurrent(message);
}

pub fn check(myType: Scanner.TokenType) bool {
    return parser.current.type == myType;
}

pub fn match(myType: Scanner.TokenType) bool {
    if (!check(myType)) return false;
    advance();
    return true;
}

pub fn emitByte(byte: u8) !void {
    try Chunk.writeChunk(currentChunk(), byte, parser.previous.line);
}

pub fn emitBytes(byte1: u8, byte2: u8) !void {
    try emitByte(byte1);
    try emitByte(byte2);
}

pub fn emitLoop(loopStart: u8) !void {
    try emitByte(@intFromEnum(Chunk.OpCode.OP_LOOP));

    const offset = currentChunk().count - loopStart + 2;
    if (offset > UINT8_COUNT) errorBase("Loop body too large.");

    try emitByte(@intCast((offset >> 8) & 0xff));
    try emitByte(@intCast(offset & 0xff));
}

pub fn emitJump(instruction: u8) !u8 {
    try emitByte(instruction);
    try emitByte(0xff);
    try emitByte(0xff);
    return @intCast(currentChunk().count - 2);
}

pub fn emitReturn() !void {
    try emitByte(@intFromEnum(Chunk.OpCode.OP_RETURN));
}

pub fn makeConstant(value: Value.Value) !u8 {
    const constant = try Chunk.addConstant(currentChunk(), value);
    if (constant > @as(usize, std.math.maxInt(u8))) {
        errorBase("too many constants in one chunk.");
        return 0;
    }

    return @intCast(constant);
}

pub fn emitConstant(value: Value.Value) !void {
    const newConstant = try makeConstant(value);
    try emitBytes(@intFromEnum(Chunk.OpCode.OP_CONSTANT), newConstant);
}

pub fn patchJump(offset: usize) void {
    const jump = currentChunk().count - offset - 2;

    if (jump > UINT8_COUNT) {
        errorBase("Too much code to jump over.");
    }

    currentChunk().code[offset] = @intCast((jump >> 8) & 0xff);
    currentChunk().code[offset + 1] = @intCast((jump) & 0xff);
}

pub fn initCompiler(compiler: *Compiler, myType: FunctionType) !void {
    compiler.function = null;
    compiler.type = myType;
    compiler.localCount = 0;
    compiler.scopeDepth = 0;

    const function = try Object.newFunction();
    compiler.function = &function.node.function;
    current = compiler;

    var local = &current.?.locals[current.?.localCount];
    current.?.localCount += 1;
    local.depth = 0;
    local.name.name[0] = 0;
    local.name.name.len = 0;
}

pub fn endCompiler() !*Object.ObjFunction {
    try emitReturn();
    const function = current.?.function;

    if (debugPrintCode) {
        if (!parser.hadError) {
            Debug.disassembleChunk(currentChunk(), if (function != null) function.?.name.?.chars else "<script>");
        }
    }

    return function.?;
}

pub fn binary(canAssign: bool) !void {
    _ = canAssign;
    const operatorType = parser.previous.type;
    const rule = getRule(operatorType);
    try parsePrecedence(@enumFromInt(@intFromEnum(rule.precedence) + 1));

    try switch (operatorType) {
        Scanner.TokenType.TOKEN_BANG_EQUAL => emitBytes(@intFromEnum(Chunk.OpCode.OP_EQUAL), @intFromEnum(Chunk.OpCode.OP_NOT)),
        Scanner.TokenType.TOKEN_EQUAL_EQUAL => emitByte(@intFromEnum(Chunk.OpCode.OP_EQUAL)),
        Scanner.TokenType.TOKEN_GREATER => emitByte(@intFromEnum(Chunk.OpCode.OP_GREATER)),
        Scanner.TokenType.TOKEN_GREATER_EQUAL => emitBytes(@intFromEnum(Chunk.OpCode.OP_LESS), @intFromEnum(Chunk.OpCode.OP_NOT)),
        Scanner.TokenType.TOKEN_LESS => emitByte(@intFromEnum(Chunk.OpCode.OP_LESS)),
        Scanner.TokenType.TOKEN_LESS_EQUAL => emitBytes(@intFromEnum(Chunk.OpCode.OP_GREATER), @intFromEnum(Chunk.OpCode.OP_NOT)),
        Scanner.TokenType.TOKEN_PLUS => emitByte(@intFromEnum(Chunk.OpCode.OP_ADD)),
        Scanner.TokenType.TOKEN_MINUS => emitByte(@intFromEnum(Chunk.OpCode.OP_SUBTRACT)),
        Scanner.TokenType.TOKEN_STAR => emitByte(@intFromEnum(Chunk.OpCode.OP_MULTIPLY)),
        Scanner.TokenType.TOKEN_SLASH => emitByte(@intFromEnum(Chunk.OpCode.OP_DIVIDE)),
        else => unreachable,
    };
}

pub fn literal(canAssign: bool) !void {
    _ = canAssign;
    try switch (parser.previous.type) {
        Scanner.TokenType.TOKEN_FALSE => emitByte(@intFromEnum(Chunk.OpCode.OP_FALSE)),
        Scanner.TokenType.TOKEN_NIL => emitByte(@intFromEnum(Chunk.OpCode.OP_NIL)),
        Scanner.TokenType.TOKEN_TRUE => emitByte(@intFromEnum(Chunk.OpCode.OP_TRUE)),
        else => return,
    };
}

pub fn grouping(canAssign: bool) !void {
    _ = canAssign;
    try expression();
    try consume(Scanner.TokenType.TOKEN_RIGHT_PAREN, "Expect ')' after expression.");
}

pub fn number(canAssign: bool) !void {
    _ = canAssign;
    const value = std.fmt.parseFloat(f64, parser.previous.name) catch |err| {
        std.debug.print("Error parsing float: {}\n", .{err});
        try emitConstant(Value.NUMBER_VAL(0));
        return;
    };
    try emitConstant(Value.NUMBER_VAL(value));
}

pub fn or_(canAssign: bool) !void {
    _ = canAssign;

    const elseJump = try emitJump(@intFromEnum(Chunk.OpCode.OP_JUMP_IF_FALSE));
    const endJump = try emitJump(@intFromEnum(Chunk.OpCode.OP_JUMP));

    patchJump(elseJump);
    try emitByte(@intFromEnum(Chunk.OpCode.OP_POP));

    try parsePrecedence(Precedence.PREC_OR);
    patchJump(endJump);
}

pub fn string(canAssign: bool) !void {
    _ = canAssign;
    try emitConstant(Value.OBJ_VAL(try Object.copyString(parser.previous.name[1 .. parser.previous.name.len - 1])));
}

pub fn variable(canAssign: bool) !void {
    try namedVariable(parser.previous, canAssign);
}

pub fn namedVariable(name: Scanner.Token, canAssign: bool) !void {
    var getOp: u8 = undefined;
    var setOp: u8 = undefined;

    var arg = resolveLocal(current.?, &name);
    if (arg != -1) {
        getOp = @intFromEnum(Chunk.OpCode.OP_GET_LOCAL);
        setOp = @intFromEnum(Chunk.OpCode.OP_SET_LOCAL);
    } else {
        arg = try identifierConstant(&name);
        getOp = @intFromEnum(Chunk.OpCode.OP_GET_GLOBAL);
        setOp = @intFromEnum(Chunk.OpCode.OP_SET_GLOBAL);
    }

    if (canAssign and match(Scanner.TokenType.TOKEN_EQUAL)) {
        try expression();
        try emitBytes(setOp, arg);
    } else {
        try emitBytes(getOp, arg);
    }
}

pub fn unary(canAssign: bool) !void {
    _ = canAssign;
    const operatorType = parser.previous.type;

    //compile the operand
    try parsePrecedence(Precedence.PREC_UNARY);

    //emit the operator instruction
    try switch (operatorType) {
        Scanner.TokenType.TOKEN_BANG => emitByte(@intFromEnum(Chunk.OpCode.OP_NOT)),
        Scanner.TokenType.TOKEN_MINUS => emitByte(@intFromEnum(Chunk.OpCode.OP_NEGATE)),
        else => unreachable,
    };

    //lmao, lets test gi
}

pub const rules = [_]ParseRule{
    .{ .prefix = grouping, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_LEFT_PAREN
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_RIGHT_PAREN
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_LEFT_BRACE
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_RIGHT_BRACE
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_COMMA
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_DOT
    .{ .prefix = unary, .infix = binary, .precedence = Precedence.PREC_TERM }, // TOKEN_MINUS
    .{ .prefix = null, .infix = binary, .precedence = Precedence.PREC_TERM }, // TOKEN_PLUS
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_SEMICOLON
    .{ .prefix = null, .infix = binary, .precedence = Precedence.PREC_FACTOR }, // TOKEN_SLASH
    .{ .prefix = null, .infix = binary, .precedence = Precedence.PREC_FACTOR }, // TOKEN_STAR
    .{ .prefix = unary, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_BANG
    .{ .prefix = null, .infix = binary, .precedence = Precedence.PREC_EQUALITY }, // TOKEN_BANG_EQUAL
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_EQUAL
    .{ .prefix = null, .infix = binary, .precedence = Precedence.PREC_EQUALITY }, // TOKEN_EQUAL_EQUAL
    .{ .prefix = null, .infix = binary, .precedence = Precedence.PREC_COMPARISON }, // TOKEN_GREATER
    .{ .prefix = null, .infix = binary, .precedence = Precedence.PREC_COMPARISON }, // TOKEN_GREATER_EQUAL
    .{ .prefix = null, .infix = binary, .precedence = Precedence.PREC_COMPARISON }, // TOKEN_LESS
    .{ .prefix = null, .infix = binary, .precedence = Precedence.PREC_COMPARISON }, // TOKEN_LESS_EQUAL
    .{ .prefix = variable, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_IDENTIFIER
    .{ .prefix = string, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_STRING
    .{ .prefix = number, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_NUMBER
    .{ .prefix = null, .infix = and_, .precedence = Precedence.PREC_AND }, // TOKEN_AND
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_CLASS
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_ELSE
    .{ .prefix = literal, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_FALSE
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_FOR
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_FUN
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_IF
    .{ .prefix = literal, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_NIL
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_OR
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_PRINT
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_RETURN
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_SUPER
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_THIS
    .{ .prefix = literal, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_TRUE
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_VAR
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_WHILE
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_ERROR
    .{ .prefix = null, .infix = null, .precedence = Precedence.PREC_NONE }, // TOKEN_EOF
};

pub fn parsePrecedence(precedence: Precedence) !void {
    advance();
    const prefixRule = getRule(parser.previous.type).prefix;
    if (prefixRule == null) {
        errorBase("Expect expression");
        return;
    }

    const canAssign = @intFromEnum(precedence) <= @intFromEnum(Precedence.PREC_ASSIGNMENT);
    try prefixRule.?(canAssign);

    while (@intFromEnum(precedence) <= @intFromEnum(getRule(parser.current.type).precedence)) {
        advance();
        const infixRule = getRule(parser.previous.type).infix;
        try infixRule.?(canAssign);
    }

    if (canAssign and match(Scanner.TokenType.TOKEN_EQUAL)) {
        errorBase("Invalid assignment target.");
    }
}

pub fn identifierConstant(name: *Scanner.Token) !u8 {
    const newString = try Object.copyString(name.name);
    return makeConstant(Value.OBJ_VAL(newString));
}

pub fn identifiersEqual(a: *const Scanner.Token, b: *Scanner.Token) bool {
    if (a.name.len != b.name.len) return false;
    return std.mem.eql(u8, a.name, b.name);
}

pub fn resolveLocal(compiler: *Compiler, name: *const Scanner.Token) u8 {
    var i = compiler.localCount - 1;
    while (i >= 0) : (i -= 1) {
        const local = &compiler.locals[i];
        if (identifiersEqual(name, &local.name)) {
            if (local.depth == -1) {
                errorBase("Can't read local variable in its own initializer.");
            }
            return @intCast(i);
        }
    }

    return -1;
}

pub fn addLocal(name: Scanner.Token) void {
    if (current != null) {
        if (current.?.localCount == UINT8_COUNT) {
            errorBase("Too many local variables in function.");
            return;
        }
        var local = current.?.locals[current.?.localCount + 1];
        local.name = name;
        local.depth = -1;
    }
}

pub fn declareVariable() !void {
    if (current != null) {
        if (current.?.scopeDepth == 0) return;
    }

    //dummy commit because i can
    const name = &parser.previous;

    var local: *Local = undefined;
    var i: usize = current.?.localCount - 1;

    while (i >= 0) : (i += 1) {
        local = &current.?.locals[i];
        if (local.depth != -1 and local.depth < current.?.scopeDepth) {
            break;
        }

        if (identifiersEqual(name, &local.name)) {
            errorBase("Already a variable with this name in this scope.");
        }
    }

    addLocal(name.*);
}

pub fn parseVariable(errorMessage: []const u8) !u8 {
    try consume(Scanner.TokenType.TOKEN_IDENTIFIER, errorMessage);

    try declareVariable();

    if (current != null) {
        if (current.?.scopeDepth > 0) return 0;
    }

    return try identifierConstant(&parser.previous);
}

pub fn markInitialized() void {
    current.?.locals[current.?.localCount - 1].depth = current.?.scopeDepth;
}

pub fn defineVariable(global: u8) !void {
    if (current != null) {
        if (current.?.scopeDepth > 0) {
            markInitialized();
            return;
        }
    }
    try emitBytes(@intFromEnum(Chunk.OpCode.OP_DEFINE_GLOBAL), global);
}

pub fn and_(canAssign: bool) !void {
    _ = canAssign;

    const endJump = try emitJump(@intFromEnum(Chunk.OpCode.OP_JUMP_IF_FALSE));

    try emitByte(@intFromEnum(Chunk.OpCode.OP_POP));

    try parsePrecedence(Precedence.PREC_AND);

    patchJump(endJump);
}

pub fn getRule(ruleType: Scanner.TokenType) *const ParseRule {
    return &rules[@intFromEnum(ruleType)];
}

pub fn expression() !void {
    try parsePrecedence(Precedence.PREC_ASSIGNMENT);
}

pub fn block() anyerror!void {
    while (!check(Scanner.TokenType.TOKEN_RIGHT_BRACE) and !check(Scanner.TokenType.TOKEN_EOF)) {
        try declaration();
    }

    try consume(Scanner.TokenType.TOKEN_RIGHT_BRACE, "Expect '}' after block.");
}

pub fn varDeclaration() !void {
    const global = try parseVariable("Expect variable name.");

    if (match(Scanner.TokenType.TOKEN_EQUAL)) {
        try expression();
    } else {
        try emitByte(@intFromEnum(Chunk.OpCode.OP_NIL));
    }

    try consume(Scanner.TokenType.TOKEN_SEMICOLON, "Expect ';' after variable declaration.");

    try defineVariable(global);
}

pub fn expressionStatement() !void {
    try expression();
    try consume(Scanner.TokenType.TOKEN_SEMICOLON, "Expect ';' after expression.");
    try emitByte(@intFromEnum(Chunk.OpCode.OP_POP));
}

pub fn forStatement() !void {
    beginScope();
    try consume(.TOKEN_LEFT_PAREN, "Expect '(' after 'for'.");
    if (match(.TOKEN_SEMICOLON)) {} else if (match(.TOKEN_VAR)) {
        try varDeclaration();
    } else {
        try expressionStatement();
    }

    var loopStart = currentChunk().count;
    var exitJump: ?usize = null;
    if (!match(.TOKEN_SEMICOLON)) {
        try expression();
        try consume(.TOKEN_SEMICOLON, "Expect ';' after loop condition.");
        exitJump = try emitJump(@intFromEnum(Chunk.OpCode.OP_JUMP_IF_FALSE));
        try emitByte(@intFromEnum(Chunk.OpCode.OP_POP));
    }

    if (match(.TOKEN_RIGHT_PAREN)) {
        const bodyJump = try emitJump(@intFromEnum(Chunk.OpCode.OP_JUMP));
        const incrementStart = currentChunk().count;
        try expression();
        try emitByte(@intFromEnum(Chunk.OpCode.OP_POP));
        try consume(.TOKEN_RIGHT_PAREN, "Expect ')' after for clauses.");

        try emitLoop(@intCast(loopStart));
        loopStart = incrementStart;
        patchJump(bodyJump);
    }

    try statement();
    try emitLoop(@intCast(loopStart));

    if (exitJump != null) {
        patchJump(exitJump.?);
        try emitByte(@intFromEnum(Chunk.OpCode.OP_POP));
    }
    try endScope();
}

pub fn ifStatement() !void {
    try consume(Scanner.TokenType.TOKEN_LEFT_PAREN, "Expect '(' after if.");
    try expression();
    try consume(Scanner.TokenType.TOKEN_RIGHT_PAREN, "Expect ')' after condition.");

    const thenJump = try emitJump(@intFromEnum(Chunk.OpCode.OP_JUMP_IF_FALSE));
    try emitByte(@intFromEnum(Chunk.OpCode.OP_POP));
    try statement();

    const elseJump = try emitJump(@intFromEnum(Chunk.OpCode.OP_JUMP));

    patchJump(thenJump);
    try emitByte(@intFromEnum(Chunk.OpCode.OP_POP));

    if (match(Scanner.TokenType.TOKEN_ELSE)) try statement();
    patchJump((elseJump));
}
// the box must be green

pub fn printStatement() !void {
    try expression();
    try consume(Scanner.TokenType.TOKEN_SEMICOLON, "Expect ';' after value.");
    try emitByte(@intFromEnum(Chunk.OpCode.OP_PRINT));
}

pub fn whileStatement() !void {
    const loopStart = currentChunk().count;

    try consume(Scanner.TokenType.TOKEN_LEFT_PAREN, "Expect '(' after 'while'.");
    try expression();
    try consume(Scanner.TokenType.TOKEN_RIGHT_PAREN, "Expect '(' after condition.");

    const exitJump = try emitJump(@intFromEnum(Chunk.OpCode.OP_JUMP_IF_FALSE));
    try emitByte(@intFromEnum(Chunk.OpCode.OP_POP));
    try statement();

    try emitLoop(@intCast(loopStart));

    patchJump(exitJump);
    try emitByte(@intFromEnum(Chunk.OpCode.OP_POP));
}

pub fn synchronize() void {
    parser.panicMode = false;

    while (parser.current.type != Scanner.TokenType.TOKEN_EOF) {
        if (parser.previous.type == Scanner.TokenType.TOKEN_SEMICOLON) return;
        switch (parser.current.type) {
            Scanner.TokenType.TOKEN_CLASS, Scanner.TokenType.TOKEN_FUN, Scanner.TokenType.TOKEN_VAR, Scanner.TokenType.TOKEN_FOR, Scanner.TokenType.TOKEN_IF, Scanner.TokenType.TOKEN_WHILE, Scanner.TokenType.TOKEN_PRINT, Scanner.TokenType.TOKEN_RETURN => return,
            else => {},
        }
        advance();
    }
}

pub fn declaration() !void {
    if (match(Scanner.TokenType.TOKEN_VAR)) {
        try varDeclaration();
    } else {
        try statement();
    }

    if (parser.panicMode) synchronize();
}

pub fn statement() anyerror!void {
    if (match(Scanner.TokenType.TOKEN_PRINT)) {
        try printStatement();
    } else if (match(.TOKEN_FOR)) {
        try forStatement();
    } else if (match(Scanner.TokenType.TOKEN_IF)) {
        try ifStatement();
    } else if (match(Scanner.TokenType.TOKEN_WHILE)) {
        try whileStatement();
    } else if (match(Scanner.TokenType.TOKEN_LEFT_BRACE)) {
        beginScope();
        try block();
        try endScope();
    } else {
        try expressionStatement();
    }
}

pub fn beginScope() void {
    current.?.scopeDepth += 1;
}

pub fn endScope() !void {
    current.?.scopeDepth += 1;

    while (current.?.localCount > 0 and current.?.locals[current.?.localCount - 1].depth > current.?.scopeDepth) {
        try emitByte(@intFromEnum(Chunk.OpCode.OP_POP));
        current.?.scopeDepth -= 1;
    }
}
