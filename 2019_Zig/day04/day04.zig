const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u32,
};

inline fn toDigits(n: u32) [6]u8 {
    var result: [6]u8 = undefined;
    var num = n;
    result[5] = @as(u8, @intCast(num % 10)) + '0';
    num /= 10;
    result[4] = @as(u8, @intCast(num % 10)) + '0';
    num /= 10;
    result[3] = @as(u8, @intCast(num % 10)) + '0';
    num /= 10;
    result[2] = @as(u8, @intCast(num % 10)) + '0';
    num /= 10;
    result[1] = @as(u8, @intCast(num % 10)) + '0';
    num /= 10;
    result[0] = @as(u8, @intCast(num % 10)) + '0';
    return result;
}

fn solve(input: []const u8) Result {
    var start: u32 = 0;
    var end: u32 = 0;
    var num: u32 = 0;

    for (input) |c| {
        if (c >= '0' and c <= '9') {
            num = num * 10 + (c - '0');
        } else if (c == '-') {
            start = num;
            num = 0;
        }
    }
    end = num;

    var digits = toDigits(start);
    const end_digits = toDigits(end);


    inline for (1..6) |i| {
        if (digits[i - 1] > digits[i]) {
            inline for (i..6) |j| {
                digits[j] = digits[i - 1];
            }
            break;
        }
    }

    var part1: u32 = 0;
    var part2: u32 = 0;

    while (true) {

        var cmp: i32 = 0;
        for (0..6) |i| {
            if (digits[i] < end_digits[i]) {
                cmp = -1;
                break;
            }
            if (digits[i] > end_digits[i]) {
                cmp = 1;
                break;
            }
        }
        if (cmp > 0) break;


        var mask: u32 = 0;
        if (digits[0] == digits[1]) mask |= 0x1;
        if (digits[1] == digits[2]) mask |= 0x2;
        if (digits[2] == digits[3]) mask |= 0x4;
        if (digits[3] == digits[4]) mask |= 0x8;
        if (digits[4] == digits[5]) mask |= 0x10;


        part1 += @intFromBool(mask != 0);


        if ((mask & (~(mask >> 1)) & (~(mask << 1))) != 0) part2 += 1;


        if (digits[5] < '9') {
            digits[5] += 1;
        } else if (digits[4] < '9') {
            digits[4] += 1;
            digits[5] = digits[4];
        } else if (digits[3] < '9') {
            digits[3] += 1;
            digits[4] = digits[3];
            digits[5] = digits[3];
        } else if (digits[2] < '9') {
            digits[2] += 1;
            digits[3] = digits[2];
            digits[4] = digits[2];
            digits[5] = digits[2];
        } else if (digits[1] < '9') {
            digits[1] += 1;
            digits[2] = digits[1];
            digits[3] = digits[1];
            digits[4] = digits[1];
            digits[5] = digits[1];
        } else if (digits[0] < '9') {
            digits[0] += 1;
            digits[1] = digits[0];
            digits[2] = digits[0];
            digits[3] = digits[0];
            digits[4] = digits[0];
            digits[5] = digits[0];
        } else {
            break;
        }
    }

    return Result{ .p1 = part1, .p2 = part2 };
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
