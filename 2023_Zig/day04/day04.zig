const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

fn nextNumber(line: []const u8, idx: *usize) ?usize {
    var i = idx.*;
    while (i < line.len and (line[i] < '0' or line[i] > '9')) : (i += 1) {}
    if (i >= line.len) {
        idx.* = i;
        return null;
    }
    var value: usize = 0;
    while (i < line.len and line[i] >= '0' and line[i] <= '9') : (i += 1) {
        value = value * 10 + (line[i] - '0');
    }
    idx.* = i;
    return value;
}

pub fn solve(input: []const u8) Result {
    var allocator = std.heap.page_allocator;
    var wins = std.ArrayListUnmanaged(usize){};
    defer wins.deinit(allocator);

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trimRight(u8, raw_line, "\r");
        if (line.len == 0) continue;
        var found = [_]bool{false} ** 100;
        const pipe_pos = std.mem.indexOfScalar(u8, line, '|') orelse continue;

        var idx: usize = 0;
        var skip_id = true;
        while (idx < pipe_pos) {
            const value = nextNumber(line[0..pipe_pos], &idx) orelse break;
            if (skip_id) {
                skip_id = false;
            } else {
                found[value] = true;
            }
        }

        idx = 0;
        var matches: usize = 0;
        const have = line[pipe_pos + 1 ..];
        while (nextNumber(have, &idx)) |value| {
            if (found[value]) matches += 1;
        }
        wins.append(allocator, matches) catch return .{ .p1 = 0, .p2 = 0 };
    }

    var sum1: u64 = 0;
    for (wins.items) |n| {
        if (n > 0) sum1 += (@as(u64, 1) << @intCast(n)) >> 1;
    }

    const len = wins.items.len;
    var copies = allocator.alloc(u64, len) catch return .{ .p1 = sum1, .p2 = 0 };
    defer allocator.free(copies);
    @memset(copies, 1);
    for (wins.items, 0..) |n, i| {
        var j: usize = 0;
        while (j < n and i + j + 1 < len) : (j += 1) {
            copies[i + j + 1] += copies[i];
        }
    }
    var sum2: u64 = 0;
    for (copies) |c| sum2 += c;

    return .{ .p1 = sum1, .p2 = sum2 };
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
