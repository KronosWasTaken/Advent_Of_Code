const std = @import("std");
const Result = struct { p1: i64, p2: i64 };
fn solve(input: []const u8) Result {
    var n: u64 = 0;
    for (input) |c| {
        if (c >= '0' and c <= '9') {
            n = n * 10 + (c - '0');
        } else if (n > 0) {
            break;
        }
    }
    const part1 = (n - 2) * (n - 2);
    var part2: u64 = 0;
    var num = 100 * (n + 1000);
    var i: usize = 1001;
    while (i > 0) : (i -= 1) {
        var f: u64 = 2;
        var s: u64 = 4;
        while (s <= num) {
            if (num % f == 0) {
                part2 += 1;
                break;
            }
            f += 1;
            s += (f << 1) - 1;
        }
        num += 17;
    }
    return .{ .p1 = @intCast(part1), .p2 = @intCast(part2) };
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
