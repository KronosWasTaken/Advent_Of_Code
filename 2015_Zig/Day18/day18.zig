const std = @import("std");

const MASK: u64 = (@as(u64, 1) << 50) - 1;
const LEFT_CORNER: u64 = @as(u64, 1) << 49;
const RIGHT_CORNER: u64 = @as(u64, 1) << 0;

const Vec2 = @Vector(2, u64);
const Shift1: @Vector(2, u6) = @splat(1);
const MASK_VEC: Vec2 = @splat(MASK);
const CORNER_EVEN = Vec2{ 0, LEFT_CORNER };
const CORNER_ODD = Vec2{ 0, RIGHT_CORNER };

const RowVec = struct {
    even: Vec2 = @splat(0),
    odd: Vec2 = @splat(0),
};

inline fn halfAdder(a: Vec2, b: Vec2) struct { Vec2, Vec2 } {
    return .{ a & b, a ^ b };
}

inline fn fullAdder(a: Vec2, b: Vec2, c: Vec2) struct { Vec2, Vec2 } {
    return .{ (a & b) | (c & (a ^ b)), a ^ b ^ c };
}

inline fn solve(input: []const u8) struct { p1: u32, p2: u32 } {
    @setRuntimeSafety(false);
    var grid: [101]RowVec = [_]RowVec{.{}} ** 101;

    var y: usize = 0;
    var x: usize = 0;
    var even: u64 = 0;
    var odd: u64 = 0;

    for (input) |c| {
        if (c == '#' or c == '.') {
            const bit: u64 = @intFromBool(c == '#');
            if ((x & 1) == 0) {
                even = (even << 1) | bit;
            } else {
                odd = (odd << 1) | bit;
            }
            x += 1;
            if (x == 100) {
                grid[y] = .{
                    .even = @splat(even),
                    .odd = @splat(odd),
                };
                y += 1;
                x = 0;
                even = 0;
                odd = 0;
            }
        }
    }

    // Set corners for Part 2 initially
    grid[0].even |= CORNER_EVEN;
    grid[0].odd |= CORNER_ODD;
    grid[99].even |= CORNER_EVEN;
    grid[99].odd |= CORNER_ODD;

    var grid2: [101]RowVec = [_]RowVec{.{}} ** 101;
    var cur = &grid;
    var nxt = &grid2;

    var step: usize = 0;
    while (step < 100) : (step += 1) {
        var above = RowVec{};
        var row = RowVec{};
        var below = cur[0];

        var gy: usize = 0;
        while (gy < 100) : (gy += 1) {
            above = row;
            row = below;
            below = cur[gy + 1];

            // Even columns
            const e_jk = fullAdder(above.odd, row.odd, below.odd);
            const e_lm = halfAdder(above.even, below.even);
            const e_n = e_jk[0] >> Shift1;
            const e_o = e_jk[1] >> Shift1;

            const e_pq = fullAdder(e_jk[0], e_lm[0], e_n);
            const e_rs = fullAdder(e_jk[1], e_lm[1], e_o);
            nxt[gy].even = (row.even | e_rs[1]) & (e_pq[1] ^ e_rs[0]) & ~e_pq[0] & MASK_VEC;

            // Odd columns
            const o_jk = fullAdder(above.even, row.even, below.even);
            const o_lm = halfAdder(above.odd, below.odd);
            const o_n = o_jk[0] << Shift1;
            const o_o = o_jk[1] << Shift1;

            const o_pq = fullAdder(o_jk[0], o_lm[0], o_n);
            const o_rs = fullAdder(o_jk[1], o_lm[1], o_o);
            nxt[gy].odd = (row.odd | o_rs[1]) & (o_pq[1] ^ o_rs[0]) & ~o_pq[0] & MASK_VEC;
        }

        nxt[0].even |= CORNER_EVEN;
        nxt[0].odd |= CORNER_ODD;
        nxt[99].even |= CORNER_EVEN;
        nxt[99].odd |= CORNER_ODD;

        const tmp = cur;
        cur = nxt;
        nxt = tmp;
    }

    var count_p1: u32 = 0;
    var count_p2: u32 = 0;
    for (0..100) |gy| {
        count_p1 += @popCount(cur[gy].even[0]) + @popCount(cur[gy].odd[0]);
        count_p2 += @popCount(cur[gy].even[1]) + @popCount(cur[gy].odd[1]);
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
