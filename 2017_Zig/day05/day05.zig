const std = @import("std");
const Result = struct { p1: usize, p2: usize };
fn solve(input: []const u8) Result {
    var jumps: [2048]i32 = undefined;
    var count: usize = 0;
    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (trimmed.len > 0) {
            jumps[count] = std.fmt.parseInt(i32, trimmed, 10) catch {
                std.debug.print("Failed to parse: '{s}'\n", .{trimmed});
                continue;
            };
            count += 1;
        }
    }
    var jumps1: [2048]i32 = undefined;
    @memcpy(jumps1[0..count], jumps[0..count]);
    var total1: usize = 0;
    var index1: isize = 0;
    while (index1 >= 0 and index1 < @as(isize, @intCast(count))) {
        const idx: usize = @intCast(index1);
        const offset = jumps1[idx];
        jumps1[idx] += 1;
        index1 += offset;
        total1 += 1;
    }
    var jumps2: [2048]i32 = undefined;
    @memcpy(jumps2[0..count], jumps[0..count]);
    var total2: usize = 0;
    var index2: isize = 0;
    while (index2 >= 0 and index2 < @as(isize, @intCast(count))) {
        const idx: usize = @intCast(index2);
        const offset = jumps2[idx];
        jumps2[idx] += if (offset >= 3) @as(i32, -1) else @as(i32, 1);
        index2 += offset;
        total2 += 1;
    }
    return .{ .p1 = total1, .p2 = total2 };
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var total: u64 = 0;
    const iterations = 10; 
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