const std = @import("std");

const Result = struct { p1: u64, p2: u64 };

const Point = struct { x: i32, y: i32 };

const CENTER = Point{ .x = 65, .y = 65 };
const CORNERS = [_]Point{
    .{ .x = 0, .y = 0 },
    .{ .x = 130, .y = 0 },
    .{ .x = 0, .y = 130 },
    .{ .x = 130, .y = 130 },
};

fn parseGrid(alloc: std.mem.Allocator, input: []const u8) !struct { width: i32, height: i32, grid: []u8 } {
    var width: i32 = 0;
    var height: i32 = 0;
    var cur: i32 = 0;
    for (input) |b| {
        if (b == '\r') continue;
        if (b == '\n') {
            if (cur > 0) {
                if (width == 0) width = cur;
                height += 1;
                cur = 0;
            }
        } else {
            cur += 1;
        }
    }
    if (cur > 0) {
        if (width == 0) width = cur;
        height += 1;
    }

    const size = @as(usize, @intCast(width * height));
    var grid = try alloc.alloc(u8, size);
    var idx: usize = 0;
    for (input) |b| {
        if (b == '\r' or b == '\n') continue;
        grid[idx] = b;
        idx += 1;
    }
    return .{ .width = width, .height = height, .grid = grid };
}

fn bfs(alloc: std.mem.Allocator, base: []const u8, width: i32, height: i32, starts: []const Point, limit: u32) [4]u64 {
    const size = @as(usize, @intCast(width * height));
    var grid = alloc.alloc(u8, size) catch return .{ 0, 0, 0, 0 };
    @memcpy(grid, base);

    var queue_pos = alloc.alloc(Point, size) catch return .{ 0, 0, 0, 0 };
    var queue_cost = alloc.alloc(u32, size) catch return .{ 0, 0, 0, 0 };
    var head: usize = 0;
    var tail: usize = 0;

    var even_inner: u64 = 0;
    var even_outer: u64 = 0;
    var odd_inner: u64 = 0;
    var odd_outer: u64 = 0;

    for (starts) |start| {
        const idx = @as(usize, @intCast(start.y * width + start.x));
        grid[idx] = '#';
        queue_pos[tail] = start;
        queue_cost[tail] = 0;
        tail += 1;
    }

    while (head < tail) : (head += 1) {
        const pos = queue_pos[head];
        const cost = queue_cost[head];
        const dist = @as(u32, @intCast(@abs(pos.x - CENTER.x) + @abs(pos.y - CENTER.y)));
        if ((cost & 1) == 1) {
            if (dist <= 65) odd_inner += 1 else odd_outer += 1;
        } else if (cost <= 64) {
            even_inner += 1;
        } else {
            even_outer += 1;
        }

        if (cost < limit) {
            const nx = [_]Point{
                .{ .x = pos.x + 1, .y = pos.y },
                .{ .x = pos.x - 1, .y = pos.y },
                .{ .x = pos.x, .y = pos.y + 1 },
                .{ .x = pos.x, .y = pos.y - 1 },
            };
            for (nx) |next| {
                if (next.x >= 0 and next.y >= 0 and next.x < width and next.y < height) {
                    const idx = @as(usize, @intCast(next.y * width + next.x));
                    if (grid[idx] != '#') {
                        grid[idx] = '#';
                        queue_pos[tail] = next;
                        queue_cost[tail] = cost + 1;
                        tail += 1;
                    }
                }
            }
        }
    }

    return .{ even_inner, even_outer, odd_inner, odd_outer };
}

pub fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const parsed = parseGrid(alloc, input) catch return .{ .p1 = 0, .p2 = 0 };

    const res1 = bfs(alloc, parsed.grid, parsed.width, parsed.height, &[_]Point{CENTER}, 130);
    const part_one = res1[0];
    const even_full = res1[0] + res1[1];
    const odd_full = res1[2] + res1[3];
    const remove_corners = res1[3];

    const res2 = bfs(alloc, parsed.grid, parsed.width, parsed.height, &CORNERS, 64);
    const add_corners = res2[0];

    const n: u64 = 202300;
    const part_two = n * n * even_full + (n + 1) * (n + 1) * odd_full + n * add_corners - (n + 1) * remove_corners;
    return .{ .p1 = part_one, .p2 = part_two };
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
