const std = @import("std");

const Result = struct { p1: u64, p2: u64 };

const Graph = [][]usize;

pub fn solve(input: []const u8) Result {
    const graph = parse(input);
    defer {
        for (graph) |row| std.heap.page_allocator.free(row);
        std.heap.page_allocator.free(graph);
    }

    const p1 = paths(graph, "you", "out");
    const one = paths(graph, "svr", "fft") * paths(graph, "fft", "dac") * paths(graph, "dac", "out");
    const two = paths(graph, "svr", "dac") * paths(graph, "dac", "fft") * paths(graph, "fft", "out");
    const p2 = one + two;

    return .{ .p1 = p1, .p2 = p2 };
}

fn parse(input: []const u8) Graph {
    @setRuntimeSafety(false);
    const allocator = std.heap.page_allocator;
    const count: usize = 26 * 26 * 26;
    var graph = allocator.alloc([]usize, count) catch unreachable;
    for (graph) |*row| row.* = &[_]usize{};

    var line_start: usize = 0;
    var i: usize = 0;
    while (i <= input.len) : (i += 1) {
        if (i == input.len or input[i] == '\n') {
            var end = i;
            if (end > line_start and input[end - 1] == '\r') end -= 1;
            if (end > line_start) {
                const line = input[line_start..end];
                var parts = std.mem.splitScalar(u8, line, ' ');
                const from = parts.next().?;
                const from_idx = (26 * (26 * @as(usize, from[0] - 'a') + @as(usize, from[1] - 'a')) + @as(usize, from[2] - 'a'));
                var edges = std.ArrayListUnmanaged(usize){};
                while (parts.next()) |edge| {
                    const edge_idx = (26 * (26 * @as(usize, edge[0] - 'a') + @as(usize, edge[1] - 'a')) + @as(usize, edge[2] - 'a'));
                    edges.append(allocator, edge_idx) catch unreachable;
                }
                graph[from_idx] = edges.toOwnedSlice(allocator) catch unreachable;
            }
            line_start = i + 1;
        }
    }

    return graph;
}

fn paths(graph: Graph, from: []const u8, to: []const u8) u64 {
    @setRuntimeSafety(false);
    const cache = std.heap.page_allocator.alloc(u64, graph.len) catch unreachable;
    defer std.heap.page_allocator.free(cache);
    @memset(cache, std.math.maxInt(u64));
    const start = (26 * (26 * @as(usize, from[0] - 'a') + @as(usize, from[1] - 'a')) + @as(usize, from[2] - 'a'));
    const end = (26 * (26 * @as(usize, to[0] - 'a') + @as(usize, to[1] - 'a')) + @as(usize, to[2] - 'a'));
    return dfs(graph, cache, start, end);
}

fn dfs(graph: Graph, cache: []u64, node: usize, end: usize) u64 {
    @setRuntimeSafety(false);
    if (node == end) return 1;
    if (cache[node] == std.math.maxInt(u64)) {
        var sum: u64 = 0;
        for (graph[node]) |next| {
            sum += dfs(graph, cache, next, end);
        }
        cache[node] = sum;
    }
    return cache[node];
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
