const std = @import("std");
const VOWEL_TABLE = blk: {
    var table: [256]u8 = [_]u8{0} ** 256;
    table['a'] = 1;
    table['e'] = 1;
    table['i'] = 1;
    table['o'] = 1;
    table['u'] = 1;
    break :blk table;
};
inline fn isNice1(line: []const u8) u8 {
    @setRuntimeSafety(false);
    if (line.len < 2) return 0;
    var vowels: u32 = VOWEL_TABLE[line[0]];
    var has_double: u8 = 0;
    for (1..line.len) |i| {
        const c = line[i];
        const prev = line[i - 1];
        vowels += VOWEL_TABLE[c];
        has_double |= @intFromBool(c == prev);
        const pair = (@as(u16, prev) << 8) | c;
        if (pair == 0x6162 or pair == 0x6364 or pair == 0x7071 or pair == 0x7879) {
            return 0;
        }
    }
    return @intFromBool(vowels >= 3 and has_double == 1);
}
inline fn isNice2(line: []const u8) u8 {
    @setRuntimeSafety(false);
    if (line.len < 4) return 0;
    var has_repeat: u8 = 0;
    for (0..line.len - 2) |i| {
        has_repeat |= @intFromBool(line[i] == line[i + 2]);
    }
    if (has_repeat == 0) return 0;
    for (0..line.len - 3) |i| {
        const pair = line[i..i + 2];
        if (std.mem.lastIndexOf(u8, line, pair)) |last| {
            if (last >= i + 2) return 1;
        }
    }
    return 0;
}
fn solve(data: []const u8) [2]u32 {
    @setRuntimeSafety(false);
    var count1: u32 = 0;
    var count2: u32 = 0;
    var lines = std.mem.tokenizeAny(u8, data, "\r\n");
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        count1 += isNice1(line);
        count2 += isNice2(line);
    }
    return .{ count1, count2 };
}
pub fn main() !void {
    const data = @embedFile("input.txt");
    var result = solve(data);
    for (0..100) |_| result = solve(data);
    const iters: u32 = 10000;
    var timer = try std.time.Timer.start();
    const start = timer.read();
    for (0..iters) |_| result = solve(data);
    const elapsed_us = @as(f64, @floatFromInt(timer.read() - start)) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result[0], result[1] });
    std.debug.print("Total: {d:.2} microseconds\n", .{elapsed_us});
    std.debug.print("Average: {d:.4} microseconds\n", .{elapsed_us / @as(f64, @floatFromInt(iters))});
}
