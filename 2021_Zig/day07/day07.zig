const std = @import("std");

const Result = struct {
    p1: i32,
    p2: i32,
};

fn selectKth(values: []i32, k: usize) i32 {
    var left: usize = 0;
    var right: usize = values.len - 1;
    while (true) {
        if (left == right) return values[left];
        const pivot = values[(left + right) / 2];
        var i = left;
        var j = right;
        while (i <= j) {
            while (values[i] < pivot) i += 1;
            while (values[j] > pivot) j -= 1;
            if (i <= j) {
                std.mem.swap(i32, &values[i], &values[j]);
                i += 1;
                if (j == 0) break;
                j -= 1;
            }
        }
        if (k <= j) {
            right = j;
        } else if (k >= i) {
            left = i;
        } else {
            return values[k];
        }
    }
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    var count: usize = 0;
    for (input) |c| {
        if (c == ',') count += 1;
    }
    if (input.len > 0) count += 1;

    const values = allocator.alloc(i32, count) catch unreachable;
    defer allocator.free(values);

    var idx: usize = 0;
    var value: i32 = 0;
    var sign: i32 = 1;
    var in_number = false;
    for (input) |c| {
        if (c == '-') {
            sign = -1;
            continue;
        }
        if (c >= '0' and c <= '9') {
            value = value * 10 + @as(i32, c - '0');
            in_number = true;
            continue;
        }
        if (!in_number) continue;
        values[idx] = value * sign;
        idx += 1;
        value = 0;
        sign = 1;
        in_number = false;
    }
    if (in_number) {
        values[idx] = value * sign;
        idx += 1;
    }
    const slice = values[0..idx];

    const half = slice.len / 2;
    var median: i32 = undefined;
    if (slice.len % 2 == 0) {
        const upper = selectKth(slice, half);
        const lower = selectKth(slice, half - 1);
        median = @divTrunc(lower + upper, 2);
    } else {
        median = selectKth(slice, half);
    }

    var p1: i32 = 0;
    var sum: i32 = 0;
    for (slice) |v| {
        const diff = if (v > median) v - median else median - v;
        p1 += diff;
        sum += v;
    }

    const mean: i32 = @divTrunc(sum, @as(i32, @intCast(slice.len)));
    var best: i32 = std.math.maxInt(i32);
    var delta: i32 = -1;
    while (delta <= 1) : (delta += 1) {
        var total: i32 = 0;
        const target = mean + delta;
        for (slice) |v| {
            const diff = if (v > target) v - target else target - v;
            total += @divTrunc(diff * (diff + 1), 2);
        }
        if (total < best) best = total;
    }

    return .{ .p1 = p1, .p2 = best };
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
