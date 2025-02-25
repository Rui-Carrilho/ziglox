const std = @import("std");
const Chunk = @import("chunk.zig");

pub const VM = struct { 
    chunk: *Chunk.Chunk,
    ip: [] u8
};

var vm: VM = undefined;

pub const InterpretResult = enum { 
    INTERPRET_OK, 
    INTERPRET_COMPILE_ERROR, 
    INTERPRET_RUNTIME_ERROR 
};

pub fn initVM() void {}

pub fn freeVM() void {}

pub fn run() InterpretResult {
    while(true) {
        const instruction = readByte();
        switch (instruction) {
            @intFromEnum(Chunk.OpCode.OP_RETURN) => {
                return InterpretResult.INTERPRET_OK;
            },
            else => unreachable,
        }
    }

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