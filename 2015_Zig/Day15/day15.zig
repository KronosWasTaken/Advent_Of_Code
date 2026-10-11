const std = @import("std");

const Vec = @Vector(4, f64);
const Mask = @Vector(4, bool);

inline fn splat(x: f64) Vec {
    return @splat(x);
}

inline fn solve(input: []const u8) struct { p1: i64, p2: i64 } {
    @setRuntimeSafety(false);
    // Index 0..3: capacity, durability, flavor, texture; index 4: calories.
    var ing: [4][5]i32 = undefined;
    var count: usize = 0;

    var i: usize = 0;
    while (i < input.len and count < 4) {
        var vals: [5]i32 = undefined;
        var v_idx: usize = 0;
        while (i < input.len and input[i] != '\n' and v_idx < 5) {
            if (input[i] == '-' or (input[i] >= '0' and input[i] <= '9')) {
                const neg = input[i] == '-';
                if (neg) i += 1;
                var num: i32 = 0;
                while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
                    num = num * 10 + (input[i] - '0');
                }
                vals[v_idx] = if (neg) -num else num;
                v_idx += 1;
            } else {
                i += 1;
            }
        }
        ing[count] = vals;
        count += 1;
        while (i < input.len and input[i] != '\n') : (i += 1) {}
        if (i < input.len and input[i] == '\n') i += 1;
    }

    var max_prop: u32 = 0;
    for (ing) |row| {
        for (row[0..4]) |v| max_prop = @max(max_prop, @abs(v));
    }
    // Every total is at most 100 * max_prop in magnitude, so a product of four totals
    // is an integer below 2^53 and f64 arithmetic on it is exact.
    const max_total = 100.0 * @as(f64, @floatFromInt(max_prop));
    if (max_total * max_total * max_total * max_total >= 0x1p53) @panic("totals too large for exact f64 products");

    // With a fixed, a line over c (teaspoons of ingredient 2, d = rem - c) has every
    // total affine in c. Four lanes hold four consecutive b values of the same a.
    var dc: [5]f64 = undefined;
    var db: [5]f64 = undefined;
    var sg: [5]f64 = undefined;
    var kk: [5]f64 = undefined;
    var inv: [5]f64 = undefined;
    var dd: [5]f64 = undefined;
    for (0..5) |j| {
        dc[j] = @floatFromInt(ing[2][j] - ing[3][j]);
        db[j] = @floatFromInt(ing[1][j] - ing[3][j]);
        // Each positivity or calorie test bounds c by floor((kk + sg * total) / dd).
        sg[j] = if (j < 4 and dc[j] < 0) 1 else -1;
        kk[j] = if (j == 4) 500 else if (dc[j] > 0) dc[j] else -1;
        dd[j] = @max(@abs(dc[j]), 1);
        inv[j] = 1.0 / dd[j];
    }
    // Reciprocal multiplication gives the exact floor except when a quotient is an integer and
    // rounds just below it; eps moves those up without crossing any non-integer quotient.
    const eps = 1e-9;

    var p1v: Vec = splat(0);
    var p2v: Vec = splat(0);

    var a: usize = 0;
    while (a <= 100) : (a += 1) {
        const af: f64 = @floatFromInt(a);
        const b_max: f64 = 100.0 - af;
        var base: [5]f64 = undefined;
        for (0..5) |j| {
            base[j] = af * @as(f64, @floatFromInt(ing[0][j])) + (100.0 - af) * @as(f64, @floatFromInt(ing[3][j]));
        }

        var b0: f64 = 0;
        while (b0 <= b_max) : (b0 += 4) {
            const bv: Vec = splat(b0) + Vec{ 0, 1, 2, 3 };
            var ok: Mask = bv <= splat(b_max);

            var alpha: [5]Vec = undefined;
            for (0..5) |j| alpha[j] = splat(base[j]) + bv * splat(db[j]);

            var lo: Vec = splat(0);
            var hi: Vec = splat(b_max) - bv;
            for (0..4) |j| {
                if (dc[j] == 0) {
                    ok = ok & (alpha[j] > splat(0));
                } else {
                    const n = splat(sg[j]) * alpha[j] + splat(kk[j]);
                    const q = @floor(n * splat(inv[j]) + splat(eps));
                    if (dc[j] > 0) lo = @max(lo, q) else hi = @min(hi, q);
                }
            }

            var t: [4]Vec = undefined;
            for (0..4) |j| t[j] = alpha[j] + lo * splat(dc[j]);
            var c = lo;
            var line_max: Vec = splat(0);
            while (true) {
                const active = ok & (c <= hi);
                if (!@reduce(.Or, active)) break;
                const s = t[0] * t[1] * t[2] * t[3];
                line_max = @max(line_max, @select(f64, active, s, splat(0)));
                for (0..4) |j| t[j] += splat(dc[j]);
                c += splat(1);
            }
            p1v = @max(p1v, line_max);

            // Calories are linear in c too: either one c gives exactly 500, or the
            // whole line does when calories do not depend on c.
            if (dc[4] != 0) {
                const n4 = splat(500) - alpha[4];
                const q4 = @floor(n4 * splat(inv[4]) + splat(eps));
                const exact = n4 - q4 * splat(dd[4]) == splat(0);
                const c2 = if (dc[4] > 0) q4 else -q4;
                const cand = ok & exact & (c2 >= lo) & (c2 <= hi);
                for (0..4) |j| t[j] = alpha[j] + c2 * splat(dc[j]);
                const s2 = t[0] * t[1] * t[2] * t[3];
                p2v = @max(p2v, @select(f64, cand, s2, splat(0)));
            } else {
                const cand = ok & (alpha[4] == splat(500));
                p2v = @max(p2v, @select(f64, cand, line_max, splat(0)));
            }
        }
    }

    return .{ .p1 = @intFromFloat(@reduce(.Max, p1v)), .p2 = @intFromFloat(@reduce(.Max, p2v)) };
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
