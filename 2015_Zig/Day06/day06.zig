const std = @import("std");

// The 1000x1000 grid is compressed to the blocks between rectangle edges. Rows are cut at every
// y edge; columns are cut per band of rows, using only the instructions that reach that band,
// which leaves far fewer columns than a global cut. Part 1 keeps a bit per block and part 2 a
// byte, and each block counts with its width times its height.

const Inst = struct {
    op: u2, // 0 = on, 1 = off, 2 = toggle
    x1: u16, // inclusive
    x2: u16, // exclusive (x2 + 1 of the input)
    r1: u16, // compressed rows, inclusive
    r2: u16, // compressed rows, exclusive
};

// Set of edge coordinates 0..1000 as a bitset, with popcount ranks: rank(e) is the index of the
// segment that starts at edge e.
const Edges = struct {
    words: [16]u64,
    prefix: [16]u16,

    fn clear(self: *Edges) void {
        self.words = [_]u64{0} ** 16;
    }

    inline fn add(self: *Edges, e: u16) void {
        self.words[e >> 6] |= @as(u64, 1) << @truncate(e);
    }

    fn finish(self: *Edges) u16 {
        var n: u16 = 0;
        for (&self.prefix, self.words) |*p, w| {
            p.* = n;
            n += @popCount(w);
        }
        return n;
    }

    inline fn rank(self: *const Edges, e: u16) u16 {
        const below = (@as(u64, 1) << @truncate(e)) - 1;
        return self.prefix[e >> 6] + @popCount(self.words[e >> 6] & below);
    }

    // Widths of the segments between consecutive edges, in order.
    fn widths(self: *const Edges, out: []u32) usize {
        var prev: u32 = 0;
        var n: usize = 0;
        var first = true;
        for (self.words, 0..) |w0, wi| {
            var w = w0;
            while (w != 0) : (w &= w - 1) {
                const e: u32 = @intCast(wi * 64 + @ctz(w));
                if (!first) {
                    out[n] = e - prev;
                    n += 1;
                }
                first = false;
                prev = e;
            }
        }
        return n;
    }
};

// Bigger bands share more of the per-band setup, smaller ones cut columns more finely; 96 rows
// measured best.
const band_rows = 96;
const max_cols = 1024;

const V = @Vector(32, u8);

// Brightness changes by `step` per segment: +1 for on, -1 (saturating) for off, +2 for toggle.
inline fn applyStep(comptime op: u2, old: V, step: V) V {
    return switch (op) {
        0, 2 => old +% step,
        1 => old -| step,
        else => unreachable,
    };
}

inline fn stepOf(comptime op: u2) u8 {
    return if (op == 2) 2 else 1;
}

// The step for each lane of vector `vec` that lies inside lo..hi-1, zero elsewhere.
inline fn laneStep(comptime op: u2, vec: usize, lo: usize, hi: usize) V {
    const lane: @Vector(32, u16) = std.simd.iota(u16, 32);
    const pos = @as(@Vector(32, u16), @splat(@intCast(vec * 32))) + lane;
    const inside = (pos >= @as(@Vector(32, u16), @splat(@intCast(lo)))) &
        (pos < @as(@Vector(32, u16), @splat(@intCast(hi))));
    return @select(u8, inside, @as(V, @splat(stepOf(op))), @as(V, @splat(0)));
}

// Part 1 rows: W words of bits (W * 64 >= columns of the band).
fn Bits(comptime W: usize) type {
    return struct {
        const Row = @Vector(W, u64);

        // Bits lo..hi-1 set.
        inline fn span(lo: u16, hi: u16) Row {
            const idx: @Vector(W, u16) = std.simd.iota(u16, W);
            const w1: @Vector(W, u16) = @splat(lo >> 6);
            const w2: @Vector(W, u16) = @splat((hi - 1) >> 6);
            const first: Row = @splat(~((@as(u64, 1) << @truncate(lo)) -% 1));
            const last: Row = @splat((@as(u64, 2) << @truncate(hi - 1)) -% 1);
            const ones: Row = @splat(~@as(u64, 0));
            var m = @select(u64, (idx >= w1) & (idx <= w2), ones, @as(Row, @splat(0)));
            m &= @select(u64, idx == w1, first, ones);
            m &= @select(u64, idx == w2, last, ones);
            return m;
        }

        fn band(insts: []const Inst, active: []const u16, ex: *const Edges, widths: []const u32, heights: []const u32, r0: u16, r1: u16) u64 {
            @setRuntimeSafety(false);
            var rows: [band_rows]Row = [_]Row{@splat(0)} ** band_rows;
            for (active) |ai| {
                const inst = insts[ai];
                const m = span(ex.rank(inst.x1), ex.rank(inst.x2));
                const lo = @max(inst.r1, r0) - r0;
                const hi = @min(inst.r2, r1) - r0;
                switch (inst.op) {
                    0 => for (rows[lo..hi]) |*r| {
                        r.* |= m;
                    },
                    1 => for (rows[lo..hi]) |*r| {
                        r.* &= ~m;
                    },
                    else => for (rows[lo..hi]) |*r| {
                        r.* ^= m;
                    },
                }
            }
            // Plane k has bit c set when bit k of column c's width is set, so a row's lit width
            // is sum_k popcount(row & plane_k) << k.
            // Built 8 columns at a time: shifting bit k of each width into the sign bit lets
            // one movemask collect that plane's 8 bits. `widths` is zero past the last column.
            var pw: [10][W]u64 = undefined;
            for (0..W) |wi| {
                var plane_bits = [_]u64{0} ** 10;
                inline for (0..8) |g| {
                    const v: @Vector(8, u32) = widths[wi * 64 + g * 8 ..][0..8].*;
                    inline for (0..10) |k| {
                        const top: @Vector(8, i32) = @bitCast(v << @splat(31 - k));
                        const bits: u8 = @bitCast(top < @as(@Vector(8, i32), @splat(0)));
                        plane_bits[k] |= @as(u64, bits) << (g * 8);
                    }
                }
                for (0..10) |k| pw[k][wi] = plane_bits[k];
            }
            var planes: [10]Row = undefined;
            for (&planes, pw) |*p, pws| p.* = pws;
            var total: u64 = 0;
            for (rows[0 .. r1 - r0], heights[r0..r1]) |r, h| {
                var lit: u64 = 0;
                inline for (0..10) |k| lit += @reduce(.Add, @as(Row, @popCount(r & planes[k]))) << k;
                total += lit * h;
            }
            return total;
        }
    };
}

fn part2Band(insts: []const Inst, active: []const u16, ex: *const Edges, cols: usize, widths: *const [max_cols + 256]u32, heights: []const u32, r0: u16, r1: u16) u64 {
    @setRuntimeSafety(false);
    // Column-major: each 32-column vector's rows are contiguous, so applying an instruction
    // walks memory sequentially down every column it covers.
    const vstride = (cols + 31) / 32;
    const nr: usize = r1 - r0;
    var buf: [band_rows * max_cols / 32]V = undefined;
    const band = buf[0 .. nr * vstride];
    @memset(band, @splat(0));
    for (active) |ai| {
        const inst = insts[ai];
        const lo = ex.rank(inst.x1);
        const hi = ex.rank(inst.x2);
        const y_lo = @max(inst.r1, r0) - r0;
        const y_hi = @min(inst.r2, r1) - r0;
        switch (inst.op) {
            inline else => |op| {
                const first = lo / 32;
                const last = (hi - 1) / 32;
                const first_step = laneStep(op, first, lo, hi);
                const last_step = laneStep(op, last, lo, hi);
                const mid: V = @splat(stepOf(op));
                // Column vectors outside, rows inside: the inner trip count is the same for
                // every column of the instruction, so its exit predicts well.
                for (first..last + 1) |v| {
                    const step = if (v == first) first_step else if (v == last) last_step else mid;
                    for (band[v * nr + y_lo .. v * nr + y_hi]) |*e| e.* = applyStep(op, e.*, step);
                }
            },
        }
    }
    // Per column vector: brightness weighted by row height down the column, then by width.
    var total: u64 = 0;
    for (0..vstride) |v| {
        var acc: @Vector(32, u32) = @splat(0);
        for (band[v * nr ..][0..nr], heights[r0..r1]) |b, h| acc += @as(@Vector(32, u32), b) * @as(@Vector(32, u32), @splat(h));
        const w: @Vector(32, u32) = widths[v * 32 ..][0..32].*;
        total += @reduce(.Add, @as(@Vector(32, u64), acc * w));
    }
    return total;
}

inline fn solve(input: []const u8) struct { p1: u64, p2: u64 } {
    @setRuntimeSafety(false);
    var raw: [512][5]u16 = undefined;
    var inst_count: usize = 0;

    var i: usize = 0;
    while (i < input.len) {
        if (input[i] != 't') break;
        const op: u2 = if (input[i + 6] == 'n') 0 else if (input[i + 6] == 'f') 1 else 2;
        i += if (op == 0) 8 else if (op == 1) 9 else 7;

        var x1: u16 = 0;
        while (input[i] != ',') : (i += 1) x1 = x1 * 10 + (input[i] - '0');
        i += 1;
        var y1: u16 = 0;
        while (input[i] != ' ') : (i += 1) y1 = y1 * 10 + (input[i] - '0');
        i += 9;
        var x2: u16 = 0;
        while (input[i] != ',') : (i += 1) x2 = x2 * 10 + (input[i] - '0');
        i += 1;
        var y2: u16 = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) y2 = y2 * 10 + (input[i] - '0');
        while (i < input.len and (input[i] == '\n' or input[i] == '\r')) : (i += 1) {}
        raw[inst_count] = .{ op, x1, x2 + 1, y1, y2 + 1 };
        inst_count += 1;
    }

    // Rows are compressed globally at every y edge.
    var ey: Edges = undefined;
    ey.clear();
    ey.add(0);
    ey.add(1000);
    for (raw[0..inst_count]) |r| {
        ey.add(r[3]);
        ey.add(r[4]);
    }
    _ = ey.finish();
    var heights: [max_cols]u32 = undefined;
    const rows = ey.widths(&heights);

    var insts: [512]Inst = undefined;
    for (raw[0..inst_count], insts[0..inst_count]) |r, *inst| {
        inst.* = .{ .op = @intCast(r[0]), .x1 = r[1], .x2 = r[2], .r1 = ey.rank(r[3]), .r2 = ey.rank(r[4]) };
    }

    // Columns are compressed per band of rows, using only the instructions that reach the
    // band: edges of instructions elsewhere would only split columns needlessly.
    var p1: u64 = 0;
    var p2: u64 = 0;
    var active: [512]u16 = undefined;
    var widths: [max_cols + 256]u32 = undefined;
    var r0: u16 = 0;
    while (r0 < rows) : (r0 += band_rows) {
        const r1: u16 = @intCast(@min(r0 + band_rows, rows));
        var ex: Edges = undefined;
        ex.clear();
        ex.add(0);
        ex.add(1000);
        var n: usize = 0;
        for (insts[0..inst_count], 0..) |inst, k| {
            if (inst.r1 < r1 and inst.r2 > r0) {
                active[n] = @intCast(k);
                n += 1;
                ex.add(inst.x1);
                ex.add(inst.x2);
            }
        }
        _ = ex.finish();
        const cols = ex.widths(&widths);
        @memset(widths[cols..][0..256], 0);
        const act = active[0..n];
        p1 += switch ((cols + 255) / 256) {
            1 => Bits(4).band(insts[0..inst_count], act, &ex, &widths, heights[0..rows], r0, r1),
            2 => Bits(8).band(insts[0..inst_count], act, &ex, &widths, heights[0..rows], r0, r1),
            else => Bits(16).band(insts[0..inst_count], act, &ex, &widths, heights[0..rows], r0, r1),
        };
        p2 += part2Band(insts[0..inst_count], act, &ex, cols, &widths, heights[0..rows], r0, r1);
    }
    return .{ .p1 = p1, .p2 = p2 };
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
