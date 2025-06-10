pub const dlist = @import("dlist.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
