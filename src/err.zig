const std = @import("std");

pub fn errorSetContains(ErrorSet: type, e: anyerror) bool {
    const bits, const min, const max = comptime blk: {
        var min = std.math.maxInt(u16);
        var max = 0;
        for (@typeInfo(ErrorSet).error_set.?) |err| {
            max = @max(max, @intFromError(@field(anyerror, err.name)));
            min = @min(min, @intFromError(@field(anyerror, err.name)));
        }
        max += 1;
        var bits = std.StaticBitSet(max - min).initEmpty();
        for (@typeInfo(ErrorSet).error_set.?) |err| bits.set(@intFromError(@field(anyerror, err.name)) - min);
        break :blk .{ bits, min, max };
    };
    const i = @intFromError(e);
    return min <= i and i < max and bits.isSet(i - min);
}

const MyErrors = error{
    OpenVersionNotFound,
    CloseNotFound,
    Bug,
};

test errorSetContains {
    try std.testing.expect(errorSetContains(MyErrors, error.OpenVersionNotFound));
    try std.testing.expect(errorSetContains(MyErrors, error.Bug));
    try std.testing.expect(!errorSetContains(MyErrors, error.Foo));
    try std.testing.expect(!errorSetContains(MyErrors, error.OutOfMemory));
}
