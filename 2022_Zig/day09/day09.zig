const std = @import("std");

const Point = struct {
    x: i32,
    y: i32,

    fn add(self: Point, other: Point) Point {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    fn scale(self: Point, value: i32) Point {
        return .{ .x = self.x * value, .y = self.y * value };
    }
};

const Move = struct {
    step: Point,
    amount: i32,
};

const Bounds = struct {
    x1: i32,
    y1: i32,
    x2: i32,
    y2: i32,
};

const Result = struct {
    p1: u32,
    p2: u32,
};

fn signum(value: i32) i32 {
    return if (value > 0) 1 else if (value < 0) -1 else 0;
}

fn apart(a: Point, b: Point) bool {
    return @abs(a.x - b.x) > 1 or @abs(a.y - b.y) > 1;
}

fn countLines(input: []const u8) usize {
    var count: usize = 0;
    var line_start: usize = 0;
    var i: usize = 0;
    while (i < input.len) {
        const b = input[i];
        var newline_len: usize = 0;
        if (b == '\r') {
            newline_len = if (i + 1 < input.len and input[i + 1] == '\n') 2 else 1;
        } else if (b == '\n') {
            newline_len = 1;
        }
        if (newline_len > 0) {
            if (i > line_start) count += 1;
            line_start = i + newline_len;
            i += newline_len;
            continue;
        }
        i += 1;
    }
    if (line_start < input.len) count += 1;
    return count;
}

fn parse(input: []const u8, allocator: std.mem.Allocator) !struct { bounds: Bounds, moves: []Move } {
    const move_count = countLines(input);
    var moves = try allocator.alloc(Move, move_count);
    var move_index: usize = 0;

    var x1: i32 = std.math.maxInt(i32);
    var y1: i32 = std.math.maxInt(i32);
    var x2: i32 = std.math.minInt(i32);
    var y2: i32 = std.math.minInt(i32);
    var current = Point{ .x = 0, .y = 0 };

    var i: usize = 0;
    while (i < input.len) {
        const dir = input[i];
        i += 1;
        while (i < input.len and (input[i] == ' ' or input[i] == '\n' or input[i] == '\r')) : (i += 1) {}
        var amount: i32 = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
            amount = amount * 10 + @as(i32, input[i] - '0');
        }
        while (i < input.len and (input[i] == '\n' or input[i] == '\r')) : (i += 1) {}

        const step = switch (dir) {
            'U' => Point{ .x = 0, .y = -1 },
            'D' => Point{ .x = 0, .y = 1 },
            'L' => Point{ .x = -1, .y = 0 },
            else => Point{ .x = 1, .y = 0 },
        };
        moves[move_index] = .{ .step = step, .amount = amount };
        move_index += 1;

        const next = current.add(step.scale(amount));
        x1 = @min(x1, next.x);
        y1 = @min(y1, next.y);
        x2 = @max(x2, next.x);
        y2 = @max(y2, next.y);
        current = next;
    }

    return .{ .bounds = .{ .x1 = x1, .y1 = y1, .x2 = x2, .y2 = y2 }, .moves = moves[0..move_index] };
}

fn simulate(comptime N: usize, bounds: Bounds, moves: []const Move, allocator: std.mem.Allocator) u32 {
    const width: i32 = bounds.x2 - bounds.x1 + 1;
    const height: i32 = bounds.y2 - bounds.y1 + 1;
    const start = Point{ .x = -bounds.x1, .y = -bounds.y1 };

    var rope: [N]Point = undefined;
    for (&rope) |*knot| knot.* = start;

    var grid = allocator.alloc(u8, @intCast(width * height)) catch unreachable;
    defer allocator.free(grid);
    @memset(grid, 0);

    var distinct: u32 = 0;
    for (moves) |mv| {
        var step_count: i32 = 0;
        while (step_count < mv.amount) : (step_count += 1) {
            rope[0] = rope[0].add(mv.step);
            var i: usize = 1;
            while (i < N) : (i += 1) {
                if (!apart(rope[i - 1], rope[i])) break;
                const dx = signum(rope[i - 1].x - rope[i].x);
                const dy = signum(rope[i - 1].y - rope[i].y);
                rope[i] = rope[i].add(.{ .x = dx, .y = dy });
            }

            const tail = rope[N - 1];
            const index: usize = @intCast(width * tail.y + tail.x);
            if (grid[index] == 0) {
                grid[index] = 1;
                distinct += 1;
            }
        }
    }

    return distinct;
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const parsed = parse(input, allocator) catch unreachable;
    defer allocator.free(parsed.moves);

    return .{ .p1 = simulate(2, parsed.bounds, parsed.moves, allocator), .p2 = simulate(10, parsed.bounds, parsed.moves, allocator) };
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
