const std = @import("std");
inline fn solve(input: []const u8) struct { p1: i32, p2: i32 } {
    @setRuntimeSafety(false);
    var code_len: i32 = 0;
    var mem_len: i32 = 0;
    var enc_len: i32 = 0;
    var i: usize = 0;
    while (i < input.len) {
        const start = i;
        while (i < input.len) {
            if (input[i] < 14) break; // '\r' = 13, '\n' = 10
            i += 1;
        }
        const line = input[start..i];
        i += @intFromBool(i < input.len and input[i] == '\r');
        i += @intFromBool(i < input.len and input[i] == '\n');
        if (line.len == 0) break;
        const len = line.len;
        code_len += @intCast(len);
        var j: usize = 1;
        var mem_count: i32 = 0;
        const end = len - 1;
        while (j < end) {
            const skip: usize = if (line[j] != '\\') 1 else if (line[j + 1] == 'x') 4 else 2;
            j += skip;
            mem_count += 1;
        }
        mem_len += mem_count;
        var enc_count: i32 = 2; // surrounding quotes
        for (line) |c| {
            enc_count += if (c == '\\' or c == '"') 2 else 1;
        }
        enc_len += enc_count;
    }
    return .{ .p1 = code_len - mem_len, .p2 = enc_len - code_len };
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
