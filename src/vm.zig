const std = @import("std");
const Chunk = @import("chunk.zig");
const Value = @import("value.zig");
const Debug = @import("debug.zig");

const STACK_MAX = 256;

pub const VM = struct { 
    chunk: *Chunk.Chunk, 
    ip: []u8, 
    stack: [STACK_MAX]Value.Value, 
    stackTop: *Value.Value 
};

var vm: VM = undefined;

pub fn resetStack() void {
    vm.stackTop = &vm.stack[0];
}

pub const InterpretResult = enum { 
    INTERPRET_OK, 
    INTERPRET_COMPILE_ERROR, 
    INTERPRET_RUNTIME_ERROR 
};

pub fn initVM() void {
    resetStack();
}

pub fn freeVM() void {}

pub fn push(value: Value) void {
    vm.stackTop.* = value;
    vm.stackTop += 1;
}

pub fn pop() Value.Value {
    vm.stackTop -= 1;
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
            Debug.disassembleInstruction(vm.chunk, @intCast(@as(i8, vm.ip) - @as(i8, &vm.chunk.code[0])));
        }
        const instruction = readByte();
        switch (instruction) {
            @intFromEnum(Chunk.OpCode.OP_ADD) => {},
            @intFromEnum(Chunk.OpCode.OP_CONSTANT) => {
                const constant: Value.Value = readConstant();
                push(constant);
                Value.printValue(constant);
                std.debug.print("\n", .{});
                break;
            },
            @intFromEnum(Chunk.OpCode.OP_RETURN) => {
                Value.printValue(pop());
                std.debug.print("\n", .{});
                return InterpretResult.INTERPRET_OK;
            },
            @intFromEnum(Chunk.OpCode.OP_NEGATE) => {
                push(-pop());
                break;
            },
            else => unreachable,
        }
    }
}

fn readConstant() Value.Value {
    return vm.chunk.constants.values[readByte()];
}

fn readByte() u8 {
    const byte = vm.ip[0];
    vm.ip += 1;
    return byte;
}

pub fn interpret(chunk: *Chunk.Chunk) InterpretResult {
    vm.chunk = chunk;
    vm.ip = chunk.code;
    return run();
}
