const std = @import("std");
const target = [_]i8{ 3, 7, 2, 3, 0, 0, 5, 3, 2, 1 };
inline fn getAttrIdx(first: u8, len: u8) u8 {
    return switch (first) {
        'c' => if (len == 8) 0 else if (len == 4) 8 else 1, // children(8), cars(4), cats(4)
        's' => 2, // samoyeds
        'p' => if (len == 11) 3 else 9, // pomeranians(11), perfumes(8)
        'a' => 4, // akitas
        'v' => 5, // vizslas
        'g' => 6, // goldfish
        't' => 7, // trees
        else => 255,
    };
}
fn solve(input: []const u8) struct { p1: u16, p2: u16 } {
    @setRuntimeSafety(false);
    var p1: u16 = 0;
    var p2: u16 = 0;
    var idx: usize = 0;
    while (idx < input.len) {
        idx += 4;
        var sue_num: u16 = input[idx] - '0';
        idx += 1;
        if (input[idx] != ':') {
            sue_num = sue_num * 10 + (input[idx] - '0');
            idx += 1;
            if (input[idx] != ':') {
                sue_num = sue_num * 10 + (input[idx] - '0');
                idx += 1;
            }
        }
        idx += 2; // Skip ": "
        var match_p1: u8 = 1;
        var match_p2: u8 = 1;
        comptime var attr_count: u8 = 0;
        inline while (attr_count < 3) : (attr_count += 1) {
            const start = idx;
            while (input[idx] != ':') : (idx += 1) {}
            const attr_len = @as(u8, @intCast(idx - start));
            const first_char = input[start];
            idx += 2; // Skip ": "
            var val: i8 = @as(i8, @intCast(input[idx] - '0'));
            idx += 1;
            if (input[idx] >= '0' and input[idx] <= '9') {
                val = val * 10 + @as(i8, @intCast(input[idx] - '0'));
                idx += 1;
            }
            const i = getAttrIdx(first_char, attr_len);
            const tgt = target[i];
            match_p1 &= @intFromBool(val == tgt);
            const is_gt = (i == 1 or i == 7); // cats, trees
            const is_lt = (i == 3 or i == 6); // pomeranians, goldfish
            const p2_match = if (is_gt) (val > tgt) else if (is_lt) (val < tgt) else (val == tgt);
            match_p2 &= @intFromBool(p2_match);
            if (idx < input.len and input[idx] == ',') idx += 2;
        }
        if (match_p1 != 0) p1 = sue_num;
        if (match_p2 != 0) p2 = sue_num;
        while (idx < input.len and (input[idx] == '\r' or input[idx] == '\n')) : (idx += 1) {}
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
