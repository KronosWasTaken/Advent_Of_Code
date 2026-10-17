const std = @import("std");

const target = 150;
const lanes = 8;
const V = @Vector(lanes, u32);
const slots = (target + lanes) / lanes * lanes; // volumes 0..target, rounded up to vectors
const pad = 152; // room below volume 0 for any item up to `target`
const inf = std.math.maxInt(u32);
const max_items = 24;

inline fn solve(input: []const u8) struct { p1: u32, p2: u32 } {
    @setRuntimeSafety(false);
    var items: [max_items]usize = undefined;
    var count: usize = 0;

    var idx: usize = 0;
    while (idx < input.len) {
        while (idx < input.len and (input[idx] < '0' or input[idx] > '9')) : (idx += 1) {}
        if (idx >= input.len) break;
        var val: usize = 0;
        while (idx < input.len and input[idx] >= '0' and input[idx] <= '9') : (idx += 1) {
            val = val * 10 + (input[idx] - '0');
        }
        items[count] = val;
        count += 1;
    }

    // 0/1 knapsack tables over volumes 0..150, updated 8 volumes per vector without branches.
    // Each table sits behind `pad` entries of its "nothing" value, so volume - item never
    // needs a bounds check. Volumes are walked downwards and each vector loads its sources
    // before storing, so every update reads the table as it was before this item.
    var ways = [_]u32{0} ** (pad + slots); // subsets reaching each volume
    var fewest = [_]u32{inf} ** (pad + slots); // fewest containers reaching each volume
    ways[pad] = 1;
    fewest[pad] = 0;
    for (items[0..count]) |item| {
        if (item == 0 or item > target) continue;
        var v: usize = slots;
        while (v > 0) {
            v -= lanes;
            const at = pad + v;
            const w: V = ways[at..][0..lanes].*;
            const f: V = fewest[at..][0..lanes].*;
            const w_src: V = ways[at - item ..][0..lanes].*;
            const f_src: V = fewest[at - item ..][0..lanes].*;
            ways[at..][0..lanes].* = w + w_src;
            fewest[at..][0..lanes].* = @min(f, f_src +| @as(V, @splat(1)));
        }
    }

    // Part 2: subsets of exactly the fewest size, counted by size up to that size only.
    const k_min = fewest[pad + target];
    if (k_min > count) return .{ .p1 = ways[pad + target], .p2 = 0 }; // nothing reaches it
    var by_size: [max_items + 1][pad + slots]u32 = undefined;
    for (by_size[0 .. k_min + 1]) |*row| @memset(row, 0);
    by_size[0][pad] = 1;
    for (items[0..count]) |item| {
        if (item == 0 or item > target) continue;
        var k = k_min;
        while (k > 0) : (k -= 1) {
            var v: usize = slots;
            while (v > 0) {
                v -= lanes;
                const at = pad + v;
                const cur: V = by_size[k][at..][0..lanes].*;
                const src: V = by_size[k - 1][at - item ..][0..lanes].*;
                by_size[k][at..][0..lanes].* = cur + src;
            }
        }
    }

    return .{ .p1 = ways[pad + target], .p2 = by_size[k_min][pad + target] };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
