const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u32,
};

fn setBit(bits: *[3]u64, x: usize) void {
    bits[x >> 6] |= @as(u64, 1) << @intCast(x & 63);
}

fn countLoops(
    width: usize,
    start_x: usize,
    start_y: usize,
    up: []const i16,
    down: []const i16,
    left: []const i16,
    right: []const i16,
    cells: []const usize,
) u32 {
    const size = up.len;
    const allocator = std.heap.page_allocator;
    var stamps = allocator.alloc(u32, size * 4) catch unreachable;
    defer allocator.free(stamps);
    @memset(stamps, 0);
    var gen: u32 = 1;
    var loops: u32 = 0;

    for (cells) |cell| {
        if (cell == start_y * width + start_x) continue;
        const block_y = cell / width;
        const block_x = cell % width;

        var cx = start_x;
        var cy = start_y;
        var cdir: u8 = 0;
        gen += 1;

        while (true) {
            const state = (cy * width + cx) * 4 + cdir;
            if (stamps[state] == gen) {
                loops += 1;
                break;
            }
            stamps[state] = gen;

            const idx = cy * width + cx;
            switch (cdir) {
                0 => {
                    var wall = up[idx];
                    if (block_x == cx and block_y < cy and (wall < 0 or block_y > @as(usize, @intCast(wall)))) wall = @intCast(block_y);
                    if (wall < 0) break;
                    cy = @as(usize, @intCast(wall + 1));
                    cdir = 1;
                },
                1 => {
                    var wall = right[idx];
                    if (block_y == cy and block_x > cx and (wall < 0 or block_x < @as(usize, @intCast(wall)))) wall = @intCast(block_x);
                    if (wall < 0) break;
                    cx = @as(usize, @intCast(wall - 1));
                    cdir = 2;
                },
                2 => {
                    var wall = down[idx];
                    if (block_x == cx and block_y > cy and (wall < 0 or block_y < @as(usize, @intCast(wall)))) wall = @intCast(block_y);
                    if (wall < 0) break;
                    cy = @as(usize, @intCast(wall - 1));
                    cdir = 3;
                },
                else => {
                    var wall = left[idx];
                    if (block_y == cy and block_x < cx and (wall < 0 or block_x > @as(usize, @intCast(wall)))) wall = @intCast(block_x);
                    if (wall < 0) break;
                    cx = @as(usize, @intCast(wall + 1));
                    cdir = 0;
                },
            }
        }
    }

    return loops;
}

fn solve(input: []const u8) Result {
    const line_end = std.mem.indexOfScalar(u8, input, '\n') orelse 0;
    var width = line_end;
    var stride = line_end + 1;
    if (line_end > 0 and input[line_end - 1] == '\r') {
        width = line_end - 1;
        stride = line_end + 1;
    }
    const height = if (stride > 0) input.len / stride else 0;
    if (width == 0 or height == 0) return Result{ .p1 = 0, .p2 = 0 };

    var start_x: usize = 0;
    var start_y: usize = 0;
    for (0..height) |y| {
        const row = input[y * stride ..][0..width];
        if (std.mem.indexOfScalar(u8, row, '^')) |x| {
            start_x = x;
            start_y = y;
            break;
        }
    }

    const size = width * height;
    const allocator = std.heap.page_allocator;
    var up = allocator.alloc(i16, size) catch unreachable;
    var down = allocator.alloc(i16, size) catch unreachable;
    var left = allocator.alloc(i16, size) catch unreachable;
    var right = allocator.alloc(i16, size) catch unreachable;
    defer allocator.free(up);
    defer allocator.free(down);
    defer allocator.free(left);
    defer allocator.free(right);

    for (0..height) |y| {
        var last: i16 = -1;
        for (0..width) |x| {
            const idx = y * width + x;
            left[idx] = last;
            if (input[y * stride + x] == '#') last = @intCast(x);
        }
        last = -1;
        var x_rev: usize = width;
        while (x_rev > 0) {
            x_rev -= 1;
            const idx = y * width + x_rev;
            right[idx] = last;
            if (input[y * stride + x_rev] == '#') last = @intCast(x_rev);
        }
    }

    for (0..width) |x| {
        var last: i16 = -1;
        for (0..height) |y| {
            const idx = y * width + x;
            up[idx] = last;
            if (input[y * stride + x] == '#') last = @intCast(y);
        }
        last = -1;
        var y_rev: usize = height;
        while (y_rev > 0) {
            y_rev -= 1;
            const idx = y_rev * width + x;
            down[idx] = last;
            if (input[y_rev * stride + x] == '#') last = @intCast(y_rev);
        }
    }

    var visited = allocator.alloc([3]u64, height) catch unreachable;
    defer allocator.free(visited);
    @memset(visited, .{ 0, 0, 0 });

    var x = start_x;
    var y = start_y;
    var dir: u8 = 0;

    while (true) {
        const idx = y * width + x;
        switch (dir) {
            0 => {
                const wall = up[idx];
                if (wall < 0) {
                    var yy: usize = y + 1;
                    while (yy > 0) : (yy -= 1) setBit(&visited[yy - 1], x);
                    break;
                }
                const ny = @as(usize, @intCast(wall + 1));
                var yy: usize = y;
                while (yy >= ny) : (yy -= 1) {
                    setBit(&visited[yy], x);
                    if (yy == ny) break;
                }
                y = ny;
                dir = 1;
            },
            1 => {
                const wall = right[idx];
                if (wall < 0) {
                    var xx: usize = x;
                    while (xx < width) : (xx += 1) setBit(&visited[y], xx);
                    break;
                }
                const nx = @as(usize, @intCast(wall - 1));
                var xx: usize = x;
                while (xx <= nx) : (xx += 1) setBit(&visited[y], xx);
                x = nx;
                dir = 2;
            },
            2 => {
                const wall = down[idx];
                if (wall < 0) {
                    var yy: usize = y;
                    while (yy < height) : (yy += 1) setBit(&visited[yy], x);
                    break;
                }
                const ny = @as(usize, @intCast(wall - 1));
                var yy: usize = y;
                while (yy <= ny) : (yy += 1) setBit(&visited[yy], x);
                y = ny;
                dir = 3;
            },
            else => {
                const wall = left[idx];
                if (wall < 0) {
                    var xx: usize = 0;
                    while (xx <= x) : (xx += 1) setBit(&visited[y], xx);
                    break;
                }
                const nx = @as(usize, @intCast(wall + 1));
                var xx: usize = nx;
                while (xx <= x) : (xx += 1) setBit(&visited[y], xx);
                x = nx;
                dir = 0;
            },
        }
    }

    var p1: u32 = 0;
    var visited_list = allocator.alloc(usize, size) catch unreachable;
    defer allocator.free(visited_list);
    var visited_len: usize = 0;

    for (0..height) |yy| {
        const row_bits = visited[yy];
        for (0..3) |chunk| {
            var mask = row_bits[chunk];
            if (chunk == 2 and width % 64 != 0) {
                mask &= (@as(u64, 1) << @intCast(width % 64)) - 1;
            }
            p1 += @popCount(mask);
            while (mask != 0) {
                const bit = @ctz(mask);
                const xx = chunk * 64 + bit;
                visited_list[visited_len] = yy * width + xx;
                visited_len += 1;
                mask &= mask - 1;
            }
        }
    }

    if (visited_len == 0) return Result{ .p1 = p1, .p2 = 0 };

    const cpu_count = std.Thread.getCpuCount() catch 1;
    const thread_count = @max(@as(usize, 1), @min(cpu_count, visited_len));
    const chunk = (visited_len + thread_count - 1) / thread_count;
    var handles = allocator.alloc(std.Thread, thread_count) catch unreachable;
    defer allocator.free(handles);
    var results = allocator.alloc(u32, thread_count) catch unreachable;
    defer allocator.free(results);

    for (0..thread_count) |i| {
        const start = i * chunk;
        const end = @min(visited_len, start + chunk);
        const slice = visited_list[start..end];
        handles[i] = std.Thread.spawn(.{}, struct {
            fn run(
                res: *u32,
                width_: usize,
                sx: usize,
                sy: usize,
                up_: []const i16,
                down_: []const i16,
                left_: []const i16,
                right_: []const i16,
                cells_: []const usize,
            ) void {
                res.* = countLoops(width_, sx, sy, up_, down_, left_, right_, cells_);
            }
        }.run, .{ &results[i], width, start_x, start_y, up, down, left, right, slice }) catch unreachable;
    }

    var loops: u32 = 0;
    for (0..thread_count) |i| {
        handles[i].join();
        loops += results[i];
    }

    return Result{ .p1 = p1, .p2 = loops };
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
