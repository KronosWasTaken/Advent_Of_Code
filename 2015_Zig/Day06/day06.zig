const std = @import("std");
var grid1: [1000000]u8 = undefined;
var grid2: [1000000]u8 = undefined;
inline fn solve(input: []const u8) struct { p1: u32, p2: u32 } {
    @setRuntimeSafety(false);
    @memset(&grid1, 0);
    @memset(&grid2, 0);
    var i: usize = 0;
    while (i < input.len) {
        if (input[i] != 't') break;
        const op: u8 = if (input[i + 6] == 'n') 0 else if (input[i + 6] == 'f') 1 else 2;
        i += if (op == 0) 8 else if (op == 1) 9 else 7;
        var x1: u16 = 0;
        while (input[i] != ',') : (i += 1) x1 = x1 * 10 + input[i] - '0';
        i += 1;
        var y1: u16 = 0;
        while (input[i] != ' ') : (i += 1) y1 = y1 * 10 + input[i] - '0';
        i += 9;
        var x2: u16 = 0;
        while (input[i] != ',') : (i += 1) x2 = x2 * 10 + input[i] - '0';
        i += 1;
        var y2: u16 = 0;
        while (input[i] >= '0' and input[i] <= '9') : (i += 1) y2 = y2 * 10 + input[i] - '0';
        while (i < input.len and (input[i] == '\n' or input[i] == '\r')) : (i += 1) {}
        const width = x2 - x1 + 1;
        const height = y2 - y1 + 1;
        var y: u16 = 0;
        while (y < height) : (y += 1) {
            const base = (y1 + y) * 1000 + x1;
            if (op == 0) {
                @memset(grid1[base..][0..width], 1);
                var x: u16 = 0;
                while (x < width) : (x += 1) grid2[base + x] += 1;
            } else if (op == 1) {
                @memset(grid1[base..][0..width], 0);
                var x: u16 = 0;
                while (x < width) : (x += 1) grid2[base + x] -|= 1;
            } else {
                var x: u16 = 0;
                while (x < width) : (x += 1) {
                    grid1[base + x] ^= 1;
                    grid2[base + x] += 2;
                }
            }
        }
    }
    var p1: u32 = 0;
    var p2: u32 = 0;
    const Vec = @Vector(64, u8);
    var j: usize = 0;
    while (j + 64 <= 1000000) : (j += 64) {
        const v1: Vec = grid1[j..][0..64].*;
        const v2: Vec = grid2[j..][0..64].*;
        p1 += @reduce(.Add, @as(@Vector(64, u32), v1));
        p2 += @reduce(.Add, @as(@Vector(64, u32), v2));
    }
    while (j < 1000000) : (j += 1) {
        p1 += grid1[j];
        p2 += grid2[j];
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
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
