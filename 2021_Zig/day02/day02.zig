const std = @import("std");

const Result = struct {
    p1: i32,
    p2: i32,
};

fn solve(input: []const u8) Result {
    var pos1: i32 = 0;
    var depth1: i32 = 0;
    var pos2: i32 = 0;
    var depth2: i32 = 0;
    var aim: i32 = 0;

    var i: usize = 0;
    while (i < input.len) {
        while (i < input.len and (input[i] == ' ' or input[i] == '\n' or input[i] == '\r' or input[i] == '\t')) : (i += 1) {}
        if (i >= input.len) break;

        const cmd_start = i;
        while (i < input.len and input[i] >= 'a' and input[i] <= 'z') : (i += 1) {}
        const cmd = input[cmd_start..i];

        while (i < input.len and (input[i] == ' ' or input[i] == '\n' or input[i] == '\r' or input[i] == '\t')) : (i += 1) {}
        var value: i32 = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
            value = value * 10 + @as(i32, input[i] - '0');
        }

        switch (cmd.len) {
            2 => {
                depth1 -= value;
                aim -= value;
            },
            4 => {
                depth1 += value;
                aim += value;
            },
            7 => {
                pos1 += value;
                pos2 += value;
                depth2 += aim * value;
            },
            else => {},
        }
    }

    return .{ .p1 = pos1 * depth1, .p2 = pos2 * depth2 };
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
