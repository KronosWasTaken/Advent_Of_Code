// Device side of the Day 04 GPU search: one thread per number, MD5 in registers.
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

const S = [64]u32{
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5, 9,  14, 20, 5, 9,  14, 20, 5, 9,  14, 20, 5, 9,  14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
};

// Packed ASCII of the last three digits (value 0..999) and of the first four (value 0..9999).
const TBL3 = blk: {
    @setEvalBranchQuota(100_000);
    var t: [1000]u32 = undefined;
    for (0..1000) |v| t[v] = digit(v / 100) | (digit((v / 10) % 10) << 8) | (digit(v % 10) << 16);
    break :blk t;
};

const TBL4 = blk: {
    @setEvalBranchQuota(200_000);
    var t: [10000]u32 = undefined;
    for (0..10000) |v| t[v] = digit(v / 1000) | (digit((v / 100) % 10) << 8) | (digit((v / 10) % 10) << 16) | (digit(v % 10) << 24);
    break :blk t;
};

fn digit(d: usize) u32 {
    return '0' + @as(u32, @intCast(d));
}

inline fn md5Rounds(M: *const [16]u32) u32 {
    var a: u32 = 0x67452301;
    var b: u32 = 0xefcdab89;
    var c: u32 = 0x98badcfe;
    var d: u32 = 0x10325476;
    // Rounds 0..60 only: the output word is b after round 60.
    inline for (0..61) |i| {
        const g = comptime if (i < 16) i else if (i < 32) (5 * i + 1) % 16 else if (i < 48) (3 * i + 5) % 16 else (7 * i) % 16;
        var F: u32 = if (i < 16) (b & c) | (~b & d) else if (i < 32) (d & b) | (~d & c) else if (i < 48) b ^ c ^ d else c ^ (b | ~d);
        F = F +% a +% K[i] +% M[g];
        a = d;
        d = c;
        c = b;
        b = b +% std.math.rotl(u32, F, S[i]);
    }
    return b +% 0x67452301;
}

// Key "iwrupvqb" then the seven digits of n, which is always one MD5 block here.
inline fn md5Seven(n: u32) u32 {
    const p = n / 1000;
    const t = n - p * 1000;
    var M = [_]u32{0} ** 16;
    M[0] = 0x75727769;
    M[1] = 0x62717670;
    M[2] = TBL4[p];
    M[3] = TBL3[t] | 0x80000000;
    M[14] = 15 * 8;
    return md5Rounds(&M);
}

// Any digit count, with the digits written one by one.
inline fn md5Generic(n: u32, digits: u32) u32 {
    var M = [_]u32{0} ** 16;
    M[0] = 0x75727769;
    M[1] = 0x62717670;
    var rest = n;
    var j: u32 = 0;
    while (j < digits) : (j += 1) {
        const pos = 8 + digits - 1 - j;
        M[pos >> 2] |= (digit(rest % 10)) << @intCast((pos & 3) * 8);
        rest /= 10;
    }
    const end = 8 + digits;
    M[end >> 2] |= @as(u32, 0x80) << @intCast((end & 3) * 8);
    M[14] = end * 8;
    return md5Rounds(&M);
}

inline fn threadIdx() u32 {
    return asm volatile ("mov.u32 %[r], %%tid.x;" : [r] "=r" (-> u32));
}

inline fn blockIdx() u32 {
    return asm volatile ("mov.u32 %[r], %%ctaid.x;" : [r] "=r" (-> u32));
}

inline fn blockDim() u32 {
    return asm volatile ("mov.u32 %[r], %%ntid.x;" : [r] "=r" (-> u32));
}

export fn search(start: u32, count: u32, digits: u32, best1: *u32, best2: *u32) callconv(.kernel) void {
    const idx = blockIdx() * blockDim() + threadIdx();
    if (idx >= count) return;
    const n = start + idx;
    const h0 = if (digits == 7) md5Seven(n) else md5Generic(n, digits);
    if (h0 & 0x00F0FFFF == 0) _ = @atomicRmw(u32, best1, .Min, n, .monotonic);
    if (h0 & 0x00FFFFFF == 0) _ = @atomicRmw(u32, best2, .Min, n, .monotonic);
}
