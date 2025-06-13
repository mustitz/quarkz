const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;
const Location = std.builtin.SourceLocation;
const DList = @import("dlist.zig").DList;

pub const Level = enum(u8) {
    trace = 0,
    debug,
    info,
    notice,
    warn,
    err,
};

const Coordinates = struct {
    ts: i128,
    pid: u32,
    tid: u32,

    pub fn init() Coordinates {
        return Coordinates{
            .ts = std.time.nanoTimestamp(),
            .pid = @intCast(std.os.linux.getpid()),
            .tid = @intCast(std.os.linux.gettid()),
        };
    }
};

const Nucleon = struct {
    const ALIGN = 16;
    const OGLUON = std.mem.alignForward(usize, @sizeOf(Nucleon), ALIGN);

    level: Level,
    msg: []const u8,
    coords: Coordinates,
    loc: Location,
    link: DList,
    mem: [] align(ALIGN) u8,

    pub fn create(
        allocator: Allocator,
        level: Level,
        loc: Location,
        comptime msg: []const u8,
        gluon: anytype,
    ) !*Nucleon {
        const ALIGNMENT = comptime std.mem.Alignment.fromByteUnits(ALIGN);

        const zgluon = @sizeOf(@TypeOf(gluon));
        const ogluon = Nucleon.OGLUON;
        const sz = ogluon + zgluon;

        const mem = try allocator.alignedAlloc(u8, ALIGNMENT, sz);

        const nucleon: *Nucleon = @ptrCast(mem.ptr);
        nucleon.level = level;
        nucleon.msg = msg;
        nucleon.coords = Coordinates.init();
        nucleon.loc = loc;
        nucleon.mem = mem;
        nucleon.link.init();

        const pgluon = mem.ptr + ogluon;
        const bytes = std.mem.asBytes(&gluon);
        @memcpy(pgluon[0..bytes.len], bytes);

        return nucleon;
    }

    pub fn createFmt(
        allocator: Allocator,
        level: Level,
        loc: Location,
        comptime fmt: []const u8,
        args: anytype,
        gluon: anytype,
    ) !*Nucleon {
        const ALIGNMENT = comptime std.mem.Alignment.fromByteUnits(ALIGN);

        const zgluon = @sizeOf(@TypeOf(gluon));
        const zmsg = std.fmt.count(fmt, args) + 1;

        const ogluon = Nucleon.OGLUON;
        const omsg = std.mem.alignForward(usize, ogluon + zgluon, ALIGN);
        const sz = omsg + zmsg;

        const mem = try allocator.alignedAlloc(u8, ALIGNMENT, sz);

        const nucleon: *Nucleon = @ptrCast(mem.ptr);
        nucleon.level = level;
        nucleon.coords = Coordinates.init();
        nucleon.loc = loc;
        nucleon.mem = mem;
        nucleon.link.init();

        const pgluon = mem.ptr + ogluon;
        const bytes = std.mem.asBytes(&gluon);
        @memcpy(pgluon[0..bytes.len], bytes);

        const pmsg = mem.ptr + omsg;
        _ = try std.fmt.bufPrint(pmsg[0..zmsg-1], fmt, args);
        pmsg[zmsg-1] = 0;
        nucleon.msg = pmsg[0..zmsg-1];

        return nucleon;
    }

    pub fn destroy(self: *Nucleon, allocator: Allocator) void {
        allocator.free(self.mem);
    }

    pub fn getGluon(self: *const Nucleon, comptime T: type) *const T {
        return @ptrCast(@alignCast(self.mem.ptr + OGLUON));
    }
};

pub const Atom = struct {
    name: []const u8,
    cosmos: *Cosmos,
    birthTs: i128,
    durationNs: u128,
    nucleons: DList,
    link: DList,

    pub fn create(name: []const u8, cosmos: *Cosmos) !*Atom {
        const atom = try cosmos.allocator.create(Atom);
        atom.name = name;
        atom.cosmos = cosmos;
        atom.birthTs = std.time.nanoTimestamp();
        atom.nucleons.init();
        atom.durationNs = 0;
        atom.link.init();
        return atom;
    }

    pub fn destroy(self: *Atom) void {
        var iter = self.nucleons.iterator();
        while (iter.next()) |node| {
            const nucleon = node.containerOf(Nucleon, "link");
            nucleon.destroy(self.cosmos.allocator);
        }
        self.link.remove();
        self.cosmos.allocator.destroy(self);
    }

    pub fn decay(self: *Atom) void {
        std.debug.assert(self.durationNs == 0);
        const duration = std.time.nanoTimestamp() - self.birthTs;
        std.debug.assert(duration >= 0);
        self.durationNs = @intCast(duration);
    }

    fn newNucleon(
        self: *Atom,
        level: Level,
        comptime msg: []const u8,
        gluon: anytype,
        loc: Location
    ) !void {
        const nucleon = try Nucleon.create(self.cosmos.allocator, level, loc, msg, gluon);
        self.nucleons.insertBefore(&nucleon.link);
    }

    fn newNucleonFmt(
        self: *Atom,
        level: Level,
        comptime fmt: []const u8,
        args: anytype,
        gluon: anytype,
        loc: Location
    ) !void {
        const nucleon = try Nucleon.createFmt(self.cosmos.allocator, level, loc, fmt, args, gluon);
        self.nucleons.insertBefore(&nucleon.link);
    }

    pub fn trace(self: *Atom, loc: Location, comptime msg: []const u8, gluon: anytype) void {
        self.newNucleon(.trace, msg, gluon, loc) catch {};
    }

    pub fn debug(self: *Atom, loc: Location, comptime msg: []const u8, gluon: anytype) void {
        self.newNucleon(.debug, msg, gluon, loc) catch {};
    }

    pub fn info(self: *Atom, loc: Location, comptime msg: []const u8, gluon: anytype) void {
        self.newNucleon(.info, msg, gluon, loc) catch {};
    }

    pub fn notice(self: *Atom, loc: Location, comptime msg: []const u8, gluon: anytype) void {
        self.newNucleon(.notice, msg, gluon, loc) catch {};
    }

    pub fn warn(self: *Atom, loc: Location, comptime msg: []const u8, gluon: anytype) void {
        self.newNucleon(.warn, msg, gluon, loc) catch {};
    }

    pub fn err(self: *Atom, loc: Location, comptime msg: []const u8, gluon: anytype) void {
        self.newNucleon(.err, msg, gluon, loc) catch {};
    }

    pub fn traceFmt(self: *Atom, loc: Location, comptime fmt: []const u8, args: anytype, gluon: anytype) void {
        self.newNucleonFmt(.trace, fmt, args, gluon, loc) catch {};
    }

    pub fn debugFmt(self: *Atom, loc: Location, comptime fmt: []const u8, args: anytype, gluon: anytype) void {
        self.newNucleonFmt(.debug, fmt, args, gluon, loc) catch {};
    }

    pub fn infoFmt(self: *Atom, loc: Location, comptime fmt: []const u8, args: anytype, gluon: anytype) void {
        self.newNucleonFmt(.info, fmt, args, gluon, loc) catch {};
    }

    pub fn noticeFmt(self: *Atom, loc: Location, comptime fmt: []const u8, args: anytype, gluon: anytype) void {
        self.newNucleonFmt(.info, fmt, args, gluon, loc) catch {};
    }

    pub fn warnFmt(self: *Atom, loc: Location, comptime fmt: []const u8, args: anytype, gluon: anytype) void {
        self.newNucleonFmt(.warn, fmt, args, gluon, loc) catch {};
    }

    pub fn errFmt(self: *Atom, loc: Location, comptime fmt: []const u8, args: anytype, gluon: anytype) void {
        self.newNucleonFmt(.err, fmt, args, gluon, loc) catch {};
    }
};

pub const Cosmos = struct {
    atoms: DList,
    allocator: Allocator,

    pub fn create(allocator: Allocator) !*Cosmos {
        const cosmos = try allocator.create(Cosmos);
        cosmos.atoms.init();
        cosmos.allocator = allocator;
        return cosmos;
    }

    pub fn destroy(self: *Cosmos) void {
        var iter = self.atoms.iterator();
        while (iter.next()) |node| {
            const atom = node.containerOf(Atom, "link");
            atom.destroy();
        }
        self.allocator.destroy(self);
    }

    pub fn newAtom(self: *Cosmos, name: []const u8) !*Atom {
        const atom = try Atom.create(name, self);
        self.atoms.insertBefore(&atom.link);
        return atom;
    }
};

test "two coords" {
    const coords1 = Coordinates.init();
    const coords2 = Coordinates.init();

    try testing.expectEqual(coords1.pid, coords2.pid);
    try testing.expectEqual(coords1.tid, coords2.tid);
    try testing.expect(coords2.ts > coords1.ts);
}

test "nucleon create and check fields" {
   const allocator = std.testing.allocator;
   const MAGIC_STR = "Spam message";

   const nucleon = try Nucleon.create(
       allocator,
       .info,
       @src(),
       MAGIC_STR,
       .{},
   );
   defer nucleon.destroy(allocator);

   try testing.expectEqual(.info, nucleon.level);
   try testing.expectEqualStrings(MAGIC_STR, nucleon.msg);
   try testing.expect(nucleon.coords.ts > 0);
   try testing.expect(nucleon.coords.pid > 0);
}

test "nucleon create with int gluon" {
    const MAGIC_STR = "🚀 i32 Test 🎭";
    const MAGIC_INT: i32 = 609;
    const allocator = std.testing.allocator;

    const nucleon = try Nucleon.create(
        allocator,
        .warn,
        @src(),
        MAGIC_STR,
        MAGIC_INT,
    );
    defer nucleon.destroy(allocator);

    try testing.expectEqual(.warn, nucleon.level);
    try testing.expectEqualStrings(MAGIC_STR, nucleon.msg);

    const gluon = nucleon.getGluon(i32);
    try testing.expectEqual(MAGIC_INT, gluon.*);
}

test "nucleon create fmt and check fields" {
   const allocator = std.testing.allocator;

   const nucleon = try Nucleon.createFmt(
       allocator,
       .info,
       @src(),
       "test msg: {}",
       .{42},
       .{},
   );
   defer nucleon.destroy(allocator);

   try testing.expectEqual(.info, nucleon.level);
   try testing.expectEqualStrings("test msg: 42", nucleon.msg);
   try testing.expect(nucleon.coords.ts > 0);
   try testing.expect(nucleon.coords.pid > 0);
}

test "nucleon create fmt with struct gluon" {
   const MyStruct = struct {
       id: u32,
       value: f64,
       flag: bool,
   };

   const MAGIC_STR = "🚀 struct Test 🎭";
   const MAGIC_STRUCT = MyStruct{
       .id = 42,
       .value = 3.14159,
       .flag = true,
   };
   const allocator = std.testing.allocator;

   const nucleon = try Nucleon.createFmt(
       allocator,
       .debug,
       @src(),
       MAGIC_STR,
       .{},
       MAGIC_STRUCT,
   );
   defer nucleon.destroy(allocator);

   try testing.expectEqual(.debug, nucleon.level);
   try testing.expectEqualStrings(MAGIC_STR, nucleon.msg);

   const gluon = nucleon.getGluon(MyStruct);
   try testing.expectEqual(MAGIC_STRUCT.id, gluon.id);
   try testing.expectEqual(MAGIC_STRUCT.value, gluon.value);
   try testing.expectEqual(MAGIC_STRUCT.flag, gluon.flag);
}

test "atom create, decay and destroy" {
    const name = "Hg";

    const cosmos = try Cosmos.create(std.testing.allocator);
    defer cosmos.destroy();

    const atom = try cosmos.newAtom(name);
    defer atom.destroy();

    try testing.expect(atom.birthTs > 0);
    try testing.expectEqualStrings(name, atom.name);
    try testing.expect(atom.nucleons.isEmpty());
    try testing.expectEqual(0, atom.durationNs);

    atom.decay();
    try testing.expect(atom.durationNs > 0);
}

test "cosmos create and destroy" {
    const allocator = std.testing.allocator;

    const cosmos = try Cosmos.create(allocator);
    defer cosmos.destroy();

    try testing.expect(cosmos.atoms.isEmpty());
}

test "atom logging methods with static messages" {
    const cosmos = try Cosmos.create(std.testing.allocator);
    defer cosmos.destroy();

    const atom = try cosmos.newAtom("TestAtom");

    const debug_gluon: i32 = 42;
    const info_gluon = .{ .status = "ok" };
    const err_gluon = .{ .code = 500, .desc = "server error" };

    atom.trace(@src(), "trace message", .{});
    atom.debug(@src(), "debug message", debug_gluon);
    atom.info(@src(), "info message", info_gluon);
    atom.notice(@src(), "notice message", .{});
    atom.warn(@src(), "warn message", true);
    atom.err(@src(), "error message", err_gluon);

    try testing.expectEqual(6, atom.nucleons.count() - 1); // -1 for the head node

    var iter = atom.nucleons.iterator();

    const n1 = iter.next().?.containerOf(Nucleon, "link");
    try testing.expectEqual(.trace, n1.level);
    try testing.expectEqualStrings("trace message", n1.msg);

    const n2 = iter.next().?.containerOf(Nucleon, "link");
    try testing.expectEqual(.debug, n2.level);
    try testing.expectEqualStrings("debug message", n2.msg);
    try testing.expectEqual(debug_gluon, n2.getGluon(i32).*);

    const n3 = iter.next().?.containerOf(Nucleon, "link");
    try testing.expectEqual(.info, n3.level);
    try testing.expectEqualStrings("info message", n3.msg);
    const n3_gluon = n3.getGluon(@TypeOf(info_gluon));
    try testing.expectEqualStrings(info_gluon.status, n3_gluon.status);

    const n4 = iter.next().?.containerOf(Nucleon, "link");
    try testing.expectEqual(.notice, n4.level);
    try testing.expectEqualStrings("notice message", n4.msg);

    const n5 = iter.next().?.containerOf(Nucleon, "link");
    try testing.expectEqual(.warn, n5.level);
    try testing.expectEqualStrings("warn message", n5.msg);
    try testing.expectEqual(true, n5.getGluon(bool).*);

    const n6 = iter.next().?.containerOf(Nucleon, "link");
    try testing.expectEqual(.err, n6.level);
    try testing.expectEqualStrings("error message", n6.msg);
    const n6_gluon = n6.getGluon(@TypeOf(err_gluon));
    try testing.expectEqual(err_gluon.code, n6_gluon.code);
    try testing.expectEqualStrings(err_gluon.desc, n6_gluon.desc);
}

test "atom formatting methods without gluons using two atoms" {
    const cosmos = try Cosmos.create(std.testing.allocator);
    defer cosmos.destroy();

    const atom1 = try cosmos.newAtom("FirstAtom");
    const atom2 = try cosmos.newAtom("SecondAtom");

    atom1.traceFmt(@src(), "trace count: {}", .{1}, .{});
    atom1.debugFmt(@src(), "debug value: {d:.2}", .{3.14159}, .{});
    atom1.infoFmt(@src(), "info status: {s}", .{"active"}, .{});

    atom2.warnFmt(@src(), "warn level: {} threshold: {}", .{5, 100}, .{});
    atom2.errFmt(@src(), "error code: {d} message: {s}", .{404, "not found"}, .{});

    try testing.expectEqual(3, atom1.nucleons.count() - 1); // -1 for the head node
    try testing.expectEqual(2, atom2.nucleons.count() - 1); // -1 for the head node



    var iter1 = atom1.nucleons.iterator();

    const n1 = iter1.next().?.containerOf(Nucleon, "link");
    try testing.expectEqual(.trace, n1.level);
    try testing.expectEqualStrings("trace count: 1", n1.msg);

    const n2 = iter1.next().?.containerOf(Nucleon, "link");
    try testing.expectEqual(.debug, n2.level);
    try testing.expectEqualStrings("debug value: 3.14", n2.msg);

    const n3 = iter1.next().?.containerOf(Nucleon, "link");
    try testing.expectEqual(.info, n3.level);
    try testing.expectEqualStrings("info status: active", n3.msg);

    var iter2 = atom2.nucleons.iterator();



    const n4 = iter2.next().?.containerOf(Nucleon, "link");
    try testing.expectEqual(.warn, n4.level);
    try testing.expectEqualStrings("warn level: 5 threshold: 100", n4.msg);

    const n5 = iter2.next().?.containerOf(Nucleon, "link");
    try testing.expectEqual(.err, n5.level);
    try testing.expectEqualStrings("error code: 404 message: not found", n5.msg);
}
