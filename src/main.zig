const std = @import("std");
const dataset = @import("readTable.zig");
const uniqueValueCounter = @import("countUniqueValues.zig");
const entropyUtil = @import("entropyUtil.zig");
const structure = @import("structures.zig");
const decisionTreeUtil = @import("decisionTreeUtil.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator_instance = gpa.allocator(); // method returns a value
    const allocator = &allocator_instance; // required is a pointer
    const records = try dataset.readDataset(allocator, "resources/data.txt");
    // try analysis(allocator, records);
    std.debug.print("\nstarting\n", .{});
    //building decision tree
    const decisions = try dataset.readDecisions(allocator, records);

    const root = try decisionTreeUtil.buildTree(allocator, records, decisions, getMockAttributeAvailability(records));
    std.debug.print("\nThe tree has been built\n", .{});
    printTree(root, 0);

    // freeTree(allocator, root);
    // allocator.free(records);
    // allocator.free(decisions);
}

fn getMockAttributeAvailability( records: []const structure.Record) []bool {
    var mockAvailabity: [16]bool = undefined;
    const attributeNum = records[0].attributeCount;
    for (mockAvailabity[0..attributeNum]) |*slot| slot.* = true;
    return mockAvailabity[0..attributeNum];
}

fn printTree(node: *structure.TreeNode, indent: usize) void {
    for (0..indent) |_| {
        std.debug.print(" ", .{});
    }

    switch (node.*) {
        .Leaf => |leaf| {
            std.debug.print("-> decision {d}\n", .{ leaf.decision });
        },
        .Internal => |inNode| {
            std.debug.print("[A{d}]\n", .{ inNode.attributeIndex });
            var it = inNode.children.iterator();
            while (it.next()) |entry| {
                const value = entry.key_ptr.*;
                for (0..indent+4) |_| std.debug.print(" ", .{});
                std.debug.print("value {d}:\n", .{ value });
                printTree(entry.value_ptr.*, indent + 4);
            }
        },
    }
}


fn analysis(allocator: *std.mem.Allocator, records: []const structure.Record) !void {
    std.debug.print("Loaded {} records\n", .{records.len});

    for (records, 0..) |r, idx| {
        std.debug.print("Record {}: ", .{idx});
        for (r.attributes[0..r.attributeCount]) |a| {
            std.debug.print("{} ", .{a});
        }
        std.debug.print("=> decision: {}\n", .{r.decision});
    }

    std.debug.print("\n", .{});

    const maps = try uniqueValueCounter.countValueOccurrencesPerAttribute(allocator, records, records[0].attributeCount);

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

    const entropy = try entropyUtil.calculateEntropy(allocator, decisions);
    std.debug.print("\nSimple entropy = {d}\n", .{entropy});

    // Info(Ai, Tj)
    const attributesEntropies = try entropyUtil.infoXT(allocator, records, decisions);
    for (attributesEntropies, 0..) |e, i| {
        std.debug.print("Entropy for attribute {} = {d}\n", .{ i, e });
    }
    std.debug.print("\n", .{});

    // Gain(Ai, Tj)
    const attributesGains = try entropyUtil.gainXT(allocator, entropy, attributesEntropies);
    for (attributesGains, 0..) |g, i| {
        std.debug.print("Gain for attribute {} = {d}\n", .{ i, g });
    }
    std.debug.print("\n", .{});
    const bestAttributeIndex = try entropyUtil.getMaxAttributeIndex(attributesGains);
    std.debug.print("The attribute {d} has the best gain: {d}\n", .{ bestAttributeIndex, attributesGains[bestAttributeIndex] });
    std.debug.print("\n", .{});

    const splitInfo = try entropyUtil.splitInfoXT(allocator, records, decisions);
    for (splitInfo, 0..) |info, i| {
        std.debug.print("Split information for attribute {} = {d}\n", .{ i, info });
    }
    std.debug.print("\n", .{});

    const gainRatio = try entropyUtil.gainRatioXT(allocator, attributesGains, splitInfo);
    for (gainRatio, 0..) |ratio, i| {
        std.debug.print("Gain ratio for attribute {} = {d}\n", .{ i, ratio });
    }
    std.debug.print("\n", .{});
    const bestRatioIndex = try entropyUtil.getMaxAttributeIndex(gainRatio);
    std.debug.print("The attribute {d} has the best ratio: {d}\n", .{ bestRatioIndex, gainRatio[bestRatioIndex] });
    std.debug.print("\n", .{});
}
