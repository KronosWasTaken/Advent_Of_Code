const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

const Square = struct {
    size: usize,
    bytes: []u8,
};

fn parse(input: []const u8, allocator: std.mem.Allocator) Square {
    var size: usize = 0;
    while (size < input.len and input[size] != '\n' and input[size] != '\r') : (size += 1) {}

    var bytes = allocator.alloc(u8, size * size) catch unreachable;
    var idx: usize = 0;
    for (input) |c| {
        if (c >= '0' and c <= '9') {
            bytes[idx] = c - '0';
            idx += 1;
        }
    }

    return .{ .size = size, .bytes = bytes };
}

fn dijkstra(square: Square, allocator: std.mem.Allocator) usize {
    const size = square.size;
    const bytes = square.bytes;
    const edge = size - 1;
    const end = size * size - 1;

    var todo: [10]std.ArrayListUnmanaged(u32) = [_]std.ArrayListUnmanaged(u32){.{}} ** 10;
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        todo[i].ensureTotalCapacity(allocator, 1024) catch unreachable;
    }
    defer {
        i = 0;
        while (i < 10) : (i += 1) todo[i].deinit(allocator);
    }

    var cost = allocator.alloc(u16, size * size) catch unreachable;
    defer allocator.free(cost);
    @memset(cost, std.math.maxInt(u16));

    todo[0].append(allocator, 0) catch unreachable;
    cost[0] = 0;

    var risk: usize = 0;
    while (true) {
        const bucket = &todo[risk % 10];
        var j: usize = 0;
        while (j < bucket.items.len) : (j += 1) {
            const current = bucket.items[j];
            if (current == end) return risk;

            const x = current % size;
            const y = current / size;
            const base = @as(u16, @intCast(risk));

            if (x > 0) {
                const next = current - 1;
                const next_cost = base + bytes[next];
                if (next_cost < cost[next]) {
                    todo[next_cost % 10].append(allocator, @as(u32, @intCast(next))) catch unreachable;
                    cost[next] = next_cost;
                }
            }
            if (x < edge) {
                const next = current + 1;
                const next_cost = base + bytes[next];
                if (next_cost < cost[next]) {
                    todo[next_cost % 10].append(allocator, @as(u32, @intCast(next))) catch unreachable;
                    cost[next] = next_cost;
                }
            }
            if (y > 0) {
                const next = current - size;
                const next_cost = base + bytes[next];
                if (next_cost < cost[next]) {
                    todo[next_cost % 10].append(allocator, @as(u32, @intCast(next))) catch unreachable;
                    cost[next] = next_cost;
                }
            }
            if (y < edge) {
                const next = current + size;
                const next_cost = base + bytes[next];
                if (next_cost < cost[next]) {
                    todo[next_cost % 10].append(allocator, @as(u32, @intCast(next))) catch unreachable;
                    cost[next] = next_cost;
                }
            }
        }
        bucket.clearRetainingCapacity();
        risk += 1;
    }
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const square = parse(input, allocator);
    defer allocator.free(square.bytes);

    const p1 = dijkstra(square, allocator);

    const size = square.size;
    var expanded_bytes = allocator.alloc(u8, 25 * size * size) catch unreachable;
    defer allocator.free(expanded_bytes);

    var i: usize = 0;
    while (i < square.bytes.len) : (i += 1) {
        const x1 = i % size;
        const y1 = i / size;
        const base = @as(usize, square.bytes[i]);
        var x2: usize = 0;
        while (x2 < 5) : (x2 += 1) {
            var y2: usize = 0;
            while (y2 < 5) : (y2 += 1) {
                const index = (5 * size) * (y2 * size + y1) + (x2 * size + x1);
                expanded_bytes[index] = @as(u8, @intCast(1 + (base - 1 + x2 + y2) % 9));
            }
        }
    }

    const expanded = Square{ .size = 5 * size, .bytes = expanded_bytes };
    const p2 = dijkstra(expanded, allocator);

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
