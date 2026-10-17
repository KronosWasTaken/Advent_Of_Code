const std = @import("std");

const Vec = @Vector(16, u8);

const Cmp = enum { eq, gt, lt };

const attr_names = [_][]const u8{ "children", "cats", "samoyeds", "pomeranians", "akitas", "vizslas", "goldfish", "trees", "cars", "perfumes" };
const attr_target = [_]u8{ 3, 7, 2, 3, 0, 0, 5, 3, 2, 1 };
const attr_cmp = [_]Cmp{ .eq, .gt, .eq, .lt, .eq, .eq, .lt, .gt, .eq, .eq };

// Bit 0 is set when the value matches for part 1, bit 1 when it matches for part 2.
const attr_ok = blk: {
    @setEvalBranchQuota(10_000);
    var t: [attr_names.len * 100]u8 = undefined;
    for (attr_target, attr_cmp, 0..) |target, cmp, attr| {
        for (0..100) |val| {
            const p1 = val == target;
            const p2 = switch (cmp) {
                .eq => val == target,
                .gt => val > target,
                .lt => val < target,
            };
            t[attr * 100 + val] = @intFromBool(p1) | (@as(u8, @intFromBool(p2)) << 1);
        }
    }
    break :blk t;
};

inline fn key2(a: u8, b: u8) usize {
    return @as(usize, a - 'a') * 26 + (b - 'a');
}

// The third- and second-to-last letters of every attribute name are unique, so a 676-byte
// table names the attribute. (A three-letter key would need 17.5 KB, which costs page
// faults on a cold run.)
const attr_by_key = blk: {
    @setEvalBranchQuota(10_000);
    var t = [_]u8{0xFF} ** (26 * 26);
    for (attr_names, 0..) |name, attr| {
        const k = key2(name[name.len - 3], name[name.len - 2]);
        if (t[k] != 0xFF) @compileError("attribute key collision");
        t[k] = attr;
    }
    break :blk t;
};

fn solve(input: []const u8) struct { p1: u16, p2: u16 } {
    @setRuntimeSafety(false);
    // Each line has one "Sue N:" colon and three attribute colons, so the colons of every
    // line are consecutive in this list. 512 lines of input is the most this buffer holds.
    var colons: [4 * 512]u16 = undefined;
    var colon_count: usize = 0;

    // Zero padding past the last line lets the 64-byte block loads below stay in bounds.
    const len = input.len - 64;
    var block: usize = 0;
    while (block < len) : (block += 64) {
        var mask: u64 = 0;
        inline for (0..4) |q| {
            const chunk: Vec = input[block + 16 * q ..][0..16].*;
            mask |= @as(u64, @as(u16, @bitCast(chunk == @as(Vec, @splat(':'))))) << (16 * q);
        }
        while (mask != 0) : (mask &= mask - 1) {
            colons[colon_count] = @intCast(block + @ctz(mask));
            colon_count += 1;
        }
    }

    var p1: u16 = 0;
    var p2: u16 = 0;
    var c: usize = 0;
    while (c + 4 <= colon_count) : (c += 4) {
        const sue_colon = colons[c];
        var sue_num: u16 = 0;
        var scale: u16 = 1;
        var p = sue_colon;
        while (input[p - 1] >= '0' and input[p - 1] <= '9') : (p -= 1) {
            sue_num += (input[p - 1] - '0') * scale;
            scale *= 10;
        }

        var matches: u8 = 3;
        inline for (1..4) |attr_num| {
            const colon = colons[c + attr_num];
            const attr = attr_by_key[key2(input[colon - 3], input[colon - 2])];
            const d0 = input[colon + 2] - '0';
            const d1 = input[colon + 3] -% '0';
            const two_digits = d1 < 10;
            const val: u8 = if (two_digits) d0 * 10 + d1 else d0;
            matches &= attr_ok[@as(usize, attr) * 100 + val];
        }

        if (matches & 1 != 0) p1 = sue_num;
        if (matches & 2 != 0) p2 = sue_num;
    }
    return .{ .p1 = p1, .p2 = p2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt") ++ [_]u8{0} ** 64;
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
