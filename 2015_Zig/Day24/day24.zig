const std = @import("std");

const max_items = 32;

const Items = struct {
    v: [max_items + 1]u32, // ascending, padded with maxInt past n
    pre: [max_items + 1]u32, // pre[j] = sum of v[0..j]
    n: usize,
    odd_from: usize, // every item from this index on is odd

    // Sum of the m largest items.
    inline fn top(s: *const Items, m: usize) u32 {
        return s.pre[s.n] - s.pre[s.n - m];
    }

    // First index from `start` whose item can still be completed by m - 1 later picks
    // (those sum to at most top(m - 1)).
    inline fn firstUseful(s: *const Items, start: usize, m: usize, r: u32) usize {
        const need = r -| s.top(m - 1);
        // v is sorted, so the first item >= need sits at index count(v < need).
        const below: @Vector(max_items, bool) = s.v[0..max_items].* < @as(@Vector(max_items, u32), @splat(need));
        return @max(start, @popCount(@as(u32, @bitCast(below))));
    }

    // Smallest product of a pair from v[start..] summing to r. a * (r - a) grows as a
    // approaches r / 2, so the first pair the two-pointer scan meets is the answer.
    inline fn bestPair(s: *const Items, start: usize, r: u32) u64 {
        var lo = start;
        var hi = s.n - 1;
        while (lo < hi) {
            const sum = s.v[lo] + s.v[hi];
            if (sum == r) return @as(u64, s.v[lo]) * s.v[hi];
            if (sum < r) lo += 1 else hi -= 1;
        }
        return std.math.maxInt(u64);
    }

    // Smallest quantum entanglement among the subsets of exactly k items summing to goal,
    // found by an ascending depth-first search with sum and product pruning.
    inline fn bestOfSize(s: *const Items, k: usize, goal: u32) u64 {
        @setRuntimeSafety(false);
        var best: u64 = std.math.maxInt(u64);
        var pos: [max_items]usize = undefined;
        var rem: [max_items]u32 = undefined;
        var prod: [max_items]u64 = undefined;
        var d: usize = 0;
        rem[0] = goal;
        prod[0] = 1;
        pos[0] = s.firstUseful(0, k, goal);
        while (true) {
            const m = k - d;
            const j = pos[d];
            // m odd items can only sum to a remainder of the same parity.
            var ok = j + m <= s.n and s.pre[j + m] - s.pre[j] <= rem[d] and
                (j < s.odd_from or (m ^ rem[d]) & 1 == 0);
            const v = s.v[j];
            const np = prod[d] *| v;
            if (ok) {
                // The other picks are at least the next m - 1 items.
                var bound = np;
                for (1..m) |t| bound *|= s.v[j + t];
                ok = bound < best;
            }
            // Both checks only get worse for later j, so a failure ends this level.
            if (!ok) {
                if (d == 0) break;
                d -= 1;
                pos[d] += 1;
                continue;
            }
            const r = rem[d] - v;
            if (m <= 3) {
                if (m == 3) {
                    best = @min(best, np *| s.bestPair(j + 1, r));
                } else if (m == 1 and r == 0) {
                    best = @min(best, np);
                }
                if (m != 2) {
                    pos[d] += 1;
                    continue;
                }
            }
            d += 1;
            rem[d] = r;
            prod[d] = np;
            pos[d] = s.firstUseful(j + 1, m - 1, r);
        }
        return best;
    }

    inline fn minQe(s: *const Items, goal: u32) u64 {
        var k: usize = 1;
        while (k <= s.n and s.top(k) < goal) : (k += 1) {}
        while (k <= s.n) : (k += 1) {
            const best = s.bestOfSize(k, goal);
            if (best != std.math.maxInt(u64)) return best;
        }
        return std.math.maxInt(u64);
    }
};

inline fn solve(input: []const u8) struct { p1: u64, p2: u64 } {
    @setRuntimeSafety(false);
    var s: Items = undefined;
    @memset(&s.v, std.math.maxInt(u32));
    s.n = 0;
    var sum: u32 = 0;

    var i: usize = 0;
    while (i < input.len) {
        while (i < input.len and (input[i] < '0' or input[i] > '9')) : (i += 1) {}
        if (i >= input.len) break;
        var num: u32 = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
            num = num * 10 + (input[i] - '0');
        }
        // Insertion sort; the input is normally already ascending.
        var j = s.n;
        while (j > 0 and s.v[j - 1] > num) : (j -= 1) s.v[j] = s.v[j - 1];
        s.v[j] = num;
        sum += num;
        s.n += 1;
    }
    s.pre[0] = 0;
    s.odd_from = 0;
    for (0..s.n) |j| {
        s.pre[j + 1] = s.pre[j] + s.v[j];
        if (s.v[j] & 1 == 0) s.odd_from = j + 1;
    }

    var qe: [2]u64 = undefined;
    for (&qe, [2]u32{ 3, 4 }) |*q, groups| q.* = s.minQe(sum / groups);
    return .{ .p1 = qe[0], .p2 = qe[1] };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {d} | Part 2: {d}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}

