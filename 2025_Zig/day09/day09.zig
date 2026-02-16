const std = @import("std");

const Result = struct { p1: u64, p2: u64 };

const Tile = struct { x: u64, y: u64 };

const Interval = struct {
    l: u64,
    r: u64,

    fn intersects(self: Interval, other: Interval) bool {
        return other.l <= self.r and self.l <= other.r;
    }

    fn intersection(self: Interval, other: Interval) Interval {
        return .{ .l = @max(self.l, other.l), .r = @min(self.r, other.r) };
    }

    fn contains(self: Interval, x: u64) bool {
        return self.l <= x and x <= self.r;
    }
};

const Candidate = struct {
    x: u64,
    y: u64,
    interval: Interval,
};

pub fn solve(input: []const u8) Result {
    const tiles = parseTiles(input);
    defer std.heap.page_allocator.free(tiles);

    const p1 = part1(tiles);
    const p2 = part2(tiles);
    return .{ .p1 = p1, .p2 = p2 };
}

fn parseTiles(input: []const u8) []Tile {
    const allocator = std.heap.page_allocator;
    var list = std.ArrayListUnmanaged(Tile){};
    var i: usize = 0;
    while (i < input.len) {
        while (i < input.len and input[i] < '0') : (i += 1) {}
        if (i >= input.len) break;
        const x = parseNumber(input, &i);
        while (i < input.len and input[i] < '0') : (i += 1) {}
        const y = parseNumber(input, &i);
        list.append(allocator, .{ .x = x, .y = y }) catch unreachable;
    }
    return list.toOwnedSlice(allocator) catch unreachable;
}

fn parseNumber(input: []const u8, index: *usize) u64 {
    var value: u64 = 0;
    while (index.* < input.len and input[index.*] >= '0' and input[index.*] <= '9') : (index.* += 1) {
        value = value * 10 + @as(u64, input[index.*] - '0');
    }
    return value;
}

fn part1(tiles: []const Tile) u64 {
    var area: u64 = 0;
    var i: usize = 0;
    while (i < tiles.len) : (i += 1) {
        var j: usize = i + 1;
        while (j < tiles.len) : (j += 1) {
            const dx = diff(tiles[i].x, tiles[j].x) + 1;
            const dy = diff(tiles[i].y, tiles[j].y) + 1;
            const candidate = dx * dy;
            if (candidate > area) area = candidate;
        }
    }
    return area;
}

fn diff(a: u64, b: u64) u64 {
    return if (a > b) a - b else b - a;
}

fn part2(tiles_input: []const Tile) u64 {
    const allocator = std.heap.page_allocator;
    var tiles = std.ArrayListUnmanaged(Tile){};
    defer tiles.deinit(allocator);
    tiles.appendSlice(allocator, tiles_input) catch unreachable;

    std.sort.heap(Tile, tiles.items, {}, struct {
        fn lessThan(_: void, a: Tile, b: Tile) bool {
            return if (a.y == b.y) a.x < b.x else a.y < b.y;
        }
    }.lessThan);

    var largest_area: u64 = 0;
    var candidates = std.ArrayListUnmanaged(Candidate){};
    defer candidates.deinit(allocator);
    var descending_edges = std.ArrayListUnmanaged(u64){};
    defer descending_edges.deinit(allocator);
    var intervals = std.ArrayListUnmanaged(Interval){};
    defer intervals.deinit(allocator);

    var idx: usize = 0;
    while (idx + 1 < tiles.items.len) : (idx += 2) {
        const t0 = tiles.items[idx];
        const t1 = tiles.items[idx + 1];
        const y = t0.y;

        toggleEdge(&descending_edges, t0.x);
        toggleEdge(&descending_edges, t1.x);
        updateIntervals(descending_edges.items, &intervals);

        for (candidates.items) |candidate| {
            const widths = [_]u64{ t0.x, t1.x };
            for (widths) |x| {
                if (candidate.interval.contains(x)) {
                    const area = (diff(candidate.x, x) + 1) * (diff(candidate.y, y) + 1);
                    if (area > largest_area) largest_area = area;
                }
            }
        }

        var write: usize = 0;
        for (candidates.items) |candidate| {
            const maybe = findInterval(intervals.items, candidate.x);
            if (maybe) |inter| {
                candidates.items[write] = .{ .x = candidate.x, .y = candidate.y, .interval = inter.intersection(candidate.interval) };
                write += 1;
            }
        }
        candidates.items.len = write;

        const corners = [_]u64{ t0.x, t1.x };
        for (corners) |x| {
            if (findInterval(intervals.items, x)) |inter| {
                candidates.append(allocator, .{ .x = x, .y = y, .interval = inter }) catch unreachable;
            }
        }
    }

    return largest_area;
}

fn toggleEdge(list: *std.ArrayListUnmanaged(u64), value: u64) void {
    var i: usize = 0;
    while (i < list.items.len and list.items[i] < value) : (i += 1) {}
    if (i == list.items.len or list.items[i] != value) {
        list.insert(std.heap.page_allocator, i, value) catch unreachable;
    } else {
        _ = list.orderedRemove(i);
    }
}

fn updateIntervals(edges: []const u64, intervals: *std.ArrayListUnmanaged(Interval)) void {
    intervals.clearRetainingCapacity();
    var i: usize = 0;
    while (i + 1 < edges.len) : (i += 2) {
        intervals.append(std.heap.page_allocator, .{ .l = edges[i], .r = edges[i + 1] }) catch unreachable;
    }
}

fn findInterval(intervals: []const Interval, x: u64) ?Interval {
    for (intervals) |interval| {
        if (interval.contains(x)) return interval;
    }
    return null;
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
