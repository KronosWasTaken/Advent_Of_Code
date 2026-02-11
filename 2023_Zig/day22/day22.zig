const std = @import("std");

const Result = struct { p1: usize, p2: usize };

pub fn solve(input: []const u8) Result {
    var numbers = std.ArrayListUnmanaged([6]usize){};
    defer numbers.deinit(std.heap.page_allocator);
    var it = std.mem.tokenizeAny(u8, input, "\r\n,~");
    var buf: [6]usize = undefined;
    var idx: usize = 0;
    while (it.next()) |tok| {
        var value: usize = 0;
        for (tok) |b| value = value * 10 + (b - '0');
        buf[idx] = value;
        idx += 1;
        if (idx == 6) {
            idx = 0;
            numbers.append(std.heap.page_allocator, buf) catch return .{ .p1 = 0, .p2 = 0 };
        }
    }

    const bricks = numbers.items;
    std.mem.sort([6]usize, bricks, {}, struct {
        fn lessThan(_: void, a: [6]usize, b: [6]usize) bool {
            return a[2] < b[2];
        }
    }.lessThan);

    var heights: [100]usize = [_]usize{0} ** 100;
    var indices: [100]usize = [_]usize{std.math.maxInt(usize)} ** 100;
    const heights_slice = heights[0..];
    const indices_slice = indices[0..];
    var safe = std.ArrayListUnmanaged(bool){};
    safe.resize(std.heap.page_allocator, bricks.len) catch return .{ .p1 = 0, .p2 = 0 };
    @memset(safe.items, true);

    var dominator = std.ArrayListUnmanaged(struct { parent: usize, depth: usize }){};
    dominator.ensureTotalCapacity(std.heap.page_allocator, bricks.len) catch return .{ .p1 = 0, .p2 = 0 };

    var i: usize = 0;
    while (i < bricks.len) : (i += 1) {
        const brick = bricks[i];
        const x1 = brick[0];
        const y1 = brick[1];
        const z1 = brick[2];
        const x2 = brick[3];
        const y2 = brick[4];
        const z2 = brick[5];
        const start = 10 * y1 + x1;
        const end = 10 * y2 + x2;
        const step: usize = if (y2 > y1) 10 else 1;
        const height = z2 - z1 + 1;

        var top: usize = 0;
        var previous: usize = std.math.maxInt(usize);
        var underneath: usize = 0;
        var parent: usize = 0;
        var depth: usize = 0;

        var j: usize = start;
        while (j <= end) : (j += step) {
            const h = heights_slice[j];
            if (h > top) top = h;
        }

        j = start;
        while (j <= end) : (j += step) {
            if (heights_slice[j] == top) {
                const index = indices_slice[j];
                if (index != previous) {
                    previous = index;
                    underneath += 1;
                    if (underneath == 1) {
                        const dom = dominator.items[previous];
                        parent = dom.parent;
                        depth = dom.depth;
                    } else {
                        var a = parent;
                        var b = depth;
                        var x = dominator.items[previous].parent;
                        var y = dominator.items[previous].depth;
                        while (b > y) {
                            const dom = dominator.items[a];
                            a = dom.parent;
                            b = dom.depth;
                        }
                        while (y > b) {
                            const dom = dominator.items[x];
                            x = dom.parent;
                            y = dom.depth;
                        }
                        while (a != x) {
                            const dom_a = dominator.items[a];
                            const dom_x = dominator.items[x];
                            a = dom_a.parent;
                            b = dom_a.depth;
                            x = dom_x.parent;
                        }
                        parent = a;
                        depth = b;
                    }
                }
            }
            heights_slice[j] = top + height;
            indices_slice[j] = i;
        }

        if (underneath == 1) {
            safe.items[previous] = false;
            parent = previous;
            depth = dominator.items[previous].depth + 1;
        }

        dominator.appendAssumeCapacity(.{ .parent = parent, .depth = depth });
    }

    var part_one: usize = 0;
    for (safe.items) |b| {
        if (b) part_one += 1;
    }
    var part_two: usize = 0;
    for (dominator.items) |dom| {
        part_two += dom.depth;
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
