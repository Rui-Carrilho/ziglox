const std = @import("std");

pub const Scanner = struct { start: []const u8, current: []const u8, line: i8 };

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

pub const Token = struct { type: TokenType, start: []const u8, length: i32, line: i32 };

var scanner: Scanner = undefined;

pub fn initScanner(source: []const u8) void {
    scanner.start = source;
    scanner.current = source;
    scanner.line = 1;
}

pub fn isAlpha(c: u8) void {
    return(c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
}

pub fn isDigit() bool {
    return c >= '0' and c <= '9';
}

pub fn scanToken() Token {
    skipWhitespace();
    scanner.start = scanner.current;
    if (isAtEnd()) return makeToken(TokenType.TOKEN_EOF);

    var c: u8 = advance();
    if (isDigit(c)) return number();

    switch (c) {
        '(' => return makeToken(TokenType.TOKEN_LEFT_PAREN),
        ')' => return makeToken(TokenType.TOKEN_LEFT_PAREN),
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
        '"' => return string();
        // other cases would go here
    }

    return errorToken("Unexpected character");
}

pub fn string() Token {
    while (peek() != '"' and !isAtEnd()) {
        if (peek() == '\n') scanner.line += 1;
        advance();
    }

    if(isAtEnd()) return errorToken("Unterminated string.");

    advance();
    return makeToken(TokenType.TOKEN_STRING);
}

pub fn isAtEnd() bool {
    return scanner.current.len == 0;
}

pub fn advance() u8 {
    scanner.current += 1;
    return scanner.current[-1];
}

pub fn peek() u8 {
    return scanner.current;
}

pub fn peekNext() u8 {
    if (isAtEnd()) return '\0';
    return scanner.current[1];
}

pub fn match(expected: u8) bool {
    if(isAtEnd()) return false;
    if(scanner.current != expected) return false;
    scanner.current += 1;
    return true;
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

pub fn skipWhitespace() bool {
    while (true) {
        var c: u8 = peek();
        switch (c) {
            ' ' => ,
            '\r' => ,
            '\t' => advance(),
            '\n' => {
                scanner.line += 1;
                advance()
            },
            '/' => {
                if (peekNext() == '/') {
                    while (peek() != '\n' and !isAtEnd()) advance();
                } else {
                    return,
                }
            },
            else => return,
        }
    }
}

pub fn number() Token {
    while (isDigit(peek())) advance();

    if (peek() == '.' and isDigit(peekNext())) {
        advance();

        while (isDigit(peek())) advance();
    }

    return makeToken(TokenType.TOKEN_NUMBER);
}