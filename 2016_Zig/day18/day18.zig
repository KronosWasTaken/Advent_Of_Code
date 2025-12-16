const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const result = solve(input);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
fn solve(input: []const u8) Result {
    const first_row = std.mem.trim(u8, input, &std.ascii.whitespace);
    const width = first_row.len;

var current: u128 = 0;
    for (first_row, 0..) |c, i| {
        if (c == '^') {
            current |= @as(u128, 1) << @intCast(width - 1 - i);
        }
    }

    const mask = if (width == 128) ~@as(u128, 0) else (@as(u128, 1) << @intCast(width)) - 1;
    var total_safe_p1: u32 = 0;
    var total_safe_p2: u32 = 0;

    var row = current;
    for (0..40) |_| {
        const traps = @popCount(row);
        total_safe_p1 += @intCast(width - traps);
        row = ((row << 1) ^ (row >> 1)) & mask;
    }

total_safe_p2 = total_safe_p1;
    for (40..400000) |_| {
        const traps = @popCount(row);
        total_safe_p2 += @intCast(width - traps);
        row = ((row << 1) ^ (row >> 1)) & mask;
    }
    return .{ .p1 = total_safe_p1, .p2 = total_safe_p2 };
}
