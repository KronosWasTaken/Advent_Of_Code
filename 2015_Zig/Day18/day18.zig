const std = @import("std");

const MASK: u64 = (@as(u64, 1) << 50) - 1;
const LEFT_CORNER: u64 = @as(u64, 1) << 49;
const RIGHT_CORNER: u64 = @as(u64, 1) << 0;

// Lanes: 0 = even columns (part 1), 1 = even columns (part 2),
// 2 = odd columns (part 1), 3 = odd columns (part 2).
const Row = @Vector(4, u64);
const Shift1: @Vector(4, u6) = @splat(1);
const MASK_VEC: Row = @splat(MASK);
const CORNER: Row = .{ 0, LEFT_CORNER, 0, RIGHT_CORNER };
const EVEN_LANES: @Vector(4, bool) = .{ true, true, false, false };
const SWAP_PARITY = [4]i32{ 2, 3, 0, 1 };

inline fn halfAdder(a: Row, b: Row) struct { Row, Row } {
    return .{ a & b, a ^ b };
}

inline fn fullAdder(a: Row, b: Row, c: Row) struct { Row, Row } {
    return .{ (a & b) | (c & (a ^ b)), a ^ b ^ c };
}

// Every column's neighbours have the other parity, so the other parity's word is put in each half.
inline fn swapParity(v: Row) Row {
    return @shuffle(u64, v, undefined, SWAP_PARITY);
}

inline fn toNeighbour(v: Row) Row {
    return @select(u64, EVEN_LANES, v >> Shift1, v << Shift1);
}

inline fn solve(input: []const u8) struct { p1: u32, p2: u32 } {
    @setRuntimeSafety(false);
    var grid: [101]Row = [_]Row{@splat(0)} ** 101;

    var y: usize = 0;
    var x: usize = 0;
    var even: u64 = 0;
    var odd: u64 = 0;

    for (input) |c| {
        const cell: usize = @intFromBool(c == '#' or c == '.');
        const bit: u64 = @intFromBool(c == '#');
        const is_odd: u64 = x & 1;
        // Column x is bit 49 - x / 2 of its parity word, so each word holds its columns from the left.
        const shift: u6 = @intCast(49 - (x >> 1));
        even |= (bit & (1 - is_odd)) << shift;
        odd |= (bit & is_odd) << shift;
        x += cell;
        if (x == 100) {
            grid[y] = .{ even, even, odd, odd };
            y += 1;
            x = 0;
            even = 0;
            odd = 0;
        }
    }

    grid[0] |= CORNER;
    grid[99] |= CORNER;

    var grid2: [101]Row = [_]Row{@splat(0)} ** 101;
    var cur = &grid;
    var nxt = &grid2;

    var step: usize = 0;
    while (step < 100) : (step += 1) {
        var above: Row = @splat(0);
        var row: Row = @splat(0);
        var below = cur[0];

        var gy: usize = 0;
        while (gy < 100) : (gy += 1) {
            above = row;
            row = below;
            below = cur[gy + 1];

            const jk = fullAdder(swapParity(above), swapParity(row), swapParity(below));
            const lm = halfAdder(above, below);
            const n = toNeighbour(jk[0]);
            const o = toNeighbour(jk[1]);

            const pq = fullAdder(jk[0], lm[0], n);
            const rs = fullAdder(jk[1], lm[1], o);
            nxt[gy] = (row | rs[1]) & (pq[1] ^ rs[0]) & ~pq[0] & MASK_VEC;
        }

        nxt[0] |= CORNER;
        nxt[99] |= CORNER;

        const tmp = cur;
        cur = nxt;
        nxt = tmp;
    }

    var count_p1: u32 = 0;
    var count_p2: u32 = 0;
    for (0..100) |gy| {
        count_p1 += @popCount(cur[gy][0]) + @popCount(cur[gy][2]);
        count_p2 += @popCount(cur[gy][1]) + @popCount(cur[gy][3]);
    }

    return .{ .p1 = count_p1, .p2 = count_p2 };
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
