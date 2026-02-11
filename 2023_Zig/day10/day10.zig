const std = @import("std");

const Result = struct {
    p1: i32,
    p2: i32,
};

const Dir = struct { dx: i32, dy: i32 };
const UP = Dir{ .dx = 0, .dy = -1 };
const DOWN = Dir{ .dx = 0, .dy = 1 };
const LEFT = Dir{ .dx = -1, .dy = 0 };
const RIGHT = Dir{ .dx = 1, .dy = 0 };

pub fn solve(input: []const u8) Result {
    var width: usize = 0;
    var height: usize = 0;
    var cur: usize = 0;
    for (input) |b| {
        if (b == '\r') continue;
        if (b == '\n') {
            if (cur > 0) {
                if (width == 0) width = cur;
                height += 1;
                cur = 0;
            }
        } else {
            cur += 1;
        }
    }
    if (cur > 0) {
        if (width == 0) width = cur;
        height += 1;
    }
    if (width == 0 or height == 0) return .{ .p1 = 0, .p2 = 0 };

    const stride: usize = width + 2;
    const total = (height + 2) * stride;
    var grid = std.heap.page_allocator.alloc(u8, total) catch return .{ .p1 = 0, .p2 = 0 };
    defer std.heap.page_allocator.free(grid);
    @memset(grid, '.');

    var start_idx: usize = 0;
    var x: usize = 0;
    var y: usize = 0;
    var idx: usize = stride + 1;
    for (input) |b| {
        if (b == '\r') continue;
        if (b == '\n') {
            if (x > 0) {
                y += 1;
                x = 0;
                idx = (y + 1) * stride + 1;
            }
            continue;
        }
        grid[idx] = b;
        if (b == 'S') start_idx = idx;
        idx += 1;
        x += 1;
    }

    const start_x: i32 = @intCast(start_idx % stride);
    const start_y: i32 = @intCast(start_idx / stride);

    var corner_x = start_x;
    var corner_y = start_y;

    var direction = DOWN;
    const up = grid[start_idx - stride];
    if (up == '|' or up == '7' or up == 'F') direction = UP;

    var pos_x = start_x + direction.dx;
    var pos_y = start_y + direction.dy;
    var steps: i32 = 1;
    var area: i32 = 0;

    while (true) {
        while (true) {
            const tile = grid[@as(usize, @intCast(pos_y)) * stride + @as(usize, @intCast(pos_x))];
            if (tile != '-' and tile != '|') break;
            pos_x += direction.dx;
            pos_y += direction.dy;
            steps += 1;
        }

        const tile = grid[@as(usize, @intCast(pos_y)) * stride + @as(usize, @intCast(pos_x))];
        const next_dir = switch (tile) {
            '7' => if (direction.dy == -1) LEFT else DOWN,
            'F' => if (direction.dy == -1) RIGHT else DOWN,
            'J' => if (direction.dy == 1) LEFT else UP,
            'L' => if (direction.dy == 1) RIGHT else UP,
            else => null,
        };
        const det = corner_x * pos_y - corner_y * pos_x;
        area += det;
        if (next_dir == null) break;
        direction = next_dir.?;
        corner_x = pos_x;
        corner_y = pos_y;
        pos_x += direction.dx;
        pos_y += direction.dy;
        steps += 1;
    }

    const part_one = @divTrunc(steps, 2);
    const area_abs: i32 = if (area < 0) -area else area;
    const part_two = @divTrunc(area_abs, 2) - @divTrunc(steps, 2) + 1;
    return .{ .p1 = part_one, .p2 = part_two };
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
