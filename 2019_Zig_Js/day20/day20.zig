const std = @import("std");

const Result = struct { p1: u32, p2: u32 };

const Kind = enum { Inner, Outer, Start, End };

const Tile = union(enum) {
    Wall,
    Open,
    Portal: struct { key: [2]u8, kind: Kind },
};

const Edge = struct {
    to: usize,
    kind: Kind,
    distance: u32,
};

const Maze = struct {
    start: usize,
    portals: std.ArrayList(std.ArrayList(Edge)),
};

fn parse(input: []const u8, allocator: std.mem.Allocator) !Maze {
    var lines = try std.ArrayList([]const u8).initCapacity(allocator, 200);
    defer lines.deinit(allocator);

    var iter = std.mem.splitScalar(u8, input, '\n');
    while (iter.next()) |line| {
        try lines.append(allocator, line);
    }

    const height = lines.items.len;
    const width = if (height > 0) lines.items[0].len else 0;


    var tiles = try allocator.alloc(Tile, height * width);
    defer allocator.free(tiles);
    for (tiles) |*tile| tile.* = .Wall;


    for (lines.items, 0..) |line, y| {
        for (line, 0..) |c, x| {
            if (c == '.') {
                tiles[y * width + x] = .Open;
            }
        }
    }

    var map = std.AutoHashMap([3]u8, usize).init(allocator);
    defer map.deinit();
    var found = try std.ArrayList(usize).initCapacity(allocator, 50);
    defer found.deinit(allocator);
    var start: usize = std.math.maxInt(usize);


    var y: i32 = 0;
    while (y < height) : (y += 1) {
        var x: i32 = 0;
        while (x < width) : (x += 1) {
            const uy: usize = @intCast(y);
            const ux: usize = @intCast(x);
            if (uy >= lines.items.len or ux >= lines.items[uy].len) continue;
            const c = lines.items[uy][ux];
            if (!std.ascii.isUpper(c)) continue;


            const dirs = [_][2]i32{ .{0, -1}, .{0, 1}, .{-1, 0}, .{1, 0} };
            for (dirs) |d| {
                const ny = y + d[1];
                const nx = x + d[0];
                if (ny < 0 or ny >= height or nx < 0 or nx >= width) continue;
                const nuy: usize = @intCast(ny);
                const nux: usize = @intCast(nx);
                if (nuy >= lines.items.len or nux >= lines.items[nuy].len) continue;
                const nc = lines.items[nuy][nux];
                if (!std.ascii.isUpper(nc)) continue;


                const oy = y - d[1];
                const ox = x - d[0];
                if (oy < 0 or oy >= height or ox < 0 or ox >= width) continue;
                const ouy: usize = @intCast(oy);
                const oux: usize = @intCast(ox);
                if (ouy >= lines.items.len or oux >= lines.items[ouy].len) continue;
                if (lines.items[ouy][oux] != '.') continue;

                const portal_idx = ouy * width + oux;


                const pair: [2]u8 = if (d[1] < 0 or d[0] < 0) .{nc, c} else .{c, nc};


                const inner = x > 2 and x < width - 3 and y > 2 and y < height - 3;

                const kind: Kind = blk: {
                    if (pair[0] == 'A' and pair[1] == 'A') {
                        start = found.items.len;
                        break :blk .Start;
                    } else if (pair[0] == 'Z' and pair[1] == 'Z') {
                        break :blk .End;
                    } else if (inner) {
                        break :blk .Inner;
                    } else {
                        break :blk .Outer;
                    }
                };

                const opposite: Kind = if (kind == .Inner) .Outer else if (kind == .Outer) .Inner else kind;
                const key: [3]u8 = .{pair[0], pair[1], @intFromEnum(opposite)};

                tiles[portal_idx] = .{ .Portal = .{ .key = pair, .kind = kind } };
                try map.put(key, found.items.len);
                try found.append(allocator, portal_idx);
                break;
            }
        }
    }


    var portals = try std.ArrayList(std.ArrayList(Edge)).initCapacity(allocator, 50);
    var todo = try std.ArrayList(struct { idx: usize, steps: u32 }).initCapacity(allocator, 1000);
    defer todo.deinit(allocator);
    var visited = try allocator.alloc(usize, tiles.len);
    defer allocator.free(visited);
    @memset(visited, std.math.maxInt(usize));

    for (found.items) |start_idx| {
        var edges = try std.ArrayList(Edge).initCapacity(allocator, 20);
        todo.clearRetainingCapacity();
        try todo.append(allocator, .{ .idx = start_idx, .steps = 0 });

        var read_idx: usize = 0;
        while (read_idx < todo.items.len) {
            const current = todo.items[read_idx];
            read_idx += 1;
            visited[current.idx] = start_idx;

            const cy = current.idx / width;
            const cx = current.idx % width;
            const neighbors = [_]usize{
                if (cx > 0) current.idx - 1 else current.idx,
                if (cx < width - 1) current.idx + 1 else current.idx,
                if (cy > 0) current.idx - width else current.idx,
                if (cy < height - 1) current.idx + width else current.idx,
            };

            for (neighbors) |next_idx| {
                if (next_idx >= tiles.len or visited[next_idx] == start_idx) continue;

                const next_steps = current.steps + 1;
                switch (tiles[next_idx]) {
                    .Wall => {},
                    .Open => try todo.append(allocator, .{ .idx = next_idx, .steps = next_steps }),
                    .Portal => |portal| {
                        const key: [3]u8 = .{portal.key[0], portal.key[1], @intFromEnum(portal.kind)};
                        if (map.get(key)) |to| {
                            try edges.append(allocator, .{ .to = to, .kind = portal.kind, .distance = next_steps });
                        }
                    },
                }
            }
        }

        try portals.append(allocator, edges);
    }

    return Maze{ .start = start, .portals = portals };
}

fn part1(maze: *const Maze, allocator: std.mem.Allocator) !u32 {
    var todo = try std.ArrayList(struct { steps: u32, idx: usize }).initCapacity(allocator, 1000);
    defer todo.deinit(allocator);
    try todo.append(allocator, .{ .steps = 0, .idx = maze.start });

    var read_idx: usize = 0;
    while (read_idx < todo.items.len) {
        const current = todo.items[read_idx];
        read_idx += 1;

        for (maze.portals.items[current.idx].items) |edge| {
            const next_steps = current.steps + edge.distance + 1;

            switch (edge.kind) {
                .Inner, .Outer => try todo.append(allocator, .{ .steps = next_steps, .idx = edge.to }),
                .End => return next_steps - 1,
                .Start => {},
            }
        }
    }

    return 0;
}

fn part2(maze: *const Maze, allocator: std.mem.Allocator) !u32 {
    var cache = std.AutoHashMap([2]usize, u32).init(allocator);
    defer cache.deinit();

    var todo = try std.ArrayList(struct { steps: u32, idx: usize, level: usize }).initCapacity(allocator, 2000);
    defer todo.deinit(allocator);
    try todo.append(allocator, .{ .steps = 0, .idx = maze.start, .level = 0 });

    var read_idx: usize = 0;
    while (read_idx < todo.items.len) {
        const current = todo.items[read_idx];
        read_idx += 1;

        const key: [2]usize = .{current.idx, current.level};

        if (cache.get(key)) |min_steps| {
            if (min_steps <= current.steps) continue;
        }
        try cache.put(key, current.steps);

        for (maze.portals.items[current.idx].items) |edge| {
            const next_steps = current.steps + edge.distance + 1;

            switch (edge.kind) {
                .Inner => {
                    if (current.level < maze.portals.items.len) {
                        try todo.append(allocator, .{ .steps = next_steps, .idx = edge.to, .level = current.level + 1 });
                    }
                },
                .Outer => {
                    if (current.level > 0) {
                        try todo.append(allocator, .{ .steps = next_steps, .idx = edge.to, .level = current.level - 1 });
                    }
                },
                .End => {
                    if (current.level == 0) {
                        return next_steps - 1;
                    }
                },
                .Start => {},
            }
        }
    }

    return 0;
}

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    var maze = try parse(input, allocator);
    defer {
        for (maze.portals.items) |*edges| {
            edges.deinit(allocator);
        }
        maze.portals.deinit(allocator);
    }

    const p1 = try part1(&maze, allocator);
    const p2 = try part2(&maze, allocator);

    return Result{ .p1 = p1, .p2 = p2 };
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
    std.debug.print("Part 1: {}\nPart 2: {}\nTime: {d:.2} microseconds\n", .{result.p1, result.p2, elapsed_us});
}
