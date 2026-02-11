const std = @import("std");

const SIZE: usize = 24;

const Result = struct {
    p1: u32,
    p2: u32,
};

fn parse(input: []const u8, allocator: std.mem.Allocator) ![]u8 {
    var cube = try allocator.alloc(u8, SIZE * SIZE * SIZE);
    @memset(cube, 0);

    var coords: [3]usize = undefined;
    var coord_idx: usize = 0;
    var num: usize = 0;
    var in_num = false;

    for (input) |b| {
        if (b >= '0' and b <= '9') {
            num = num * 10 + (b - '0');
            in_num = true;
        } else if (in_num) {
            coords[coord_idx] = num;
            coord_idx += 1;
            num = 0;
            in_num = false;
            if (coord_idx == 3) {
                cube[(coords[0] + 1) * SIZE * SIZE + (coords[1] + 1) * SIZE + (coords[2] + 1)] = 1;
                coord_idx = 0;
            }
        }
    }
    if (in_num and coord_idx == 2) {
        coords[coord_idx] = num;
        cube[(coords[0] + 1) * SIZE * SIZE + (coords[1] + 1) * SIZE + (coords[2] + 1)] = 1;
    }

    return cube;
}

fn count(cube: []const u8, adjust: fn (u32) u32) u32 {
    var total: u32 = 0;
    for (cube, 0..) |cell, i| {
        if (cell == 1) {
            const neighbors: u32 = @as(u32, cube[i -| 1]) +
                @as(u32, cube[i + 1]) +
                @as(u32, cube[i -| SIZE]) +
                @as(u32, cube[i + SIZE]) +
                @as(u32, cube[i -| SIZE * SIZE]) +
                @as(u32, cube[i + SIZE * SIZE]);
            total += adjust(neighbors);
        }
    }
    return total;
}

fn part1Adjust(x: u32) u32 {
    return 6 - x;
}

fn part2Adjust(x: u32) u32 {
    return x >> 3;
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const cube = parse(input, allocator) catch unreachable;
    defer allocator.free(cube);

    const p1 = count(cube, part1Adjust);

    var cube2 = allocator.dupe(u8, cube) catch unreachable;
    defer allocator.free(cube2);
    cube2[0] = 8;

    var stack = std.ArrayListUnmanaged(usize){};
    defer stack.deinit(allocator);
    stack.append(allocator, 0) catch unreachable;

    while (stack.items.len > 0) {
        const index = stack.pop().?;
        const neighbors = [_]usize{
            index -| 1,
            index + 1,
            index -| SIZE,
            index + SIZE,
            index -| SIZE * SIZE,
            index + SIZE * SIZE,
        };
        for (neighbors) |next| {
            if (next < cube2.len and cube2[next] == 0) {
                cube2[next] = 8;
                stack.append(allocator, next) catch unreachable;
            }
        }
    }

    const p2 = count(cube2, part2Adjust);
    return .{ .p1 = p1, .p2 = p2 };
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
