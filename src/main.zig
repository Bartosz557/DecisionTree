const std = @import("std");
const dataset = @import("readTable.zig");
const uniqueValueCounter = @import("countUniqueValues.zig");
const entropyUtil = @import("entropyUtil.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator_instance = gpa.allocator(); // method returns a value
    const allocator = &allocator_instance; // required is a pointer

    const records = try dataset.readDataset(allocator, "resources/data.txt");
    std.debug.print("Loaded {} records\n", .{records.len});

    for (records, 0..) |r, idx| {
        std.debug.print("Record {}: ", .{idx});
        for (r.attributes[0..r.attribute_count]) |a| {
            std.debug.print("{} ", .{a});
        }
        std.debug.print("=> decision: {}\n", .{r.decision});
    }

    std.debug.print("\n", .{});

    const maps = try uniqueValueCounter.countValueOccurrencesPerAttribute(allocator, records, records[0].attribute_count);

    for (maps, 0..) |*map, i| {
        std.debug.print("Attribute {} -> {} unique values\n", .{ i, map.count() });

        var keys = try allocator.alloc(u8, map.count());
        var k: usize = 0;
        var it = map.iterator();
        while (it.next()) |entry| {
            keys[k] = entry.key_ptr.*;
            k += 1;
        }

        std.sort.heap(u8, keys, {}, std.sort.asc(u8));

        for (keys) |key| {
            const count = map.get(key).?;
            std.debug.print("  value {} -> {} times\n", .{ key, count });
        }

        allocator.free(keys);
    }

    const decisions = try dataset.readDecisions(allocator, records);
    std.debug.print("\nDecisions Found:\n", .{});
    for (decisions) |decision| {
        std.debug.print("{}\n", .{decision});
    }
    const entropy = try entropyUtil.calculateEntropy(allocator, decisions);
    std.debug.print("\nSimple entropy = {d}\n", .{entropy});

    // Info(Ai, Tj)
    const attributesEntropies = try entropyUtil.infoXT(allocator, records, decisions);
        for (attributesEntropies, 0..) |e, i| {
        std.debug.print("Entropy for attribute {} = {d}\n", .{i, e});
    }
    std.debug.print("\n", .{});
}