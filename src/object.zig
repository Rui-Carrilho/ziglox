const std = @import("std");

pub const ObjType = enum {
    OBJ_STRING
};

pub const Obj = struct {type: ObjType};