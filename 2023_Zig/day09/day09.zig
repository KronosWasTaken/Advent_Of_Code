const std = @import("std");

const Result = struct {
    p1: i64,
    p2: i64,
};

fn nextSigned(line: []const u8, idx: *usize) ?i64 {
    var i = idx.*;
    while (i < line.len and line[i] != '-' and (line[i] < '0' or line[i] > '9')) : (i += 1) {}
    if (i >= line.len) {
        idx.* = i;
        return null;
    }
    var sign: i64 = 1;
    if (line[i] == '-') {
        sign = -1;
        i += 1;
    }
    var value: i64 = 0;
    while (i < line.len and line[i] >= '0' and line[i] <= '9') : (i += 1) {
        value = value * 10 + @as(i64, line[i] - '0');
    }
    idx.* = i;
    return value * sign;
}

pub fn solve(input: []const u8) Result {
    var lines = std.mem.splitScalar(u8, input, '\n');
    const first = std.mem.trimRight(u8, lines.next() orelse "", "\r");
    if (first.len == 0) return .{ .p1 = 0, .p2 = 0 };

    var idx: usize = 0;
    var row: usize = 0;
    while (nextSigned(first, &idx)) |_| row += 1;

    var triangle: std.ArrayListUnmanaged(i64) = .{};
    defer triangle.deinit(std.heap.page_allocator);
    triangle.append(std.heap.page_allocator, 1) catch return .{ .p1 = 0, .p2 = 0 };

    var coefficient: i64 = 1;
    var i: usize = 0;
    while (i < row) : (i += 1) {
        const num = coefficient * (@as(i64, @intCast(i)) - @as(i64, @intCast(row)));
        const den = @as(i64, @intCast(i + 1));
        coefficient = @divTrunc(num, den);
        triangle.append(std.heap.page_allocator, coefficient) catch return .{ .p1 = 0, .p2 = 0 };
    }

    var part_one: i64 = 0;
    var part_two: i64 = 0;
    var all_lines = std.mem.splitScalar(u8, input, '\n');
    while (all_lines.next()) |raw_line| {
        const line = std.mem.trimRight(u8, raw_line, "\r");
        if (line.len == 0) continue;
        idx = 0;
        var k: usize = 0;
        while (nextSigned(line, &idx)) |value| : (k += 1) {
            part_one += value * triangle.items[k];
            part_two += value * triangle.items[k + 1];
        }
    }

    const p1 = if (part_one < 0) -part_one else part_one;
    const p2 = if (part_two < 0) -part_two else part_two;
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
