const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
const SIZE: usize = 250;
const HALF: usize = SIZE / 2;
const CENTER: usize = SIZE * HALF + HALF;
fn solve(input: []const u8) Result {
    const gpa = std.heap.page_allocator;
    var input_grid: std.ArrayList([]const u8) = .{};
    defer input_grid.deinit(gpa);
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        input_grid.append(gpa, line) catch unreachable;
    }
    const input_height: i32 = @intCast(input_grid.items.len);
    const input_width: i32 = @intCast(input_grid.items[0].len);
    const grid_size: usize = 500;
    const grid_half: i32 = 250;
    var grid1 = gpa.alloc(bool, grid_size * grid_size) catch unreachable;
    defer gpa.free(grid1);
    @memset(grid1, false);
    const offset_y = grid_half - @divTrunc(input_height, 2);
    const offset_x = grid_half - @divTrunc(input_width, 2);
    for (input_grid.items, 0..) |row, y| {
        for (row, 0..) |cell, x| {
            if (cell == '#') {
                const gy: usize = @intCast(@as(i32, @intCast(y)) + offset_y);
                const gx: usize = @intCast(@as(i32, @intCast(x)) + offset_x);
                grid1[gy * grid_size + gx] = true;
            }
        }
    }
    var x: i32 = grid_half;
    var y: i32 = grid_half;
    var dir: u2 = 0;
    var infections: u32 = 0;
    const DX = [4]i32{ 0, 1, 0, -1 };
    const DY = [4]i32{ -1, 0, 1, 0 };
    for (0..10000) |_| {
        const idx: usize = @intCast(@as(usize, @intCast(y)) * grid_size + @as(usize, @intCast(x)));
        if (grid1[idx]) {
            dir +%= 1;
            grid1[idx] = false;
        } else {
            dir -%= 1;
            grid1[idx] = true;
            infections += 1;
        }
        x += DX[dir];
        y += DY[dir];
    }
    const p1 = infections;
    var grid = gpa.alloc(u8, SIZE * SIZE) catch unreachable;
    defer gpa.free(grid);
    @memset(grid, 0);
    var cache: [4][4][256]u32 = undefined;
    for (0..4) |quadrant| {
        for (0..4) |direction| {
            for (0..256) |state| {
                cache[quadrant][direction][state] = computeBlock(grid, quadrant, direction, state);
            }
        }
    }
    const offset_compressed = SIZE - (@as(usize, @intCast(input_width)) / 2);
    for (input_grid.items, 0..) |row, y_val| {
        for (row, 0..) |cell, x_val| {
            if (cell == '#') {
                const adjusted_x = x_val + offset_compressed;
                const adjusted_y = y_val + offset_compressed;
                const index = SIZE * (adjusted_y / 2) + (adjusted_x / 2);
                const offset_bits: u3 = @intCast(4 * (adjusted_y % 2) + 2 * (adjusted_x % 2));
                grid[index] |= @as(u8, 2) << offset_bits;
            }
        }
    }
    var index: usize = CENTER;
    var quadrant: usize = 0;
    var direction: usize = 0;
    var infected: usize = 0;
    var remaining: usize = 10_000_000;
    while (remaining > 8) {
        const state: usize = grid[index];
        const pack = cache[quadrant][direction][state];
        grid[index] = @truncate(pack); 
        index = index +% ((pack >> 20) -% SIZE); 
        quadrant = ((pack >> 8) & 3); 
        direction = ((pack >> 10) & 3); 
        infected += ((pack >> 12) & 15); 
        remaining -= ((pack >> 16) & 15); 
    }
    for (0..remaining) |_| {
        const result = step(grid, index, quadrant, direction);
        index = result[0];
        quadrant = result[1];
        direction = result[2];
        infected += result[3];
    }
    return .{ .p1 = p1, .p2 = @intCast(infected) };
}
fn computeBlock(grid: []u8, quadrant_in: usize, direction_in: usize, state: usize) u32 {
    var index: usize = CENTER;
    var quadrant = quadrant_in;
    var direction = direction_in;
    var infected: usize = 0;
    var steps: usize = 0;
    grid[CENTER] = @intCast(state);
    while (index == CENTER and steps < 8) {
        const result = step(grid, index, quadrant, direction);
        index = result[0];
        quadrant = result[1];
        direction = result[2];
        infected += result[3];
        steps += 1;
    }
    const next_state = grid[CENTER];
    grid[CENTER] = 0;
    const next_index = index +% SIZE -% CENTER;
    return @as(u32, next_state) |
           (@as(u32, @intCast(quadrant)) << 8) |
           (@as(u32, @intCast(direction)) << 10) |
           (@as(u32, @intCast(infected)) << 12) |
           (@as(u32, @intCast(steps)) << 16) |
           (@as(u32, @intCast(next_index)) << 20);
}
fn step(grid: []u8, index: usize, quadrant: usize, direction: usize) [4]usize {
    const shift: u3 = @intCast(2 * quadrant);
    const node = (grid[index] >> shift) & 3;
    const next_node = (node + 1) & 3;
    const next_direction = (direction + node + 3) % 4;
    const mask = ~(@as(u8, 0b11) << shift);
    grid[index] = (grid[index] & mask) | (next_node << shift);
    var x = 2 * (index % SIZE) + (quadrant % 2);
    var y = 2 * (index / SIZE) + (quadrant / 2);
    switch (next_direction) {
        0 => y -= 1,
        1 => x += 1,
        2 => y += 1,
        3 => x -= 1,
        else => unreachable,
    }
    const next_index = SIZE * (y / 2) + (x / 2);
    const next_quadrant = 2 * (y % 2) + (x % 2);
    const infected: usize = if (next_node == 2) 1 else 0;
    return .{ next_index, next_quadrant, next_direction, infected };
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
