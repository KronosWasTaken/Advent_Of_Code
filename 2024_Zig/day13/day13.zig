const std = @import("std");

const Result = struct {
    p1: i64,
    p2: i64,
};

fn nextInt(input: []const u8, index: *usize) ?i64 {
    var i = index.*;
    while (i < input.len and !((input[i] >= '0' and input[i] <= '9') or input[i] == '-')) : (i += 1) {}
    if (i >= input.len) {
        index.* = i;
        return null;
    }
    var sign: i64 = 1;
    if (input[i] == '-') {
        sign = -1;
        i += 1;
    }
    var value: i64 = 0;
    while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
        value = value * 10 + @as(i64, input[i] - '0');
    }
    index.* = i;
    return value * sign;
}

fn play(row: []const i64, part_two: bool) i64 {
    const ax = row[0];
    const ay = row[1];
    const bx = row[2];
    const by = row[3];
    var px = row[4];
    var py = row[5];
    if (part_two) {
        px += 10_000_000_000_000;
        py += 10_000_000_000_000;
    }
    const det = ax * by - ay * bx;
    if (det == 0) return 0;
    var a = by * px - bx * py;
    var b = ax * py - ay * px;
    if (@rem(a, det) != 0 or @rem(b, det) != 0) return 0;
    a = @divTrunc(a, det);
    b = @divTrunc(b, det);
    return 3 * a + b;
}

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    var nums: std.ArrayListUnmanaged(i64) = .{};
    defer nums.deinit(allocator);

    var idx: usize = 0;
    while (nextInt(input, &idx)) |value| {
        try nums.append(allocator, value);
    }

    var p1: i64 = 0;
    var p2: i64 = 0;
    var i: usize = 0;
    while (i + 5 < nums.items.len) : (i += 6) {
        const row = nums.items[i .. i + 6];
        p1 += play(row, false);
        p2 += play(row, true);
    }

    return .{ .p1 = p1, .p2 = p2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input, std.heap.page_allocator);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
