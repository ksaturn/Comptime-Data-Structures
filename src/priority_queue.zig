const std = @import("std");

/// Priority queue for storing generic data.
/// Asserts the capacity is greater than zero.
/// Requires `compareFn` that returns `std.math.Order.lt` when its second
/// argument should get popped before its third argument,
/// `std.math.Order.eq` if the arguments are of equal priority, or `std.math.Order.gt`
/// if the third argument should be popped first.
/// For example, to make `pop` return the min number, provide
/// `fn lessThan(_: void, lhs: T, rhs: T) std.math.Order { return std.math.order(lhs, rhs); }`
pub fn PriorityQueue(comptime T: type, comptime capacity: usize, comptime Context: type, comptime compareFn: fn (context: Context, lhs: T, rhs: T) std.math.Order) type {
    std.debug.assert(capacity > 0);
    return struct {
        const Self = @This();

        items: [capacity]T = undefined,
        context: Context,
        len: usize = 0,

        /// Error set for the PriorityQueue.
        pub const Error = error{
            /// Tried to update a non-existent item.
            NoItem,
            /// Tried to put into a full queue.
            Full,
        };

        /// Initialize with a context for item comparison.
        ///
        /// Returns:
        ///     Priority queue.
        pub fn init(context: Context) Self {
            return .{ .context = context };
        }

        /// Put item into the queue, maintaining priority.
        ///
        /// Arguments:
        ///     item: Item to put into the queue.
        /// Returns:
        ///     Error.Full if there was no free space.
        pub fn put(self: *Self, item: T) Error!void {
            try self.ensureCapacity();
            self.items[self.len] = item;
            self.siftUp(self.len);
            self.len += 1;
        }

        /// Put item into the queue, maintaining priority.
        /// Asserts there is enough space for the new item.
        ///
        /// Arguments:
        ///     item: Item to put into the queue.
        pub fn putAssumeCapacity(self: *Self, item: T) void {
            std.debug.assert(self.len < capacity);
            self.items[self.len] = item;
            self.siftUp(self.len);
            self.len += 1;
        }

        /// Check that there is space for at least one item.
        ///
        /// Returns:
        ///     Error.Full if there was no free space.
        pub fn ensureCapacity(self: Self) Error!void {
            if (self.len == capacity) return Error.Full;
        }

        /// Peek at the highest priority item in the queue.
        ///
        /// Returns:
        ///     Peeked item or `null` if there were no items.
        pub fn peek(self: Self) ?T {
            return if (self.len > 0) self.items[0] else null;
        }

        /// Pop the highest priority item from the queue.
        ///
        /// Returns:
        ///     Popped item or `null` if there were no items.
        pub fn popOrNull(self: *Self) ?T {
            return if (self.len > 0) self.pop() else null;
        }

        /// Pop the highest priority item from the queue.
        ///
        /// Returns:
        ///     Popped item.
        pub fn pop(self: *Self) T {
            const item = self.items[0];
            self.items[0] = self.items[self.len - 1];
            self.len -= 1;
            self.siftDown(0);
            return item;
        }

        /// Update an old item with a new one.
        ///
        /// Arguments:
        ///     old_item: Item to update.
        ///     new_item: Item to update to.
        /// Returns:
        ///     Error.NoItem if there was no old item found.
        pub fn update(self: *Self, old_item: T, new_item: T) Error!void {
            const old_item_idx = blk: {
                for (self.items) |item, i| {
                    if (compareFn(self.context, item, old_item).compare(.eq)) break :blk i;
                }
                return Error.NoItem;
            };
            self.items[old_item_idx] = new_item;
            switch (compareFn(self.context, new_item, old_item)) {
                .gt => self.siftDown(old_item_idx),
                .lt => self.siftUp(old_item_idx),
                .eq => {},
            }
        }

        /// Sifts up an item to restore priority.
        ///
        /// Arguments:
        ///     idx: Item idx to sift up.
        pub fn siftUp(self: *Self, idx: usize) void {
            var parent_idx: usize = undefined;
            var parent: T = undefined;
            var child: T = undefined;
            var child_idx = idx;
            while (child_idx > 0) {
                parent_idx = (child_idx - 1) >> 1;
                child = self.items[child_idx];
                parent = self.items[parent_idx];
                if (compareFn(self.context, child, parent) != .lt) break;
                self.items[parent_idx] = child;
                self.items[child_idx] = parent;
                child_idx = parent_idx;
            }
        }

        /// Sifts down an item to restore priority.
        ///
        /// Arguments:
        ///     idx: Item idx to sift down.
        pub fn siftDown(self: *Self, idx: usize) void {
            var right_idx: usize = undefined;
            var left_idx: usize = undefined;
            var min_idx: usize = undefined;
            const mid_idx = self.len >> 1;
            var right: ?T = undefined;
            var left: ?T = undefined;
            var min: T = undefined;
            var item_idx = idx;
            while (true) {
                left_idx = (item_idx << 1) + 1;
                right_idx = left_idx + 1;
                left = if (left_idx < self.len) self.items[left_idx] else null;
                right = if (right_idx < self.len) self.items[right_idx] else null;
                min_idx = item_idx;
                min = self.items[item_idx];
                if (left) |item| {
                    if (compareFn(self.context, item, min) == .lt) {
                        min_idx = left_idx;
                        min = item;
                    }
                }
                if (right) |item| {
                    if (compareFn(self.context, item, min) == .lt) {
                        min_idx = right_idx;
                        min = item;
                    }
                }
                if (min_idx == item_idx) return {};
                self.items[min_idx] = self.items[item_idx];
                self.items[item_idx] = min;
                item_idx = min_idx;
                if (item_idx >= mid_idx) return {};
            }
        }
    };
}

const MinHeap = PriorityQueue(u33, void, lessThan);
const MaxHeap = PriorityQueue(u33, void, greaterThan);

fn lessThan(_: void, lhs: u33, rhs: u33) std.math.Order {
    return std.math.order(lhs, rhs);
}

fn greaterThan(_: void, lhs: u33, rhs: u33) std.math.Order {
    return std.math.order(rhs, lhs);
}

fn contextLessThan(context: []const u33, lhs: usize, rhs: usize) std.math.Order {
    return std.math.order(context[lhs], context[rhs]);
}

test "PriorityQueue: min heap put and pop" {
    var queue = PriorityQueue(u33, 6, void, lessThan).init({});
    try queue.put(54);
    try queue.put(12);
    try queue.put(77);
    try queue.put(23);
    try queue.put(25);
    try queue.put(13);
    try std.testing.expect(12 == queue.popOrNull());
    try std.testing.expect(13 == queue.popOrNull());
    try std.testing.expect(23 == queue.popOrNull());
    try std.testing.expect(25 == queue.popOrNull());
    try std.testing.expect(54 == queue.popOrNull());
    try std.testing.expect(77 == queue.popOrNull());
}

test "PriorityQueue: max heap put and pop" {
    var queue = PriorityQueue(u33, 6, void, greaterThan).init({});
    try queue.put(54);
    try queue.put(12);
    try queue.put(7);
    try queue.put(23);
    try queue.put(25);
    try queue.put(13);
    try std.testing.expect(54 == queue.popOrNull());
    try std.testing.expect(25 == queue.popOrNull());
    try std.testing.expect(23 == queue.popOrNull());
    try std.testing.expect(13 == queue.popOrNull());
    try std.testing.expect(12 == queue.popOrNull());
    try std.testing.expect(7 == queue.popOrNull());
}

test "PriorityQueue: min heap put and pop same" {
    var queue = PriorityQueue(u33, 6, void, lessThan).init({});
    try queue.put(1);
    try queue.put(1);
    try queue.put(2);
    try queue.put(2);
    try queue.put(1);
    try queue.put(1);
    try std.testing.expect(1 == queue.popOrNull());
    try std.testing.expect(1 == queue.popOrNull());
    try std.testing.expect(1 == queue.popOrNull());
    try std.testing.expect(1 == queue.popOrNull());
    try std.testing.expect(2 == queue.popOrNull());
    try std.testing.expect(2 == queue.popOrNull());
}

test "PriorityQueue: max heap put and pop same" {
    var queue = PriorityQueue(u33, 6, void, greaterThan).init({});
    try queue.put(1);
    try queue.put(1);
    try queue.put(2);
    try queue.put(2);
    try queue.put(1);
    try queue.put(1);
    try std.testing.expect(2 == queue.popOrNull());
    try std.testing.expect(2 == queue.popOrNull());
    try std.testing.expect(1 == queue.popOrNull());
    try std.testing.expect(1 == queue.popOrNull());
    try std.testing.expect(1 == queue.popOrNull());
    try std.testing.expect(1 == queue.popOrNull());
}

test "PriorityQueue: min heap pop empty" {
    var queue = PriorityQueue(u33, 6, void, lessThan).init({});
    try std.testing.expectEqual(null, queue.popOrNull());
}

test "PriorityQueue: min heap edge case 3 items" {
    var queue = PriorityQueue(u33, 3, void, lessThan).init({});
    try queue.put(9);
    try queue.put(3);
    try queue.put(2);
    try std.testing.expect(2 == queue.popOrNull());
    try std.testing.expect(3 == queue.popOrNull());
    try std.testing.expect(9 == queue.popOrNull());
}

test "PriorityQueue: min heap peek" {
    var queue = PriorityQueue(u33, 3, void, lessThan).init({});
    try std.testing.expectEqual(null, queue.peek());
    try queue.put(9);
    try queue.put(3);
    try queue.put(2);
    try std.testing.expect(2 == queue.peek());
    try std.testing.expect(2 == queue.peek());
}

test "PriorityQueue: min heap sift up with odd indices" {
    var queue = PriorityQueue(u33, 18, void, lessThan).init({});
    const items = [18]u33{ 15, 7, 21, 14, 13, 22, 12, 6, 7, 25, 5, 24, 11, 16, 15, 24, 2, 1 };
    for (items) |item| {
        try queue.put(item);
    }
    const sorted_items = [18]u33{ 1, 2, 5, 6, 7, 7, 11, 12, 13, 14, 15, 15, 16, 21, 22, 24, 24, 25 };
    for (sorted_items) |item| {
        try std.testing.expect(item == queue.popOrNull());
    }
}

test "PriorityQueue: max heap update" {
    var queue = PriorityQueue(u33, 3, void, greaterThan).init({});
    try queue.put(55);
    try queue.put(44);
    try queue.put(11);
    try queue.update(55, 5);
    try queue.update(44, 1);
    try queue.update(11, 4);
    try std.testing.expect(5 == queue.popOrNull());
    try std.testing.expect(4 == queue.popOrNull());
    try std.testing.expect(1 == queue.popOrNull());
}

test "PriorityQueue: max heap update same" {
    var queue = PriorityQueue(u33, 4, void, greaterThan).init({});
    try queue.put(1);
    try queue.put(1);
    try queue.put(2);
    try queue.put(2);
    try queue.update(1, 5);
    try queue.update(2, 4);
    try std.testing.expect(5 == queue.popOrNull());
    try std.testing.expect(4 == queue.popOrNull());
    try std.testing.expect(2 == queue.popOrNull());
    try std.testing.expect(1 == queue.popOrNull());
}

test "PriorityQueue: min heap update" {
    var queue = PriorityQueue(u33, 3, void, lessThan).init({});
    try queue.put(55);
    try queue.put(44);
    try queue.put(11);
    try queue.update(55, 5);
    try queue.update(44, 4);
    try queue.update(11, 1);
    try std.testing.expect(1 == queue.popOrNull());
    try std.testing.expect(4 == queue.popOrNull());
    try std.testing.expect(5 == queue.popOrNull());
}

test "PriorityQueue: min heap update same" {
    var queue = PriorityQueue(u33, 4, void, lessThan).init({});
    try queue.put(1);
    try queue.put(1);
    try queue.put(2);
    try queue.put(2);
    try queue.update(1, 5);
    try queue.update(2, 4);
    try std.testing.expect(1 == queue.popOrNull());
    try std.testing.expect(2 == queue.popOrNull());
    try std.testing.expect(4 == queue.popOrNull());
    try std.testing.expect(5 == queue.popOrNull());
}

test "PriorityQueue: min heap put and pop with context" {
    const context = [7]u33{ 5, 3, 4, 2, 2, 8, 0 };
    var queue = PriorityQueue(usize, 7, []const u33, contextLessThan).init(context[0..]);
    try queue.put(0);
    try queue.put(1);
    try queue.put(2);
    try queue.put(3);
    try queue.put(4);
    try queue.put(5);
    try queue.put(6);
    try std.testing.expect(6 == queue.popOrNull());
    try std.testing.expect(4 == queue.popOrNull());
    try std.testing.expect(3 == queue.popOrNull());
    try std.testing.expect(1 == queue.popOrNull());
    try std.testing.expect(2 == queue.popOrNull());
    try std.testing.expect(0 == queue.popOrNull());
    try std.testing.expect(5 == queue.popOrNull());
}
