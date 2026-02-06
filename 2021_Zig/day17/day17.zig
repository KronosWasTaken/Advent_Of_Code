const std = @import("std");

const Result = struct {
    p1: i32,
    p2: usize,
};

fn solve(input: []const u8) Result {
    var values: [4]i32 = undefined;
    var idx: usize = 0;
    var value: i32 = 0;
    var sign: i32 = 1;
    var in_num = false;
    for (input) |c| {
        if (c == '-') {
            sign = -1;
            continue;
        }
        if (c >= '0' and c <= '9') {
            value = value * 10 + @as(i32, c - '0');
            in_num = true;
            continue;
        }
        if (!in_num) continue;
        values[idx] = value * sign;
        idx += 1;
        value = 0;
        sign = 1;
        in_num = false;
        if (idx == 4) break;
    }
    if (in_num and idx < 4) {
        values[idx] = value * sign;
        idx += 1;
    }

    const left = values[0];
    const right = values[1];
    const bottom = values[2];
    const top = values[3];

    const n = -(bottom + 1);
    const p1 = @divTrunc(n * (n + 1), 2);

    var min_dx: i32 = 1;
    while (@divTrunc(min_dx * (min_dx + 1), 2) < left) : (min_dx += 1) {}
    const max_dx = right + 1;
    const min_dy = bottom;
    const max_dy = -bottom;

    const max_t = @as(usize, @intCast(1 - 2 * bottom));
    var new = std.ArrayListUnmanaged(usize){};
    var cont = std.ArrayListUnmanaged(usize){};
    defer new.deinit(std.heap.page_allocator);
    defer cont.deinit(std.heap.page_allocator);

    new.ensureTotalCapacity(std.heap.page_allocator, max_t) catch unreachable;
    cont.ensureTotalCapacity(std.heap.page_allocator, max_t) catch unreachable;
    new.items.len = max_t;
    cont.items.len = max_t;
    @memset(new.items, 0);
    @memset(cont.items, 0);

    var dx: i32 = min_dx;
    while (dx < max_dx) : (dx += 1) {
        var x: i32 = 0;
        var vx: i32 = dx;
        var first = true;
        var t: usize = 0;
        while (t < max_t) : (t += 1) {
            if (x > right) break;
            if (x >= left) {
                if (first) {
                    first = false;
                    new.items[t] += 1;
                } else {
                    cont.items[t] += 1;
                }
            }
            x += vx;
            if (vx > 0) vx -= 1;
        }
    }

    var total: usize = 0;
    var dy: i32 = min_dy;
    while (dy < max_dy) : (dy += 1) {
        var y: i32 = 0;
        var vy: i32 = dy;
        var t: usize = 0;
        var first = true;
        while (y >= bottom) {
            if (y <= top) {
                if (first) {
                    first = false;
                    total += cont.items[t];
                }
                total += new.items[t];
            }
            y += vy;
            vy -= 1;
            t += 1;
        }
    }

    return .{ .p1 = p1, .p2 = total };
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
