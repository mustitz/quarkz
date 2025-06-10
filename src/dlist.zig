const std = @import("std");
const testing = std.testing;

pub const DList = struct {
    next: *DList,
    prev: *DList,

    pub fn init(self: *DList) void {
        self.next = self;
        self.prev = self;
    }

    pub fn insertAfter(self: *DList, new_node: *DList) void {
        const next = self.next;
        new_node.next = next;
        new_node.prev = self;
        next.prev = new_node;
        self.next = new_node;
    }

    pub fn insertBefore(self: *DList, new_node: *DList) void {
        self.prev.insertAfter(new_node);
    }

    pub fn remove(self: *DList) void {
        self.prev.next = self.next;
        self.next.prev = self.prev;
    }

    pub fn isEmpty(self: *const DList) bool {
        return self.next == self;
    }

    pub fn count(self: *const DList) usize {
        var current = self.next;
        var result: usize = 1;
        while (current != self) {
            result += 1;
            current = current.next;
        }
        return result;
    }

    pub fn iterator(self: *const DList) DListIterator {
        return DListIterator{ .current = self.next, .start = self };
    }

    pub fn containerOf(
        self: *const DList,
        comptime Container: type,
        comptime fieldName: []const u8
    ) *Container {
        return @constCast(@alignCast(@fieldParentPtr(fieldName, self)));
    }
};

const DListIterator = struct {
    current: *const DList,
    start: *const DList,

    pub fn next(self: *DListIterator) ?*const DList {
        const result = self.current;
        if (result == self.start) return null;
        self.current = result.next;
        return result;
    }
};



// Tests

const Data = struct {
   value: i32,
   link: DList,
};

test "dlist init remove" {
    var node: DList = undefined;
    node.init();
    node.remove();

    try testing.expectEqual(1, node.count());
    try testing.expect(node.isEmpty());
    try testing.expectEqual(&node, node.next);
    try testing.expectEqual(&node, node.prev);
}

test "dlist insert and count" {
    var root: DList = undefined;
    root.init();

    var node: DList = undefined;

    root.insertAfter(&node);

    try testing.expectEqual(2, root.count());
    try testing.expectEqual(2, node.count());

    node.remove();

    try testing.expectEqual(1, root.count());
}

fn calculateMagic(root: *const DList) i32 {
   var magic: i32 = 0;
   var multiplier: i32 = 1;
   var iter = root.iterator();

   while (iter.next()) |node| {
       const data = node.containerOf(Data, "link");
       magic += data.value * multiplier;
       multiplier += 1;
   }

   return magic;
}

test "dlist insertBefore and iterator with data" {
   var root: DList = undefined;
   root.init();

   var elem1 = Data{ .value = 1, .link = undefined };
   var elem2 = Data{ .value = 2, .link = undefined };

   root.insertBefore(&elem1.link); // [root, 1]
   root.insertBefore(&elem2.link); // [root, 1, 2]

   // [1, 2] -> 1 * 1 + 2 * 2 = 5
   try testing.expectEqual(5, calculateMagic(&root));
   try testing.expectEqual(3, root.count());

   elem1.link.remove();
   // [2] -> 2 * 1 = 2
   try testing.expectEqual(2, calculateMagic(&root));
   try testing.expectEqual(2, root.count());

   elem2.link.remove();
   // [] -> 0
   try testing.expectEqual(0, calculateMagic(&root));
   try testing.expectEqual(1, root.count());
}

test "dlist insertAfter and iterator with data" {
   var root: DList = undefined;
   root.init();

   var elem1 = Data{ .value = 1, .link = undefined };
   var elem2 = Data{ .value = 2, .link = undefined };

   root.insertAfter(&elem1.link);       // [root, 1]
   elem1.link.insertAfter(&elem2.link); // [root, 1, 2]

   // [1, 2] -> 1 * 1 + 2 * 2 = 5
   try testing.expectEqual(5, calculateMagic(&root));
   try testing.expectEqual(3, root.count());

   elem1.link.remove();
   // [2] -> 2 * 1 = 2
   try testing.expectEqual(2, calculateMagic(&root));
   try testing.expectEqual(2, root.count());

   elem2.link.remove();
   // [] -> 0
   try testing.expectEqual(0, calculateMagic(&root));
   try testing.expectEqual(1, root.count());
}
