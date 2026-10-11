const std = @import("std");

const Inst = struct {
    op: u2, // 0 = on, 1 = off, 2 = toggle
    x1: u16,
    x2: u16,
    y1: u16,
    y2: u16,
};


const V = @Vector(32, u8);

// Coordinates run 0..999, so every rectangle edge (x1 and x2 + 1) is one of 0..1000.
// Both parts only need the state of each block between neighbouring edges, so the grid
// is compressed to those blocks, and each block is weighted by its size when summing.
const Axis = struct {
    seg_of: [1001]u16, // segment index that starts at each edge coordinate
    width: [1024]u32, // size of each segment, zero past the last one
    count: usize,

    fn build(marks: *const [1001]bool) Axis {
        var axis: Axis = .{ .seg_of = undefined, .width = [_]u32{0} ** 1024, .count = 0 };
        var edges: [1001]u16 = undefined;
        var n: usize = 0;
        for (marks, 0..) |marked, c| {
            axis.seg_of[c] = @intCast(n);
            edges[n] = @intCast(c);
            n += @intFromBool(marked);
        }
        for (0..n - 1) |i| axis.width[i] = edges[i + 1] - edges[i];
        axis.count = n - 1;
        return axis;
    }
};

// Compressed space is processed in bands of rows. Each band is cleared and reused, so the
// working set stays small: fresh pages are expensive to touch on Windows.
const band_rows = 64;

const Row = @Vector(8, u64);

// Bits lo..hi are inclusive, and only the words of this 8-word chunk are returned.
inline fn spanMask(chunk: usize, lo: u16, hi: u16) Row {
    const ones: Row = @splat(~@as(u64, 0));
    const zeros: Row = @splat(0);
    const lane: @Vector(8, u16) = std.simd.iota(u16, 8);
    const word_idx = @as(@Vector(8, u16), @splat(@intCast(chunk * 8))) + lane;
    const w1: @Vector(8, u16) = @splat(lo >> 6);
    const w2: @Vector(8, u16) = @splat(hi >> 6);
    const b1: u6 = @truncate(lo);
    const b2: u6 = @truncate(hi);
    const mask_first: Row = @splat(~((@as(u64, 1) << b1) -% 1));
    const mask_last: Row = @splat((@as(u64, 2) << b2) -% 1);

    // Words between the two end words are fully covered, the end words get partial masks.
    // When both ends share a word, the two partial masks are ANDed together.
    const in_span = (word_idx >= w1) & (word_idx <= w2);
    var mask = @select(u64, in_span, ones, zeros);
    mask &= @select(u64, word_idx == w1, mask_first, ones);
    mask &= @select(u64, word_idx == w2, mask_last, ones);
    return mask;
}

var bits_buf: [band_rows][2]Row = undefined;

inline fn applyBits(comptime op: u2, comptime chunks: usize, row: *[2]Row, masks: [2]Row) void {
    for (0..chunks) |c| {
        row[c] = switch (op) {
            0 => row[c] | masks[c],
            1 => row[c] & ~masks[c],
            2 => row[c] ^ masks[c],
            else => unreachable,
        };
    }
}

fn runPart1Bitset(comptime chunks: usize, insts: []const Inst, x_axis: *const Axis, y_axis: *const Axis) u32 {
    @setRuntimeSafety(false);
    const zeros: Row = @splat(0);

    // Plane k has bit s set when bit k of x-segment s's width is set. Summing the lit
    // segments weighted by width is then one popcount per plane, shifted by k.
    var plane_words: [10][16]u64 = [_][16]u64{[_]u64{0} ** 16} ** 10;
    for (0..x_axis.count) |s| {
        const width = x_axis.width[s];
        for (0..10) |k| {
            const bit: u6 = @intCast(s % 64);
            plane_words[k][s / 64] |= @as(u64, (width >> @intCast(k)) & 1) << bit;
        }
    }
    var planes: [10][2]Row = undefined;
    for (0..10) |k| {
        for (0..2) |c| planes[k][c] = plane_words[k][c * 8 ..][0..8].*;
    }

    var total: u32 = 0;
    var band_start: usize = 0;
    while (band_start < y_axis.count) : (band_start += band_rows) {
        const band_end = @min(band_start + band_rows, y_axis.count);
        @memset(bits_buf[0 .. band_end - band_start], [_]Row{zeros} ** 2);

        for (insts) |inst| {
            const y_lo = @max(inst.y1, band_start);
            const y_hi = @min(inst.y2, band_end);
            if (y_lo >= y_hi) continue;

            var masks: [2]Row = .{ zeros, zeros };
            for (0..chunks) |c| masks[c] = spanMask(c, inst.x1, inst.x2 - 1);

            switch (inst.op) {
                inline else => |op| for (y_lo..y_hi) |y| applyBits(op, chunks, &bits_buf[y - band_start], masks),
            }
        }

        for (band_start..band_end) |y| {
            const row = &bits_buf[y - band_start];
            var lit_width: u64 = 0;
            for (0..10) |k| {
                var lit: u64 = 0;
                for (0..chunks) |c| {
                    lit += @reduce(.Add, @as(@Vector(8, u64), @popCount(row[c] & planes[k][c])));
                }
                const shift: u6 = @intCast(k);
                lit_width += lit << shift;
            }
            total += @intCast(lit_width * y_axis.width[y]);
        }
    }
    return total;
}

// Compressed grid, row-major with a 32-aligned stride so each row splits into whole vectors.
var band2_buf: [band_rows * 1024]u8 align(32) = undefined;

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

// Only the first and last vectors of a range can be partly outside it, so their steps are
// built once per instruction and every row then just reuses them.
const Span = struct {
    first: usize,
    last: usize,
    first_step: V,
    last_step: V,
};

inline fn spanFor(comptime op: u2, lo: usize, hi: usize) Span {
    return .{
        .first = lo / 32,
        .last = (hi - 1) / 32,
        .first_step = laneStep(op, lo / 32, lo, hi),
        .last_step = laneStep(op, (hi - 1) / 32, lo, hi),
    };
}

inline fn updateRow(comptime op: u2, row: []u8, span: Span) void {
    const vecs: [*]align(32) V = @ptrCast(@alignCast(row.ptr));
    const mid: V = @splat(stepOf(op));
    vecs[span.first] = applyStep(op, vecs[span.first], span.first_step);
    if (span.first == span.last) return;
    for (span.first + 1..span.last) |v| vecs[v] = applyStep(op, vecs[v], mid);
    vecs[span.last] = applyStep(op, vecs[span.last], span.last_step);
}

fn runPart2Compressed(insts: []const Inst, x_axis: *const Axis, y_axis: *const Axis) u32 {
    @setRuntimeSafety(false);
    const stride = (x_axis.count + 31) & ~@as(usize, 31);

    var total: u32 = 0;
    var band_start: usize = 0;
    while (band_start < y_axis.count) : (band_start += band_rows) {
        const band_end = @min(band_start + band_rows, y_axis.count);
        const band = band2_buf[0 .. (band_end - band_start) * stride];
        @memset(band, 0);

        for (insts) |inst| {
            const y_lo = @max(inst.y1, band_start);
            const y_hi = @min(inst.y2, band_end);
            if (y_lo >= y_hi) continue;
            switch (inst.op) {
                inline else => |op| {
                    const span = spanFor(op, inst.x1, inst.x2);
                    for (y_lo..y_hi) |y| updateRow(op, band[(y - band_start) * stride ..][0..stride], span);
                },
            }
        }

        for (band_start..band_end) |y| {
            const row = band[(y - band_start) * stride ..][0..stride];
            var acc: @Vector(32, u32) = @splat(0);
            var x: usize = 0;
            while (x < stride) : (x += 32) {
                const v: V = row[x..][0..32].*;
                const w: @Vector(32, u32) = x_axis.width[x..][0..32].*;
                acc += @as(@Vector(32, u32), v) * w;
            }
            total += @reduce(.Add, acc) * y_axis.width[y];
        }
    }
    return total;
}

inline fn solve(input: []const u8) struct { p1: u32, p2: u32 } {
    @setRuntimeSafety(false);
    var insts: [512]Inst = undefined;
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

        insts[inst_count] = .{
            .op = op,
            .x1 = x1,
            .x2 = x2,
            .y1 = y1,
            .y2 = y2,
        };
        inst_count += 1;
    }

    // Edges are inclusive starts and exclusive ends, so each rectangle covers x1..x2+1.
    var x_marks = [_]bool{false} ** 1001;
    var y_marks = [_]bool{false} ** 1001;
    x_marks[0] = true;
    x_marks[1000] = true;
    y_marks[0] = true;
    y_marks[1000] = true;
    for (insts[0..inst_count]) |inst| {
        x_marks[inst.x1] = true;
        x_marks[inst.x2 + 1] = true;
        y_marks[inst.y1] = true;
        y_marks[inst.y2 + 1] = true;
    }
    const x_axis = Axis.build(&x_marks);
    const y_axis = Axis.build(&y_marks);

    var segs: [512]Inst = undefined;
    for (insts[0..inst_count], segs[0..inst_count]) |inst, *seg| {
        seg.* = .{
            .op = inst.op,
            .x1 = x_axis.seg_of[inst.x1],
            .x2 = x_axis.seg_of[inst.x2 + 1],
            .y1 = y_axis.seg_of[inst.y1],
            .y2 = y_axis.seg_of[inst.y2 + 1],
        };
    }

    const p1 = if (x_axis.count <= 512)
        runPart1Bitset(1, segs[0..inst_count], &x_axis, &y_axis)
    else
        runPart1Bitset(2, segs[0..inst_count], &x_axis, &y_axis);
    const p2 = runPart2Compressed(segs[0..inst_count], &x_axis, &y_axis);
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
