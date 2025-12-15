const std = @import("std");
inline fn solve(input: []const u8) struct { p1: i32, p2: usize } {
    @setRuntimeSafety(false);
    var count: i32 = 0;
    var i: usize = 0;
    const Vec = @Vector(64, u8);
    const open: Vec = @splat('(');
    while (i + 64 <= input.len) : (i += 64) {
        count += @reduce(.Add, @as(@Vector(64, i32), @intCast(@as(@Vector(64, u8), @intFromBool(input[i..][0..64].* == open)))));
    }
    while (i < input.len) : (i += 1) {
        count += @intFromBool(input[i] == '(');
    }
    var floor: i32 = 0;
    var basement: usize = 0;
    for (input, 0..) |c, j| {
        floor += @as(i32, @intFromBool(c == '(')) * 2 - 1;
        if (floor == -1) {
            basement = j + 1;
            break;
        }
    }
    return .{ .p1 = count * 2 - @as(i32, @intCast(input.len)), .p2 = basement };
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var result = solve(input);
    for (0..100) |_| result = solve(input);
    const iters: u32 = 100000;
    var timer = try std.time.Timer.start();
    const start = timer.read();
    for (0..iters) |_| result = solve(input);
    const elapsed_us = @as(f64, @floatFromInt(timer.read() - start)) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Total: {d:.2} microseconds\n", .{elapsed_us});
    std.debug.print("Average: {d:.4} microseconds\n", .{elapsed_us / @as(f64, @floatFromInt(iters))});
}
