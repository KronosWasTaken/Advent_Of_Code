const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u32,
};

const DirsX = [_]i32{ 0, 0, -1, 1 };
const DirsY = [_]i32{ -1, 1, 0, 0 };

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    var width: usize = 0;
    while (width < input.len and input[width] != '\n' and input[width] != '\r') : (width += 1) {}

    var height: usize = 0;
    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        if (input[i] == '\n') height += 1;
    }
    if (input.len > 0 and input[input.len - 1] != '\n') height += 1;

    const size = width * height;
    const grid = allocator.alloc(u8, size) catch unreachable;
    defer allocator.free(grid);

    var idx: usize = 0;
    for (input) |c| {
        if (c >= '0' and c <= '9') {
            grid[idx] = c;
            idx += 1;
        }
    }

    var p1: u32 = 0;
    var basins = allocator.alloc(u32, size) catch unreachable;
    defer allocator.free(basins);
    var basin_count: usize = 0;

    i = 0;
    while (i < size) : (i += 1) {
        const cur = grid[i];
        const x = i % width;
        const y = i / width;
        var low = true;

        var d: usize = 0;
        while (d < 4) : (d += 1) {
            const nx = @as(i32, @intCast(x)) + DirsX[d];
            const ny = @as(i32, @intCast(y)) + DirsY[d];
            if (nx < 0 or ny < 0 or nx >= @as(i32, @intCast(width)) or ny >= @as(i32, @intCast(height))) continue;
            const nidx = @as(usize, @intCast(ny)) * width + @as(usize, @intCast(nx));
            if (grid[nidx] <= cur) {
                low = false;
                break;
            }
        }
        if (low) p1 += 1 + @as(u32, cur - '0');
    }

    var stack = allocator.alloc(usize, size) catch unreachable;
    defer allocator.free(stack);

    i = 0;
    while (i < size) : (i += 1) {
        if (grid[i] >= '9') continue;
        var size_count: u32 = 0;
        var top: usize = 0;
        stack[top] = i;
        top += 1;
        grid[i] = '9';

        while (top > 0) {
            top -= 1;
            const cur_index = stack[top];
            size_count += 1;
            const cx = cur_index % width;
            const cy = cur_index / width;
            var d: usize = 0;
            while (d < 4) : (d += 1) {
                const nx = @as(i32, @intCast(cx)) + DirsX[d];
                const ny = @as(i32, @intCast(cy)) + DirsY[d];
                if (nx < 0 or ny < 0 or nx >= @as(i32, @intCast(width)) or ny >= @as(i32, @intCast(height))) continue;
                const nidx = @as(usize, @intCast(ny)) * width + @as(usize, @intCast(nx));
                if (grid[nidx] < '9') {
                    grid[nidx] = '9';
                    stack[top] = nidx;
                    top += 1;
                }
            }
        }

        basins[basin_count] = size_count;
        basin_count += 1;
    }

    if (basin_count < 3) return .{ .p1 = p1, .p2 = 0 };
    var a: u32 = 0;
    var b: u32 = 0;
    var c: u32 = 0;
    i = 0;
    while (i < basin_count) : (i += 1) {
        const v = basins[i];
        if (v > a) {
            c = b;
            b = a;
            a = v;
        } else if (v > b) {
            c = b;
            b = v;
        } else if (v > c) {
            c = v;
        }
    }

    return .{ .p1 = p1, .p2 = a * b * c };
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
