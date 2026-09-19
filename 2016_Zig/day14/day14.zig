const std = @import("std");

const Vec = @Vector(8, u32);

inline fn rotl(comptime s: u6, v: Vec) Vec {
    return (v << @as(Vec, @splat(s))) | (v >> @as(Vec, @splat(32 - s)));
}

const MD5_SHIFTS = [64]u5{
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5, 9,  14, 20, 5, 9,  14, 20, 5, 9,  14, 20, 5, 9,  14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
};

const MD5_CONSTS = [64]u32{
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed, 0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
};

inline fn swapEndianVec(v: Vec) Vec {
    return @as(Vec, @Vector(8, u32){
        @byteSwap(v[0]),
        @byteSwap(v[1]),
        @byteSwap(v[2]),
        @byteSwap(v[3]),
        @byteSwap(v[4]),
        @byteSwap(v[5]),
        @byteSwap(v[6]),
        @byteSwap(v[7]),
    });
}

inline fn hexEncodeWord(val: u32) struct { hi: u32, lo: u32 } {
    var x = @as(u64, val);
    x = ((x << 16) & 0x0000ffff00000000) | (x & 0x000000000000ffff);
    x = ((x << 8) & 0x00ff000000ff0000) | (x & 0x000000ff000000ff);
    x = ((x << 4) & 0x0f000f000f000f00) | (x & 0x000f000f000f000f);

    const letters = ((x + 0x0606060606060606) >> 4) & 0x0101010101010101;
    const ascii = x + 0x3030303030303030 + letters * 39;

    return .{
        .hi = @byteSwap(@as(u32, @truncate(ascii >> 32))),
        .lo = @byteSwap(@as(u32, @truncate(ascii))),
    };
}

inline fn md5Transform8(M: [16]Vec) [4]Vec {
    var a: Vec = @splat(0x67452301);
    var b: Vec = @splat(0xefcdab89);
    var c: Vec = @splat(0x98badcfe);
    var d: Vec = @splat(0x10325476);

    inline for (0..16) |i| {
        const f = (b & c) | ((~b) & d);
        const next_b = b +% rotl(MD5_SHIFTS[i], a +% f +% @as(Vec, @splat(MD5_CONSTS[i])) +% M[i]);
        a = d;
        d = c;
        c = b;
        b = next_b;
    }
    inline for (0..16) |i| {
        const g = (5 * i + 1) % 16;
        const f = (d & b) | ((~d) & c);
        const next_b = b +% rotl(MD5_SHIFTS[16 + i], a +% f +% @as(Vec, @splat(MD5_CONSTS[16 + i])) +% M[g]);
        a = d;
        d = c;
        c = b;
        b = next_b;
    }
    inline for (0..16) |i| {
        const g = (3 * i + 5) % 16;
        const f = b ^ c ^ d;
        const next_b = b +% rotl(MD5_SHIFTS[32 + i], a +% f +% @as(Vec, @splat(MD5_CONSTS[32 + i])) +% M[g]);
        a = d;
        d = c;
        c = b;
        b = next_b;
    }
    inline for (0..16) |i| {
        const g = (7 * i) % 16;
        const f = c ^ (b | (~d));
        const next_b = b +% rotl(MD5_SHIFTS[48 + i], a +% f +% @as(Vec, @splat(MD5_CONSTS[48 + i])) +% M[g]);
        a = d;
        d = c;
        c = b;
        b = next_b;
    }

    return .{
        swapEndianVec(a +% @as(Vec, @splat(0x67452301))),
        swapEndianVec(b +% @as(Vec, @splat(0xefcdab89))),
        swapEndianVec(c +% @as(Vec, @splat(0x98badcfe))),
        swapEndianVec(d +% @as(Vec, @splat(0x10325476))),
    };
}

fn stretchMd5Simd(h: *[4]Vec) void {
    @setRuntimeSafety(false);
    var M: [16]Vec = undefined;
    M[8] = @splat(0x80);
    M[9] = @splat(0);
    M[10] = @splat(0);
    M[11] = @splat(0);
    M[12] = @splat(0);
    M[13] = @splat(0);
    M[14] = @splat(32 * 8);
    M[15] = @splat(0);

    var words: [8][8]u32 = undefined;
    inline for (0..8) |lane| {
        const p0 = hexEncodeWord(h[0][lane]);
        const p1 = hexEncodeWord(h[1][lane]);
        const p2 = hexEncodeWord(h[2][lane]);
        const p3 = hexEncodeWord(h[3][lane]);

        words[0][lane] = p0.hi;
        words[1][lane] = p0.lo;
        words[2][lane] = p1.hi;
        words[3][lane] = p1.lo;
        words[4][lane] = p2.hi;
        words[5][lane] = p2.lo;
        words[6][lane] = p3.hi;
        words[7][lane] = p3.lo;
    }

    inline for (0..8) |k| {
        M[k] = words[k];
    }

    h.* = md5Transform8(M);
}

fn md5Scalar(msg: []const u8, out: *[4]u32) void {
    @setRuntimeSafety(false);
    var block = [_]u8{0} ** 64;
    @memcpy(block[0..msg.len], msg);
    block[msg.len] = 0x80;
    std.mem.writeInt(u32, block[56..60], @intCast(msg.len * 8), .little);

    var M: [16]u32 = undefined;
    for (0..16) |i| {
        M[i] = std.mem.readInt(u32, block[i * 4 ..][0..4], .little);
    }

    var a: u32 = 0x67452301;
    var b: u32 = 0xefcdab89;
    var c: u32 = 0x98badcfe;
    var d: u32 = 0x10325476;

    inline for (0..64) |i| {
        var f: u32 = undefined;
        var g: usize = undefined;
        if (i < 16) {
            f = (b & c) | ((~b) & d);
            g = i;
        } else if (i < 32) {
            f = (d & b) | ((~d) & c);
            g = (5 * i + 1) % 16;
        } else if (i < 48) {
            f = b ^ c ^ d;
            g = (3 * i + 5) % 16;
        } else {
            f = c ^ (b | (~d));
            g = (7 * i) % 16;
        }
        const next_b = b +% std.math.rotl(u32, a +% f +% MD5_CONSTS[i] +% M[g], MD5_SHIFTS[i]);
        a = d;
        d = c;
        c = b;
        b = next_b;
    }

    out[0] = @byteSwap(a +% 0x67452301);
    out[1] = @byteSwap(b +% 0xefcdab89);
    out[2] = @byteSwap(c +% 0x98badcfe);
    out[3] = @byteSwap(d +% 0x10325476);
}

const PatternResult = struct {
    triplet: ?u4 = null,
    quintuplets: u16 = 0,
};

inline fn extractPatterns(hash: [4]u32) PatternResult {
    var res = PatternResult{};
    var prev: u8 = 0xff;
    var count: u32 = 1;

    inline for (0..4) |w_idx| {
        var w = hash[w_idx];
        inline for (0..8) |_| {
            const nib: u4 = @truncate(w >> 28);
            w <<= 4;

            if (nib == prev) {
                count += 1;
            } else {
                count = 1;
                prev = nib;
            }

            if (count == 3 and res.triplet == null) {
                res.triplet = nib;
            }
            if (count == 5) {
                res.quintuplets |= @as(u16, 1) << nib;
            }
        }
    }
    return res;
}

const CandidateKey = struct {
    index: u32,
    char: u4,
};

const QuintupletEntry = struct {
    index: u32,
    mask: u16,
};

const KeyFinder = struct {
    salt: []const u8,
    is_stretched: bool,
    index_cursor: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),
    is_active: std.atomic.Value(bool) = std.atomic.Value(bool).init(true),

    candidates: std.ArrayListUnmanaged(CandidateKey) = .{},
    quintuplets: std.ArrayListUnmanaged(QuintupletEntry) = .{},
    confirmed_keys: std.AutoHashMapUnmanaged(u32, void) = .{},
    mutex: std.Thread.Mutex = .{},
    allocator: std.mem.Allocator,

    fn recordPattern(self: *KeyFinder, index: u32, pattern: PatternResult) void {
        if (pattern.triplet == null and pattern.quintuplets == 0) return;

        self.mutex.lock();
        defer self.mutex.unlock();

        if (pattern.triplet) |char| {
            self.candidates.append(self.allocator, .{ .index = index, .char = char }) catch {};
            const mask = @as(u16, 1) << char;
            for (self.quintuplets.items) |q| {
                if (q.index > index and q.index <= index + 1000 and (q.mask & mask) != 0) {
                    self.confirmed_keys.put(self.allocator, index, {}) catch {};
                    break;
                }
            }
        }

        if (pattern.quintuplets != 0) {
            self.quintuplets.append(self.allocator, .{ .index = index, .mask = pattern.quintuplets }) catch {};
            for (self.candidates.items) |c| {
                if (c.index + 1000 >= index and c.index < index) {
                    if ((pattern.quintuplets & (@as(u16, 1) << c.char)) != 0) {
                        self.confirmed_keys.put(self.allocator, c.index, {}) catch {};
                    }
                }
            }
        }

        if (self.confirmed_keys.count() >= 64) {
            self.is_active.store(false, .release);
        }
    }
};

fn finderWorker(finder: *KeyFinder) void {
    @setRuntimeSafety(false);
    var text_buf: [64]u8 = undefined;
    @memcpy(text_buf[0..finder.salt.len], finder.salt);

    const step: u32 = 64;

    if (!finder.is_stretched) {
        while (finder.is_active.load(.acquire)) {
            const start = finder.index_cursor.fetchAdd(step, .acq_rel);
            for (0..step) |offset| {
                const idx = start + @as(u32, @intCast(offset));
                const text = std.fmt.bufPrint(text_buf[finder.salt.len..], "{d}", .{idx}) catch unreachable;
                var h: [4]u32 = undefined;
                md5Scalar(text_buf[0 .. finder.salt.len + text.len], &h);
                finder.recordPattern(idx, extractPatterns(h));
            }
        }
    } else {
        while (finder.is_active.load(.acquire)) {
            const start = finder.index_cursor.fetchAdd(step, .acq_rel);
            var offset: u32 = 0;
            while (offset < step) : (offset += 8) {
                const base = start + offset;
                var lane_words: [4][8]u32 = undefined;

                inline for (0..8) |lane| {
                    const idx = base + @as(u32, @intCast(lane));
                    const text = std.fmt.bufPrint(text_buf[finder.salt.len..], "{d}", .{idx}) catch unreachable;
                    var h: [4]u32 = undefined;
                    md5Scalar(text_buf[0 .. finder.salt.len + text.len], &h);
                    lane_words[0][lane] = h[0];
                    lane_words[1][lane] = h[1];
                    lane_words[2][lane] = h[2];
                    lane_words[3][lane] = h[3];
                }

                var simd_vecs = [4]Vec{
                    lane_words[0],
                    lane_words[1],
                    lane_words[2],
                    lane_words[3],
                };

                for (0..2016) |_| {
                    stretchMd5Simd(&simd_vecs);
                }

                inline for (0..8) |lane| {
                    const idx = base + @as(u32, @intCast(lane));
                    const stretched = [4]u32{
                        simd_vecs[0][lane],
                        simd_vecs[1][lane],
                        simd_vecs[2][lane],
                        simd_vecs[3][lane],
                    };
                    finder.recordPattern(idx, extractPatterns(stretched));
                }
            }
        }
    }
}

fn solveKeypad(allocator: std.mem.Allocator, salt: []const u8, is_stretched: bool) !u32 {
    var finder = KeyFinder{
        .salt = salt,
        .is_stretched = is_stretched,
        .allocator = allocator,
    };
    defer finder.candidates.deinit(allocator);
    defer finder.quintuplets.deinit(allocator);
    defer finder.confirmed_keys.deinit(allocator);

    const cpus = std.Thread.getCpuCount() catch 4;
    const threads = try allocator.alloc(std.Thread, cpus);
    defer allocator.free(threads);

    for (threads) |*t| {
        t.* = try std.Thread.spawn(.{}, finderWorker, .{&finder});
    }
    for (threads) |t| {
        t.join();
    }

    var sorted_keys = try std.ArrayList(u32).initCapacity(allocator, finder.confirmed_keys.count());
    defer sorted_keys.deinit(allocator);

    var it = finder.confirmed_keys.keyIterator();
    while (it.next()) |k| {
        sorted_keys.appendAssumeCapacity(k.*);
    }
    std.mem.sort(u32, sorted_keys.items, {}, std.sort.asc(u32));

    return if (sorted_keys.items.len >= 64) sorted_keys.items[63] else 0;
}

pub fn main() !void {
    const raw = @embedFile("input.txt");
    const salt = std.mem.trim(u8, raw, "\r\n ");
    const allocator = std.heap.page_allocator;

    var timer = try std.time.Timer.start();
    const p1 = try solveKeypad(allocator, salt, false);
    const p2 = try solveKeypad(allocator, salt, true);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;

    std.debug.print("Part 1: {} | Part 2: {}\n", .{ p1, p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
