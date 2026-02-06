const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

fn simulate(fish: *[9]u64, days: usize) u64 {
    var day: usize = 0;
    while (day < days) : (day += 1) {
        fish[(day + 7) % 9] += fish[day % 9];
    }
    var total: u64 = 0;
    for (fish) |value| total += value;
    return total;
}

fn solve(input: []const u8) Result {
    var fish: [9]u64 = [_]u64{0} ** 9;
    var value: usize = 0;
    var in_number = false;
    for (input) |c| {
        if (c >= '0' and c <= '9') {
            value = value * 10 + @as(usize, c - '0');
            in_number = true;
            continue;
        }
        if (!in_number) continue;
        fish[value] += 1;
        value = 0;
        in_number = false;
    }
    if (in_number) fish[value] += 1;

    var fish_copy = fish;
    const p1 = simulate(&fish_copy, 80);
    const p2 = simulate(&fish, 256);
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
