const std = @import("std");
const Chunk = @import("chunk.zig");
const Value = @import("value.zig");
const Debug = @import("debug.zig");
const Compiler = @import("compiler.zig");

const STACK_MAX = 256;

pub const VM = struct { 
    chunk: *Chunk.Chunk, 
    ip: [*]u8, 
    stack: [STACK_MAX]Value.Value, 
    stackTop: [*]Value.Value 
};

var vm: VM = undefined;

pub fn resetStack() void {
    vm.stackTop = @ptrCast(&vm.stack[0]);
}

pub fn runtimeError(comptime format: []const u8, args:anytype) void {
    std.debug.print(format ++ "\n", args);

    const instruction = vm.ip - &vm.chunk.code[0] - 1;
    const line = vm.chunk.lines[instruction];

    std.debug.print("[line {d}] in script\n", .{line});

    resetStack();
}

pub const InterpretResult = enum { INTERPRET_OK, INTERPRET_COMPILE_ERROR, INTERPRET_RUNTIME_ERROR };

pub fn initVM() void {
    resetStack();
}

pub fn freeVM() void {}

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

pub fn run() InterpretResult {
    while (true) {
        if (Debug.debug_trace_execution) {
            std.debug.print("        ", .{});
            for (vm.stack) |slot| {
                std.debug.print("[ ", .{});
                Value.printValue(slot);
                std.debug.print(" ]", .{});
            }
            std.debug.print("\n", .{});
            _ = Debug.disassembleInstruction(vm.chunk, vm.ip - &vm.chunk.code[0]);
        }
        const instruction = readByte();
        switch (instruction) {
            @intFromEnum(Chunk.OpCode.OP_ADD) => {
                binaryOp(add);
            },
            @intFromEnum(Chunk.OpCode.OP_CONSTANT) => {
                const constant: Value.Value = readConstant();
                push(constant);
                Value.printValue(constant);
                std.debug.print("\n", .{});
            },
            @intFromEnum(Chunk.OpCode.OP_DIVIDE) => {
                binaryOp(divide);
            },
            @intFromEnum(Chunk.OpCode.OP_MULTIPLY) => {
                binaryOp(multiply);
            },
            @intFromEnum(Chunk.OpCode.OP_RETURN) => {
                Value.printValue(pop());
                std.debug.print("\n", .{});
                return InterpretResult.INTERPRET_OK;
            },
            @intFromEnum(Chunk.OpCode.OP_SUBTRACT) => {
                binaryOp(subtract);
            },
            @intFromEnum(Chunk.OpCode.OP_NEGATE) => {
                if (!Value.IS_NUMBER(peek(0))) {
                    runtimeError("Operand must be a number.", .{});
                    return InterpretResult.INTERPRET_RUNTIME_ERROR;
                }
                push(Value.NUMBER_VAL(-Value.AS_NUMBER(pop())));
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

fn readByte() u8 {
    const byte = vm.ip[0];
    vm.ip += 1;
    return byte;
}

pub fn interpret(source: []const u8, allocator: *std.mem.Allocator) !InterpretResult {
    var chunk: Chunk.Chunk = undefined;
    Chunk.initChunk(&chunk);

    const compilingResult = try Compiler.compile(source, &chunk, allocator);

    if (!compilingResult) {
        Chunk.freeChunk(&chunk, allocator);
        return InterpretResult.INTERPRET_COMPILE_ERROR;
    }

    vm.chunk = &chunk;
    vm.ip = vm.chunk.code.ptr;

    const result = run();

    Chunk.freeChunk(&chunk, allocator);
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

pub fn subtract(a:f64, b: f64) Value.Value {
    return Value.NUMBER_VAL(a - b);
}

pub fn multiply(a: f64, b: f64) Value.Value {
    return Value.NUMBER_VAL(a * b);
}

pub fn divide(a: f64, b: f64) Value.Value {
    return Value.NUMBER_VAL(a / b);
}