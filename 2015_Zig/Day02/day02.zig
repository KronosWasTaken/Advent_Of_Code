const std = @import("std");
inline fn parseNum(data: []const u8, idx: *usize) u32 {
    var n: u32 = 0;
    var found = false;
    while (idx.* < data.len) {
        const c = data[idx.*];
        if (c >= '0' and c <= '9') {
            n = n * 10 + (c - '0');
            found = true;
            idx.* += 1;
        } else if (found) {
            idx.* += 1;
            break;
        } else {
            idx.* += 1;
        }
    }
    return n;
}
fn solve(data: []const u8) [2]u32 {
    var paper: u32 = 0;
    var ribbon: u32 = 0;
    var i: usize = 0;
    while (i < data.len) {
        const l = parseNum(data, &i);
        const w = parseNum(data, &i);
        const h = parseNum(data, &i);
        if (l == 0) break;
        const a = l * w;
        const b = w * h;
        const c = h * l;
        const min = @min(@min(a, b), c);
        paper += 2 * (a + b + c) + min;
        const p1 = l + w;
        const p2 = w + h;
        const p3 = h + l;
        const minp = @min(@min(p1, p2), p3);
        ribbon += 2 * minp + l * w * h;
    }
    return .{ paper, ribbon };
}
pub fn main() !void {
    const data = @embedFile("input.txt");
    _ = solve(data);
    const iterations = 10000;
    var timer = try std.time.Timer.start();
    const start = timer.read();
    var i: usize = 0;
    var result: [2]u32 = undefined;
    while (i < iterations) : (i += 1) {
        result = solve(data);
    }
    const end = timer.read();
    const elapsed_ns = end - start;
    const avg_us = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result[0]});
    std.debug.print("Part 2: {}\n", .{result[1]});
    std.debug.print("Time: {d:.3} microseconds (avg of {} iterations)\n", .{avg_us, iterations});
}
