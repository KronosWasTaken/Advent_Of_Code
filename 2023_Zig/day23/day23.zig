const std = @import("std");

const Result = struct { p1: u32, p2: u32 };

const Point = struct {
    x: i32,
    y: i32,

    fn add(self: Point, other: Point) Point {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }
};

const ORIGIN = Point{ .x = 0, .y = 0 };
const UP = Point{ .x = 0, .y = -1 };
const DOWN = Point{ .x = 0, .y = 1 };
const LEFT = Point{ .x = -1, .y = 0 };
const RIGHT = Point{ .x = 1, .y = 0 };
const ORTHO = [_]Point{ UP, DOWN, LEFT, RIGHT };

const Row = [8]u8;
const Neighbor = struct { row: Row, gap: bool, horizontal: u32, vertical: u32 };
const RowKey = struct { row: Row, gap: bool };

const Graph = struct {
    start: Point,
    end: Point,
    edges: std.HashMap(Point, std.ArrayListUnmanaged(Point), PointCtx, std.hash_map.default_max_load_percentage),
    weight: std.HashMap(EdgeKey, u32, EdgeCtx, std.hash_map.default_max_load_percentage),
};

const Input = struct {
    extra: u32,
    horizontal: [6][6]u32,
    vertical: [6][6]u32,
};

const PointCtx = struct {
    pub fn hash(_: @This(), key: Point) u64 {
        var h: u64 = 0;
        h = std.hash.Wyhash.hash(h, std.mem.asBytes(&key.x));
        h = std.hash.Wyhash.hash(h, std.mem.asBytes(&key.y));
        return h;
    }
    pub fn eql(_: @This(), a: Point, b: Point) bool {
        return a.x == b.x and a.y == b.y;
    }
};

const EdgeKey = struct { a: Point, b: Point };

const EdgeCtx = struct {
    pub fn hash(_: @This(), key: EdgeKey) u64 {
        var h: u64 = 0;
        h = std.hash.Wyhash.hash(h, std.mem.asBytes(&key.a.x));
        h = std.hash.Wyhash.hash(h, std.mem.asBytes(&key.a.y));
        h = std.hash.Wyhash.hash(h, std.mem.asBytes(&key.b.x));
        h = std.hash.Wyhash.hash(h, std.mem.asBytes(&key.b.y));
        return h;
    }
    pub fn eql(_: @This(), a: EdgeKey, b: EdgeKey) bool {
        return a.a.x == b.a.x and a.a.y == b.a.y and a.b.x == b.b.x and a.b.y == b.b.y;
    }
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

fn gridIndex(width: i32, p: Point) usize {
    return @as(usize, @intCast(p.y * width + p.x));
}

fn compress(input: []const u8, alloc: std.mem.Allocator) !Graph {
    var parsed = try parseGrid(alloc, input);
    const width = parsed.width;
    const height = parsed.height;
    const start = Point{ .x = 1, .y = 1 };
    const end = Point{ .x = width - 2, .y = height - 2 };

    parsed.grid[gridIndex(width, start.add(UP))] = '#';
    parsed.grid[gridIndex(width, end.add(DOWN))] = '#';

    var edges = std.HashMap(Point, std.ArrayListUnmanaged(Point), PointCtx, std.hash_map.default_max_load_percentage).init(alloc);
    var weight = std.HashMap(EdgeKey, u32, EdgeCtx, std.hash_map.default_max_load_percentage).init(alloc);
    var poi = std.ArrayListUnmanaged(Point){};
    var seen = std.HashMap(Point, void, PointCtx, std.hash_map.default_max_load_percentage).init(alloc);

    poi.append(alloc, start) catch {};
    parsed.grid[gridIndex(width, end)] = 'P';

    var head: usize = 0;
    while (head < poi.items.len) : (head += 1) {
        const from = poi.items[head];
        parsed.grid[gridIndex(width, from)] = '#';

        for (ORTHO) |direction| {
            const next_pos = from.add(direction);
            if (next_pos.x < 0 or next_pos.y < 0 or next_pos.x >= width or next_pos.y >= height) continue;
            if (parsed.grid[gridIndex(width, next_pos)] == '#') continue;

            var to = next_pos;
            var cost: u32 = 1;
            while (parsed.grid[gridIndex(width, to)] != 'P') {
                var neighbor_count: u8 = 0;
                var next = to;
                for (ORTHO) |o| {
                    const cand = to.add(o);
                    if (cand.x < 0 or cand.y < 0 or cand.x >= width or cand.y >= height) continue;
                    if (parsed.grid[gridIndex(width, cand)] != '#') {
                        neighbor_count += 1;
                        if (neighbor_count == 1) next = cand;
                    }
                }
                if (neighbor_count > 1) {
                    parsed.grid[gridIndex(width, to)] = 'P';
                    break;
                }
                parsed.grid[gridIndex(width, to)] = '#';
                to = next;
                cost += 1;
            }

            const entry_from = edges.getPtr(from) orelse blk: {
                edges.put(from, std.ArrayListUnmanaged(Point){}) catch {};
                break :blk edges.getPtr(from).?;
            };
            entry_from.append(alloc, to) catch {};
            const entry_to = edges.getPtr(to) orelse blk: {
                edges.put(to, std.ArrayListUnmanaged(Point){}) catch {};
                break :blk edges.getPtr(to).?;
            };
            entry_to.append(alloc, from) catch {};
            weight.put(.{ .a = from, .b = to }, cost) catch {};
            weight.put(.{ .a = to, .b = from }, cost) catch {};

            if (!seen.contains(to)) {
                seen.put(to, {}) catch {};
                poi.append(alloc, to) catch {};
            }
        }
    }

    return .{ .start = start, .end = end, .edges = edges, .weight = weight };
}

fn graphToGrid(graph: *Graph, alloc: std.mem.Allocator) Input {
    const start = graph.start;
    const end = graph.end;
    const start_edges = graph.edges.get(start).?.items;
    const end_edges = graph.edges.get(end).?.items;
    const extra = 2 + graph.weight.get(.{ .a = start, .b = start_edges[0] }).? + graph.weight.get(.{ .a = end, .b = end_edges[0] }).?;

    var seen = std.HashMap(Point, void, PointCtx, std.hash_map.default_max_load_percentage).init(alloc);
    var grid: [6][6]Point = undefined;
    var horizontal: [6][6]u32 = [_][6]u32{[_]u32{0} ** 6} ** 6;
    var vertical: [6][6]u32 = [_][6]u32{[_]u32{0} ** 6} ** 6;

    const nextPerimeter = struct {
        fn get(g: *Graph, visited: *std.HashMap(Point, void, PointCtx, std.hash_map.default_max_load_percentage), point: Point) Point {
            const edges = g.edges.get(point).?.items;
            for (edges) |candidate| {
                const deg = g.edges.get(candidate).?.items.len;
                if (deg == 3 and !visited.contains(candidate)) {
                    visited.put(candidate, {}) catch {};
                    return candidate;
                }
            }
            return point;
        }
    }.get;

    grid[0][0] = nextPerimeter(graph, &seen, start);

    var i: usize = 1;
    while (i < 5) : (i += 1) {
        const left = grid[0][i - 1];
        const above = grid[i - 1][0];
        const next_left = nextPerimeter(graph, &seen, left);
        const next_above = nextPerimeter(graph, &seen, above);
        grid[0][i] = next_left;
        grid[i][0] = next_above;
        horizontal[0][i - 1] = graph.weight.get(.{ .a = left, .b = next_left }).?;
        vertical[i - 1][0] = graph.weight.get(.{ .a = above, .b = next_above }).?;
    }

    grid[0][5] = grid[0][4];
    grid[5][0] = grid[4][0];

    var y: usize = 1;
    while (y < 6) : (y += 1) {
        var x: usize = 1;
        while (x < 6) : (x += 1) {
            const left = grid[y][x - 1];
            const above = grid[y - 1][x];
            var it = graph.edges.iterator();
            while (it.next()) |entry| {
                const key = entry.key_ptr.*;
                if (seen.contains(key)) continue;
                const list = entry.value_ptr.*.items;
                var has_left = false;
                var has_above = false;
                for (list) |n| {
                    if (n.x == left.x and n.y == left.y) has_left = true;
                    if (n.x == above.x and n.y == above.y) has_above = true;
                }
                if (has_left and has_above) {
                    seen.put(key, {}) catch {};
                    grid[y][x] = key;
                    horizontal[y][x - 1] = graph.weight.get(.{ .a = left, .b = key }).?;
                    vertical[y - 1][x] = graph.weight.get(.{ .a = above, .b = key }).?;
                    break;
                }
            }
        }
    }

    return .{ .extra = extra, .horizontal = horizontal, .vertical = vertical };
}

fn dfs(result: *std.ArrayListUnmanaged(Neighbor), previous: Row, current: Row, start: usize, gap: bool, horizontal: u32, vertical: u32) void {
    if (start == 6) {
        result.append(std.heap.page_allocator, .{ .row = current, .gap = gap, .horizontal = horizontal, .vertical = vertical }) catch {};
        return;
    }

    if (previous[start] == 0) {
        if (!gap) dfs(result, previous, current, start + 1, true, horizontal, vertical);
        var horiz = horizontal;
        var end = start + 1;
        while (end < 6) : (end += 1) {
            horiz |= (@as(u32, 1) << @intCast(end - 1));
            if (previous[end] == 0) {
                var next = current;
                next[start] = 'S';
                next[end] = 'E';
                const vert = vertical | (@as(u32, 1) << @intCast(start)) | (@as(u32, 1) << @intCast(end));
                dfs(result, previous, next, end + 1, gap, horiz, vert);
            } else {
                var next = current;
                next[start] = previous[end];
                const vert = vertical | (@as(u32, 1) << @intCast(start));
                dfs(result, previous, next, end + 1, gap, horiz, vert);
                break;
            }
        }
    } else {
        var next = current;
        next[start] = previous[start];
        dfs(result, previous, next, start + 1, gap, horizontal, vertical | (@as(u32, 1) << @intCast(start)));

        var horiz = horizontal;
        var end = start + 1;
        while (end < 6) : (end += 1) {
            horiz |= (@as(u32, 1) << @intCast(end - 1));
            if (previous[end] == 0) {
                var next2 = current;
                next2[end] = previous[start];
                const vert = vertical | (@as(u32, 1) << @intCast(end));
                dfs(result, previous, next2, end + 1, gap, horiz, vert);
            } else {
                const left = previous[start];
                const right = previous[end];
                if (left == 'E' and right == 'S') {
                    dfs(result, previous, current, end + 1, gap, horiz, vertical);
                } else if (left == 'E' and right == 'E') {
                    var next2 = current;
                    var i = start;
                    while (i > 0) : (i -= 1) {
                        if (current[i - 1] == 'S') {
                            next2[i - 1] = 'E';
                            break;
                        }
                    }
                    dfs(result, previous, next2, end + 1, gap, horiz, vertical);
                } else if (left == 'S' and right == 'S') {
                    var modified = previous;
                    var level: i32 = 0;
                    var idx2 = end + 1;
                    while (idx2 < 6) : (idx2 += 1) {
                        if (previous[idx2] == 'S') level += 1;
                        if (previous[idx2] == 'E') {
                            if (level == 0) {
                                modified[idx2] = 'S';
                                break;
                            }
                            level -= 1;
                        }
                    }
                    dfs(result, modified, current, end + 1, gap, horiz, vertical);
                }
                break;
            }
        }
    }
}

fn sumBits(bits: u32, row: [6]u32) u32 {
    var sum: u32 = 0;
    var i: usize = 0;
    while (i < 6) : (i += 1) {
        if (((bits >> @intCast(i)) & 1) == 1) sum += row[i];
    }
    return sum;
}

fn part1(input: Input) u32 {
    var total: [6][6]u32 = [_][6]u32{[_]u32{0} ** 6} ** 6;
    var y: usize = 0;
    while (y < 6) : (y += 1) {
        var x: usize = 0;
        while (x < 6) : (x += 1) {
            const left = if (x > 0) total[y][x - 1] + input.horizontal[y][x - 1] else 0;
            const above = if (y > 0) total[y - 1][x] + input.vertical[y - 1][x] else 0;
            total[y][x] = if (left > above) left else above;
        }
    }
    return input.extra + total[5][5];
}

fn part2(input: Input) u32 {
    const start: Row = .{ 'S', 0, 0, 0, 0, 0, 0, 0 };
    const end: Row = .{ 0, 0, 0, 0, 0, 'S', 0, 0 };

    var todo = std.ArrayListUnmanaged(Row){};
    defer todo.deinit(std.heap.page_allocator);
    var seen = std.AutoHashMap(Row, void).init(std.heap.page_allocator);
    defer seen.deinit();
    var graph = std.AutoHashMap(Row, []Neighbor).init(std.heap.page_allocator);
    defer graph.deinit();

    todo.append(std.heap.page_allocator, start) catch {};
    seen.put(start, {}) catch {};

    var head: usize = 0;
    while (head < todo.items.len) : (head += 1) {
        const row = todo.items[head];
        var neighbors = std.ArrayListUnmanaged(Neighbor){};
        defer neighbors.deinit(std.heap.page_allocator);
        dfs(&neighbors, row, .{ 0, 0, 0, 0, 0, 0, 0, 0 }, 0, false, 0, 0);

        for (neighbors.items) |item| {
            if (!seen.contains(item.row)) {
                seen.put(item.row, {}) catch {};
                todo.append(std.heap.page_allocator, item.row) catch {};
            }
        }

        graph.put(row, std.heap.page_allocator.dupe(Neighbor, neighbors.items) catch neighbors.items) catch {};
    }

    var current = std.AutoHashMap(RowKey, u32).init(std.heap.page_allocator);
    var next = std.AutoHashMap(RowKey, u32).init(std.heap.page_allocator);
    defer current.deinit();
    defer next.deinit();
    current.put(.{ .row = start, .gap = false }, 0) catch {};

    var y: usize = 0;
    while (y < 6) : (y += 1) {
        var it = current.iterator();
        while (it.next()) |entry| {
            const key = entry.key_ptr.*;
            const steps = entry.value_ptr.*;
            const neighbors = graph.get(key.row) orelse &[_]Neighbor{};
            for (neighbors) |item| {
                if (key.gap and item.gap) continue;
                const extra = sumBits(item.horizontal, input.horizontal[y]) + sumBits(item.vertical, input.vertical[y]);
                const next_key = RowKey{ .row = item.row, .gap = key.gap or item.gap };
                const prev = next.get(next_key) orelse 0;
                const candidate = steps + extra;
                if (candidate > prev) next.put(next_key, candidate) catch {};
            }
        }
        current.clearRetainingCapacity();
        var it2 = next.iterator();
        while (it2.next()) |entry| {
            current.put(entry.key_ptr.*, entry.value_ptr.*) catch {};
        }
        next.clearRetainingCapacity();
    }

    return input.extra + (current.get(.{ .row = end, .gap = true }) orelse 0);
}

pub fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var graph = compress(input, alloc) catch return .{ .p1 = 0, .p2 = 0 };
    const simplified = graphToGrid(&graph, alloc);
    const p1 = part1(simplified);
    const p2 = part2(simplified);
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
