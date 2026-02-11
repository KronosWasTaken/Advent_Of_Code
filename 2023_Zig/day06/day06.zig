const std = @import("std");

const Result = struct {
    p1: u128,
    p2: u128,
};

fn nextNumber(line: []const u8, idx: *usize) ?u128 {
    var i = idx.*;
    while (i < line.len and (line[i] < '0' or line[i] > '9')) : (i += 1) {}
    if (i >= line.len) {
        idx.* = i;
        return null;
    }
    var value: u128 = 0;
    while (i < line.len and line[i] >= '0' and line[i] <= '9') : (i += 1) {
        value = value * 10 + (line[i] - '0');
    }
    idx.* = i;
    return value;
}

fn parseMerged(line: []const u8) u128 {
    var value: u128 = 0;
    for (line) |b| {
        if (b >= '0' and b <= '9') value = value * 10 + (b - '0');
    }
    return value;
}

fn isqrt(value: u128) u128 {
    if (value < 2) return value;
    var lo: u128 = 1;
    var hi: u128 = value;
    while (lo + 1 < hi) {
        const mid = (lo + hi) / 2;
        const sq = mid * mid;
        if (sq == value) return mid;
        if (sq < value) {
            lo = mid;
        } else {
            hi = mid;
        }
    }
    return lo;
}

fn divCeil(a: u128, b: u128) u128 {
    return (a + b - 1) / b;
}

fn race(time: u128, distance: u128) u128 {
    const root = isqrt(time * time - 4 * distance);
    var start = divCeil(time - root, 2);
    var end = (time + root) / 2;
    if (start * (time - start) > distance) start -= 1;
    if (end * (time - end) > distance) end += 1;
    return end - start - 1;
}

pub fn solve(input: []const u8) Result {
    var lines = std.mem.splitScalar(u8, input, '\n');
    const line1 = std.mem.trimRight(u8, lines.next() orelse "", "\r");
    const line2 = std.mem.trimRight(u8, lines.next() orelse "", "\r");

    var times: std.ArrayListUnmanaged(u128) = .{};
    var dists: std.ArrayListUnmanaged(u128) = .{};
    defer times.deinit(std.heap.page_allocator);
    defer dists.deinit(std.heap.page_allocator);

    var idx: usize = 0;
    while (nextNumber(line1, &idx)) |value| {
        times.append(std.heap.page_allocator, value) catch return .{ .p1 = 0, .p2 = 0 };
    }
    idx = 0;
    while (nextNumber(line2, &idx)) |value| {
        dists.append(std.heap.page_allocator, value) catch return .{ .p1 = 0, .p2 = 0 };
    }

    var p1: u128 = 1;
    var i: usize = 0;
    while (i < times.items.len and i < dists.items.len) : (i += 1) {
        p1 *= race(times.items[i], dists.items[i]);
    }

    const t2 = parseMerged(line1);
    const d2 = parseMerged(line2);
    const p2 = race(t2, d2);

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
