const std = @import("std");
const Result = struct { p1: usize, p2: usize };
fn solve(input: []const u8) Result {
    const gpa = std.heap.page_allocator;
    var count: usize = 0;
    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |_| count += 1;
    const jumps = gpa.alloc(i32, count * 2) catch unreachable;
    defer gpa.free(jumps);
    @memset(jumps, 0);
    var idx: usize = 0;
    lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (trimmed.len > 0) {
            jumps[idx] = std.fmt.parseInt(i32, trimmed, 10) catch 0;
            jumps[idx + count] = jumps[idx];
            idx += 1;
        }
    }
    var p1: usize = 0;
    var pos: usize = 0;
    while (pos < count) {
        const offset = jumps[pos];
        jumps[pos] += 1;
        pos = pos +% @as(usize, @bitCast(@as(isize, offset)));
        p1 += 1;
    }
    var p2: usize = 0;
    pos = 0;
    while (pos < count) {
        const idx2 = pos + count;
        const offset = jumps[idx2];
        if (offset >= 3) {
            jumps[idx2] -= 1;
        } else {
            jumps[idx2] += 1;
        }
        pos = pos +% @as(usize, @bitCast(@as(isize, offset)));
        p2 += 1;
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
