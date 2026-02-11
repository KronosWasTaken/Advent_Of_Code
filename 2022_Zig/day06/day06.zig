const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

fn find(input: []const u8, marker: usize) usize {
    var seen: [26]usize = .{0} ** 26;
    var start: usize = 0;

    for (input, 0..) |b, i| {
        if (b == '\n' or b == '\r') continue;
        const idx: usize = @intCast(b - 'a');
        const prev = seen[idx];
        seen[idx] = i + 1;
        if (prev > start) start = prev;
        if (i + 1 - start == marker) return i + 1;
    }

    return 0;
}

fn solve(input: []const u8) Result {
    return .{ .p1 = find(input, 4), .p2 = find(input, 14) };
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
