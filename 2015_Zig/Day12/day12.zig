const std = @import("std");

// `red` marks an object with a "red" string as a direct value (its sum is then ignored).
const Frame = struct {
    sum: i32,
    red: bool,
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

// Walks the JSON in 64-byte blocks. Vector compares find quotes, brackets and
// number starts; a prefix-XOR over the quotes marks bytes inside strings so
// only structural bytes outside strings become events. Events are handled in
// order with an explicit stack instead of recursion.
inline fn solve(input: []const u8) struct { p1: i32, p2: i32 } {
    @setRuntimeSafety(false);
    // The bottom frame (index 0) is a dummy that collects the root container's total.
    var stack: [64]Frame = undefined;
    stack[0] = .{ .sum = 0, .red = false };
    var depth: usize = 0;
    var p1: i32 = 0;

    var in_str: u64 = 0; // all ones when the previous block ended inside a string
    var prev_num: u64 = 0; // bit 0: previous block ended on a digit or '-'
    var prev_colon: u64 = 0; // bit 0: previous block ended on a ':'

    var base: usize = 0;
    while (base < input.len) : (base += 64) {
        var block = [_]u8{0} ** 64;
        const n = @min(64, input.len - base);
        @memcpy(block[0..n], input[base .. base + n]);
        const v: Vec = block;

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

        var events = open_quotes | brackets | num_starts;
        while (events != 0) : (events &= events - 1) {
            const pos = base + @ctz(events);
            switch (input[pos]) {
                '[', '{' => {
                    depth += 1;
                    stack[depth] = .{ .sum = 0, .red = false };
                },
                ']', '}' => {
                    const f = stack[depth];
                    depth -= 1;
                    stack[depth].sum += if (f.red) 0 else f.sum;
                },
                '"' => {
                    if (input[pos + 1] == 'r' and input[pos + 2] == 'e' and input[pos + 3] == 'd' and input[pos + 4] == '"') {
                        stack[depth].red = true;
                    }
                },
                else => {
                    const neg = input[pos] == '-';
                    var j = pos + @as(usize, @intFromBool(neg));
                    var acc: i32 = 0;
                    while (input[j] >= '0' and input[j] <= '9') : (j += 1) {
                        acc = acc * 10 + @as(i32, input[j] - '0');
                    }
                    const val = if (neg) -acc else acc;
                    p1 += val;
                    stack[depth].sum += val;
                },
            }
        }
    }

    return .{ .p1 = p1, .p2 = stack[0].sum };
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
