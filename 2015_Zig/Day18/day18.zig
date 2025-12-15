const std = @import("std");
const Lights = [100][7]u64;
fn parse(input: []const u8) Lights {
    var grid: Lights = std.mem.zeroes(Lights);
    var y: usize = 0;
    var x: usize = 0;
    var idx: usize = 0;
    while (idx < input.len) : (idx += 1) {
        const c = input[idx];
        if (c == '#' or c == '.') {
            const bit: u64 = @intFromBool(c == '#');
            const block = x / 16;
            const offset: u6 = @intCast(4 * (15 - (x % 16)));
            grid[y][block] |= bit << offset;
            x += 1;
        } else if (c == '\n') {
            if (x > 0) {
                y += 1;
                x = 0;
            }
        }
    }
    return grid;
}
fn gameOfLife(input: *const Lights, part_two: bool) u32 {
    var grids: [2]Lights = undefined;
    grids[0] = input.*;
    var temp: Lights = undefined;
    var current: u1 = 0;
    var step: u32 = 0;
    while (step < 100) : (step += 1) {
        const grid = &grids[current];
        const next = &grids[1 - current];
        var y: usize = 0;
        while (y < 100) : (y += 1) {
            var x: usize = 0;
            while (x < 7) : (x += 1) {
                const cell = grid[y][x];
                var sum = cell + (cell >> 4) + (cell << 4);
                if (x > 0) {
                    sum += grid[y][x - 1] << 60;
                }
                if (x < 6) {
                    sum += grid[y][x + 1] >> 60;
                }
                temp[y][x] = sum;
            }
        }
        y = 0;
        while (y < 100) : (y += 1) {
            const has_above = y > 0;
            const has_below = y < 99;
            var x: usize = 0;
            while (x < 7) : (x += 1) {
                var sum = temp[y][x] - grid[y][x];
                if (has_above) {
                    sum += temp[y - 1][x];
                }
                if (has_below) {
                    sum += temp[y + 1][x];
                }
                const a = sum >> 3;
                const b = sum >> 2;
                const c = sum >> 1;
                const d = sum | grid[y][x];
                next[y][x] = (~a & ~b & c & d) & 0x1111111111111111;
            }
            next[y][6] &= 0x1111000000000000;
        }
        if (part_two) {
            next[0][0] |= 1 << 60;
            next[0][6] |= 1 << 48;
            next[99][0] |= 1 << 60;
            next[99][6] |= 1 << 48;
        }
        current = 1 - current;
    }
    var count: u32 = 0;
    const final_grid = &grids[current];
    for (final_grid) |row| {
        for (row) |cell| {
            count += @popCount(cell);
        }
    }
    return count;
}
fn solve(input: []const u8) struct { p1: u32, p2: u32 } {
    @setRuntimeSafety(false);
    var grid = parse(input);
    const p1 = gameOfLife(&grid, false);
    const p2 = gameOfLife(&grid, true);
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
