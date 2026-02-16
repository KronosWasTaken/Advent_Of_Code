const std = @import("std");

const Result = struct { p1: usize, p2: usize };

const Box = struct { x: usize, y: usize, z: usize };
const Pair = struct { i: u16, j: u16, dist: u32 };

const BUCKETS: usize = 4;
const SIZE: usize = 10_000 * 10_000;

const Node = struct { parent: usize, size: usize };

const Input = struct {
    boxes: []Box,
    buckets: []std.ArrayListUnmanaged(Pair),
};

const WorkerBuckets = struct {
    buckets: [BUCKETS]std.ArrayListUnmanaged(Pair),

    fn init() WorkerBuckets {
        var result: WorkerBuckets = undefined;
        for (&result.buckets) |*bucket| bucket.* = std.ArrayListUnmanaged(Pair){};
        return result;
    }

    fn deinit(self: *WorkerBuckets, allocator: std.mem.Allocator) void {
        for (&self.buckets) |*bucket| bucket.deinit(allocator);
    }
};

const Task = struct {
    boxes: []const Box,
    start: usize,
    end: usize,
};

pub fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const parsed = parse(allocator, input);
    defer {
        for (parsed.buckets) |*bucket| bucket.deinit(allocator);
        allocator.free(parsed.buckets);
        allocator.free(parsed.boxes);
    }

    return .{ .p1 = part1(&parsed, 1000), .p2 = part2(&parsed) };
}

fn parse(allocator: std.mem.Allocator, input: []const u8) Input {
    var count: usize = 0;
    var i: usize = 0;
    while (i < input.len) {
        while (i < input.len and input[i] < '0') : (i += 1) {}
        if (i >= input.len) break;
        count += 1;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {}
    }

    const box_count = count / 3;
    const boxes = allocator.alloc(Box, box_count) catch unreachable;
    i = 0;
    var idx: usize = 0;
    while (idx < box_count) : (idx += 1) {
        var values = [_]usize{ 0, 0, 0 };
        var v: usize = 0;
        while (v < 3) : (v += 1) {
            while (i < input.len and input[i] < '0') : (i += 1) {}
            var value: usize = 0;
            while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
                value = value * 10 + @as(usize, input[i] - '0');
            }
            values[v] = value;
        }
        boxes[idx] = .{ .x = values[0], .y = values[1], .z = values[2] };
    }

    const cpu_count = @max(@as(usize, std.Thread.getCpuCount() catch 1), 1);
    const worker_count = @min(cpu_count, @max(boxes.len, 1));
    const tasks = allocator.alloc(Task, worker_count) catch unreachable;
    const workers = allocator.alloc(WorkerBuckets, worker_count) catch unreachable;
    const threads = allocator.alloc(std.Thread, worker_count) catch unreachable;

    var t: usize = 0;
    while (t < worker_count) : (t += 1) {
        const start = boxes.len * t / worker_count;
        const end = boxes.len * (t + 1) / worker_count;
        tasks[t] = .{ .boxes = boxes, .start = start, .end = end };
        workers[t] = WorkerBuckets.init();
    }

    t = 0;
    while (t < worker_count) : (t += 1) {
        threads[t] = std.Thread.spawn(.{}, workerMain, .{ &tasks[t], &workers[t] }) catch unreachable;
    }

    t = 0;
    while (t < worker_count) : (t += 1) {
        threads[t].join();
    }

    const buckets = allocator.alloc(std.ArrayListUnmanaged(Pair), BUCKETS) catch unreachable;
    for (buckets) |*bucket| bucket.* = std.ArrayListUnmanaged(Pair){};

    for (workers) |*worker| {
        for (0..BUCKETS) |b| {
            buckets[b].appendSlice(allocator, worker.buckets[b].items) catch unreachable;
        }
        worker.deinit(allocator);
    }

    allocator.free(tasks);
    allocator.free(workers);
    allocator.free(threads);

    for (buckets) |*bucket| {
        std.sort.heap(Pair, bucket.items, {}, struct {
            fn lessThan(_: void, a: Pair, rhs: Pair) bool {
                return a.dist < rhs.dist;
            }
        }.lessThan);
    }

    return .{ .boxes = boxes, .buckets = buckets };
}

fn workerMain(task: *const Task, worker: *WorkerBuckets) void {
    const boxes = task.boxes;
    var left: usize = task.start;
    while (left < task.end) : (left += 1) {
        var right: usize = left + 1;
        while (right < boxes.len) : (right += 1) {
            const dx = absDiff(boxes[left].x, boxes[right].x);
            const dy = absDiff(boxes[left].y, boxes[right].y);
            const dz = absDiff(boxes[left].z, boxes[right].z);
            const distance: u32 = @intCast(dx * dx + dy * dy + dz * dz);
            const index = @as(usize, distance / SIZE);
            if (index < BUCKETS) {
                worker.buckets[index].append(std.heap.page_allocator, .{ .i = @intCast(left), .j = @intCast(right), .dist = distance }) catch unreachable;
            }
        }
    }
}

fn absDiff(a: usize, b: usize) usize {
    return if (a > b) a - b else b - a;
}

fn part1(input: *const Input, limit: usize) usize {
    const boxes = input.boxes;
    const buckets = input.buckets;
    const nodes = initNodes(boxes.len);
    defer std.heap.page_allocator.free(nodes);

    var taken: usize = 0;
    for (buckets) |bucket| {
        for (bucket.items) |pair| {
            _ = unionNodes(nodes, pair.i, pair.j);
            taken += 1;
            if (taken >= limit) break;
        }
        if (taken >= limit) break;
    }

    var top = [_]usize{ 0, 0, 0 };
    var idx: usize = 0;
    while (idx < nodes.len) : (idx += 1) {
        if (nodes[idx].parent != idx) continue;
        const size = nodes[idx].size;
        if (size > top[0]) {
            top[2] = top[1];
            top[1] = top[0];
            top[0] = size;
        } else if (size > top[1]) {
            top[2] = top[1];
            top[1] = size;
        } else if (size > top[2]) {
            top[2] = size;
        }
    }

    return top[0] * top[1] * top[2];
}

fn part2(input: *const Input) usize {
    const boxes = input.boxes;
    const buckets = input.buckets;
    const nodes = initNodes(boxes.len);
    defer std.heap.page_allocator.free(nodes);

    for (buckets) |bucket| {
        for (bucket.items) |pair| {
            if (unionNodes(nodes, pair.i, pair.j) == boxes.len) {
                return boxes[pair.i].x * boxes[pair.j].x;
            }
        }
    }

    unreachable;
}

fn initNodes(count: usize) []Node {
    const nodes = std.heap.page_allocator.alloc(Node, count) catch unreachable;
    var i: usize = 0;
    while (i < count) : (i += 1) {
        nodes[i] = .{ .parent = i, .size = 1 };
    }
    return nodes;
}

fn find(nodes: []Node, x: usize) usize {
    var current = x;
    while (nodes[current].parent != current) {
        const parent = nodes[current].parent;
        nodes[current].parent = nodes[parent].parent;
        current = parent;
    }
    return current;
}

fn unionNodes(nodes: []Node, a: usize, b: usize) usize {
    var x = find(nodes, a);
    var y = find(nodes, b);
    if (x != y) {
        if (nodes[x].size < nodes[y].size) {
            const tmp = x;
            x = y;
            y = tmp;
        }
        nodes[y].parent = x;
        nodes[x].size += nodes[y].size;
    }
    return nodes[x].size;
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
