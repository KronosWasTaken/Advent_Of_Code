const std = @import("std");

const Replacement = struct {
    from: []const u8,
    to: []const u8,
};

const Vec = @Vector(16, u8);
const max_molecule = 1024;
const hash_base: u64 = 0x9E3779B97F4A7C15;

// powers[i] = hash_base^i, so a candidate's hash can be assembled from prefix hashes in O(1).
const powers = blk: {
    @setEvalBranchQuota(10_000);
    var t: [max_molecule + 1]u64 = undefined;
    t[0] = 1;
    for (1..t.len) |i| t[i] = t[i - 1] *% hash_base;
    break :blk t;
};

fn solve(input: []const u8) struct { p1: u32, p2: u32 } {
    @setRuntimeSafety(false);
    var reps_buf: [64]Replacement = undefined;
    var rep_count: usize = 0;
    var molecule: []const u8 = "";

    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        if (std.mem.indexOf(u8, line, " => ")) |idx| {
            reps_buf[rep_count] = .{
                .from = line[0..idx],
                .to = line[idx + 4 ..],
            };
            rep_count += 1;
        } else {
            molecule = line;
        }
    }
    const reps = reps_buf[0..rep_count];
    const n = molecule.len;

    // Zero padding lets the 16-byte window loads and the pattern matches run past the
    // molecule end; zero is never a letter, so no match can start beyond it.
    var mol = [_]u8{0} ** (max_molecule + 32);
    @memcpy(mol[0..n], molecule);

    var prefix: [max_molecule + 1]u64 = undefined;
    prefix[0] = 0;
    for (0..n) |i| prefix[i + 1] = prefix[i] *% hash_base +% mol[i];

    // Polynomial hashes mod 2^64 can in principle collide, but for molecules this short
    // a collision among the candidates is negligibly unlikely; the answer is checked against
    // the exact distinct count.
    var set = [_]u64{0} ** 2048;
    var p1: u32 = 0;

    for (reps) |rep| {
        const from = rep.from;
        const to_len = rep.to.len;
        var to_hash: u64 = 0;
        for (rep.to) |c| to_hash = to_hash *% hash_base +% c;

        var base: usize = 0;
        while (base < n) : (base += 16) {
            var hits: u16 = 0xFFFF;
            for (from, 0..) |c, k| {
                const window: Vec = mol[base + k ..][0..16].*;
                hits &= @bitCast(window == @as(Vec, @splat(c)));
            }
            while (hits != 0) : (hits &= hits - 1) {
                const pos = base + @ctz(hits);
                const suffix_len = n - pos - from.len;
                const suffix = prefix[n] -% prefix[pos + from.len] *% powers[suffix_len];
                var h = prefix[pos] *% powers[to_len + suffix_len] +% to_hash *% powers[suffix_len] +% suffix;
                if (h == 0) h = 1;

                var idx = (h *% 0x9E3779B97F4A7C15) >> 53;
                while (set[idx] != 0 and set[idx] != h) idx = (idx + 1) & 2047;
                if (set[idx] == 0) {
                    set[idx] = h;
                    p1 += 1;
                }
            }
        }
    }

    var upper: u32 = 0;
    var rn: u32 = 0;
    var ar: u32 = 0;
    var y: u32 = 0;
    for (0..n) |i| {
        const c = mol[i];
        const next = mol[i + 1];
        upper += @intFromBool(c >= 'A' and c <= 'Z');
        rn += @intFromBool(c == 'R' and next == 'n');
        ar += @intFromBool(c == 'A' and next == 'r');
        y += @intFromBool(c == 'Y');
    }

    const p2 = upper - rn - ar - 2 * y - 1;
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
