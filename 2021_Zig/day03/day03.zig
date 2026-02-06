const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u32,
};

fn rating(allocator: std.mem.Allocator, input: []const []const u8, cmp: fn (usize, usize) bool) u32 {
    var working = allocator.alloc([]const u8, input.len) catch unreachable;
    defer allocator.free(working);
    std.mem.copyForwards([]const u8, working, input);

    var len = working.len;
    var column: usize = 0;
    while (len > 1) : (column += 1) {
        var ones: usize = 0;
        var i: usize = 0;
        while (i < len) : (i += 1) {
            if (working[i][column] == '1') ones += 1;
        }
        const zeros = len - ones;
        const keep: u8 = if (cmp(ones, zeros)) '1' else '0';

        var write: usize = 0;
        i = 0;
        while (i < len) : (i += 1) {
            const line = working[i];
            if (line[column] == keep) {
                working[write] = line;
                write += 1;
            }
        }
        len = write;
    }

    var value: u32 = 0;
    for (working[0]) |bit| {
        value = (value << 1) | @as(u32, @intFromBool(bit == '1'));
    }
    return value;
}

fn collectLines(input: []const u8, allocator: std.mem.Allocator) []const []const u8 {
    var count: usize = 0;
    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        if (input[i] == '\n') count += 1;
    }
    if (input.len > 0 and input[input.len - 1] != '\n') count += 1;

    const lines = allocator.alloc([]const u8, count) catch unreachable;
    var idx: usize = 0;
    var start: usize = 0;
    i = 0;
    while (i <= input.len) : (i += 1) {
        if (i == input.len or input[i] == '\n') {
            var end = i;
            if (end > start and input[end - 1] == '\r') end -= 1;
            if (end > start) {
                lines[idx] = input[start..end];
                idx += 1;
            }
            start = i + 1;
        }
    }
    return lines[0..idx];
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const lines = collectLines(input, allocator);
    defer allocator.free(lines);

    const width = lines[0].len;
    var gamma: u32 = 0;
    var epsilon: u32 = 0;

    var column: usize = 0;
    while (column < width) : (column += 1) {
        var ones: usize = 0;
        for (lines) |line| {
            if (line[column] == '1') ones += 1;
        }
        const zeros = lines.len - ones;
        gamma = (gamma << 1) | @as(u32, @intFromBool(ones > zeros));
        epsilon = (epsilon << 1) | @as(u32, @intFromBool(zeros > ones));
    }

    const oxygen = rating(allocator, lines, struct {
        fn cmp(a: usize, b: usize) bool {
            return a >= b;
        }
    }.cmp);
    const co2 = rating(allocator, lines, struct {
        fn cmp(a: usize, b: usize) bool {
            return a < b;
        }
    }.cmp);

    return .{ .p1 = gamma * epsilon, .p2 = oxygen * co2 };
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
