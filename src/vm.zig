const std = @import("std");
const Chunk = @import("chunk.zig");
const Value = @import("value.zig");
const Debug = @import("debug.zig");
const Compiler = @import("compiler.zig");
const Object = @import("object.zig");
const memory = @import("memory.zig");
const Table = @import("table.zig");

const STACK_MAX = 256;

pub const VM = struct { chunk: *Chunk.Chunk, ip: [*]u8, stack: [STACK_MAX]Value.Value, stackTop: [*]Value.Value, globals: Table.Table, objects: ?*Object.Obj, strings: Table.Table };

pub var vm: VM = undefined;

pub fn resetStack() void {
    vm.stackTop = @ptrCast(&vm.stack[0]);
}

pub fn runtimeError(comptime format: []const u8, args: anytype) void {
    std.debug.print(format ++ "\n", args);

    const instruction = vm.ip - &vm.chunk.code[0] - 1;
    const line = vm.chunk.lines[instruction];

    std.debug.print("[line {d}] in script\n", .{line});

    resetStack();
}

pub const InterpretResult = enum { INTERPRET_OK, INTERPRET_COMPILE_ERROR, INTERPRET_RUNTIME_ERROR };

pub fn initVM() void {
    resetStack();
    vm.objects = null;
    Table.initTable(&vm.globals);
    Table.initTable(&vm.strings);
}

pub fn freeVM() !void {
    try Table.freeTable(&vm.globals);
    try Table.freeTable(&vm.strings);
    try memory.freeObjects();
}

pub fn push(value: Value.Value) void {
    vm.stackTop[0] = value;
    vm.stackTop += 1;
}

pub fn pop() Value.Value {
    vm.stackTop -= 1;
    return vm.stackTop[0];
}

pub fn peek(distance: usize) Value.Value {
    return (vm.stackTop - 1 - distance)[0];
}

pub fn isFalsey(value: Value.Value) bool {
    return Value.IS_NIL(value) or (Value.IS_BOOL(value) and !Value.AS_BOOL(value));
}

pub fn concatenate() !void {
    const b = Object.AS_STRING(pop());
    const a = Object.AS_STRING(pop());

    const length = a.chars.len + b.chars.len;

    const chars = try memory.ALLOCATE(u8, length);

    @memcpy(chars[0..a.chars.len], a.chars);
    @memcpy(chars[a.chars.len..], b.chars);

    const result = try Object.takeString(chars);
    push(Value.OBJ_VAL(result));
}

pub fn run() !InterpretResult {
    while (true) {
        if (Debug.debug_trace_execution) {
            std.debug.print("== stack ==\n", .{});
            for (vm.stack) |slot| {
                std.debug.print("[ ", .{});
                Value.printValue(slot);
                std.debug.print(" ]", .{});
            }
            std.debug.print("\n", .{});
            std.debug.print("== globals ==\n", .{});
            Table.debugPrintTable(&vm.globals);
            _ = Debug.disassembleInstruction(vm.chunk, vm.ip - &vm.chunk.code[0]);
        }
        const instruction = readByte();
        switch (instruction) {
            @intFromEnum(Chunk.OpCode.OP_ADD) => {
                if (Object.IS_STRING(peek(0)) and Object.IS_STRING(peek(1))) {
                    try concatenate();
                } else if (Value.IS_NUMBER(peek(0)) and Value.IS_NUMBER(peek(1))) {
                    const b = Value.AS_NUMBER(pop());
                    const a = Value.AS_NUMBER(pop());
                    push(Value.NUMBER_VAL(a + b));
                } else {
                    runtimeError("Operands must be two numbers or two strings", .{});
                    return InterpretResult.INTERPRET_RUNTIME_ERROR;
                }
            },
            @intFromEnum(Chunk.OpCode.OP_CONSTANT) => {
                const constant: Value.Value = readConstant();
                push(constant);
                Value.printValue(constant);
                std.debug.print("\n", .{});
            },
            @intFromEnum(Chunk.OpCode.OP_DEFINE_GLOBAL) => {
                const name = readString();
                _ = try Table.tableSet(&vm.globals, name, peek(0));
                _ = pop();
            },
            @intFromEnum(Chunk.OpCode.OP_DIVIDE) => {
                binaryOp(divide);
            },
            @intFromEnum(Chunk.OpCode.OP_EQUAL) => {
                const b = pop();
                const a = pop();
                push(Value.BOOL_VAL(Value.valuesEqual(a, b)));
            },
            @intFromEnum(Chunk.OpCode.OP_FALSE) => {
                push(Value.BOOL_VAL(false));
            },
            @intFromEnum(Chunk.OpCode.OP_GET_GLOBAL) => {
                const name = readString();
                var value: Value.Value = Value.NIL_VAL;

                const tableGet = try Table.tableGet(&vm.globals, name, &value);
                std.debug.print("tableGet: {}\n", .{tableGet});
                if (!tableGet) {
                    runtimeError("Undefined variable '{s}'.", .{Object.OBJ_AS_STRING(name.*).chars});
                    return InterpretResult.INTERPRET_RUNTIME_ERROR;
                }
                push(value);
            },
            @intFromEnum(Chunk.OpCode.OP_GET_LOCAL) => {
                const slot = readByte();
                push(vm.stack[slot]);
            },
            @intFromEnum(Chunk.OpCode.OP_GREATER) => {
                binaryOp(greaterThan);
            },
            @intFromEnum(Chunk.OpCode.OP_LESS) => {
                binaryOp(lessThan);
            },
            @intFromEnum(Chunk.OpCode.OP_MULTIPLY) => {
                binaryOp(multiply);
            },
            @intFromEnum(Chunk.OpCode.OP_NEGATE) => {
                if (!Value.IS_NUMBER(peek(0))) {
                    runtimeError("Operand must be a number.", .{});
                    return InterpretResult.INTERPRET_RUNTIME_ERROR;
                }
                push(Value.NUMBER_VAL(-Value.AS_NUMBER(pop())));
            },
            @intFromEnum(Chunk.OpCode.OP_NIL) => {
                push(Value.NIL_VAL);
            },
            @intFromEnum(Chunk.OpCode.OP_NOT) => {
                push(Value.BOOL_VAL(isFalsey(pop())));
            },
            @intFromEnum(Chunk.OpCode.OP_POP) => {
                _ = pop();
            },
            @intFromEnum(Chunk.OpCode.OP_PRINT) => {
                Value.printValue(pop());
                std.debug.print("\n", .{});
            },
            @intFromEnum(Chunk.OpCode.OP_RETURN) => {
                //exit interpreter
                return InterpretResult.INTERPRET_OK;
            },
            @intFromEnum(Chunk.OpCode.OP_SET_GLOBAL) => {
                const name = readString();
                const tableSet = try Table.tableSet(&vm.globals, name, peek(0));
                if (tableSet) {
                    _ = Table.tableDelete(&vm.globals, name);
                    runtimeError("Undefined variable {s}", .{name.node.string.chars});
                    return InterpretResult.INTERPRET_RUNTIME_ERROR;
                }
            },
            @intFromEnum(Chunk.OpCode.OP_SET_LOCAL) => {
                const slot = readByte();
                vm.stack[slot] = peek(0);
            },
            @intFromEnum(Chunk.OpCode.OP_SUBTRACT) => {
                binaryOp(subtract);
            },
            @intFromEnum(Chunk.OpCode.OP_TRUE) => {
                push(Value.BOOL_VAL(true));
            },
            else => {
                std.debug.print("the instruction was {}", .{instruction});
                std.debug.panic("fuuuuuuuuuuuck", .{});
            },
        }
    }
    unreachable;
}

fn readConstant() Value.Value {
    return vm.chunk.constants.values[readByte()];
}

fn readString() *Object.Obj {
    return Object.AS_STRING_OBJ(readConstant());
}

fn readByte() u8 {
    const byte = vm.ip[0];
    vm.ip += 1;
    return byte;
}

pub fn interpret(source: []const u8) !InterpretResult {
    var chunk: Chunk.Chunk = undefined;
    Chunk.initChunk(&chunk);

    const compilingResult = try Compiler.compile(source, &chunk);

    if (!compilingResult) {
        Chunk.freeChunk(&chunk);
        return InterpretResult.INTERPRET_COMPILE_ERROR;
    }

    vm.chunk = &chunk;
    vm.ip = vm.chunk.code.ptr;

    const result = run();

    Chunk.freeChunk(&chunk);
    return result;
}

pub fn binaryOp(comptime op: fn (f64, f64) Value.Value) void {
    const b: f64 = Value.AS_NUMBER(pop());
    const a: f64 = Value.AS_NUMBER(pop());
    push(op(a, b));
}

pub fn add(a: f64, b: f64) Value.Value {
    return Value.NUMBER_VAL(a + b);
}

pub fn subtract(a: f64, b: f64) Value.Value {
    return Value.NUMBER_VAL(a - b);
}

pub fn multiply(a: f64, b: f64) Value.Value {
    return Value.NUMBER_VAL(a * b);
}

pub fn divide(a: f64, b: f64) Value.Value {
    return Value.NUMBER_VAL(a / b);
}

pub fn greaterThan(a: f64, b: f64) Value.Value {
    return Value.BOOL_VAL(a > b);
}

pub fn lessThan(a: f64, b: f64) Value.Value {
    return Value.BOOL_VAL(a < b);
}
