const std = @import("std");
inline fn lookAndSay(input: []const u8, output: []u8) usize {
    @setRuntimeSafety(false);
    var out_idx: usize = 0;
    var i: usize = 0;
    const len = input.len;
    while (i < len) {
        const digit = input[i];
        const start = i;
        i += 1;
        while (i + 3 < len and input[i] == digit and input[i + 1] == digit and 
               input[i + 2] == digit and input[i + 3] == digit) {
            i += 4;
        }
        while (i < len and input[i] == digit) : (i += 1) {}
        const count = i - start;
        output[out_idx] = @as(u8, @intCast(count)) + '0';
        output[out_idx + 1] = digit;
        out_idx += 2;
    }
    return out_idx;
}
fn solve(initial: []const u8) struct { p1: usize, p2: usize } {
    @setRuntimeSafety(false);
    var buf1: [6000000]u8 = undefined;
    var buf2: [6000000]u8 = undefined;
    var len = initial.len;
    @memcpy(buf1[0..len], initial);
    var p1: usize = 0;
    var src = &buf1;
    var dst = &buf2;
    for (0..50) |iter| {
        len = lookAndSay(src.*[0..len], dst.*[0..]);
        if (iter == 39) p1 = len;
        const tmp = src;
        src = dst;
        dst = tmp;
    }
    return .{ .p1 = p1, .p2 = len };
}
pub fn main() !void {
    const input = "1113122113";
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\nPart 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
