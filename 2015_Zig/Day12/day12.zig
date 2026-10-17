const std = @import("std");

// `red` marks an object with a "red" string as a direct value (its sum is then ignored).
const Frame = struct {
    sum: i32,
    red: i32, // all ones when the object holds a "red" value
};

const Vec = @Vector(64, u8);

inline fn bitsOf(v: Vec, comptime c: u8) u64 {
    return @as(u64, @bitCast(v == @as(Vec, @splat(c))));
}

inline fn prefixXor(x: u64) u64 {
    var r = x;
    r ^= r << 1;
    r ^= r << 2;
    r ^= r << 4;
    r ^= r << 8;
    r ^= r << 16;
    r ^= r << 32;
    return r;
}

// Value of the leading digits of an 8-byte window, without a branch per digit: the digit
// count comes from the first non-digit byte, the digits are shifted to the top of the word
// and combined pairwise (SWAR: 2, then 4, then 8 digits at a time).
inline fn parse8(bytes: *const [8]u8) i32 {
    const w = std.mem.readInt(u64, bytes, .little);
    const d = w -% 0x3030303030303030;
    // A byte is a digit when it is 0..9 after subtracting '0' (no borrow, below 10).
    // Borrows and carries only travel upwards, so every byte below the first non-digit is exact.
    const not_digit = (d | (d +% 0x7676767676767676)) & 0x8080808080808080;
    if (not_digit == 0) return parseSlow(bytes); // eight or more digits
    const len: u6 = @intCast(@ctz(not_digit) >> 3);
    // Keep the len digits, right-aligned so the last digit lands in the top byte.
    // No digits shifts by 64, which std.math.shl turns into 0 without a branch.
    const shift: u7 = 64 - @as(u7, len) * 8;
    var x = std.math.shl(u64, d, shift);
    x = (x *% 10 +% (x >> 8)) & 0x00FF00FF00FF00FF;
    x = (x *% 100 +% (x >> 16)) & 0x0000FFFF0000FFFF;
    x = (x *% 10000 +% (x >> 32)) & 0x00000000FFFFFFFF;
    return @intCast(x);
}

fn parseSlow(s: []const u8) i32 {
    var acc: i32 = 0;
    for (s) |c| {
        if (c < '0' or c > '9') break;
        acc = acc * 10 + @as(i32, c - '0');
    }
    return acc;
}

// Walks the JSON in 64-byte blocks. Vector compares find quotes, brackets and
// number starts; a prefix-XOR over the quotes marks bytes inside strings so
// only structural bytes outside strings become events. Events are handled in
// order with an explicit stack instead of recursion.
inline fn solve(input: []const u8) struct { p1: i32, p2: i32 } {
    @setRuntimeSafety(false);
    // The bottom frame (index 0) is a dummy that collects the root container's total.
    var stack: [64]Frame = undefined;
    stack[0] = .{ .sum = 0, .red = 0 };
    var depth: usize = 0;
    var p1: i32 = 0;

    var in_str: u64 = 0; // all ones when the previous block ended inside a string
    var prev_num: u64 = 0; // bit 0: previous block ended on a digit or '-'
    var prev_colon: u64 = 0; // bit 0: previous block ended on a ':'

    var base: usize = 0;
    while (base < input.len) : (base += 64) {
        // Full blocks are loaded straight from the input; only the tail is copied and padded.
        var v: Vec = undefined;
        if (input.len - base >= 64) {
            v = input[base..][0..64].*;
        } else {
            var block = [_]u8{0} ** 64;
            @memcpy(block[0 .. input.len - base], input[base..]);
            v = block;
        }

        const quotes = bitsOf(v, '"');
        const pre = prefixXor(quotes) ^ in_str;
        in_str = @as(u64, 0) -% (pre >> 63);

        // Only a string right after a ':' can be a "red" value, so keys never become events.
        const colons = bitsOf(v, ':');
        const after_colon = (colons << 1) | prev_colon;
        prev_colon = colons >> 63;
        const open_quotes = quotes & pre & after_colon;
        const brackets = (bitsOf(v, '[') | bitsOf(v, ']') | bitsOf(v, '{') | bitsOf(v, '}')) & ~pre;
        const digits = @as(u64, @bitCast((v >= @as(Vec, @splat('0'))) & (v <= @as(Vec, @splat('9'))))) | bitsOf(v, '-');
        // A number starts at a digit or '-' that does not follow another digit or '-'.
        const num_starts = digits & ~((digits << 1) | prev_num) & ~pre;
        prev_num = digits >> 63;

        // Every event runs the same straight-line code: which kind it is only selects values
        // through masks, so nothing depends on a branch the predictor would keep missing.
        var events = open_quotes | brackets | num_starts;
        while (events != 0) : (events &= events - 1) {
            const pos = base + @ctz(events);
            const c = input[pos];
            const open: u32 = @as(u32, @intFromBool(c == '[')) | @intFromBool(c == '{');
            const close: u32 = @as(u32, @intFromBool(c == ']')) | @intFromBool(c == '}');
            const quote: u32 = @intFromBool(c == '"');
            const neg: i32 = @intFromBool(c == '-');
            // Numbers: the value; anything else parses no digits and gives 0.
            const mag = parse8(input[pos + @as(usize, @intCast(neg)) ..][0..8]);
            const val = (mag ^ -neg) + neg;
            p1 += val;
            // "red" right after a colon marks the enclosing object.
            const red_word = std.mem.readInt(u32, input[pos + 1 ..][0..4], .little);
            const red: i32 = -@as(i32, @intCast(quote & @intFromBool(red_word == 0x22646572)));

            const top = stack[depth];
            depth -= close;
            const cmask: i32 = -@as(i32, @intCast(close));
            stack[depth].sum += ((top.sum & ~top.red) & cmask) + val;
            depth += open;
            const keep: i32 = @as(i32, @intCast(open)) - 1;
            stack[depth].sum &= keep;
            stack[depth].red = (stack[depth].red & keep) | red;
        }
    }

    return .{ .p1 = p1, .p2 = stack[0].sum };
}

pub fn main() !void {
    // Zero padding keeps the fixed-size reads past the last event inside the buffer; zero is
    // never an event byte.
    const input = @embedFile("input.txt") ++ [_]u8{0} ** 16;
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
