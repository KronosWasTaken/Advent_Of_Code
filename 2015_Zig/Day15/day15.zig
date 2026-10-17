const std = @import("std");

// Lanes are values of a; several vectors' worth are in flight so their dependency chains overlap.
const lanes = 8;
const Vec = @Vector(lanes, f64);
const Mask = @Vector(lanes, bool);

inline fn splat(x: f64) Vec {
    return @splat(x);
}

// Product of the four property totals at c (teaspoons of ingredient 2) on a line.
inline fn score(alpha: [5]Vec, dc: [5]f64, c: Vec) Vec {
    var s: Vec = splat(1);
    for (0..4) |j| s *= alpha[j] + c * splat(dc[j]);
    return s;
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

    // Inside [lo, hi] every total is positive, so log(score) is a sum of logs of positive
    // affine functions of c: concave. The scores along a line therefore rise and then fall,
    // and climbing from any start reaches the line's exact maximum. Each line starts from the
    // previous line's best c, which is usually within a step or two of the new one. The four
    // lanes are four values of a, and b steps through each lane's lines in order.
    var a0: f64 = 0;
    while (a0 <= 100) : (a0 += lanes) {
        const av: Vec = splat(a0) + std.simd.iota(f64, lanes);
        const b_max: Vec = splat(100) - av;
        var base: [5]Vec = undefined;
        for (0..5) |j| {
            base[j] = av * splat(@floatFromInt(ing[0][j])) + b_max * splat(@floatFromInt(ing[3][j]));
        }
        var best_c: Vec = splat(0);

        var b: f64 = 0;
        while (b <= 100 - a0) : (b += 1) {
            const bv: Vec = splat(b);
            var ok: Mask = bv <= b_max;

            var alpha: [5]Vec = undefined;
            for (0..5) |j| alpha[j] = base[j] + bv * splat(db[j]);

            var lo: Vec = splat(0);
            var hi: Vec = b_max - bv;
            for (0..4) |j| {
                if (dc[j] == 0) {
                    ok = ok & (alpha[j] > splat(0));
                } else {
                    const n = splat(sg[j]) * alpha[j] + splat(kk[j]);
                    const q = @floor(n * splat(inv[j]) + splat(eps));
                    if (dc[j] > 0) lo = @max(lo, q) else hi = @min(hi, q);
                }
            }
            ok = ok & (lo <= hi);

            var c = @min(@max(best_c, lo), hi);
            var cur = score(alpha, dc, c);
            while (true) {
                const up_ok = ok & (c + splat(1) <= hi);
                const dn_ok = ok & (c - splat(1) >= lo);
                const up = score(alpha, dc, c + splat(1));
                const dn = score(alpha, dc, c - splat(1));
                const go_up = up_ok & (up > cur);
                const go_dn = dn_ok & (dn > cur) & !go_up;
                if (!@reduce(.Or, go_up | go_dn)) break;
                c = @select(f64, go_up, c + splat(1), @select(f64, go_dn, c - splat(1), c));
                cur = @select(f64, go_up, up, @select(f64, go_dn, dn, cur));
            }
            best_c = @select(f64, ok, c, best_c);
            const line_max = @select(f64, ok, cur, splat(0));
            p1v = @max(p1v, line_max);

            // Calories are linear in c too: either one c gives exactly 500, or the
            // whole line does when calories do not depend on c.
            if (dc[4] != 0) {
                const n4 = splat(500) - alpha[4];
                const q4 = @floor(n4 * splat(inv[4]) + splat(eps));
                const exact = n4 - q4 * splat(dd[4]) == splat(0);
                const c2 = if (dc[4] > 0) q4 else -q4;
                const cand = ok & exact & (c2 >= lo) & (c2 <= hi);
                p2v = @max(p2v, @select(f64, cand, score(alpha, dc, c2), splat(0)));
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
