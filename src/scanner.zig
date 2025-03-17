const std = @import("std");

pub const Scanner = struct { start: [*]const u8, current: [*]const u8, line: i8 };

pub const TokenType = enum {
    // Single-character tokens.
    TOKEN_LEFT_PAREN,
    TOKEN_RIGHT_PAREN,
    TOKEN_LEFT_BRACE,
    TOKEN_RIGHT_BRACE,
    TOKEN_COMMA,
    TOKEN_DOT,
    TOKEN_MINUS,
    TOKEN_PLUS,
    TOKEN_SEMICOLON,
    TOKEN_SLASH,
    TOKEN_STAR,

    // One or two character tokens.
    TOKEN_BANG,
    TOKEN_BANG_EQUAL,
    TOKEN_EQUAL,
    TOKEN_EQUAL_EQUAL,
    TOKEN_GREATER,
    TOKEN_GREATER_EQUAL,
    TOKEN_LESS,
    TOKEN_LESS_EQUAL,

    // Literals.
    TOKEN_IDENTIFIER,
    TOKEN_STRING,
    TOKEN_NUMBER,

    // Keywords.
    TOKEN_AND,
    TOKEN_CLASS,
    TOKEN_ELSE,
    TOKEN_FALSE,
    TOKEN_FOR,
    TOKEN_FUN,
    TOKEN_IF,
    TOKEN_NIL,
    TOKEN_OR,
    TOKEN_PRINT,
    TOKEN_RETURN,
    TOKEN_SUPER,
    TOKEN_THIS,
    TOKEN_TRUE,
    TOKEN_VAR,
    TOKEN_WHILE,

    TOKEN_ERROR,
    TOKEN_EOF,
};

pub const Token = struct { type: TokenType, start: [*]const u8, length: i32, line: i32 };

var scanner: Scanner = undefined;

pub fn initScanner(source: []const u8) void {
    scanner.start = @ptrCast(source.ptr);
    scanner.current = @ptrCast(source.ptr);
    scanner.line = 1;
}

pub fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
}

pub fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

pub fn scanToken() Token {
    _ = skipWhitespace();
    scanner.start = scanner.current;
    if (isAtEnd()) return makeToken(TokenType.TOKEN_EOF);

    const c = advance();
    if (isAlpha(c)) return identifier();
    if (isDigit(c)) return number();

    //std.debug.print("in scanToken - {d} (d)", .{c});

    switch (c) {
        '(' => return makeToken(TokenType.TOKEN_LEFT_PAREN),
        ')' => return makeToken(TokenType.TOKEN_RIGHT_PAREN),
        '{' => return makeToken(TokenType.TOKEN_LEFT_BRACE),
        '}' => return makeToken(TokenType.TOKEN_RIGHT_BRACE),
        ';' => return makeToken(TokenType.TOKEN_SEMICOLON),
        ',' => return makeToken(TokenType.TOKEN_COMMA),
        '.' => return makeToken(TokenType.TOKEN_DOT),
        '-' => return makeToken(TokenType.TOKEN_MINUS),
        '+' => return makeToken(TokenType.TOKEN_PLUS),
        '/' => return makeToken(TokenType.TOKEN_SLASH),
        '*' => return makeToken(TokenType.TOKEN_STAR),
        '!' => return makeToken(if (match('=')) TokenType.TOKEN_BANG_EQUAL else TokenType.TOKEN_BANG),
        '=' => return makeToken(if (match('=')) TokenType.TOKEN_EQUAL_EQUAL else TokenType.TOKEN_EQUAL),
        '<' => return makeToken(if (match('=')) TokenType.TOKEN_LESS_EQUAL else TokenType.TOKEN_LESS),
        '>' => return makeToken(if (match('=')) TokenType.TOKEN_GREATER_EQUAL else TokenType.TOKEN_GREATER),
        '"' => return string(),
        else => {
            std.debug.print("we got a fuckup here: {d} (d) - {c} (c)", .{ c, c });
        },
        // other cases would go here
    }

    return errorToken("Unexpected character");
}

pub fn string() Token {
    while (peek() != '"' and !isAtEnd()) {
        if (peek() == '\n') scanner.line += 1;
        _ = advance();
    }

    if (isAtEnd()) return errorToken("Unterminated string.");

    _ = advance();
    return makeToken(TokenType.TOKEN_STRING);
}

pub fn isAtEnd() bool {
    return scanner.current[0] == 0;
}

pub fn advance() u8 {
    const value = scanner.current[0];
    scanner.current = @ptrFromInt(@intFromPtr(scanner.current) + @sizeOf(u8));
    return value;
}

pub fn peek() u8 {
    return scanner.current[0];
}

pub fn peekNext() u8 {
    if (isAtEnd()) return 0;
    return scanner.current[1];
}

pub fn match(expected: u8) bool {
    if (isAtEnd()) return false;
    if (scanner.current[0] != expected) return false;
    scanner.current = @ptrFromInt(@intFromPtr(scanner.current) + @sizeOf(u8));
    return true;
}

pub fn makeToken(tokenType: TokenType) Token {
    var token: Token = undefined;
    token.type = tokenType;
    token.start = scanner.start;
    token.length = @intCast(@intFromPtr(scanner.current) - @intFromPtr(scanner.start));
    token.line = scanner.line;
    //std.debug.print("the scanner line is {d}, so the token line is {d}", .{scanner.line, token.line});

    return token;
}

pub fn errorToken(message: []const u8) Token {
    var token: Token = undefined;
    token.type = TokenType.TOKEN_EOF;
    token.start = @ptrCast(message.ptr);
    token.length = @intCast(message.len);
    token.line = scanner.line;
    return token;
}

pub fn skipWhitespace() void {
    while (true) {
        const c = peek();
        switch (c) {
            ' ', '\r', '\t' => _ = advance(),
            '\n' => {
                scanner.line += 1;
                _ = advance();
            },
            '/' => {
                if (peekNext() == '/') {
                    while (peek() != '\n' and !isAtEnd()) _ = advance();
                } else {
                    return;
                }
            },
            else => return,
        }
    }
}

pub fn checkKeyword(start: u8, length: u8, rest: []const u8, tokenType: TokenType) TokenType {
    const current_length = @intFromPtr(scanner.current) - @intFromPtr(scanner.start);
    if (current_length == start + length and
        std.mem.eql(u8, scanner.start[start .. start + length], rest)) {
        return tokenType;
    }

    return TokenType.TOKEN_IDENTIFIER; // Assuming TOKEN_IDENTIFIER is defined as an enum
}

pub fn identifierType() TokenType {
    switch (scanner.start[0]) {
        'a' => return checkKeyword(1, 2, "nd", TokenType.TOKEN_AND),
    }
    return TokenType.TOKEN_IDENTIFIER;
}

pub fn identifier() Token {
    while (isAlpha(peek()) or isDigit(peek())) _ = advance();
    return makeToken(identifierType());
}

pub fn number() Token {
    while (isDigit(peek())) _ = advance();

    if (peek() == '.' and isDigit(peekNext())) {
        _ = advance();

        while (isDigit(peek())) _ = advance();
    }

    return makeToken(TokenType.TOKEN_NUMBER);
}
