const std = @import("std");

const KEY = "iwrupvqb";
const SIMD_WIDTH = 8;
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

inline fn md5TransformVec(M: [16]Vec) [4]Vec {
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

    return .{
        a +% @as(Vec, @splat(0x67452301)),
        b +% @as(Vec, @splat(0xefcdab89)),
        c +% @as(Vec, @splat(0x98badcfe)),
        d +% @as(Vec, @splat(0x10325476)),
    };
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
    found_p1: std.atomic.Value(bool),
    found_p2: std.atomic.Value(bool),
};

fn workerThread(shared: *Shared) void {
    @setRuntimeSafety(false);
    var buf: [64]u8 = undefined;
    @memcpy(buf[0..KEY.len], KEY);

    while (true) {
        if (shared.found_p1.load(.acquire) and shared.found_p2.load(.acquire)) return;

        const chunk_start = shared.iter.fetchAdd(1000, .monotonic);
        
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
        
        var buffers: [SIMD_WIDTH][64]u8 = undefined;
        for (0..SIMD_WIDTH) |i| {
            @memcpy(&buffers[i], &buf);
        }

        for (0..SIMD_WIDTH) |i| {
            buffers[i][base_len] = 0x80;
            @memset(buffers[i][base_len+1..56], 0);
            
            const bit_len = base_len * 8;
            buffers[i][56] = @intCast(bit_len & 0xFF);
            buffers[i][57] = @intCast((bit_len >> 8) & 0xFF);
            buffers[i][58] = @intCast((bit_len >> 16) & 0xFF);
            buffers[i][59] = @intCast((bit_len >> 24) & 0xFF);
            @memset(buffers[i][60..], 0);
        }

        var offset: u32 = 0;
        while (offset < 1000) : (offset += SIMD_WIDTH) {
            inline for (0..SIMD_WIDTH) |i| {
                const curr_offset = offset + @as(u32, i);
                
                buffers[i][base_len - 3] = '0' + @as(u8, @intCast(curr_offset / 100));
                buffers[i][base_len - 2] = '0' + @as(u8, @intCast((curr_offset / 10) % 10));
                buffers[i][base_len - 1] = '0' + @as(u8, @intCast(curr_offset % 10));
            }

            var M: [16]Vec = undefined;
            inline for (0..16) |j| {
                var lane_vals: [SIMD_WIDTH]u32 = undefined;
                inline for (0..SIMD_WIDTH) |i| {
                    lane_vals[i] = std.mem.readInt(u32, @ptrCast(&buffers[i][j*4]), .little);
                }
                M[j] = lane_vals;
            }

            const res = md5TransformVec(M);
            const a = res[0];

            if (!shared.found_p1.load(.acquire)) {
                 const mask = @as(Vec, @splat(0x00F0FFFF));
                 const check = (a & mask) == @as(Vec, @splat(0));
                 if (@reduce(.Or, check)) {
                     inline for (0..SIMD_WIDTH) |i| {
                         if (check[i]) {
                             const n = chunk_start + offset + @as(u32, i);
                             _ = shared.result_p1.fetchMin(n, .monotonic);
                             shared.found_p1.store(true, .release);
                         }
                     }
                 }
            }
            
            if (!shared.found_p2.load(.acquire)) {
                 const mask = @as(Vec, @splat(0x00FFFFFF));
                 const check = (a & mask) == @as(Vec, @splat(0));
                 if (@reduce(.Or, check)) {
                     inline for (0..SIMD_WIDTH) |i| {
                         if (check[i]) {
                             const n = chunk_start + offset + @as(u32, i);
                             _ = shared.result_p2.fetchMin(n, .monotonic);
                             shared.found_p2.store(true, .release);
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
        shared.found_p1.store(true, .release);
    }
    if (hash[0] == 0 and hash[1] == 0 and hash[2] == 0) {
        _ = shared.result_p2.fetchMin(n, .monotonic);
        shared.found_p2.store(true, .release);
    }
}

pub fn main() !void {
    var shared_warmup = Shared{
        .iter = std.atomic.Value(u32).init(0),
        .result_p1 = std.atomic.Value(u32).init(std.math.maxInt(u32)),
        .result_p2 = std.atomic.Value(u32).init(std.math.maxInt(u32)),
        .found_p1 = std.atomic.Value(bool).init(false),
        .found_p2 = std.atomic.Value(bool).init(false),
    };
    try run_solve(&shared_warmup);
    
    std.debug.print("Part 1: {}\n", .{shared_warmup.result_p1.load(.monotonic)});
    std.debug.print("Part 2: {}\n", .{shared_warmup.result_p2.load(.monotonic)});

    const iters = 10;
    var timer = try std.time.Timer.start();
    const start = timer.read();
    
    for (0..iters) |_| {
        var shared = Shared{
            .iter = std.atomic.Value(u32).init(0),
            .result_p1 = std.atomic.Value(u32).init(std.math.maxInt(u32)),
            .result_p2 = std.atomic.Value(u32).init(std.math.maxInt(u32)),
            .found_p1 = std.atomic.Value(bool).init(false),
            .found_p2 = std.atomic.Value(bool).init(false),
        };
        try run_solve(&shared);
    }
    
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Total: {d:.2} microseconds\n", .{elapsed_us});
    std.debug.print("Average: {d:.2} microseconds\n", .{elapsed_us / @as(f64, @floatFromInt(iters))});
}

fn run_solve(shared: *Shared) !void {
    const num_threads = @max(std.Thread.getCpuCount() catch 8, 1);
    var threads: [32]std.Thread = undefined;
    const actual_threads = @min(num_threads, threads.len);
    
    for (0..actual_threads) |i| {
        threads[i] = try std.Thread.spawn(.{}, workerThread, .{shared});
    }
    
    for (0..actual_threads) |i| {
        threads[i].join();
    }
}
