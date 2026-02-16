const std = @import("std");

const Result = struct {
    p1: i64,
    p2: usize,
};

const Robot = struct {
    x: usize,
    y: usize,
    dx: usize,
    dy: usize,
};

fn nextInt(input: []const u8, index: *usize) ?i64 {
    var i = index.*;
    while (i < input.len and !((input[i] >= '0' and input[i] <= '9') or input[i] == '-')) : (i += 1) {}
    if (i >= input.len) {
        index.* = i;
        return null;
    }
    var sign: i64 = 1;
    if (input[i] == '-') {
        sign = -1;
        i += 1;
    }
    var value: i64 = 0;
    while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
        value = value * 10 + @as(i64, input[i] - '0');
    }
    index.* = i;
    return value * sign;
}

fn part1(robots: []const Robot) i64 {
    var quadrants = [_]i64{ 0, 0, 0, 0 };
    for (robots) |robot| {
        const x = (robot.x + 100 * robot.dx) % 101;
        const y = (robot.y + 100 * robot.dy) % 103;
        if (x < 50 and y < 51) {
            quadrants[0] += 1;
        } else if (x < 50 and y > 51) {
            quadrants[1] += 1;
        } else if (x > 50 and y < 51) {
            quadrants[2] += 1;
        } else if (x > 50 and y > 51) {
            quadrants[3] += 1;
        }
    }
    return quadrants[0] * quadrants[1] * quadrants[2] * quadrants[3];
}

fn part2(robots: []const Robot, allocator: std.mem.Allocator) !usize {
    var rows: std.ArrayListUnmanaged(usize) = .{};
    defer rows.deinit(allocator);
    var columns: std.ArrayListUnmanaged(usize) = .{};
    defer columns.deinit(allocator);

    var time: usize = 0;
    while (time < 103) : (time += 1) {
        var xs = [_]u16{0} ** 101;
        var ys = [_]u16{0} ** 103;

        for (robots) |robot| {
            const x = (robot.x + time * robot.dx) % 101;
            xs[x] += 1;
            const y = (robot.y + time * robot.dy) % 103;
            ys[y] += 1;
        }

        if (time < 101) {
            var count: usize = 0;
            for (xs) |v| {
                if (v >= 33) count += 1;
            }
            if (count >= 2) try columns.append(allocator, time);
        }
        var count_y: usize = 0;
        for (ys) |v| {
            if (v >= 31) count_y += 1;
        }
        if (count_y >= 2) try rows.append(allocator, time);
    }

    if (rows.items.len == 1 and columns.items.len == 1) {
        const t = columns.items[0];
        const u = rows.items[0];
        return (5253 * t + 5151 * u) % 10403;
    }

    var floor = try allocator.alloc(i32, 10403);
    defer allocator.free(floor);
    @memset(floor, -1);

    for (columns.items) |t| {
        outer: for (rows.items) |u| {
            const time_idx = (5253 * t + 5151 * u) % 10403;
            const stamp: i32 = @intCast(time_idx);
            for (robots) |robot| {
                const x = (robot.x + time_idx * robot.dx) % 101;
                const y = (robot.y + time_idx * robot.dy) % 103;
                const index = 101 * y + x;
                if (floor[index] == stamp) continue :outer;
                floor[index] = stamp;
            }
            return time_idx;
        }
    }

    return 0;
}

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    var robots: std.ArrayListUnmanaged(Robot) = .{};
    defer robots.deinit(allocator);

    var idx: usize = 0;
    while (true) {
        const x = nextInt(input, &idx) orelse break;
        const y = nextInt(input, &idx) orelse break;
        const dx = nextInt(input, &idx) orelse break;
        const dy = nextInt(input, &idx) orelse break;
        try robots.append(allocator, .{
            .x = @intCast(x),
            .y = @intCast(y),
            .dx = @intCast(@mod(dx, 101)),
            .dy = @intCast(@mod(dy, 103)),
        });
    }

    const p1 = part1(robots.items);
    const p2 = try part2(robots.items, allocator);
    return .{ .p1 = p1, .p2 = p2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input, std.heap.page_allocator);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
