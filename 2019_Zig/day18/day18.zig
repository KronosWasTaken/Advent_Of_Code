const std = @import("std");

const Result = struct { p1: u32, p2: u32 };

const State = struct {
    position: u32,
    remaining: u32,
};

const Door = struct {
    distance: u32,
    needed: u32,
};

const Maze = struct {
    initial: State,
    maze: [30][30]Door,
};

fn isKey(b: u8) ?usize {
    if (b >= 'a' and b <= 'z') {
        return b - 'a';
    }
    return null;
}

fn isDoor(b: u8) ?usize {
    if (b >= 'A' and b <= 'Z') {
        return b - 'A';
    }
    return null;
}

fn parseMaze(allocator: std.mem.Allocator, width: usize, bytes: []const u8) !Maze {
    var initial = State{ .position = 0, .remaining = 0 };
    var found = try std.ArrayList(struct { index: usize, id: usize }).initCapacity(allocator, 100);
    defer found.deinit(allocator);

    var robots: usize = 26;


    for (bytes, 0..) |b, i| {
        if (isKey(b)) |key| {
            initial.remaining |= @as(u32, 1) << @intCast(key);
            try found.append(allocator, .{ .index = i, .id = key });
        }
        if (b == '@') {
            initial.position |= @as(u32, 1) << @intCast(robots);
            try found.append(allocator, .{ .index = i, .id = robots });
            robots += 1;
        }
    }

    const default = Door{ .distance = std.math.maxInt(u32), .needed = 0 };
    var maze: [30][30]Door = undefined;
    for (0..30) |i| {
        for (0..30) |j| {
            maze[i][j] = default;
        }
    }

    var visited = try allocator.alloc(usize, bytes.len);
    defer allocator.free(visited);
    @memset(visited, std.math.maxInt(usize));

    var todo = try std.ArrayList(struct { index: usize, distance: u32, needed: u32 }).initCapacity(allocator, 1000);
    defer todo.deinit(allocator);

    for (found.items) |start_item| {
        const start = start_item.index;
        const from = start_item.id;

        todo.clearRetainingCapacity();
        try todo.append(allocator, .{ .index = start, .distance = 0, .needed = 0 });
        visited[start] = from;
        var todo_idx: usize = 0;

        while (todo_idx < todo.items.len) {
            const current = todo.items[todo_idx];
            todo_idx += 1;
            const index = current.index;
            const distance = current.distance;
            var needed = current.needed;

            if (isDoor(bytes[index])) |door| {
                needed |= @as(u32, 1) << @intCast(door);
            }

            if (isKey(bytes[index])) |to| {
                if (distance > 0) {
                    maze[from][to] = Door{ .distance = distance, .needed = needed };
                    maze[to][from] = Door{ .distance = distance, .needed = needed };
                    continue;
                }
            }


            const offsets = [_]i32{ 1, -1, @as(i32, @intCast(width)), -@as(i32, @intCast(width)) };
            for (offsets) |offset| {
                var next_idx: i32 = @intCast(index);
                next_idx += offset;
                if (next_idx >= 0 and next_idx < @as(i32, @intCast(bytes.len))) {
                    const next: usize = @intCast(next_idx);
                    if (bytes[next] != '#' and visited[next] != from) {
                        try todo.append(allocator, .{ .index = next, .distance = distance + 1, .needed = needed });
                        visited[next] = from;
                    }
                }
            }
        }
    }


    for (0..30) |i| {
        maze[i][i].distance = 0;
    }

    for (0..30) |k| {
        for (0..30) |i| {
            for (0..30) |j| {
                const candidate = maze[i][k].distance +| maze[k][j].distance;
                if (maze[i][j].distance > candidate) {
                    maze[i][j].distance = candidate;
                    maze[i][j].needed = maze[i][k].needed | (@as(u32, 1) << @intCast(k)) | maze[k][j].needed;
                }
            }
        }
    }

    return Maze{ .initial = initial, .maze = maze };
}

const QueueEntry = struct { cost: u32, state: State };

const QueueContext = struct {
    pub fn compare(ctx: void, a: QueueEntry, b: QueueEntry) std.math.Order {
        _ = ctx;
        return std.math.order(a.cost, b.cost);
    }
};

fn explore(allocator: std.mem.Allocator, width: usize, bytes: []const u8) !u32 {
    const maze = try parseMaze(allocator, width, bytes);

    var visited = std.AutoHashMap(State, u32).init(allocator);
    defer visited.deinit();

    var todo = std.PriorityQueue(QueueEntry, void, QueueContext.compare).init(allocator, {});
    defer todo.deinit();

    try todo.add(.{ .cost = 0, .state = maze.initial });

    while (todo.removeOrNull()) |current| {
        const total = current.cost;
        const state = current.state;

        if (state.remaining == 0) {
            return total;
        }

        const gop = try visited.getOrPut(state);
        if (gop.found_existing) {
            if (total >= gop.value_ptr.*) {
                continue;
            }
        }
        gop.value_ptr.* = total;


        const pos = state.position;
        var bit: u32 = 0;
        while (bit < 30) : (bit += 1) {
            if ((pos & (@as(u32, 1) << @intCast(bit))) != 0) {
                const from = bit;


                const rem = state.remaining;
                var key_bit: u32 = 0;
                while (key_bit < 26) : (key_bit += 1) {
                    if ((rem & (@as(u32, 1) << @intCast(key_bit))) != 0) {
                        const to = key_bit;
                        const door_info = maze.maze[from][to];

                        if (door_info.distance != std.math.maxInt(u32) and (state.remaining & door_info.needed) == 0) {
                            const next_total = total + door_info.distance;
                            const from_mask = @as(u32, 1) << @intCast(from);
                            const to_mask = @as(u32, 1) << @intCast(to);

                            const next_state = State{
                                .position = state.position ^ from_mask ^ to_mask,
                                .remaining = state.remaining ^ to_mask,
                            };

                            try todo.add(.{ .cost = next_total, .state = next_state });
                        }
                    }
                }
            }
        }
    }

    return 0;
}

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    var lines = std.mem.splitSequence(u8, input, "\n");
    var width: usize = 0;
    var bytes = try std.ArrayList(u8).initCapacity(allocator, 10000);
    defer bytes.deinit(allocator);

    while (lines.next()) |line| {
        var clean_line = line;

        if (clean_line.len > 0 and clean_line[clean_line.len - 1] == '\r') {
            clean_line = clean_line[0 .. clean_line.len - 1];
        }
        if (clean_line.len > 0) {
            if (width == 0) width = clean_line.len;
            try bytes.appendSlice(allocator, clean_line);
        }
    }

    const part1 = try explore(allocator, width, bytes.items);


    var modified = try allocator.dupe(u8, bytes.items);
    defer allocator.free(modified);

    const total_len = bytes.items.len;
    const height = total_len / width;
    const center_row = height / 2;
    const center_col = width / 2;

    const patch_offsets = [_]i32{ -1, 0, 1 };
    const patches = [_][3]u8{
        "@#@".*,
        "###".*,
        "@#@".*,
    };

    for (patch_offsets, patches) |offset, patch| {
        const row_offset = @as(i32, @intCast(center_row)) + offset;
        const row: usize = @intCast(row_offset);
        for (patch, 0..) |ch, col_offset| {
            const col = center_col - 1 + col_offset;
            const idx = row * width + col;
            if (idx < modified.len) {
                modified[idx] = ch;
            }
        }
    }

    const part2 = try explore(allocator, width, modified);

    return Result{ .p1 = part1, .p2 = part2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input, arena.allocator());
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\nPart 2: {}\nTime: {d:.2} microseconds\n", .{ result.p1, result.p2, elapsed_us });
}

