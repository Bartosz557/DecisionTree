pub const MAX_ATTRS = 16;

pub const Record = struct {
    attributes: [MAX_ATTRS]u8,
    attribute_count: usize,
    decision: u8,
};
