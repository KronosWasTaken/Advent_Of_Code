const std = @import("std");

const Result = struct { p1: u64, p2: u64 };

pub fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    var lines = std.ArrayListUnmanaged([]const u8){};
    defer lines.deinit(allocator);

    var start: usize = 0;
    var i: usize = 0;
    while (i <= input.len) : (i += 1) {
        if (i == input.len or input[i] == '\n') {
            var end = i;
            if (end > start and input[end - 1] == '\r') end -= 1;
            if (end > start) lines.append(allocator, input[start..end]) catch unreachable;
            start = i + 1;
        }
    }

    const width = if (lines.items.len > 0) lines.items[0].len else 0;
    const center = width / 2;
    var timelines = std.ArrayListUnmanaged(u64){};
    defer timelines.deinit(allocator);
    timelines.resize(allocator, width) catch unreachable;
    @memset(timelines.items, 0);
    timelines.items[center] = 1;

    var splits: u64 = 0;
    var y: usize = 0;
    var line_index: usize = 2;
    while (line_index < lines.items.len) : (line_index += 2) {
        const row = lines.items[line_index];
        var x: usize = center - y;
        while (x <= center + y) : (x += 2) {
            const count = timelines.items[x];
            if (count > 0 and row[x] == '^') {
                splits += 1;
                timelines.items[x] = 0;
                timelines.items[x - 1] += count;
                timelines.items[x + 1] += count;
            }
        }
        y += 1;
    }

    var total: u64 = 0;
    for (timelines.items) |value| total += value;

    return .{ .p1 = splits, .p2 = total };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
