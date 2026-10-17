// CPU side of the Day 04 search: while the GPU covers the bottom of the range, CPU threads take
// 1000-number chunks from the top slice. Every chunk is seven-digit numbers sharing their first
// four digits, so MD5 steps 0..2 are done once per chunk and the rest runs 8 numbers per AVX2
// vector, three vectors interleaved.
const std = @import("std");

const lanes = 8;
const il = 3;
const Vec = @Vector(lanes, u32);

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

// M[3] for the last three digits 000..999: the digits, then the 0x80 pad. Padded so the last
// interleaved group can read past 999; those lanes are ignored.
const word3 = blk: {
    var t: [1000 + il * lanes]u32 align(32) = [_]u32{0} ** (1000 + il * lanes);
    for (0..1000) |v| t[v] = ('0' + v / 100) | (('0' + v / 10 % 10) << 8) | (('0' + v % 10) << 16) | 0x80000000;
    break :blk t;
};

pub const Shared = struct {
    // Chunk i covers n = lo + 1000*i .. +999.
    lo: u32,
    chunks: u32,
    next: std.atomic.Value(u32) = .init(0),
    done: std.atomic.Value(u32) = .init(0),
    ready: std.atomic.Value(u32) = .init(0),
    go: std.atomic.Value(u32) = .init(0),
    best: [2]std.atomic.Value(u32) = .{ .init(std.math.maxInt(u32)), .init(std.math.maxInt(u32)) },

    // Helper thread body: report in, spin until the solve starts, then take chunks until none
    // are left. Spinning keeps the core awake, so there is no wake-up delay at the start.
    pub fn helper(s: *Shared) void {
        _ = s.ready.fetchAdd(1, .release);
        while (s.go.load(.acquire) == 0) std.atomic.spinLoopHint();
        while (s.workOne()) {}
    }

    pub fn start(s: *Shared) void {
        s.go.store(1, .release);
    }

    // Claim and hash one chunk; false when none are left.
    pub fn workOne(s: *Shared) bool {
        const i = s.next.fetchAdd(1, .monotonic);
        if (i >= s.chunks) return false;
        chunk(s, s.lo + i * 1000);
        _ = s.done.fetchAdd(1, .release);
        return true;
    }
};

// n = c0 .. c0+999, c0 a multiple of 1000 with seven digits.
fn chunk(s: *Shared, c0: u32) void {
    @setEvalBranchQuota(100_000);
    const p = c0 / 1000;
    const m2: u32 = ('0' + p / 1000) | (('0' + p / 100 % 10) << 8) | (('0' + p / 10 % 10) << 16) | (('0' + p % 10) << 24);
    const M = [16]u32{ KEY0, KEY1, m2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 15 * 8, 0 };

    // Steps 0..2 do not depend on the last three digits.
    var a0 = IV[0];
    var b0 = IV[1];
    var c0s = IV[2];
    var d0 = IV[3];
    inline for (0..3) |i| {
        const f = (b0 & c0s) | (~b0 & d0);
        const t = f +% a0 +% K[i] +% M[i];
        a0 = d0;
        d0 = c0s;
        c0s = b0;
        b0 = b0 +% std.math.rotl(u32, t, S[i]);
    }

    var off: u32 = 0;
    while (off < 1000) : (off += il * lanes) {
        var a: [il]Vec = undefined;
        var b: [il]Vec = undefined;
        var c: [il]Vec = undefined;
        var d: [il]Vec = undefined;
        var m3: [il]Vec = undefined;
        inline for (0..il) |j| {
            m3[j] = word3[off + j * lanes ..][0..lanes].*;
            a[j] = @splat(a0);
            b[j] = @splat(b0);
            c[j] = @splat(c0s);
            d[j] = @splat(d0);
        }
        inline for (3..61) |i| {
            const g = comptime switch (i / 16) {
                0 => i,
                1 => (5 * i + 1) % 16,
                2 => (3 * i + 5) % 16,
                else => (7 * i) % 16,
            };
            inline for (0..il) |j| {
                const f = switch (i / 16) {
                    0 => d[j] ^ (b[j] & (c[j] ^ d[j])),
                    1 => c[j] ^ (d[j] & (b[j] ^ c[j])),
                    2 => b[j] ^ c[j] ^ d[j],
                    else => c[j] ^ (b[j] | ~d[j]),
                };
                const w: Vec = if (g == 3) m3[j] else @splat(M[g]);
                const t = f +% a[j] +% @as(Vec, @splat(K[i])) +% w;
                a[j] = d[j];
                d[j] = c[j];
                c[j] = b[j];
                b[j] = b[j] +% std.math.rotl(Vec, t, S[(i / 16) * 4 + i % 4]);
            }
        }
        inline for (0..il) |j| {
            const h = b[j] +% @as(Vec, @splat(IV[0]));
            const hit = (h & @as(Vec, @splat(0x00F0FFFF))) == @as(Vec, @splat(0));
            if (@reduce(.Or, hit)) {
                for (0..lanes) |l| {
                    const k = off + @as(u32, @intCast(j * lanes + l));
                    if (k >= 1000 or !hit[l]) continue;
                    _ = s.best[0].fetchMin(c0 + k, .monotonic);
                    if (h[l] & 0x00FFFFFF == 0) _ = s.best[1].fetchMin(c0 + k, .monotonic);
                }
            }
        }
    }
}
