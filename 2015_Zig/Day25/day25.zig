const std = @import("std");
inline fn modPow(base: u64, exp: u64, modulus: u64) u64 {
    @setRuntimeSafety(false);
    if (exp == 0) return 1;
    var result: u64 = 1;
    var b = base % modulus;
    var e = exp;
    while (e > 0) {
        if (e & 1 == 1) {
            result = (result * b) % modulus;
        }
        b = (b * b) % modulus;
        e >>= 1;
    }
    return result;
}
fn solve(input: []const u8) struct { p1: u64, p2: []const u8 } {
    @setRuntimeSafety(false);
    var idx: usize = 0;
    while (idx < input.len and (input[idx] < '0' or input[idx] > '9')) : (idx += 1) {}
    var row: u64 = 0;
    while (idx < input.len and input[idx] >= '0' and input[idx] <= '9') : (idx += 1) {
        row = row * 10 + (input[idx] - '0');
    }
    while (idx < input.len and (input[idx] < '0' or input[idx] > '9')) : (idx += 1) {}
    var col: u64 = 0;
    while (idx < input.len and input[idx] >= '0' and input[idx] <= '9') : (idx += 1) {
        col = col * 10 + (input[idx] - '0');
    }
    const n = col + row - 1;
    const triangle = (n * (n + 1)) / 2;
    const index = triangle - row;
    const base: u64 = 252533;
    const modulus: u64 = 33554393;
    const first_code: u64 = 20151125;
    const power = modPow(base, index, modulus);
    const result = (first_code * power) % modulus;
    return .{ .p1 = result, .p2 = "Merry Christmas!" };
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {d} | Part 2: {s}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
