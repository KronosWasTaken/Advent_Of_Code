const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
const SIZE: usize = 500;
const HALF: i32 = SIZE / 2;
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
    const offset_y = HALF - @divTrunc(input_height, 2);
    const offset_x = HALF - @divTrunc(input_width, 2);
    var grid1 = gpa.alloc(bool, SIZE * SIZE) catch unreachable;
    defer gpa.free(grid1);
    @memset(grid1, false);
    for (input_grid.items, 0..) |row, y| {
        for (row, 0..) |cell, x| {
            if (cell == '#') {
                const gy: usize = @intCast(@as(i32, @intCast(y)) + offset_y);
                const gx: usize = @intCast(@as(i32, @intCast(x)) + offset_x);
                grid1[gy * SIZE + gx] = true;
            }
        }
    }
    var x: i32 = HALF;
    var y: i32 = HALF;
    var dx: i32 = 0;
    var dy: i32 = -1;
    var infections: u32 = 0;
    for (0..10000) |_| {
        const idx: usize = @intCast(@as(usize, @intCast(y)) * SIZE + @as(usize, @intCast(x)));
        if (grid1[idx]) {
            const tmp = dx;
            dx = -dy;
            dy = tmp;
            grid1[idx] = false;
        } else {
            const tmp = dx;
            dx = dy;
            dy = -tmp;
            grid1[idx] = true;
            infections += 1;
        }
        x += dx;
        y += dy;
    }
    const p1 = infections;
    var grid2 = gpa.alloc(u8, SIZE * SIZE) catch unreachable;
    defer gpa.free(grid2);
    @memset(grid2, 0);
    for (input_grid.items, 0..) |row, y_val| {
        for (row, 0..) |cell, x_val| {
            if (cell == '#') {
                const gy: usize = @intCast(@as(i32, @intCast(y_val)) + offset_y);
                const gx: usize = @intCast(@as(i32, @intCast(x_val)) + offset_x);
                grid2[gy * SIZE + gx] = 2;
            }
        }
    }
    x = HALF;
    y = HALF;
    dx = 0;
    dy = -1;
    var infections2: u32 = 0;
    var i: u32 = 0;
    while (i < 10_000_000) : (i += 1) {
        const idx: usize = @as(usize, @intCast(y)) * SIZE + @as(usize, @intCast(x));
        const state = grid2[idx];
        const new_dx: i32 = switch (state) {
            0 => dy,
            1 => dx,
            2 => -dy,
            3 => -dx,
            else => unreachable,
        };
        const new_dy: i32 = switch (state) {
            0 => -dx,
            1 => dy,
            2 => dx,
            3 => -dy,
            else => unreachable,
        };
        dx = new_dx;
        dy = new_dy;
        infections2 += @intFromBool(state == 1);
        grid2[idx] = (state + 1) & 3;
        x += dx;
        y += dy;
    }
    return .{ .p1 = p1, .p2 = infections2 };
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