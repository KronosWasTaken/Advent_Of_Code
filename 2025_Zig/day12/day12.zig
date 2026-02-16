const std = @import("std");

const Result = struct { p1: usize, p2: []const u8 };

pub fn solve(input: []const u8) Result {
    var count: usize = 0;
    var index: usize = 0;
    var group_idx: usize = 0;
    var w: u32 = 0;
    var h: u32 = 0;
    var sum: u32 = 0;

    var i: usize = 0;
    while (i < input.len) {
        while (i < input.len and (input[i] < '0' or input[i] > '9')) : (i += 1) {}
        if (i >= input.len) break;
        var value: u32 = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
            value = value * 10 + @as(u32, input[i] - '0');
        }

        if (index >= 6) {
            switch (group_idx) {
                0 => w = value,
                1 => h = value,
                else => sum += value,
            }
            group_idx += 1;
            if (group_idx == 8) {
                if ((w / 3) * (h / 3) >= sum) count += 1;
                group_idx = 0;
                sum = 0;
            }
        }

        index += 1;
    }

    return .{ .p1 = count, .p2 = "n/a" };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {s}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
