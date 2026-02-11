const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u32,
};

fn mask(s: []const u8) u128 {
    var acc: u128 = 0;
    for (s) |b| {
        acc |= (@as(u128, 1) << @as(u7, @intCast(b)));
    }
    return acc;
}

fn priority(value: u128) u32 {
    const bit: u32 = @intCast(@ctz(value));
    return if (bit > 96) bit - 96 else bit - 38;
}

fn solve(input: []const u8) Result {
    var p1: u32 = 0;
    var p2: u32 = 0;

    var lines = std.mem.splitAny(u8, input, "\r\n");
    var group: [3]u128 = undefined;
    var count: usize = 0;

    while (lines.next()) |line| {
        if (line.len == 0) continue;
        const half = line.len / 2;
        p1 += priority(mask(line[0..half]) & mask(line[half..]));

        group[count] = mask(line);
        count += 1;
        if (count == 3) {
            p2 += priority(group[0] & group[1] & group[2]);
            count = 0;
        }
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
