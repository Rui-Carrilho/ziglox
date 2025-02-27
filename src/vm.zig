const std = @import("std");
const Chunk = @import("chunk.zig");
const Value = @import("value.zig");
const Debug = @import("debug.zig");

pub const VM = struct { chunk: *Chunk.Chunk, ip: []u8 };

var vm: VM = undefined;

pub const InterpretResult = enum { INTERPRET_OK, INTERPRET_COMPILE_ERROR, INTERPRET_RUNTIME_ERROR };

pub fn initVM() void {}

pub fn freeVM() void {}

pub fn run() InterpretResult {
    while (true) {
        if (Debug.debug_trace_execution) {
            Debug.disassembleInstruction(vm.chunk, @intCast(@in(vm.ip) - @ptrToInt(&vm.chunk.code[0])));
        }
        const instruction = readByte();
        switch (instruction) {
            @intFromEnum(Chunk.OpCode.OP_CONSTANT) => {
                const constant: Value.Value = readConstant();
                Value.printValue(constant);
                std.debug.print("\n", .{});
                break;
            },
            @intFromEnum(Chunk.OpCode.OP_RETURN) => {
                return InterpretResult.INTERPRET_OK;
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
