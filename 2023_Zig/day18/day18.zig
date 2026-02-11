const std = @import("std");

const Result = struct {
    p1: i64,
    p2: i64,
};

const Point = struct { x: i64, y: i64 };

fn det(a: Point, b: Point) i64 {
    return a.x * b.y - a.y * b.x;
}

fn parseHex(bytes: []const u8) i64 {
    var value: i64 = 0;
    for (bytes) |b| {
        value <<= 4;
        value += switch (b) {
            '0'...'9' => @as(i64, b - '0'),
            'a'...'f' => @as(i64, b - 'a' + 10),
            'A'...'F' => @as(i64, b - 'A' + 10),
            else => 0,
        };
    }
    return value;
}

pub fn solve(input: []const u8) Result {
    var idx: usize = 0;
    var p1_pos = Point{ .x = 0, .y = 0 };
    var p2_pos = Point{ .x = 0, .y = 0 };
    var area1: i64 = 0;
    var area2: i64 = 0;
    var perim1: i64 = 0;
    var perim2: i64 = 0;

    while (idx < input.len) {
        while (idx < input.len and std.ascii.isWhitespace(input[idx])) : (idx += 1) {}
        if (idx >= input.len) break;

        const dir_char = input[idx];
        idx += 1;
        while (idx < input.len and input[idx] == ' ') : (idx += 1) {}

        var amount: i64 = 0;
        while (idx < input.len and input[idx] >= '0' and input[idx] <= '9') : (idx += 1) {
            amount = amount * 10 + @as(i64, input[idx] - '0');
        }

        while (idx < input.len and std.ascii.isWhitespace(input[idx])) : (idx += 1) {}
        if (idx >= input.len) break;

        const color_start = idx;
        while (idx < input.len and !std.ascii.isWhitespace(input[idx])) : (idx += 1) {}
        const color = input[color_start..idx];

        const dir1 = switch (dir_char) {
            'U' => Point{ .x = 0, .y = -1 },
            'D' => Point{ .x = 0, .y = 1 },
            'L' => Point{ .x = -1, .y = 0 },
            'R' => Point{ .x = 1, .y = 0 },
            else => Point{ .x = 0, .y = 0 },
        };
        const prev1 = p1_pos;
        p1_pos = Point{ .x = p1_pos.x + dir1.x * amount, .y = p1_pos.y + dir1.y * amount };
        area1 += det(prev1, p1_pos);
        perim1 += amount;

        const hex = color[2 .. color.len - 2];
        const amount2 = parseHex(hex);
        const dir2 = switch (color[color.len - 2]) {
            '0' => Point{ .x = 1, .y = 0 },
            '1' => Point{ .x = 0, .y = 1 },
            '2' => Point{ .x = -1, .y = 0 },
            '3' => Point{ .x = 0, .y = -1 },
            else => Point{ .x = 0, .y = 0 },
        };
        const prev2 = p2_pos;
        p2_pos = Point{ .x = p2_pos.x + dir2.x * amount2, .y = p2_pos.y + dir2.y * amount2 };
        area2 += det(prev2, p2_pos);
        perim2 += amount2;
    }

    const p1 = @divTrunc(area1, 2) + @divTrunc(perim1, 2) + 1;
    const p2 = @divTrunc(area2, 2) + @divTrunc(perim2, 2) + 1;
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
