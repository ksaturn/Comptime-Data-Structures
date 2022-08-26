const ccq = @import("comptime_circular_queue.zig");
const cpq = @import("comptime_priority_queue.zig");

pub const ComptimeCircularQueue = ccq.ComptimeCircularQueue;
pub const ComptimeCircularQueueError = ccq.ComptimeCircularQueueError;

pub const ComptimePriorityQueue = cpq.ComptimePriorityQueue;
pub const ComptimePriorityQueueError = cpq.ComptimePriorityQueueError;
