const std = @import("std");
const dataset = @import("readTable.zig");
const uniqueValueCounter = @import("countUniqueValues.zig");
const entropyUtil = @import("entropyUtil.zig");
const structure = @import("structures.zig");
const decisionTreeUtil = @import("decisionTreeUtil.zig");


pub fn buildTree(allocator: *std.mem.Allocator, records: []const structure.Record,  decisions: []const u8, isAttributeAvailable: []bool) !*structure.TreeNode {

    std.debug.print("\nBuilding a new tree node\n", .{});
    for (decisions) |d| {
        std.debug.print("Decision: {}\n", .{d});
    }
    if(isPure(decisions)) {
        std.debug.print("\nPure decisions. Creating new leaf\n", .{});
        return try createLeaf(allocator, decisions[0]);
    }

    var anyLeft = false;
    for (isAttributeAvailable) |b| {
        if (b) { anyLeft = true; break; }
    }
    if (!anyLeft) {
        std.debug.print("\nNo attributes left. Creating new leaf\n", .{});
        return try createLeaf(allocator, try getMostCommonDecision(allocator, decisions));
    }


    const entropy = try entropyUtil.calculateEntropy(allocator, decisions);
    const attributesEntropies = try entropyUtil.infoXT(allocator, records, decisions);
    const attributesGains = try entropyUtil.gainXT(allocator, entropy, attributesEntropies);
    const splitInfo = try entropyUtil.splitInfoXT(allocator, records, decisions);
    const gainRatio = try entropyUtil.gainRatioXT(allocator, attributesGains, splitInfo);
    for (gainRatio, 0..) |ratio, i| {
        std.debug.print("Gain ratio for attribute {} = {d}\n", .{ i, ratio });
    }
    const bestRatioIndex = try entropyUtil.getMaxValueIndex(gainRatio, isAttributeAvailable);
    std.debug.print("Best Attribute index: {}\n", .{bestRatioIndex});

    var isNextAttributeAvailable = isAttributeAvailable;
    isNextAttributeAvailable[bestRatioIndex] = false;

    if (gainRatio[bestRatioIndex] == 0.0) {
        std.debug.print("\nBest Ratio equals 0. Creating new leaf\n", .{});
        return try createLeaf(allocator, try getMostCommonDecision(allocator, decisions));
    }



    const node = try createInternal(allocator, bestRatioIndex);

    const features = try entropyUtil.getFeatures(allocator, records, bestRatioIndex);
    defer allocator.free(features);
    var partitions = try entropyUtil.getPartitions(allocator, features, decisions);
    defer partitions.deinit();

    if (partitions.count() <= 1) {
            std.debug.print("\nPartition coun: {}. Creating new leaf\n", .{partitions.count()});
    return try createLeaf(allocator, try getMostCommonDecision(allocator, decisions));
    }

    for (features) |d| {
        std.debug.print("features: {}\n", .{d});
    }

    var it = partitions.iterator();
    while (it.next()) |entry| {
        std.debug.print("partition key: {}\n", .{entry.key_ptr.*});
        const partitionValue = entry.key_ptr.*;
        const decisionsSlice = try entry.value_ptr.*.toOwnedSlice();
        defer allocator.free(decisionsSlice);

        for (decisionsSlice) |d| {
            std.debug.print("values: {}\n", .{d});
        }


        const recordsSlice = try filterRecords(allocator, records, bestRatioIndex, partitionValue);
        defer allocator.free(recordsSlice);

        const child = try buildTree(allocator, recordsSlice, decisionsSlice, isNextAttributeAvailable);
        _ = try node.Internal.children.put(partitionValue, child); // '_ =' because put() returns value 
    }

    return node;

}

fn isPure(decisions: []const u8) bool {
    if (decisions.len <= 1) return true;
    const first = decisions[0];
    for (decisions[1..]) |d| {
        if (d != first) 
        return false;
    }
    return true;
}

pub fn createInternal(allocator: *std.mem.Allocator, bestRatioIndex: usize) !*structure.TreeNode {
    const node = try allocator.create(structure.TreeNode);
    node.* = structure.TreeNode{ .Internal = .{
            .attributeIndex = bestRatioIndex,
            .children = std.AutoHashMap(u8, *structure.TreeNode).init(allocator.*),
        },
    };
    std.debug.print("\nCreating new child node\n", .{});
    return node;
}

fn createLeaf(allocator: *std.mem.Allocator, decision: u8) !*structure.TreeNode {
    const node = try allocator.create(structure.TreeNode);
    node.* = structure.TreeNode{ .Leaf = .{ .decision = decision}};
    return node;
}

fn getMostCommonDecision(allocator: *std.mem.Allocator, decisions: []const u8) !u8 {
    var map = std.AutoHashMap(u8, usize).init(allocator.*);
    defer map.deinit();
    for (decisions) |decision| {
        const entry = try map.getOrPut(decision);
        if (!entry.found_existing) {
            entry.value_ptr.* = 1;
        } else {
            entry.value_ptr.* += 1;
        }
    }
    var bestValue: u8 = 0;
    var bestCount: usize = 0;
    var it = map.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.* > bestCount) {
            bestCount = entry.value_ptr.*;
            bestValue = entry.key_ptr.*;
        }
    }
    return bestValue;
}

fn filterRecords(allocator: *std.mem.Allocator, records: []const structure.Record, bestRatioIndex: usize, partitionValue: u8) ![]const structure.Record {
    var matchCount: usize = 0;
    for (records) |record| {
        if (record.attributes[bestRatioIndex] == partitionValue) {
            matchCount += 1;
        }
    }
    var filteredRecords = try allocator.alloc(structure.Record, matchCount);
    var filteredRecordIndex: usize = 0;
    for (records) |record| {
        if(record.attributes[bestRatioIndex] == partitionValue){
            filteredRecords[filteredRecordIndex] = record;
            filteredRecordIndex+=1;
        }
    }
    return filteredRecords;
}