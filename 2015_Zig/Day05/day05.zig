const std = @import("std");

inline fn solve(data: []const u8) struct { p1: u32, p2: u32 } {
    @setRuntimeSafety(false);
    const VOWEL_MASK: u32 = 0x0104111;
    const FORBIDDEN_MASK: u32 = 0x101000a;

    var count1: u32 = 0;
    var count2: u32 = 0;
    var pairs = [_]u32{0} ** 729;

    var line_idx: u32 = 1;
    var base_offset: usize = 0;

    while (base_offset + 16 <= data.len) {
        if (data[base_offset] < 'a' or data[base_offset] > 'z') {
            base_offset += 1;
            continue;
        }
        const line = data[base_offset .. base_offset + 16];
        base_offset += 16;
        while (base_offset < data.len and (data[base_offset] == '\r' or data[base_offset] == '\n')) : (base_offset += 1) {}

        var vowels: u32 = 0;
        var has_double: bool = false;
        var prev_mask: u32 = 0;
        var nice1 = true;

        var first: u32 = 0;
        var second: u32 = 0;
        var two_pair = false;
        var split_pair = false;
        const base = line_idx * 1000;
        line_idx += 1;

        inline for (0..16) |offset| {
            const c = line[offset];
            const cur_mask = @as(u32, 1) << @as(u5, @truncate(c - 'a'));
            if ((FORBIDDEN_MASK & cur_mask & (prev_mask << 1)) != 0) {
                nice1 = false;
            }
            if ((VOWEL_MASK & cur_mask) != 0) vowels += 1;
            has_double = has_double or (prev_mask == cur_mask);
            prev_mask = cur_mask;

            const third: u32 = (c - 'a') + 1;
            const pair_idx = 27 * second + third;
            const pos = base + @as(u32, offset);
            const delta = pos - pairs[pair_idx];

            if (delta > offset) {
                pairs[pair_idx] = pos;
            } else if (delta > 1) {
                two_pair = true;
            }
            split_pair = split_pair or (first == third);

            first = second;
            second = third;
        }

        if (nice1 and vowels >= 3 and has_double) count1 += 1;
        if (two_pair and split_pair) count2 += 1;
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
