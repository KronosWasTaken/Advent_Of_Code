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

inline fn md5WordA(M: [16]Vec) Vec {
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

    return swapEndianVec(a +% @as(Vec, @splat(0x67452301)));
}

const SUFFIX_WORDS_PAD: [1000]u32 = blk: {
    var table: [1000]u32 = undefined;
    for (0..1000) |i| {
        const d0 = @as(u32, '0' + @as(u8, @intCast(i / 100)));
        const d1 = @as(u32, '0' + @as(u8, @intCast((i / 10) % 10)));
        const d2 = @as(u32, '0' + @as(u8, @intCast(i % 10)));
        table[i] = d0 | (d1 << 8) | (d2 << 16) | (0x80 << 24);
    }
    break :blk table;
};

const SUFFIX_WORDS_SHIFTED: [1000]u32 = blk: {
    var table: [1000]u32 = undefined;
    for (0..1000) |i| {
        const d0 = @as(u32, '0' + @as(u8, @intCast(i / 100)));
        const d1 = @as(u32, '0' + @as(u8, @intCast((i / 10) % 10)));
        const d2 = @as(u32, '0' + @as(u8, @intCast(i % 10)));
        table[i] = (d0 << 8) | (d1 << 16) | (d2 << 24);
    }
    break :blk table;
};

const InterestingHash = struct {
    index: u32,
    digest_word: u32,
};

const PasswordMiner = struct {
    salt: []const u8,
    counter: std.atomic.Value(u32) = std.atomic.Value(u32).init(1000),
    is_active: std.atomic.Value(bool) = std.atomic.Value(bool).init(true),
    matches: std.ArrayListUnmanaged(InterestingHash) = .{},
    positions_seen: u8 = 0,
    lock: std.Thread.Mutex = .{},
    allocator: std.mem.Allocator,

    fn recordMatch(self: *PasswordMiner, index: u32, word: u32) void {
        if ((word & 0xfffff000) != 0) return;

        self.lock.lock();
        defer self.lock.unlock();

        self.matches.append(self.allocator, .{
            .index = index,
            .digest_word = word,
        }) catch {};

        const pos = @as(u4, @truncate(word >> 8));
        if (pos < 8) {
            self.positions_seen |= @as(u8, 1) << @as(u3, @truncate(pos));
            if (self.positions_seen == 0xff and self.matches.items.len >= 8) {
                self.is_active.store(false, .release);
            }
        }
    }
};

fn miningWorker(miner: *PasswordMiner) void {
    @setRuntimeSafety(false);
    const m0: Vec = @splat(std.mem.readInt(u32, miner.salt[0..4], .little));
    const m1: Vec = @splat(std.mem.readInt(u32, miner.salt[4..8], .little));
    const zero: Vec = @splat(0);

    while (miner.is_active.load(.acquire)) {
        const base_index = miner.counter.fetchAdd(1000, .monotonic);

        var num_buf: [32]u8 = undefined;
        const formatted = std.fmt.bufPrint(&num_buf, "{s}{d}", .{ miner.salt, base_index }) catch continue;

        var M: [16]Vec = [_]Vec{zero} ** 16;
        M[0] = m0;
        M[1] = m1;
        M[2] = @splat(std.mem.readInt(u32, formatted[8..12], .little));

        if (formatted.len == 15) {
            M[14] = @splat(15 * 8);
            var offset: u32 = 0;
            while (offset < 1000) : (offset += 8) {
                M[3] = SUFFIX_WORDS_PAD[offset..][0..8].*;
                const res = md5WordA(M);
                const mask = (res & @as(Vec, @splat(0xfffff000))) == zero;

                if (@reduce(.Or, mask)) {
                    inline for (0..8) |i| {
                        if (mask[i]) {
                            miner.recordMatch(base_index + offset + @as(u32, @intCast(i)), res[i]);
                        }
                    }
                }
            }
        } else if (formatted.len == 16) {
            M[4] = @splat(0x80);
            M[14] = @splat(16 * 8);
            const prefix_char: Vec = @splat(@as(u32, formatted[12]));
            var offset: u32 = 0;
            while (offset < 1000) : (offset += 8) {
                M[3] = SUFFIX_WORDS_SHIFTED[offset..][0..8].* | prefix_char;
                const res = md5WordA(M);
                const mask = (res & @as(Vec, @splat(0xfffff000))) == zero;

                if (@reduce(.Or, mask)) {
                    inline for (0..8) |i| {
                        if (mask[i]) {
                            miner.recordMatch(base_index + offset + @as(u32, @intCast(i)), res[i]);
                        }
                    }
                }
            }
        }
    }
}

inline fn toHexChar(val: u4) u8 {
    const chars = "0123456789abcdef";
    return chars[val];
}

pub fn main() !void {
    const raw = @embedFile("input.txt");
    const salt = std.mem.trim(u8, raw, " \t\r\n.");
    const allocator = std.heap.page_allocator;

    var timer = try std.time.Timer.start();
    var miner = PasswordMiner{
        .salt = salt,
        .allocator = allocator,
    };
    defer miner.matches.deinit(allocator);

    const cpus = std.Thread.getCpuCount() catch 4;
    const threads = try allocator.alloc(std.Thread, cpus);
    defer allocator.free(threads);

    for (threads) |*t| {
        t.* = try std.Thread.spawn(.{}, miningWorker, .{&miner});
    }
    for (threads) |t| {
        t.join();
    }

    const cmp = struct {
        fn lessThan(_: void, a: InterestingHash, b: InterestingHash) bool {
            return a.index < b.index;
        }
    }.lessThan;
    std.mem.sort(InterestingHash, miner.matches.items, {}, cmp);

    var pass1: [8]u8 = undefined;
    for (0..8) |i| {
        pass1[i] = toHexChar(@as(u4, @truncate(miner.matches.items[i].digest_word >> 8)));
    }

    var pass2 = [_]u8{0} ** 8;
    var filled_count: usize = 0;
    for (miner.matches.items) |item| {
        const pos = @as(u4, @truncate(item.digest_word >> 8));
        if (pos < 8 and pass2[pos] == 0) {
            pass2[pos] = toHexChar(@as(u4, @truncate(item.digest_word >> 4)));
            filled_count += 1;
            if (filled_count == 8) break;
        }
    }

    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;
    std.debug.print("Part 1: {s} | Part 2: {s}\n", .{ pass1, pass2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
