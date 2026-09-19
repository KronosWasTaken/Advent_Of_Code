const std = @import("std");

const MOD: u64 = 0x7fffffff;
const FACTOR_A: u64 = 16807;
const FACTOR_B: u64 = 48271;
const BLOCK_SIZE: usize = 50_000;
const TOTAL_BLOCKS: usize = 805;
const PART_ONE: usize = 40_000_000;
const PART_TWO: usize = 5_000_000;

inline fn generate(x: u64, factor: u64) u64 {
    const p = x *% factor;
    const s = (p >> 31) + (p & MOD);
    return ((s >> 31) + s) & MOD;
}

fn modPow(base: u64, exp: u64, mod: u64) u64 {
    _ = mod;
    if (exp == 0) {
        return 1;
    }
    var result: u64 = 1;
    var b = base & MOD;
    var e = exp;
    while (e > 0) {
        if ((e & 1) == 1) {
            result = generate(result, b);
        }
        b = generate(b, b);
        e >>= 1;
    }
    return result;
}

const BlockResult = struct {
    done: std.atomic.Value(bool),
    ones: u32,
    fours_len: u32,
    eights_len: u32,
    fours: [13000]u16,
    eights: [6500]u16,
};

const SharedContext = struct {
    start_a: u64,
    start_b: u64,
    next_block: std.atomic.Value(usize),
    blocks: []BlockResult,
};

fn worker(shared: *SharedContext) void {
    @setRuntimeSafety(false);
    while (true) {
        const block_idx = shared.next_block.fetchAdd(1, .monotonic);
        if (block_idx >= TOTAL_BLOCKS) {
            break;
        }

        const offset = @as(u64, @intCast(block_idx)) * BLOCK_SIZE;
        var a = generate(shared.start_a, modPow(FACTOR_A, offset, MOD));
        var b = generate(shared.start_b, modPow(FACTOR_B, offset, MOD));

        var ones: u32 = 0;
        var fours_count: u32 = 0;
        var eights_count: u32 = 0;
        const res = &shared.blocks[block_idx];

        if (block_idx < 800) {
            var i: usize = 0;
            while (i < BLOCK_SIZE) : (i += 1) {
                a = generate(a, FACTOR_A);
                b = generate(b, FACTOR_B);

                const low_a: u16 = @truncate(a);
                const low_b: u16 = @truncate(b);

                if (low_a == low_b) {
                    ones += 1;
                }
                if ((low_a & 3) == 0) {
                    res.fours[fours_count] = low_a;
                    fours_count += 1;
                }
                if ((low_b & 7) == 0) {
                    res.eights[eights_count] = low_b;
                    eights_count += 1;
                }
            }
        } else {
            var i: usize = 0;
            while (i < BLOCK_SIZE) : (i += 1) {
                a = generate(a, FACTOR_A);
                b = generate(b, FACTOR_B);

                const low_a: u16 = @truncate(a);
                const low_b: u16 = @truncate(b);

                if ((low_a & 3) == 0) {
                    res.fours[fours_count] = low_a;
                    fours_count += 1;
                }
                if ((low_b & 7) == 0) {
                    res.eights[eights_count] = low_b;
                    eights_count += 1;
                }
            }
        }

        res.ones = ones;
        res.fours_len = fours_count;
        res.eights_len = eights_count;
        res.done.store(true, .release);
    }
}

fn solve(allocator: std.mem.Allocator, start_a: u64, start_b: u64) !struct { p1: u32, p2: u32 } {
    const blocks = try allocator.alloc(BlockResult, TOTAL_BLOCKS);
    defer allocator.free(blocks);

    for (blocks) |*blk| {
        blk.done = std.atomic.Value(bool).init(false);
    }

    var shared = SharedContext{
        .start_a = start_a,
        .start_b = start_b,
        .next_block = std.atomic.Value(usize).init(0),
        .blocks = blocks,
    };

    const cpu_count = std.Thread.getCpuCount() catch 4;
    const threads = try allocator.alloc(std.Thread, cpu_count);
    defer allocator.free(threads);

    for (threads) |*thread| {
        thread.* = try std.Thread.spawn(.{}, worker, .{&shared});
    }

    var p1: u32 = 0;
    var p2: u32 = 0;

    const fours = try allocator.alloc(u16, PART_TWO + 1000);
    defer allocator.free(fours);
    const eights = try allocator.alloc(u16, PART_TWO + 1000);
    defer allocator.free(eights);

    var total_fours: usize = 0;
    var total_eights: usize = 0;
    var checked_pairs: usize = 0;

    for (0..TOTAL_BLOCKS) |idx| {
        while (!shared.blocks[idx].done.load(.acquire)) {
            std.atomic.spinLoopHint();
        }
        const res = &shared.blocks[idx];
        p1 += res.ones;

        if (total_fours < PART_TWO) {
            const copy_len = @min(res.fours_len, PART_TWO - total_fours);
            @memcpy(fours[total_fours .. total_fours + copy_len], res.fours[0..copy_len]);
            total_fours += copy_len;
        }

        if (total_eights < PART_TWO) {
            const copy_len = @min(res.eights_len, PART_TWO - total_eights);
            @memcpy(eights[total_eights .. total_eights + copy_len], res.eights[0..copy_len]);
            total_eights += copy_len;
        }

        const available = @min(total_fours, total_eights);
        while (checked_pairs < available) : (checked_pairs += 1) {
            if (fours[checked_pairs] == eights[checked_pairs]) {
                p2 += 1;
            }
        }
    }

    for (threads) |thread| {
        thread.join();
    }

    return .{ .p1 = p1, .p2 = p2 };
}

fn parseStartingValues(input: []const u8) struct { a: u64, b: u64 } {
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    const line_a = lines.next() orelse "";
    const line_b = lines.next() orelse "";

    var tokens_a = std.mem.tokenizeAny(u8, line_a, " ");
    _ = tokens_a.next();
    _ = tokens_a.next();
    _ = tokens_a.next();
    _ = tokens_a.next();
    const start_a = std.fmt.parseInt(u64, tokens_a.next() orelse "0", 10) catch 0;

    var tokens_b = std.mem.tokenizeAny(u8, line_b, " ");
    _ = tokens_b.next();
    _ = tokens_b.next();
    _ = tokens_b.next();
    _ = tokens_b.next();
    const start_b = std.fmt.parseInt(u64, tokens_b.next() orelse "0", 10) catch 0;

    return .{
        .a = start_a,
        .b = start_b,
    };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    const starts = parseStartingValues(input);
    const allocator = std.heap.page_allocator;

    var timer = try std.time.Timer.start();
    const res = try solve(allocator, starts.a, starts.b);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;

    std.debug.print("Part 1: {} | Part 2: {}\n", .{ res.p1, res.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
