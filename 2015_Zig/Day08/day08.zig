const std = @import("std");

const Vec = @Vector(64, u8);

inline fn bitsOf(v: Vec, comptime c: u8) u64 {
    return @as(u64, @bitCast(v == @as(Vec, @splat(c))));
}

// Which characters are escaped, 64 at a time (the backslash-run trick from simdjson): a
// character is escaped when it follows an odd-length run of backslashes. `carry` is 1 when
// the previous block ended on an escaping backslash.
inline fn escapedChars(backslash: u64, carry: *u64) u64 {
    const odd_bits: u64 = 0xAAAAAAAAAAAAAAAA;
    const potential = backslash & ~carry.*;
    const code = (((potential << 1) | odd_bits) -% potential) ^ odd_bits;
    const escaped = code ^ (backslash | carry.*);
    carry.* = (code & backslash) >> 63;
    return escaped;
}

// Every string is one line, so with E escapes of which X are \x, the code is 2 + its memory
// length plus E + 2X characters longer: part 1 is 2 per line + E + 2X. Encoding adds one
// character per quote or backslash plus the 2 new enclosing quotes, so part 2 is
// quotes + backslashes + 2 per line.
inline fn solve(input: []const u8) struct { p1: i32, p2: i32 } {
    @setRuntimeSafety(false);
    var len = input.len;
    while (len > 0 and input[len - 1] <= ' ') : (len -= 1) {}

    var escapes: u32 = 0;
    var hex: u32 = 0;
    var specials: u32 = 0;
    var newlines: u32 = 0;
    var carry: u64 = 0;
    var base: usize = 0;
    while (base < len) : (base += 64) {
        var v: Vec = undefined;
        if (len - base >= 64) {
            v = input[base..][0..64].*;
        } else {
            var block = [_]u8{0} ** 64;
            @memcpy(block[0 .. len - base], input[base..len]);
            v = block;
        }
        const backslash = bitsOf(v, '\\');
        const escaped = escapedChars(backslash, &carry);
        escapes += @popCount(escaped);
        hex += @popCount(escaped & bitsOf(v, 'x'));
        specials += @popCount(backslash | bitsOf(v, '"'));
        newlines += @popCount(bitsOf(v, '\n'));
    }
    const lines = newlines + 1;
    return .{
        .p1 = @intCast(2 * lines + escapes + 2 * hex),
        .p2 = @intCast(specials + 2 * lines),
    };
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\nPart 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
