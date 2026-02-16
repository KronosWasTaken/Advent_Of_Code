const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u32,
};

fn absI32(value: i32) i32 {
    return if (value < 0) -value else value;
}

fn delta(a: i32, b: i32) i32 {
    const diff = b - a;
    if (diff == 0) return 0;
    if (absI32(diff) > 3) return 0;
    return if (diff > 0) 1 else -1;
}

fn check(report: []const i32) Result {
    if (report.len < 2) return Result{ .p1 = 0, .p2 = 0 };

    var score: i32 = 0;
    var i: usize = 0;
    while (i + 1 < report.len) : (i += 1) {
        score += delta(report[i], report[i + 1]);
    }

    if (absI32(score) == @as(i32, @intCast(report.len - 1))) {
        return Result{ .p1 = 1, .p2 = 1 };
    }

    i = 0;
    while (i < report.len) : (i += 1) {
        var adjusted = score;
        if (i > 0) {
            adjusted -= delta(report[i - 1], report[i]);
        }
        if (i + 1 < report.len) {
            adjusted -= delta(report[i], report[i + 1]);
        }
        if (i > 0 and i + 1 < report.len) {
            adjusted += delta(report[i - 1], report[i + 1]);
        }
        if (absI32(adjusted) == @as(i32, @intCast(report.len - 2))) {
            return Result{ .p1 = 0, .p2 = 1 };
        }
    }

    return Result{ .p1 = 0, .p2 = 0 };
}

fn solve(input: []const u8) Result {
    var report: [64]i32 = undefined;
    var report_len: usize = 0;

    var part_one: u32 = 0;
    var part_two: u32 = 0;

    var value: i32 = 0;
    var sign: i32 = 1;
    var in_number = false;

    for (input) |byte| {
        if (byte == '\r') continue;
        if (byte == '-') {
            sign = -1;
            continue;
        }
        if (byte >= '0' and byte <= '9') {
            value = value * 10 + @as(i32, @intCast(byte - '0'));
            in_number = true;
            continue;
        }
        if (in_number) {
            report[report_len] = value * sign;
            report_len += 1;
            value = 0;
            sign = 1;
            in_number = false;
        }
        if (byte == '\n') {
            if (report_len > 0) {
                const result = check(report[0..report_len]);
                part_one += result.p1;
                part_two += result.p2;
                report_len = 0;
            }
        }
    }

    if (in_number) {
        report[report_len] = value * sign;
        report_len += 1;
    }
    if (report_len > 0) {
        const result = check(report[0..report_len]);
        part_one += result.p1;
        part_two += result.p2;
    }

    return Result{ .p1 = part_one, .p2 = part_two };
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
