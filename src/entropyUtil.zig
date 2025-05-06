const std = @import("std");
const structure = @import("structures.zig");

pub fn infoXT(allocator: *std.mem.Allocator, records: []const structure.Record, decisions: []const u8) ![]f64 {
    var attributesEntropies = try allocator.alloc(f64, records[0].attributeCount);
    var freeOnError = true;
    defer if (freeOnError) allocator.free(attributesEntropies);
    // Iterating Ai
    for (0..records[0].attributeCount) |i| {
        // Iterating through record ith attribute
        // Features = column values of each Attribute - I values
        const features = try getFeatures(allocator, records, i);
        defer allocator.free(features);
        // Partition = Tj
        var partitions = try getPartitions(allocator, features, decisions);
        defer partitions.deinit();
        const attributeEntropy: f64 = try getAttributeEntropy(allocator, partitions, records.len);
        attributesEntropies[i] = attributeEntropy;
    }
    freeOnError = false;
    return attributesEntropies;
}

pub fn getFeatures(allocator: *std.mem.Allocator, records: []const structure.Record, aIndex: usize) ![]u8 {
    var features = try allocator.alloc(u8, records.len);
    for (records, 0..) |record, j| { // Rows = J
        features[j] = record.attributes[aIndex];
    }
    return features;
}

pub fn getPartitions(allocator: *std.mem.Allocator, features: []const u8, decisions: []const u8) !std.AutoHashMap(u8, std.ArrayList(u8)) {
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

pub fn gainXT(allocator: *std.mem.Allocator, entropy: f64, attributesEntropies: []const f64) ![]const f64 {
    var attributesGains = try allocator.alloc(f64, attributesEntropies.len);
    for (attributesEntropies, 0..) |aEntropy, i| {
        attributesGains[i] = entropy - aEntropy;
    }
    return attributesGains;
}

// used only for analysis in main.zig
pub fn getMaxAttributeIndex(values: []const f64) !usize {
    var maxIndex: usize = 0;
    var maxVal: f64 = values[0];
    for (values, 0..) |value, i| {
        if (value > maxVal) {
            maxVal = value;
            maxIndex = i;
        }
    }
    return maxIndex;
}

pub fn getMaxValueIndex(values: []const f64, isAttributeAvailable: [structure.MAX_ATTRS]bool) !usize {
    for (isAttributeAvailable, 0..) |isAvailable, i| {
        std.debug.print("Attribute {} is available?: {}", .{i, isAvailable});
    }
    var bestIndex: usize = undefined;
    for (isAttributeAvailable, 0..) |isAvailable, i| {
        if (isAvailable) {
            bestIndex = i;
            break;
        }
    }

    var bestValue = values[bestIndex];
    
    for (isAttributeAvailable, 0..) |isAvailable, i| {
        if ((isAvailable) and (values[i] > bestValue)) {
            bestValue = values[i];
            bestIndex = i;
        }
    }

    return bestIndex;
}

pub fn splitInfoXT(allocator: *std.mem.Allocator, records: []const structure.Record, decisions: []const u8) ![]const f64 {
    var splitInfo = try allocator.alloc(f64, records[0].attributeCount);
    for (0..records[0].attributeCount) |i| {
        var attributeSplitInfo: f64 = 0;
        const features = try getFeatures(allocator, records, i);
        defer allocator.free(features);
        var partitions = try getPartitions(allocator, features, decisions);
        defer partitions.deinit();
        var it = partitions.iterator();
        while (it.next()) |entry| {
            const slice = try entry.value_ptr.*.toOwnedSlice();
            defer allocator.free(slice);
            const partitionWeight: f64 = @as(f64, @floatFromInt(slice.len)) / @as(f64, @floatFromInt(records.len));
            attributeSplitInfo -= partitionWeight * std.math.log2(partitionWeight);
        }
        splitInfo[i] = attributeSplitInfo;
    }
    return splitInfo;
}
pub fn gainRatioXT(allocator: *std.mem.Allocator, gains: []const f64, splitInfo: []const f64) ![]const f64 {
    var gainsRatios = try allocator.alloc(f64, gains.len);
    for (gains, 0..) |gain, i| {
            if (splitInfo[i] == 0.0) {
        gainsRatios[i] = 0.0;
    } else {
        gainsRatios[i] = gain / splitInfo[i];
    }
    }
    return gainsRatios;
}
