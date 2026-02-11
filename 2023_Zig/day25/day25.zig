const std = @import("std");

const Result = struct { p1: usize, p2: []const u8 };

const Input = struct {
    edges: []usize,
    nodes: [][2]usize,
};

fn perfectHash(lookup: []usize, nodes: *std.ArrayListUnmanaged(std.ArrayListUnmanaged(usize)), slice: []const u8) usize {
    var hash: usize = 0;
    var i: usize = 0;
    while (i < 3) : (i += 1) hash = 26 * hash + @as(usize, slice[i] - 'a');
    var index = lookup[hash];
    if (index == std.math.maxInt(usize)) {
        index = nodes.items.len;
        lookup[hash] = index;
        nodes.append(std.heap.page_allocator, std.ArrayListUnmanaged(usize){}) catch {};
    }
    return index;
}

fn parse(input: []const u8, alloc: std.mem.Allocator) Input {
    const lookup = alloc.alloc(usize, 26 * 26 * 26) catch return .{ .edges = &[_]usize{}, .nodes = &[_][2]usize{} };
    @memset(lookup, std.math.maxInt(usize));
    var adj = std.ArrayListUnmanaged(std.ArrayListUnmanaged(usize)){};
    adj.ensureTotalCapacity(alloc, 2000) catch {};

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trimRight(u8, raw_line, "\r");
        if (line.len == 0) continue;
        const first = perfectHash(lookup, &adj, line[0..3]);
        var idx: usize = 5;
        while (idx + 2 < line.len) : (idx += 4) {
            const second = perfectHash(lookup, &adj, line[idx .. idx + 3]);
            adj.items[first].append(alloc, second) catch {};
            adj.items[second].append(alloc, first) catch {};
        }
    }

    var edges = std.ArrayListUnmanaged(usize){};
    var nodes = std.ArrayListUnmanaged([2]usize){};
    for (adj.items) |list| {
        const start = edges.items.len;
        edges.appendSlice(alloc, list.items) catch {};
        const end = edges.items.len;
        nodes.append(alloc, .{ start, end }) catch {};
    }

    return .{ .edges = edges.items, .nodes = nodes.items };
}

fn neighbours(input: Input, node: usize) []const usize {
    const range = input.nodes[node];
    return input.edges[range[0]..range[1]];
}

fn furthest(input: Input, start: usize, alloc: std.mem.Allocator) usize {
    var todo = std.ArrayListUnmanaged(usize){};
    defer todo.deinit(alloc);
    var head: usize = 0;
    todo.append(alloc, start) catch {};
    var seen = alloc.alloc(bool, input.nodes.len) catch return start;
    @memset(seen, false);
    seen[start] = true;

    var result = start;
    while (head < todo.items.len) : (head += 1) {
        const current = todo.items[head];
        result = current;
        for (neighbours(input, current)) |next| {
            if (!seen[next]) {
                seen[next] = true;
                todo.append(alloc, next) catch {};
            }
        }
    }
    return result;
}

fn flow(input: Input, start: usize, end: usize, alloc: std.mem.Allocator) usize {
    var todo = std.ArrayListUnmanaged(struct { node: usize, head: usize }){};
    defer todo.deinit(alloc);
    var path = std.ArrayListUnmanaged(struct { edge: usize, next: usize }){};
    defer path.deinit(alloc);
    var used = alloc.alloc(bool, input.edges.len) catch return 0;
    @memset(used, false);
    var result: usize = 0;

    var iter: usize = 0;
    while (iter < 4) : (iter += 1) {
        todo.clearRetainingCapacity();
        path.clearRetainingCapacity();
        todo.append(alloc, .{ .node = start, .head = std.math.maxInt(usize) }) catch {};
        var seen = alloc.alloc(bool, input.nodes.len) catch return 0;
        @memset(seen, false);
        seen[start] = true;
        result = 0;

        var head: usize = 0;
        while (head < todo.items.len) : (head += 1) {
            const current = todo.items[head];
            result += 1;
            if (current.node == end) {
                var index = current.head;
                while (index != std.math.maxInt(usize)) {
                    const link = path.items[index];
                    used[link.edge] = true;
                    index = link.next;
                }
                break;
            }
            const range = input.nodes[current.node];
            var edge = range[0];
            while (edge < range[1]) : (edge += 1) {
                if (used[edge]) continue;
                const next = input.edges[edge];
                if (!seen[next]) {
                    seen[next] = true;
                    todo.append(alloc, .{ .node = next, .head = path.items.len }) catch {};
                    path.append(alloc, .{ .edge = edge, .next = current.head }) catch {};
                }
            }
        }
    }

    return result;
}

pub fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const parsed = parse(input, alloc);
    const start = furthest(parsed, 0, alloc);
    const end = furthest(parsed, start, alloc);
    const size = flow(parsed, start, end, alloc);
    return .{ .p1 = size * (parsed.nodes.len - size), .p2 = "n/a" };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {s}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
