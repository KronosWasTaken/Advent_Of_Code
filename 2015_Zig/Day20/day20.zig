const std = @import("std");
fn solve(input: []const u8) struct { p1: u32, p2: u32 } {
    @setRuntimeSafety(false);
    var target: u32 = 0;
    for (input) |c| {
        if (c >= '0' and c <= '9') {
            target = target * 10 + (c - '0');
        }
    }
    if (target == 0) return .{ .p1 = 0, .p2 = 0 };
    const limit: usize = 1000000;
    var houses1: [limit]u32 = undefined;
    var houses2: [limit]u32 = undefined;
    @memset(&houses1, 0);
    @memset(&houses2, 0);
    var elf: u32 = 1;
    while (elf < limit) : (elf += 1) {
        var h: usize = elf;
        while (h < limit) : (h += elf) {
            houses1[h] += elf * 10;
        }
        h = elf;
        var count: u32 = 0;
        while (h < limit and count < 50) : ({ h += elf; count += 1; }) {
            houses2[h] += elf * 11;
        }
    }
    var p1: u32 = 0;
    var p2: u32 = 0;
    for (houses1, 0..) |presents, h| {
        if (p1 == 0 and presents >= target) p1 = @intCast(h);
        if (p2 == 0 and houses2[h] >= target) p2 = @intCast(h);
        if (p1 != 0 and p2 != 0) break;
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
    std.debug.print("Part 1: {d} | Part 2: {d}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
