const std = @import("std");

const Result = struct { p1: i32, p2: i32 };

pub fn solve(input: []const u8) Result {
    var dial: i32 = 50;
    var part_one: i32 = 0;
    var part_two: i32 = 0;
    var direction: ?u8 = null;

    var i: usize = 0;
    while (i < input.len) {
        const c = input[i];
        if (c >= 'A' and c <= 'Z') {
            direction = c;
            i += 1;
            continue;
        }

        if (c == '-' or (c >= '0' and c <= '9')) {
            var sign: i32 = 1;
            if (c == '-') {
                sign = -1;
                i += 1;
            }
            var value: i32 = 0;
            while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
                value = value * 10 + @as(i32, input[i] - '0');
            }
            if (direction) |dir| {
                const amount = sign * value;
                if (dir == 'R') {
                    part_two += @divFloor(dial + amount, 100);
                    dial = @mod(dial + amount, 100);
                } else {
                    const reversed = @mod(100 - dial, 100);
                    part_two += @divFloor(reversed + amount, 100);
                    dial = std.math.mod(i32, dial - amount, 100) catch unreachable;
                }
                if (dial == 0) part_one += 1;
                direction = null;
            }
            continue;
        }

        i += 1;
    }

    return .{ .p1 = part_one, .p2 = part_two };
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
