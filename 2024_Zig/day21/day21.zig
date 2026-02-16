const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

const Pos = struct { x: i32, y: i32 };
const Key = struct { ch: u8, pos: Pos };

const ComboKey = struct {
    from: u8,
    to: u8,
};

const CacheKey = struct {
    from: u8,
    to: u8,
    depth: usize,
};

fn padCombinations(allocator: std.mem.Allocator) !std.AutoHashMap(ComboKey, std.ArrayListUnmanaged([]const u8)) {
    var combos = std.AutoHashMap(ComboKey, std.ArrayListUnmanaged([]const u8)).init(allocator);

    const numeric_gap = Pos{ .x = 0, .y = 3 };
    const numeric_keys = [_]Key{
        .{ .ch = '7', .pos = .{ .x = 0, .y = 0 } },
        .{ .ch = '8', .pos = .{ .x = 1, .y = 0 } },
        .{ .ch = '9', .pos = .{ .x = 2, .y = 0 } },
        .{ .ch = '4', .pos = .{ .x = 0, .y = 1 } },
        .{ .ch = '5', .pos = .{ .x = 1, .y = 1 } },
        .{ .ch = '6', .pos = .{ .x = 2, .y = 1 } },
        .{ .ch = '1', .pos = .{ .x = 0, .y = 2 } },
        .{ .ch = '2', .pos = .{ .x = 1, .y = 2 } },
        .{ .ch = '3', .pos = .{ .x = 2, .y = 2 } },
        .{ .ch = '0', .pos = .{ .x = 1, .y = 3 } },
        .{ .ch = 'A', .pos = .{ .x = 2, .y = 3 } },
    };

    const directional_gap = Pos{ .x = 0, .y = 0 };
    const directional_keys = [_]Key{
        .{ .ch = '^', .pos = .{ .x = 1, .y = 0 } },
        .{ .ch = 'A', .pos = .{ .x = 2, .y = 0 } },
        .{ .ch = '<', .pos = .{ .x = 0, .y = 1 } },
        .{ .ch = 'v', .pos = .{ .x = 1, .y = 1 } },
        .{ .ch = '>', .pos = .{ .x = 2, .y = 1 } },
    };

    try padRoutes(allocator, &combos, &numeric_keys, numeric_gap);
    try padRoutes(allocator, &combos, &directional_keys, directional_gap);

    return combos;
}

fn padRoutes(
    allocator: std.mem.Allocator,
    combos: *std.AutoHashMap(ComboKey, std.ArrayListUnmanaged([]const u8)),
    pad: []const Key,
    gap: Pos,
) !void {
    for (pad) |first| {
        for (pad) |second| {
            if (!(first.pos.x == gap.x and second.pos.y == gap.y)) {
                var path = std.ArrayListUnmanaged(u8){};
                defer path.deinit(allocator);
                try appendRepeats(allocator, &path, if (first.pos.y < second.pos.y) 'v' else '^', @intCast(@abs(first.pos.y - second.pos.y)));
                try appendRepeats(allocator, &path, if (first.pos.x < second.pos.x) '>' else '<', @intCast(@abs(first.pos.x - second.pos.x)));
                try path.append(allocator, 'A');
                const owned = try allocator.alloc(u8, path.items.len);
                @memcpy(owned, path.items);
                const entry = try combos.getOrPut(.{ .from = first.ch, .to = second.ch });
                if (!entry.found_existing) entry.value_ptr.* = .{};
                try entry.value_ptr.append(allocator, owned);
            }

            if (first.pos.x != second.pos.x and first.pos.y != second.pos.y and !(second.pos.x == gap.x and first.pos.y == gap.y)) {
                var path = std.ArrayListUnmanaged(u8){};
                defer path.deinit(allocator);
                try appendRepeats(allocator, &path, if (first.pos.x < second.pos.x) '>' else '<', @intCast(@abs(first.pos.x - second.pos.x)));
                try appendRepeats(allocator, &path, if (first.pos.y < second.pos.y) 'v' else '^', @intCast(@abs(first.pos.y - second.pos.y)));
                try path.append(allocator, 'A');
                const owned = try allocator.alloc(u8, path.items.len);
                @memcpy(owned, path.items);
                const entry = try combos.getOrPut(.{ .from = first.ch, .to = second.ch });
                if (!entry.found_existing) entry.value_ptr.* = .{};
                try entry.value_ptr.append(allocator, owned);
            }
        }
    }
}

fn appendRepeats(allocator: std.mem.Allocator, list: *std.ArrayListUnmanaged(u8), ch: u8, count_u32: u32) !void {
    const count = @as(usize, count_u32);
    if (count == 0) return;
    const start = list.items.len;
    try list.resize(allocator, start + count);
    @memset(list.items[start .. start + count], ch);
}

fn dfs(
    allocator: std.mem.Allocator,
    cache: *std.AutoHashMap(CacheKey, usize),
    combos: *std.AutoHashMap(ComboKey, std.ArrayListUnmanaged([]const u8)),
    code: []const u8,
    depth: usize,
) usize {
    if (depth == 0) return code.len;

    var previous: u8 = 'A';
    var result: usize = 0;

    for (code) |current| {
        const key = CacheKey{ .from = previous, .to = current, .depth = depth };
        if (cache.get(key)) |value| {
            result += value;
        } else {
            const entry = combos.get(ComboKey{ .from = previous, .to = current }) orelse unreachable;
            var best: usize = std.math.maxInt(usize);
            for (entry.items) |path| {
                const presses = dfs(allocator, cache, combos, path, depth - 1);
                if (presses < best) best = presses;
            }
            cache.put(key, best) catch unreachable;
            result += best;
        }
        previous = current;
    }

    return result;
}

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    var pairs = std.ArrayListUnmanaged(struct { code: []const u8, value: usize }){};
    defer pairs.deinit(allocator);

    var line_it = std.mem.splitScalar(u8, input, '\n');
    while (line_it.next()) |raw| {
        var line = raw;
        if (line.len > 0 and line[line.len - 1] == '\r') line = line[0 .. line.len - 1];
        if (line.len == 0) continue;

        const value = parseUnsigned(line);
        const code = line;
        try pairs.append(allocator, .{ .code = code, .value = value });
    }

    var combos = try padCombinations(allocator);
    defer {
        var it = combos.valueIterator();
        while (it.next()) |list| {
            for (list.items) |slice| {
                allocator.free(slice);
            }
            list.deinit(allocator);
        }
        combos.deinit();
    }

    var cache = std.AutoHashMap(CacheKey, usize).init(allocator);
    defer cache.deinit();

    var p1: usize = 0;
    var p2: usize = 0;
    for (pairs.items) |pair| {
        const score1 = dfs(allocator, &cache, &combos, pair.code, 3) * pair.value;
        const score2 = dfs(allocator, &cache, &combos, pair.code, 26) * pair.value;
        p1 += score1;
        p2 += score2;
    }

    return .{ .p1 = p1, .p2 = p2 };
}

fn parseUnsigned(line: []const u8) usize {
    var i: usize = 0;
    while (i < line.len and (line[i] < '0' or line[i] > '9')) : (i += 1) {}
    var value: usize = 0;
    while (i < line.len and line[i] >= '0' and line[i] <= '9') : (i += 1) {
        value = value * 10 + @as(usize, line[i] - '0');
    }
    return value;
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
