const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

fn bump(grid: *[144]u8, flashed: *[144]bool, stack: *[100]usize, top: *usize, index: usize) void {
    if (grid[index] < 9) {
        grid[index] += 1;
    } else {
        grid[index] = 0;
        flashed[index] = true;
        stack[top.*] = index;
        top.* += 1;
    }
}

fn simulate(grid_in: *const [144]u8, until_sync: bool) Result {
    var grid = grid_in.*;
    var flashed: [144]bool = [_]bool{true} ** 144;
    var stack: [100]usize = undefined;

    var total: usize = 0;
    var steps: usize = 0;

    while (true) {
        var flashes: usize = 0;
        var top: usize = 0;

        var y: usize = 0;
        while (y < 10) : (y += 1) {
            var x: usize = 0;
            while (x < 10) : (x += 1) {
                const index = 12 * (y + 1) + (x + 1);
                flashed[index] = false;
                bump(&grid, &flashed, &stack, &top, index);
            }
        }

        while (top > 0) {
            top -= 1;
            const index = stack[top];
            flashes += 1;
            const n1 = index + 1;
            const n2 = index + 11;
            const n3 = index + 12;
            const n4 = index + 13;
            const n5 = index - 1;
            const n6 = index - 11;
            const n7 = index - 12;
            const n8 = index - 13;
            if (!flashed[n1]) bump(&grid, &flashed, &stack, &top, n1);
            if (!flashed[n2]) bump(&grid, &flashed, &stack, &top, n2);
            if (!flashed[n3]) bump(&grid, &flashed, &stack, &top, n3);
            if (!flashed[n4]) bump(&grid, &flashed, &stack, &top, n4);
            if (!flashed[n5]) bump(&grid, &flashed, &stack, &top, n5);
            if (!flashed[n6]) bump(&grid, &flashed, &stack, &top, n6);
            if (!flashed[n7]) bump(&grid, &flashed, &stack, &top, n7);
            if (!flashed[n8]) bump(&grid, &flashed, &stack, &top, n8);
        }

        steps += 1;
        total += flashes;
        if (!until_sync and steps == 100) break;
        if (until_sync and flashes == 100) break;
    }

    return .{ .p1 = total, .p2 = steps };
}

fn solve(input: []const u8) Result {
    var grid: [144]u8 = [_]u8{0} ** 144;
    var row: usize = 0;
    var col: usize = 0;
    for (input) |c| {
        if (c >= '0' and c <= '9') {
            grid[12 * (row + 1) + (col + 1)] = c - '0';
            col += 1;
            if (col == 10) {
                col = 0;
                row += 1;
            }
        }
    }

    const part1 = simulate(&grid, false);
    const part2 = simulate(&grid, true);
    return .{ .p1 = part1.p1, .p2 = part2.p2 };
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
