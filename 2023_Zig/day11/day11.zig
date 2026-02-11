const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

fn axis(counts: []const u16, factor: u64) u64 {
    var gaps: u64 = 0;
    var result: u64 = 0;
    var prefix_sum: u64 = 0;
    var prefix_items: u64 = 0;
    var i: usize = 0;
    while (i < counts.len) : (i += 1) {
        const count = counts[i];
        if (count > 0) {
            const expanded = @as(u64, @intCast(i)) + factor * gaps;
            const extra = prefix_items * expanded - prefix_sum;
            result += @as(u64, count) * extra;
            prefix_sum += @as(u64, count) * expanded;
            prefix_items += count;
        } else {
            gaps += 1;
        }
    }
    return result;
}

pub fn solve(input: []const u8) Result {
    var xs: [140]u16 = [_]u16{0} ** 140;
    var ys: [140]u16 = [_]u16{0} ** 140;
    var y: usize = 0;
    var x: usize = 0;
    for (input) |b| {
        if (b == '\r') continue;
        if (b == '\n') {
            if (x > 0) y += 1;
            x = 0;
            continue;
        }
        if (b == '#') {
            xs[x] += 1;
            ys[y] += 1;
        }
        x += 1;
    }

    const p1 = axis(&xs, 1) + axis(&ys, 1);
    const p2 = axis(&xs, 999999) + axis(&ys, 999999);
    return .{ .p1 = p1, .p2 = p2 };
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
