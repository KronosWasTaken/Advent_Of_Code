const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u32,
};

const Grid = struct {
    width: usize,
    height: usize,
    data: []u8,
};

const Point = struct {
    x: i32,
    y: i32,
};

fn parse(input: []const u8, allocator: std.mem.Allocator) !struct { grid: Grid, start: Point } {
    var width: usize = 0;
    var grid_height: usize = 0;
    var current_width: usize = 0;
    var i: usize = 0;
    while (i < input.len) {
        const b = input[i];
        if (b == '\r' or b == '\n') {
            if (current_width > 0) {
                if (width == 0) width = current_width;
                grid_height += 1;
                current_width = 0;
            }
            if (b == '\r' and i + 1 < input.len and input[i + 1] == '\n') i += 1;
        } else {
            current_width += 1;
        }
        i += 1;
    }
    if (current_width > 0) {
        if (width == 0) width = current_width;
        grid_height += 1;
    }

    const total = width * grid_height;
    var data = try allocator.alloc(u8, total);
    var start = Point{ .x = 0, .y = 0 };
    var idx: usize = 0;
    var y: usize = 0;
    i = 0;
    while (i < input.len) {
        const b = input[i];
        if (b == '\r' or b == '\n') {
            if (b == '\r' and i + 1 < input.len and input[i + 1] == '\n') i += 1;
            if (idx == (y + 1) * width) y += 1;
        } else {
            data[idx] = b;
            if (b == 'E') {
                const x = idx % width;
                start = .{ .x = @intCast(x), .y = @intCast(y) };
            }
            idx += 1;
        }
        i += 1;
    }

    return .{ .grid = .{ .width = width, .height = grid_height, .data = data }, .start = start };
}

fn height(value: u8) i32 {
    return switch (value) {
        'S' => 'a',
        'E' => 'z',
        else => value,
    };
}

fn bfs(grid: Grid, start: Point, allocator: std.mem.Allocator) Result {
    const total = grid.width * grid.height;
    var visited = allocator.alloc(u8, total) catch unreachable;
    defer allocator.free(visited);
    @memset(visited, 0);

    var queue = allocator.alloc(usize, total) catch unreachable;
    defer allocator.free(queue);

    var head: usize = 0;
    var tail: usize = 0;
    const start_index: usize = @intCast(@as(i32, start.y) * @as(i32, @intCast(grid.width)) + start.x);
    queue[tail] = start_index;
    tail += 1;
    visited[start_index] = 1;

    var steps = allocator.alloc(u32, total) catch unreachable;
    defer allocator.free(steps);
    @memset(steps, 0);

    var p1: u32 = 0;
    var p2: u32 = 0;

    const dirs = [_]Point{ .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 1 }, .{ .x = -1, .y = 0 }, .{ .x = 1, .y = 0 } };

    while (head < tail) {
        const idx = queue[head];
        head += 1;
        const x: i32 = @intCast(idx % grid.width);
        const y: i32 = @intCast(idx / grid.width);
        const current = grid.data[idx];
        const current_height = height(current);

        if (current == 'S' and p1 == 0) p1 = steps[idx];
        if ((current == 'a' or current == 'S') and p2 == 0) p2 = steps[idx];
        if (p1 != 0 and p2 != 0) break;

        for (dirs) |dir| {
            const nx = x + dir.x;
            const ny = y + dir.y;
            if (nx < 0 or ny < 0 or nx >= @as(i32, @intCast(grid.width)) or ny >= @as(i32, @intCast(grid.height))) continue;
            const nidx: usize = @intCast(ny * @as(i32, @intCast(grid.width)) + nx);
            if (visited[nidx] == 1) continue;
            const next_height = height(grid.data[nidx]);
            if (current_height - next_height <= 1) {
                visited[nidx] = 1;
                steps[nidx] = steps[idx] + 1;
                queue[tail] = nidx;
                tail += 1;
            }
        }
    }

    return .{ .p1 = p1, .p2 = p2 };
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const parsed = parse(input, allocator) catch unreachable;
    defer allocator.free(parsed.grid.data);
    return bfs(parsed.grid, parsed.start, allocator);
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
