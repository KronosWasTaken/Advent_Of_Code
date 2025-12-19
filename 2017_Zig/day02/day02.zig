const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
fn solve(input: []const u8) Result {
    var p1: u32 = 0;
    var p2: u32 = 0;
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    var buffer: [20]u32 = undefined; 
    while (lines.next()) |line| {
        var count: usize = 0;
        var tokens = std.mem.tokenizeAny(u8, line, " \t");
        while (tokens.next()) |token| {
            buffer[count] = std.fmt.parseInt(u32, token, 10) catch continue;
            count += 1;
        }
        const nums = buffer[0..count];
        std.mem.sort(u32, nums, {}, comptime std.sort.asc(u32));
        if (count > 0) {
            p1 += nums[count - 1] - nums[0];
            outer: for (nums, 0..) |smaller, i| {
                for (nums[i + 1..]) |larger| {
                    if (larger % smaller == 0) {
                        p2 += larger / smaller;
                        break :outer;
                    }
                }
            }
        }
    }
    return .{ .p1 = p1, .p2 = p2 };
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var total: u64 = 0;
    const iterations = 1000;
    var result: Result = undefined;
    for (0..iterations) |_| {
        var timer = try std.time.Timer.start();
        result = solve(input);
        total += timer.read();
    }
    const avg_ns = total / iterations;
    const avg_us = @as(f64, @floatFromInt(avg_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{avg_us});
}
