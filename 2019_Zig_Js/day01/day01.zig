const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u32,
};

fn solve(input: []const u8) Result {
    var part1: u32 = 0;
    var part2: u32 = 0;
    var num: u32 = 0;

    for (input) |c| {
        if (c >= '0' and c <= '9') {
            num = num * 10 + (c - '0');
        } else if (num > 0) {
            const fuel = num / 3 - 2;
            part1 += fuel;
            var f = fuel;
            while (f > 8) {
                f = f / 3 - 2;
                part2 += f;
            }
            num = 0;
        }
    }

    part2 += part1;
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

