const std = @import("std");

/// Error set for the ComptimeCircularQueue.
pub const ComptimeCircularQueueError = error{
    /// Tried to put into a full queue.
    Full,
};

/// Circular queue backed by an array allocated at compile-time.
/// Asserts the capacity is greater than zero.
pub fn ComptimeCircularQueue(comptime T: type, comptime capacity: usize) type {
    std.debug.assert(capacity > 0);
    return struct {
        const Self = @This();

        item_opts: [capacity]?T = [1]?T{null} ** capacity,
        pop_idx: usize = 0,
        put_idx: usize = 0,

        /// Put item into the queue.
        ///
        /// Arguments:
        ///     item: Item to put into the queue.
        /// Returns:
        ///     ComptimeCircularQueueError.Full if there was no free space.
        pub fn put(self: *Self, item: T) ComptimeCircularQueueError!void {
            try self.ensureCapacity();
            self.put_idx = next(self.put_idx);
            self.item_opts[self.put_idx] = item;
        }

        /// Put item into the queue.
        /// Asserts there is enough space for the new item.
        ///
        /// Arguments:
        ///     item: Item to put into the queue.
        pub fn putAssumeCapacity(self: *Self, item: T) void {
            std.debug.assert(self.item_opts[next(self.put_idx)] == null);
            self.put_idx = next(self.put_idx);
            self.item_opts[self.put_idx] = item;
        }

        /// Check that there is space for at least one item.
        ///
        /// Returns:
        ///     ComptimeCircularQueueError.Full if there was no free space.
        pub fn ensureCapacity(self: Self) ComptimeCircularQueueError!void {
            if (self.item_opts[next(self.put_idx)] != null) return ComptimeCircularQueueError.Full;
        }

        /// Pop item from the queue.
        ///
        /// Returns:
        ///     Popped item or `null` if there were no items.
        pub fn popOrNull(self: *Self) ?T {
            return if (self.item_opts[next(self.pop_idx)] != null) self.pop() else null;
        }

        /// Pop item from the queue.
        ///
        /// Returns:
        ///     Popped item.
        pub fn pop(self: *Self) T {
            self.pop_idx = next(self.pop_idx);
            defer self.item_opts[self.pop_idx] = null;
            return self.item_opts[self.pop_idx].?;
        }

        /// Get the next idx.
        ///
        /// Arguments:
        ///     idx: Current idx.
        /// Returns:
        ///     Number of present items.
        pub fn next(idx: usize) usize {
            return if (capacity < 2 or idx > capacity - 2) 0 else idx + 1;
        }

        /// Determine the number of present items.
        ///
        /// Returns:
        ///     Number of present items.
        pub fn len(self: Self) usize {
            if (self.put_idx > self.pop_idx) {
                return self.put_idx - self.pop_idx;
            } else if (self.put_idx == self.pop_idx) {
                return if (self.item_opts[self.put_idx] != null) capacity else 0;
            } else {
                return (self.put_idx + capacity) - self.pop_idx;
            }
        }

        /// Copy items in FIFO order.
        ///
        /// Returns:
        ///     Array of items copied in FIFO order.
        pub fn copyItems(self: Self) [capacity]?T {
            var item_opts = [1]?T{null} ** capacity;
            var queue_idx = next(self.pop_idx);
            var queue_item_opt = self.item_opts[queue_idx];
            for (item_opts) |*item_opt| {
                item_opt.* = queue_item_opt orelse break;
                queue_idx = next(queue_idx);
                queue_item_opt = self.item_opts[queue_idx];
            }
            return item_opts;
        }
    };
}

test "ComptimeCircularQueue: put and pop ordinary type" {
    const capacities = [1]u33{123} ** 123;
    inline for (capacities) |capacity| {
        var queue = ComptimeCircularQueue(u33, capacity){};
        var values = [1]u33{123} ** capacity;
        for (values) |*value, i| {
            value.* = @intCast(u33, i);
        }
        for (values) |value| {
            try queue.put(value);
        }
        for (values) |value| {
            try std.testing.expect(value == queue.popOrNull());
        }
        try std.testing.expect(0 == queue.len());
    }
}

test "ComptimeCircularQueue: put and pop optional type" {
    const T = u33;
    const a: ?T = 1;
    const b: ?T = null;
    var queue = ComptimeCircularQueue(?u33, 123){};
    try queue.put(a);
    try std.testing.expect(1 == queue.len());
    try queue.put(b);
    try std.testing.expect(2 == queue.len());
    try std.testing.expect(1 == queue.popOrNull());
    try std.testing.expectEqual(null, queue.popOrNull());
    for (queue.item_opts) |_| {
        try queue.put(null);
    }
    try std.testing.expectEqual(queue.item_opts.len, queue.len());
}

test "ComptimeCircularQueue: put too many items" {
    const T = u33;
    const capacity: usize = 123;
    var queue = ComptimeCircularQueue(T, capacity){};
    var values = [1]T{123} ** capacity;
    for (values) |*value, i| {
        value.* = @intCast(T, i);
    }
    for (values) |value| {
        try queue.put(value);
    }
    try std.testing.expectError(ComptimeCircularQueueError.Full, queue.put(333));
}

test "ComptimeCircularQueue: pop too many items" {
    var queue = ComptimeCircularQueue(u33, 123){};
    try std.testing.expectEqual(null, queue.popOrNull());
}

test "ComptimeCircularQueue: copy items" {
    var queue = ComptimeCircularQueue(u33, 123){};
    var item_opts = queue.copyItems();
    for (item_opts) |i| {
        try std.testing.expectEqual(null, i);
    }
    try queue.put(1);
    try queue.put(2);
    item_opts = queue.copyItems();
    try std.testing.expect(1 == item_opts[0].?);
    try std.testing.expect(2 == item_opts[1].?);
    try queue.put(3);
    _ = queue.popOrNull();
    item_opts = queue.copyItems();
    try std.testing.expect(2 == item_opts[0].?);
    try std.testing.expect(3 == item_opts[1].?);
}

test "ComptimeCircularQueue: circle back" {
    var queue = ComptimeCircularQueue(u33, 3){};
    try queue.put(1);
    try std.testing.expect(1 == queue.len());
    try queue.put(2);
    try std.testing.expect(2 == queue.len());
    try std.testing.expect(1 == queue.popOrNull());
    try std.testing.expect(1 == queue.len());
    try queue.put(3);
    try std.testing.expect(2 == queue.len());
    try std.testing.expect(2 == queue.popOrNull());
    try std.testing.expect(1 == queue.len());
    try queue.put(4);
    try std.testing.expect(2 == queue.len());
    try std.testing.expect(3 == queue.popOrNull());
    try std.testing.expect(1 == queue.len());
    try std.testing.expect(4 == queue.popOrNull());
    try std.testing.expect(0 == queue.len());
    try queue.put(1);
    try std.testing.expect(1 == queue.len());
    try std.testing.expect(1 == queue.popOrNull());
    try std.testing.expect(0 == queue.len());
    try queue.put(2);
    try std.testing.expect(1 == queue.len());
    try queue.put(3);
    try std.testing.expect(2 == queue.len());
    try queue.put(4);
    try std.testing.expect(3 == queue.len());
    try std.testing.expectError(ComptimeCircularQueueError.Full, queue.put(100));
    try std.testing.expect(3 == queue.len());
    try std.testing.expect(2 == queue.popOrNull());
    try std.testing.expect(2 == queue.len());
    try std.testing.expect(3 == queue.popOrNull());
    try std.testing.expect(1 == queue.len());
    try queue.put(5);
    try std.testing.expect(2 == queue.len());
    try std.testing.expect(4 == queue.popOrNull());
    try std.testing.expect(5 == queue.popOrNull());
    try std.testing.expect(0 == queue.len());
}
