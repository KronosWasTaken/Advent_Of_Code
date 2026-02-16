const std = @import("std");

const Result = struct {
    p1: u32,
    p2: []const u8,
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

fn inBounds(pos: Pos) bool {
    return pos.x >= 0 and pos.y >= 0 and pos.x < 71 and pos.y < 71;
}

fn idx(pos: Pos) usize {
    return @as(usize, @intCast(pos.y)) * 71 + @as(usize, @intCast(pos.x));
}

fn nextInt(input: []const u8, index: *usize) ?i32 {
    var i = index.*;
    while (i < input.len and (input[i] == ' ' or input[i] == '\n' or input[i] == '\r' or input[i] == ',')) : (i += 1) {}
    if (i >= input.len) {
        index.* = i;
        return null;
    }
    var sign: i32 = 1;
    if (input[i] == '-') {
        sign = -1;
        i += 1;
    }
    var value: i32 = 0;
    while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
        value = value * 10 + @as(i32, input[i] - '0');
    }
    index.* = i;
    return value * sign;
}

fn part1(grid: []i32, allocator: std.mem.Allocator) !u32 {
    var seen = try allocator.alloc(i32, grid.len);
    defer allocator.free(seen);
    @memcpy(seen, grid);
    seen[idx(.{ .x = 0, .y = 0 })] = 0;

    var queue: std.ArrayListUnmanaged(struct { pos: Pos, cost: u32 }) = .{};
    defer queue.deinit(allocator);
    try queue.append(allocator, .{ .pos = .{ .x = 0, .y = 0 }, .cost = 0 });

    var head: usize = 0;
    while (head < queue.items.len) : (head += 1) {
        const state = queue.items[head];
        if (state.pos.x == 70 and state.pos.y == 70) return state.cost;
        for (ORTHO) |dir| {
            const next = add(state.pos, dir);
            if (inBounds(next)) {
                const i = idx(next);
                if (seen[i] > 1024) {
                    seen[i] = 0;
                    try queue.append(allocator, .{ .pos = next, .cost = state.cost + 1 });
                }
            }
        }
    }
    return 0;
}

fn part2(grid: []i32, allocator: std.mem.Allocator) ![]const u8 {
    var time_grid = try allocator.alloc(i32, grid.len);
    defer allocator.free(time_grid);
    @memcpy(time_grid, grid);

    var time: i32 = std.math.maxInt(i32);
    var todo: std.ArrayListUnmanaged(Pos) = .{};
    defer todo.deinit(allocator);
    var head: usize = 0;

    const Entry = struct { t: i32, pos: Pos };
    const Ctx = struct {};
    const compare = struct {
        fn lt(_: Ctx, a: Entry, b: Entry) std.math.Order {
            if (a.t > b.t) return .lt;
            if (a.t < b.t) return .gt;
            return .eq;
        }
    }.lt;
    var heap = std.PriorityQueue(Entry, Ctx, compare).init(allocator, .{});
    defer heap.deinit();

    var visited = try allocator.alloc(bool, grid.len);
    defer allocator.free(visited);
    @memset(visited, false);

    time_grid[idx(.{ .x = 0, .y = 0 })] = 0;
    try todo.append(allocator, .{ .x = 0, .y = 0 });
    visited[idx(.{ .x = 0, .y = 0 })] = true;

    while (true) {
        while (head < todo.items.len) : (head += 1) {
            const position = todo.items[head];
            if (position.x == 70 and position.y == 70) {
                var index: usize = 0;
                while (index < time_grid.len and time_grid[index] != time) : (index += 1) {}
                const x = index % 71;
                const y = index / 71;
                var out = try allocator.alloc(u8, 32);
                const len = try std.fmt.bufPrint(out, "{},{}", .{ x, y });
                return out[0..len.len];
            }
            for (ORTHO) |dir| {
                const next = add(position, dir);
                if (inBounds(next)) {
                    const i = idx(next);
                    if (time < time_grid[i]) {
                        time_grid[i] = 0;
                        if (!visited[i]) {
                            visited[i] = true;
                            try todo.append(allocator, next);
                        }
                    } else {
                        try heap.add(.{ .t = time_grid[i], .pos = next });
                    }
                }
            }
        }

        var entry = heap.remove();
        while (time_grid[idx(entry.pos)] != entry.t) {
            entry = heap.remove();
        }
        time = entry.t;
        const entry_idx = idx(entry.pos);
        if (!visited[entry_idx]) {
            visited[entry_idx] = true;
            try todo.append(allocator, entry.pos);
        }
    }
}

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    var grid = try allocator.alloc(i32, 71 * 71);
    defer allocator.free(grid);
    @memset(grid, std.math.maxInt(i32));

    var idx_in: usize = 0;
    var counter: i32 = 0;
    while (true) {
        const x = nextInt(input, &idx_in) orelse break;
        const y = nextInt(input, &idx_in) orelse break;
        const position = Pos{ .x = x, .y = y };
        grid[idx(position)] = counter;
        counter += 1;
    }

    const p1 = try part1(grid, allocator);
    const p2 = try part2(grid, allocator);
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
    std.debug.print("Part 2: {s}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
