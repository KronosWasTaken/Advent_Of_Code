const std = @import("std");

const Vec = @Vector(16, u8);
const Pairs = @Vector(16, u16);

inline fn eqChar(v: Vec, c: u8) @Vector(16, bool) {
    return v == @as(Vec, @splat(c));
}

inline fn solve(data: []const u8) struct { p1: u32, p2: u32 } {
    @setRuntimeSafety(false);
    var count1: u32 = 0;
    var count2: u32 = 0;
    var pos: usize = 0;

    while (pos + 16 <= data.len) {
        const line: Vec = data[pos..][0..16].*;
        pos += 16;
        while (pos < data.len and (data[pos] == '\r' or data[pos] == '\n')) : (pos += 1) {}

        // Lane 15 of the shifted vectors is filled with 0, which never matches a letter.
        const next1 = std.simd.shiftElementsLeft(line, 1, 0);
        const next2 = std.simd.shiftElementsLeft(line, 2, 0);

        const vowels = eqChar(line, 'a') | eqChar(line, 'e') | eqChar(line, 'i') | eqChar(line, 'o') | eqChar(line, 'u');
        const forbidden_first = eqChar(line, 'a') | eqChar(line, 'c') | eqChar(line, 'p') | eqChar(line, 'x');
        const forbidden = (next1 -% line == @as(Vec, @splat(1))) & forbidden_first;
        const has_double = line == next1;
        const letter_gap = line == next2;

        const nice1 = !@reduce(.Or, forbidden) and @popCount(@as(u16, @bitCast(vowels))) >= 3 and @reduce(.Or, has_double);
        count1 += @intFromBool(nice1);

        // A pair occurring at distance k >= 2 is an occurrence that does not overlap it.
        const pairs = @as(Pairs, line) * @as(Pairs, @splat(256)) + @as(Pairs, next1);
        var pair_repeat: @Vector(16, bool) = @splat(false);
        inline for (2..16) |k| {
            const ahead = std.simd.shiftElementsLeft(pairs, k, 0xFFFF);
            pair_repeat |= pairs == ahead;
        }
        const nice2 = @reduce(.Or, pair_repeat) and @reduce(.Or, letter_gap);
        count2 += @intFromBool(nice2);
    }

    return .{ .p1 = count1, .p2 = count2 };
}

pub fn main() !void {
    const data = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(data);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
