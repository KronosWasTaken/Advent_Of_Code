const std = @import("std");

const Result = struct { p1: u64, p2: u64 };

const Grid = struct {
    width: i32,
    height: i32,
    data: []const u8,
};

pub fn solve(input: []const u8) Result {
    const grid = parseGrid(input);
    defer std.heap.page_allocator.free(grid.data);

    const bottom = grid.height - 1;
    var right = grid.width;

    var part_one: u64 = 0;
    var part_two: u64 = 0;

    var x: i32 = grid.width - 1;
    while (x >= 0) : (x -= 1) {
        if (gridAt(grid, x, bottom) == ' ') continue;
        const left = x;
        const plus = gridAt(grid, left, bottom) == '+';
        var rows_sum: u64 = if (plus) 0 else 1;
        var cols_sum: u64 = if (plus) 0 else 1;

        var y: i32 = 0;
        while (y < bottom) : (y += 1) {
            var num: u64 = 0;
            var cx: i32 = left;
            while (cx < right) : (cx += 1) {
                num = acc(grid, num, cx, y);
            }
            if (plus) rows_sum += num else rows_sum *= num;
        }

        var cx: i32 = left;
        while (cx < right) : (cx += 1) {
            var num: u64 = 0;
            y = 0;
            while (y < bottom) : (y += 1) {
                num = acc(grid, num, cx, y);
            }
            if (plus) cols_sum += num else cols_sum *= num;
        }

        part_one += rows_sum;
        part_two += cols_sum;
        right = left - 1;
    }

    return .{ .p1 = part_one, .p2 = part_two };
}

fn parseGrid(input: []const u8) Grid {
    const allocator = std.heap.page_allocator;
    var lines = std.ArrayListUnmanaged([]const u8){};
    defer lines.deinit(allocator);

    var start: usize = 0;
    var i: usize = 0;
    while (i <= input.len) : (i += 1) {
        if (i == input.len or input[i] == '\n') {
            var end = i;
            if (end > start and input[end - 1] == '\r') end -= 1;
            if (end > start) lines.append(allocator, input[start..end]) catch unreachable;
            start = i + 1;
        }
    }

    const height = @as(i32, @intCast(lines.items.len));
    const width = if (lines.items.len > 0) @as(i32, @intCast(lines.items[0].len)) else 0;

    const data = allocator.alloc(u8, @as(usize, @intCast(width * height))) catch unreachable;
    var idx: usize = 0;
    for (lines.items) |line| {
        std.mem.copyForwards(u8, data[idx .. idx + line.len], line);
        idx += line.len;
    }

    return .{ .width = width, .height = height, .data = data };
}

fn gridAt(grid: Grid, x: i32, y: i32) u8 {
    return grid.data[@as(usize, @intCast(y * grid.width + x))];
}

fn acc(grid: Grid, number: u64, x: i32, y: i32) u64 {
    const digit = gridAt(grid, x, y);
    return if (digit == ' ') number else 10 * number + @as(u64, digit - '0');
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
