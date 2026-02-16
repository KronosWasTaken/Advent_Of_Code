const std = @import("std");

const Result = struct { p1: usize, p2: usize };
const Point = struct { x: i32, y: i32 };

const Diagonal = [_]Point{
    .{ .x = -1, .y = -1 }, .{ .x = 0, .y = -1 }, .{ .x = 1, .y = -1 },
    .{ .x = -1, .y = 0 },  .{ .x = 1, .y = 0 },  .{ .x = -1, .y = 1 },
    .{ .x = 0, .y = 1 },   .{ .x = 1, .y = 1 },
};

const Input = struct {
    todo: std.ArrayListUnmanaged(Point),
    padded: []u8,
    width: i32,
    height: i32,
};

pub fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    var parsed = parse(input, allocator);
    defer parsed.todo.deinit(allocator);
    defer allocator.free(parsed.padded);

    const p1 = parsed.todo.items.len;
    const p2 = part2(&parsed, allocator);
    return .{ .p1 = p1, .p2 = p2 };
}

fn parse(input: []const u8, allocator: std.mem.Allocator) Input {
    const width = lineWidth(input);
    const height = lineCount(input);

    const grid = allocator.alloc(u8, @as(usize, @intCast(width * height))) catch unreachable;
    defer allocator.free(grid);
    fillGrid(input, grid, width);

    const padded_width = width + 2;
    const padded_height = height + 2;
    var padded = allocator.alloc(u8, @as(usize, @intCast(padded_width * padded_height))) catch unreachable;
    @memset(padded, 0xFF);

    var todo = std.ArrayListUnmanaged(Point){};

    var y: i32 = 0;
    while (y < height) : (y += 1) {
        var x: i32 = 0;
        while (x < width) : (x += 1) {
            if (gridAt(grid, width, x, y) == '@') {
                var count: u8 = 0;
                for (Diagonal) |d| {
                    const nx = x + d.x;
                    const ny = y + d.y;
                    if (nx >= 0 and nx < width and ny >= 0 and ny < height) {
                        if (gridAt(grid, width, nx, ny) == '@') count += 1;
                    }
                }

                const px = x + 1;
                const py = y + 1;
                padded[index(padded_width, px, py)] = count;
                if (count < 4) todo.append(allocator, .{ .x = px, .y = py }) catch unreachable;
            }
        }
    }

    return .{ .todo = todo, .padded = padded, .width = padded_width, .height = padded_height };
}

fn lineWidth(input: []const u8) i32 {
    var width: i32 = 0;
    var i: usize = 0;
    while (i < input.len and input[i] != '\n') : (i += 1) {
        if (input[i] != '\r') width += 1;
    }
    return width;
}

fn lineCount(input: []const u8) i32 {
    var count: i32 = 0;
    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        if (input[i] == '\n') count += 1;
    }
    if (input.len > 0 and input[input.len - 1] != '\n') count += 1;
    return count;
}

fn fillGrid(input: []const u8, grid: []u8, width: i32) void {
    var x: i32 = 0;
    var y: i32 = 0;
    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        const c = input[i];
        if (c == '\r') continue;
        if (c == '\n') {
            y += 1;
            x = 0;
        } else {
            grid[@as(usize, @intCast(y * width + x))] = c;
            x += 1;
        }
    }
}

fn gridAt(grid: []const u8, width: i32, x: i32, y: i32) u8 {
    return grid[@as(usize, @intCast(y * width + x))];
}

fn index(width: i32, x: i32, y: i32) usize {
    return @as(usize, @intCast(y * width + x));
}

fn part2(parsed: *Input, allocator: std.mem.Allocator) usize {
    var removed: usize = 0;
    while (parsed.todo.items.len > 0) {
        const point = parsed.todo.pop().?;
        removed += 1;
        for (Diagonal) |d| {
            const nx = point.x + d.x;
            const ny = point.y + d.y;
            const idx = index(parsed.width, nx, ny);
            if (parsed.padded[idx] == 4) {
                parsed.todo.append(allocator, .{ .x = nx, .y = ny }) catch unreachable;
            }
            parsed.padded[idx] -= 1;
        }
    }
    return removed;
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
