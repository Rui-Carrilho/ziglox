const std = @import("std");
const Chunk = @import("chunk.zig");
const Value = @import("value.zig");
const Debug = @import("debug.zig");

const STACK_MAX = 256;

pub const VM = struct { chunk: *Chunk.Chunk, ip: *u8, stack: [STACK_MAX]Value.Value, stackTop: *Value.Value };

var vm: VM = undefined;

pub fn resetStack() void {
    vm.stackTop = &vm.stack[0];
}

pub const InterpretResult = enum { INTERPRET_OK, INTERPRET_COMPILE_ERROR, INTERPRET_RUNTIME_ERROR };

pub fn initVM() void {
    resetStack();
}

pub fn freeVM() void {}

pub fn push(value: Value.Value) void {
    vm.stackTop.* = value;
    vm.stackTop = @ptrFromInt(@intFromPtr(vm.stackTop) + @sizeOf(Value.Value));
}

pub fn pop() Value.Value {
    vm.stackTop = @ptrFromInt(@intFromPtr(vm.stackTop) - @sizeOf(Value.Value));
    return vm.stackTop.*;
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
            _ = Debug.disassembleInstruction(vm.chunk, @intFromPtr(vm.ip) - @intFromPtr(&vm.chunk.code[0]));
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
                push(-pop());
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
    const byte = vm.ip.*;
    vm.ip = @ptrFromInt(@intFromPtr(vm.ip) + @sizeOf(u8));
    return byte;
}

pub fn interpret(chunk: *Chunk.Chunk) InterpretResult {
    vm.chunk = chunk;
    vm.ip = &chunk.code[0];
    return run();
}

pub fn binaryOp(comptime op: fn (f64, f64) f64) void {
    const b: f64 = pop();
    const a: f64 = pop();
    push(op(a, b));
}

pub fn add(a: f64, b: f64) f64 {
    return a + b;
}

pub fn subtract(a:f64, b: f64) f64 {
    return a - b;
}

pub fn multiply(a: f64, b: f64) f64 {
    return a * b;
}

pub fn divide(a: f64, b: f64) f64 {
    return a / b;
}