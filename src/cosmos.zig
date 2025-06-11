const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;
const Location = std.builtin.SourceLocation;
const DList = @import("dlist.zig").DList;

pub const Level = enum(u8) {
    trace = 0,
    debug,
    info,
    warn,
    err,
};

const Coordinates = struct {
    ts: i128,
    pid: i32,
    tid: i32,
};

pub const Nucleon = struct {
    const ALIGN = 16;
    const OGLUON = std.mem.alignForward(usize, @sizeOf(Nucleon), ALIGN);

    level: Level,
    msg: []const u8,
    coords: Coordinates,
    loc: Location,
    link: DList,
    mem: [] align(ALIGN) u8,

    pub fn getGluon(self: *const Nucleon, comptime T: type) *const T {
        return @ptrCast(@alignCast(self.mem.ptr + OGLUON));
    }

    pub fn destroy(self: *Nucleon, allocator: Allocator) void {
        allocator.free(self.mem);
    }
};

pub const Atom = struct {
    name: []const u8,
    birthTs: i128,
    durationNs: u128,
    nucleons: DList,
    link: DList,

    pub fn destroy(self: *Atom, allocator: Allocator) void {
        var iter = self.nucleons.iterator();
        while (iter.next()) |node| {
            const nucleon = node.containerOf(Nucleon, "link");
            nucleon.destroy(allocator);
        }
        allocator.destroy(self);
    }

    pub fn decay(self: *Atom) void {
        std.debug.assert(self.durationNs == 0);
        const duration = std.time.nanoTimestamp() - self.birthTs;
        std.debug.assert(duration >= 0);
        self.durationNs = @intCast(duration);
    }
};

fn coords() Coordinates {
    return Coordinates{
        .ts = std.time.nanoTimestamp(),
        .pid = std.os.linux.getpid(),
        .tid = std.os.linux.gettid(),
    };
}

pub fn createNucleon(
    allocator: Allocator,
    level: Level,
    loc: Location,
    comptime msg: []const u8,
    gluon: anytype,
) !*Nucleon {
    const ALIGN = Nucleon.ALIGN;
    const ALIGNMENT = comptime std.mem.Alignment.fromByteUnits(ALIGN);

    const zgluon = @sizeOf(@TypeOf(gluon));
    const ogluon = Nucleon.OGLUON;
    const sz = ogluon + zgluon;

    const mem = try allocator.alignedAlloc(u8, ALIGNMENT, sz);

    const nucleon: *Nucleon = @ptrCast(mem.ptr);
    nucleon.level = level;
    nucleon.msg = msg;
    nucleon.coords = coords();
    nucleon.loc = loc;
    nucleon.mem = mem;
    nucleon.link.init();

    const pgluon = mem.ptr + ogluon;
    const bytes = std.mem.asBytes(&gluon);
    @memcpy(pgluon[0..bytes.len], bytes);

    return nucleon;
}

pub fn createNucleonFmt(
    allocator: Allocator,
    level: Level,
    loc: Location,
    comptime fmt: []const u8,
    args: anytype,
    gluon: anytype,
) !*Nucleon {
    const ALIGN = Nucleon.ALIGN;
    const ALIGNMENT = comptime std.mem.Alignment.fromByteUnits(ALIGN);

    const zgluon = @sizeOf(@TypeOf(gluon));
    const zmsg = std.fmt.count(fmt, args) + 1;

    const ogluon = Nucleon.OGLUON;
    const omsg = std.mem.alignForward(usize, ogluon + zgluon, ALIGN);
    const sz = omsg + zmsg;

    const mem = try allocator.alignedAlloc(u8, ALIGNMENT, sz);

    const nucleon: *Nucleon = @ptrCast(mem.ptr);
    nucleon.level = level;
    nucleon.coords = coords();
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

pub fn createAtom(allocator: Allocator, name: []const u8) !*Atom {
    const atom = try allocator.create(Atom);
    atom.birthTs = std.time.nanoTimestamp();
    atom.name = name;
    atom.nucleons.init();
    atom.durationNs = 0;
    atom.link.init();
    return atom;
}

test "two coords" {
    const coords1 = coords();
    const coords2 = coords();

    try testing.expectEqual(coords1.pid, coords2.pid);
    try testing.expectEqual(coords1.tid, coords2.tid);
    try testing.expect(coords2.ts > coords1.ts);
}

test "nucleon create and check fields" {
   const allocator = std.testing.allocator;
   const MAGIC_STR = "Spam message";

   const nucleon = try createNucleon(
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

    const nucleon = try createNucleon(
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

   const nucleon = try createNucleonFmt(
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

   const nucleon = try createNucleonFmt(
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
    const allocator = std.testing.allocator;
    const name = "Hg";

    const atom = try createAtom(allocator, name);
    defer atom.destroy(allocator);

    try testing.expect(atom.birthTs > 0);
    try testing.expectEqualStrings(name, atom.name);
    try testing.expect(atom.nucleons.isEmpty());
    try testing.expectEqual(0, atom.durationNs);

    atom.decay();
    try testing.expect(atom.durationNs > 0);
}
