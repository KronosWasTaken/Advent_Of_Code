const std = @import("std");

const Result = struct {
    p1: i32,
    p2: i32,
};

const Point = struct {
    y: i32,
    x: i32,
};

fn gcd(a: i32, b: i32) i32 {
    var x = if (a < 0) -a else a;
    var y = if (b < 0) -b else b;
    while (y != 0) {
        const t = y;
        y = @mod(x, t);
        x = t;
    }
    return x;
}


inline fn getQuad(dy: i32, dx: i32) i32 {
    if (dy < 0 and dx >= 0) return 0;
    if (dy >= 0 and dx > 0) return 1;
    if (dy > 0 and dx <= 0) return 2;
    return 3;
}


inline fn crossProduct(a_dy: i32, a_dx: i32, b_dy: i32, b_dx: i32) i32 {
    return b_dx * a_dy - b_dy * a_dx;
}

fn solve(input: []const u8, _: std.mem.Allocator) !Result {
    var asteroids: [500]Point = undefined;
    var count: usize = 0;

    var y: i32 = 0;
    var x: i32 = 0;
    for (input) |c| {
        if (c == '#') {
            asteroids[count] = Point{ .y = y, .x = x };
            count += 1;
            x += 1;
        } else if (c == '\n') {
            y += 1;
            x = 0;
        } else {
            x += 1;
        }
    }

    var best_count: i32 = 0;
    var best_idx: usize = 0;


    for (asteroids[0..count], 0..) |from, i| {
        var visible: i32 = 0;
        var seen: [10100]u8 = undefined;
        @memset(&seen, 0);

        for (asteroids[0..count], 0..) |to, j| {
            if (i == j) continue;
            var dy = to.y - from.y;
            var dx = to.x - from.x;
            const g = gcd(dy, dx);
            dy = @divTrunc(dy, g);
            dx = @divTrunc(dx, g);

            const dir_idx = @as(usize, @intCast((50 + dy) * 101 + (50 + dx)));
            if (seen[dir_idx] == 0) {
                seen[dir_idx] = 1;
                visible += 1;
            }
        }

        if (visible > best_count) {
            best_count = visible;
            best_idx = i;
        }
    }


    const station = asteroids[best_idx];


    var targets: [500][3]f64 = undefined;
    var target_count: usize = 0;

    for (asteroids[0..count], 0..) |asteroid, i| {
        if (i == best_idx) continue;

        const dy = @as(f64, @floatFromInt(asteroid.y - station.y));
        const dx = @as(f64, @floatFromInt(asteroid.x - station.x));
        const angle = std.math.atan2(-dx, dy);
        const dist_sq = dy * dy + dx * dx;

        targets[target_count] = [_]f64{ angle, dist_sq, @floatFromInt(i) };
        target_count += 1;
    }


    std.sort.block([3]f64, targets[0..target_count], void{}, struct {
        pub fn lessThan(_: void, a: [3]f64, b: [3]f64) bool {
            const angle_diff = a[0] - b[0];
            if (angle_diff * angle_diff > 1e-18) return a[0] < b[0];
            return a[1] < b[1];
        }
    }.lessThan);


    var group_ends: [500]usize = undefined;
    var group_count: usize = 0;
    var i: usize = 0;

    while (i < target_count) {
        var j = i + 1;
        while (j < target_count and @abs(targets[j][0] - targets[i][0]) < 1e-9) {
            j += 1;
        }
        group_ends[group_count] = j;
        group_count += 1;
        i = j;
    }


    var vaporized: i32 = 0;
    var target_idx: usize = 0;
    var layer: usize = 0;

    outer: while (vaporized < 200) {
        for (0..group_count) |g| {
            const start = if (g == 0) @as(usize, 0) else group_ends[g - 1];
            const end = group_ends[g];

            if (layer + start < end) {
                vaporized += 1;
                target_idx = @as(usize, @intFromFloat(targets[layer + start][2]));

                if (vaporized == 200) break :outer;
            }
        }
        layer += 1;
    }

    const target = asteroids[target_idx];
    const part2 = target.x * 100 + target.y;

    return Result{ .p1 = best_count, .p2 = part2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input, allocator);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}

