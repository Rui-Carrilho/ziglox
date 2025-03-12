const std = @import("std");

pub const Scanner = struct {
    start: []const u8,
    current: []const u8,
    line: i8
};

pub const TokenType = enum {
    // Single-character tokens.
    TOKEN_LEFT_PAREN, TOKEN_RIGHT_PAREN,
    TOKEN_LEFT_BRACE, TOKEN_RIGHT_BRACE,
    TOKEN_COMMA, TOKEN_DOT, TOKEN_MINUS, TOKEN_PLUS,
    TOKEN_SEMICOLON, TOKEN_SLASH, TOKEN_STAR,

    // One or two character tokens.
    TOKEN_BANG, TOKEN_BANG_EQUAL,
    TOKEN_EQUAL, TOKEN_EQUAL_EQUAL,
    TOKEN_GREATER, TOKEN_GREATER_EQUAL,
    TOKEN_LESS, TOKEN_LESS_EQUAL,

    // Literals.
    TOKEN_IDENTIFIER, TOKEN_STRING, TOKEN_NUMBER,
    
    // Keywords.
    TOKEN_AND, TOKEN_CLASS, TOKEN_ELSE, TOKEN_FALSE,
    TOKEN_FOR, TOKEN_FUN, TOKEN_IF, TOKEN_NIL, TOKEN_OR,
    TOKEN_PRINT, TOKEN_RETURN, TOKEN_SUPER, TOKEN_THIS,
    TOKEN_TRUE, TOKEN_VAR, TOKEN_WHILE,

    TOKEN_ERROR, TOKEN_EOF
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

pub fn scanToken() Token {
    scanner.start = scanner.current;
    if(isAtEnd()) return makeToken(TokenType.TOKEN_EOF);
    
    return errorToken("Unexpected character");
}

pub fn isAtEnd() bool {
    return scanner.current.len == 0;
}

pub fn makeToken(tokenType: TokenType) Token {
    var token: Token = undefined;
    token.type = tokenType;
    token.start = scanner.start;
    token.length = @as(i32, scanner.current - scanner.start);
    token.line = scanner.line;
    return token;
}

pub fn errorToken(message: []const u8) Token {
    var token: Token = undefined;
    token.type = TokenType.TOKEN_EOF;
    token.start = message;
    token.length = @as(i32, message.len);
    token.line = scanner.line;
    return token;
}