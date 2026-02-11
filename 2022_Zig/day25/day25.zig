const std = @import("std");

const Result = struct {
    p1: []const u8,
    p2: []const u8,
};

fn fromSnafu(snafu: []const u8) i64 {
    var acc: i64 = 0;
    for (snafu) |c| {
        const digit: i64 = switch (c) {
            '=' => -2,
            '-' => -1,
            '0' => 0,
            '1' => 1,
            '2' => 2,
            else => 0,
        };
        acc = acc * 5 + digit;
    }
    return acc;
}

fn toSnafu(n: i64, allocator: std.mem.Allocator) []u8 {
    var value = n;
    var digits = std.ArrayListUnmanaged(u8){};
    while (value > 0) {
        const next: u8 = switch (@mod(value, 5)) {
            0 => '0',
            1 => '1',
            2 => '2',
            3 => '=',
            4 => '-',
            else => '0',
        };
        digits.append(allocator, next) catch unreachable;
        value = @divTrunc(value + 2, 5);
    }
    if (digits.items.len == 0) {
        digits.append(allocator, '0') catch unreachable;
    }

    var out = allocator.alloc(u8, digits.items.len) catch unreachable;
    var i: usize = 0;
    while (i < digits.items.len) : (i += 1) {
        out[i] = digits.items[digits.items.len - 1 - i];
    }
    digits.deinit(allocator);
    return out;
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    var sum: i64 = 0;

    var start: usize = 0;
    var i: usize = 0;
    while (i <= input.len) : (i += 1) {
        const end_line = i == input.len or input[i] == '\n';
        if (!end_line) continue;
        var line = input[start..i];
        line = std.mem.trimRight(u8, line, "\r");
        if (line.len > 0) sum += fromSnafu(line);
        start = i + 1;
    }

    const p1 = toSnafu(sum, allocator);
    return .{ .p1 = p1, .p2 = "n/a" };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {s}\n", .{result.p1});
    std.debug.print("Part 2: {s}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
