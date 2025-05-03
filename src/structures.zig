const std = @import("std");

pub const Record = struct {
    attributes: [16]u8,
    attributeCount: usize,
    decision: u8,
};

pub const TreeNode = union(enum) {
    Internal: struct {
        attributeIndex: usize,
        children: std.AutoHashMap(u8, *TreeNode),
    },
    Leaf: struct {
        decision: u8,
    },
};

