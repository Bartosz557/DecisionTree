const std = @import("std");
const structure = @import("recordStruct.zig");

pub fn readDataset(allocator: *std.mem.Allocator, path: []const u8) ![]structure.Record {
    const fs = std.fs.cwd();
    const file = try fs.openFile(path, .{});
    defer file.close();

    const reader = file.reader();
    var buf = [_]u8{0} ** 1024;

    var records = std.ArrayList(structure.Record).init(allocator.*);

    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var tokenizer = std.mem.tokenizeAny(u8, line, ";");
        var record = structure.Record{
            .attributes = undefined,
            .attribute_count = 0,
            .decision = 0,
        };

        var i: usize = 0;
        var skip_line = false;

        while (tokenizer.next()) |token| {
            const cleaned = std.mem.trim(u8, token, " \r\n");
            const value = std.fmt.parseInt(u8, cleaned, 10) catch |err| {
                std.debug.print("Invalid token `{s}`: {}\n", .{ token, err });
                skip_line = true;
                break;
            };

            if (tokenizer.peek() == null) {
                record.decision = value;
            } else {
                record.attributes[i] = value;
                i += 1;
            }
        }

        if (!skip_line) {
            record.attribute_count = i;
            try records.append(record);
        }
    }

    return records.toOwnedSlice();
}


pub fn readDecisions(allocator: *std.mem.Allocator, records: []const structure.Record) ![]u8 {
    const out = try allocator.alloc(u8, records.len);
    for (records, 0..) |r, i| {
        out[i] = r.decision;
    }
    return out;
}
