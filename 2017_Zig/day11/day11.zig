const std = @import("std");
const Result = struct { p1: i32, p2: i32 };
fn hexDistance(q: i32, r: i32) i32 {
    const s = -q - r;
    const aq: i32 = @intCast(@abs(q));
    const ar: i32 = @intCast(@abs(r));
    const as: i32 = @intCast(@abs(s));
    return @divTrunc(aq + ar + as, 2);
}
fn solve(input: []const u8) Result {
    var q: i32 = 0;
    var r: i32 = 0;
    var max_dist: i32 = 0;
    var i: usize = 0;
    while (i < input.len) {
        const first = input[i];
        i += 1;
        if (first == 'n') {
            if (i < input.len and input[i] == 'e') {
                i += 1;
                q += 1;
                r -= 1;
            } else if (i < input.len and input[i] == 'w') {
                i += 1;
                q -= 1;
            } else {
                r -= 1;
            }
        } else if (first == 's') {
            if (i < input.len and input[i] == 'e') {
                i += 1;
                q += 1;
            } else if (i < input.len and input[i] == 'w') {
                i += 1;
                q -= 1;
                r += 1;
            } else {
                r += 1;
            }
        }
        const dist = hexDistance(q, r);
        max_dist = @max(max_dist, dist);
        if (i < input.len and input[i] == ',') i += 1;
    }
    return .{ .p1 = hexDistance(q, r), .p2 = max_dist };
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
