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

const Exclusive = struct {
    threes: std.ArrayListUnmanaged(u32),
    fives: std.ArrayListUnmanaged(u32),
    found: std.AutoHashMapUnmanaged(usize, void),
};

const Shared = struct {
    input: []const u8,
    part_two: bool,
    iter: AtomicIter,
    mutex: std.Thread.Mutex,
    exclusive: Exclusive,
    allocator: std.mem.Allocator,
};

const AtomicIter = struct {
    next_index: std.atomic.Value(usize),
    step: usize,
    stop_flag: std.atomic.Value(bool),

    fn init(start: usize, step: usize) AtomicIter {
        return .{
            .next_index = std.atomic.Value(usize).init(start),
            .step = step,
            .stop_flag = std.atomic.Value(bool).init(false),
        };
    }

    fn next(self: *AtomicIter) ?usize {
        if (self.stop_flag.load(.acquire)) {
            return null;
        }
        return self.next_index.fetchAdd(self.step, .acq_rel);
    }

    fn stop(self: *AtomicIter) void {
        self.stop_flag.store(true, .release);
    }
};

fn solve(allocator: std.mem.Allocator, salt: []const u8) !Result {
    const p1 = try generatePad(allocator, salt, false);
    const p2 = try generatePad(allocator, salt, true);
    return .{ .p1 = p1, .p2 = p2 };
}

fn generatePad(allocator: std.mem.Allocator, salt: []const u8, part_two: bool) !usize {
    var shared = Shared{
        .input = salt,
        .part_two = part_two,
        .iter = AtomicIter.init(0, 1),
        .mutex = .{},
        .exclusive = .{
            .threes = .{},
            .fives = .{},
            .found = .{},
        },
        .allocator = allocator,
    };
    defer shared.exclusive.threes.deinit(allocator);
    defer shared.exclusive.fives.deinit(allocator);
    defer shared.exclusive.found.deinit(allocator);

    const thread_count = std.Thread.getCpuCount() catch 4;
    const threads = try allocator.alloc(std.Thread, thread_count);
    defer allocator.free(threads);

    for (threads) |*t| {
        t.* = try std.Thread.spawn(.{}, worker, .{&shared});
    }
    for (threads) |t| {
        t.join();
    }

    return extract64th(allocator, &shared.exclusive.found);
}

fn extract64th(allocator: std.mem.Allocator, found: *std.AutoHashMapUnmanaged(usize, void)) !usize {
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

fn ensureLen(list: *std.ArrayListUnmanaged(u32), allocator: std.mem.Allocator, len: usize) void {
    if (list.items.len >= len) {
        return;
    }
    const old_len = list.items.len;
    list.resize(allocator, len) catch @panic("oom");
    @memset(list.items[old_len..], 0);
}

fn worker(shared: *Shared) void {
    @setRuntimeSafety(false);
    var buf: [64]u8 = undefined;
    @memcpy(buf[0..shared.input.len], shared.input);

    while (shared.iter.next()) |n_raw| {
        const n: i32 = @intCast(n_raw);
        const msg_len = shared.input.len + formatInt(buf[shared.input.len..], @intCast(n));
        var hash: [4]u32 = undefined;
        md5SingleBlock(buf[0..msg_len], &hash);

        if (shared.part_two) {
            var buffer = [_]u8{0} ** 64;
            for (0..2016) |_| {
                @memcpy(buffer[0..8], &to_ascii(hash[0]));
                @memcpy(buffer[8..16], &to_ascii(hash[1]));
                @memcpy(buffer[16..24], &to_ascii(hash[2]));
                @memcpy(buffer[24..32], &to_ascii(hash[3]));
                md5SingleBlock(buffer[0..32], &hash);
            }
        }

        check(shared, n, hash);
    }
}

fn check(shared: *Shared, n: i32, hash: [4]u32) void {
    const a = hash[0];
    const b = hash[1];
    const c = hash[2];
    const d = hash[3];

    var prev: u32 = std.math.maxInt(u32);
    var same: u32 = 1;
    var three: u32 = 0;
    var five: u32 = 0;

    for ([_]u32{ d, c, b, a }) |word| {
        var value = word;
        var i: usize = 0;
        while (i < 8) : (i += 1) {
            const next = value & 0xF;
            if (next == prev) {
                same += 1;
            } else {
                same = 1;
            }
            if (same == 3) {
                three = @as(u32, 1) << @intCast(next);
            }
            if (same == 5) {
                five |= @as(u32, 1) << @intCast(next);
            }
            value >>= 4;
            prev = next;
        }
    }

    if (three == 0 and five == 0) {
        return;
    }

    shared.mutex.lock();
    defer shared.mutex.unlock();

    if (three != 0) {
        const idx = @as(usize, @intCast(n));
        ensureLen(&shared.exclusive.threes, shared.allocator, idx + 1);
        shared.exclusive.threes.items[idx] = three;

        const end = @min(idx + 1001, shared.exclusive.fives.items.len);
        var scan = idx + 1;
        while (scan < end) : (scan += 1) {
            if (three & shared.exclusive.fives.items[scan] != 0) {
                shared.exclusive.found.put(shared.allocator, idx, {}) catch {};
                break;
            }
        }
    }

    if (five != 0) {
        const idx = @as(usize, @intCast(n));
        ensureLen(&shared.exclusive.fives, shared.allocator, idx + 1);
        shared.exclusive.fives.items[idx] = five;
        ensureLen(&shared.exclusive.threes, shared.allocator, idx + 1);

        const start = if (idx > 1000) idx - 1000 else 0;
        var scan = start;
        while (scan < idx) : (scan += 1) {
            if (five & shared.exclusive.threes.items[scan] != 0) {
                shared.exclusive.found.put(shared.allocator, scan, {}) catch {};
            }
        }
    }

    if (shared.exclusive.found.count() >= 64) {
        shared.iter.stop();
    }
}

fn md5SingleBlock(msg: []const u8, out: *[4]u32) void {
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
        M[i] = std.mem.readInt(u32, block[i * 4 ..][0..4], .little);
    }
    const S = [64]u32{ 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21 };
    const K = [64]u32{ 0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501, 0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821, 0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8, 0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed, 0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a, 0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70, 0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665, 0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1, 0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391 };
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
        a = d;
        d = c;
        c = b;
        b = b +% std.math.rotl(u32, F, S[round]);
    }
    out[0] = @byteSwap(a +% 0x67452301);
    out[1] = @byteSwap(b +% 0xefcdab89);
    out[2] = @byteSwap(c +% 0x98badcfe);
    out[3] = @byteSwap(d +% 0x10325476);
}

inline fn to_ascii(n: u32) [8]u8 {
    var value = @as(u64, n);
    value = ((value << 16) & 0x0000ffff00000000) | (value & 0x000000000000ffff);
    value = ((value << 8) & 0x00ff000000ff0000) | (value & 0x000000ff000000ff);
    value = ((value << 4) & 0x0f000f000f000f00) | (value & 0x000f000f000f000f);
    const mask = ((value + 0x0606060606060606) >> 4) & 0x0101010101010101;
    value = value + 0x3030303030303030 + 0x27 * mask;
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..], value, .big);
    return bytes;
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
