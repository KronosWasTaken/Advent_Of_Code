const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u32,
};

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

const State = union(enum) {
    Todo,
    OnStack: usize,
    Done: usize,
};

const BitSet = struct {
    bits: [190]u64 = [_]u64{0} ** 190,

    fn insert(self: *BitSet, width: i32, pos: Point) void {
        const index = @as(usize, @intCast(width * pos.y + pos.x));
        const base = index >> 6;
        const offset = index & 63;
        self.bits[base] |= (@as(u64, 1) << @intCast(offset));
    }

    fn merge(self: *BitSet, other: *const BitSet) void {
        var i: usize = 0;
        while (i < self.bits.len) : (i += 1) {
            self.bits[i] |= other.bits[i];
        }
    }

    fn size(self: *const BitSet) u32 {
        var sum: u32 = 0;
        for (self.bits) |b| sum += @popCount(b);
        return sum;
    }
};

const PointSetCtx = struct {
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

const PointSet = std.HashMap(Point, void, PointSetCtx, std.hash_map.default_max_load_percentage);

const Node = struct {
    tiles: BitSet,
    from: PointSet,
    to: PointSet,

    fn init(alloc: std.mem.Allocator) Node {
        return .{ .tiles = .{}, .from = PointSet.init(alloc), .to = PointSet.init(alloc) };
    }

    fn deinit(self: *Node) void {
        self.from.deinit();
        self.to.deinit();
    }
};

const Graph = struct {
    width: i32,
    height: i32,
    grid: []u8,
    seen: [][2]bool,
    state: []State,
    stack: std.ArrayListUnmanaged(usize),
    nodes: std.ArrayListUnmanaged(Node),
    alloc: std.mem.Allocator,

    fn contains(self: *const Graph, pos: Point) bool {
        return pos.x >= 0 and pos.y >= 0 and pos.x < self.width and pos.y < self.height;
    }

    fn index(self: *const Graph, pos: Point) usize {
        return @as(usize, @intCast(pos.y * self.width + pos.x));
    }

    fn cell(self: *const Graph, pos: Point) u8 {
        return self.grid[self.index(pos)];
    }
};

fn parseGrid(alloc: std.mem.Allocator, input: []const u8) !Graph {
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
    const seen = try alloc.alloc([2]bool, size);
    const state = try alloc.alloc(State, size);
    @memset(seen, .{ false, false });
    @memset(state, State.Todo);

    var x: i32 = 0;
    var y: i32 = 0;
    var idx: usize = 0;
    for (input) |b| {
        if (b == '\r') continue;
        if (b == '\n') {
            if (x > 0) {
                y += 1;
                x = 0;
            }
            continue;
        }
        grid[idx] = b;
        idx += 1;
        x += 1;
    }

    return .{
        .width = width,
        .height = height,
        .grid = grid,
        .seen = seen,
        .state = state,
        .stack = .{},
        .nodes = .{},
        .alloc = alloc,
    };
}

fn follow(graph: *Graph, start: Point, dir: Point) u32 {
    var position = start;
    var direction = dir;
    var node = Node.init(graph.alloc);
    defer node.deinit();

    while (graph.contains(position)) {
        const cell = graph.cell(position);
        switch (cell) {
            '|', '-' => {
                const idx = graph.index(position);
                const state = graph.state[idx];
                const node_index = switch (state) {
                    .Todo => strongConnect(graph, position),
                    .Done => |id| id,
                    .OnStack => unreachable,
                };
                node.tiles.merge(&graph.nodes.items[node_index].tiles);
                break;
            },
            '\\' => direction = Point{ .x = direction.y, .y = direction.x },
            '/' => direction = Point{ .x = -direction.y, .y = -direction.x },
            else => {
                const index: usize = if (direction.x != 0) 1 else 0;
                const seen = &graph.seen[graph.index(position)];
                if (seen[index]) return 0;
            },
        }
        node.tiles.insert(graph.width, position);
        position = position.add(direction);
    }

    return node.tiles.size();
}

fn beam(graph: *Graph, node: *Node, start: Point, dir: Point) void {
    var position = start;
    var direction = dir;
    while (graph.contains(position)) {
        const cell = graph.cell(position);
        switch (cell) {
            '|' => {
                if (direction.y != 0) {
                    _ = node.from.put(position, {}) catch {};
                } else {
                    _ = node.to.put(position, {}) catch {};
                    break;
                }
            },
            '-' => {
                if (direction.x != 0) {
                    _ = node.from.put(position, {}) catch {};
                } else {
                    _ = node.to.put(position, {}) catch {};
                    break;
                }
            },
            '\\' => direction = Point{ .x = direction.y, .y = direction.x },
            '/' => direction = Point{ .x = -direction.y, .y = -direction.x },
            else => {
                const index: usize = if (direction.x != 0) 1 else 0;
                const seen = &graph.seen[graph.index(position)];
                if (seen[index]) break;
                seen[index] = true;
            },
        }
        node.tiles.insert(graph.width, position);
        position = position.add(direction);
    }
}

fn strongConnect(graph: *Graph, position: Point) usize {
    const index = graph.nodes.items.len;
    graph.stack.append(graph.alloc, index) catch {};
    graph.nodes.append(graph.alloc, Node.init(graph.alloc)) catch {};

    var node = Node.init(graph.alloc);
    if (graph.cell(position) == '|') {
        beam(graph, &node, position, UP);
        beam(graph, &node, position.add(DOWN), DOWN);
    } else {
        beam(graph, &node, position, LEFT);
        beam(graph, &node, position.add(RIGHT), RIGHT);
    }

    var it_from = node.from.keyIterator();
    while (it_from.next()) |p| {
        graph.state[graph.index(p.*)] = .{ .OnStack = index };
    }

    var lowlink = index;
    var it_to = node.to.keyIterator();
    while (it_to.next()) |p| {
        const pos = p.*;
        switch (graph.state[graph.index(pos)]) {
            .Todo => {
                const child = strongConnect(graph, pos);
                if (child < lowlink) lowlink = child;
            },
            .OnStack => |other| {
                if (other < lowlink) lowlink = other;
            },
            .Done => {},
        }
    }

    if (lowlink == index) {
        while (graph.stack.items.len > 0) {
            const next = graph.stack.pop() orelse break;
            if (next == index) break;
            const other = &graph.nodes.items[next];
            node.tiles.merge(&other.tiles);
            var it_from2 = other.from.keyIterator();
            while (it_from2.next()) |p| _ = node.from.put(p.*, {}) catch {};
            var it_to2 = other.to.keyIterator();
            while (it_to2.next()) |p| _ = node.to.put(p.*, {}) catch {};
        }

        var it_mark = node.from.keyIterator();
        while (it_mark.next()) |p| {
            graph.state[graph.index(p.*)] = .{ .Done = index };
        }

        var it_diff = node.to.keyIterator();
        while (it_diff.next()) |p| {
            if (node.from.contains(p.*)) continue;
            const st = graph.state[graph.index(p.*)];
            switch (st) {
                .Done => |other_index| node.tiles.merge(&graph.nodes.items[other_index].tiles),
                else => {},
            }
        }
    }

    graph.nodes.items[index].deinit();
    graph.nodes.items[index] = node;
    return lowlink;
}

pub fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var graph = parseGrid(arena.allocator(), input) catch return .{ .p1 = 0, .p2 = 0 };

    const part_one = follow(&graph, ORIGIN, RIGHT);
    var part_two = part_one;

    var x: i32 = 0;
    while (x < graph.width) : (x += 1) {
        part_two = @max(part_two, follow(&graph, Point{ .x = x, .y = 0 }, DOWN));
        part_two = @max(part_two, follow(&graph, Point{ .x = x, .y = graph.height - 1 }, UP));
    }

    var y: i32 = 0;
    while (y < graph.height) : (y += 1) {
        part_two = @max(part_two, follow(&graph, Point{ .x = 0, .y = y }, RIGHT));
        part_two = @max(part_two, follow(&graph, Point{ .x = graph.width - 1, .y = y }, LEFT));
    }

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
