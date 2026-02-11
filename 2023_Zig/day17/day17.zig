const std = @import("std");

const Result = struct {
    p1: i32,
    p2: i32,
};

const Node = struct { x: i32, y: i32, dir: u8 };

fn parseGrid(alloc: std.mem.Allocator, input: []const u8) !struct { width: i32, height: i32, heat: []i32 } {
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
    var heat = try alloc.alloc(i32, size);
    var idx: usize = 0;
    for (input) |b| {
        if (b == '\r' or b == '\n') continue;
        heat[idx] = @as(i32, b - '0');
        idx += 1;
    }
    return .{ .width = width, .height = height, .heat = heat };
}

inline fn heuristic(x: i32, y: i32, cost: i32, size: i32, size_half: i32) usize {
    const priority = @min(2 * size - x - y, size + size_half);
    return @intCast(@mod(cost + priority, 100));
}

fn astar(comptime L: i32, comptime U: i32, width: i32, heat: []const i32, cost: [][2]i32, buckets: []std.ArrayListUnmanaged(Node), alloc: std.mem.Allocator) i32 {
    const size = width;
    const size_half = @divTrunc(size, 2);
    const stride = @as(usize, @intCast(size));

    for (cost) |*c| c.* = .{ std.math.maxInt(i32), std.math.maxInt(i32) };
    var i: usize = 0;
    while (i < buckets.len) : (i += 1) buckets[i].clearRetainingCapacity();

    buckets[0].append(alloc, .{ .x = 0, .y = 0, .dir = 0 }) catch {};
    buckets[0].append(alloc, .{ .x = 0, .y = 0, .dir = 1 }) catch {};
    cost[0][0] = 0;
    cost[0][1] = 0;

    var bucket_index: usize = 0;
    while (true) {
        var bucket = &buckets[bucket_index];
        while (bucket.items.len > 0) {
            const node = bucket.pop() orelse break;
            const x = node.x;
            const y = node.y;
            const dir = node.dir;
            const idx = @as(usize, @intCast(size * y + x));
            const steps = cost[idx][dir];

            if (x == size - 1 and y == size - 1) return steps;

            if (dir == 0) {
                var next = idx;
                var extra = steps;
                var i_step: i32 = 1;
                while (i_step <= U) : (i_step += 1) {
                    if (x + i_step >= size) break;
                    next += 1;
                    extra += heat[next];
                    if (i_step >= L and extra < cost[next][1]) {
                        buckets[heuristic(x + i_step, y, extra, size, size_half)].append(alloc, .{ .x = x + i_step, .y = y, .dir = 1 }) catch {};
                        cost[next][1] = extra;
                    }
                }

                next = idx;
                extra = steps;
                i_step = 1;
                while (i_step <= U) : (i_step += 1) {
                    if (i_step > x) break;
                    next -= 1;
                    extra += heat[next];
                    if (i_step >= L and extra < cost[next][1]) {
                        buckets[heuristic(x - i_step, y, extra, size, size_half)].append(alloc, .{ .x = x - i_step, .y = y, .dir = 1 }) catch {};
                        cost[next][1] = extra;
                    }
                }
            } else {
                var next = idx;
                var extra = steps;
                var i_step: i32 = 1;
                while (i_step <= U) : (i_step += 1) {
                    if (y + i_step >= size) break;
                    next += stride;
                    extra += heat[next];
                    if (i_step >= L and extra < cost[next][0]) {
                        buckets[heuristic(x, y + i_step, extra, size, size_half)].append(alloc, .{ .x = x, .y = y + i_step, .dir = 0 }) catch {};
                        cost[next][0] = extra;
                    }
                }

                next = idx;
                extra = steps;
                i_step = 1;
                while (i_step <= U) : (i_step += 1) {
                    if (i_step > y) break;
                    next -= stride;
                    extra += heat[next];
                    if (i_step >= L and extra < cost[next][0]) {
                        buckets[heuristic(x, y - i_step, extra, size, size_half)].append(alloc, .{ .x = x, .y = y - i_step, .dir = 0 }) catch {};
                        cost[next][0] = extra;
                    }
                }
            }
        }
        bucket_index = (bucket_index + 1) % 100;
    }
}

pub fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const parsed = parseGrid(alloc, input) catch return .{ .p1 = 0, .p2 = 0 };

    const cost = alloc.alloc([2]i32, parsed.heat.len) catch return .{ .p1 = 0, .p2 = 0 };
    var buckets: [100]std.ArrayListUnmanaged(Node) = undefined;
    var i: usize = 0;
    while (i < buckets.len) : (i += 1) {
        buckets[i] = .{};
        buckets[i].ensureTotalCapacity(alloc, 1000) catch {};
    }
    defer {
        i = 0;
        while (i < buckets.len) : (i += 1) buckets[i].deinit(alloc);
    }

    const p1 = astar(1, 3, parsed.width, parsed.heat, cost, &buckets, alloc);
    const p2 = astar(4, 10, parsed.width, parsed.heat, cost, &buckets, alloc);
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
