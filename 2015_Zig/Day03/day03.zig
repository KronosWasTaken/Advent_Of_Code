const std = @import("std");
const GRID_SIZE = 400;
const OFFSET: i32 = GRID_SIZE / 2;
const DX = blk: {
    var table: [256]i16 = [_]i16{0} ** 256;
    table['>'] = 1;
    table['<'] = -1;
    break :blk table;
};
const DY = blk: {
    var table: [256]i16 = [_]i16{0} ** 256;
    table['^'] = 1;
    table['v'] = -1;
    break :blk table;
};
inline fn idx(x: i16, y: i16) usize {
    @setRuntimeSafety(false);
    const xi: i32 = x + OFFSET;
    const yi: i32 = y + OFFSET;
    return @intCast(xi * GRID_SIZE + yi);
}
fn solve(data: []const u8) [2]u32 {
    @setRuntimeSafety(false);
    var grid1 = [_]u8{0} ** (GRID_SIZE * GRID_SIZE);
    var grid2 = [_]u8{0} ** (GRID_SIZE * GRID_SIZE);
    var sx: i16 = 0;
    var sy: i16 = 0;
    var rx: i16 = 0;
    var ry: i16 = 0;
    var rsx: i16 = 0;
    var rsy: i16 = 0;
    const start = idx(0, 0);
    grid1[start] = 1;
    grid2[start] = 1;
    var count1: u32 = 1;
    var count2: u32 = 1;
    for (data, 0..) |c, i| {
        const dx = DX[c];
        const dy = DY[c];
        sx += dx;
        sy += dy;
        const pos1 = idx(sx, sy);
        count1 += @intFromBool(grid1[pos1] == 0);
        grid1[pos1] = 1;
        if (i & 1 == 0) {
            rx += dx;
            ry += dy;
            const pos2 = idx(rx, ry);
            count2 += @intFromBool(grid2[pos2] == 0);
            grid2[pos2] = 1;
        } else {
            rsx += dx;
            rsy += dy;
            const pos2 = idx(rsx, rsy);
            count2 += @intFromBool(grid2[pos2] == 0);
            grid2[pos2] = 1;
        }
    }
    return .{ count1, count2 };
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
