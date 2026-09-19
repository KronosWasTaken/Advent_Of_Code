const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
fn solve(input: []const u8) Result {
    const digits = std.mem.trimRight(u8, input, &std.ascii.whitespace);
    var p1: u32 = 0;
    var p2: u32 = 0;
    const half = digits.len / 2;
    for (digits[0..digits.len-1], 0..) |d, i| {
        const val = d - '0';
        if (d == digits[i + 1]) p1 += val;
        if (d == digits[(i + half) % digits.len]) p2 += val;
    }
    if (digits[digits.len-1] == digits[0]) p1 += digits[digits.len-1] - '0';
    if (digits[digits.len-1] == digits[half - 1]) p2 += digits[digits.len-1] - '0';
    return .{ .p1 = p1, .p2 = p2 };
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const result = solve(input);
    const elapsed_ns = timer.read();
    const avg_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{avg_us});
}
