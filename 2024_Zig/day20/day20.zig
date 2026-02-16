const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u32,
};

const Pos = struct { x: i32, y: i32 };
const Dir = Pos;
const ORTHO = [_]Dir{
    .{ .x = 1, .y = 0 },
    .{ .x = -1, .y = 0 },
    .{ .x = 0, .y = 1 },
    .{ .x = 0, .y = -1 },
};

fn add(a: Pos, b: Pos) Pos {
    return .{ .x = a.x + b.x, .y = a.y + b.y };
}

fn manhattan(a: Pos, b: Pos) i32 {
    const dx = if (a.x > b.x) a.x - b.x else b.x - a.x;
    const dy = if (a.y > b.y) a.y - b.y else b.y - a.y;
    return dx + dy;
}

fn inBounds(width: usize, height: usize, pos: Pos) bool {
    return pos.x >= 0 and pos.y >= 0 and pos.x < @as(i32, @intCast(width)) and pos.y < @as(i32, @intCast(height));
}

fn idx(width: usize, pos: Pos) usize {
    return @as(usize, @intCast(pos.y)) * width + @as(usize, @intCast(pos.x));
}

fn check(time: []const i32, width: usize, height: usize, first: Pos, delta: Pos) u32 {
    const second = add(first, delta);
    if (!inBounds(width, height, second)) return 0;
    const t1 = time[idx(width, first)];
    const t2 = time[idx(width, second)];
    if (t2 == std.math.maxInt(i32)) return 0;
    const diff = @as(i32, @intCast(@abs(t1 - t2))) - manhattan(first, second);
    return @intFromBool(diff >= 100);
}

fn parse(input: []const u8, allocator: std.mem.Allocator) !struct { time: []i32, width: usize, height: usize } {
    const line_end = std.mem.indexOfScalar(u8, input, '\n') orelse input.len;
    var width = line_end;
    var stride = line_end + 1;
    if (line_end > 0 and input[line_end - 1] == '\r') {
        width = line_end - 1;
        stride = line_end + 1;
    }
    const height = if (stride > 0) input.len / stride else 0;

    var start = Pos{ .x = 0, .y = 0 };
    var end = Pos{ .x = 0, .y = 0 };
    var y: usize = 0;
    while (y < height) : (y += 1) {
        var x: usize = 0;
        while (x < width) : (x += 1) {
            const pos = Pos{ .x = @intCast(x), .y = @intCast(y) };
            const c = input[y * stride + x];
            if (c == 'S') start = pos;
            if (c == 'E') end = pos;
        }
    }

    var time = try allocator.alloc(i32, width * height);
    @memset(time, std.math.maxInt(i32));

    var elapsed: i32 = 0;
    var position = start;
    var direction = ORTHO[0];
    for (ORTHO) |dir| {
        const next = add(position, dir);
        if (input[idx(stride, next)] != '#') {
            direction = dir;
            break;
        }
    }

    while (!(position.x == end.x and position.y == end.y)) {
        time[idx(width, position)] = elapsed;
        elapsed += 1;
        const options = [_]Dir{ direction, .{ .x = -direction.y, .y = direction.x }, .{ .x = direction.y, .y = -direction.x } };
        for (options) |dir| {
            const next = add(position, dir);
            if (input[idx(stride, next)] != '#') {
                direction = dir;
                position = next;
                break;
            }
        }
    }
    time[idx(width, end)] = elapsed;

    return .{ .time = time, .width = width, .height = height };
}

fn part1(time: []const i32, width: usize, height: usize) u32 {
    var cheats: u32 = 0;
    var y: usize = 1;
    while (y + 1 < height) : (y += 1) {
        var x: usize = 1;
        while (x + 1 < width) : (x += 1) {
            const point = Pos{ .x = @intCast(x), .y = @intCast(y) };
            if (time[idx(width, point)] != std.math.maxInt(i32)) {
                cheats += check(time, width, height, point, .{ .x = 2, .y = 0 });
                cheats += check(time, width, height, point, .{ .x = 0, .y = 2 });
            }
        }
    }
    return cheats;
}

fn part2(time: []const i32, width: usize, height: usize) u32 {
    var cheats: u32 = 0;
    const max_time = std.math.maxInt(i32);
    var y: usize = 1;
    while (y + 1 < height) : (y += 1) {
        var x: usize = 1;
        while (x + 1 < width) : (x += 1) {
            const point = Pos{ .x = @intCast(x), .y = @intCast(y) };
            if (time[idx(width, point)] == max_time) continue;
            var x_off: i32 = 2;
            while (x_off < 21) : (x_off += 1) {
                cheats += check(time, width, height, point, .{ .x = x_off, .y = 0 });
            }
            var y_off: i32 = 1;
            while (y_off < 21) : (y_off += 1) {
                x_off = y_off - 20;
                while (x_off < 21 - y_off) : (x_off += 1) {
                    cheats += check(time, width, height, point, .{ .x = x_off, .y = y_off });
                }
            }
        }
    }
    return cheats;
}

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    const parsed = try parse(input, allocator);
    defer allocator.free(parsed.time);

    const p1 = part1(parsed.time, parsed.width, parsed.height);
    const p2 = part2(parsed.time, parsed.width, parsed.height);
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
