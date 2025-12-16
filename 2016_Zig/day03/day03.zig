const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
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
fn solve(input: []const u8) Result {
    @setRuntimeSafety(false);
    var p1: u32 = 0;
    var p2: u32 = 0;
    var buf: [9]u16 = undefined;
    var buf_len: usize = 0;
    var i: usize = 0;
    while (i < input.len) {
        var nums: [3]u16 = undefined;
        var n_idx: usize = 0;

        while (i < input.len and n_idx < 3) {
            const c = input[i];
            if (c >= '0' and c <= '9') {
                var n: u16 = c - '0';
                i += 1;
                while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
                    n = n * 10 + (input[i] - '0');
                }
                nums[n_idx] = n;
                n_idx += 1;
            } else {
                i += 1;
            }
        }

        while (i < input.len and input[i] != '\n') : (i += 1) {}
        while (i < input.len and (input[i] == '\n' or input[i] == '\r')) : (i += 1) {}
        if (n_idx == 3) {
            if (isValid(nums[0], nums[1], nums[2])) p1 += 1;
            buf[buf_len] = nums[0];
            buf[buf_len + 1] = nums[1];
            buf[buf_len + 2] = nums[2];
            buf_len += 3;
            if (buf_len == 9) {
                if (isValid(buf[0], buf[3], buf[6])) p2 += 1;
                if (isValid(buf[1], buf[4], buf[7])) p2 += 1;
                if (isValid(buf[2], buf[5], buf[8])) p2 += 1;
                buf_len = 0;
            }
        }
    }
    return .{ .p1 = p1, .p2 = p2 };
}
inline fn isValid(a: u16, b: u16, c: u16) bool {
    return (a + b > c) and (a + c > b) and (b + c > a);
}
