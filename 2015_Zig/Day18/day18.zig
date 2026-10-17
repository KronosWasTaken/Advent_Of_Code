const std = @import("std");

const EVEN_BITS: u64 = 0x5555_5555_5555_5555;
const ODD_BITS: u64 = 0xAAAA_AAAA_AAAA_AAAA;

// Lanes: 0 = even columns (part 1), 1 = odd columns (part 1),
// 2 = even columns (part 2), 3 = odd columns (part 2). Column x is bit x / 2 of its parity word.
const Row = @Vector(4, u64);
const SHIFT_UP: @Vector(4, u6) = .{ 15, 0, 15, 0 };
const SHIFT_DOWN: @Vector(4, u6) = .{ 14, 1, 14, 1 };
// Part 2 corners: column 0 is even bit 0, column 99 is odd bit 49.
const CORNER: Row = .{ 0, 0, 1, @as(u64, 1) << 49 };
const SWAP_PARITY = [4]i32{ 1, 0, 3, 2 };
const Bytes = @Vector(32, u8);
const HASH: Bytes = @splat('#');

// Every column's neighbours have the other parity, so the other parity's word is swapped in
// (an in-lane shuffle, since both parities of a part share a 128-bit half).
inline fn swapParity(v: Row) Row {
    return @shuffle(u64, v, undefined, SWAP_PARITY);
}

// Even column 2k's second neighbour is odd column 2k-1 (bit k-1 -> shift up), odd column 2k+1's is
// even column 2k+2 (bit k+1 -> shift down). Two variable shifts do both directions without a blend,
// and going up by 15 then down by 14 drops column 99 off the word's top instead of needing a mask.
inline fn toNeighbour(v: Row) Row {
    return (v << SHIFT_UP) >> SHIFT_DOWN;
}

// Per row, once per step: h = left + self + right (2 bits), p = left + right (2 bits).
// Each row's sums serve the rows above and below it, so only one shuffle and two shifts per row.
const Sums = struct { h1: Row, h0: Row, p1: Row, p0: Row };

inline fn horizontal(row: Row) Sums {
    const same = swapParity(row);
    const other = toNeighbour(same);
    const p1 = same & other;
    const p0 = same ^ other;
    return .{ .h1 = p1 | (row & p0), .h0 = p0 ^ row, .p1 = p1, .p0 = p0 };
}

inline fn hashBits(chunk: *const [32]u8) u64 {
    const v: Bytes = chunk.*;
    return @as(u32, @bitCast(v == HASH));
}

inline fn pext(src: u64, mask: u64) u64 {
    return asm ("pextq %[mask], %[src], %[ret]"
        : [ret] "=r" (-> u64),
        : [src] "r" (src),
          [mask] "r" (mask),
    );
}

inline fn solve(input: []const u8) struct { p1: u32, p2: u32 } {
    @setRuntimeSafety(false);
    var grid: [101]Row = undefined;
    grid[100] = @splat(0);

    const stride = std.mem.indexOfScalar(u8, input, '\n').? + 1;
    for (0..100) |y| {
        const line = input[y * stride ..];
        // Columns 0..63 and 64..99; the last load ends exactly at column 99 to stay inside the input.
        const lo = hashBits(line[0..32]) | hashBits(line[32..64]) << 32;
        const hi = hashBits(line[64..96]) | (hashBits(line[68..100]) >> 28) << 32;
        const even = pext(lo, EVEN_BITS) | pext(hi, EVEN_BITS) << 32;
        const odd = pext(lo, ODD_BITS) | pext(hi, ODD_BITS) << 32;
        grid[y] = .{ even, odd, even, odd };
    }

    grid[0] |= CORNER;
    grid[99] |= CORNER;

    var grid2: [101]Row = undefined;
    grid2[100] = @splat(0);
    var cur = &grid;
    var nxt = &grid2;

    var step: usize = 0;
    while (step < 100) : (step += 1) {
        var above: Sums = .{ .h1 = @splat(0), .h0 = @splat(0), .p1 = @splat(0), .p0 = @splat(0) };
        var row = cur[0];
        var mid = horizontal(row);

        var gy: usize = 0;
        while (gy < 100) : (gy += 1) {
            const below_row = cur[gy + 1];
            const below = horizontal(below_row);

            // Neighbour count = row sums above and below + the pair sum beside the cell.
            const twos_carry = (above.h1 & below.h1) | (mid.p1 & (above.h1 ^ below.h1));
            const twos = above.h1 ^ below.h1 ^ mid.p1;
            const ones_carry = (above.h0 & below.h0) | (mid.p0 & (above.h0 ^ below.h0));
            const ones = above.h0 ^ below.h0 ^ mid.p0;
            // Alive next iff (count | alive) == 3.
            nxt[gy] = (row | ones) & (twos ^ ones_carry) & ~twos_carry;

            above = mid;
            mid = below;
            row = below_row;
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
        count_p1 += @popCount(cur[gy][0]) + @popCount(cur[gy][1]);
        count_p2 += @popCount(cur[gy][2]) + @popCount(cur[gy][3]);
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
