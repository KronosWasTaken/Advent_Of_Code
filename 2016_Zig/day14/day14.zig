const std = @import("std");

const Result = struct { p1: usize, p2: usize };
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const salt = "yjdafjpo";
    var timer = try std.time.Timer.start();
    const result = try solve(allocator, salt);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
const Entry = struct {
    first_triplet: ?u8,
    quintuplets: u16,
};
fn solve(allocator: std.mem.Allocator, salt: []const u8) !Result {
    const MAX_INDEX = 40000;
    const p1_entries = try allocator.alloc(Entry, MAX_INDEX);
    defer allocator.free(p1_entries);

    {
        const thread_count = std.Thread.getCpuCount() catch 4;
        const threads = try allocator.alloc(std.Thread, thread_count);
        defer allocator.free(threads);
        const block_size = MAX_INDEX / thread_count;
        for (threads, 0..) |*t, i| {
            const start = i * block_size;
            const end = if (i == thread_count - 1) MAX_INDEX else (i + 1) * block_size;
            t.* = try std.Thread.spawn(.{}, worker, .{ salt, start, end, p1_entries, false });
        }
        for (threads) |t| t.join();
    }
    const p1 = try find64Keys(allocator, p1_entries, MAX_INDEX);

    const p2_entries = try allocator.alloc(Entry, MAX_INDEX);
    defer allocator.free(p2_entries);
    {
        const thread_count = std.Thread.getCpuCount() catch 4;
        const threads = try allocator.alloc(std.Thread, thread_count);
        defer allocator.free(threads);
        const block_size = MAX_INDEX / thread_count;
        for (threads, 0..) |*t, i| {
            const start = i * block_size;
            const end = if (i == thread_count - 1) MAX_INDEX else (i + 1) * block_size;
            t.* = try std.Thread.spawn(.{}, worker, .{ salt, start, end, p2_entries, true });
        }
        for (threads) |t| t.join();
    }
    const p2 = try find64Keys(allocator, p2_entries, MAX_INDEX);
    return .{ .p1 = p1, .p2 = p2 };
}
fn worker(salt: []const u8, start: usize, end: usize, entries: []Entry, stretch: bool) void {
    @setRuntimeSafety(false);
    var buf: [64]u8 = undefined;
    @memcpy(buf[0..salt.len], salt);
    for (start..end) |idx| {
        const msg_len = salt.len + formatInt(buf[salt.len..], @intCast(idx));
        var hash: [16]u8 = undefined;
        md5SingleBlock(buf[0..msg_len], &hash);
        var hex: [32]u8 = undefined;
        toHexStr(&hash, &hex);
        if (stretch) {
            for (0..2016) |_| {
                md5SingleBlock(&hex, &hash);
                toHexStr(&hash, &hex);
            }
        }
        entries[idx] = analyzeHash(&hex);
    }
}
fn find64Keys(allocator: std.mem.Allocator, entries: []Entry, max: usize) !usize {
    var found = std.AutoHashMap(usize, void).init(allocator);
    defer found.deinit();
    for (0..max) |i| {
        if (entries[i].first_triplet) |c| {
            const range_end = @min(i + 1001, max);
            const mask = @as(u16, 1) << @intCast(c);
            for (i + 1..range_end) |j| {
                if (entries[j].quintuplets & mask != 0) {
                    try found.put(i, {});
                    break;
                }
            }
        }
    }
    var keys = std.ArrayListUnmanaged(usize){};
    defer keys.deinit(allocator);
    var it = found.keyIterator();
    while (it.next()) |key| {
        try keys.append(allocator, key.*);
    }
    std.mem.sort(usize, keys.items, {}, std.sort.asc(usize));
    if (keys.items.len >= 64) {
        return keys.items[63];
    }
    return 0;
}
fn analyzeHash(hex: *const [32]u8) Entry {
    @setRuntimeSafety(false);
    var first_triplet: ?u8 = null;
    var quintuplets: u16 = 0;
    var i: usize = 0;
    while (i < 30) : (i += 1) {
        const c = hex[i];
        if (hex[i + 1] == c and hex[i + 2] == c) {
            if (first_triplet == null) {
                const val: u8 = if (c >= 'a') c - 'a' + 10 else c - '0';
                first_triplet = val;
            }
            if (i < 28 and hex[i + 3] == c and hex[i + 4] == c) {
                const val: u8 = if (c >= 'a') c - 'a' + 10 else c - '0';
                quintuplets |= (@as(u16, 1) << @intCast(val));
            }
        }
    }
    return .{ .first_triplet = first_triplet, .quintuplets = quintuplets };
}
fn md5SingleBlock(msg: []const u8, out: *[16]u8) void {
    @setRuntimeSafety(false);
    var block: [64]u8 = [_]u8{0} ** 64;
    @memcpy(block[0..msg.len], msg);
    block[msg.len] = 0x80;
    const bit_len = msg.len * 8;
    block[56] = @intCast(bit_len & 0xFF);
    block[57] = @intCast((bit_len >> 8) & 0xFF);
    block[58] = @intCast((bit_len >> 16) & 0xFF);
    block[59] = @intCast((bit_len >> 24) & 0xFF);
    var M: [16]u32 = undefined;
    for (0..16) |i| {
        M[i] = std.mem.readInt(u32, block[i*4..][0..4], .little);
    }
    const S = [64]u32{7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21};
    const K = [64]u32{0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501, 0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821, 0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8, 0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed, 0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a, 0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70, 0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665, 0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1, 0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391};
    var a: u32 = 0x67452301;
    var b: u32 = 0xefcdab89;
    var c: u32 = 0x98badcfe;
    var d: u32 = 0x10325476;
    inline for (0..64) |round| {
        var F: u32 = undefined;
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
        F = F +% a +% K[round] +% M[g];
        a = d; d = c; c = b;
        b = b +% std.math.rotl(u32, F, S[round]);
    }
    a +%= 0x67452301;
    b +%= 0xefcdab89;
    c +%= 0x98badcfe;
    d +%= 0x10325476;
    std.mem.writeInt(u32, out[0..4], a, .little);
    std.mem.writeInt(u32, out[4..8], b, .little);
    std.mem.writeInt(u32, out[8..12], c, .little);
    std.mem.writeInt(u32, out[12..16], d, .little);
}
inline fn toHexStr(hash: *const [16]u8, out: *[32]u8) void {
    const table = "0123456789abcdef";
    @setRuntimeSafety(false);
    for (0..16) |i| {
        out[i * 2] = table[hash[i] >> 4];
        out[i * 2 + 1] = table[hash[i] & 0xF];
    }
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
