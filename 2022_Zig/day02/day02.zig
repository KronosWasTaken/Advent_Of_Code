const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u32,
};

fn solve(input: []const u8) Result {
    const score1 = [_]u32{ 4, 8, 3, 1, 5, 9, 7, 2, 6 };
    const score2 = [_]u32{ 3, 4, 8, 1, 5, 9, 2, 6, 7 };
    var p1: u32 = 0;
    var p2: u32 = 0;

    var i: usize = 0;
    while (i < input.len) {
        while (i < input.len and (input[i] == ' ' or input[i] == '\r' or input[i] == '\n')) : (i += 1) {}
        if (i >= input.len) break;
        const a = input[i];
        i += 1;
        while (i < input.len and (input[i] == ' ' or input[i] == '\r' or input[i] == '\n')) : (i += 1) {}
        if (i >= input.len) break;
        const b = input[i];
        i += 1;

        const idx: usize = 3 * @as(usize, a - 'A') + @as(usize, b - 'X');
        p1 += score1[idx];
        p2 += score2[idx];
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
