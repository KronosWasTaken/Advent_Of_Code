const std = @import("std");

const KEY = "iwrupvqb";
const SIMD_WIDTH = 8;
// 4+ lanes spill YMM registers and run slower.
const IL = 3;
const Vec = @Vector(SIMD_WIDTH, u32);

const S = [64]u32{
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5, 9,  14, 20, 5, 9,  14, 20, 5, 9,  14, 20, 5, 9,  14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
};

const K = [64]u32{
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
    0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
    0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
    0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
    0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
    0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
    0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
    0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
    0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
};

inline fn rotateLeftVec(x: Vec, n: u32) Vec {
    const shift: @Vector(SIMD_WIDTH, u5) = @splat(@intCast(n));
    const inv_shift: @Vector(SIMD_WIDTH, u5) = @splat(@intCast(32 - n));
    return (x << shift) | (x >> inv_shift);
}

const WORD3_15 = blk: {
    var tbl: [1000]u32 align(64) = undefined;
    for (0..1000) |n| {
        const d0: u32 = '0' + @as(u32, @intCast(n / 100));
        const d1: u32 = '0' + @as(u32, @intCast((n / 10) % 10));
        const d2: u32 = '0' + @as(u32, @intCast(n % 10));
        tbl[n] = d0 | (d1 << 8) | (d2 << 16) | 0x80000000;
    }
    break :blk tbl;
};

const DIGITS = blk: {
    var tbl: [1000][3]u8 = undefined;
    for (0..1000) |n| {
        tbl[n][0] = '0' + @as(u8, @intCast(n / 100));
        tbl[n][1] = '0' + @as(u8, @intCast((n / 10) % 10));
        tbl[n][2] = '0' + @as(u8, @intCast(n % 10));
    }
    break :blk tbl;
};

inline fn md5TransformVec(M: [16]Vec) Vec {
    var a: Vec = @splat(0x67452301);
    var b: Vec = @splat(0xefcdab89);
    var c: Vec = @splat(0x98badcfe);
    var d: Vec = @splat(0x10325476);

    inline for (0..64) |round| {
        var F: Vec = undefined;
        var g: usize = undefined;

        if (round < 16) {
            F = (b & c) | ((~b) & d);
            g = round;
        } else if (round < 32) {
            F = (d & b) | ((~d) & c);
            g = (5 * round + 1) % 16;
        } else if (round < 48) {
            F = b ^ c ^ d;
            g = (3 * round + 5) % 16;
        } else {
            F = c ^ (b | (~d));
            g = (7 * round) % 16;
        }

        const k_vec: Vec = @splat(K[round]);
        F = F +% a +% k_vec +% M[g];
        a = d;
        d = c;
        c = b;
        b = b +% rotateLeftVec(F, S[round]);
    }

    return a +% @as(Vec, @splat(0x67452301));
}

const Precomputed = struct {
    a: u32,
    b: u32,
    c: u32,
    d: u32,
};

inline fn precomputeRounds012(m2: u32) Precomputed {
    var a: u32 = 0x67452301;
    var b: u32 = 0xefcdab89;
    var c: u32 = 0x98badcfe;
    var d: u32 = 0x10325476;
    const m0: u32 = 0x75727769; // "iwru"
    const m1: u32 = 0x62717670; // "pvqb"

    inline for (0..3) |round| {
        const F = (b & c) | ((~b) & d);
        const m = if (round == 0) m0 else if (round == 1) m1 else m2;
        const temp = F +% a +% K[round] +% m;
        a = d;
        d = c;
        c = b;
        b = b +% std.math.rotl(u32, temp, S[round]);
    }

    return .{ .a = a, .b = b, .c = c, .d = d };
}

const WORD3_14 = blk: {
    var tbl: [104]u32 align(64) = [_]u32{0} ** 104;
    for (0..100) |n| {
        const d0: u32 = '0' + @as(u32, @intCast(n / 10));
        const d1: u32 = '0' + @as(u32, @intCast(n % 10));
        tbl[n] = d0 | (d1 << 8) | 0x00800000;
    }
    break :blk tbl;
};

inline fn md5TransformSpecialized(comptime m14: u32, pre: Precomputed, m2: u32, m3: Vec) Vec {
    const F3_const: u32 = (pre.d ^ (pre.b & (pre.c ^ pre.d))) +% pre.a +% K[3];
    const F3: Vec = @as(Vec, @splat(F3_const)) +% m3;

    var a: Vec = @splat(pre.d);
    var d: Vec = @splat(pre.c);
    var c: Vec = @splat(pre.b);
    var b: Vec = @as(Vec, @splat(pre.b)) +% rotateLeftVec(F3, S[3]);

    const m0: u32 = 0x75727769;
    const m1: u32 = 0x62717670;
    const k29_m2: u32 = K[29] +% m2;
    const k47_m2: u32 = K[47] +% m2;

    inline for (4..61) |round| {
        var F: Vec = undefined;
        if (round < 16) {
            F = d ^ (b & (c ^ d));
        } else if (round < 32) {
            F = c ^ (d & (b ^ c));
        } else if (round < 48) {
            F = b ^ c ^ d;
        } else {
            F = c ^ (b | (~d));
        }

        const g = if (round < 16)
            round
        else if (round < 32)
            (5 * round + 1) % 16
        else if (round < 48)
            (3 * round + 5) % 16
        else
            (7 * round) % 16;

        if (g == 3) {
            F = F +% a +% @as(Vec, @splat(K[round])) +% m3;
        } else if (g == 0) {
            F = F +% a +% @as(Vec, @splat(K[round] +% m0));
        } else if (g == 1) {
            F = F +% a +% @as(Vec, @splat(K[round] +% m1));
        } else if (round == 29) {
            F = F +% a +% @as(Vec, @splat(k29_m2));
        } else if (round == 47) {
            F = F +% a +% @as(Vec, @splat(k47_m2));
        } else if (g == 14) {
            F = F +% a +% @as(Vec, @splat(K[round] +% m14));
        } else {
            F = F +% a +% @as(Vec, @splat(K[round]));
        }

        a = d;
        d = c;
        c = b;
        b = b +% rotateLeftVec(F, S[round]);
    }

    // At the end of round 60, b holds the exact value.
    // The addition of 0x67452301 is folded into the additive inverse constant comparison!
    return b;
}

inline fn md5TransformInterleaved(comptime N: usize, comptime m14: u32, pre: Precomputed, m2: u32, m3: [N]Vec) [N]Vec {
    const F3_const: u32 = (pre.d ^ (pre.b & (pre.c ^ pre.d))) +% pre.a +% K[3];

    var a: [N]Vec = undefined;
    var b: [N]Vec = undefined;
    var c: [N]Vec = undefined;
    var d: [N]Vec = undefined;
    inline for (0..N) |j| {
        const F3: Vec = @as(Vec, @splat(F3_const)) +% m3[j];
        a[j] = @splat(pre.d);
        d[j] = @splat(pre.c);
        c[j] = @splat(pre.b);
        b[j] = @as(Vec, @splat(pre.b)) +% rotateLeftVec(F3, S[3]);
    }

    const m0: u32 = 0x75727769;
    const m1: u32 = 0x62717670;
    const k29_m2: u32 = K[29] +% m2;
    const k47_m2: u32 = K[47] +% m2;

    inline for (4..61) |round| {
        const g = if (round < 16)
            round
        else if (round < 32)
            (5 * round + 1) % 16
        else if (round < 48)
            (3 * round + 5) % 16
        else
            (7 * round) % 16;

        inline for (0..N) |j| {
            var F: Vec = undefined;
            if (round < 16) {
                F = d[j] ^ (b[j] & (c[j] ^ d[j]));
            } else if (round < 32) {
                F = c[j] ^ (d[j] & (b[j] ^ c[j]));
            } else if (round < 48) {
                F = b[j] ^ c[j] ^ d[j];
            } else {
                F = c[j] ^ (b[j] | (~d[j]));
            }

            if (g == 3) {
                F = F +% a[j] +% @as(Vec, @splat(K[round])) +% m3[j];
            } else if (g == 0) {
                F = F +% a[j] +% @as(Vec, @splat(K[round] +% m0));
            } else if (g == 1) {
                F = F +% a[j] +% @as(Vec, @splat(K[round] +% m1));
            } else if (round == 29) {
                F = F +% a[j] +% @as(Vec, @splat(k29_m2));
            } else if (round == 47) {
                F = F +% a[j] +% @as(Vec, @splat(k47_m2));
            } else if (g == 14) {
                F = F +% a[j] +% @as(Vec, @splat(K[round] +% m14));
            } else {
                F = F +% a[j] +% @as(Vec, @splat(K[round]));
            }

            const new_b = b[j] +% rotateLeftVec(F, S[round]);
            a[j] = d[j];
            d[j] = c[j];
            c[j] = b[j];
            b[j] = new_b;
        }
    }

    return b;
}

inline fn formatInt(buf: []u8, n: u32) usize {
    @setRuntimeSafety(false);
    if (n == 0) {
        buf[0] = '0';
        return 1;
    }
    var num = n;
    var len: usize = 0;
    var temp: [10]u8 = undefined;
    while (num > 0) {
        temp[len] = @intCast('0' + (num % 10));
        num /= 10;
        len += 1;
    }
    for (0..len) |i| {
        buf[i] = temp[len - 1 - i];
    }
    return len;
}

const Shared = struct {
    iter: std.atomic.Value(u32),
    result_p1: std.atomic.Value(u32),
    result_p2: std.atomic.Value(u32),
};

// No number at or above both current results can lower either answer, so a
// worker may stop once its next block starts there.
fn searchBound(shared: *const Shared) u32 {
    return @max(shared.result_p1.load(.monotonic), shared.result_p2.load(.monotonic));
}

fn workerThread(shared: *Shared) void {
    @setEvalBranchQuota(100000);
    @setRuntimeSafety(false);
    var buf: [64]u8 = undefined;
    @memcpy(buf[0..KEY.len], KEY);

    while (true) {
        const big_start = shared.iter.fetchAdd(16000, .monotonic);
        if (big_start >= searchBound(shared)) return;

        var chunk_offset: u32 = 0;
        while (chunk_offset < 16000) : (chunk_offset += 1000) {
            const chunk_start = big_start + chunk_offset;
            if (chunk_start >= searchBound(shared)) return;

            if (chunk_start < 1000) {
                var hash_out: [16]u8 = undefined;
                for (0..1000) |i| {
                    const n = chunk_start + @as(u32, @intCast(i));
                    if (n == 0) continue;
                    const len = KEY.len + formatInt(buf[KEY.len..], n);

                    std.crypto.hash.Md5.hash(buf[0..len], &hash_out, .{});
                    checkResult(n, &hash_out, shared);
                }
                continue;
            }

        const base_len = KEY.len + formatInt(buf[KEY.len..], chunk_start);

        if (base_len == 14) {
            const mask5 = @as(Vec, @splat(0x00F0FFFF));
            const zero_vec = @as(Vec, @splat(0));
            const a_init = @as(Vec, @splat(0x67452301));

            for (0..10) |h_idx| {
                const sub_start = chunk_start + @as(u32, @intCast(h_idx * 100));
                _ = formatInt(buf[KEY.len..], sub_start);
                const m2 = std.mem.readInt(u32, buf[8..12], .little);
                const pre = precomputeRounds012(m2);

                var k: u32 = 0;
                while (k + IL * SIMD_WIDTH <= 100) : (k += IL * SIMD_WIDTH) {
                    var m3: [IL]Vec = undefined;
                    inline for (0..IL) |j| {
                        m3[j] = @as(*align(4) const Vec, @ptrCast(&WORD3_14[k + j * SIMD_WIDTH])).*;
                    }

                    const b = md5TransformInterleaved(IL, 112, pre, m2, m3);

                    var a: [IL]Vec = undefined;
                    var hit = @as(@Vector(SIMD_WIDTH, bool), @splat(false));
                    inline for (0..IL) |j| {
                        a[j] = b[j] +% a_init;
                        hit = hit | ((a[j] & mask5) == zero_vec);
                    }

                    if (@reduce(.Or, hit)) {
                        inline for (0..IL) |j| {
                            const cj = (a[j] & mask5) == zero_vec;
                            inline for (0..SIMD_WIDTH) |i| {
                                if (cj[i]) {
                                    const n = sub_start + k + @as(u32, j * SIMD_WIDTH + i);
                                    _ = shared.result_p1.fetchMin(n, .monotonic);
                                    if ((a[j][i] & 0x00FFFFFF) == 0) {
                                        _ = shared.result_p2.fetchMin(n, .monotonic);
                                    }
                                }
                            }
                        }
                    }
                }

                while (k < 100) : (k += SIMD_WIDTH) {
                    const m3 = @as(*align(4) const Vec, @ptrCast(&WORD3_14[k])).*;
                    const a = md5TransformSpecialized(112, pre, m2, m3) +% a_init;
                    const check5 = (a & mask5) == zero_vec;
                    if (@reduce(.Or, check5)) {
                        inline for (0..SIMD_WIDTH) |i| {
                            if (check5[i]) {
                                const n = sub_start + k + @as(u32, i);
                                if (n < sub_start + 100) {
                                    _ = shared.result_p1.fetchMin(n, .monotonic);
                                    if ((a[i] & 0x00FFFFFF) == 0) {
                                        _ = shared.result_p2.fetchMin(n, .monotonic);
                                    }
                                }
                            }
                        }
                    }
                }
            }
            continue;
        }

        if (base_len == 15) {
            const m2 = std.mem.readInt(u32, buf[8..12], .little);
            const pre = precomputeRounds012(m2);
            const mask6 = @as(Vec, @splat(0x00FFFFFF));
            const inv6 = @as(Vec, @splat(0x00BADCFF));
            var offset: u32 = 0;

            while (offset + IL * SIMD_WIDTH <= 1000) : (offset += IL * SIMD_WIDTH) {
                var m3: [IL]Vec = undefined;
                inline for (0..IL) |j| {
                    m3[j] = @as(*align(4) const Vec, @ptrCast(&WORD3_15[offset + j * SIMD_WIDTH])).*;
                }

                const b = md5TransformInterleaved(IL, 120, pre, m2, m3);

                var hit = @as(@Vector(SIMD_WIDTH, bool), @splat(false));
                inline for (0..IL) |j| {
                    hit = hit | ((b[j] & mask6) == inv6);
                }

                if (@reduce(.Or, hit)) {
                    inline for (0..IL) |j| {
                        const cj = (b[j] & mask6) == inv6;
                        inline for (0..SIMD_WIDTH) |i| {
                            if (cj[i]) {
                                const n = chunk_start + offset + @as(u32, j * SIMD_WIDTH + i);
                                _ = shared.result_p2.fetchMin(n, .monotonic);
                            }
                        }
                    }
                }
            }

            // Remainder (8 numbers at a time)
            while (offset < 1000) : (offset += SIMD_WIDTH) {
                const m3 = @as(*align(4) const Vec, @ptrCast(&WORD3_15[offset])).*;
                const b = md5TransformSpecialized(120, pre, m2, m3);
                const check6 = (b & mask6) == inv6;
                if (@reduce(.Or, check6)) {
                    inline for (0..SIMD_WIDTH) |i| {
                        if (check6[i]) {
                            const n = chunk_start + offset + @as(u32, i);
                            _ = shared.result_p2.fetchMin(n, .monotonic);
                        }
                    }
                }
            }
            continue;
        }

        var buffers: [SIMD_WIDTH][64]u8 = undefined;
        for (0..SIMD_WIDTH) |i| {
            @memcpy(&buffers[i], &buf);
        }

        for (0..SIMD_WIDTH) |i| {
            buffers[i][base_len] = 0x80;
            @memset(buffers[i][base_len + 1 .. 56], 0);

            const bit_len = base_len * 8;
            buffers[i][56] = @intCast(bit_len & 0xFF);
            buffers[i][57] = @intCast((bit_len >> 8) & 0xFF);
            buffers[i][58] = @intCast((bit_len >> 16) & 0xFF);
            buffers[i][59] = @intCast((bit_len >> 24) & 0xFF);
            @memset(buffers[i][60..], 0);
        }

        var M: [16]Vec = undefined;
        inline for (0..16) |j| {
            var lane_vals: [SIMD_WIDTH]u32 = undefined;
            inline for (0..SIMD_WIDTH) |i| {
                lane_vals[i] = std.mem.readInt(u32, @ptrCast(&buffers[i][j * 4]), .little);
            }
            M[j] = lane_vals;
        }

        const w1 = (base_len - 3) / 4;
        const w2 = (base_len - 1) / 4;

        var offset: u32 = 0;
        // General path for other lengths
        while (offset < 1000) : (offset += SIMD_WIDTH) {
                inline for (0..SIMD_WIDTH) |i| {
                    const curr_offset = offset + @as(u32, i);
                    const d = DIGITS[curr_offset];
                    buffers[i][base_len - 3] = d[0];
                    buffers[i][base_len - 2] = d[1];
                    buffers[i][base_len - 1] = d[2];
                }

                inline for (0..SIMD_WIDTH) |i| {
                    M[w1][i] = std.mem.readInt(u32, @ptrCast(&buffers[i][w1 * 4]), .little);
                }
                if (w1 != w2) {
                    inline for (0..SIMD_WIDTH) |i| {
                        M[w2][i] = std.mem.readInt(u32, @ptrCast(&buffers[i][w2 * 4]), .little);
                    }
                }

                const a = md5TransformVec(M);

                const mask5 = @as(Vec, @splat(0x00F0FFFF));
                const check5 = (a & mask5) == @as(Vec, @splat(0));
                if (@reduce(.Or, check5)) {
                    inline for (0..SIMD_WIDTH) |i| {
                        if (check5[i]) {
                            const n = chunk_start + offset + @as(u32, i);
                            _ = shared.result_p1.fetchMin(n, .monotonic);

                            if ((a[i] & 0x00FFFFFF) == 0) {
                                _ = shared.result_p2.fetchMin(n, .monotonic);
                            }
                        }
                    }
                }
            }
        }
    }
}

fn checkResult(n: u32, hash: *const [16]u8, shared: *Shared) void {
    if (hash[0] == 0 and hash[1] == 0 and hash[2] < 0x10) {
        _ = shared.result_p1.fetchMin(n, .monotonic);
    }
    if (hash[0] == 0 and hash[1] == 0 and hash[2] == 0) {
        _ = shared.result_p2.fetchMin(n, .monotonic);
    }
}

pub fn main() !void {
    var shared = Shared{
        .iter = std.atomic.Value(u32).init(0),
        .result_p1 = std.atomic.Value(u32).init(std.math.maxInt(u32)),
        .result_p2 = std.atomic.Value(u32).init(std.math.maxInt(u32)),
    };

    var timer = try std.time.Timer.start();
    try run_solve(&shared);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;

    std.debug.print("Part 1: {}\n", .{shared.result_p1.load(.monotonic)});
    std.debug.print("Part 2: {}\n", .{shared.result_p2.load(.monotonic)});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}

fn run_solve(shared: *Shared) !void {
    const num_threads = @max(std.Thread.getCpuCount() catch 12, 1);
    var threads: [32]std.Thread = undefined;
    const actual_threads = @min(num_threads, threads.len);

    for (0..actual_threads - 1) |i| {
        threads[i] = try std.Thread.spawn(.{}, workerThread, .{shared});
    }
    workerThread(shared);

    for (0..actual_threads - 1) |i| {
        threads[i].join();
    }
}
