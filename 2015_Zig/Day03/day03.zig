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

const BITS = GRID_SIZE * GRID_SIZE;
const WORDS = (BITS + 63) / 64;

// Marks a house as visited and returns 1 if it was new, 0 otherwise.
inline fn visit(grid: *[WORDS]u64, pos: usize) u32 {
    const mask = @as(u64, 1) << @as(u6, @truncate(pos));
    const word = &grid[pos >> 6];
    const is_new = word.* & mask == 0;
    word.* |= mask;
    return @intFromBool(is_new);
}

fn solve(data: []const u8) [2]u32 {
    @setRuntimeSafety(false);
    var grid1 = [_]u64{0} ** WORDS;
    var grid2 = [_]u64{0} ** WORDS;

    var sx: i16 = 0;
    var sy: i16 = 0;
    var rx: i16 = 0;
    var ry: i16 = 0;
    var rsx: i16 = 0;
    var rsy: i16 = 0;

    const start = idx(0, 0);
    _ = visit(&grid1, start);
    _ = visit(&grid2, start);

    var count1: u32 = 1;
    var count2: u32 = 1;

    for (data, 0..) |c, i| {
        const dx = DX[c];
        const dy = DY[c];

        sx += dx;
        sy += dy;
        count1 += visit(&grid1, idx(sx, sy));

        if (i & 1 == 0) {
            rx += dx;
            ry += dy;
            count2 += visit(&grid2, idx(rx, ry));
        } else {
            rsx += dx;
            rsy += dy;
            count2 += visit(&grid2, idx(rsx, rsy));
        }
    }
    return .{ count1, count2 };
}

pub fn main() !void {
    const data = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(data);
    const elapsed_ns = timer.read() - start;
    const avg_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result[0]});
    std.debug.print("Part 2: {}\n", .{result[1]});
    std.debug.print("Time: {d:.3} microseconds\n", .{avg_us});
}
