// Device side of the Day 04 GPU search. Each thread owns one decade n = 10q .. 10q+9: the key
// and the leading digits are shared, so the setup and MD5 steps 0..2 run once per thread and
// only the last digit (one byte of M[3]) changes between its ten hashes.
const std = @import("std");

const K = [64]u32{
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed, 0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
};

const S = [16]u5{ 7, 12, 17, 22, 5, 9, 14, 20, 4, 11, 16, 23, 6, 10, 15, 21 };

const IV = [4]u32{ 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476 };
const KEY0: u32 = 0x75727769; // "iwru"
const KEY1: u32 = 0x62717670; // "pvqb"

const State = struct { a: u32, b: u32, c: u32, d: u32 };

// x * one + y. `one` is a kernel parameter that is always 1, so ptxas cannot fold the multiply
// and must emit an IMAD, which runs on the FMA pipe. The MD5 loop otherwise saturates the
// integer ALU pipe (LOP3, IADD3, LEA.HI) while the FMA pipe sits idle.
inline fn madOne(x: u32, one: u32, y: u32) u32 {
    return asm ("mad.lo.u32 %[r], %[x], %[o], %[y];"
        : [r] "=r" (-> u32),
        : [x] "r" (x),
          [o] "r" (one),
          [y] "r" (y),
    );
}

// MD5 steps [from, to). Steps past 60 are never needed: the first output word is b after step 60,
// plus IV[0], and step 60 returns that sum directly as .b.
inline fn steps(comptime from: usize, comptime to: usize, st: State, M: *const [16]u32, one: u32) State {
    return stepsN(1, from, to, .{st}, M, .{M[3]}, one)[0];
}

// The same steps for N messages that differ only in M[3], interleaved step by step so each
// basic block holds N independent dependency chains for the scheduler to overlap.
inline fn stepsN(comptime N: usize, comptime from: usize, comptime to: usize, st: [N]State, M: *const [16]u32, m3: [N]u32, one: u32) [N]State {
    var s = st;
    inline for (from..to) |i| {
        const g = comptime switch (i / 16) {
            0 => i,
            1 => (5 * i + 1) % 16,
            2 => (3 * i + 5) % 16,
            else => (7 * i) % 16,
        };
        inline for (&s, 0..) |*x, l| {
            const f = switch (i / 16) {
                0 => (x.b & x.c) | (~x.b & x.d),
                1 => (x.d & x.b) | (~x.d & x.c),
                2 => x.b ^ x.c ^ x.d,
                else => x.c ^ (x.b | ~x.d),
            };
            const w = if (g == 3) m3[l] else M[g];
            // f + a + K + M as two IMADs on the FMA pipe instead of an IADD3 on the busy ALU pipe.
            const t = madOne(f, one, madOne(one, K[i] +% w, x.a));
            // The output word gets IV[0] added here, off the critical path, instead of after the step.
            const base = if (i == 60) madOne(one, IV[0], x.b) else x.b;
            x.a = x.d;
            x.d = x.c;
            x.c = x.b;
            // ptxas fuses the add and the rotate into a single LEA.HI.
            x.b = base +% std.math.rotl(u32, t, S[(i / 16) * 4 + i % 4]);
        }
    }
    return s;
}

// out.b is the first word of the digest; its low bytes are the leading hex digits.
inline fn record(out: State, n: u32, best: *[2]u32) void {
    const h0 = out.b;
    if (h0 & 0x00F0FFFF == 0) {
        _ = @atomicRmw(u32, &best[0], .Min, n, .monotonic);
        if (h0 & 0x00FFFFFF == 0) _ = @atomicRmw(u32, &best[1], .Min, n, .monotonic);
    }
}

// ASCII of a four-digit number, first digit in the low byte. SWAR: split into two 0..99 halves
// in 16-bit lanes, then one multiply by 103/1024 divides both lanes by 10 at once.
inline fn ascii4(p: u32) u32 {
    const hi = p / 100;
    const x = hi | ((p - hi * 100) << 16);
    const tens = ((x *% 103) >> 10) & 0x000F000F;
    const ones = x - tens * 10;
    return (tens | (ones << 8)) + 0x30303030;
}

const iv_state = State{ .a = IV[0], .b = IV[1], .c = IV[2], .d = IV[3] };

// Decade of D-digit numbers (D = 5, 6 or 7): "iwrupvqb" + four prefix digits fill M[0..2],
// the remaining D-4 digits and the 0x80 pad sit in M[3], and the last digit is byte D-5 of M[3].
inline fn decade(comptime D: u32, q: u32, best: *[2]u32, one: u32) void {
    @setEvalBranchQuota(100_000);
    const div = comptime std.math.pow(u32, 10, D - 5);
    const p = q / div;
    const low = q - p * div;
    const pad = @as(u32, 0x80) << (8 * (D - 4));
    const zero = @as(u32, 0x30) << (8 * (D - 5));
    var m3 = pad | zero | switch (D) {
        7 => (0x30 + low / 10) | ((0x30 + low % 10) << 8),
        6 => 0x30 + low,
        else => 0,
    };
    const inc = @as(u32, 1) << (8 * (D - 5));

    var M = [_]u32{0} ** 16;
    M[0] = KEY0;
    M[1] = KEY1;
    M[2] = ascii4(p);
    M[14] = (8 + D) * 8;
    const head = steps(0, 3, iv_state, &M, one);

    // All ten hashes interleaved step by step: ten independent chains to schedule. Measured
    // faster than 1, 2 or 5 at a time. The single-trip loop is deliberate: in this form ptxas
    // allocates 56 registers and interleaves more aggressively than the straight-line version
    // (48 registers), which measured ~5% slower.
    var n = q * 10;
    const end = n + 10;
    while (n < end) : (n += 10) {
        var m3s: [10]u32 = undefined;
        inline for (&m3s, 0..) |*x, k| x.* = m3 +% @as(u32, k) * inc;
        const outs = stepsN(10, 3, 61, .{head} ** 10, &M, m3s, one);
        inline for (outs, 0..) |o, k| record(o, n + @as(u32, k), best);
        m3 +%= 10 * inc;
    }
}

// n below 10000 (q < 1000): digits written one by one, whole message per hash.
fn small(q: u32, best: *[2]u32, one: u32) void {
    var k: u32 = 0;
    while (k < 10) : (k += 1) {
        const n = q * 10 + k;
        if (n == 0) continue;
        // Bytes 8..15 of the message: the digits, then the 0x80 pad.
        var w: u64 = 0x80;
        var len: u32 = 8;
        var rest = n;
        while (rest != 0) : (rest /= 10) {
            w = (w << 8) | (0x30 + rest % 10);
            len += 1;
        }
        var M = [_]u32{0} ** 16;
        M[0] = KEY0;
        M[1] = KEY1;
        M[2] = @truncate(w);
        M[3] = @truncate(w >> 32);
        M[14] = len * 8;
        record(steps(0, 61, iv_state, &M, one), n, best);
    }
}

inline fn threadIdx() u32 {
    return asm volatile ("mov.u32 %[r], %%tid.x;"
        : [r] "=r" (-> u32),
    );
}

inline fn blockIdx() u32 {
    return asm volatile ("mov.u32 %[r], %%ctaid.x;"
        : [r] "=r" (-> u32),
    );
}

inline fn blockDim() u32 {
    return asm volatile ("mov.u32 %[r], %%ntid.x;"
        : [r] "=r" (-> u32),
    );
}

// Thread q checks n = 10q .. 10q+9 for q in [start, end); best[0] and best[1] collect the
// smallest n for each part.
export fn search(start: u32, end: u32, best: *[2]u32, one: u32) callconv(.kernel) void {
    const q = start + blockIdx() * blockDim() + threadIdx();
    if (q >= end) return;
    if (q >= 100000) {
        decade(7, q, best, one);
    } else if (q >= 10000) {
        decade(6, q, best, one);
    } else if (q >= 1000) {
        decade(5, q, best, one);
    } else {
        small(q, best, one);
    }
}
