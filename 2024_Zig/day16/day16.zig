const std = @import("std");

const Result = struct {
    p1: i32,
    p2: usize,
};

const Pos = struct { x: i32, y: i32 };

const DIRECTIONS = [_]Pos{
    .{ .x = 1, .y = 0 },
    .{ .x = 0, .y = 1 },
    .{ .x = -1, .y = 0 },
    .{ .x = 0, .y = -1 },
};

const Grid = struct {
    width: usize,
    height: usize,
    stride: usize,
    cells: []const u8,

    fn index(self: Grid, pos: Pos) usize {
        return @as(usize, @intCast(pos.y)) * self.stride + @as(usize, @intCast(pos.x));
    }

    fn get(self: Grid, pos: Pos) u8 {
        return self.cells[self.index(pos)];
    }
};

const State = struct { pos: Pos, dir: usize, cost: i32 };

const Queue = struct {
    items: std.ArrayListUnmanaged(State) = .{},
    head: usize = 0,

    fn deinit(self: *Queue, allocator: std.mem.Allocator) void {
        self.items.deinit(allocator);
    }

    fn push(self: *Queue, allocator: std.mem.Allocator, value: State) !void {
        try self.items.append(allocator, value);
    }

    fn pop(self: *Queue) ?State {
        if (self.head >= self.items.items.len) return null;
        const value = self.items.items[self.head];
        self.head += 1;
        if (self.head >= self.items.items.len) {
            self.items.clearRetainingCapacity();
            self.head = 0;
        }
        return value;
    }

    fn isEmpty(self: Queue) bool {
        return self.items.items.len == self.head;
    }
};

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    const line_end = std.mem.indexOfScalar(u8, input, '\n') orelse input.len;
    var width = line_end;
    var stride = line_end + 1;
    if (line_end > 0 and input[line_end - 1] == '\r') {
        width = line_end - 1;
        stride = line_end + 1;
    }
    const height = if (stride > 0) input.len / stride else 0;
    const grid = Grid{ .width = width, .height = height, .stride = stride, .cells = input };

    var start = Pos{ .x = 0, .y = 0 };
    var end = Pos{ .x = 0, .y = 0 };
    var y: usize = 0;
    while (y < height) : (y += 1) {
        var x: usize = 0;
        while (x < width) : (x += 1) {
            const pos = Pos{ .x = @intCast(x), .y = @intCast(y) };
            const c = grid.get(pos);
            if (c == 'S') start = pos;
            if (c == 'E') end = pos;
        }
    }

    var seen = try allocator.alloc([4]i32, width * height);
    defer allocator.free(seen);
    for (seen) |*row| row.* = .{ std.math.maxInt(i32), std.math.maxInt(i32), std.math.maxInt(i32), std.math.maxInt(i32) };

    var todo_first = Queue{};
    defer todo_first.deinit(allocator);
    var todo_second = Queue{};
    defer todo_second.deinit(allocator);

    try todo_first.push(allocator, .{ .pos = start, .dir = 0, .cost = 0 });
    seen[@as(usize, @intCast(start.y)) * width + @as(usize, @intCast(start.x))][0] = 0;

    var lowest: i32 = std.math.maxInt(i32);

    while (!todo_first.isEmpty()) {
        while (todo_first.pop()) |state| {
            if (state.cost >= lowest) continue;
            if (state.pos.x == end.x and state.pos.y == end.y) {
                lowest = state.cost;
                continue;
            }
            const left = (state.dir + 3) % 4;
            const right = (state.dir + 1) % 4;
            const next_states = [_]State{
                .{ .pos = add(state.pos, DIRECTIONS[state.dir]), .dir = state.dir, .cost = state.cost + 1 },
                .{ .pos = state.pos, .dir = left, .cost = state.cost + 1000 },
                .{ .pos = state.pos, .dir = right, .cost = state.cost + 1000 },
            };
            for (next_states) |next| {
                if (grid.get(next.pos) != '#' and next.cost < seen[@as(usize, @intCast(next.pos.y)) * width + @as(usize, @intCast(next.pos.x))][next.dir]) {
                    if (next.dir == state.dir) {
                        try todo_first.push(allocator, next);
                    } else {
                        try todo_second.push(allocator, next);
                    }
                    seen[@as(usize, @intCast(next.pos.y)) * width + @as(usize, @intCast(next.pos.x))][next.dir] = next.cost;
                }
            }
        }
        std.mem.swap(Queue, &todo_first, &todo_second);
    }

    var todo = Queue{};
    defer todo.deinit(allocator);
    var path = try allocator.alloc(bool, width * height);
    defer allocator.free(path);
    @memset(path, false);

    const end_index = @as(usize, @intCast(end.y)) * width + @as(usize, @intCast(end.x));
    for (seen[end_index], 0..) |cost, dir| {
        if (cost == lowest) {
            try todo.push(allocator, .{ .pos = end, .dir = dir, .cost = lowest });
        }
    }

    while (todo.pop()) |state| {
        const idx = @as(usize, @intCast(state.pos.y)) * width + @as(usize, @intCast(state.pos.x));
        path[idx] = true;
        if (state.pos.x == start.x and state.pos.y == start.y) continue;
        const left = (state.dir + 3) % 4;
        const right = (state.dir + 1) % 4;
        const next_states = [_]State{
            .{ .pos = add(state.pos, .{ .x = -DIRECTIONS[state.dir].x, .y = -DIRECTIONS[state.dir].y }), .dir = state.dir, .cost = state.cost - 1 },
            .{ .pos = state.pos, .dir = left, .cost = state.cost - 1000 },
            .{ .pos = state.pos, .dir = right, .cost = state.cost - 1000 },
        };
        for (next_states) |next| {
            const next_idx = @as(usize, @intCast(next.pos.y)) * width + @as(usize, @intCast(next.pos.x));
            if (next.cost == seen[next_idx][next.dir]) {
                try todo.push(allocator, next);
                seen[next_idx][next.dir] = std.math.maxInt(i32);
            }
        }
    }

    var count: usize = 0;
    for (path) |flag| {
        if (flag) count += 1;
    }
    return .{ .p1 = lowest, .p2 = count };
}

fn add(a: Pos, b: Pos) Pos {
    return .{ .x = a.x + b.x, .y = a.y + b.y };
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
