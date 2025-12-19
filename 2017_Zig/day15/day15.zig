const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
const MOD: u64 = 0x7fffffff;
const FACTOR_A: u64 = 16807;
const FACTOR_B: u64 = 48271;
const BLOCK_SIZE: u32 = 50000;
const PART_ONE: u32 = 40_000_000;
const PART_TWO: u32 = 5_000_000;
inline fn fastMod(n: u64) u64 {
    const low = n & MOD;
    const high = n >> 31;
    const sum = low + high;
    return if (sum < MOD) sum else sum - MOD;
}
fn modPow(base: u64, exp: u64, mod: u64) u64 {
    if (exp == 0) return 1;
    var result: u64 = 1;
    var b = base % mod;
    var e = exp;
    while (e > 0) {
        if (e & 1 == 1) {
            result = fastMod(result *% b);
        }
        b = fastMod(b *% b);
        e >>= 1;
    }
    return result;
}
const Block = struct {
    start: u32,
    ones: u32,
    fours: std.ArrayList(u16),
    eights: std.ArrayList(u16),
};
const WorkerData = struct {
    start_a: u64,
    start_b: u64,
    block_idx: u32,
    allocator: std.mem.Allocator,
    result: ?Block,
};
fn blockWorker(data: *WorkerData) void {
    const gpa = data.allocator;
    var a = data.start_a;
    var b = data.start_b;
    var ones: u32 = 0;
    var fours: std.ArrayList(u16) = .{};
    var eights: std.ArrayList(u16) = .{};
    fours.ensureTotalCapacity(gpa, BLOCK_SIZE / 4) catch unreachable;
    eights.ensureTotalCapacity(gpa, BLOCK_SIZE / 8) catch unreachable;
    var i: u32 = 0;
    while (i < BLOCK_SIZE) : (i += 4) {
        a = fastMod(a *% FACTOR_A);
        b = fastMod(b *% FACTOR_B);
        const left1: u16 = @truncate(a);
        const right1: u16 = @truncate(b);
        ones += @intFromBool(left1 == right1);
        if ((left1 & 3) == 0) fours.append(gpa, left1) catch unreachable;
        if ((right1 & 7) == 0) eights.append(gpa, right1) catch unreachable;
        a = fastMod(a *% FACTOR_A);
        b = fastMod(b *% FACTOR_B);
        const left2: u16 = @truncate(a);
        const right2: u16 = @truncate(b);
        ones += @intFromBool(left2 == right2);
        if ((left2 & 3) == 0) fours.append(gpa, left2) catch unreachable;
        if ((right2 & 7) == 0) eights.append(gpa, right2) catch unreachable;
        a = fastMod(a *% FACTOR_A);
        b = fastMod(b *% FACTOR_B);
        const left3: u16 = @truncate(a);
        const right3: u16 = @truncate(b);
        ones += @intFromBool(left3 == right3);
        if ((left3 & 3) == 0) fours.append(gpa, left3) catch unreachable;
        if ((right3 & 7) == 0) eights.append(gpa, right3) catch unreachable;
        a = fastMod(a *% FACTOR_A);
        b = fastMod(b *% FACTOR_B);
        const left4: u16 = @truncate(a);
        const right4: u16 = @truncate(b);
        ones += @intFromBool(left4 == right4);
        if ((left4 & 3) == 0) fours.append(gpa, left4) catch unreachable;
        if ((right4 & 7) == 0) eights.append(gpa, right4) catch unreachable;
    }
    data.result = Block{
        .start = data.block_idx * BLOCK_SIZE,
        .ones = ones,
        .fours = fours,
        .eights = eights,
    };
}
fn solve(input: []const u8) Result {
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    const line_a = lines.next() orelse "";
    const line_b = lines.next() orelse "";
    var tokens_a = std.mem.tokenizeAny(u8, line_a, " ");
    var tokens_b = std.mem.tokenizeAny(u8, line_b, " ");
    _ = tokens_a.next();
    _ = tokens_a.next();
    _ = tokens_a.next();
    _ = tokens_a.next();
    const start_a = std.fmt.parseInt(u64, tokens_a.next() orelse "0", 10) catch 0;
    _ = tokens_b.next();
    _ = tokens_b.next();
    _ = tokens_b.next();
    _ = tokens_b.next();
    const start_b = std.fmt.parseInt(u64, tokens_b.next() orelse "0", 10) catch 0;
    const gpa = std.heap.page_allocator;
    const num_blocks = PART_ONE / BLOCK_SIZE;
    const num_threads = @min(8, std.Thread.getCpuCount() catch 4);
    var all_fours: std.ArrayList(u16) = .{};
    defer all_fours.deinit(gpa);
    var all_eights: std.ArrayList(u16) = .{};
    defer all_eights.deinit(gpa);
    var p1: u32 = 0;
    var block_idx: u32 = 0;
    while (block_idx < num_blocks) {
        const batch_size = @min(num_threads, num_blocks - block_idx);
        var threads: [8]std.Thread = undefined;
        var worker_data: [8]WorkerData = undefined;
        for (0..batch_size) |t| {
            const idx = block_idx + @as(u32, @intCast(t));
            const offset: u64 = idx * BLOCK_SIZE;
            const factor_a = modPow(FACTOR_A, offset, MOD);
            const factor_b = modPow(FACTOR_B, offset, MOD);
            worker_data[t] = .{
                .start_a = fastMod(start_a *% factor_a),
                .start_b = fastMod(start_b *% factor_b),
                .block_idx = idx,
                .allocator = gpa,
                .result = null,
            };
            threads[t] = std.Thread.spawn(.{}, blockWorker, .{&worker_data[t]}) catch unreachable;
        }
        for (0..batch_size) |t| {
            threads[t].join();
            if (worker_data[t].result) |*block| {
                p1 += block.ones;
                all_fours.appendSlice(gpa, block.fours.items) catch unreachable;
                all_eights.appendSlice(gpa, block.eights.items) catch unreachable;
                block.fours.deinit(gpa);
                block.eights.deinit(gpa);
            }
        }
        block_idx += @intCast(batch_size);
    }
    var p2: u32 = 0;
    const limit = @min(PART_TWO, @min(all_fours.items.len, all_eights.items.len));
    for (0..limit) |i| {
        p2 += @intFromBool(all_fours.items[i] == all_eights.items[i]);
    }
    return .{ .p1 = p1, .p2 = p2 };
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
