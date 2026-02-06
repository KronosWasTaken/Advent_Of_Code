const std = @import("std");

const Result = struct {
    p1: usize,
    p2: u32,
};

fn toDigit(total: u8) u32 {
    return switch (total) {
        42 => 0,
        17 => 1,
        34 => 2,
        39 => 3,
        30 => 4,
        37 => 5,
        41 => 6,
        25 => 7,
        49 => 8,
        45 => 9,
        else => 0,
    };
}

fn solve(input: []const u8) Result {
    var p1: usize = 0;
    var p2: u32 = 0;

    var i: usize = 0;
    while (i < input.len) {
        var frequency: [104]u8 = [_]u8{0} ** 104;

        var cursor = i;
        while (cursor < input.len and input[cursor] != '\n' and input[cursor] != '|') : (cursor += 1) {
            const c = input[cursor];
            if (c >= 'a' and c <= 'g') frequency[c] += 1;
        }

        while (cursor < input.len and input[cursor] != '|') : (cursor += 1) {}
        if (cursor < input.len and input[cursor] == '|') cursor += 1;

        var digit_total: u32 = 0;
        var digit_count: usize = 0;
        var current: u8 = 0;
        var in_token = false;
        while (cursor < input.len) : (cursor += 1) {
            const c = input[cursor];
            if (c == '\r') continue;
            if (c == '\n') {
                if (in_token) {
                    const digit = toDigit(current);
                    if (digit == 1 or digit == 4 or digit == 7 or digit == 8) p1 += 1;
                    digit_total = digit_total * 10 + digit;
                }
                cursor += 1;
                break;
            }
            if (c == ' ') {
                if (in_token) {
                    const digit = toDigit(current);
                    if (digit == 1 or digit == 4 or digit == 7 or digit == 8) p1 += 1;
                    digit_total = digit_total * 10 + digit;
                    digit_count += 1;
                    current = 0;
                    in_token = false;
                    if (digit_count == 4) {
                        while (cursor + 1 < input.len and input[cursor + 1] != '\n') : (cursor += 1) {}
                    }
                }
                continue;
            }
            if (c >= 'a' and c <= 'g') {
                current += frequency[c];
                in_token = true;
            }
        }

        p2 += digit_total;
        i = cursor;
    }

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
