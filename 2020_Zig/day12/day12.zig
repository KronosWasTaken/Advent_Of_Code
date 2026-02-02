const std = @import("std");

const Result = struct {
    p1: i32,
    p2: i32,
};

const Point = struct {
    x: i32,
    y: i32,

    fn left(self: Point) Point {
        return .{ .x = -self.y, .y = self.x };
    }

    fn right(self: Point) Point {
        return .{ .x = self.y, .y = -self.x };
    }

    fn back(self: Point) Point {
        return .{ .x = -self.x, .y = -self.y };
    }
};

fn rotateLeft(point: Point, degrees: i32) Point {
    return switch (degrees) {
        90 => point.left(),
        180 => point.back(),
        270 => point.right(),
        else => point,
    };
}

fn solve(input: []const u8) Result {
    var p1 = Point{ .x = 0, .y = 0 };
    var d1 = Point{ .x = 1, .y = 0 };
    var p2 = Point{ .x = 0, .y = 0 };
    var w2 = Point{ .x = 10, .y = 1 };

    var i: usize = 0;
    while (i < input.len) {
        const cmd = input[i];
        i += 1;
        var value: i32 = 0;
        while (i < input.len and input[i] >= '0') : (i += 1) {
            value = value * 10 + @as(i32, input[i] - '0');
        }
        if (i < input.len and input[i] == '\r') i += 1;
        if (i < input.len and input[i] == '\n') i += 1;

        switch (cmd) {
            'N' => {
                p1.y += value;
                w2.y += value;
            },
            'S' => {
                p1.y -= value;
                w2.y -= value;
            },
            'E' => {
                p1.x += value;
                w2.x += value;
            },
            'W' => {
                p1.x -= value;
                w2.x -= value;
            },
            'F' => {
                p1.x += d1.x * value;
                p1.y += d1.y * value;
                p2.x += w2.x * value;
                p2.y += w2.y * value;
            },
            'R' => {
                d1 = rotateLeft(d1, 360 - value);
                w2 = rotateLeft(w2, 360 - value);
            },
            'L' => {
                d1 = rotateLeft(d1, value);
                w2 = rotateLeft(w2, value);
            },
            else => {},
        }
    }

    const part1: i32 = @intCast(@abs(p1.x) + @abs(p1.y));
    const part2: i32 = @intCast(@abs(p2.x) + @abs(p2.y));

    return .{ .p1 = part1, .p2 = part2 };
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
