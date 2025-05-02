const std = @import("std");
const structure = @import("recordStruct.zig");

pub fn infoXT(allocator: *std.mem.Allocator, records: []const structure.Record, decisions: []const u8) ![]f64 {
    var attributesEntropies = try allocator.alloc(f64, records[0].attribute_count);
    var freeOnError = true;
    defer if (freeOnError) allocator.free(attributesEntropies);
    // Iterating Ai
    for (0..records[0].attribute_count) |i| {
        // Iterating through record ith attribute
        // Features = column values of each Attribute - I values
        var features = try allocator.alloc(u8, records.len);
        defer allocator.free(features);
        for (records, 0..) |record, j| { // Rows = J
            features[j] = record.attributes[i];
        }
        // Partition = Tj
        var partitions = try getPartitions(allocator, features, decisions);
        defer partitions.deinit();
        const attributeEntropy: f64 = try getAttributeEntropy(allocator, partitions, records.len);
        attributesEntropies[i] = attributeEntropy;
    }
    freeOnError = false;
    return attributesEntropies;
}

fn getPartitions(allocator: *std.mem.Allocator, features: []const u8, decisions: []const u8) !std.AutoHashMap(u8, std.ArrayList(u8)) {
    var partitions = std.AutoHashMap(u8, std.ArrayList(u8)).init(allocator.*);
    for (features, 0..) |feature, i| {
        const decision = decisions[i];
        const entry = try partitions.getOrPut(feature);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(u8).init(allocator.*);
        }
        try entry.value_ptr.*.append(decision);
    }
    return partitions;
}

fn getAttributeEntropy(allocator: *std.mem.Allocator, partitions: std.AutoHashMap(u8, std.ArrayList(u8)), featuresNum: usize) !f64 {
    var it = partitions.iterator();
    var partitionEntropy: f64 = 0;
    while (it.next()) |entry| {
        const slice = try entry.value_ptr.*.toOwnedSlice();
        defer allocator.free(slice);
        partitionEntropy += (try calculateEntropy(allocator, slice)) * @as(f64, @floatFromInt(slice.len));
    }
    return partitionEntropy / @as(f64, @floatFromInt(featuresNum));
}

pub fn calculateEntropy(allocator: *std.mem.Allocator, decisions: []const u8) !f64 {
    var map = std.AutoHashMap(u8, usize).init(allocator.*);
    defer map.deinit();

    for (decisions) |d| {
        const entry = try map.getOrPut(d);
        if (!entry.found_existing) {
            entry.value_ptr.* = 1;
        } else {
            entry.value_ptr.* += 1;
        }
    }

    const total = decisions.len;
    var entropy: f64 = 0.0;

    var it = map.iterator();
    while (it.next()) |entry| {
        const count = entry.value_ptr.*;
        const p = @as(f64, @floatFromInt(count)) / @as(f64, @floatFromInt(total));
        entropy -= p * std.math.log2(p);
    }

    return entropy;
}
