const std = @import("std");
const testing = std.testing;

pub const DateTime = struct {
    year: u16,
    month: u8,   // 1-12
    day: u8,     // 1-31
    hour: u8,    // 0-23
    minute: u8,  // 0-59
    second: u8,  // 0-59
    millis: u16, // 0-999

    pub fn fromTimestamp(timestamp_ns: i128) DateTime {
        const timestamp = @divTrunc(timestamp_ns, std.time.ns_per_s);
        const millis: u16 = @intCast(@divTrunc(@mod(timestamp_ns, std.time.ns_per_s), std.time.ns_per_ms));

        const epoch_seconds = std.time.epoch.EpochSeconds{ .secs = @intCast(timestamp) };
        const epoch_day = epoch_seconds.getEpochDay();
        const year_day = epoch_day.calculateYearDay();
        const month_day = year_day.calculateMonthDay();
        const day_seconds = epoch_seconds.getDaySeconds();

        return DateTime{
            .year = @intCast(year_day.year),
            .month = month_day.month.numeric(),
            .day = month_day.day_index + 1,
            .hour = day_seconds.getHoursIntoDay(),
            .minute = day_seconds.getMinutesIntoHour(),
            .second = day_seconds.getSecondsIntoMinute(),
            .millis = millis,
        };
    }

    pub fn now() DateTime {
        return fromTimestamp(std.time.nanoTimestamp());
    }

    const FormatType = enum {
        unknown,
        empty,
        iso,
        log,
        us,
        time,
        date,
    };

    fn detectFormat(comptime fmt: []const u8) FormatType {
        if (std.mem.eql(u8, fmt, "")) return .empty;
        if (std.mem.eql(u8, fmt, "iso")) return .iso;
        if (std.mem.eql(u8, fmt, "log")) return .log;
        if (std.mem.eql(u8, fmt, "us")) return .us;
        if (std.mem.eql(u8, fmt, "time")) return .time;
        if (std.mem.eql(u8, fmt, "date")) return .date;
        return .unknown;
    }

    pub fn format(
        self: DateTime,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;

        switch (comptime detectFormat(fmt)) {
            .iso, .empty, .unknown => {
                try writer.print("{d:4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}", .{
                    self.year, self.month, self.day, self.hour, self.minute, self.second, self.millis
                });
            },
            .log => {
                try writer.print("{d:4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}", .{
                    self.year, self.month, self.day, self.hour, self.minute, self.second, self.millis
                });
            },
            .us => {
                try writer.print("{d}/{d}/{d} {d}:{d:0>2}:{d:0>2}", .{
                    self.month, self.day, self.year, self.hour, self.minute, self.second
                });
            },
            .time => {
                try writer.print("{d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}", .{
                    self.hour, self.minute, self.second, self.millis
                });
            },
            .date => {
                try writer.print("{d:4}-{d:0>2}-{d:0>2}", .{
                    self.year, self.month, self.day
                });
            },
        }
    }
};

test "DateTime fromTimestamp basic" {
    // Known timestamp: 2023-12-25 10:30:45.123 UTC
    const timestamp_ns: i128 = 1703500245123000000;
    const dt = DateTime.fromTimestamp(timestamp_ns);

    try testing.expectEqual(@as(u16, 2023), dt.year);
    try testing.expectEqual(@as(u8, 12), dt.month);
    try testing.expectEqual(@as(u8, 25), dt.day);
    try testing.expectEqual(@as(u8, 10), dt.hour);
    try testing.expectEqual(@as(u8, 30), dt.minute);
    try testing.expectEqual(@as(u8, 45), dt.second);
    try testing.expectEqual(@as(u16, 123), dt.millis);
}

test "DateTime now" {
    const dt = DateTime.now();

    try testing.expect(dt.year >= 2025);
    try testing.expect(dt.month >= 1 and dt.month <= 12);
    try testing.expect(dt.day >= 1 and dt.day <= 31);
    try testing.expect(dt.hour <= 23);
    try testing.expect(dt.minute <= 59);
    try testing.expect(dt.second <= 59);
    try testing.expect(dt.millis <= 999);
}

test "DateTime custom format - default" {
    const dt = DateTime{
        .year = 2023,
        .month = 12,
        .day = 25,
        .hour = 10,
        .minute = 30,
        .second = 45,
        .millis = 123,
    };

    var buffer: [64]u8 = undefined;
    const result = try std.fmt.bufPrint(buffer[0..], "{}", .{dt});
    try testing.expectEqualStrings("2023-12-25T10:30:45.123", result);
}

test "DateTime custom format - iso" {
    const dt = DateTime{
        .year = 2023,
        .month = 12,
        .day = 25,
        .hour = 10,
        .minute = 30,
        .second = 45,
        .millis = 123,
    };

    var buffer: [64]u8 = undefined;
    const result = try std.fmt.bufPrint(buffer[0..], "{iso}", .{dt});
    try testing.expectEqualStrings("2023-12-25T10:30:45.123", result);
}

test "DateTime custom format - log" {
    const dt = DateTime{
        .year = 2023,
        .month = 12,
        .day = 25,
        .hour = 10,
        .minute = 30,
        .second = 45,
        .millis = 123,
    };

    var buffer: [64]u8 = undefined;
    const result = try std.fmt.bufPrint(buffer[0..], "{log}", .{dt});
    try testing.expectEqualStrings("2023-12-25 10:30:45.123", result);
}

test "DateTime custom format - time only" {
    const dt = DateTime{
        .year = 2023,
        .month = 12,
        .day = 25,
        .hour = 10,
        .minute = 30,
        .second = 45,
        .millis = 123,
    };

    var buffer: [64]u8 = undefined;
    const result = try std.fmt.bufPrint(buffer[0..], "{time}", .{dt});
    try testing.expectEqualStrings("10:30:45.123", result);
}

test "DateTime custom format - date only" {
    const dt = DateTime{
        .year = 2023,
        .month = 12,
        .day = 25,
        .hour = 10,
        .minute = 30,
        .second = 45,
        .millis = 123,
    };

    var buffer: [64]u8 = undefined;
    const result = try std.fmt.bufPrint(buffer[0..], "{date}", .{dt});
    try testing.expectEqualStrings("2023-12-25", result);
}

test "DateTime edge cases - single digits" {
    const dt = DateTime{
        .year = 2023,
        .month = 1,
        .day = 5,
        .hour = 9,
        .minute = 3,
        .second = 7,
        .millis = 45,
    };

    var buffer: [64]u8 = undefined;
    const result = try std.fmt.bufPrint(buffer[0..], "{}", .{dt});
    try testing.expectEqualStrings("2023-01-05T09:03:07.045", result);
}
