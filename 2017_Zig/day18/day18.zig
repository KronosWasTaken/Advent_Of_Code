const std = @import("std");
const Result = struct { p1: i64, p2: i64 };
fn getValue(registers: *std.AutoHashMap(u8, i64), operand: []const u8) i64 {
    if (operand.len == 0) return 0;
    if (operand[0] >= 'a' and operand[0] <= 'z') {
        return registers.get(operand[0]) orelse 0;
    }
    return std.fmt.parseInt(i64, operand, 10) catch 0;
}
fn solve(input: []const u8) Result {
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    var line_idx: usize = 0;
    var seed: u64 = 0;
    while (lines.next()) |line| {
        if (line_idx == 9) {
            var tokens = std.mem.tokenizeScalar(u8, line, ' ');
            _ = tokens.next(); 
            _ = tokens.next(); 
            if (tokens.next()) |num_str| {
                seed = std.fmt.parseInt(u64, num_str, 10) catch 0;
            }
            break;
        }
        line_idx += 1;
    }
    var numbers: [127]u64 = undefined;
    var p = seed;
    for (0..127) |i| {
        p = (p *% 8505) % 0x7fffffff;
        p = (p *% 129749 +% 12345) % 0x7fffffff;
        numbers[i] = p % 10000;
    }
    const p1 = numbers[126];
    var sorted = numbers;
    var swapped = true;
    var count: usize = 0;
    while (swapped) {
        swapped = false;
        var i: usize = 1;
        while (i < 127 - count) : (i += 1) {
            if (sorted[i - 1] < sorted[i]) {
                const temp = sorted[i - 1];
                sorted[i - 1] = sorted[i];
                sorted[i] = temp;
                swapped = true;
            }
        }
        count += 1;
    }
    const p2 = 127 * ((count + 1) / 2);
    return .{ .p1 = @intCast(p1), .p2 = @intCast(p2) };
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