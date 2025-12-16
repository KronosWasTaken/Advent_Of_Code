const std = @import("std");

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
const ResultItem = struct { idx: u32, hash: [16]u8 };
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const cwd = std.fs.cwd();
    const file_content = try cwd.readFileAlloc(allocator, "input.txt", 1024);
    defer allocator.free(file_content);
    var prefix = std.mem.trim(u8, file_content, " \t\r\n.");
    if (std.mem.lastIndexOf(u8, prefix, " ")) |idx| {
        prefix = prefix[idx + 1 ..];
    }
    prefix = std.mem.trim(u8, prefix, " \t");
    var timer = try std.time.Timer.start();
    var found = std.ArrayListUnmanaged(ResultItem){};
    defer found.deinit(allocator);
    var mutex = std.Thread.Mutex{};
    var should_stop = std.atomic.Value(bool).init(false);
    var next_block = std.atomic.Value(u32).init(0);
    var mask = std.atomic.Value(u16).init(0);
    const thread_count = std.Thread.getCpuCount() catch 4;
    const threads = try allocator.alloc(std.Thread, thread_count);
    defer allocator.free(threads);
    const Context = struct {
        prefix: []const u8,
        found: *std.ArrayListUnmanaged(ResultItem),
        allocator: std.mem.Allocator,
        mutex: *std.Thread.Mutex,
        should_stop: *std.atomic.Value(bool),
        next_block: *std.atomic.Value(u32),
        mask: *std.atomic.Value(u16),
    };
    const ctx = Context{
        .prefix = prefix,
        .found = &found,
        .allocator = allocator,
        .mutex = &mutex,
        .should_stop = &should_stop,
        .next_block = &next_block,
        .mask = &mask,
    };
    for (threads) |*t| {
        t.* = try std.Thread.spawn(.{}, worker, .{&ctx});
    }
    for (threads) |t| {
        t.join();
    }
    const sort = struct {
        fn lessThan(_: void, a: ResultItem, b: ResultItem) bool {
            return a.idx < b.idx;
        }
    };
    std.mem.sort(ResultItem, found.items, {}, sort.lessThan);
    var p1_str = [_]u8{' '} ** 8;
    for (0..8) |i| {
        if (i < found.items.len) {
            p1_str[i] = toHex(found.items[i].hash[2]);
        }
    }
    var p2_str = [_]u8{0} ** 8;
    var p2_filled = [_]bool{false} ** 8;
    for (found.items) |item| {
        const sixth = item.hash[2];
        if (sixth < 8) {
            if (!p2_filled[sixth]) {
                p2_filled[sixth] = true;
                const seventh = item.hash[3] >> 4;
                p2_str[sixth] = toHex(seventh);
            }
        }
    }
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;
    std.debug.print("Part 1: {s} | Part 2: {s}\n", .{ p1_str, p2_str });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
fn worker(ctx: *const anyopaque) void {
    const Context = struct {
        prefix: []const u8,
        found: *std.ArrayListUnmanaged(ResultItem),
        allocator: std.mem.Allocator,
        mutex: *std.Thread.Mutex,
        should_stop: *std.atomic.Value(bool),
        next_block: *std.atomic.Value(u32),
        mask: *std.atomic.Value(u16),
    };
    const context: *const Context = @ptrCast(@alignCast(ctx));
    const prefix_len = context.prefix.len;
    while (!context.should_stop.load(.monotonic)) {
        const start = context.next_block.fetchAdd(1000, .monotonic);

        if (start < 1000) {
            var buf: [64]u8 = undefined;
            @memcpy(buf[0..prefix_len], context.prefix);
            for (0..1000) |i| {
                const idx = @as(u32, @intCast(i));
                const msg_len = prefix_len + formatInt(buf[prefix_len..], idx);
                var hash: [16]u8 = undefined;
                md5SingleBlock(buf[0..msg_len], &hash);
                checkHash(idx, &hash, context);
            }
            continue;
        }

        var buffers: [SIMD_WIDTH][64]u8 align(64) = undefined;

        inline for (0..SIMD_WIDTH) |i| {
            @memcpy(buffers[i][0..prefix_len], context.prefix);
        }

        var base_buf: [64]u8 = undefined;
        @memcpy(base_buf[0..prefix_len], context.prefix);
        const base_len = prefix_len + formatInt(base_buf[prefix_len..], start);
        var offset: u32 = 0;
        while (offset < 1000) : (offset += SIMD_WIDTH) {

            inline for (0..SIMD_WIDTH) |i| {
                const n = offset + @as(u32, @intCast(i));
                @memcpy(buffers[i][0..base_len], base_buf[0..base_len]);
                buffers[i][base_len - 3] = '0' + @as(u8, @intCast(n / 100));
                buffers[i][base_len - 2] = '0' + @as(u8, @intCast((n / 10) % 10));
                buffers[i][base_len - 1] = '0' + @as(u8, @intCast(n % 10));

                buffers[i][base_len] = 0x80;
                @memset(buffers[i][base_len + 1..56], 0);
                const bit_len = base_len * 8;
                buffers[i][56] = @intCast(bit_len & 0xFF);
                buffers[i][57] = @intCast((bit_len >> 8) & 0xFF);
                buffers[i][58] = @intCast((bit_len >> 16) & 0xFF);
                buffers[i][59] = @intCast((bit_len >> 24) & 0xFF);
                @memset(buffers[i][60..64], 0);
            }

            const hashes = md5TransformVec(&buffers, base_len);

            inline for (0..SIMD_WIDTH) |i| {
                const idx = start + offset + @as(u32, @intCast(i));
                if (offset + @as(u32, @intCast(i)) >= 1000) break;
                var hash: [16]u8 = undefined;
                std.mem.writeInt(u32, hash[0..4], hashes[0][i], .little);
                std.mem.writeInt(u32, hash[4..8], hashes[1][i], .little);
                std.mem.writeInt(u32, hash[8..12], hashes[2][i], .little);
                std.mem.writeInt(u32, hash[12..16], hashes[3][i], .little);
                checkHash(idx, &hash, context);
            }
        }
    }
}
inline fn rotateLeftVec(x: Vec, n: u32) Vec {
    const shift: @Vector(SIMD_WIDTH, u5) = @splat(@intCast(n));
    const inv_shift: @Vector(SIMD_WIDTH, u5) = @splat(@intCast(32 - n));
    return (x << shift) | (x >> inv_shift);
}
fn md5TransformVec(buffers: *const [SIMD_WIDTH][64]u8, _: usize) [4]Vec {
    @setRuntimeSafety(false);
    var M: [16]Vec = undefined;

    inline for (0..16) |j| {
        var lane_vals: [SIMD_WIDTH]u32 = undefined;
        inline for (0..SIMD_WIDTH) |i| {
            lane_vals[i] = std.mem.readInt(u32, buffers[i][j*4..][0..4], .little);
        }
        M[j] = lane_vals;
    }
    var a: Vec = @splat(0x67452301);
    var b: Vec = @splat(0xefcdab89);
    var c: Vec = @splat(0x98badcfe);
    var d: Vec = @splat(0x10325476);

    inline for (0..16) |i| {
        const f = (b & c) | ((~b) & d);
        const k_vec: Vec = @splat(K[i]);
        const temp = a +% f +% k_vec +% M[i];
        a = d;
        d = c;
        c = b;
        b = b +% rotateLeftVec(temp, S[i]);
    }

    inline for (0..16) |i| {
        const g_idx = [16]usize{ 1, 6, 11, 0, 5, 10, 15, 4, 9, 14, 3, 8, 13, 2, 7, 12 };
        const g = (d & b) | ((~d) & c);
        const k_vec: Vec = @splat(K[16 + i]);
        const temp = a +% g +% k_vec +% M[g_idx[i]];
        a = d;
        d = c;
        c = b;
        b = b +% rotateLeftVec(temp, S[16 + i]);
    }

    inline for (0..16) |i| {
        const h_idx = [16]usize{ 5, 8, 11, 14, 1, 4, 7, 10, 13, 0, 3, 6, 9, 12, 15, 2 };
        const h = b ^ c ^ d;
        const k_vec: Vec = @splat(K[32 + i]);
        const temp = a +% h +% k_vec +% M[h_idx[i]];
        a = d;
        d = c;
        c = b;
        b = b +% rotateLeftVec(temp, S[32 + i]);
    }

    inline for (0..16) |i| {
        const i_idx = [16]usize{ 0, 7, 14, 5, 12, 3, 10, 1, 8, 15, 6, 13, 4, 11, 2, 9 };
        const ii = c ^ (b | (~d));
        const k_vec: Vec = @splat(K[48 + i]);
        const temp = a +% ii +% k_vec +% M[i_idx[i]];
        a = d;
        d = c;
        c = b;
        b = b +% rotateLeftVec(temp, S[48 + i]);
    }
    return .{
        a +% @as(Vec, @splat(0x67452301)),
        b +% @as(Vec, @splat(0xefcdab89)),
        c +% @as(Vec, @splat(0x98badcfe)),
        d +% @as(Vec, @splat(0x10325476)),
    };
}
fn md5SingleBlock(msg: []const u8, out: *[16]u8) void {
    @setRuntimeSafety(false);
    var block: [64]u8 align(16) = [_]u8{0} ** 64;
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
    var a: u32 = 0x67452301;
    var b: u32 = 0xefcdab89;
    var c: u32 = 0x98badcfe;
    var d: u32 = 0x10325476;

    inline for (0..16) |i| {
        const f = (b & c) | ((~b) & d);
        const temp = a +% f +% K[i] +% M[i];
        a = d;
        d = c;
        c = b;
        b = b +% std.math.rotl(u32, temp, S[i]);
    }

    inline for (0..16) |i| {
        const g_idx = [16]usize{ 1, 6, 11, 0, 5, 10, 15, 4, 9, 14, 3, 8, 13, 2, 7, 12 };
        const g = (d & b) | ((~d) & c);
        const temp = a +% g +% K[16 + i] +% M[g_idx[i]];
        a = d;
        d = c;
        c = b;
        b = b +% std.math.rotl(u32, temp, S[16 + i]);
    }

    inline for (0..16) |i| {
        const h_idx = [16]usize{ 5, 8, 11, 14, 1, 4, 7, 10, 13, 0, 3, 6, 9, 12, 15, 2 };
        const h = b ^ c ^ d;
        const temp = a +% h +% K[32 + i] +% M[h_idx[i]];
        a = d;
        d = c;
        c = b;
        b = b +% std.math.rotl(u32, temp, S[32 + i]);
    }

    inline for (0..16) |i| {
        const i_idx = [16]usize{ 0, 7, 14, 5, 12, 3, 10, 1, 8, 15, 6, 13, 4, 11, 2, 9 };
        const ii = c ^ (b | (~d));
        const temp = a +% ii +% K[48 + i] +% M[i_idx[i]];
        a = d;
        d = c;
        c = b;
        b = b +% std.math.rotl(u32, temp, S[48 + i]);
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
inline fn checkHash(idx: u32, hash: *const [16]u8, context: anytype) void {
    if (hash[0] == 0 and hash[1] == 0 and (hash[2] & 0xF0) == 0) {
        context.mutex.lock();
        context.found.append(context.allocator, .{ .idx = idx, .hash = hash.* }) catch {};
        const sixth = hash[2];
        if (sixth < 8) {
            const prev = context.mask.fetchOr(@as(u16, 1) << @intCast(sixth), .monotonic);
            const new_mask = prev | (@as(u16, 1) << @intCast(sixth));
            if ((new_mask & 0xff) == 0xff) {
                context.should_stop.store(true, .release);
            }
        }
        context.mutex.unlock();
    }
}
fn toHex(val: u8) u8 {
    return if (val < 10) '0' + val else 'a' + (val - 10);
}
