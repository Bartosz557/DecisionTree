const std = @import("std");
const structure = @import("structures.zig");

pub fn countValueOccurrencesPerAttribute(allocator: *std.mem.Allocator, records: []const structure.Record, attr_count: usize) ![]std.AutoHashMap(u8, usize) {
    var maps = try allocator.alloc(std.AutoHashMap(u8, usize), attr_count);

    for (maps) |*map| {
        map.* = std.AutoHashMap(u8, usize).init(allocator.*);
    }

    for (records) |r| {
        for (r.attributes[0..r.attributeCount], 0..) |value, i| {
            const map = &maps[i];
            const entry = try map.getOrPut(value);
            if (!entry.found_existing) {
                entry.value_ptr.* = 1;
            } else {
                entry.value_ptr.* += 1;
            }
        }
    }
    return maps;
}
